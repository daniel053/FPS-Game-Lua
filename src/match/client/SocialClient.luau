--!strict
-- Comunicação sem voz e sem texto no cliente (GDD 12.3 e 12.4, F8). Só pede e mostra; o servidor
-- (SocialService) confere tudo e decide quem recebe.
--   * Ping: PC Z (toque curto = rápido, segurar = roda) ou botão do meio do mouse; controle R3;
--     celular botão PING (toque = rápido, segurar = roda). Rápido = "Inimigo aqui" se a mira está num
--     inimigo, senão "Vou para cá". Só na ilha de duelo.
--   * Frases: PC V; controle L3; celular FRASES. A roda também leva aos emotes e ao elogio quando valem.
--   * Emotes: PC G; celular EMOTES (no mirante e no fim da rodada).
--   * Elogio: botão no fim da rodada (PC H) e na tela final.
-- Mostra: marcador do ping no mundo e no minimapa, legenda, balão em cima do parceiro.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local AudioConfig = require(Shared.Config.AudioConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local MatchTypes = require(Shared.Match.MatchTypes)
local Remotes = require(Shared.Remotes)
local SocialConfig = require(Shared.Config.SocialConfig)
local SocialRules = require(Shared.Social.SocialRules)
local SocialTypes = require(Shared.Social.SocialTypes)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local TouchLayout = require(Shared.Ui.TouchLayout)
local Ui = require(Shared.Ui.Ui)
local UiConfig = require(Shared.Config.UiConfig)

local Captions = require(script.Parent.Parent.Combat.Captions)
local CombatEffects = require(script.Parent.Parent.Combat.CombatEffects)
local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local Widgets = require(script.Parent.Parent.Common.Ui.Widgets)
local MatchClient = require(script.Parent.MatchClient)
local Minimap = require(script.Parent.Minimap)
local SocialWheel = require(script.Parent.SocialWheel)

local S = Strings.Social
local KEYS = UiConfig.Keys
local LABELS = UiConfig.KeyLabels

type Marker = { key: string, attachment: Attachment, gui: BillboardGui, distance: TextLabel, expiresAt: number }

local SocialClient = {}

local player = Players.LocalPlayer
local requestRemote: RemoteEvent? = nil
local markers: { Marker } = {}
local praised: { [string]: boolean } = {} -- chaves de elogio já usadas (só para mostrar)
local praiseCallbacks: { () -> () } = {}

local touchGui: ScreenGui
local pingButton: TextButton
local phraseButton: TextButton
local emoteButton: TextButton
local praiseGui: ScreenGui
local praiseButton: Widgets.Button
local bubble: BillboardGui? = nil

local function request(kind: SocialTypes.RequestName, arg: any?)
	if requestRemote then
		requestRemote:FireServer(kind, arg)
	end
end

local function phase(): string?
	local snapshot = MatchClient.get()
	return if snapshot then snapshot.phase else nil
end

local function round(): number
	local snapshot = MatchClient.get()
	return if snapshot then snapshot.round else 0
end

-- Pings ------------------------------------------------------------------------------------------

local function enemyColor(): Color3
	local profile = PlayerDataClient.get()
	local id = if profile then profile.settings.enemyOutlineColor else "red"
	return Theme.EnemyOutline[id] or Theme.Color.Danger
end

local function pingColor(kind: string): Color3
	if kind == "Enemy" then
		return enemyColor()
	elseif kind == "Danger" then
		return Theme.Social.PingDanger
	elseif kind == "Help" then
		return Theme.Social.PingHelp
	end
	return Theme.Social.PingGoing
end

local function pingInfo(kind: string): { label: string, short: string, icon: string }
	return S.Pings[kind] or S.Pings.Going
end

-- Para onde a mira aponta: (posição, mira num inimigo?)
local function aimTarget(): (Vector3?, boolean)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil, false
	end
	local params = RaycastParams.new()
	params.CollisionGroup = CombatNames.Groups.ShotRay
	local ignore: { Instance } = { CombatEffects.getFolder() }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	local origin = camera.CFrame.Position
	local result = workspace:Raycast(origin, camera.CFrame.LookVector * SocialConfig.Ping.MaxDistance, params)
	if result == nil then
		return nil, false
	end
	local model = result.Instance:FindFirstAncestorWhichIsA("Model")
	local team = model and model:GetAttribute(CombatNames.Attr.TeamId)
	local isEnemy = team ~= nil and team ~= MatchClient.myTeamId() and model ~= player.Character
	return result.Position, isEnemy
end

local function canPing(): boolean
	return SocialRules.canPing(MatchClient.myLocation())
end

local function sendPing(kind: string)
	local position = aimTarget()
	if position == nil then
		Captions.show(S.PingNoTarget, Theme.Color.TextSecondary)
		return
	end
	request("Ping", { kind = kind, position = position } :: SocialTypes.PingRequest)
end

local function quickPing()
	if not canPing() then
		return
	end
	local position, onEnemy = aimTarget()
	if position == nil then
		Captions.show(S.PingNoTarget, Theme.Color.TextSecondary)
		return
	end
	local kind = if onEnemy then SocialConfig.Ping.QuickOnEnemy else SocialConfig.Ping.QuickDefault
	request("Ping", { kind = kind, position = position } :: SocialTypes.PingRequest)
end

local function openPingWheel()
	if not canPing() then
		return
	end
	local options: { SocialWheel.Option } = {}
	for _, kind in SocialConfig.Ping.Kinds do
		local info = pingInfo(kind)
		table.insert(options, { id = kind, text = info.icon .. " " .. info.label, color = pingColor(kind) })
	end
	SocialWheel.open(S.PingWheel, options, sendPing)
end

local function removeMarker(index: number)
	local marker = table.remove(markers, index)
	if marker then
		marker.gui:Destroy()
		marker.attachment:Destroy()
		Minimap.removePing(marker.key)
	end
end

local function showPing(data: SocialTypes.PingData)
	local info = pingInfo(data.kind)
	local color = pingColor(data.kind)
	local mine = data.fromUserId == player.UserId
	local key = `{data.fromUserId}_{data.expiresAt}`

	-- No máximo N marcadores de cada jogador: o mais velho some
	local count = 0
	for i = #markers, 1, -1 do
		if string.sub(markers[i].key, 1, #tostring(data.fromUserId) + 1) == `{data.fromUserId}_` then
			count += 1
			if count >= SocialConfig.Ping.MaxActive then
				removeMarker(i)
			end
		end
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "Ping"
	attachment.WorldPosition = data.position
	attachment.Parent = workspace.Terrain

	local size = Theme.PingMarkerSize
	local gui = Instance.new("BillboardGui")
	gui.Name = "PingMarker"
	gui.Adornee = attachment
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(120, size + 34)
	gui.StudsOffset = Vector3.new(0, 1.5, 0)
	gui.ResetOnSpawn = false
	local icon = Ui.label("Icon", Theme.Font.Title, size, color, gui)
	icon.Size = UDim2.new(1, 0, 0, size)
	icon.Text = info.icon
	Ui.outlineText(icon)
	local name = Ui.label("Name", Theme.Font.Title, Theme.TextSize.Label, color, gui)
	name.Position = UDim2.fromOffset(0, size)
	name.Size = UDim2.new(1, 0, 0, 16)
	name.Text = info.short
	Ui.outlineText(name)
	local distance = Ui.label("Distance", Theme.Font.Number, Theme.TextSize.Label, Theme.Color.TextPrimary, gui)
	distance.Position = UDim2.fromOffset(0, size + 16)
	distance.Size = UDim2.new(1, 0, 0, 16)
	Ui.outlineText(distance)
	gui.Parent = player:WaitForChild("PlayerGui")

	table.insert(
		markers,
		{ key = key, attachment = attachment, gui = gui, distance = distance, expiresAt = data.expiresAt }
	)
	Minimap.addPing(key, data.island, data.position, info.icon, color, data.expiresAt)
	Captions.show(string.format(S.PingCaption, if mine then S.You else data.name, info.label), color)
	if not mine then
		CombatEffects.playSound(AudioConfig.Ping)
	end
end

local function updateMarkers()
	local now = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	for i = #markers, 1, -1 do
		local marker = markers[i]
		if now >= marker.expiresAt then
			removeMarker(i)
		elseif camera then
			local studs = (camera.CFrame.Position - marker.attachment.WorldPosition).Magnitude
			marker.distance.Text = string.format(S.Meters, math.floor(studs * 0.28 + 0.5)) -- 1 stud ≈ 0,28 m
		end
	end
end

local function clearMarkers()
	for i = #markers, 1, -1 do
		removeMarker(i)
	end
end

-- Frases -----------------------------------------------------------------------------------------

local function praiseKey(): string?
	return SocialRules.praiseKey(phase(), round())
end

local function canPraise(): boolean
	local key = praiseKey()
	return key ~= nil and not praised[key] and MatchClient.partnerPlayer() ~= nil
end

function SocialClient.canPraise(): boolean
	return canPraise()
end

function SocialClient.praise()
	local key = praiseKey()
	if key == nil or praised[key] or MatchClient.partnerPlayer() == nil then
		return
	end
	praised[key] = true
	request("Praise")
	for _, callback in praiseCallbacks do
		task.spawn(callback)
	end
end

-- A tela final mostra "ELOGIADO" depois de elogiar por qualquer caminho.
function SocialClient.onPraiseChanged(callback: () -> ())
	table.insert(praiseCallbacks, callback)
end

local function canEmote(): boolean
	return SocialRules.canEmote(MatchClient.myLocation(), phase())
end

local function openEmoteWheel()
	if not canEmote() then
		return
	end
	local options: { SocialWheel.Option } = {}
	for _, def in SocialConfig.Emotes.List do
		table.insert(options, { id = def.id, text = S.Emotes[def.id] or def.id })
	end
	SocialWheel.open(S.EmoteWheel, options, function(id: string)
		request("Emote", id)
	end)
end

local function openPhraseWheel()
	if MatchClient.myTeamId() == nil then
		return
	end
	local options: { SocialWheel.Option } = {}
	for _, id in SocialConfig.Phrases.Ids do
		table.insert(options, { id = id, text = S.Phrases[id] or id })
	end
	if canPraise() then
		table.insert(options, { id = "_praise", text = S.PraiseOption, color = Theme.Social.Praise })
	end
	if canEmote() then
		table.insert(options, { id = "_emotes", text = S.ToEmotes })
	end
	SocialWheel.open(S.PhraseWheel, options, function(id: string)
		if id == "_praise" then
			SocialClient.praise()
		elseif id == "_emotes" then
			openEmoteWheel()
		else
			request("Phrase", id)
		end
	end)
end

local function showBubble(target: Player, text: string)
	if bubble then
		bubble:Destroy()
		bubble = nil
	end
	local character = target.Character
	local head = character and character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PhraseBubble"
	gui.Adornee = head
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(200, 34)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.ResetOnSpawn = false
	local label = Ui.label("Text", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Social.PhraseText, gui)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 30)
	label.BackgroundTransparency = Theme.SocialBubbleTransparency
	label.BackgroundColor3 = Theme.Social.PhraseBubble
	label.Text = text
	Ui.corner(label, 8)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = label
	gui.Parent = player:WaitForChild("PlayerGui")
	bubble = gui
	task.delay(SocialConfig.Phrases.BubbleSeconds, function()
		if bubble == gui then
			gui:Destroy()
			bubble = nil
		end
	end)
end

local function showPhrase(data: SocialTypes.PhraseData)
	local text = S.Phrases[data.id] or data.id
	local mine = data.fromUserId == player.UserId
	Captions.show(string.format(S.PhraseCaption, if mine then S.You else data.name, text))
	if not mine then
		CombatEffects.playSound(AudioConfig.Phrase)
		local from = Players:GetPlayerByUserId(data.fromUserId)
		if from then
			showBubble(from, text)
		end
	end
end

-- Teclado, mouse e controle ----------------------------------------------------------------------

-- Segurar abre a roda; soltar depois de segurar escolhe a opção sob o mouse. Toque curto: `onTap`.
local function bindHold(keys: { Enum.KeyCode }, onTap: () -> (), openWheel: () -> (), tapKeepsWheel: boolean)
	local downAt: number? = nil
	local wheelOpenedByHold = false
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not table.find(keys, input.KeyCode) then
			return
		end
		if SocialWheel.isOpen() and not wheelOpenedByHold then
			SocialWheel.close() -- mesma tecla de novo fecha a roda aberta por toque curto
			return
		end
		downAt = os.clock()
		wheelOpenedByHold = false
		local myDown = downAt
		task.delay(SocialConfig.Wheel.HoldSeconds, function()
			if downAt == myDown then
				wheelOpenedByHold = true
				openWheel()
			end
		end)
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if not table.find(keys, input.KeyCode) or downAt == nil then
			return
		end
		downAt = nil
		if wheelOpenedByHold then
			wheelOpenedByHold = false
			if InputDevice.get() == "KeyboardMouse" then
				SocialWheel.release()
			end
		elseif tapKeepsWheel then
			openWheel()
		else
			onTap()
		end
	end)
end

local function bindKeys()
	bindHold({ KEYS.Ping, KEYS.PingPad }, quickPing, openPingWheel, false)
	bindHold({ KEYS.Phrase, KEYS.PhrasePad }, openPhraseWheel, openPhraseWheel, true)
	bindHold({ KEYS.Emote }, openEmoteWheel, openEmoteWheel, true)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			quickPing()
		elseif input.KeyCode == KEYS.Praise and canPraise() then
			SocialClient.praise()
		end
	end)
end

-- Botões de toque --------------------------------------------------------------------------------

local function makeRound(id: string, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = id
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = Theme.Color.PanelBase
	button.BackgroundTransparency = 0.35
	button.AutoButtonColor = false
	button.FontFace = Theme.Font.Title
	button.TextSize = Theme.TextSize.Label
	button.TextColor3 = Theme.Color.TextPrimary
	button.TextScaled = false
	button.Text = text
	Ui.corner(button, 999)
	Ui.stroke(button, Theme.Color.PanelBorder, 2)
	button.Parent = touchGui
	return button
end

local function bindTouchHold(button: TextButton, onTap: () -> (), openWheel: () -> ())
	local downAt: number? = nil
	local opened = false
	button.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		downAt = os.clock()
		opened = false
		local myDown = downAt
		task.delay(SocialConfig.Wheel.HoldSeconds, function()
			if downAt == myDown then
				opened = true
				openWheel()
			end
		end)
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch or downAt == nil then
			return
		end
		downAt = nil
		if not opened then
			onTap()
		end
	end)
end

local function applyTouchLayout()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 400)
	local profile = PlayerDataClient.get()
	local saved = profile and profile.settings.mobileLayout
	local touchButtons: { [string]: TextButton } = { Ping = pingButton, Phrase = phraseButton, Emote = emoteButton }
	for id, button in touchButtons do
		local p = TouchLayout.resolve(id, viewport, saved)
		button.Position = p.position
		button.Size = UDim2.fromOffset(p.size, p.size)
	end
end

local function buildTouch()
	touchGui = Instance.new("ScreenGui")
	touchGui.Name = "SocialTouchControls"
	touchGui.ResetOnSpawn = false
	touchGui.IgnoreGuiInset = true -- mesma área do editor de botões (TouchLayout)
	touchGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	touchGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	touchGui.DisplayOrder = 5
	pingButton = makeRound("Ping", Strings.LayoutEditor.Names.Ping)
	phraseButton = makeRound("Phrase", Strings.LayoutEditor.Names.Phrase)
	emoteButton = makeRound("Emote", Strings.LayoutEditor.Names.Emote)
	bindTouchHold(pingButton, quickPing, openPingWheel)
	phraseButton.Activated:Connect(openPhraseWheel)
	emoteButton.Activated:Connect(openEmoteWheel)
	touchGui.Parent = player:WaitForChild("PlayerGui")
	applyTouchLayout()
end

-- Elogio no fim da rodada ------------------------------------------------------------------------

local function buildPraise()
	praiseGui = Ui.screen("PraiseButton", 12, Enum.ScreenInsets.CoreUISafeInsets)
	praiseGui.Enabled = false
	praiseButton = Widgets.button(praiseGui, S.PraiseShort, "primary", {
		pc = LABELS.Praise,
		arrow = false,
		size = UDim2.fromOffset(240, Theme.Touch.MinTarget),
		textSize = Theme.TextSize.Label,
	})
	praiseButton.root.AnchorPoint = Vector2.new(0.5, 0)
	praiseButton.root.Position = UDim2.new(0.5, 0, 0, 96)
	praiseButton.onClick(SocialClient.praise)
	praiseGui.Parent = player:WaitForChild("PlayerGui")
end

-- Visibilidade -----------------------------------------------------------------------------------

local function refresh()
	local hasTeam = MatchClient.myTeamId() ~= nil
	pingButton.Visible = canPing()
	phraseButton.Visible = hasTeam
	emoteButton.Visible = canEmote()

	-- Elogio: só no fim da rodada (a tela final tem o seu)
	local partner = MatchClient.partnerPlayer()
	local show = phase() == "RoundEnd" and partner ~= nil and canPraise()
	praiseGui.Enabled = show
	if show and partner then
		praiseButton.setText(string.format(S.Praise, partner.DisplayName))
	end
end

function SocialClient.Start()
	if not MatchClient.isEnabled() then
		return
	end
	requestRemote = Remotes.event("SocialRequest")
	buildTouch()
	buildPraise()
	bindKeys()

	Remotes.event("SocialEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Ping" then
			showPing(data :: SocialTypes.PingData)
		elseif kind == "Phrase" then
			showPhrase(data :: SocialTypes.PhraseData)
		elseif kind == "Emote" then
			Captions.show(string.format(S.EmoteCaption, S.Emotes[data.id] or data.id))
		elseif kind == "Praised" then
			Captions.show(string.format(S.Praised, data.name), Theme.Social.Praise)
			CombatEffects.playSound(AudioConfig.Phrase)
		elseif kind == "PraiseSent" then
			Captions.show(string.format(S.PraiseSent, data.name), Theme.Social.Praise)
		end
	end)

	local lastPhase: string? = nil
	MatchClient.onChanged(function(snapshot: MatchTypes.Snapshot)
		if snapshot.phase ~= lastPhase then
			lastPhase = snapshot.phase
			if snapshot.phase == "Receiving" or snapshot.phase == "Forming" then
				table.clear(praised) -- partida nova
			end
			-- Marcadores valem na preparação e no combate da rodada
			if snapshot.phase ~= "Prep" and snapshot.phase ~= "Combat" then
				clearMarkers()
			end
		end
		refresh()
	end)
	SocialClient.onPraiseChanged(refresh)
	player:GetAttributeChangedSignal(MatchTypes.Attr.Location):Connect(function()
		if not canPing() and SocialWheel.isOpen() then
			SocialWheel.close()
		end
		refresh()
	end)
	player:GetAttributeChangedSignal(CombatNames.Attr.TeamId):Connect(refresh)
	InputDevice.onChanged(refresh)
	PlayerDataClient.onChanged(applyTouchLayout)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyTouchLayout)
	end
	RunService.RenderStepped:Connect(function()
		updateMarkers()
		touchGui.Enabled = InputDevice.get() == "Touch" and not SocialWheel.isOpen()
	end)
	refresh()
end

return SocialClient
