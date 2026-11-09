--!strict
-- Arena de teste cinza da F2 (FASES F2: "arena de teste cinza com alvos e coberturas").
-- É montada pelo código ao iniciar o servidor, só durante o jogo (nada é salvo no place).
-- Na F3 as ilhas cinza substituem esta arena (CombatConfig.TestArena.Enabled = false).
--
-- Conteúdo:
--   * bases das duas duplas de teste em lados opostos;
--   * área de coberturas: cheias (6 studs), meia altura (3 studs), parede grande para testar o
--     contorno do parceiro (corpo inteiro escondido) e uma cobertura fina com alvo atrás (Moedor);
--   * estande de tiro com alvos a 10, 20, 40, 60, 80 e 100 studs (perda de dano com a distância);
--   * alvos que andam de um lado para o outro (assistência de mira e tiro automático).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local Strings = require(Shared.Config.Strings)
local TeamColors = require(Shared.Config.TeamColors)
local Theme = require(Shared.Config.Theme)

local CharacterService = require(script.Parent.CharacterService)
local Combatants = require(script.Parent.Combatants)

local ARENA = CombatConfig.TestArena
local COLORS = Theme.Combat

local ARENA_NAME = "TestArena"
local FLOOR_TOP = 1
local SIZE_X, SIZE_Z = 160, 120
local WALL_HEIGHT = 10

type Dummy = {
	model: Model,
	base: CFrame,
	moving: boolean,
	phase: number,
}

local TestArenaService = {}

local arena: Folder
local dummiesFolder: Folder
local dummies: { [Model]: Dummy } = {}
local spawnPoints: { [string]: { CFrame } } = {}
local dummiesMove = true

local function block(name: string, size: Vector3, center: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = center
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Peça apoiada no chão: `x`, `z` = centro; `size.Y` = altura.
local function onFloor(name: string, size: Vector3, x: number, z: number, color: Color3, parent: Instance): Part
	return block(name, size, Vector3.new(x, FLOOR_TOP + size.Y / 2, z), color, parent)
end

local function buildGeometry()
	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = arena

	block("Floor", Vector3.new(SIZE_X, 1, SIZE_Z), Vector3.new(0, FLOOR_TOP - 0.5, 0), COLORS.ArenaFloor, geometry)
	-- Paredes em volta
	local halfX, halfZ = SIZE_X / 2, SIZE_Z / 2
	onFloor("WallNorth", Vector3.new(SIZE_X, WALL_HEIGHT, 2), 0, halfZ + 1, COLORS.ArenaWall, geometry)
	onFloor("WallSouth", Vector3.new(SIZE_X, WALL_HEIGHT, 2), 0, -halfZ - 1, COLORS.ArenaWall, geometry)
	onFloor("WallEast", Vector3.new(2, WALL_HEIGHT, SIZE_Z + 4), halfX + 1, 0, COLORS.ArenaWall, geometry)
	onFloor("WallWest", Vector3.new(2, WALL_HEIGHT, SIZE_Z + 4), -halfX - 1, 0, COLORS.ArenaWall, geometry)

	-- Área de coberturas (lado oeste)
	-- Parede grande: o parceiro atrás dela fica com o corpo inteiro escondido (contorno aparece).
	onFloor("PartnerTestWall", Vector3.new(12, 8, 2), -50, -10, COLORS.ArenaWall, geometry)
	-- Coberturas cheias (≥ 6 studs, KIT-MODULAR)
	onFloor("FullCover", Vector3.new(8, 6, 1.5), -30, -25, COLORS.ArenaCover, geometry)
	onFloor("FullCover", Vector3.new(1.5, 6, 8), -15, -5, COLORS.ArenaCover, geometry)
	onFloor("FullCover", Vector3.new(8, 6, 1.5), -60, 20, COLORS.ArenaCover, geometry)
	onFloor("FullCover", Vector3.new(1.5, 6, 8), -35, 30, COLORS.ArenaCover, geometry)
	onFloor("FullCover", Vector3.new(8, 6, 1.5), -5, 30, COLORS.ArenaCover, geometry)
	-- Meia altura (3 studs)
	onFloor("HalfCover", Vector3.new(6, 3, 1.5), -45, -35, COLORS.ArenaCover, geometry)
	onFloor("HalfCover", Vector3.new(6, 3, 1.5), -20, 15, COLORS.ArenaCover, geometry)
	onFloor("HalfCover", Vector3.new(1.5, 3, 6), -65, -5, COLORS.ArenaCover, geometry)
	onFloor("HalfCover", Vector3.new(6, 3, 1.5), -8, -30, COLORS.ArenaCover, geometry)
	-- Cobertura fina (o Moedor atravessa com dano reduzido)
	onFloor("ThinCover", Vector3.new(8, 6, 0.8), -30, 8, COLORS.ArenaThin, geometry)

	-- Estande de tiro (lado leste): linha de tiro em z = -50 e faixas no chão a cada distância
	onFloor("FiringLine", Vector3.new(70, 0.1, 0.6), 42.5, -50, COLORS.ArenaMarker, geometry)
	for _, distance in { 10, 20, 40, 60, 80, 100 } do
		onFloor(`Mark{distance}`, Vector3.new(70, 0.1, 0.3), 42.5, -50 + distance, COLORS.ArenaMarker, geometry)
	end
end

local function buildSpawns()
	local teamA, teamB = TeamColors.Order[1], TeamColors.Order[2]
	spawnPoints[teamA] = {}
	spawnPoints[teamB] = {}
	for _, x in { -60, -50, -40 } do
		local a = Vector3.new(x, FLOOR_TOP + 3, -54)
		local b = Vector3.new(x, FLOOR_TOP + 3, 54)
		table.insert(spawnPoints[teamA], CFrame.lookAt(a, Vector3.new(x, a.Y, 0)))
		table.insert(spawnPoints[teamB], CFrame.lookAt(b, Vector3.new(x, b.Y, 0)))
	end
end

local function spawnFor(teamId: string): CFrame
	local list = spawnPoints[teamId] or spawnPoints[TeamColors.Order[1]]
	return list[math.random(1, #list)]
end

local function addLabel(model: Model, text: string)
	local head = model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "DummyLabel"
	gui.Size = UDim2.fromOffset(220, 28)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 140
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Theme.Font.BodyStrong
	label.TextSize = Theme.TextSize.Body
	label.TextColor3 = Theme.Color.TextPrimary
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui
	gui.Parent = head
end

local function createDummy(position: Vector3, facing: Vector3, label: string, moving: boolean)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(
			CharacterService.baseDescription(COLORS.DummyBody),
			Enum.HumanoidRigType.R15
		)
	end)
	if not ok or model == nil then
		warn(`[Arena] Não foi possível criar um alvo: {model}`)
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and root:IsA("BasePart")) then
		model:Destroy()
		return
	end
	model.Name = Strings.Combat.DummyName
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	root.Anchored = true

	local feetToRoot = humanoid.HipHeight + root.Size.Y / 2
	local base = CFrame.lookAt(
		Vector3.new(position.X, FLOOR_TOP + feetToRoot, position.Z),
		Vector3.new(position.X + facing.X, FLOOR_TOP + feetToRoot, position.Z + facing.Z)
	)
	model:PivotTo(base)
	CharacterService.setBodyGroup(model)
	local hitbox = CharacterService.attachHitbox(model)
	if hitbox == nil then
		model:Destroy()
		return
	end
	addLabel(model, label)
	model.Parent = dummiesFolder

	Combatants.register(model, hitbox, {
		player = nil,
		teamId = CombatNames.DummyTeam,
		displayName = Strings.Combat.DummyName,
	})
	dummies[model] = { model = model, base = base, moving = moving, phase = math.random() * math.pi * 2 }
end

local function buildDummies()
	local name = Strings.Combat.DummyName
	local towardFiringLine = Vector3.new(0, 0, -1)
	for i, distance in { 10, 20, 40, 60, 80, 100 } do
		local x = 15 + (i - 1) * 10
		local text = string.format(Strings.Combat.DummyDistance, name, distance)
		task.spawn(createDummy, Vector3.new(x, 0, -50 + distance), towardFiringLine, text, false)
	end
	-- Atrás da cobertura fina
	task.spawn(
		createDummy,
		Vector3.new(-30, 0, 12),
		towardFiringLine,
		string.format(Strings.Combat.DummyThinCover, name),
		false
	)
	-- Alvos que andam
	local movingText = string.format(Strings.Combat.DummyMoving, name)
	task.spawn(createDummy, Vector3.new(-8, 0, 5), towardFiringLine, movingText, true)
	task.spawn(createDummy, Vector3.new(-55, 0, 5), towardFiringLine, movingText, true)
	-- Alvos parados na área de coberturas
	task.spawn(createDummy, Vector3.new(-40, 0, 40), towardFiringLine, name, false)
	task.spawn(createDummy, Vector3.new(-20, 0, 45), towardFiringLine, name, false)
end

-- Painel de teste: liga/desliga o movimento dos alvos. Devolve o novo estado.
function TestArenaService.toggleDummyMovement(): boolean
	dummiesMove = not dummiesMove
	return dummiesMove
end

function TestArenaService.isEnabled(): boolean
	return ARENA.Enabled
end

function TestArenaService.Init()
	if not ARENA.Enabled then
		return
	end
	local existing = workspace:FindFirstChild(ARENA_NAME)
	if existing then
		existing:Destroy()
	end
	arena = Instance.new("Folder")
	arena.Name = ARENA_NAME
	dummiesFolder = Instance.new("Folder")
	dummiesFolder.Name = "Dummies"
	dummiesFolder.Parent = arena
	buildGeometry()
	buildSpawns()
	arena.Parent = workspace
	CharacterService.setSpawnProvider(spawnFor)
end

function TestArenaService.Start()
	if not ARENA.Enabled then
		return
	end
	buildDummies()

	-- Alvo derrubado some e volta com vida cheia.
	Combatants.onKnocked(function(target: Combatants.Combatant)
		local dummy = dummies[target.model]
		if dummy == nil then
			return
		end
		target.model.Parent = nil
		task.delay(ARENA.DummyRespawnSeconds, function()
			target.model.Parent = dummiesFolder
			Combatants.revive(target)
		end)
	end)

	local amplitude = ARENA.DummyStrafeDistance
	local angularSpeed = ARENA.DummyStrafeSpeed / amplitude
	RunService.Heartbeat:Connect(function()
		if not dummiesMove then
			return
		end
		local now = os.clock()
		for _, dummy in dummies do
			if dummy.moving and dummy.model.Parent then
				local offset = math.sin(now * angularSpeed + dummy.phase) * amplitude
				dummy.model:PivotTo(dummy.base * CFrame.new(offset, 0, 0))
			end
		end
	end)
end

return TestArenaService
