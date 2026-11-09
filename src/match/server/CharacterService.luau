--!strict
-- Personagem base (GDD 3.2 e 3.3): todos com o mesmo corpo de blocos, sem o avatar do jogador,
-- hitbox única em cápsula (sem cabeça), cor da equipe numa faixa em cada braço e no capacete.
-- Também cuida de aparecer, ser derrubado e voltar (na arena de teste da F2).

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CharacterConfig = require(Shared.Config.CharacterConfig)
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local TeamColors = require(Shared.Config.TeamColors)
local Theme = require(Shared.Config.Theme)

local Combatants = require(script.Parent.Combatants)
local TeamService = require(script.Parent.TeamService)

local GROUPS = CombatNames.Groups
local HITBOX = CombatConfig.Hitbox
local BODY = CharacterConfig.BaseBody

type SpawnedCallback = (player: Player, character: Model) -> ()
type SpawnProvider = (teamId: string) -> CFrame
type LostCallback = (player: Player) -> ()

-- Onde o jogador entra no combate (partida): dupla e ilha.
export type CombatPlacement = { teamId: string, island: number?, protectSeconds: number? }

local BOTS_FOLDER = "MatchBots"

local CharacterService = {}

local spawnedCallbacks: { SpawnedCallback } = {}
local lostCallbacks: { LostCallback } = {}
local pendingRespawn: { [Player]: boolean } = {}
local spawnProvider: SpawnProvider = function(_teamId: string): CFrame
	return CFrame.new(0, 5, 0)
end

-- Grupos de colisão: os tiros passam pelo corpo e só acertam a hitbox; a visão só bate no mapa.
local function setupCollisionGroups()
	for _, name in { GROUPS.Body, GROUPS.Hitbox, GROUPS.ShotRay, GROUPS.SightRay } do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	for _, other in { "Default", GROUPS.Body, GROUPS.Hitbox, GROUPS.SightRay } do
		PhysicsService:CollisionGroupSetCollidable(GROUPS.Hitbox, other, false)
	end
	PhysicsService:CollisionGroupSetCollidable(GROUPS.Hitbox, GROUPS.ShotRay, true)
	PhysicsService:CollisionGroupSetCollidable(GROUPS.Body, GROUPS.ShotRay, false)
	PhysicsService:CollisionGroupSetCollidable(GROUPS.Body, GROUPS.SightRay, false)
end

-- Corpo base: blocos padrão do Roblox, cinza claro com pernas escuras. Nenhum acessório nem roupa.
function CharacterService.baseDescription(bodyColor: Color3?): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	local body = bodyColor or Theme.Combat.BodyNeutral
	description.HeadColor = body
	description.TorsoColor = body
	description.LeftArmColor = body
	description.RightArmColor = body
	description.LeftLegColor = Theme.Combat.BodyDark
	description.RightLegColor = Theme.Combat.BodyDark
	return description
end

local function firstPart(model: Model, names: { string }): BasePart?
	for _, name in names do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function makeColorPart(name: string, size: Vector3, cframe: CFrame, anchor: BasePart, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.CollisionGroup = GROUPS.Body
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	return part
end

-- Faixa nos dois braços + capacete na cor da equipe [DECIDIDO]. Atualiza a cor se já existirem.
function CharacterService.applyTeamColor(model: Model, color: Color3)
	local existing = model:FindFirstChild(CombatNames.TeamBandName)
	if existing then
		for _, part in existing:GetChildren() do
			if part:IsA("BasePart") then
				part.Color = color
			end
		end
		return
	end

	local folder = Instance.new("Model")
	folder.Name = CombatNames.TeamBandName

	for _, names in { { "RightUpperArm", "Right Arm" }, { "LeftUpperArm", "Left Arm" } } do
		local arm = firstPart(model, names)
		if arm then
			local size = Vector3.new(arm.Size.X + 0.08, BODY.ArmBandHeight, arm.Size.Z + 0.08)
			local offset = arm.Size.Y / 2 - BODY.ArmBandHeight / 2 - 0.1
			makeColorPart("ArmBand", size, arm.CFrame * CFrame.new(0, offset, 0), arm, color).Parent = folder
		end
	end

	local head = firstPart(model, { "Head" })
	if head then
		local size = Vector3.new(head.Size.X + 0.12, BODY.HelmetHeight, head.Size.Z + 0.12)
		local offset = head.Size.Y / 2 - BODY.HelmetHeight / 2 + 0.12
		makeColorPart("Helmet", size, head.CFrame * CFrame.new(0, offset, 0), head, color).Parent = folder
	end

	folder.Parent = model
end

-- Hitbox única em cápsula (cilindro em pé), igual para todos, presa ao HumanoidRootPart.
function CharacterService.attachHitbox(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid) then
		return nil
	end
	local old = model:FindFirstChild(CombatNames.HitboxName)
	if old then
		old:Destroy()
	end

	-- Distância dos pés ao centro do HumanoidRootPart
	local feetToRoot = if humanoid.RigType == Enum.HumanoidRigType.R15
		then humanoid.HipHeight + root.Size.Y / 2
		else 2 + root.Size.Y / 2

	local hitbox = Instance.new("Part")
	hitbox.Name = CombatNames.HitboxName
	hitbox.Shape = Enum.PartType.Cylinder
	hitbox.Size = Vector3.new(HITBOX.Height, HITBOX.Radius * 2, HITBOX.Radius * 2) -- o eixo do cilindro é X
	hitbox.CFrame = root.CFrame * CFrame.new(0, HITBOX.Height / 2 - feetToRoot, 0) * CFrame.Angles(0, 0, math.pi / 2)
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = true
	hitbox.Massless = true
	hitbox.CastShadow = false
	hitbox.CollisionGroup = GROUPS.Hitbox
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = hitbox
	weld.Parent = hitbox
	hitbox.Parent = model
	return hitbox
end

-- Corpo no grupo "CharacterBody" (os tiros atravessam; só a hitbox recebe).
function CharacterService.setBodyGroup(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= CombatNames.HitboxName then
			descendant.CollisionGroup = GROUPS.Body
		end
	end
end

local function setupHumanoid(humanoid: Humanoid)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- o nome do parceiro é do cliente (GDD 7.6)
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = CharacterConfig.Movement.WalkSpeed
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = if CharacterConfig.Movement.CanJump then CharacterConfig.Movement.JumpHeight else 0
end

function CharacterService.setSpawnProvider(provider: SpawnProvider)
	spawnProvider = provider
end

function CharacterService.onSpawned(callback: SpawnedCallback)
	table.insert(spawnedCallbacks, callback)
end

-- Personagem perdido fora do combate (caiu, botão de reiniciar do Roblox) na partida.
function CharacterService.onLost(callback: LostCallback)
	table.insert(lostCallbacks, callback)
end

local function autoMode(): boolean
	return CombatConfig.TestArena.Enabled
end

-- Cria o personagem base do jogador (sem colocar no mundo nem registrar para combate).
local function createCharacter(player: Player): Model?
	local ok, err = pcall(function()
		player:LoadCharacterWithHumanoidDescriptionAsync(CharacterService.baseDescription())
	end)
	if not ok then
		warn(`[Personagem] Falha ao criar o personagem de {player.Name}: {err}`)
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or humanoid == nil then
		return nil
	end
	setupHumanoid(humanoid)
	CharacterService.setBodyGroup(character)
	local teamId = TeamService.get(player)
	if teamId then
		CharacterService.applyTeamColor(character, TeamColors.getColor(teamId))
	end
	if CharacterService.attachHitbox(character) == nil then
		warn(`[Personagem] Personagem de {player.Name} sem HumanoidRootPart`)
		return nil
	end

	humanoid.Died:Connect(function()
		-- Caiu para fora do mapa ou o Roblox matou o personagem: conta como derrubado sem atacante.
		local combatant = Combatants.get(character)
		if combatant then
			Combatants.knockWithoutSource(combatant)
		elseif not autoMode() and player.Character == character then
			character:Destroy()
			for _, callback in lostCallbacks do
				task.spawn(callback, player)
			end
		end
	end)
	character.Destroying:Connect(function()
		Combatants.unregister(character)
	end)
	return character
end

local function registerCombatant(player: Player, character: Model, placement: CombatPlacement): Combatants.Combatant?
	local hitbox = character:FindFirstChild(CombatNames.HitboxName)
	if not (hitbox and hitbox:IsA("BasePart")) then
		return nil
	end
	return Combatants.register(character, hitbox, {
		player = player,
		teamId = placement.teamId,
		island = placement.island,
		displayName = player.DisplayName,
		protectSeconds = placement.protectSeconds or CombatConfig.SpawnProtectionSeconds,
	})
end

-- Arena de teste (F2): nasce, registra e volta 3 s depois de derrubado.
local function spawnPlayer(player: Player)
	pendingRespawn[player] = nil
	if player.Parent == nil then
		return
	end
	local teamId = TeamService.get(player) or TeamService.assignBalanced(player)
	local character = createCharacter(player)
	if character == nil then
		return
	end
	CharacterService.applyTeamColor(character, TeamColors.getColor(teamId))
	character:PivotTo(spawnProvider(teamId))
	registerCombatant(player, character, { teamId = teamId, island = nil, protectSeconds = nil })
	for _, callback in spawnedCallbacks do
		task.spawn(callback, player, character)
	end
end

local function scheduleRespawn(player: Player)
	if pendingRespawn[player] then
		return
	end
	pendingRespawn[player] = true
	task.delay(CombatConfig.TestArena.RespawnSeconds, spawnPlayer, player)
end

-- Partida (F3): coloca o jogador num ponto. Com `combat`, ele entra no combate daquela ilha
-- (vida e escudo cheios); sem, fica fora do combate (mirante). Reaproveita o personagem se ele
-- ainda existe; senão cria um novo. Pode esperar (cria o personagem).
local placing: { [Player]: boolean } = {}

local function placeNow(player: Player, cframe: CFrame, combat: CombatPlacement?): Model?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or character.Parent == nil or humanoid == nil or humanoid.Health <= 0 then
		character = createCharacter(player)
	end
	if character == nil or player.Parent == nil then
		return nil
	end
	CharacterService.setFrozen(character, false)
	character:PivotTo(cframe)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = Vector3.zero
	end
	if combat then
		registerCombatant(player, character, combat)
	else
		Combatants.unregister(character)
	end
	for _, callback in spawnedCallbacks do
		task.spawn(callback, player, character)
	end
	return character
end

function CharacterService.place(player: Player, cframe: CFrame, combat: CombatPlacement?): Model?
	-- Um pedido por vez por jogador: dois pedidos juntos criariam dois personagens.
	while placing[player] do
		task.wait()
	end
	if player.Parent == nil then
		return nil
	end
	placing[player] = true
	local ok, result = pcall(placeNow, player, cframe, combat)
	placing[player] = nil
	if not ok then
		warn(`[Personagem] Falha ao colocar {player.Name}: {result}`)
		return nil
	end
	return result
end

-- Tira o personagem do mundo (ex.: jogador que vai voltar ao lobby).
function CharacterService.remove(player: Player)
	local character = player.Character
	if character then
		character:Destroy()
	end
end

-- Congelado na base durante a preparação (GDD 4.1): não anda, mas pode olhar em volta.
function CharacterService.setFrozen(model: Model, frozen: boolean)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = frozen
	end
end

-- Jogador de teste (só DEV_): alvo parado com o corpo base, registrado como combatente da dupla.
function CharacterService.spawnBot(name: string, teamId: string, island: number, cframe: CFrame): Combatants.Combatant?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(CharacterService.baseDescription(), Enum.HumanoidRigType.R15)
	end)
	if not ok or model == nil then
		warn(`[Personagem] Não foi possível criar o jogador de teste: {model}`)
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and root:IsA("BasePart")) then
		model:Destroy()
		return nil
	end
	model.Name = name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	root.Anchored = true
	local feetToRoot = humanoid.HipHeight + root.Size.Y / 2
	-- `cframe` vem 3 studs acima do chão (ponto de nascer): apoia os pés no chão
	model:PivotTo(cframe * CFrame.new(0, feetToRoot - 3, 0))
	CharacterService.setBodyGroup(model)
	CharacterService.applyTeamColor(model, TeamColors.getColor(teamId))
	local hitbox = CharacterService.attachHitbox(model)
	if hitbox == nil then
		model:Destroy()
		return nil
	end
	local folder = workspace:FindFirstChild(BOTS_FOLDER)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = BOTS_FOLDER
		folder.Parent = workspace
	end
	model.Parent = folder
	model.Destroying:Connect(function()
		Combatants.unregister(model)
	end)
	return Combatants.register(model, hitbox, {
		player = nil,
		teamId = teamId,
		island = island,
		displayName = name,
		protectSeconds = 0,
	})
end

function CharacterService.Init()
	Players.CharacterAutoLoads = false
	setupCollisionGroups()
end

function CharacterService.Start()
	Combatants.onKnocked(function(target: Combatants.Combatant)
		local player = target.player
		if player == nil then
			if
				target.model:IsDescendantOf(workspace)
				and target.model.Parent
				and target.model.Parent.Name == BOTS_FOLDER
			then
				target.model:Destroy() -- jogador de teste derrubado some (sem corpo no chão)
			end
			return
		end
		if player.Character ~= target.model then
			return
		end
		-- Sem corpo no chão (GDD 7.7): o personagem some e o efeito de poeira aparece nos clientes.
		target.model:Destroy()
		if autoMode() then
			scheduleRespawn(player)
		end
	end)

	TeamService.onChanged(function(player: Player, teamId: string?)
		local character = player.Character
		if character == nil or teamId == nil then
			return
		end
		CharacterService.applyTeamColor(character, TeamColors.getColor(teamId))
		local combatant = Combatants.get(character)
		if combatant then
			Combatants.setTeam(combatant, teamId)
		end
	end)

	if autoMode() then
		Players.PlayerAdded:Connect(spawnPlayer)
		for _, player in Players:GetPlayers() do
			task.spawn(spawnPlayer, player)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		pendingRespawn[player] = nil
	end)
end

return CharacterService
