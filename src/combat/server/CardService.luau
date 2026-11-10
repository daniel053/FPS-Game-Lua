--!strict
-- Cartas no combate (FASES F4, GDD 8). O servidor é a autoridade:
--   * guarda as cartas de cada jogador na rodada (a básica escolhida e, a partir da 4ª rodada, a ult);
--   * recusa carta que o jogador não tem nesta rodada, sem carga, em recarga, fora do combate,
--     derrubado, com horário inválido ou pedidos demais;
--   * faz o efeito de cada carta.
--
-- Efeitos (GDD 8.4):
--   Nuvem (C)    -> o servidor calcula o arco da bola contra o mapa e cria a nuvem onde ela bate;
--   Impulso (Q)  -> o cliente aplica o salto na hora (ele controla o próprio corpo no Roblox);
--                   o servidor só gasta a carga e confere a recarga;
--   Tremor (E)   -> onda no chão à frente; quem está no chão e na frente (sem parede no meio) fica
--                   lento (CombatService.applySlow) e com a mira tremida (atributo TremorUntil);
--   Renascer (X) -> marca no chão; caindo nos 8 s, volta à marca com vida e escudo cheios
--                   (guarda de queda do Combatants); passando os 8 s, volta mantendo a vida.
-- Quem chama arm/disarm/clearWorld é o MatchService (começo e fim do combate).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CardConfig = require(Shared.Config.CardConfig)
local CardRules = require(Shared.Cards.CardRules)
local CardState = require(Shared.Cards.CardState)
local CardTypes = require(Shared.Cards.CardTypes)
local CombatNames = require(Shared.Combat.CombatNames)
local Remotes = require(Shared.Remotes)
local ShotValidation = require(Shared.Combat.ShotValidation)
local Theme = require(Shared.Config.Theme)

local ActivityService = require(script.Parent.ActivityService)
local CombatService = require(script.Parent.CombatService)
local Combatants = require(script.Parent.Combatants)

type CardKey = string -- "C", "Q", "E" ou "X" (Types.CardKey); string por causa do verificador de tipos
type CardDef = CardConfig.CardDef

local NAMES = CardTypes.Names
local THROW_STEP = 1 / 30

type Armed = {
	round: number,
	cards: CardRules.RoundCards, -- valendo agora (tecla -> ID)
	ultId: string?, -- a ult do jogador (aparece com cadeado antes da 4ª rodada)
	states: { [string]: CardState.State }, -- por tecla
	active: boolean,
	lastActionT: number,
	rateStart: number,
	rateCount: number,
}

type Renascer = { mark: CFrame, endsAt: number, part: BasePart, token: {} }

type Watch = { accepted: number, refused: number }

local CardService = {}

local actionEvent: RemoteEvent
local cardEvent: RemoteEvent
local fxEvent: RemoteEvent
local worldFolder: Folder

local armed: { [Player]: Armed } = {}
local renascers: { [Player]: Renascer } = {}
local watches: { [Player]: Watch } = {}
local roundToken = 0 -- muda a cada fim de rodada: efeitos atrasados da rodada anterior não acontecem

local sightParams = RaycastParams.new()
sightParams.CollisionGroup = CombatNames.Groups.SightRay
sightParams.FilterType = Enum.RaycastFilterType.Exclude
sightParams.FilterDescendantsInstances = {}

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

-- Estado para o cliente ----------------------------------------------------------------------------

local function views(a: Armed): { CardTypes.CardView }
	local list: { CardTypes.CardView } = {}
	local now = serverNow()
	for key, id in a.cards do
		local state = a.states[key]
		CardState.update(state, now)
		table.insert(list, {
			key = key :: CardKey,
			id = id,
			charges = state.charges,
			maxCharges = state.maxCharges,
			rechargeAt = state.rechargeAt,
			locked = false,
		})
	end
	-- Ult ainda travada: aparece com cadeado (ESTILO T6)
	if a.ultId and a.cards[CardConfig.UltKey] == nil then
		table.insert(list, {
			key = CardConfig.UltKey :: string,
			id = a.ultId,
			charges = 0,
			maxCharges = CardConfig.UltUsesPerRound,
			rechargeAt = nil,
			locked = true,
		})
	end
	return list
end

local function sendCards(player: Player)
	local a = armed[player]
	local data: CardTypes.CardsData = {
		cards = if a then views(a) else {},
		active = a ~= nil and a.active,
	}
	cardEvent:FireClient(player, "Cards", data)
end

-- Ajudas -------------------------------------------------------------------------------------------

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Distância do centro do corpo até os pés.
local function feetOffset(model: Model): number
	local root = rootOf(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil then
		return 3
	end
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	return 2 + root.Size.Y / 2
end

local function effectPart(name: string, shape: Enum.PartType): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	return part
end

-- Nuvem (C) ----------------------------------------------------------------------------------------

local function spawnSmoke(position: Vector3, def: CardDef)
	local radius = def.params.Radius
	local smoke = effectPart("Nuvem", Enum.PartType.Ball)
	smoke.Size = Vector3.one * radius * 2
	smoke.Position = position
	smoke.Color = Theme.Cards.Smoke
	smoke.Transparency = Theme.SmokeTransparency
	smoke:SetAttribute(NAMES.SmokeRadiusAttr, radius)
	CollectionService:AddTag(smoke, NAMES.SmokeTag)
	smoke.Parent = worldFolder
	task.delay(def.params.Duration, function()
		smoke:Destroy()
	end)
end

local function useNuvem(_player: Player, combatant: Combatants.Combatant, direction: Vector3?, def: CardDef)
	local head = combatant.model:FindFirstChild("Head")
	local root = rootOf(combatant.model)
	if not (head and head:IsA("BasePart")) or root == nil then
		return
	end
	local dir = direction or root.CFrame.LookVector
	local p = def.params
	local origin = head.Position
	local velocity = dir * p.ThrowSpeed + Vector3.new(0, p.ThrowLift, 0)
	local gravity = workspace.Gravity
	local path = CardRules.throwPath(origin, velocity, gravity, p.MaxFlightSeconds, THROW_STEP)
	local impact = path[#path]
	local flight = p.MaxFlightSeconds
	for i = 2, #path do
		local from = path[i - 1]
		local segment = path[i] - from
		local hit = workspace:Raycast(from, segment, sightParams)
		if hit then
			local fraction = (hit.Position - from).Magnitude / math.max(segment.Magnitude, 1e-6)
			flight = (i - 2 + fraction) * THROW_STEP
			impact = hit.Position + hit.Normal * 0.5
			if hit.Normal.Y > 0.7 then
				-- Caiu no chão: sobe o centro para a nuvem cobrir uma pessoa em pé por inteiro
				impact += Vector3.new(0, p.Radius * 0.35, 0)
			end
			break
		end
	end
	local fx: CardTypes.NuvemThrowData = { origin = origin, velocity = velocity, flight = flight, gravity = gravity }
	fxEvent:FireAllClients("NuvemThrow", fx)
	local token = roundToken
	task.delay(flight, function()
		if token == roundToken then
			spawnSmoke(impact, def)
		end
	end)
end

-- Tremor (E) ---------------------------------------------------------------------------------------

local function isGrounded(model: Model, check: number): boolean
	local root = rootOf(model)
	if root == nil then
		return false
	end
	if root.Anchored then
		return true -- jogador de teste (alvo parado no chão)
	end
	local params = RaycastParams.new()
	params.CollisionGroup = CombatNames.Groups.SightRay
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	return workspace:Raycast(root.Position, Vector3.new(0, -check, 0), params) ~= nil
end

local function hitByTremor(target: Combatants.Combatant, def: CardDef)
	local p = def.params
	local untilT = serverNow() + p.DebuffDuration
	target.model:SetAttribute(NAMES.TremorUntilAttr, untilT)
	local victim = target.player
	if victim then
		CombatService.applySlow(victim, p.SlowPercent, p.DebuffDuration)
		local data: CardTypes.TremoredData = { untilT = untilT }
		cardEvent:FireClient(victim, "Tremored", data)
	end
	if p.Damage > 0 then
		Combatants.applyDamage(target, p.Damage, { player = nil, weaponId = def.id, at = nil })
	end
end

local function useTremor(_player: Player, combatant: Combatants.Combatant, direction: Vector3?, def: CardDef)
	local root = rootOf(combatant.model)
	if root == nil then
		return
	end
	local p = def.params
	local look = direction or root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	local forward = flat.Unit
	local feet = root.Position - Vector3.new(0, feetOffset(combatant.model), 0)

	-- Não atravessa paredes: a onda para na primeira parede à frente (na altura da cintura)
	local length = p.Length
	local wall = workspace:Raycast(root.Position, forward * p.Length, sightParams)
	if wall then
		length = (wall.Position - root.Position).Magnitude
	end

	local fx: CardTypes.TremorWaveData =
		{ origin = feet, direction = forward, length = length, width = p.Width, speed = p.WaveSpeed }
	fxEvent:FireAllClients("TremorWave", fx)

	local token = roundToken
	for _, target in Combatants.all() do
		if target == combatant or not target.alive or not Combatants.canDamage(combatant, target) then
			continue
		end
		local targetRoot = rootOf(target.model)
		if targetRoot == nil then
			continue
		end
		local targetFeet = targetRoot.Position - Vector3.new(0, feetOffset(target.model), 0)
		local inside, along = CardRules.inWave(feet, forward, length, p.Width, p.GroundTolerance, targetFeet)
		if not inside then
			continue
		end
		-- Parede no meio (quina, cobertura entre os dois)?
		if workspace:Raycast(root.Position, targetRoot.Position - root.Position, sightParams) then
			continue
		end
		task.delay(along / p.WaveSpeed, function()
			-- Só quem ainda está no chão quando a onda passa (GDD 8.4: "quem está no chão")
			if token == roundToken and target.alive and isGrounded(target.model, p.GroundedCheck) then
				hitByTremor(target, def)
			end
		end)
	end
end

-- Renascer (X) -------------------------------------------------------------------------------------

local function sendRenascer(player: Player, endsAt: number?, revived: boolean?)
	local data: CardTypes.RenascerData = { endsAt = endsAt, revived = revived }
	cardEvent:FireClient(player, "Renascer", data)
end

local function cancelRenascer(player: Player)
	local r = renascers[player]
	if r == nil then
		return
	end
	renascers[player] = nil
	r.part:Destroy()
	sendRenascer(player, nil, false)
end

-- Volta à marca. `revived` = caiu na janela (vida e escudo cheios); senão mantém a vida (fim dos 8 s).
local function finishRenascer(player: Player, revived: boolean, def: CardDef)
	local r = renascers[player]
	if r == nil then
		return
	end
	renascers[player] = nil
	r.part:Destroy()
	local combatant = Combatants.getByPlayer(player)
	local character = player.Character
	if combatant == nil or character == nil then
		sendRenascer(player, nil, false)
		return
	end
	if revived or CardConfig.RenascerReturnOnExpire then
		local root = rootOf(character)
		local from = if root then root.Position else r.mark.Position
		character:PivotTo(r.mark)
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
		local fx: CardTypes.RenascerReturnData = { from = from, to = r.mark.Position }
		fxEvent:FireAllClients("RenascerReturn", fx)
	end
	if revived then
		Combatants.revive(combatant, def.params.ReturnProtection)
	end
	sendRenascer(player, nil, revived)
end

local function useRenascer(player: Player, combatant: Combatants.Combatant, _direction: Vector3?, def: CardDef)
	local root = rootOf(combatant.model)
	if root == nil then
		return
	end
	cancelRenascer(player)
	local p = def.params
	local feet = root.Position - Vector3.new(0, feetOffset(combatant.model) - 0.05, 0)
	local mark = effectPart("RenascerMarca", Enum.PartType.Cylinder)
	mark.Size = Vector3.new(0.15, 4, 4)
	mark.CFrame = CFrame.new(feet) * CFrame.Angles(0, 0, math.pi / 2)
	mark.Material = Enum.Material.Neon -- brilho permitido só em efeito de carta (ESTILO 2.6)
	mark.Color = Theme.Cards.card_renascer
	mark.Transparency = Theme.CardFxTransparency
	CollectionService:AddTag(mark, NAMES.MarkTag)
	mark.Parent = worldFolder

	local token = {}
	local endsAt = serverNow() + p.Window
	-- Guarda a posição e para onde o jogador olhava
	renascers[player] = { mark = root.CFrame, endsAt = endsAt, part = mark, token = token }
	sendRenascer(player, endsAt, nil)
	task.delay(p.Window, function()
		local r = renascers[player]
		if r and r.token == token then
			finishRenascer(player, false, def)
		end
	end)
end

-- Pedidos ------------------------------------------------------------------------------------------

type Effect = (player: Player, combatant: Combatants.Combatant, direction: Vector3?, def: CardDef) -> ()

local EFFECTS: { [string]: Effect } = {
	card_nuvem = useNuvem,
	card_impulso = function() end, -- o salto é aplicado pelo cliente; aqui só a carga
	card_tremor = useTremor,
	card_renascer = useRenascer,
}

local function refuse(player: Player)
	local watch = watches[player]
	if watch then
		watch.refused += 1
	end
	sendCards(player) -- corrige o que o cliente achou que tinha
end

local function rateLimited(a: Armed): boolean
	local now = os.clock()
	if now - a.rateStart >= 1 then
		a.rateStart = now
		a.rateCount = 0
	end
	a.rateCount += 1
	return a.rateCount > CardConfig.ActionsPerSecond
end

local function onAction(player: Player, action: unknown, key: unknown, t: unknown, arg: unknown)
	if action ~= "Use" then
		return
	end
	local a = armed[player]
	if a == nil or not a.active then
		refuse(player)
		return
	end
	if rateLimited(a) then
		refuse(player)
		return
	end
	if typeof(key) ~= "string" then
		refuse(player)
		return
	end
	local id = a.cards[key :: CardKey]
	local def = if id then CardConfig.get(id) else nil
	local state = a.states[key :: string]
	if def == nil or state == nil then
		refuse(player) -- carta que não escolheu (ou ult ainda travada)
		return
	end
	local combatant = Combatants.getByPlayer(player)
	if combatant == nil or not combatant.alive then
		refuse(player)
		return
	end
	if not ShotValidation.checkTime(t, serverNow(), a.lastActionT) then
		refuse(player)
		return
	end
	local at = t :: number
	if not CardState.use(state, at) then
		refuse(player) -- sem carga, em recarga ou rápido demais
		return
	end
	a.lastActionT = at
	local watch = watches[player]
	if watch then
		watch.accepted += 1
	end
	ActivityService.markActive(player)
	local effect = EFFECTS[def.id]
	if effect then
		-- Um erro no efeito não pode derrubar o servidor nem devolver a carga (já foi gasta).
		local ok, err = pcall(effect :: any, player, combatant, CardRules.readDirection(arg), def)
		if not ok then
			warn(`[Cartas] Erro no efeito de {def.id}: {err}`)
		end
	end
	sendCards(player)
end

-- API para o MatchService ---------------------------------------------------------------------------

-- Começo do combate: cartas da rodada com as cargas cheias.
function CardService.arm(player: Player, basicId: string?, ultId: string?, round: number)
	local cards = CardRules.roundCards(basicId, ultId, round)
	local states: { [string]: CardState.State } = {}
	for key, id in cards do
		local def = CardConfig.get(id)
		if def then
			states[key] = CardState.new(def)
		end
	end
	armed[player] = {
		round = round,
		cards = cards,
		ultId = ultId,
		states = states,
		active = true,
		lastActionT = -math.huge,
		rateStart = 0,
		rateCount = 0,
	}
	sendCards(player)
end

-- Fora do combate (mirante, fim da rodada, derrubado): sem cartas, marca do Renascer some.
function CardService.disarm(player: Player)
	cancelRenascer(player)
	if armed[player] then
		armed[player] = nil
		sendCards(player)
	end
end

-- Fim da rodada: nuvens e marcas somem; efeitos atrasados (nuvem no ar, onda andando) não acontecem.
function CardService.clearWorld()
	roundToken += 1
	for _, child in worldFolder:GetChildren() do
		child:Destroy()
	end
	for _, combatant in Combatants.all() do
		combatant.model:SetAttribute(NAMES.TremorUntilAttr, nil)
	end
end

-- Painel de teste: cargas cheias e recargas zeradas.
function CardService.devRefill(player: Player): boolean
	local a = armed[player]
	if a == nil then
		return false
	end
	for _, state in a.states do
		CardState.resetRound(state)
	end
	sendCards(player)
	return true
end

-- Painel de teste: conta os pedidos aceitos e recusados até `devWatchEnd`.
function CardService.devWatchStart(player: Player)
	watches[player] = { accepted = 0, refused = 0 }
end

function CardService.devWatchEnd(player: Player): (number, number)
	local watch = watches[player]
	watches[player] = nil
	if watch == nil then
		return 0, 0
	end
	return watch.accepted, watch.refused
end

function CardService.isArmed(player: Player): boolean
	return armed[player] ~= nil
end

-- Ciclo de vida ------------------------------------------------------------------------------------

function CardService.Init()
	actionEvent = Remotes.event("CardAction")
	cardEvent = Remotes.event("CardEvent")
	fxEvent = Remotes.event("CardFx")
	local existing = workspace:FindFirstChild(NAMES.WorldFolder)
	if existing and existing:IsA("Folder") then
		worldFolder = existing
	else
		worldFolder = Instance.new("Folder")
		worldFolder.Name = NAMES.WorldFolder
		worldFolder.Parent = workspace
	end
end

function CardService.Start()
	actionEvent.OnServerEvent:Connect(onAction)

	-- Renascer: caiu dentro da janela -> volta à marca com vida e escudo cheios.
	Combatants.setKnockGuard(function(target: Combatants.Combatant): boolean
		local player = target.player
		if player == nil or renascers[player] == nil then
			return false
		end
		local a = armed[player]
		local id = a and a.cards[CardConfig.UltKey]
		local def = if id then CardConfig.get(id) else nil
		if def == nil then
			return false
		end
		finishRenascer(player, true, def)
		return true
	end)

	-- Derrubado de verdade: sem cartas até a próxima rodada.
	Combatants.onKnocked(function(target: Combatants.Combatant)
		local player = target.player
		if player then
			CardService.disarm(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		cancelRenascer(player)
		armed[player] = nil
		watches[player] = nil
	end)
end

return CardService
