--!strict
-- Minimapa redondo (ESTILO T6, GDD 7.6), canto superior direito, só enquanto o jogador está numa ilha:
--   * a ilha vista de cima, norte para cima (não gira), com as construções desenhadas a partir das
--     peças do mapa (serve para as ilhas cinza e para os mapas finais da F10);
--   * a zona (círculo roxo) quando começa a fechar;
--   * você (seta branca na direção da câmera), o parceiro (seta verde na direção dele) e os inimigos só
--     quando vistos (contorno ligado), que continuam por um instante depois de sumir;
--   * "X" onde alguém foi derrubado nesta ilha: verde = aliado, cor de inimigo = inimigo; some aos poucos,
--     no máximo alguns de cada vez, e limpa a cada rodada;
--   * tamanho escolhido nas configurações (settings.minimapSize), aplicado na hora;
--   * os pings da dupla (F8): ícone na cor do ping, até expirar (Minimap.addPing).
-- Sem neon.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CombatNames = require(Shared.Combat.CombatNames)
local CombatTypes = require(Shared.Combat.CombatTypes)
local CombatConfig = require(Shared.Config.CombatConfig)
local MatchTypes = require(Shared.Match.MatchTypes)
local Remotes = require(Shared.Remotes)
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
local ally: TextLabel
local baseSize = 0 -- tamanho do minimapa no tamanho "médio" (px), conforme a tela
local sizeChangedCallbacks: { (number) -> () } = {}
type DeathMark = { label: TextLabel, island: number, position: Vector3, at: number }
local deathMarks: { DeathMark } = {}
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

-- Marcadores de morte ---------------------------------------------------------------------------

local function removeDeathMark(index: number)
	deathMarks[index].label:Destroy()
	table.remove(deathMarks, index)
end

local function clearDeathMarks()
	for i = #deathMarks, 1, -1 do
		removeDeathMark(i)
	end
end

-- "X" no lugar onde alguém foi derrubado (nunca só a cor: a forma é o X, ESTILO 5).
local function addDeathMark(data: CombatTypes.KnockedData)
	if not map or data.island == nil then
		return
	end
	local myTeam = MatchClient.myTeamId()
	local isAlly = myTeam ~= nil and data.teamId == myTeam
	while #deathMarks >= CFG.DeathMarkMax do
		removeDeathMark(1) -- o mais antigo sai
	end
	local size = CFG.DeathMarkSize
	local label = Ui.label("Death", Theme.Font.Title, size, if isAlly then COLORS.Ally else enemyColor(), map)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.fromOffset(size, size)
	label.Text = "✕"
	label.ZIndex = 4 -- embaixo de você, do parceiro e dos inimigos vivos
	Ui.outlineText(label)
	table.insert(deathMarks, { label = label, island = data.island, position = data.position, at = os.clock() })
end

local function updateDeathMarks(island: number)
	local now = os.clock()
	for i = #deathMarks, 1, -1 do
		local mark = deathMarks[i]
		local age = now - mark.at
		if age >= CFG.DeathMarkSeconds then
			removeDeathMark(i)
			continue
		end
		mark.label.Visible = mark.island == island
		if mark.island == island then
			place(mark.label, island, mark.position)
			local fadeFrom = CFG.DeathMarkSeconds - CFG.DeathMarkFadeSeconds
			local fade = math.clamp((age - fadeFrom) / CFG.DeathMarkFadeSeconds, 0, 1)
			mark.label.TextTransparency = fade
			local stroke = mark.label:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = math.max(stroke.Transparency, fade)
			end
		end
	end
end

-- Tamanho ----------------------------------------------------------------------------------------

local function sizeScale(): number
	local profile = PlayerDataClient.get()
	local id = if profile then profile.settings.minimapSize else "medium"
	return CFG.SizeScale[id] or 1
end

-- Tamanho atual do minimapa em pixels (o topo da partida encolhe para não encostar nele).
function Minimap.pixelSize(): number
	local base = if baseSize > 0 then baseSize else Theme.Hud.MinimapSize -- antes de montar
	return math.floor(base * sizeScale() + 0.5)
end

function Minimap.onSizeChanged(callback: (number) -> ())
	table.insert(sizeChangedCallbacks, callback)
end

local function applySize()
	local size = Minimap.pixelSize()
	if holder.Size.X.Offset == size then
		return
	end
	holder.Size = UDim2.fromOffset(size, size)
	for _, callback in sizeChangedCallbacks do
		task.spawn(callback, size)
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
	updateDeathMarks(island)
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

	-- Parceiro: seta verde na direção para onde ele olha (vivo e na mesma ilha)
	local partner = MatchClient.partnerPlayer()
	local partnerCharacter = partner and partner.Character
	local partnerRoot = partnerCharacter and partnerCharacter:FindFirstChild("HumanoidRootPart")
	local partnerIsland = partnerCharacter and partnerCharacter:GetAttribute(MatchTypes.Attr.Island)
	local partnerAlive = partnerCharacter ~= nil and partnerCharacter:GetAttribute(CombatNames.Attr.Alive) ~= false
	ally.Visible = partnerRoot ~= nil and partnerRoot:IsA("BasePart") and partnerIsland == island and partnerAlive
	if partnerRoot and partnerRoot:IsA("BasePart") then
		place(ally, island, partnerRoot.Position)
		local look = partnerRoot.CFrame.LookVector
		ally.Rotation = math.deg(math.atan2(look.X, -look.Z))
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
	baseSize = if small then Theme.Hud.MinimapSizeSmall else Theme.Hud.MinimapSize
	local size = Minimap.pixelSize()

	holder = Ui.frame("Holder", gui)
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.new(1, -Theme.ScreenMargin, 0, Theme.ScreenMargin / 2)
	holder.Size = UDim2.fromOffset(size, size)
	holder.Visible = false

	-- Cantos de 999 px: o círculo continua círculo em qualquer tamanho escolhido.
	canvas = Instance.new("CanvasGroup")
	canvas.Name = "Circle"
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundColor3 = COLORS.Background
	canvas.BackgroundTransparency = Theme.MinimapBackgroundTransparency
	canvas.BorderSizePixel = 0
	Ui.corner(canvas, 999)
	canvas.Parent = holder
	local ring = Ui.frame("Ring", holder)
	ring.Size = UDim2.fromScale(1, 1)
	Ui.corner(ring, 999)
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

	local allySize = CFG.AllyArrowSize
	ally = Ui.label("Ally", Theme.Font.Title, allySize, COLORS.Ally, map)
	ally.AnchorPoint = Vector2.new(0.5, 0.5)
	ally.Size = UDim2.fromOffset(allySize, allySize)
	ally.Text = "▲"
	ally.ZIndex = 5
	Ui.outlineText(ally)
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
	local lastPhase: MatchTypes.Phase? = nil
	MatchClient.onChanged(function(snapshot: MatchTypes.Snapshot)
		if snapshot.phase == "Draw" then
			drawnIsland = nil -- ilha nova a cada sorteio (e o mapa pode ter sido montado de novo)
		end
		-- Rodada nova (preparação) ou partida acabando: os X da rodada anterior saem.
		if snapshot.phase ~= lastPhase and snapshot.phase ~= "Combat" and snapshot.phase ~= "RoundEnd" then
			clearDeathMarks()
		end
		lastPhase = snapshot.phase
	end)
	Remotes.event("CombatEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Knocked" then
			addDeathMark(data :: CombatTypes.KnockedData)
		end
	end)
	PlayerDataClient.onChanged(function()
		applySize()
	end)
	RunService.RenderStepped:Connect(update)
end

return Minimap
