--!strict
-- Tela do lobby, versão SIMPLES da F5 (ESTILO T3; visual final na F7):
--   * esquerda: a dupla (nome, elo, Pronto/Esperando), + CONVIDAR e SAIR DA DUPLA;
--   * direita: cartão "Duelo em dupla", x/2 prontos e o botão JOGAR, que vira
--     "Procurando partida… 5/7" com CANCELAR;
--   * topo direito: moedas (segunda moeda é [ABERTO], não aparece);
--   * janela de convite (jogadores do servidor + convite nativo do Roblox) e convite recebido.
-- Celular: só toque. PC: atalhos sempre visíveis ([Enter] jogar/cancelar, [G] convidar,
-- [Y]/[N] aceitar/recusar). Controle: X jogar/cancelar, Y convidar, seleção pelos botões.
-- No PC o mouse fica livre no lobby (é um menu); a câmera continua em primeira pessoa.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage.Shared
local LobbyTypes = require(Shared.Queue.LobbyTypes)
local QueueConfig = require(Shared.Config.QueueConfig)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.ProvisionalUi)

local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)

local S = Strings.Lobby
local NOTICE_SECONDS = 4
local PANEL_WIDTH = 280

local LobbyScreen = {}

local player = Players.LocalPlayer
local requestEvent: RemoteEvent
local snapshot: LobbyTypes.Snapshot? = nil

local gui: ScreenGui
local coinsLabel: TextLabel
local memberRows: { TextLabel } = {}
local inviteButton: TextButton
local leaveButton: TextButton
local readyLabel: TextLabel
local searchLabel: TextLabel
local playButton: TextButton
local cancelButton: TextButton
local invitePanel: Frame
local inviteList: ScrollingFrame
local inviteEmpty: TextLabel
local incomingCard: Frame
local incomingText: TextLabel
local acceptButton: TextButton
local declineButton: TextButton
local noticeLabel: TextLabel
local noticeUntil = 0
local keyChips: { TextLabel } = {}

local function request(kind: LobbyTypes.RequestName, arg: any?)
	requestEvent:FireServer(kind, arg)
end

local function rankName(id: string): string
	local names = Strings.Ranks :: { [string]: string }
	return names[id] or id
end

local function notice(text: string)
	noticeLabel.Text = text
	noticeUntil = os.clock() + NOTICE_SECONDS
end

-- Chip de tecla ao lado de um botão (só aparece no teclado ou no controle).
local function attachChip(button: GuiObject, key: string, gamepadKey: string?)
	local chip = Ui.keyChip(key, button)
	chip.AnchorPoint = Vector2.new(1, 0.5)
	chip.Position = UDim2.new(1, -8, 0.5, 0)
	chip.Size = UDim2.fromOffset(if #key > 1 then 52 else 22, 22)
	chip:SetAttribute("Key", key)
	chip:SetAttribute("GamepadKey", gamepadKey)
	table.insert(keyChips, chip)
end

local function refreshChips()
	local device = InputDevice.get()
	for _, label in keyChips do
		local key = label:GetAttribute("Key")
		local gamepadKey = label:GetAttribute("GamepadKey")
		if device == "KeyboardMouse" and typeof(key) == "string" then
			label.Visible = true
			label.Text = key
		elseif device == "Gamepad" and typeof(gamepadKey) == "string" then
			label.Visible = true
			label.Text = gamepadKey
		else
			label.Visible = false
		end
	end
end

-- Estado na tela -----------------------------------------------------------------------------------

local function myReady(snap: LobbyTypes.Snapshot): boolean
	local me = snap.members[1]
	return me ~= nil and me.ready
end

local function refreshInviteList(snap: LobbyTypes.Snapshot)
	for _, child in inviteList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	inviteEmpty.Visible = #snap.available == 0
	for i, ref in snap.available do
		local row = Ui.frame("Row", inviteList)
		row.LayoutOrder = i
		row.Size = UDim2.new(1, -8, 0, Theme.Touch.MinTarget)
		local name = Ui.label("Name", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, row)
		name.Size = UDim2.new(1, -150, 1, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = ref.name
		local invited = table.find(snap.invitedOut, ref.userId) ~= nil
		local button = Ui.button("Invite", if invited then S.Invited else S.InviteButton, not invited, row)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.fromScale(1, 0.5)
		button.Size = UDim2.fromOffset(140, Theme.Touch.MinTarget)
		button.TextSize = Theme.TextSize.Body
		button.Modal = true
		button.Active = not invited
		button.Activated:Connect(function()
			if not invited then
				request("Invite", ref.userId)
			end
		end)
	end
end

local function render()
	local snap = snapshot
	if snap == nil then
		return
	end
	local partySize = QueueConfig.PartySize

	-- Dupla
	local readyCount = 0
	for i = 1, partySize do
		local row = memberRows[i]
		local member = snap.members[i]
		if member then
			if member.ready then
				readyCount += 1
			end
			local name = if i == 1 then string.format(S.You, member.name) else member.name
			row.Text = string.format(S.MemberLine, name, rankName(member.rankTier))
				.. "\n"
				.. (if member.ready then S.Ready else S.NotReady)
			row.TextColor3 = if member.ready then Theme.Color.Success else Theme.Color.TextPrimary
		else
			row.Text = S.EmptySlot
			row.TextColor3 = Theme.Color.TextSecondary
		end
	end
	local idle = snap.state == "Idle"
	inviteButton.Visible = #snap.members < partySize and idle
	leaveButton.Visible = #snap.members > 1 and snap.state ~= "Teleporting"
	readyLabel.Text = string.format(S.ReadyCount, readyCount, #snap.members)

	-- Fila
	if snap.state == "Queued" then
		local q = snap.queue
		searchLabel.Text = if q then string.format(S.Searching, q.count, q.target) else ""
		playButton.Text = string.format(S.Searching, if q then q.count else 1, if q then q.target else 7)
		playButton.BackgroundColor3 = Theme.Color.PanelRaised
		cancelButton.Visible = true
	elseif snap.state == "Teleporting" then
		searchLabel.Text = S.Teleporting
		playButton.Text = S.MatchFound
		playButton.BackgroundColor3 = Theme.Color.PanelRaised
		cancelButton.Visible = false
	else
		searchLabel.Text = ""
		local waiting = myReady(snap)
		playButton.Text = if waiting then S.WaitingPartner else S.Play
		playButton.BackgroundColor3 = if waiting then Theme.Color.PanelRaised else Theme.Color.Accent
		cancelButton.Visible = waiting
	end

	-- Convites
	if invitePanel.Visible then
		if not inviteButton.Visible then
			invitePanel.Visible = false
		else
			refreshInviteList(snap)
		end
	end
	local incoming = snap.invitesIn[1]
	incomingCard.Visible = incoming ~= nil
	if incoming then
		incomingText.Text = string.format(S.InviteReceived, incoming.name)
	end
end

-- Ações --------------------------------------------------------------------------------------------

local function primaryAction()
	local snap = snapshot
	if snap == nil then
		return
	end
	if snap.state == "Queued" then
		request("Cancel")
	elseif snap.state == "Idle" then
		request(if myReady(snap) then "Cancel" else "Play")
	end
end

local function setInvitePanel(open: boolean)
	invitePanel.Visible = open
	if open and snapshot then
		refreshInviteList(snapshot :: LobbyTypes.Snapshot)
	end
	if InputDevice.get() == "Gamepad" then
		GuiService.SelectedObject = if open then inviteButton else playButton
	end
end

local function answerInvite(accept: boolean)
	local snap = snapshot
	local incoming = snap and snap.invitesIn[1]
	if incoming then
		request(if accept then "AcceptInvite" else "DeclineInvite", incoming.userId)
	end
end

local function promptRobloxInvite()
	task.spawn(function()
		local ok, canInvite = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and canInvite then
			pcall(function()
				SocialService:PromptGameInvite(player)
			end)
		end
	end)
end

-- Montagem -----------------------------------------------------------------------------------------

local function build()
	gui = Ui.screen("LobbyScreen", 10, Enum.ScreenInsets.CoreUISafeInsets)

	local title = Ui.label("Title", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, gui)
	title.Position = UDim2.fromOffset(Theme.ScreenMargin, Theme.ScreenMargin)
	title.Size = UDim2.fromOffset(200, 30)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = S.Title
	Ui.outlineText(title)

	coinsLabel = Ui.label("Coins", Theme.Font.Number, Theme.TextSize.Title, Theme.Color.Coin, gui)
	coinsLabel.AnchorPoint = Vector2.new(1, 0)
	coinsLabel.Position = UDim2.new(1, -Theme.ScreenMargin, 0, Theme.ScreenMargin)
	coinsLabel.Size = UDim2.fromOffset(200, 30)
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
	Ui.outlineText(coinsLabel)

	-- Esquerda: a dupla
	local party = Ui.panel("Party", gui)
	party.AnchorPoint = Vector2.new(0, 0.5)
	party.Position = UDim2.new(0, Theme.ScreenMargin, 0.55, 0)
	party.Size = UDim2.fromScale(0.32, 0)
	party.AutomaticSize = Enum.AutomaticSize.Y
	local partyLimit = Instance.new("UISizeConstraint")
	partyLimit.MaxSize = Vector2.new(PANEL_WIDTH, math.huge)
	partyLimit.Parent = party
	Ui.padding(party, 12)
	Ui.list(party, Enum.FillDirection.Vertical, 8)

	local partyTitle = Ui.label("Title", Theme.Font.Title, Theme.TextSize.PrimaryButton, Theme.Color.TextPrimary, party)
	partyTitle.Size = UDim2.new(1, 0, 0, 24)
	partyTitle.TextXAlignment = Enum.TextXAlignment.Left
	partyTitle.Text = S.PartyTitle
	partyTitle.LayoutOrder = 0
	for i = 1, QueueConfig.PartySize do
		local row = Ui.label(`Member{i}`, Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, party)
		row.Size = UDim2.new(1, 0, 0, 40)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextYAlignment = Enum.TextYAlignment.Top
		row.TextWrapped = true
		row.LayoutOrder = i
		memberRows[i] = row
	end
	inviteButton = Ui.button("Invite", S.Invite, false, party)
	inviteButton.Size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget)
	inviteButton.LayoutOrder = 10
	inviteButton.Modal = true
	inviteButton.Activated:Connect(function()
		setInvitePanel(not invitePanel.Visible)
	end)
	attachChip(inviteButton, "G", "Y")
	leaveButton = Ui.button("Leave", S.LeaveParty, false, party)
	leaveButton.Size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget)
	leaveButton.LayoutOrder = 11
	leaveButton.Visible = false
	leaveButton.Activated:Connect(function()
		request("LeaveParty")
	end)

	-- Direita: o modo e o JOGAR
	local mode = Ui.panel("Mode", gui)
	mode.AnchorPoint = Vector2.new(1, 0.5)
	mode.Position = UDim2.new(1, -Theme.ScreenMargin, 0.55, 0)
	mode.Size = UDim2.fromScale(0.34, 0)
	mode.AutomaticSize = Enum.AutomaticSize.Y
	local modeLimit = Instance.new("UISizeConstraint")
	modeLimit.MaxSize = Vector2.new(PANEL_WIDTH + 20, math.huge)
	modeLimit.Parent = mode
	Ui.padding(mode, 12)
	Ui.list(mode, Enum.FillDirection.Vertical, 8)

	local modeTitle = Ui.label("Title", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, mode)
	modeTitle.Size = UDim2.new(1, 0, 0, 28)
	modeTitle.TextXAlignment = Enum.TextXAlignment.Left
	modeTitle.Text = S.ModeTitle
	modeTitle.LayoutOrder = 1
	local subtitle = Ui.label("Subtitle", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary, mode)
	subtitle.Size = UDim2.new(1, 0, 0, 20)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextWrapped = true
	subtitle.Text = S.ModeSubtitle
	subtitle.LayoutOrder = 2
	readyLabel = Ui.label("Ready", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.Success, mode)
	readyLabel.Size = UDim2.new(1, 0, 0, 20)
	readyLabel.TextXAlignment = Enum.TextXAlignment.Left
	readyLabel.LayoutOrder = 3
	searchLabel = Ui.label("Search", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, mode)
	searchLabel.Size = UDim2.new(1, 0, 0, 20)
	searchLabel.TextXAlignment = Enum.TextXAlignment.Left
	searchLabel.LayoutOrder = 4

	playButton = Ui.button("Play", S.Play, true, mode)
	playButton.Size = UDim2.new(1, 0, 0, Theme.PrimaryButtonMinHeight)
	playButton.LayoutOrder = 5
	playButton.Modal = true -- o lobby é um menu: mouse livre no PC
	playButton.TextScaled = false
	playButton.TextWrapped = true
	playButton.Activated:Connect(primaryAction)
	attachChip(playButton, "Enter", "X")
	cancelButton = Ui.button("Cancel", S.Cancel, false, mode)
	cancelButton.Size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget)
	cancelButton.LayoutOrder = 6
	cancelButton.Visible = false
	cancelButton.Activated:Connect(function()
		request("Cancel")
	end)

	-- Janela de convite (sobre o jogo, fundo do painel, nunca preto opaco)
	invitePanel = Ui.panel("InvitePanel", gui)
	invitePanel.AnchorPoint = Vector2.new(0.5, 0.5)
	invitePanel.Position = UDim2.fromScale(0.5, 0.55)
	invitePanel.Size = UDim2.fromScale(0.42, 0.62)
	invitePanel.Visible = false
	invitePanel.ZIndex = 5
	local inviteLimit = Instance.new("UISizeConstraint")
	inviteLimit.MinSize = Vector2.new(300, 220)
	inviteLimit.MaxSize = Vector2.new(440, 420)
	inviteLimit.Parent = invitePanel
	Ui.padding(invitePanel, 12)

	local inviteTitle =
		Ui.label("Title", Theme.Font.Title, Theme.TextSize.PrimaryButton, Theme.Color.TextPrimary, invitePanel)
	inviteTitle.Size = UDim2.new(1, 0, 0, 24)
	inviteTitle.TextXAlignment = Enum.TextXAlignment.Left
	inviteTitle.Text = S.InviteTitle
	local hint = Ui.label("Hint", Theme.Font.Body, Theme.TextSize.Label, Theme.Color.TextSecondary, invitePanel)
	hint.Position = UDim2.fromOffset(0, 26)
	hint.Size = UDim2.new(1, 0, 0, 18)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Text = S.InviteHint

	inviteList = Instance.new("ScrollingFrame")
	inviteList.Name = "List"
	inviteList.BackgroundTransparency = 1
	inviteList.BorderSizePixel = 0
	inviteList.Position = UDim2.fromOffset(0, 48)
	inviteList.Size = UDim2.new(1, 0, 1, -48 - Theme.Touch.MinTarget - 8)
	inviteList.CanvasSize = UDim2.new()
	inviteList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	inviteList.ScrollBarThickness = 4
	inviteList.Parent = invitePanel
	Ui.list(inviteList, Enum.FillDirection.Vertical, 6)
	inviteEmpty = Ui.label("Empty", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary, invitePanel)
	inviteEmpty.Position = UDim2.fromOffset(0, 56)
	inviteEmpty.Size = UDim2.new(1, 0, 0, 40)
	inviteEmpty.TextWrapped = true
	inviteEmpty.Text = S.NobodyToInvite

	local inviteButtons = Ui.frame("Buttons", invitePanel)
	inviteButtons.AnchorPoint = Vector2.new(0, 1)
	inviteButtons.Position = UDim2.fromScale(0, 1)
	inviteButtons.Size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget)
	local friends = Ui.button("Friends", S.RobloxFriends, true, inviteButtons)
	friends.Size = UDim2.new(0.6, -4, 1, 0)
	friends.TextSize = Theme.TextSize.Body
	friends.Modal = true
	friends.Activated:Connect(promptRobloxInvite)
	local close = Ui.button("Close", S.Close, false, inviteButtons)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.new(0.4, -4, 1, 0)
	close.TextSize = Theme.TextSize.Body
	close.Activated:Connect(function()
		setInvitePanel(false)
	end)

	-- Convite recebido (topo, no meio)
	incomingCard = Ui.panel("Incoming", gui)
	incomingCard.AnchorPoint = Vector2.new(0.5, 0)
	incomingCard.Position = UDim2.new(0.5, 0, 0, Theme.ScreenMargin + 36)
	incomingCard.Size = UDim2.new(0.46, 0, 0, 104)
	incomingCard.Visible = false
	local incomingLimit = Instance.new("UISizeConstraint")
	incomingLimit.MinSize = Vector2.new(300, 104)
	incomingLimit.MaxSize = Vector2.new(460, 104)
	incomingLimit.Parent = incomingCard
	Ui.padding(incomingCard, 10)
	incomingText = Ui.label("Text", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, incomingCard)
	incomingText.Size = UDim2.new(1, 0, 0, 36)
	incomingText.TextWrapped = true
	acceptButton = Ui.button("Accept", S.Accept, true, incomingCard)
	acceptButton.AnchorPoint = Vector2.new(0, 1)
	acceptButton.Position = UDim2.fromScale(0, 1)
	acceptButton.Size = UDim2.new(0.5, -4, 0, Theme.Touch.MinTarget)
	acceptButton.TextSize = Theme.TextSize.Body
	acceptButton.Modal = true
	acceptButton.Activated:Connect(function()
		answerInvite(true)
	end)
	attachChip(acceptButton, "Y")
	declineButton = Ui.button("Decline", S.Decline, false, incomingCard)
	declineButton.AnchorPoint = Vector2.new(1, 1)
	declineButton.Position = UDim2.fromScale(1, 1)
	declineButton.Size = UDim2.new(0.5, -4, 0, Theme.Touch.MinTarget)
	declineButton.TextSize = Theme.TextSize.Body
	declineButton.Activated:Connect(function()
		answerInvite(false)
	end)
	attachChip(declineButton, "N")

	noticeLabel = Ui.label("Notice", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, gui)
	noticeLabel.AnchorPoint = Vector2.new(0.5, 1)
	noticeLabel.Position = UDim2.new(0.5, 0, 1, -Theme.ScreenMargin)
	noticeLabel.Size = UDim2.new(0.9, 0, 0, 22)
	noticeLabel.TextWrapped = true
	noticeLabel.Visible = false
	Ui.outlineText(noticeLabel)

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Atalhos ------------------------------------------------------------------------------------------

local function bindKeys()
	local function onAction(name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if name == "LobbyPlay" then
			primaryAction()
		elseif name == "LobbyInvite" then
			if inviteButton.Visible then
				setInvitePanel(not invitePanel.Visible)
			end
		elseif name == "LobbyAccept" then
			if not incomingCard.Visible then
				return Enum.ContextActionResult.Pass
			end
			answerInvite(true)
		elseif name == "LobbyDecline" then
			if not incomingCard.Visible then
				return Enum.ContextActionResult.Pass
			end
			answerInvite(false)
		end
		return Enum.ContextActionResult.Sink
	end
	ContextActionService:BindAction("LobbyPlay", onAction, false, Enum.KeyCode.Return, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction("LobbyInvite", onAction, false, Enum.KeyCode.G, Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("LobbyAccept", onAction, false, Enum.KeyCode.Y)
	ContextActionService:BindAction("LobbyDecline", onAction, false, Enum.KeyCode.N)
end

function LobbyScreen.Start()
	requestEvent = Remotes.event("LobbyRequest")
	build()
	bindKeys()
	refreshChips()
	InputDevice.onChanged(function(device: InputDevice.Device)
		refreshChips()
		if device == "Gamepad" and GuiService.SelectedObject == nil then
			GuiService.SelectedObject = playButton
		end
	end)

	local function showCoins(profile: any)
		coinsLabel.Text = "● " .. tostring(profile.coins)
	end
	local profile = PlayerDataClient.get()
	if profile then
		showCoins(profile)
	end
	PlayerDataClient.onChanged(showCoins)

	Remotes.event("LobbyState").OnClientEvent:Connect(function(snap: LobbyTypes.Snapshot)
		local before = snapshot
		snapshot = snap
		render()
		-- Convite novo: no controle, já seleciona ACEITAR
		if InputDevice.get() == "Gamepad" and #snap.invitesIn > 0 and (before == nil or #before.invitesIn == 0) then
			GuiService.SelectedObject = acceptButton
		end
	end)
	Remotes.event("LobbyEvent").OnClientEvent:Connect(function(kind: string, data: { key: string, name: string? })
		if kind ~= "Notice" or typeof(data) ~= "table" then
			return
		end
		local text = S.Notices[data.key]
		if text then
			notice(if data.name then string.format(text, data.name) else text)
		end
	end)

	RunService.RenderStepped:Connect(function()
		noticeLabel.Visible = os.clock() < noticeUntil
		local snap = snapshot
		local q = snap and snap.queue
		if snap and snap.state == "Queued" and q and q.startsAt then
			local left = math.max(0, math.ceil(q.startsAt - workspace:GetServerTimeNow()))
			searchLabel.Text = string.format(S.StartsIn, left)
		end
	end)
end

return LobbyScreen
