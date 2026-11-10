--!strict
-- Marcação de aliado e inimigo (GDD 7.6) [DECIDIDO]. A regra fica em Shared/Combat/MarkerRules;
-- aqui só se aplica na tela:
--   * inimigo à vista: contorno vermelho (ou a cor de acessibilidade) pulsando devagar, só no que
--     aparece (não atravessa paredes), e barra de vida vermelha sobre a cabeça;
--   * aliado à vista: barra de vida verde e nome; com o corpo todo escondido: silhueta verde
--     através da parede;
--   * barra: vida na cor do time e uma linha azul fina de escudo em cima;
--   * do mirante: nome de quem duela na cor da equipe.
-- A cada 0,1 s, raios da câmera até cabeça, tronco, mãos e pés decidem se alguém está à vista.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CharacterConfig = require(Shared.Config.CharacterConfig)
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local MarkerRules = require(Shared.Combat.MarkerRules)
local MatchTypes = require(Shared.Match.MatchTypes)
local TeamColors = require(Shared.Config.TeamColors)
local Theme = require(Shared.Config.Theme)

local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local CombatEffects = require(script.Parent.CombatEffects)
local Smoke = require(script.Parent.Smoke)

local ATTR = CombatNames.Attr
local CFG = CombatConfig.Markers
local HEALTH = CharacterConfig.Health

-- Pontos do corpo checados (R15 e R6)
local BODY_POINTS = {
	{ "Head" },
	{ "UpperTorso", "Torso" },
	{ "LeftHand", "Left Arm" },
	{ "RightHand", "Right Arm" },
	{ "LeftFoot", "Left Leg" },
	{ "RightFoot", "Right Leg" },
}

type Overhead = {
	gui: BillboardGui,
	name: TextLabel,
	barHolder: Frame,
	hpFill: Frame,
	shieldFill: Frame,
}

type Tracked = {
	model: Model,
	highlight: Highlight,
	overhead: Overhead?,
	connections: { RBXScriptConnection },
	state: MarkerRules.State,
}

local TeamMarkers = {}

local player = Players.LocalPlayer
local tracked: { [Model]: Tracked } = {}

local sightParams = RaycastParams.new()
sightParams.CollisionGroup = CombatNames.Groups.SightRay
sightParams.FilterType = Enum.RaycastFilterType.Exclude

local function myTeam(): string?
	local teamId = player:GetAttribute(ATTR.TeamId)
	return if typeof(teamId) == "string" then teamId else nil
end

local function enemyColor(): Color3
	local profile = PlayerDataClient.get()
	local choice = if profile then profile.settings.enemyOutlineColor else "red"
	return Theme.EnemyOutline[choice] or Theme.EnemyOutline.red
end

local function reduceEffects(): boolean
	local profile = PlayerDataClient.get()
	return profile ~= nil and profile.settings.reduceEffects
end

local function viewerOnMirante(): boolean
	return player:GetAttribute(MatchTypes.Attr.Location) == MatchTypes.MiranteLocation
		and player.Character ~= nil
		and player.Character:GetAttribute(MatchTypes.Attr.Island) == nil
end

local function frame(parent: Instance, color: Color3, transparency: number): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.Parent = parent
	return f
end

local function makeOverhead(model: Model): Overhead?
	local head = model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return nil
	end
	local nameHeight = Theme.TextSize.Body + 4
	local gui = Instance.new("BillboardGui")
	gui.Name = "Marker"
	gui.Size =
		UDim2.fromOffset(math.max(CFG.BarWidth, 160), nameHeight + CFG.ShieldLineHeight + CFG.BarGap + CFG.BarHeight)
	gui.SizeOffset = Vector2.new(0, 0.5)
	gui.StudsOffset = Vector3.new(0, head.Size.Y / 2 + CFG.BarOffsetStuds, 0)
	gui.AlwaysOnTop = true -- só aparece quando a regra decide (já checada por raios)
	gui.LightInfluence = 0
	gui.MaxDistance = CFG.BarMaxDistance
	gui.Enabled = false

	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, nameHeight)
	name.FontFace = Theme.Font.BodyStrong
	name.TextSize = Theme.TextSize.Body
	name.TextColor3 = Theme.Marker.AllyName
	name.TextStrokeTransparency = 0.3
	local display = model:GetAttribute(ATTR.DisplayName)
	name.Text = if typeof(display) == "string" then display else model.Name
	name.Parent = gui

	-- Linha do escudo + barra de vida
	local holder = Instance.new("Frame")
	holder.Name = "Bar"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.fromScale(0.5, 1)
	holder.Size = UDim2.fromOffset(CFG.BarWidth, CFG.ShieldLineHeight + CFG.BarGap + CFG.BarHeight)
	holder.Parent = gui

	local shieldBack = frame(holder, Theme.Marker.BarBack, Theme.MarkerBarBackTransparency)
	shieldBack.Size = UDim2.new(1, 0, 0, CFG.ShieldLineHeight)
	local shieldFill = frame(shieldBack, Theme.Marker.ShieldLine, 0)
	shieldFill.Size = UDim2.fromScale(1, 1)

	local hpBack = frame(holder, Theme.Marker.BarBack, Theme.MarkerBarBackTransparency)
	hpBack.Position = UDim2.fromOffset(0, CFG.ShieldLineHeight + CFG.BarGap)
	hpBack.Size = UDim2.new(1, 0, 0, CFG.BarHeight)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Marker.BarBorder
	stroke.Thickness = 1
	stroke.Parent = hpBack
	local hpFill = frame(hpBack, Theme.Marker.AllyBar, 0)
	hpFill.Size = UDim2.fromScale(1, 1)

	gui.Adornee = head
	gui.Parent = CombatEffects.getFolder()
	return { gui = gui, name = name, barHolder = holder, hpFill = hpFill, shieldFill = shieldFill }
end

local function numberAttr(model: Model, name: string): number
	local value = model:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function updateBar(entry: Tracked)
	local overhead = entry.overhead
	if overhead == nil then
		return
	end
	local hp, shield = MarkerRules.barFractions(
		numberAttr(entry.model, ATTR.Hp),
		numberAttr(entry.model, ATTR.Shield),
		HEALTH.MaxHp,
		HEALTH.MaxShield
	)
	overhead.hpFill.Size = UDim2.fromScale(hp, 1)
	overhead.shieldFill.Size = UDim2.fromScale(shield, 1)
end

-- Aplica um estado da regra na tela.
local function apply(entry: Tracked, state: MarkerRules.State)
	entry.state = state
	local highlight = entry.highlight
	if state.outline == "Enemy" then
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded -- só desenha o que está visível
		local color = enemyColor()
		highlight.OutlineColor = color
		highlight.FillColor = color
		highlight.FillTransparency = CFG.EnemyFillTransparency
		highlight.Enabled = true
	elseif state.outline == "AllySilhouette" then
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- atravessa a parede
		highlight.OutlineColor = Theme.Marker.AllySilhouette
		highlight.FillColor = Theme.Marker.AllySilhouette
		highlight.FillTransparency = CFG.AllySilhouetteFillTransparency
		highlight.OutlineTransparency = 0
		highlight.Enabled = true
	else
		highlight.Enabled = false
	end

	local wantsOverhead = state.bar ~= "None" or state.name ~= "None"
	if wantsOverhead and entry.overhead == nil then
		entry.overhead = makeOverhead(entry.model)
		updateBar(entry)
	end
	local overhead = entry.overhead
	if overhead == nil then
		return
	end
	overhead.gui.Enabled = wantsOverhead
	if not wantsOverhead then
		return
	end
	overhead.barHolder.Visible = state.bar ~= "None"
	overhead.hpFill.BackgroundColor3 = if state.bar == "Enemy" then enemyColor() else Theme.Marker.AllyBar
	overhead.name.Visible = state.name ~= "None"
	if state.name == "Team" then
		local teamId = entry.model:GetAttribute(ATTR.TeamId)
		overhead.name.TextColor3 = TeamColors.getColor(if typeof(teamId) == "string" then teamId else "")
	else
		overhead.name.TextColor3 = Theme.Marker.AllyName
	end
end

-- Algum ponto do corpo à vista da câmera?
local function anyPartVisible(model: Model, origin: Vector3): boolean
	local filter: { Instance } = { model, CombatEffects.getFolder() }
	if player.Character then
		table.insert(filter, player.Character)
	end
	local camera = workspace.CurrentCamera
	if camera then
		table.insert(filter, camera)
	end
	sightParams.FilterDescendantsInstances = filter
	for _, names in BODY_POINTS do
		for _, partName in names do
			local part = model:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				if workspace:Raycast(origin, part.Position - origin, sightParams) == nil then
					return true
				end
				break
			end
		end
	end
	return false
end

local function evaluate(entry: Tracked, origin: Vector3?, onMirante: boolean)
	local model = entry.model
	local mine = player.Character and player.Character:GetAttribute(MatchTypes.Attr.Island)
	local targetIsland = model:GetAttribute(MatchTypes.Attr.Island)
	local isSelf = model == player.Character
	local alive = model:GetAttribute(ATTR.Alive) == true
	local sameIsland = player.Character ~= nil and targetIsland == mine
	local isPartner = not isSelf and model:GetAttribute(ATTR.TeamId) == myTeam()

	local visible = false
	local smoke = false
	if origin and alive and not isSelf and sameIsland and not onMirante then
		visible = anyPartVisible(model, origin)
		if visible and not isPartner then
			local hitbox = model:FindFirstChild(CombatNames.HitboxName)
			local target = if hitbox and hitbox:IsA("BasePart") then hitbox.Position else model:GetPivot().Position
			smoke = Smoke.blocks(origin, target)
		end
	end

	apply(
		entry,
		MarkerRules.decide({
			isSelf = isSelf,
			alive = alive,
			isPartner = isPartner,
			sameIsland = sameIsland,
			anyPartVisible = visible,
			behindSmoke = smoke,
			viewerOnMirante = onMirante,
			targetOnIsland = targetIsland ~= nil,
		})
	)
end

local function track(instance: Instance)
	if not instance:IsA("Model") or tracked[instance] then
		return
	end
	local model = instance
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0
	highlight.Enabled = false
	highlight.Adornee = model
	highlight.Parent = CombatEffects.getFolder()
	local entry: Tracked = {
		model = model,
		highlight = highlight,
		overhead = nil,
		connections = {},
		state = { outline = "None", bar = "None", name = "None" },
	}
	tracked[model] = entry
	for _, attr in { ATTR.Hp, ATTR.Shield } do
		table.insert(
			entry.connections,
			model:GetAttributeChangedSignal(attr):Connect(function()
				updateBar(entry)
			end)
		)
	end
	table.insert(
		entry.connections,
		model:GetAttributeChangedSignal(ATTR.DisplayName):Connect(function()
			local overhead = entry.overhead
			local display = model:GetAttribute(ATTR.DisplayName)
			if overhead and typeof(display) == "string" then
				overhead.name.Text = display
			end
		end)
	)
end

local function untrack(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local entry = tracked[instance]
	if entry == nil then
		return
	end
	tracked[instance] = nil
	for _, connection in entry.connections do
		connection:Disconnect()
	end
	entry.highlight:Destroy()
	if entry.overhead then
		entry.overhead.gui:Destroy()
	end
end

local function checkAll()
	local camera = workspace.CurrentCamera
	local origin = if camera then camera.CFrame.Position else nil
	local onMirante = viewerOnMirante()
	for _, entry in tracked do
		evaluate(entry, origin, onMirante)
	end
end

-- Pulso do contorno do inimigo (devagar; ESTILO 2.7, exceção do GDD 7.6)
local function pulse()
	local value = MarkerRules.pulse(
		os.clock(),
		CFG.EnemyPulseSeconds,
		CFG.EnemyOutlineTransparencyMin,
		CFG.EnemyOutlineTransparencyMax,
		reduceEffects()
	)
	for _, entry in tracked do
		if entry.state.outline == "Enemy" then
			entry.highlight.OutlineTransparency = value
		end
	end
end

function TeamMarkers.Start()
	CollectionService:GetInstanceAddedSignal(CombatNames.CombatantTag):Connect(track)
	CollectionService:GetInstanceRemovedSignal(CombatNames.CombatantTag):Connect(untrack)
	for _, instance in CollectionService:GetTagged(CombatNames.CombatantTag) do
		track(instance)
	end
	PlayerDataClient.onChanged(function()
		for _, entry in tracked do
			apply(entry, entry.state) -- cor de acessibilidade pode ter mudado
		end
	end)
	RunService.RenderStepped:Connect(pulse)

	task.spawn(function()
		while true do
			checkAll()
			task.wait(CFG.CheckSeconds)
		end
	end)
end

return TeamMarkers
