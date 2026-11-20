--!strict
-- Armas no servidor (GDD 7.2 e 7.3, segurança 16.6). O servidor é a autoridade:
--   * guarda as armas, a munição e a cadência de cada jogador (a mesma máquina WeaponState do cliente);
--   * recusa tiro fora da cadência, sem munição, recarregando, longe demais ou atrás de parede;
--   * calcula o dano (com a distância) e aplica pelo registro Combatants.
-- O cliente acerta o alvo na tela dele e manda o ponto de acerto; o servidor confere tudo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CharacterConfig = require(Shared.Config.CharacterConfig)
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local CombatTypes = require(Shared.Combat.CombatTypes)
local Remotes = require(Shared.Remotes)
local ShotValidation = require(Shared.Combat.ShotValidation)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponMath = require(Shared.Combat.WeaponMath)
local WeaponState = require(Shared.Combat.WeaponState)

local CharacterService = require(script.Parent.CharacterService)
local Combatants = require(script.Parent.Combatants)

type Slot = CombatTypes.Slot
type WeaponDef = WeaponConfig.WeaponDef

local VALIDATION = CombatConfig.Validation
local HITBOX = CombatConfig.Hitbox
local SLACK = VALIDATION.TimingSlackSeconds

type Loadout = { primary: string?, secondary: string, melee: string }

type PlayerCombat = {
	loadout: Loadout,
	equipped: Slot,
	guns: { [string]: WeaponState.State },
	melee: WeaponState.MeleeState,
	lastActionT: number,
	rateWindowStart: number,
	rateCount: number,
}

-- Teste de exploit do painel (só DEV_): conta tiros aceitos numa janela curta.
type ExploitWatch = { sent: number, accepted: number, firstT: number?, lastT: number?, fireRate: number }

local CombatService = {}

local actionEvent: RemoteEvent
local combatEvent: RemoteEvent
local shotFx: UnreliableRemoteEvent

local players: { [Player]: PlayerCombat } = {}
local exploitWatches: { [Player]: ExploitWatch } = {}
-- Lentidão de carta (Tremor, GDD 8.4): multiplicador da velocidade e até quando (os.clock)
local slows: { [Player]: { multiplier: number, untilClock: number } } = {}
local activityCallbacks: { (player: Player) -> () } = {}
-- Ações aceitas da arma (tutorial, F6): "Equip" (slot), "Reload" (nil), "Alt" (boolean)
export type WeaponEventKind = "Equip" | "Reload" | "Alt"
type WeaponListener = (player: Player, kind: WeaponEventKind, data: any) -> ()
local weaponListeners: { WeaponListener } = {}

local function emitWeapon(player: Player, kind: WeaponEventKind, data: any)
	for _, listener in weaponListeners do
		task.spawn(listener, player, kind, data)
	end
end

local sightParams = RaycastParams.new()
sightParams.CollisionGroup = CombatNames.Groups.SightRay
sightParams.FilterType = Enum.RaycastFilterType.Exclude
sightParams.FilterDescendantsInstances = {}

-- Estado -----------------------------------------------------------------------------------------

local function defaultLoadout(): Loadout
	return {
		primary = CombatConfig.TestArena.DefaultPrimary,
		secondary = CombatConfig.TestArena.DefaultSecondary,
		melee = WeaponConfig.Melee.id,
	}
end

local function buildCombat(loadout: Loadout): PlayerCombat
	local guns: { [string]: WeaponState.State } = {}
	local primaryDef = if loadout.primary then WeaponConfig.get(loadout.primary) else nil
	if primaryDef then
		guns.primary = WeaponState.new(primaryDef)
	end
	local secondaryDef = WeaponConfig.get(loadout.secondary)
	assert(secondaryDef, `Secundária inválida: {loadout.secondary}`)
	guns.secondary = WeaponState.new(secondaryDef)
	return {
		loadout = loadout,
		equipped = if guns.primary then "primary" else "secondary",
		guns = guns,
		melee = WeaponState.newMelee(WeaponConfig.Melee),
		lastActionT = -math.huge,
		rateWindowStart = 0,
		rateCount = 0,
	}
end

local function sendLoadout(player: Player, pc: PlayerCombat)
	local data: CombatTypes.LoadoutData = {
		primary = pc.loadout.primary,
		secondary = pc.loadout.secondary,
		melee = pc.loadout.melee,
		equipped = pc.equipped,
	}
	combatEvent:FireClient(player, "Loadout", data)
end

local function sendSync(player: Player, slot: string, state: WeaponState.State)
	local data: CombatTypes.SyncData = { slot = slot :: Slot, ammo = state.ammo, reloadEndsAt = state.reloadEndsAt }
	combatEvent:FireClient(player, "Sync", data)
end

local function slowMultiplier(player: Player): number
	local slow = slows[player]
	if slow == nil then
		return 1
	end
	if os.clock() >= slow.untilClock then
		slows[player] = nil
		return 1
	end
	return slow.multiplier
end

local function updateWalkSpeed(player: Player, pc: PlayerCombat)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local multiplier = slowMultiplier(player)
	if pc.equipped == "melee" then
		humanoid.WalkSpeed = WeaponMath.walkSpeed(nil, false, true) * multiplier
		return
	end
	local state = pc.guns[pc.equipped]
	local scoped = state ~= nil and state.alt and WeaponConfig.hasScope(state.def)
	humanoid.WalkSpeed = WeaponMath.walkSpeed(if state then state.def else nil, scoped, false) * multiplier
end

-- Deixa o jogador mais lento por `seconds` (ex.: Tremor: 50% = percent 0.5). Só no combate.
function CombatService.applySlow(player: Player, percent: number, seconds: number)
	local pc = players[player]
	if pc == nil then
		return
	end
	local untilClock = os.clock() + seconds
	slows[player] = { multiplier = math.clamp(1 - percent, 0, 1), untilClock = untilClock }
	updateWalkSpeed(player, pc)
	task.delay(seconds + 0.05, function()
		local slow = slows[player]
		local current = players[player]
		if slow and slow.untilClock == untilClock then
			slows[player] = nil
		end
		if current then
			updateWalkSpeed(player, current)
		end
	end)
end

-- Troca as armas do jogador (F3: fases por rodada; F2: painel de teste). Munição cheia.
function CombatService.setLoadout(player: Player, primary: string?, secondary: string)
	local pc = buildCombat({ primary = primary, secondary = secondary, melee = WeaponConfig.Melee.id })
	players[player] = pc
	sendLoadout(player, pc)
	updateWalkSpeed(player, pc)
end

-- Sem armas (mirante, preparação): o servidor recusa qualquer ação e o cliente esconde a arma.
function CombatService.disarm(player: Player)
	players[player] = nil
	slows[player] = nil
	combatEvent:FireClient(player, "Disarm", nil)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = CharacterConfig.Movement.WalkSpeed
	end
end

-- Chamado a cada pedido de arma aceito para análise (atividade do jogador, GDD 4.9 AFK).
function CombatService.onActivity(callback: (player: Player) -> ())
	table.insert(activityCallbacks, callback)
end

-- Ações da arma aceitas pelo servidor (tutorial: "troque de arma", "recarregue", "abra a mira").
function CombatService.onWeaponEvent(listener: WeaponListener)
	table.insert(weaponListeners, listener)
end

function CombatService.getLoadout(player: Player): Loadout?
	local pc = players[player]
	return if pc then pc.loadout else nil
end

-- Painel de teste: coloca a arma no espaço dela (primária ou pistola) e já equipa.
function CombatService.devSetWeapon(player: Player, weaponId: string): boolean
	local def = WeaponConfig.get(weaponId)
	local pc = players[player]
	if def == nil or pc == nil then
		return false
	end
	local loadout = table.clone(pc.loadout)
	if def.slot == "primary" then
		loadout.primary = weaponId
	else
		loadout.secondary = weaponId
	end
	local newPc = buildCombat(loadout)
	newPc.equipped = def.slot
	players[player] = newPc
	sendLoadout(player, newPc)
	updateWalkSpeed(player, newPc)
	return true
end

function CombatService.devWatchExploit(player: Player, sent: number)
	local pc = players[player]
	local state = pc and pc.guns[pc.equipped]
	local watch: ExploitWatch = {
		sent = sent,
		accepted = 0,
		firstT = nil,
		lastT = nil,
		fireRate = if state then state.def.fireRate else 1,
	}
	exploitWatches[player] = watch
end

-- Resultado do teste de exploit: (aceitos, enviados, permitidos pela cadência)
function CombatService.devFinishExploit(player: Player): (number, number, number)
	local watch = exploitWatches[player]
	exploitWatches[player] = nil
	if watch == nil then
		return 0, 0, 0
	end
	local span = if watch.firstT and watch.lastT then watch.lastT - watch.firstT else 0
	local allowed = 1 + math.floor(span * watch.fireRate + 1e-6)
	return watch.accepted, watch.sent, allowed
end

-- Validação -------------------------------------------------------------------------------------

local function rateLimited(pc: PlayerCombat): boolean
	local now = os.clock()
	if now - pc.rateWindowStart >= 1 then
		pc.rateWindowStart = now
		pc.rateCount = 0
	end
	pc.rateCount += 1
	return pc.rateCount > VALIDATION.ActionsPerSecond
end

local function headPosition(character: Model): Vector3?
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	return nil
end

-- Linha de visão de `from` até `to` só contra o mapa. Devolve o multiplicador de dano:
-- 1 = livre; `penetration.damageMultiplier` = atravessou UMA cobertura fina; nil = bloqueado.
local function lineOfSight(from: Vector3, to: Vector3, penetration: WeaponConfig.Penetration?): number?
	-- Para um pouco antes do ponto de acerto: um acerto no pé não pode ser "bloqueado" pelo chão.
	local full = to - from
	if full.Magnitude < 0.3 then
		return 1
	end
	local delta = full.Unit * (full.Magnitude - 0.25)
	local forward = workspace:Raycast(from, delta, sightParams)
	if forward == nil then
		return 1
	end
	if penetration == nil then
		return nil
	end
	-- A primeira coisa no caminho é a mesma vista de trás para a frente? Então só há uma peça.
	local backward = workspace:Raycast(from + delta, -delta, sightParams)
	if backward == nil or backward.Instance ~= forward.Instance then
		return nil
	end
	local thickness = (backward.Position - forward.Position).Magnitude
	if thickness > penetration.maxThickness then
		return nil
	end
	return penetration.damageMultiplier
end

local function readFirePayload(raw: unknown, def: WeaponDef): CombatTypes.FirePayload?
	if typeof(raw) ~= "table" then
		return nil
	end
	local payload = raw :: { [any]: any }
	local origin = payload.origin
	local ends = payload.ends
	local hits = payload.hits
	if not ShotValidation.isFiniteVector(origin) or typeof(ends) ~= "table" or typeof(hits) ~= "table" then
		return nil
	end
	if #ends > def.pellets or #hits > def.pellets then
		return nil
	end
	local cleanEnds: { Vector3 } = {}
	for _, e in ends do
		if not ShotValidation.isFiniteVector(e) then
			return nil
		end
		table.insert(cleanEnds, e)
	end
	local cleanHits: { CombatTypes.FireHit } = {}
	local usedPellets: { [number]: boolean } = {}
	for _, h in hits do
		if typeof(h) ~= "table" then
			return nil
		end
		local part, position, pellet = h.part, h.position, h.pellet
		if typeof(part) ~= "Instance" or not (part :: Instance):IsA("BasePart") then
			return nil
		end
		if not ShotValidation.isFiniteVector(position) or typeof(pellet) ~= "number" then
			return nil
		end
		if pellet ~= math.floor(pellet) or pellet < 1 or pellet > def.pellets or usedPellets[pellet] then
			return nil
		end
		usedPellets[pellet] = true
		table.insert(cleanHits, { part = part :: BasePart, position = position :: Vector3, pellet = pellet })
	end
	return { origin = origin :: Vector3, ends = cleanEnds, hits = cleanHits }
end

-- Confere um acerto e devolve o alvo e o dano (nil = acerto recusado).
local function validateHit(
	shooter: Combatants.Combatant,
	def: WeaponDef,
	origin: Vector3,
	hit: CombatTypes.FireHit
): (Combatants.Combatant?, number)
	local target = Combatants.fromHitbox(hit.part)
	if target == nil or target == shooter or not target.alive then
		return nil, 0
	end
	if not Combatants.canDamage(shooter, target) then
		return nil, 0
	end
	local distance = (hit.position - origin).Magnitude
	if distance > def.range then
		return nil, 0
	end
	local fromCapsule =
		ShotValidation.distanceToCapsule(hit.position, target.hitbox.Position, HITBOX.Height, HITBOX.Radius)
	if fromCapsule > VALIDATION.HitPositionTolerance then
		return nil, 0
	end
	local multiplier = lineOfSight(origin, hit.position, def.penetration)
	if multiplier == nil then
		return nil, 0
	end
	return target, WeaponMath.pelletDamage(def, distance) * multiplier
end

local function applyHits(
	player: Player,
	shooter: Combatants.Combatant,
	weaponId: string,
	at: number,
	damageByTarget: { [Combatants.Combatant]: { damage: number, position: Vector3 } }
)
	for target, entry in damageByTarget do
		local result = Combatants.applyDamage(target, entry.damage, { player = player, weaponId = weaponId, at = at })
		if result and result.dealt > 0 then
			local hitData: CombatTypes.HitData = {
				position = entry.position,
				damage = result.dealt,
				shieldBroken = result.shieldBroken,
				knocked = result.knocked,
				toShield = result.toShield,
			}
			combatEvent:FireClient(player, "Hit", hitData)
			local victim = target.player
			if victim then
				local damaged: CombatTypes.DamagedData = { from = shooter.hitbox.Position }
				combatEvent:FireClient(victim, "Damaged", damaged)
			end
		end
	end
end

-- Ações ------------------------------------------------------------------------------------------

local function onFire(player: Player, pc: PlayerCombat, shooter: Combatants.Combatant, t: number, raw: unknown)
	local slot = pc.equipped
	local state = pc.guns[slot :: string]
	if state == nil then
		return
	end
	local def = state.def
	local payload = readFirePayload(raw, def)
	if payload == nil then
		return
	end

	local ok = WeaponState.fire(state, t, SLACK)
	local watch = exploitWatches[player]
	if watch then
		if ok then
			watch.accepted += 1
		end
		watch.firstT = watch.firstT or t
		watch.lastT = t
	end
	if not ok then
		sendSync(player, slot, state)
		return
	end

	local head = headPosition(shooter.model)
	if head == nil or (payload.origin - head).Magnitude > VALIDATION.MaxOriginDistance then
		return -- tiro gasto, mas sem dano: origem longe demais do personagem
	end

	local damageByTarget: { [Combatants.Combatant]: { damage: number, position: Vector3 } } = {}
	for _, hit in payload.hits do
		local target, damage = validateHit(shooter, def, payload.origin, hit)
		if target and damage > 0 then
			local entry = damageByTarget[target]
			if entry then
				entry.damage += damage
			else
				damageByTarget[target] = { damage = damage, position = hit.position }
			end
		end
	end
	applyHits(player, shooter, def.id, t, damageByTarget)

	-- Rastro do tiro para os outros jogadores (sem garantia de entrega; é só efeito)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			shotFx:FireClient(other, shooter.model, def.id, payload.origin, payload.ends)
		end
	end
end

local function onMelee(player: Player, pc: PlayerCombat, shooter: Combatants.Combatant, t: number, raw: unknown)
	if pc.equipped ~= "melee" or typeof(raw) ~= "table" then
		return
	end
	local payload = raw :: { [any]: any }
	local heavy = payload.heavy == true
	if not WeaponState.swing(pc.melee, heavy, t, SLACK) then
		return
	end
	local part = payload.part
	if typeof(part) ~= "Instance" then
		return -- golpe no ar
	end
	local target = Combatants.fromHitbox(part :: Instance)
	if target == nil or target == shooter or not target.alive or not Combatants.canDamage(shooter, target) then
		return
	end
	local head = headPosition(shooter.model)
	if head == nil then
		return
	end
	local melee = WeaponConfig.Melee
	local reach = ShotValidation.distanceToCapsule(head, target.hitbox.Position, HITBOX.Height, HITBOX.Radius)
	if reach > melee.range + VALIDATION.MeleeRangeTolerance then
		return
	end
	if lineOfSight(head, target.hitbox.Position, nil) == nil then
		return
	end
	local damage = if heavy then melee.heavyDamage else melee.damage
	applyHits(player, shooter, melee.id, t, { [target] = { damage = damage, position = target.hitbox.Position } })
end

local function onAction(player: Player, action: unknown, t: unknown, arg: unknown)
	local pc = players[player]
	if pc == nil or rateLimited(pc) then
		return
	end
	local shooter = Combatants.getByPlayer(player)
	if shooter == nil or not shooter.alive then
		return
	end
	local timeOk = ShotValidation.checkTime(t, workspace:GetServerTimeNow(), pc.lastActionT)
	if not timeOk then
		return
	end
	local at = t :: number
	pc.lastActionT = at
	for _, callback in activityCallbacks do
		callback(player)
	end

	if action == "Fire" then
		onFire(player, pc, shooter, at, arg)
	elseif action == "Melee" then
		onMelee(player, pc, shooter, at, arg)
	elseif action == "Equip" then
		if arg ~= "primary" and arg ~= "secondary" and arg ~= "melee" then
			return
		end
		local slot = arg :: Slot
		if slot == "melee" then
			pc.equipped = "melee"
			WeaponState.equipMelee(pc.melee, at)
		else
			local state = pc.guns[slot]
			if state == nil then
				return
			end
			pc.equipped = slot :: Slot
			WeaponState.equip(state, at)
		end
		updateWalkSpeed(player, pc)
		emitWeapon(player, "Equip", slot)
	elseif action == "Reload" then
		local state = pc.guns[pc.equipped]
		if state and WeaponState.startReload(state, at) then
			emitWeapon(player, "Reload", nil)
		end
	elseif action == "Alt" then
		local state = pc.guns[pc.equipped]
		if state and typeof(arg) == "boolean" then
			WeaponState.setAlt(state, arg)
			updateWalkSpeed(player, pc)
			emitWeapon(player, "Alt", state.alt)
		end
	elseif action == "Spin" then
		local state = pc.guns[pc.equipped]
		if state and typeof(arg) == "boolean" then
			WeaponState.setSpin(state, arg, at)
		end
	end
end

function CombatService.Init()
	actionEvent = Remotes.event("WeaponAction")
	combatEvent = Remotes.event("CombatEvent")
	shotFx = Remotes.unreliable("ShotFx")
end

function CombatService.Start()
	actionEvent.OnServerEvent:Connect(onAction)

	-- Arena de teste (F2): ao aparecer, armas novas com munição cheia (mantém as escolhidas).
	-- Na partida (F3) quem dá e tira as armas é o MatchService, a cada rodada.
	CharacterService.onSpawned(function(player: Player, _character: Model)
		if not CombatConfig.TestArena.Enabled then
			return
		end
		local previous = players[player]
		local loadout = if previous then previous.loadout else defaultLoadout()
		local pc = buildCombat(loadout)
		players[player] = pc
		sendLoadout(player, pc)
		updateWalkSpeed(player, pc)
	end)

	-- Abates: aviso "N KILL" para quem derrubou e poeira para todos.
	Combatants.onKnocked(function(target: Combatants.Combatant, source: Combatants.DamageSource?, report)
		local knocked: CombatTypes.KnockedData =
			{ position = target.hitbox.Position, teamId = target.teamId, island = target.island }
		combatEvent:FireAllClients("Knocked", knocked)

		local killer = source and source.player
		if killer == nil or killer == target.player then
			return
		end
		local kills = ((killer:GetAttribute(CombatNames.Attr.Kills) :: number?) or 0) + 1
		killer:SetAttribute(CombatNames.Attr.Kills, kills)
		local data: CombatTypes.KillData = {
			kills = kills,
			victimName = target.displayName,
			weaponId = if source then source.weaponId else "",
			seconds = report.seconds,
			shots = report.shots,
		}
		combatEvent:FireClient(killer, "Kill", data)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		players[player] = nil
		exploitWatches[player] = nil
		slows[player] = nil
	end)
end

return CombatService
