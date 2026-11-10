--!strict
-- Arena cinza do tutorial (F6), montada por código ao iniciar o servidor (nada salvo no place).
-- Uma "estação" fechada por paredes para cada parte, lado a lado; o jogador é levado de uma para a
-- outra. Visual cinza (FASES: aceito até a F10). Destaques no roxo do acento; área de perigo do
-- Renascer em vermelho (perigo, ESTILO 2.1). Sem neon.
--
-- Estações: Start (boas-vindas e movimento), Range (armas), Impulso, Nuvem, Tremor, Renascer e
-- Settings (voz, sensibilidade, retícula e final).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local TutorialConfig = require(Shared.Config.TutorialConfig)
local TutorialTypes = require(Shared.Tutorial.TutorialTypes)

local WORLD = TutorialConfig.World
local MOVE = TutorialConfig.Movement
local CARDS = TutorialConfig.Cards
local COLORS = Theme.Combat

-- "Start" | "Range" | "Impulso" | "Nuvem" | "Tremor" | "Renascer" | "Settings" (string: ver TutorialConfig.StepId)
export type StationName = string

local ORDER: { StationName } = { "Start", "Range", "Impulso", "Nuvem", "Tremor", "Renascer", "Settings" }

local FOLDER_NAME = "TutorialWorld"
local SPAWN_Z = -32 -- onde o jogador aparece em cada estação (olhando para +Z)

local TutorialWorld = {}

local folder: Folder
local origins: { [StationName]: Vector3 } = {}

local function floorTop(): number
	return WORLD.Origin.Y + WORLD.StationSize.Y / 2
end

-- Ponto no chão da estação (coordenadas locais: X para a direita, Z para a frente).
function TutorialWorld.point(station: StationName, x: number, z: number): Vector3
	local o = origins[station]
	return Vector3.new(o.X + x, floorTop(), o.Z + z)
end

-- Onde o jogador aparece (3 studs acima do chão, olhando para a frente).
function TutorialWorld.spawn(station: StationName): CFrame
	local p = TutorialWorld.point(station, 0, SPAWN_Z) + Vector3.new(0, 3, 0)
	return CFrame.lookAt(p, p + Vector3.new(0, 0, 1))
end

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

-- Bloco apoiado no chão da estação.
local function onFloor(
	name: string,
	station: StationName,
	size: Vector3,
	x: number,
	z: number,
	color: Color3,
	parent: Instance
): Part
	local base = TutorialWorld.point(station, x, z)
	return block(name, size, base + Vector3.new(0, size.Y / 2, 0), color, parent)
end

-- Disco fino no chão (círculo para andar, alvo da Nuvem).
local function disc(
	name: string,
	station: StationName,
	radius: number,
	x: number,
	z: number,
	color: Color3,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.12, radius * 2, radius * 2)
	part.CFrame = CFrame.new(TutorialWorld.point(station, x, z) + Vector3.new(0, 0.07, 0))
		* CFrame.Angles(0, 0, math.pi / 2)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = 0.25
	part.Parent = parent
	return part
end

local function buildStation(name: StationName, index: number)
	local station = Instance.new("Folder")
	station.Name = name
	station.Parent = folder
	local o = WORLD.Origin + Vector3.new((index - 1) * WORLD.StationSpacing, 0, 0)
	origins[name] = o
	local size = WORLD.StationSize
	block("Floor", size, o, COLORS.ArenaFloor, station)
	local h = WORLD.WallHeight
	local top = floorTop()
	for _, wall in
		{
			{ Vector3.new(size.X, h, 1), Vector3.new(0, 0, size.Z / 2) },
			{ Vector3.new(size.X, h, 1), Vector3.new(0, 0, -size.Z / 2) },
			{ Vector3.new(1, h, size.Z), Vector3.new(size.X / 2, 0, 0) },
			{ Vector3.new(1, h, size.Z), Vector3.new(-size.X / 2, 0, 0) },
		}
	do
		block("Wall", wall[1], Vector3.new(o.X, top + h / 2, o.Z) + wall[2], COLORS.ArenaWall, station)
	end
	-- Teto invisível: ninguém sai da estação pulando (o Impulso sobe bastante)
	local ceiling =
		block("Ceiling", Vector3.new(size.X, 1, size.Z), Vector3.new(o.X, top + 40, o.Z), COLORS.ArenaWall, station)
	ceiling.Transparency = 1
	return station
end

local function buildStart(station: Folder)
	-- Marcadores para olhar em volta: esquerda, direita e no alto à frente
	local markers = {
		{ x = -32, z = -10, height = 6 },
		{ x = 32, z = -10, height = 6 },
		{ x = 0, z = 36, height = 12 },
	}
	for i = 1, math.min(MOVE.LookMarkers, #markers) do
		local m = markers[i]
		local pillar =
			onFloor("LookPillar", "Start", Vector3.new(1.5, m.height, 1.5), m.x, m.z, COLORS.ArenaCover, station)
		local cube = block(
			`LookMarker{i}`,
			Vector3.new(3, 3, 3),
			pillar.Position + Vector3.new(0, m.height / 2 + 1.5, 0),
			Theme.Color.Accent,
			station
		)
		CollectionService:AddTag(cube, TutorialTypes.Attr.LookMarker)
	end
	disc("WalkCircle", "Start", MOVE.WalkRadius, 0, 0, Theme.Color.Accent, station)
	onFloor("JumpBox", "Start", Vector3.new(6, MOVE.BoxHeight, 6), 0, 16, COLORS.ArenaCover, station)
end

local function buildRange(station: Folder)
	-- Linha de tiro e meia parede na frente do jogador (referência de onde ficar)
	onFloor("FiringLine", "Range", Vector3.new(30, 0.1, 0.6), 0, SPAWN_Z + 4, Theme.Color.Accent, station)
	onFloor("LowWall", "Range", Vector3.new(20, 2.5, 1), 0, SPAWN_Z + 6, COLORS.ArenaCover, station)
end

local function buildImpulso(station: Folder)
	local s = CARDS.ImpulsoPlatformSize
	onFloor(
		"ImpulsoPlatform",
		"Impulso",
		Vector3.new(s, CARDS.ImpulsoPlatformHeight, s),
		0,
		SPAWN_Z + 8 + s / 2,
		COLORS.ArenaCover,
		station
	)
	-- Topo em destaque
	local topY = floorTop() + CARDS.ImpulsoPlatformHeight
	local mark = block(
		"ImpulsoTop",
		Vector3.new(s - 2, 0.1, s - 2),
		Vector3.new(
			TutorialWorld.point("Impulso", 0, 0).X,
			topY + 0.05,
			TutorialWorld.point("Impulso", 0, SPAWN_Z + 8 + s / 2).Z
		),
		Theme.Color.Accent,
		station
	)
	mark.CanCollide = false
end

local function buildNuvem(station: Folder)
	disc(
		"NuvemCircle",
		"Nuvem",
		CARDS.NuvemCircleRadius,
		0,
		SPAWN_Z + CARDS.NuvemCircleDistance,
		Theme.Color.Accent,
		station
	)
end

local function buildRenascer(station: Folder)
	local pad = onFloor(
		"DangerPad",
		"Renascer",
		Vector3.new(12, 0.2, 6),
		0,
		SPAWN_Z + CARDS.RenascerPadDistance,
		Theme.Color.Danger,
		station
	)
	pad.CanCollide = true
end

-- Áreas para o servidor conferir as tarefas ------------------------------------------------------

-- Círculo de andar (Movimento)
function TutorialWorld.walkCenter(): Vector3
	return TutorialWorld.point("Start", 0, 0)
end

-- Caixa para pular (Movimento): centro do topo e meia largura
function TutorialWorld.jumpBox(): (Vector3, number)
	return TutorialWorld.point("Start", 0, 16) + Vector3.new(0, MOVE.BoxHeight, 0), 3
end

-- Topo da plataforma do Impulso: centro e meia largura
function TutorialWorld.impulsoTop(): (Vector3, number)
	local s = CARDS.ImpulsoPlatformSize
	return TutorialWorld.point("Impulso", 0, SPAWN_Z + 8 + s / 2) + Vector3.new(0, CARDS.ImpulsoPlatformHeight, 0),
		s / 2
end

function TutorialWorld.nuvemCircle(): Vector3
	return TutorialWorld.point("Nuvem", 0, SPAWN_Z + CARDS.NuvemCircleDistance)
end

-- Área de perigo do Renascer: centro e meias medidas (X, Z)
function TutorialWorld.dangerPad(): (Vector3, Vector2)
	return TutorialWorld.point("Renascer", 0, SPAWN_Z + CARDS.RenascerPadDistance), Vector2.new(6, 3)
end

-- Onde ficam os alvos (pontos no chão) ------------------------------------------------------------

function TutorialWorld.rangeTargets(): { Vector3 }
	local list = {}
	local xs = { -8, 0, 8 }
	for i, distance in TutorialConfig.Targets.Distances do
		table.insert(list, TutorialWorld.point("Range", xs[(i - 1) % #xs + 1], SPAWN_Z + distance))
	end
	return list
end

function TutorialWorld.sniperTargets(): { Vector3 }
	local list = {}
	local xs = { -14, 14 }
	for i, distance in TutorialConfig.Targets.SniperDistances do
		table.insert(
			list,
			TutorialWorld.point(
				"Range",
				xs[(i - 1) % #xs + 1],
				math.min(SPAWN_Z + distance, WORLD.StationSize.Z / 2 - 4)
			)
		)
	end
	return list
end

function TutorialWorld.tremorTargets(): { Vector3 }
	local list = {}
	local d = CARDS.TremorTargetDistance
	for i = 1, CARDS.TremorTargets do
		local x = if i % 2 == 0 then 1.5 else -1.5
		table.insert(list, TutorialWorld.point("Tremor", x, SPAWN_Z + d + (i - 1) * 4))
	end
	return list
end

function TutorialWorld.settingsTargets(): { Vector3 }
	local list = {}
	for i = 1, TutorialConfig.Settings.MovingTargets do
		table.insert(list, TutorialWorld.point("Settings", 0, SPAWN_Z + 20 + (i - 1) * 12))
	end
	return list
end

function TutorialWorld.Init()
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	local stations: { [StationName]: Folder } = {}
	for i, name in ORDER do
		stations[name] = buildStation(name, i)
	end
	buildStart(stations.Start)
	buildRange(stations.Range)
	buildImpulso(stations.Impulso)
	buildNuvem(stations.Nuvem)
	buildRenascer(stations.Renascer)
	folder.Parent = workspace
end

return TutorialWorld
