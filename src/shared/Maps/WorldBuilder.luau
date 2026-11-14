--!strict
-- Monta o mundo da partida (GDD 6.5 e 15.3): o mirante octogonal no centro, as 4 ilhas de duelo nos
-- lados (norte, leste, sul e oeste), mais abaixo, e as nuvens. Fica em Shared para servir à partida
-- (servidor), ao lobby (cliente) e à prévia no Studio, sempre com o mesmo código.
--
-- Até cada mapa ficar pronto, a ilha usa o desenho cinza simétrico da F3 (agora com as bases fora
-- da área de duelo, nas pontas).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Build = require(script.Parent.Build)
local IslandCommon = require(script.Parent.IslandCommon)
local Praca = require(script.Parent.Islands.Praca)
local MapConfig = require(script.Parent.Parent.Config.MapConfig)
local MatchTypes = require(script.Parent.Parent.Match.MatchTypes)
local Strings = require(script.Parent.Parent.Config.Strings)
local TextUtil = require(script.Parent.Parent.TextUtil)
local Theme = require(script.Parent.Parent.Config.Theme)
local WorldLayout = require(script.Parent.Parent.Match.WorldLayout)

local WORLD = MapConfig.World
local MIRANTE = MapConfig.Mirante
local SKY = MapConfig.Sky
local COLORS = Theme.Match

local WorldBuilder = {}

WorldBuilder.FolderName = "MatchWorld"
WorldBuilder.GroundAttribute = IslandCommon.GroundAttribute -- chão desenhado no minimapa
WorldBuilder.AtmosphereName = "MatchAtmosphere"

local INVISIBLE: Build.PartOptions = { transparency = 1, query = false, shadow = false }
local DECOR: Build.PartOptions = { collide = false, query = false, shadow = false }
-- Chão e rocha das ilhas: sem sombra (projetada lá embaixo no mar de nuvens, parecia um buraco).
-- As construções continuam fazendo sombra no chão.
local NO_SHADOW: Build.PartOptions = { shadow = false }

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

-- Mirante ------------------------------------------------------------------------------------------
-- Octógono regular com um lado de frente para cada ilha. O piso é dividido por uma grade em "#":
-- placa do centro (opaca), 4 painéis retos e 4 triângulos nos cantos (de vidro). As vigas da grade
-- ficam em cima das emendas, então nenhum painel transparente se sobrepõe a outro.

local function buildMirante(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Mirante"
	local center = WorldLayout.miranteCenter()
	local floorY = center.Y
	local t = WORLD.MiranteThickness
	local apothem = WorldLayout.miranteApothem()
	local side = WorldLayout.miranteSide()
	local half = side / 2
	local band = apothem - half -- largura dos painéis retos (e catetos dos triângulos)
	local glass: Build.PartOptions = { transparency = MIRANTE.GlassTransparency, shadow = false }
	local origin = CFrame.new(center)

	-- O vidro vai até o centro, sem placa opaca: olhando para uma ilha (~15° a 30° para baixo), o
	-- olhar atravessa o piso a 10–20 studs de quem olha, e qualquer placa opaca ali tapava a ilha.
	Build.block(
		"Glass",
		Vector3.new(side, t, side),
		origin * CFrame.new(0, -t / 2, 0),
		COLORS.MiranteGlass,
		folder,
		glass
	)

	for k = 0, 3 do
		local turn = origin * CFrame.Angles(0, k * math.pi / 2, 0)
		Build.block(
			"Glass",
			Vector3.new(side, t, band),
			turn * CFrame.new(0, -t / 2, -(half + band / 2)),
			COLORS.MiranteGlass,
			folder,
			glass
		)
		Build.flatTriangle(
			"Glass",
			turn * Vector3.new(half, 0, -half),
			turn * Vector3.new(apothem, 0, -half),
			turn * Vector3.new(half, 0, -apothem),
			floorY,
			t,
			COLORS.MiranteGlass,
			folder,
			glass
		)
	end

	-- Grade em "#" (em cima das emendas), um pouco acima do vidro para não piscar
	local fw, fh = MIRANTE.FrameWidth, MIRANTE.FrameHeight
	local beamY = floorY + 0.05 - fh / 2
	for _, offset in { -half, half } do
		Build.block(
			"Frame",
			Vector3.new(WORLD.MiranteWidth, fh, fw),
			CFrame.new(center.X, beamY, center.Z + offset),
			COLORS.MiranteFrame,
			folder
		)
		Build.block(
			"Frame",
			Vector3.new(fw, fh, WORLD.MiranteWidth),
			CFrame.new(center.X + offset, beamY, center.Z),
			COLORS.MiranteFrame,
			folder
		)
	end

	-- Aro fino e barreira invisível em cada lado do octógono. Nada opaco embaixo do aro: perto da
	-- borda, qualquer faixa ali aparece pelo vidro e tapa o pedaço mais perto da ilha.
	local rimH = t + MIRANTE.RimHeight
	local barrierH = WORLD.MiranteBarrierHeight
	for k = 0, 7 do
		local edge = origin * CFrame.Angles(0, k * math.pi / 4, 0)
		Build.block(
			"Rim",
			Vector3.new(side, rimH, fw),
			edge * CFrame.new(0, -t + rimH / 2, -(apothem - fw / 2)),
			COLORS.MiranteFrame,
			folder
		)
		Build.block(
			"Barrier",
			Vector3.new(side + 2, barrierH, 1),
			edge * CFrame.new(0, barrierH / 2, -(apothem + 0.5)),
			COLORS.MiranteFrame,
			folder,
			INVISIBLE
		)
	end
	folder.Parent = parent
end

-- Ilhas ------------------------------------------------------------------------------------------
-- Cada mapa com planta aprovada tem o seu módulo em Maps/Islands; os outros usam o desenho cinza
-- simétrico da F3. As bases (iguais em todas) vêm do IslandCommon.

local ISLANDS: { [string]: (frame: CFrame, folder: Instance) -> () } = {
	map_praca = Praca,
}

local function buildGrayBody(frame: CFrame, folder: Instance)
	local body = WORLD.BodySize
	local halfX, halfZ = body.X / 2, body.Y / 2
	local t = WORLD.IslandThickness

	IslandCommon.ground(
		Build.block(
			"Floor",
			Vector3.new(body.X, t, body.Y),
			frame * CFrame.new(0, -t / 2, 0),
			COLORS.IslandFloor,
			folder,
			NO_SHADOW
		)
	)

	-- Rocha embaixo, afunilando (low poly em degraus)
	for i, scale in { 0, 0.55, 0.25 } do
		local size = if scale == 0
			then Vector3.new(body.X - 12, 10, body.Y - 12)
			else Vector3.new(body.X * scale, 12, body.Y * scale)
		Build.block(
			"Underside",
			size,
			frame * CFrame.new(0, -t - 5 - (i - 1) * 11.5, 0),
			COLORS.IslandUnderside,
			folder,
			NO_SHADOW
		)
	end

	-- Mureta em volta da área de duelo (com a abertura de cada base)
	local rail = WORLD.IslandEdgeRail
	local baseHalf = WORLD.BaseSize.Y / 2
	for _, z in { -halfZ, halfZ } do
		Build.wall("Rail", frame, Vector2.new(-halfX, z), Vector2.new(halfX, z), rail, 1, COLORS.IslandRail, folder)
	end
	for _, x in { -halfX, halfX } do
		for _, sign in { -1, 1 } do
			Build.wall(
				"Rail",
				frame,
				Vector2.new(x, sign * baseHalf),
				Vector2.new(x, sign * halfZ),
				rail,
				1,
				COLORS.IslandRail,
				folder
			)
		end
	end
	Build.mirrored("BaseCover", Vector3.new(1.5, 3, 10), frame, halfX - 12, 0, COLORS.IslandCover, folder)

	-- Galpão coberto no centro: paredes nos lados Z, portas nos lados X, telhado com tag
	local hallX, hallZ, hallH = 26, 20, 9
	for _, z in { -hallZ / 2, hallZ / 2 } do
		Build.onFloor("HallWall", Vector3.new(hallX, hallH, 1.5), frame, 0, z, COLORS.IslandWall, folder)
	end
	local sideLen = (hallZ - 6) / 2
	for _, sign in { -1, 1 } do
		Build.mirrored(
			"HallWall",
			Vector3.new(1.5, hallH, sideLen),
			frame,
			hallX / 2,
			sign * (3 + sideLen / 2),
			COLORS.IslandWall,
			folder
		)
	end
	local roof = Build.block(
		"HallRoof",
		Vector3.new(hallX + 2, 1, hallZ + 2),
		frame * CFrame.new(0, hallH + 0.5, 0),
		COLORS.IslandRoof,
		folder
	)
	CollectionService:AddTag(roof, MatchTypes.RoofTag)
	Build.mirrored("HallCover", Vector3.new(4, 3, 4), frame, 6, 0, COLORS.IslandCover, folder)

	-- Rotas laterais: coberturas cheias, meia altura e uma fina (o Moedor atravessa)
	for _, sign in { 1, -1 } do
		local laneZ = sign * 32
		Build.mirrored("FullCover", Vector3.new(8, 6, 1.5), frame, 34, laneZ, COLORS.IslandCover, folder)
		Build.mirrored("HalfCover", Vector3.new(6, 3, 1.5), frame, 18, laneZ - sign * 6, COLORS.IslandCover, folder)
		Build.mirrored("FullCover", Vector3.new(1.5, 6, 8), frame, 48, laneZ + sign * 6, COLORS.IslandCover, folder)
		-- Plataforma de 2º nível com degrau
		Build.onFloor("Platform", Vector3.new(14, 5, 10), frame, 0, sign * 38, COLORS.IslandRamp, folder)
		Build.mirrored("Step", Vector3.new(4, 2.5, 6), frame, 9, sign * 38, COLORS.IslandRamp, folder)
		Build.onFloor("PlatformCover", Vector3.new(6, 2.5, 1), frame, 0, sign * 33.5, COLORS.IslandCover, folder)
	end
	Build.mirrored("ThinCover", Vector3.new(0.8, 6, 8), frame, 24, 0, Theme.Combat.ArenaThin, folder)
end

local function buildIsland(index: number, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = `Island{index}`
	folder:SetAttribute("Island", index)
	local frame = WorldLayout.islandFrame(index)
	local mapId = WorldLayout.mapId(index)
	addLabel(IslandCommon.labelAnchor(frame, folder), TextUtil.upper(Strings.Maps[mapId] or ""))
	IslandCommon.bases(frame, folder)
	local layout = ISLANDS[mapId]
	if layout then
		layout(frame, folder)
	else
		buildGrayBody(frame, folder)
	end
	folder.Parent = parent
end

-- Nuvens -----------------------------------------------------------------------------------------
-- Nuvem de desenho animado: bolas brancas encostadas, uma maior no meio. Embaixo de tudo, um mar de
-- nuvens claro (para o fundo nunca ficar escuro olhando para baixo, ESTILO T4).

local function puff(parent: Instance, diameter: number, position: Vector3, color: Color3)
	local part = Build.block("Cloud", Vector3.one * diameter, CFrame.new(position), color, parent, DECOR)
	part.Shape = Enum.PartType.Ball
end

local function cloud(parent: Instance, position: Vector3, random: Random, scale: number)
	local puffs = random:NextInteger(SKY.CloudPuffs.Min, SKY.CloudPuffs.Max)
	local main = random:NextNumber(SKY.CloudPuffSize.Min, SKY.CloudPuffSize.Max) * scale
	local yaw = random:NextNumber(0, math.pi * 2)
	local along = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
	local across = Vector3.new(-along.Z, 0, along.X)
	puff(parent, main, position, COLORS.Cloud)
	for i = 2, puffs do
		local d = main * random:NextNumber(0.5, 0.8)
		local sideSign = if i % 2 == 0 then 1 else -1
		local offset = along * sideSign * (main * 0.35 + d * 0.3) * random:NextNumber(0.8, 1.3)
			+ across * random:NextNumber(-main * 0.25, main * 0.25)
			- Vector3.yAxis * (main - d) * 0.35
		puff(parent, d, position + offset, if i > 3 then COLORS.CloudShade else COLORS.Cloud)
	end
end

local function cloudRing(
	parent: Instance,
	random: Random,
	count: number,
	radius: NumberRange,
	height: NumberRange,
	scale: number,
	avoidIslands: boolean
)
	for _ = 1, count do
		local position = Vector3.zero
		for _ = 1, 6 do
			local angle = random:NextNumber(0, math.pi * 2)
			local r = random:NextNumber(radius.Min, radius.Max)
			position = Vector3.new(math.cos(angle) * r, random:NextNumber(height.Min, height.Max), math.sin(angle) * r)
			if not (avoidIslands and WorldLayout.islandAt(position)) then
				break
			end
		end
		cloud(parent, position, random, scale)
	end
end

local function buildSky(parent: Instance)
	-- Model persistente: com o streaming ligado, as peças longe (mar e horizonte) chegam a todos.
	local folder = Instance.new("Model")
	folder.Name = "Clouds"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local random = Random.new(SKY.CloudSeed)
	local seaY = SKY.CloudSeaY
	-- Mar em ladrilhos (uma peça tem no máximo 2048): a borda fica tão longe que some no horizonte
	local tile = SKY.CloudSeaSize
	local reach = math.floor(SKY.CloudSeaTiles / 2)
	for ix = -reach, reach do
		for iz = -reach, reach do
			Build.block(
				"CloudSea",
				Vector3.new(tile, 4, tile),
				CFrame.new(ix * tile, seaY - 2, iz * tile),
				COLORS.CloudSea,
				folder,
				DECOR
			)
		end
	end
	cloudRing(folder, random, SKY.SeaClouds, SKY.SeaCloudRadius, NumberRange.new(seaY, seaY + 10), 3, false)
	cloudRing(folder, random, SKY.LowClouds, SKY.LowCloudRadius, SKY.LowCloudY, 1, true)
	cloudRing(folder, random, SKY.FarClouds, SKY.FarCloudRadius, SKY.FarCloudY, 1.6, false)
	folder.Parent = parent
end

-- API -------------------------------------------------------------------------------------------

-- Monta o mundo inteiro numa pasta (sem pai). Quem chama põe no Workspace.
function WorldBuilder.build(): Folder
	local world = Instance.new("Folder")
	world.Name = WorldBuilder.FolderName
	buildMirante(world)
	for i = 1, WorldLayout.islandCount() do
		buildIsland(i, world)
	end
	buildSky(world)
	return world
end

-- Luz do dia e névoa leve (sem pós-processamento pesado, GDD 13.2).
function WorldBuilder.applyLighting()
	Lighting.ClockTime = SKY.ClockTime
	-- O Roblox usa um Atmosphere só: reaproveita o do place, se houver.
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if a == nil then
		local created = Instance.new("Atmosphere")
		created.Name = WorldBuilder.AtmosphereName
		created.Parent = Lighting
		a = created
	end
	assert(a, "Atmosphere")
	a.Density = SKY.AtmosphereDensity
	a.Haze = SKY.AtmosphereHaze
	a.Offset = 0
	a.Glare = 0
	a.Color = COLORS.SkyAtmosphere
	a.Decay = COLORS.SkyDecay
end

return WorldBuilder
