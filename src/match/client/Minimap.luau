--!strict
-- Minimapa redondo (ESTILO T6, GDD 7.6), canto superior direito, só enquanto o jogador está numa ilha:
--   * a ilha vista de cima, norte para cima (não gira), com as construções desenhadas a partir das
--     peças do mapa (serve para as ilhas cinza e para os mapas finais da F10);
--   * a zona (círculo roxo) quando começa a fechar;
--   * você (seta na direção da câmera), o parceiro (ponto verde) e os inimigos só quando vistos
--     (contorno ligado), que continuam por um instante depois de sumir.
--   * os pings da dupla (F8): ícone na cor do ping, até expirar (Minimap.addPing).
-- Sem neon.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CombatNames = require(Shared.Combat.CombatNames)
local CombatConfig = require(Shared.Config.CombatConfig)
local MatchTypes = require(Shared.Match.MatchTypes)
local MatchConfig = require(Shared.Config.MatchConfig)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.Ui)
local UiConfig = require(Shared.Config.UiConfig)
local WorldBuilder = require(Shared.Maps.WorldBuilder)
local WorldLayout = require(Shared.Match.WorldLayout)

local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local TeamMarkers = require(script.Parent.Parent.Combat.TeamMarkers)
local MatchClient = require(script.Parent.MatchClient)

local CFG = UiConfig.Minimap
local COLORS = Theme.Minimap
local WORLD_FOLDER = WorldBuilder.FolderName
local DETAIL_ATTRIBUTE = WorldBuilder.DetailAttribute -- peças de acabamento dos kits: fora do minimapa
-- Faixas usadas para desenhar cada triângulo de chão (a interface não tem triângulo)
local TRIANGLE_STRIPS = 10

local Minimap = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local holder: Frame
local canvas: CanvasGroup
local map: Frame -- área da ilha (escala de studs para pixels)
local zoneRing: Frame
local me: TextLabel
local ally: Frame
local enemyDots: { [Model]: Frame } = {}
local enemySeenAt: { [Model]: number } = {}
local drawnIsland: number? = nil
local lastRefresh = 0
type PingDot = { label: TextLabel, island: number, position: Vector3, expiresAt: number }
local pingDots: { [string]: PingDot } = {}

local function islandExtent(island: number): Vector2
	return WorldLayout.islandExtent(island)
end

-- Posição no mapa (0 a 1) de um ponto do mundo, para a ilha atual.
local function toMap(island: number, position: Vector3): Vector2
	local center = WorldLayout.islandCenter(island)
	local size = islandExtent(island)
	local span = math.max(size.X, size.Y) * (1 + 2 * CFG.Padding)
	return Vector2.new(0.5 + (position.X - center.X) / span, 0.5 + (position.Z - center.Z) / span)
end

local function dot(name: string, color: Color3, size: number): Frame
	local f = Ui.frame(name, map)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundTransparency = 0
	f.BackgroundColor3 = color
	f.ZIndex = 5
	Ui.corner(f, size)
	Ui.stroke(f, Theme.Color.Overlay, 1)
	return f
end

-- Triângulo de chão (chanfros e diagonais das plantas): uma WedgePart deitada (Build.flatTriangle),
-- com o ângulo reto em (-Y, +Z) local. É desenhado em faixas finas paralelas a um cateto, cada uma
-- mais curta que a anterior.
local function drawGroundTriangle(island: number, wedge: WedgePart)
	local h, d = wedge.Size.Y / 2, wedge.Size.Z / 2
	local corner = toMap(island, wedge.CFrame * Vector3.new(0, -h, d))
	local legA = toMap(island, wedge.CFrame * Vector3.new(0, h, d)) - corner
	local legB = toMap(island, wedge.CFrame * Vector3.new(0, -h, -d)) - corner
	local rotation = math.deg(math.atan2(legA.Y, legA.X))
	local thickness = legB.Magnitude / TRIANGLE_STRIPS
	for i = 0, TRIANGLE_STRIPS - 1 do
		local t = (i + 0.5) / TRIANGLE_STRIPS
		local strip = Ui.frame("Ground", map)
		strip:SetAttribute("Static", true)
		strip.AnchorPoint = Vector2.new(0.5, 0.5)
		local mid = corner + legB * t + legA * ((1 - t) / 2)
		strip.Position = UDim2.fromScale(mid.X, mid.Y)
		strip.Rotation = rotation
		-- um fio a mais na espessura, para não aparecer fresta entre as faixas
		strip.Size = UDim2.fromScale(legA.Magnitude * (1 - t), thickness * 1.15)
		strip.BackgroundTransparency = 0
		strip.BackgroundColor3 = COLORS.Island
		strip.ZIndex = 1
	end
end

-- Desenha as construções da ilha: peças acima do chão, vistas de cima.
local function drawIsland(island: number)
	for _, child in map:GetChildren() do
		if child:GetAttribute("Static") then
			child:Destroy()
		end
	end
	drawnIsland = island
	local center = WorldLayout.islandCenter(island)
	local size = islandExtent(island)
	local span = math.max(size.X, size.Y) * (1 + 2 * CFG.Padding)

	local world = workspace:FindFirstChild(WORLD_FOLDER)
	local folder = world and world:FindFirstChild(`Island{island}`)
	if folder == nil then
		return
	end
	for _, part in folder:GetDescendants() do
		if not part:IsA("BasePart") or part.Transparency >= 0.9 or part:GetAttribute(DETAIL_ATTRIBUTE) then
			continue
		end
		-- Chão (área de duelo e bases) embaixo; construções acima do chão por cima. Peças rasas e a
		-- rocha de baixo da ilha ficam de fora.
		local ground = part:GetAttribute(WorldBuilder.GroundAttribute) == true
		local top = part.Position.Y + part.Size.Y / 2
		if not ground and top < center.Y + 1 then
			continue
		end
		if ground and part:IsA("WedgePart") then
			drawGroundTriangle(island, part)
			continue
		end
		local rect = Ui.frame(if ground then "Ground" else "Block", map)
		rect:SetAttribute("Static", true)
		rect.AnchorPoint = Vector2.new(0.5, 0.5)
		local p = toMap(island, part.Position)
		rect.Position = UDim2.fromScale(p.X, p.Y)
		local _, yaw, _ = part.CFrame:ToOrientation()
		rect.Rotation = -math.deg(yaw)
		rect.Size = UDim2.fromScale(part.Size.X / span, part.Size.Z / span)
		rect.BackgroundTransparency = 0
		rect.BackgroundColor3 = if ground then COLORS.Island else COLORS.Cover
		rect.ZIndex = if ground then 1 else 2
	end
end

local function enemyColor(): Color3
	local profile = PlayerDataClient.get()
	local id = if profile then profile.settings.enemyOutlineColor else "red"
	return Theme.EnemyOutline[id] or Theme.Color.Danger
end

local function place(f: GuiObject, island: number, position: Vector3)
	local p = toMap(island, position)
	f.Position = UDim2.fromScale(p.X, p.Y)
end

-- Pings (F8): marcador com o ícone do ping (nunca só a cor), na ilha onde foi feito.
function Minimap.addPing(key: string, island: number, position: Vector3, icon: string, color: Color3, expiresAt: number)
	if not map then
		return -- minimapa ainda não montado
	end
	local existing = pingDots[key]
	if existing then
		existing.label:Destroy()
	end
	local size = Theme.PingMinimapDot + 4
	local label = Ui.label("Ping", Theme.Font.Title, size, color, map)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.fromOffset(size, size)
	label.Text = icon
	label.ZIndex = 7
	Ui.outlineText(label)
	pingDots[key] = { label = label, island = island, position = position, expiresAt = expiresAt }
end

function Minimap.removePing(key: string)
	local existing = pingDots[key]
	if existing then
		existing.label:Destroy()
		pingDots[key] = nil
	end
end

local function updatePings(island: number)
	local now = workspace:GetServerTimeNow()
	for key, ping in pingDots do
		if now >= ping.expiresAt then
			Minimap.removePing(key)
			continue
		end
		ping.label.Visible = ping.island == island
		if ping.island == island then
			local p = toMap(island, ping.position)
			ping.label.Position = UDim2.fromScale(p.X, p.Y)
		end
	end
end

local function update()
	local island = MatchClient.myIsland()
	local character = player.Character
	holder.Visible = island ~= nil
	if island == nil then
		return
	end
	updatePings(island)
	if drawnIsland ~= island then
		drawIsland(island)
	end
	local now = os.clock()

	-- Você
	local camera = workspace.CurrentCamera
	local root = character and character:FindFirstChild("HumanoidRootPart")
	me.Visible = root ~= nil and root:IsA("BasePart")
	if root and root:IsA("BasePart") then
		place(me, island, root.Position)
		if camera then
			local look = camera.CFrame.LookVector
			me.Rotation = math.deg(math.atan2(look.X, -look.Z))
		end
	end

	-- Parceiro
	local partner = MatchClient.partnerPlayer()
	local partnerRoot = partner and partner.Character and partner.Character:FindFirstChild("HumanoidRootPart")
	local partnerIsland = partner and partner.Character and partner.Character:GetAttribute(MatchTypes.Attr.Island)
	ally.Visible = partnerRoot ~= nil and partnerRoot:IsA("BasePart") and partnerIsland == island
	if partnerRoot and partnerRoot:IsA("BasePart") then
		place(ally, island, partnerRoot.Position)
	end

	-- Zona
	local snapshot = MatchClient.get()
	local started = snapshot and snapshot.phase == "Combat" and snapshot.combatStartedAt
	if started then
		local elapsed = workspace:GetServerTimeNow() - started
		local radius = WorldLayout.zoneRadius(elapsed)
		local size = islandExtent(island)
		local span = math.max(size.X, size.Y) * (1 + 2 * CFG.Padding)
		zoneRing.Visible = elapsed >= MatchConfig.Zone.StartsAt
		zoneRing.Size = UDim2.fromScale(2 * radius / span, 2 * radius / span)
	else
		zoneRing.Visible = false
	end

	-- Inimigos: só vistos (e um instante depois)
	if now - lastRefresh >= CFG.RefreshSeconds then
		lastRefresh = now
		for _, model in TeamMarkers.seenEnemies() do
			enemySeenAt[model] = now
		end
	end
	local color = enemyColor()
	for model, seenAt in enemySeenAt do
		local alive = model.Parent ~= nil and model:GetAttribute(CombatNames.Attr.Alive) == true
		local existing = enemyDots[model]
		if not alive or now - seenAt > CFG.EnemySeenSeconds then
			enemySeenAt[model] = nil
			if existing then
				existing:Destroy()
				enemyDots[model] = nil
			end
			continue
		end
		local frameDot = existing or dot("Enemy", color, 8)
		enemyDots[model] = frameDot
		frameDot.BackgroundColor3 = color
		place(frameDot, island, model:GetPivot().Position)
	end
end

local function build()
	gui = Ui.screen("Minimap", 3, Enum.ScreenInsets.CoreUISafeInsets)
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 400)
	local small = math.min(viewport.X, viewport.Y) < CombatConfig.TouchLayout.LargeScreenMinSide
	local size = if small then Theme.Hud.MinimapSizeSmall else Theme.Hud.MinimapSize

	holder = Ui.frame("Holder", gui)
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.new(1, -Theme.ScreenMargin, 0, Theme.ScreenMargin / 2)
	holder.Size = UDim2.fromOffset(size, size)
	holder.Visible = false

	canvas = Instance.new("CanvasGroup")
	canvas.Name = "Circle"
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundColor3 = COLORS.Background
	canvas.BackgroundTransparency = Theme.MinimapBackgroundTransparency
	canvas.BorderSizePixel = 0
	Ui.corner(canvas, size)
	canvas.Parent = holder
	local ring = Ui.frame("Ring", holder)
	ring.Size = UDim2.fromScale(1, 1)
	Ui.corner(ring, size)
	Ui.stroke(ring, Theme.Color.PanelBorder, 2)

	map = Ui.frame("Map", canvas)
	map.Size = UDim2.fromScale(1, 1)

	zoneRing = Ui.frame("Zone", map)
	zoneRing.AnchorPoint = Vector2.new(0.5, 0.5)
	zoneRing.Position = UDim2.fromScale(0.5, 0.5)
	zoneRing.ZIndex = 4
	zoneRing.Visible = false
	Ui.corner(zoneRing, 999)
	Ui.stroke(zoneRing, COLORS.Zone, 2)

	ally = dot("Ally", COLORS.Ally, 9)
	me = Ui.label("Me", Theme.Font.Title, 14, COLORS.Me, map)
	me.AnchorPoint = Vector2.new(0.5, 0.5)
	me.Size = UDim2.fromOffset(14, 14)
	me.Text = "▲"
	me.ZIndex = 6
	Ui.outlineText(me)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function Minimap.Start()
	if not MatchClient.isEnabled() then
		return
	end
	build()
	MatchClient.onChanged(function(snapshot: MatchTypes.Snapshot)
		if snapshot.phase == "Draw" then
			drawnIsland = nil -- ilha nova a cada sorteio (e o mapa pode ter sido montado de novo)
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return Minimap
