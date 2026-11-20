--!strict
-- [BOTS] Cérebro de um bot de preenchimento numa ilha (docs/BOTS.md). Joga como um jogador RUIM:
--   * anda pelo mapa (PathfindingService) procurando o inimigo e volta para dentro da zona;
--   * vê com campo de visão, paredes no meio contam e a Nuvem esconde;
--   * demora para reagir, a mira segue o alvo atrasada e com erro, atira em rajadas curtas e às
--     vezes fica parado no meio da troca de tiros (alvo fácil, pensando em quem joga no celular);
--   * recarrega, troca para a pistola, usa o corpo a corpo colado e as cartas da rodada.
-- O dano passa pelo mesmo registro dos jogadores (Combatants), com a fonte sem jogador; os clientes
-- veem o tiro pelo mesmo efeito (ShotFx) e quem leva o tiro vê de onde veio (CombatEvent "Damaged").

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local BotConfig = require(Shared.Config.BotConfig)
local BotRules = require(Shared.Bots.BotRules)
local CardConfig = require(Shared.Config.CardConfig)
local CardRules = require(Shared.Cards.CardRules)
local CardState = require(Shared.Cards.CardState)
local CardTypes = require(Shared.Cards.CardTypes)
local CombatNames = require(Shared.Combat.CombatNames)
local CombatTypes = require(Shared.Combat.CombatTypes)
local HealthMath = require(Shared.Combat.HealthMath)
local MapConfig = require(Shared.Config.MapConfig)
local MatchConfig = require(Shared.Config.MatchConfig)
local MatchTypes = require(Shared.Match.MatchTypes)
local Remotes = require(Shared.Remotes)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponMath = require(Shared.Combat.WeaponMath)
local WeaponState = require(Shared.Combat.WeaponState)
local WorldLayout = require(Shared.Match.WorldLayout)

local CardService = require(ServerScriptService.Combat.CardService)
local Combatants = require(ServerScriptService.Combat.Combatants)

type Combatant = Combatants.Combatant
type WeaponDef = WeaponConfig.WeaponDef

local SKILL = BotConfig.Skill
local MOVE = BotConfig.Movement
local CARD_NAMES = CardTypes.Names
local COS_HALF_FOV = math.cos(math.rad(SKILL.FieldOfViewDegrees / 2))
local FULL_HEALTH = HealthMath.total(HealthMath.full())
local TREMOR = CardConfig.get("card_tremor")
local TREMOR_SLOW = if TREMOR then TREMOR.params.SlowPercent else 0.5

type AgentCard = { id: string, def: CardConfig.CardDef, state: CardState.State }

export type Agent = {
	key: string,
	combatant: Combatant,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	head: BasePart,
	align: AlignOrientation,
	island: number,
	side: number,
	rng: Random,
	shotParams: RaycastParams,
	sightParams: RaycastParams,
	path: Path,
	onKill: (victim: Combatant) -> (),
	destroyed: boolean,
	-- Armas e cartas (só no combate)
	armed: boolean,
	guns: { [string]: WeaponState.State }, -- "primary" (pode faltar) e "secondary"
	equipped: string, -- "primary", "secondary" ou "melee"
	melee: WeaponState.MeleeState,
	cards: { AgentCard },
	combatStart: number,
	pistolDecidedFor: number?, -- recarga em que já decidiu trocar (ou não) para a pistola
	-- Alvo
	target: Combatant?,
	targetVisible: boolean,
	reactAt: number,
	aimPoint: Vector3?,
	lastSeenPos: Vector3?,
	lastSeenAt: number,
	shotsAtTarget: number,
	burstUntil: number,
	pauseUntil: number,
	nextTriggerAt: number,
	attacker: Combatant?,
	attackedAt: number,
	-- Movimento
	goal: Vector3?,
	goalKind: string,
	waypoints: { PathWaypoint }?,
	waypointIndex: number,
	pathAt: number,
	computing: boolean,
	wantsMove: boolean,
	strafeDir: number,
	strafeUntil: number,
	standing: boolean,
	progressPos: Vector3,
	progressAt: number,
	stuckCount: number,
	nextThinkAt: number,
	nextWanderAt: number,
	lastLook: Vector3?,
}

local BotAgent = {}

local combatEvent = Remotes.event("CombatEvent")
local shotFx = Remotes.unreliable("ShotFx")
local byCombatant: { [Combatant]: Agent } = {}

-- Ajudas -------------------------------------------------------------------------------------------

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return flat(a - b).Magnitude
end

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function positionOf(c: Combatant): Vector3
	return c.hitbox.Position
end

local function between(range: { Min: number, Max: number }, rng: Random): number
	return BotRules.between(range, rng)
end

local function tremored(agent: Agent, now: number): boolean
	local untilT = agent.model:GetAttribute(CARD_NAMES.TremorUntilAttr)
	return typeof(untilT) == "number" and now < untilT
end

local function currentDef(agent: Agent): WeaponDef?
	local state = agent.guns[agent.equipped]
	return if state then state.def else nil
end

local function updateSpeed(agent: Agent, now: number)
	local melee = agent.equipped == "melee"
	local speed = WeaponMath.walkSpeed(if agent.armed then currentDef(agent) else nil, false, agent.armed and melee)
	speed *= MOVE.SpeedMultiplier
	if tremored(agent, now) then
		speed *= 1 - TREMOR_SLOW
	end
	if math.abs(agent.humanoid.WalkSpeed - speed) > 0.01 then
		agent.humanoid.WalkSpeed = speed
	end
end

-- Arma na mão para os clientes (o mesmo atributo dos jogadores; combat/client/HeldWeapons desenha).
local function publishHeld(agent: Agent)
	local id: string? = nil
	if agent.armed then
		local def = currentDef(agent)
		id = if agent.equipped == "melee" then WeaponConfig.Melee.id elseif def then def.id else nil
	end
	if agent.model:GetAttribute(CombatNames.Attr.Held) ~= id then
		agent.model:SetAttribute(CombatNames.Attr.Held, id)
	end
end

-- Visão --------------------------------------------------------------------------------------------

local function smokeBetween(from: Vector3, to: Vector3): boolean
	for _, smoke in CollectionService:GetTagged(CARD_NAMES.SmokeTag) do
		if smoke:IsA("BasePart") then
			local radius = smoke:GetAttribute(CARD_NAMES.SmokeRadiusAttr)
			if typeof(radius) == "number" and CardRules.segmentHitsSphere(from, to, smoke.Position, radius) then
				return true
			end
		end
	end
	return false
end

local function canSee(agent: Agent, target: Combatant): boolean
	local from = agent.head.Position
	local to = positionOf(target)
	if workspace:Raycast(from, to - from, agent.sightParams) then
		return false
	end
	return not smokeBetween(from, to)
end

-- O inimigo mais perto que o bot percebe e enxerga agora (ou nil).
local function findTarget(agent: Agent, now: number): Combatant?
	local best: Combatant? = nil
	local bestDistance = math.huge
	local look = flat(agent.root.CFrame.LookVector)
	local recentlyAttacked = now - agent.attackedAt <= SKILL.AttackedAwarenessSeconds
	for _, c in Combatants.all() do
		if c == agent.combatant or not c.alive or not Combatants.canDamage(agent.combatant, c) then
			continue
		end
		local offset = positionOf(c) - agent.head.Position
		local distance = offset.Magnitude
		if distance > SKILL.SightRange or distance >= bestDistance then
			continue
		end
		local aware = distance <= SKILL.CloseAwareness
			or c == agent.target
			or (recentlyAttacked and c == agent.attacker)
		if not aware then
			local direction = flat(offset)
			aware = direction.Magnitude > 0.01
				and look.Magnitude > 0.01
				and look.Unit:Dot(direction.Unit) >= COS_HALF_FOV
		end
		if aware and canSee(agent, c) then
			best = c
			bestDistance = distance
		end
	end
	return best
end

-- Inimigo vivo mais perto na ilha, mesmo sem ver (para ir atrás dele).
local function nearestEnemy(agent: Agent): Combatant?
	local best: Combatant? = nil
	local bestDistance = math.huge
	for _, c in Combatants.all() do
		if c ~= agent.combatant and c.alive and Combatants.canDamage(agent.combatant, c) then
			local distance = (positionOf(c) - agent.root.Position).Magnitude
			if distance < bestDistance then
				best = c
				bestDistance = distance
			end
		end
	end
	return best
end

-- Movimento ----------------------------------------------------------------------------------------

local function faceMovement(agent: Agent)
	agent.align.Enabled = false
	agent.humanoid.AutoRotate = true
end

local function facePoint(agent: Agent, point: Vector3)
	local direction = flat(point - agent.root.Position)
	if direction.Magnitude < 0.1 then
		return
	end
	agent.humanoid.AutoRotate = false
	agent.align.CFrame = CFrame.lookAt(Vector3.zero, direction.Unit)
	agent.align.Enabled = true
end

local function moveTo(agent: Agent, point: Vector3)
	agent.wantsMove = flatDistance(point, agent.root.Position) > 1
	agent.humanoid:MoveTo(point)
end

local function stop(agent: Agent)
	agent.wantsMove = false
	agent.humanoid:MoveTo(agent.root.Position)
end

local GOAL_CHANGE = 6 -- studs: destino mudou de verdade (o caminho antigo não serve mais)

local function requestPath(agent: Agent, goal: Vector3, kind: string, now: number)
	local old = agent.goal
	if old == nil or agent.goalKind ~= kind or (old - goal).Magnitude > GOAL_CHANGE then
		agent.waypoints = nil -- até o caminho novo chegar, vai direto
	end
	agent.goal = goal
	agent.goalKind = kind
	if agent.computing then
		agent.pathAt = -math.huge -- refaz assim que o cálculo em andamento terminar
		return
	end
	agent.pathAt = now
	agent.computing = true
	local from = agent.root.Position
	task.spawn(function()
		local ok = pcall(function()
			agent.path:ComputeAsync(from, goal)
		end)
		agent.computing = false
		if agent.destroyed or agent.goal ~= goal then
			return
		end
		if ok and agent.path.Status == Enum.PathStatus.Success then
			agent.waypoints = agent.path:GetWaypoints()
			agent.waypointIndex = 1
		else
			agent.waypoints = nil -- sem caminho: vai em linha reta (e pula se travar)
		end
	end)
end

local function followPath(agent: Agent)
	local waypoints = agent.waypoints
	local goal = agent.goal
	if waypoints == nil or #waypoints == 0 then
		if goal then
			moveTo(agent, goal)
		end
		return
	end
	local index = agent.waypointIndex
	local waypoint: PathWaypoint? = waypoints[index]
	while waypoint and flatDistance(agent.root.Position, waypoint.Position) < MOVE.WaypointReach do
		index += 1
		waypoint = waypoints[index]
	end
	agent.waypointIndex = index
	if waypoint == nil then
		agent.waypoints = nil
		if goal then
			moveTo(agent, goal)
		end
		return
	end
	if waypoint.Action == Enum.PathWaypointAction.Jump then
		agent.humanoid.Jump = true
	end
	moveTo(agent, waypoint.Position)
end

-- Vai até `goal` pelo caminho; refaz o caminho quando o destino muda ou de tempos em tempos.
local function travel(agent: Agent, goal: Vector3, kind: string, now: number)
	local current = agent.goal
	if
		current == nil
		or agent.goalKind ~= kind
		or (current - goal).Magnitude > GOAL_CHANGE
		or now - agent.pathAt > MOVE.RepathSeconds
	then
		requestPath(agent, goal, kind, now)
	end
	followPath(agent)
end

-- Chão firme (a água do Porto e peças sem colisão não contam).
local function solid(hit: RaycastResult?): boolean
	if hit == nil or hit.Normal.Y <= 0.6 then
		return false
	end
	local part: Instance = hit.Instance
	return part:IsA("BasePart") and part.CanCollide
end

local function groundBelow(agent: Agent, point: Vector3): boolean
	return solid(workspace:Raycast(point + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), agent.sightParams))
end

-- Ponto no chão da ilha para andar sem rumo, puxando para o lado do inimigo.
local function roamPoint(agent: Agent): Vector3?
	local frame = WorldLayout.islandFrame(agent.island)
	local body = MapConfig.World.BodySize
	local towardEnemy = if agent.side == 1 then 1 else -1
	local floorY = MapConfig.World.IslandFloorY
	for _ = 1, 8 do
		local along = -0.2 + 1.1 * agent.rng:NextNumber() -- do meu lado até perto da base inimiga
		local x = towardEnemy * along * body.X / 2
		local z = (agent.rng:NextNumber() * 2 - 1) * 0.85 * body.Y / 2
		local top = frame * Vector3.new(x, 40, z)
		local hit = workspace:Raycast(top, Vector3.new(0, -80, 0), agent.sightParams)
		-- Chão da ilha ou plataforma baixa (nada de telhado nem água)
		if hit and solid(hit) and hit.Position.Y >= floorY - 1 and hit.Position.Y <= floorY + 10 then
			return hit.Position + Vector3.new(0, 3, 0)
		end
	end
	return nil
end

local function roam(agent: Agent, now: number)
	faceMovement(agent)
	local goal = agent.goal
	local reached = goal ~= nil and flatDistance(goal, agent.root.Position) < 4
	if goal == nil or agent.goalKind ~= "roam" or reached then
		local point = roamPoint(agent)
		if point == nil then
			stop(agent)
			return
		end
		requestPath(agent, point, "roam", now)
	elseif now - agent.pathAt > MOVE.RepathSeconds * 2 then
		requestPath(agent, goal, "roam", now)
	end
	followPath(agent)
end

-- Fora (ou quase) da zona: ponto lá dentro, na direção do centro da ilha.
local function zoneGoal(agent: Agent, now: number): Vector3?
	local elapsed = now - agent.combatStart
	if elapsed < MatchConfig.Zone.StartsAt - 5 then
		return nil
	end
	local radius = WorldLayout.zoneRadius(elapsed + 3) -- olha um pouco à frente
	local center = WorldLayout.islandCenter(agent.island)
	local offset = flat(agent.root.Position - center)
	if offset.Magnitude <= radius - MOVE.ZoneMargin then
		return nil
	end
	local inside = if offset.Magnitude > 0.1 then offset.Unit * radius * 0.4 else Vector3.zero
	return center + inside + Vector3.new(0, 3, 0)
end

-- Troca de tiros: fica de lado, chega perto ou se afasta conforme a arma; às vezes fica parado.
local function engageMove(agent: Agent, target: Combatant, now: number)
	local targetPos = positionOf(target)
	facePoint(agent, targetPos)
	local offset = flat(targetPos - agent.root.Position)
	local distance = offset.Magnitude
	local def = currentDef(agent)
	local category = if agent.equipped == "melee" then "Melee" elseif def then def.category else "Pistol"
	local preferred = MOVE.PreferredRange[category] or 20
	if distance > preferred + 8 then
		travel(agent, targetPos, "chase", now)
		return
	end
	agent.goal = nil
	agent.waypoints = nil
	if now >= agent.strafeUntil then
		agent.strafeUntil = now + between(MOVE.StrafeSeconds, agent.rng)
		agent.standing = agent.rng:NextNumber() < MOVE.StandStillChance
		agent.strafeDir = if agent.rng:NextNumber() < 0.5 then -1 else 1
	end
	if agent.standing or distance < 0.1 then
		stop(agent)
		return
	end
	local forward = offset.Unit
	local right = forward:Cross(Vector3.yAxis)
	local back = if distance < preferred - 6 then -forward * 4 else Vector3.zero
	local origin = agent.root.Position
	local point = origin + right * agent.strafeDir * MOVE.StrafeStuds + back
	local blocked = not groundBelow(agent, point) or workspace:Raycast(origin, point - origin, agent.sightParams) ~= nil
	if blocked then
		agent.strafeDir = -agent.strafeDir
		point = origin + right * agent.strafeDir * MOVE.StrafeStuds + back
	end
	moveTo(agent, point)
end

-- Preso (andando sem sair do lugar): pula; preso de novo, escolhe outro destino.
local function checkStuck(agent: Agent, now: number)
	if now - agent.progressAt < MOVE.StuckSeconds then
		return
	end
	local moved = flatDistance(agent.root.Position, agent.progressPos)
	if agent.wantsMove and moved < 1 then
		agent.humanoid.Jump = true
		agent.stuckCount += 1
		if agent.stuckCount >= 2 then
			agent.goal = nil
			agent.waypoints = nil
			agent.goalKind = ""
			agent.stuckCount = 0
		end
	else
		agent.stuckCount = 0
	end
	agent.progressPos = agent.root.Position
	agent.progressAt = now
end

-- Preparação: passeia dentro da base (a parede invisível segura).
local function wanderInBase(agent: Agent, now: number)
	faceMovement(agent)
	if now < agent.nextWanderAt then
		return
	end
	agent.nextWanderAt = now + between(MOVE.PrepWanderSeconds, agent.rng)
	local base = WorldLayout.baseFrame(agent.island, agent.side)
	local size = MapConfig.World.BaseSize
	local x = (agent.rng:NextNumber() * 2 - 1) * 0.3 * size.X / 2
	local z = (agent.rng:NextNumber() * 2 - 1) * 0.3 * size.Y / 2
	moveTo(agent, base * Vector3.new(x, 3, z))
end

-- Para onde olha (o parceiro que caiu espectar o bot, SpectateCamera).
local function publishLook(agent: Agent)
	local look = agent.root.CFrame.LookVector
	local aim = agent.aimPoint
	if agent.targetVisible and aim then
		local toAim = aim - agent.head.Position
		if toAim.Magnitude > 0.1 then
			look = toAim.Unit
		end
	end
	local last = agent.lastLook
	if last == nil or (last - look).Magnitude > 0.02 then
		agent.lastLook = look
		agent.model:SetAttribute(MatchTypes.Attr.Look, look)
	end
end

-- Dano ---------------------------------------------------------------------------------------------

-- Levou tiro: percebe quem atirou por um tempo, mesmo de costas, e vai olhar.
function BotAgent.alert(victim: Combatant, attacker: Combatant)
	local agent = byCombatant[victim]
	if agent == nil or attacker == victim then
		return
	end
	local now = workspace:GetServerTimeNow()
	agent.attacker = attacker
	agent.attackedAt = now
	if not agent.targetVisible then
		agent.lastSeenPos = positionOf(attacker)
		agent.lastSeenAt = now
	end
end

local function applyDamage(agent: Agent, victim: Combatant, amount: number, weaponId: string, now: number)
	local result = Combatants.applyDamage(victim, amount, { player = nil, weaponId = weaponId, at = now })
	if result == nil or result.dealt <= 0 then
		return
	end
	local victimPlayer = victim.player
	if victimPlayer then
		local damaged: CombatTypes.DamagedData = { from = agent.combatant.hitbox.Position }
		combatEvent:FireClient(victimPlayer, "Damaged", damaged)
	else
		BotAgent.alert(victim, agent.combatant)
	end
	if result.knocked then
		agent.onKill(victim)
	end
end

local function shoot(agent: Agent, target: Combatant, def: WeaponDef, now: number)
	local origin = agent.head.Position
	local aim = agent.aimPoint or positionOf(target)
	local toAim = aim - origin
	if toAim.Magnitude < 0.1 then
		return
	end
	local targetRoot = rootOf(target.model)
	local moving = flat(agent.root.AssemblyLinearVelocity).Magnitude > 2
	local errorDegrees = BotRules.aimErrorDegrees(SKILL, {
		distance = toAim.Magnitude,
		moving = moving,
		targetMoving = targetRoot ~= nil and flat(targetRoot.AssemblyLinearVelocity).Magnitude > 2,
		vsBot = target.player == nil,
		shotsAtTarget = agent.shotsAtTarget,
	})
	if tremored(agent, now) then
		errorDegrees += SKILL.TremorAimError
	end
	local aimDirection = WeaponMath.randomInCone(toAim.Unit, errorDegrees, agent.rng)
	local spread = WeaponMath.spreadDegrees(def, false, moving, 0)
	local directions = WeaponMath.shotDirections(def, false, aimDirection, spread, agent.rng)
	local ends: { Vector3 } = table.create(#directions)
	local damageByVictim: { [Combatant]: number } = {}
	for i, direction in directions do
		local hit = workspace:Raycast(origin, direction * def.range, agent.shotParams)
		if hit == nil then
			ends[i] = origin + direction * def.range
			continue
		end
		ends[i] = hit.Position
		local victim = Combatants.fromHitbox(hit.Instance)
		if victim and victim ~= agent.combatant and victim.alive and Combatants.canDamage(agent.combatant, victim) then
			local damage = WeaponMath.pelletDamage(def, (hit.Position - origin).Magnitude)
				* BotRules.damageMultiplier(SKILL, victim.player == nil)
			damageByVictim[victim] = (damageByVictim[victim] or 0) + damage
		end
	end
	for victim, damage in damageByVictim do
		applyDamage(agent, victim, damage, def.id, now)
	end
	-- Mesmo efeito do tiro de um jogador: rastro e som em todos os clientes
	shotFx:FireAllClients(agent.model, def.id, origin, ends)
end

-- Armas --------------------------------------------------------------------------------------------

local function equip(agent: Agent, slot: string, now: number)
	if agent.equipped == slot then
		return
	end
	if slot == "melee" then
		WeaponState.equipMelee(agent.melee, now)
	else
		local state = agent.guns[slot]
		if state == nil then
			return
		end
		WeaponState.equip(state, now)
	end
	agent.equipped = slot
	updateSpeed(agent, now)
	publishHeld(agent)
end

local function bestGun(agent: Agent): string
	return if agent.guns.primary then "primary" else "secondary"
end

local function stopSpin(agent: Agent, now: number)
	local state = agent.guns[agent.equipped]
	if state and state.spinStartedAt then
		WeaponState.setSpin(state, false, now)
	end
end

local function meleeStep(agent: Agent, target: Combatant, now: number)
	equip(agent, "melee", now)
	if now < agent.nextTriggerAt or not WeaponState.swing(agent.melee, false, now, 0) then
		return
	end
	local melee = WeaponConfig.Melee
	agent.nextTriggerAt = now + (1 / melee.swingsPerSecond) / SKILL.FireRateMultiplier
	if agent.rng:NextNumber() > SKILL.MeleeHitChance then
		return
	end
	applyDamage(agent, target, melee.damage * BotRules.damageMultiplier(SKILL, target.player == nil), melee.id, now)
end

-- Recarregando com o inimigo perto: às vezes saca a pistola (decide uma vez por recarga).
local function maybeSwitchToPistol(agent: Agent, state: WeaponState.State, distance: number, now: number)
	if agent.equipped ~= "primary" or agent.guns.secondary == nil then
		return
	end
	local reloadEndsAt = state.reloadEndsAt
	if reloadEndsAt == nil or agent.pistolDecidedFor == reloadEndsAt then
		return
	end
	agent.pistolDecidedFor = reloadEndsAt
	if distance < 25 and agent.rng:NextNumber() < SKILL.SwitchToPistolChance then
		equip(agent, "secondary", now)
	end
end

-- Cartas -------------------------------------------------------------------------------------------

local function useCards(agent: Agent, now: number)
	if #agent.cards == 0 then
		return
	end
	local target = agent.target
	local visible = agent.targetVisible and target ~= nil
	local health = HealthMath.total(agent.combatant.health) / FULL_HEALTH
	local low = health < BotConfig.Cards.LowHealth
	local toTarget = if target then positionOf(target) - agent.head.Position else nil
	for _, card in agent.cards do
		if not CardState.canUse(card.state, now) then
			continue
		end
		local want = false
		local direction: Vector3? = nil
		if card.id == "card_nuvem" then
			want = visible and low
			direction = if toTarget and toTarget.Magnitude > 0.1 then toTarget.Unit else nil
		elseif card.id == "card_impulso" then
			want = visible or agent.stuckCount > 0
		elseif card.id == "card_tremor" then
			local reach = card.def.params.Length * 0.9
			want = visible and toTarget ~= nil and flat(toTarget).Magnitude <= reach and math.abs(toTarget.Y) < 3
			direction = if toTarget and flat(toTarget).Magnitude > 0.1 then flat(toTarget).Unit else nil
		elseif card.id == "card_renascer" then
			want = visible and low
		end
		local chance = (BotConfig.Cards[card.id] or 0) * MOVE.ThinkSeconds
		if want and agent.rng:NextNumber() < chance and CardState.use(card.state, now) then
			CardService.castForNpc(agent.combatant, card.id, direction)
			return -- uma carta por vez
		end
	end
end

-- API ----------------------------------------------------------------------------------------------

function BotAgent.new(
	key: string,
	combatant: Combatant,
	island: number,
	side: number,
	rng: Random,
	onKill: (victim: Combatant) -> ()
): Agent?
	local model = combatant.model
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = rootOf(model)
	local head = model:FindFirstChild("Head")
	if humanoid == nil or root == nil or not (head and head:IsA("BasePart")) then
		return nil
	end

	-- Vira para o alvo enquanto anda de lado (o Roblox só vira para onde anda)
	local attachment = Instance.new("Attachment")
	attachment.Name = "BotFacing"
	attachment.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = "BotFacing"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = 1e6
	align.Responsiveness = 18
	align.Enabled = false
	align.Parent = root

	local shotParams = RaycastParams.new()
	shotParams.CollisionGroup = CombatNames.Groups.ShotRay
	shotParams.FilterType = Enum.RaycastFilterType.Exclude
	shotParams.FilterDescendantsInstances = { model }
	local sightParams = RaycastParams.new()
	sightParams.CollisionGroup = CombatNames.Groups.SightRay
	sightParams.FilterType = Enum.RaycastFilterType.Exclude
	sightParams.FilterDescendantsInstances = { model }

	local now = workspace:GetServerTimeNow()
	local agent: Agent = {
		key = key,
		combatant = combatant,
		model = model,
		humanoid = humanoid,
		root = root,
		head = head,
		align = align,
		island = island,
		side = side,
		rng = Random.new(rng:NextInteger(1, 2 ^ 30)),
		shotParams = shotParams,
		sightParams = sightParams,
		path = PathfindingService:CreatePath({
			AgentRadius = MOVE.AgentRadius,
			AgentHeight = MOVE.AgentHeight,
			AgentCanJump = true,
			WaypointSpacing = MOVE.WaypointSpacing,
		}),
		onKill = onKill,
		destroyed = false,
		armed = false,
		guns = {},
		equipped = "secondary",
		melee = WeaponState.newMelee(WeaponConfig.Melee),
		cards = {},
		combatStart = now,
		pistolDecidedFor = nil,
		target = nil,
		targetVisible = false,
		reactAt = math.huge,
		aimPoint = nil,
		lastSeenPos = nil,
		lastSeenAt = -math.huge,
		shotsAtTarget = 0,
		burstUntil = 0,
		pauseUntil = 0,
		nextTriggerAt = 0,
		attacker = nil,
		attackedAt = -math.huge,
		goal = nil,
		goalKind = "",
		waypoints = nil,
		waypointIndex = 1,
		pathAt = -math.huge,
		computing = false,
		wantsMove = false,
		strafeDir = 1,
		strafeUntil = 0,
		standing = false,
		progressPos = root.Position,
		progressAt = now,
		stuckCount = 0,
		-- Espalha os bots entre os quadros (nem todos pensam no mesmo quadro)
		nextThinkAt = now + rng:NextNumber() * MOVE.ThinkSeconds,
		nextWanderAt = now + rng:NextNumber() * 2,
		lastLook = nil,
	}
	byCombatant[combatant] = agent
	return agent
end

-- Começo do combate: armas da rodada (munição cheia) e cartas (cargas cheias).
function BotAgent.arm(
	agent: Agent,
	primary: string?,
	secondary: string,
	cards: { [string]: string },
	combatStart: number
)
	local guns: { [string]: WeaponState.State } = {}
	local primaryDef = if primary then WeaponConfig.get(primary) else nil
	if primaryDef then
		guns.primary = WeaponState.new(primaryDef)
	end
	local secondaryDef = WeaponConfig.get(secondary)
	if secondaryDef then
		guns.secondary = WeaponState.new(secondaryDef)
	end
	agent.guns = guns
	agent.equipped = bestGun(agent)
	agent.cards = {}
	for _, id in cards do
		local def = CardConfig.get(id)
		if def then
			table.insert(agent.cards, { id = id, def = def, state = CardState.new(def) })
		end
	end
	agent.combatStart = combatStart
	agent.armed = true
	agent.goal = nil
	agent.waypoints = nil
	updateSpeed(agent, combatStart)
	publishHeld(agent)
end

-- Decide (algumas vezes por segundo): o que vê, para onde anda, se usa carta.
function BotAgent.think(agent: Agent, now: number)
	if agent.destroyed or not agent.combatant.alive or agent.model.Parent == nil then
		return
	end
	updateSpeed(agent, now)
	if not agent.armed then
		wanderInBase(agent, now)
		publishLook(agent)
		return
	end

	-- Percepção
	local seen = findTarget(agent, now)
	if seen then
		if seen ~= agent.target or not agent.targetVisible then
			-- Alvo novo (ou que reapareceu): tempo de reação e mira começando longe
			agent.reactAt = now + between(SKILL.ReactionSeconds, agent.rng)
			if seen ~= agent.target then
				agent.shotsAtTarget = 0
			end
			local jitter =
				Vector3.new(agent.rng:NextNumber() - 0.5, agent.rng:NextNumber() - 0.5, agent.rng:NextNumber() - 0.5)
			agent.aimPoint = positionOf(seen) + jitter * 6
			agent.burstUntil = agent.reactAt + between(SKILL.BurstSeconds, agent.rng)
			agent.pauseUntil = agent.burstUntil + between(SKILL.PauseSeconds, agent.rng)
		end
		agent.target = seen
		agent.targetVisible = true
		agent.lastSeenPos = positionOf(seen)
		agent.lastSeenAt = now
	else
		agent.targetVisible = false
		local target = agent.target
		if target and (not target.alive or now - agent.lastSeenAt > SKILL.MemorySeconds) then
			agent.target = nil
		end
	end

	-- Movimento
	local zone = zoneGoal(agent, now)
	local target = agent.target
	local lastSeen = agent.lastSeenPos
	if zone then
		if agent.targetVisible and target then
			facePoint(agent, positionOf(target))
		else
			faceMovement(agent)
		end
		travel(agent, zone, "zone", now)
	elseif agent.targetVisible and target then
		engageMove(agent, target, now)
	elseif lastSeen and now - agent.lastSeenAt <= SKILL.MemorySeconds then
		faceMovement(agent)
		travel(agent, lastSeen, "chase", now)
		if flatDistance(lastSeen, agent.root.Position) < 3 then
			agent.lastSeenPos = nil -- chegou e não achou ninguém
		end
	else
		-- Muito tempo sem achar ninguém: vai atrás de um inimigo (como quem ouve os tiros)
		local prey = if now - agent.combatStart >= MOVE.HuntAfterSeconds then nearestEnemy(agent) else nil
		if prey then
			faceMovement(agent)
			travel(agent, positionOf(prey), "hunt", now)
		else
			roam(agent, now)
		end
	end
	checkStuck(agent, now)
	useCards(agent, now)
	publishLook(agent)
end

-- A cada quadro: mira atrasada e tiros (na cadência da arma × FireRateMultiplier, em rajadas).
function BotAgent.step(agent: Agent, now: number, dt: number)
	if agent.destroyed or not agent.armed or not agent.combatant.alive then
		return
	end
	local target = agent.target
	if target == nil or not agent.targetVisible or not target.alive then
		stopSpin(agent, now)
		return
	end
	local targetPos = positionOf(target)
	local aim = agent.aimPoint or targetPos
	agent.aimPoint = aim:Lerp(targetPos, 1 - math.exp(-SKILL.TrackSpeed * dt))
	if now < agent.reactAt then
		return
	end
	-- Rajadas: atira um tempo, para um tempo
	if now >= agent.burstUntil then
		if now < agent.pauseUntil then
			stopSpin(agent, now)
			return
		end
		agent.burstUntil = now + between(SKILL.BurstSeconds, agent.rng)
		agent.pauseUntil = agent.burstUntil + between(SKILL.PauseSeconds, agent.rng)
	end

	local distance = (targetPos - agent.head.Position).Magnitude
	if distance <= SKILL.MeleeRange then
		meleeStep(agent, target, now)
		return
	end
	if agent.equipped == "melee" then
		equip(agent, bestGun(agent), now)
	end
	local state = agent.guns[agent.equipped]
	if state == nil then
		return
	end
	WeaponState.update(state, now)
	if state.reloadEndsAt ~= nil then
		maybeSwitchToPistol(agent, state, distance, now)
		return
	end
	if state.ammo <= 0 then
		if agent.equipped == "secondary" and agent.guns.primary then
			equip(agent, "primary", now) -- pistola vazia: volta para a primária (que recarrega)
			local primary = agent.guns.primary
			if primary and primary.ammo <= 0 then
				WeaponState.startReload(primary, now)
			end
		else
			WeaponState.startReload(state, now)
		end
		return
	end
	if state.def.spinUpTime then
		WeaponState.setSpin(state, true, now)
	end
	if distance > state.def.range or now < agent.nextTriggerAt then
		return
	end
	if not WeaponState.fire(state, now, 0) then
		return
	end
	agent.nextTriggerAt = now + (1 / state.def.fireRate) / SKILL.FireRateMultiplier
	shoot(agent, target, state.def, now)
	agent.shotsAtTarget += 1
	if state.ammo <= 0 then
		WeaponState.startReload(state, now)
	end
end

function BotAgent.destroy(agent: Agent)
	agent.destroyed = true
	agent.armed = false
	if byCombatant[agent.combatant] == agent then
		byCombatant[agent.combatant] = nil
	end
end

return BotAgent
