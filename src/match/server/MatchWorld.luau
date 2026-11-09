--!strict
-- Mundo cinza da partida (FASES F3): mirante plano no centro e 4 ilhas de duelo em volta e abaixo.
-- Montado por código ao iniciar o servidor (nada fica salvo no place). Os mapas finais (F10) são
-- construídos no Studio; até lá, cada ilha usa o mesmo desenho simétrico (justo para os dois lados):
--   * bases nas pontas (eixo X), com cobertura na frente;
--   * galpão coberto no centro (o telhado fica transparente para quem está no mirante);
--   * duas rotas laterais com coberturas cheias e de meia altura, plataformas de 2º nível;
--   * mureta em volta (cair da ilha volta para a base e perde o escudo).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local MapConfig = require(Shared.Config.MapConfig)
local MatchTypes = require(Shared.Match.MatchTypes)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local TextUtil = require(Shared.TextUtil)
local WorldLayout = require(Shared.Match.WorldLayout)

local GRAY = MapConfig.Gray
local COLORS = Theme.Match

local WORLD_NAME = "MatchWorld"

local MatchWorld = {}

local world: Folder

local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Peça apoiada no chão da ilha, em coordenadas locais (x, z a partir do centro). Espelha no eixo X
-- quando `mirror` = true (cria a mesma peça do outro lado).
local function onFloor(
	name: string,
	size: Vector3,
	x: number,
	z: number,
	color: Color3,
	origin: Vector3,
	parent: Instance,
	mirror: boolean?
)
	local y = origin.Y + size.Y / 2
	block(name, size, CFrame.new(origin.X + x, y, origin.Z + z), color, parent)
	if mirror and x ~= 0 then
		block(name, size, CFrame.new(origin.X - x, y, origin.Z + z), color, parent)
	end
end

local function addLabel(parent: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "IslandLabel"
	gui.Size = UDim2.fromOffset(240, 56)
	gui.StudsOffset = Vector3.new(0, 34, 0)
	gui.MaxDistance = 600
	gui.LightInfluence = 0
	gui.Enabled = false -- o cliente liga só para quem está no mirante
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Theme.Font.Title
	label.TextScaled = true
	label.TextColor3 = Theme.Color.TextPrimary
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
	CollectionService:AddTag(gui, "IslandLabel")
end

local function buildIsland(index: number)
	local folder = Instance.new("Folder")
	folder.Name = `Island{index}`
	folder:SetAttribute("Island", index)
	local origin = WorldLayout.islandCenter(index)
	local size = GRAY.IslandSize
	local halfX, halfZ = size.X / 2, size.Y / 2
	local t = GRAY.IslandThickness

	local floor = block(
		"Floor",
		Vector3.new(size.X, t, size.Y),
		CFrame.new(origin.X, origin.Y - t / 2, origin.Z),
		COLORS.IslandFloor,
		folder
	)
	block(
		"Underside",
		Vector3.new(size.X - 16, 10, size.Y - 16),
		CFrame.new(origin.X, origin.Y - t - 5, origin.Z),
		COLORS.IslandUnderside,
		folder
	)
	addLabel(floor, TextUtil.upper(Strings.Maps[WorldLayout.mapId(index)] or ""))

	-- Mureta em volta
	local rail = GRAY.IslandEdgeRail
	onFloor("Rail", Vector3.new(size.X, rail, 1), 0, halfZ - 0.5, COLORS.IslandRail, origin, folder)
	onFloor("Rail", Vector3.new(size.X, rail, 1), 0, -halfZ + 0.5, COLORS.IslandRail, origin, folder)
	onFloor("Rail", Vector3.new(1, rail, size.Y - 2), halfX - 0.5, 0, COLORS.IslandRail, origin, folder, true)

	-- Bases: parede atrás e meia cobertura na frente
	local baseX = halfX - GRAY.BaseInset
	onFloor("BaseBack", Vector3.new(1.5, 7, 16), baseX + 5, 0, COLORS.IslandWall, origin, folder, true)
	onFloor("BaseCover", Vector3.new(1.5, 3, 10), baseX - 7, 0, COLORS.IslandCover, origin, folder, true)

	-- Galpão coberto no centro: paredes nos lados Z, portas nos lados X, telhado com tag
	local hallX, hallZ, hallH = 26, 20, 9
	onFloor("HallWall", Vector3.new(hallX, hallH, 1.5), 0, hallZ / 2, COLORS.IslandWall, origin, folder)
	onFloor("HallWall", Vector3.new(hallX, hallH, 1.5), 0, -hallZ / 2, COLORS.IslandWall, origin, folder)
	-- Lados X: duas paredes curtas com a porta (6 studs) no meio
	local sideLen = (hallZ - 6) / 2
	onFloor(
		"HallWall",
		Vector3.new(1.5, hallH, sideLen),
		hallX / 2,
		3 + sideLen / 2,
		COLORS.IslandWall,
		origin,
		folder,
		true
	)
	onFloor(
		"HallWall",
		Vector3.new(1.5, hallH, sideLen),
		hallX / 2,
		-3 - sideLen / 2,
		COLORS.IslandWall,
		origin,
		folder,
		true
	)
	local roof = block(
		"HallRoof",
		Vector3.new(hallX + 2, 1, hallZ + 2),
		CFrame.new(origin.X, origin.Y + hallH + 0.5, origin.Z),
		COLORS.IslandRoof,
		folder
	)
	CollectionService:AddTag(roof, MatchTypes.RoofTag)
	onFloor("HallCover", Vector3.new(4, 3, 4), 6, 0, COLORS.IslandCover, origin, folder, true)

	-- Rotas laterais (norte e sul): coberturas cheias, meia altura e uma fina (o Moedor atravessa)
	for _, sign in { 1, -1 } do
		local laneZ = sign * 32
		onFloor("FullCover", Vector3.new(8, 6, 1.5), 34, laneZ, COLORS.IslandCover, origin, folder, true)
		onFloor("HalfCover", Vector3.new(6, 3, 1.5), 18, laneZ - sign * 6, COLORS.IslandCover, origin, folder, true)
		onFloor("FullCover", Vector3.new(1.5, 6, 8), 48, laneZ + sign * 6, COLORS.IslandCover, origin, folder, true)
		-- Plataforma de 2º nível com degrau
		onFloor("Platform", Vector3.new(14, 5, 10), 0, sign * 38, COLORS.IslandRamp, origin, folder)
		onFloor("Step", Vector3.new(4, 2.5, 6), 9, sign * 38, COLORS.IslandRamp, origin, folder, true)
		onFloor("PlatformCover", Vector3.new(6, 2.5, 1), 0, sign * 33.5, COLORS.IslandCover, origin, folder)
	end
	onFloor("ThinCover", Vector3.new(0.8, 6, 8), 24, 0, Theme.Combat.ArenaThin, origin, folder, true)

	folder.Parent = world
end

local function buildMirante()
	local folder = Instance.new("Folder")
	folder.Name = "Mirante"
	local center = WorldLayout.miranteCenter()
	local side = GRAY.MiranteHalfDiagonal * math.sqrt(2)
	local t = GRAY.MiranteThickness
	local rotation = CFrame.Angles(0, math.rad(45), 0)
	block(
		"Floor",
		Vector3.new(side, t, side),
		CFrame.new(center.X, center.Y - t / 2, center.Z) * rotation,
		COLORS.MiranteFloor,
		folder
	)
	block(
		"Underside",
		Vector3.new(side - 12, 8, side - 12),
		CFrame.new(center.X, center.Y - t - 4, center.Z) * rotation,
		COLORS.IslandUnderside,
		folder
	)
	-- Borda visível baixa + barreira invisível alta em cada lado do losango
	local h = GRAY.MiranteBarrierHeight
	for i = 0, 3 do
		local edgeRotation = rotation * CFrame.Angles(0, math.rad(90 * i), 0)
		local edgeCFrame = CFrame.new(center) * edgeRotation * CFrame.new(0, 0, side / 2)
		block("Edge", Vector3.new(side, 0.6, 1), edgeCFrame * CFrame.new(0, 0.3, -0.5), COLORS.MiranteEdge, folder)
		local barrier = block(
			"Barrier",
			Vector3.new(side + 2, h, 1),
			edgeCFrame * CFrame.new(0, h / 2, 0),
			COLORS.MiranteEdge,
			folder
		)
		barrier.Transparency = 1
		barrier.CanQuery = false
		barrier.CanTouch = false
		barrier.CastShadow = false
	end
	folder.Parent = world
end

function MatchWorld.build()
	local existing = workspace:FindFirstChild(WORLD_NAME)
	if existing then
		existing:Destroy()
	end
	world = Instance.new("Folder")
	world.Name = WORLD_NAME
	buildMirante()
	for i = 1, WorldLayout.islandCount() do
		buildIsland(i)
	end
	world.Parent = workspace
end

-- Ponto aleatório no mirante (perto do centro), olhando para fora.
function MatchWorld.miranteSpawn(): CFrame
	local center = WorldLayout.miranteCenter()
	local angle = math.random() * math.pi * 2
	local radius = math.random() * GRAY.MiranteHalfDiagonal * 0.35
	local position = center + Vector3.new(math.cos(angle) * radius, 3, math.sin(angle) * radius)
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	return CFrame.lookAt(position, position + outward)
end

-- Pódio: centro do mirante (cerimônia de campeão).
function MatchWorld.podiumSpawn(slot: number): CFrame
	local center = WorldLayout.miranteCenter()
	local position = center + Vector3.new((slot - 1.5) * 4, 3, 0)
	return CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
end

return MatchWorld
