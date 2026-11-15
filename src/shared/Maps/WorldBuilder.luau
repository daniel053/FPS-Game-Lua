--!strict
-- Monta o mundo da partida (GDD 6.5 e 15.3): o mirante octogonal no centro, as 4 ilhas de duelo nos
-- lados (norte, leste, sul e oeste), mais abaixo, e as nuvens. Fica em Shared para servir à partida
-- (servidor), ao lobby (cliente) e à prévia no Studio, sempre com o mesmo código.
--
-- Cada ilha tem o seu módulo em Maps/Islands. O mundo fica salvo no place da Partida (`bake`), para
-- aparecer ao abrir o Studio; o servidor confere se a cópia salva está em dia (`sameWorld`).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Build = require(script.Parent.Build)
local IslandCommon = require(script.Parent.IslandCommon)
local Fabrica = require(script.Parent.Islands.Fabrica)
local Porto = require(script.Parent.Islands.Porto)
local Praca = require(script.Parent.Islands.Praca)
local Torre = require(script.Parent.Islands.Torre)
local MapConfig = require(script.Parent.Parent.Config.MapConfig)
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
WorldBuilder.DetailAttribute = Build.DetailAttribute -- peças de acabamento: fora do minimapa
WorldBuilder.AtmosphereName = "MatchAtmosphere"
WorldBuilder.RebuiltAttribute = "RebuiltAtStart" -- a cópia salva estava velha e o servidor refez

local INVISIBLE: Build.PartOptions = { transparency = 1, query = false, shadow = false }
local DECOR: Build.PartOptions = { collide = false, query = false, shadow = false }

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
-- Cada mapa tem o seu módulo em Maps/Islands (a planta da área de duelo e as cores das bases). As
-- bases (iguais em todas) vêm do IslandCommon.

local ISLANDS: { [string]: IslandCommon.Island } = {
	map_porto = Porto,
	map_fabrica = Fabrica,
	map_praca = Praca,
	map_torre = Torre,
}

local function buildIsland(index: number, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = `Island{index}`
	folder:SetAttribute("Island", index)
	local frame = WorldLayout.islandFrame(index)
	local mapId = WorldLayout.mapId(index)
	local island = ISLANDS[mapId]
	addLabel(IslandCommon.labelAnchor(frame, folder), TextUtil.upper(Strings.Maps[mapId] or ""))
	IslandCommon.bases(frame, folder, island.style)
	island.build(frame, folder)
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

-- Monta o mundo dentro de `world`, uma parte por vez (mirante, cada ilha, nuvens). `pause` roda
-- entre as partes: no Studio (modo de edição) é um `task.wait`, para a janela não travar.
local function fill(world: Instance, pause: (() -> ())?)
	local steps: { () -> () } = {
		function()
			buildMirante(world)
		end,
	}
	for i = 1, WorldLayout.islandCount() do
		table.insert(steps, function()
			buildIsland(i, world)
		end)
	end
	table.insert(steps, function()
		buildSky(world)
	end)
	for _, step in steps do
		step()
		if pause then
			pause()
		end
	end
end

-- Monta o mundo inteiro numa pasta (sem pai). Quem chama põe no Workspace.
function WorldBuilder.build(): Folder
	local world = Instance.new("Folder")
	world.Name = WorldBuilder.FolderName
	fill(world)
	return world
end

-- Monta o mundo já dentro de `parent` (troca o que existir com o mesmo nome).
function WorldBuilder.install(parent: Instance, pause: (() -> ())?): Folder
	local existing = parent:FindFirstChild(WorldBuilder.FolderName)
	if existing then
		existing:Destroy()
	end
	local world = Instance.new("Folder")
	world.Name = WorldBuilder.FolderName
	world.Parent = parent
	fill(world, pause)
	return world
end

-- O mundo `saved` (a cópia salva no place) é igual ao `fresh` (o que o código monta hoje)? Compara
-- quantas peças há e as somas de posição, tamanho, cor, transparência e colisão (valores que o
-- place guarda sem arredondar) e, com uma folga pequena, a soma dos giros.
function WorldBuilder.sameWorld(saved: Instance, fresh: Instance): boolean
	local function measure(world: Instance): (number, number, number)
		local count, sum, turn = 0, 0, 0
		for _, part in world:GetDescendants() do
			if part:IsA("BasePart") then
				count += 1
				local p, s, c = part.Position, part.Size, part.Color
				sum += p.X + p.Y * 3 + p.Z * 7 + s.X * 11 + s.Y * 13 + s.Z * 17
				sum += math.round(c.R * 255) * 19 + math.round(c.G * 255) * 23 + math.round(c.B * 255) * 29
				sum += part.Transparency * 31 + (if part.CanCollide then 37 else 0) + (if part.CanQuery then 41 else 0)
				local look, right = part.CFrame.LookVector, part.CFrame.RightVector
				turn += look.X + look.Y * 3 + look.Z * 7 + right.X * 11 + right.Y * 13 + right.Z * 17
			end
		end
		return count, sum, turn
	end
	local countA, sumA, turnA = measure(saved)
	local countB, sumB, turnB = measure(fresh)
	return countA == countB and math.abs(sumA - sumB) < 0.01 and math.abs(turnA - turnB) < 0.01
end

-- O SpawnLocation do place fica embaixo do mirante e aparecia pelo vidro: vai para o centro do
-- mirante, invisível e sem colisão (quem entra aparece ali até o servidor posicionar).
function WorldBuilder.hideSpawn(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("SpawnLocation") then
			child.Transparency = 1
			child.CanCollide = false
			child.CanQuery = false
			child.CastShadow = false
			for _, decal in child:GetChildren() do
				if decal:IsA("Decal") then
					decal:Destroy()
				end
			end
			child.CFrame = CFrame.new(WorldLayout.miranteCenter() + Vector3.new(0, child.Size.Y / 2, 0))
		end
	end
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

-- Monta o mundo no Workspace do place aberto no Studio (modo de edição), para ficar salvo e visível
-- ao abrir o place. Rodar pela barra de comandos (README, "Mapa salvo no place"); depois salvar.
function WorldBuilder.bake(): Folder
	WorldBuilder.applyLighting()
	local world = WorldBuilder.install(workspace, task.wait)
	WorldBuilder.hideSpawn(workspace)
	return world
end

return WorldBuilder
