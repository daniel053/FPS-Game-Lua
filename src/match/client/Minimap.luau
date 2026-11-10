--!strict
-- Minimapa redondo (ESTILO T6, GDD 7.6), canto superior direito, só enquanto o jogador está numa ilha:
--   * a ilha vista de cima, norte para cima (não gira), com as construções desenhadas a partir das
--     peças do mapa (serve para as ilhas cinza e para os mapas finais da F10);
--   * a zona (círculo roxo) quando começa a fechar;
--   * você (seta na direção da câmera), o parceiro (ponto verde) e os inimigos só quando vistos
--     (contorno ligado), que continuam por um instante depois de sumir.
-- Sem neon. Pings (F8) entram aqui depois.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CombatNames = require(Shared.Combat.CombatNames)
local CombatConfig = require(Shared.Config.CombatConfig)
local MapConfig = require(Shared.Config.MapConfig)
local MatchTypes = require(Shared.Match.MatchTypes)
local MatchConfig = require(Shared.Config.MatchConfig)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.Ui)
local UiConfig = require(Shared.Config.UiConfig)
local WorldLayout = require(Shared.Match.WorldLayout)

local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local TeamMarkers = require(script.Parent.Parent.Combat.TeamMarkers)
local MatchClient = require(script.Parent.MatchClient)

local CFG = UiConfig.Minimap
local COLORS = Theme.Minimap
local WORLD_FOLDER = "MatchWorld"

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

local function islandExtent(): Vector2
	return MapConfig.Gray.IslandSize
end

-- Posição no mapa (0 a 1) de um ponto do mundo, para a ilha atual.
local function toMap(island: number, position: Vector3): Vector2
	local center = WorldLayout.islandCenter(island)
	local size = islandExtent()
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

-- Desenha as construções da ilha: peças acima do chão, vistas de cima.
local function drawIsland(island: number)
	for _, child in map:GetChildren() do
		if child:GetAttribute("Static") then
			child:Destroy()
		end
	end
	drawnIsland = island
	local center = WorldLayout.islandCenter(island)
	local size = islandExtent()
	local span = math.max(size.X, size.Y) * (1 + 2 * CFG.Padding)

	local ground = Ui.frame("Ground", map)
	ground:SetAttribute("Static", true)
	ground.AnchorPoint = Vector2.new(0.5, 0.5)
	ground.Position = UDim2.fromScale(0.5, 0.5)
	ground.Size = UDim2.fromScale(size.X / span, size.Y / span)
	ground.BackgroundTransparency = 0
	ground.BackgroundColor3 = COLORS.Island
	Ui.corner(ground, 4)

	local world = workspace:FindFirstChild(WORLD_FOLDER)
	local folder = world and world:FindFirstChild(`Island{island}`)
	if folder == nil then
		return
	end
	for _, part in folder:GetDescendants() do
		if not part:IsA("BasePart") or part.Transparency >= 0.9 then
			continue
		end
		local top = part.Position.Y + part.Size.Y / 2
		if top < center.Y + 1 or part.Size.X >= size.X * 0.9 then
			continue -- chão e peças rasas
		end
		local rect = Ui.frame("Block", map)
		rect:SetAttribute("Static", true)
		rect.AnchorPoint = Vector2.new(0.5, 0.5)
		local p = toMap(island, part.Position)
		rect.Position = UDim2.fromScale(p.X, p.Y)
		local _, yaw, _ = part.CFrame:ToOrientation()
		rect.Rotation = -math.deg(yaw)
		rect.Size = UDim2.fromScale(part.Size.X / span, part.Size.Z / span)
		rect.BackgroundTransparency = 0
		rect.BackgroundColor3 = COLORS.Cover
		rect.ZIndex = 2
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

local function update()
	local island = MatchClient.myIsland()
	local character = player.Character
	holder.Visible = island ~= nil
	if island == nil then
		return
	end
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
		local size = islandExtent()
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
