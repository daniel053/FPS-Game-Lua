--!strict
-- Tela do lobby (ESTILO T3, visual final da F7):
--   * topo esquerdo: logo provisória + "LOBBY"; topo direito: moedas (a segunda moeda é [ABERTO] e
--     não aparece) e a engrenagem (painel de configurações; P no PC);
--   * esquerda: a dupla (avatar, nome, elo, Pronto/Esperando), + CONVIDAR AMIGOS e SAIR DA DUPLA;
--   * direita: cartão "Duelo em dupla", x/2 prontos e o botão JOGAR, que vira
--     "Procurando partida… 5/7" com CANCELAR;
--   * centro: o cenário (ilhas cinza flutuantes, LobbyBackdrop), livre;
--   * embaixo: navegação JOGAR, ARSENAL (T5), CARTAS (T1), MAPAS (T4), RANKING (F9) e LOJA (em breve: F11);
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
local Ui = require(Shared.Ui.Ui)

local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local SettingsController = require(script.Parent.Parent.Common.SettingsController)
local Avatars = require(script.Parent.Parent.Common.Ui.Avatars)
local Logo = require(script.Parent.Parent.Common.Ui.Logo)
local RankBadge = require(script.Parent.Parent.Common.Ui.RankBadge)
local Widgets = require(script.Parent.Parent.Common.Ui.Widgets)
local ArsenalScreen = require(script.Parent.ArsenalScreen)
local CardsScreen = require(script.Parent.CardsScreen)
local MapsScreen = require(script.Parent.MapsScreen)
local RankingScreen = require(script.Parent.RankingScreen)

local S = Strings.Lobby
local U = Strings.Ui
local NOTICE_SECONDS = 4
local PANEL_WIDTH = 280
local MEMBER_HEIGHT = 52
local COMPACT_MEMBER_HEIGHT = 44
local COMPACT_BELOW_HEIGHT = 440 -- telas mais baixas (celular deitado): modo compacto
local PANEL_TOP = 64 -- abaixo da logo e das moedas

type MemberRow = { root: Frame, avatar: Avatars.Avatar, name: TextLabel, state: TextLabel }

local LobbyScreen = {}

local player = Players.LocalPlayer
local requestEvent: RemoteEvent
local snapshot: LobbyTypes.Snapshot? = nil

local gui: ScreenGui
local coinsLabel: TextLabel
local memberRows: { MemberRow } = {}
local inviteButton: Widgets.Button
local leaveButton: Widgets.Button
local readyLabel: TextLabel
local searchLabel: TextLabel
local playButton: Widgets.Button
local cancelButton: Widgets.Button
local invite: Widgets.Modal
local inviteList: ScrollingFrame
local inviteEmpty: TextLabel
local incomingCard: Frame
local incomingText: TextLabel
local acceptButton: Widgets.Button
local declineButton: Widgets.Button
local noticeLabel: TextLabel
local noticeUntil = 0
local modeBanner: Frame
local modeSubtitle: TextLabel

local function request(kind: LobbyTypes.RequestName, arg: any?)
	requestEvent:FireServer(kind, arg)
end

local function notice(text: string)
	noticeLabel.Text = text
	noticeUntil = os.clock() + NOTICE_SECONDS
end

-- Estado na tela -----------------------------------------------------------------------------------

local function myReady(snap: LobbyTypes.Snapshot): boolean
	local me = snap.members[1]
	return me ~= nil and me.ready
end

local function refreshInviteList(snap: LobbyTypes.Snapshot)
	Ui.clear(inviteList)
	inviteEmpty.Visible = #snap.available == 0
	for i, ref in snap.available do
		local row = Ui.frame("Row", inviteList)
		row.LayoutOrder = i
		row.Size = UDim2.new(1, -8, 0, Theme.Touch.MinTarget)
		local avatar = Avatars.new(row, Theme.Touch.MinTarget - 8)
		avatar.root.Position = UDim2.fromOffset(0, 4)
		Avatars.set(avatar, ref.userId, ref.name, Theme.Color.PanelBorder)
		local name = Ui.label("Name", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, row)
		name.Position = UDim2.fromOffset(Theme.Touch.MinTarget, 0)
		name.Size = UDim2.new(1, -150 - Theme.Touch.MinTarget, 1, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = ref.name
		local invited = table.find(snap.invitedOut, ref.userId) ~= nil
		local button = Widgets.button(row, if invited then S.Invited else S.InviteButton, "primary", {
			size = UDim2.fromOffset(140, Theme.Touch.MinTarget),
			textSize = Theme.TextSize.Body,
			arrow = false,
			modal = true,
		})
		button.root.AnchorPoint = Vector2.new(1, 0.5)
		button.root.Position = UDim2.fromScale(1, 0.5)
		button.setEnabled(not invited)
		button.onClick(function()
			request("Invite", ref.userId)
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
			Avatars.set(
				row.avatar,
				member.userId,
				member.name,
				if member.ready then Theme.Color.Success else Theme.Color.PanelBorder
			)
			local name = if i == 1 then string.format(S.You, member.name) else member.name
			row.name.Text = string.format(S.MemberLine, RankBadge.escape(name), RankBadge.rich(member.rankTier))
			row.name.TextColor3 = Theme.Color.TextPrimary
			row.state.Text = if member.ready then S.Ready else S.NotReady
			row.state.TextColor3 = if member.ready then Theme.Color.Success else Theme.Color.TextSecondary
			row.avatar.root.Visible = true
		else
			row.avatar.root.Visible = false
			row.name.Text = S.EmptySlot
			row.name.TextColor3 = Theme.Color.TextSecondary
			row.state.Text = ""
		end
	end
	local idle = snap.state == "Idle"
	inviteButton.root.Visible = #snap.members < partySize and idle
	leaveButton.root.Visible = #snap.members > 1 and snap.state ~= "Teleporting"
	readyLabel.Text = string.format(S.ReadyCount, readyCount, #snap.members)

	-- Fila
	if snap.state == "Queued" then
		local q = snap.queue
		searchLabel.Text = if q then string.format(S.Searching, q.count, q.target) else ""
		playButton.setText(string.format(S.Searching, if q then q.count else 1, if q then q.target else 7))
		playButton.setKind("secondary")
		cancelButton.root.Visible = true
	elseif snap.state == "Teleporting" then
		searchLabel.Text = S.Teleporting
		playButton.setText(S.MatchFound)
		playButton.setKind("secondary")
		cancelButton.root.Visible = false
	else
		searchLabel.Text = ""
		local waiting = myReady(snap)
		playButton.setText(if waiting then S.WaitingPartner else S.Play)
		playButton.setKind(if waiting then "secondary" else "primary")
		cancelButton.root.Visible = waiting
	end

	-- Convites
	if invite.isOpen() then
		if not inviteButton.root.Visible then
			invite.close()
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
	if open then
		invite.open()
		if snapshot then
			refreshInviteList(snapshot :: LobbyTypes.Snapshot)
		end
	else
		invite.close()
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

local function buildTop()
	local margin = Theme.ScreenMargin
	local logo = Logo.new(gui, 40, S.Title)
	logo.Position = UDim2.fromOffset(margin, margin / 2)

	-- Moedas e engrenagem (topo direito)
	local right = Ui.frame("TopRight", gui)
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.new(1, -margin, 0, margin / 2)
	right.Size = UDim2.fromOffset(0, Theme.Touch.MinTarget)
	right.AutomaticSize = Enum.AutomaticSize.X
	local layout = Ui.list(right, Enum.FillDirection.Horizontal, Theme.Space.Medium)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center

	local coinPlate = Ui.panel("Coins", right, nil, Theme.Chamfer.Tab)
	coinPlate.Size = UDim2.fromOffset(130, Theme.Touch.MinTarget)
	coinPlate.LayoutOrder = 1
	coinsLabel = Ui.label("Value", Theme.Font.Number, Theme.TextSize.Title, Theme.Color.TextPrimary, coinPlate)
	coinsLabel.Position = UDim2.fromOffset(34, 0)
	coinsLabel.Size = UDim2.new(1, -44, 1, 0)
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
	coinsLabel.ZIndex = 2
	local coinIcon = Ui.label("Icon", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.Coin, coinPlate)
	coinIcon.Position = UDim2.fromOffset(10, 0)
	coinIcon.Size = UDim2.fromOffset(24, Theme.Touch.MinTarget)
	coinIcon.Text = U.Coin
	coinIcon.ZIndex = 2

	local gearHolder = Ui.frame("Gear", right)
	gearHolder.Size = UDim2.fromOffset(Theme.Touch.MinTarget, Theme.Touch.MinTarget)
	gearHolder.LayoutOrder = 2
	local gear = Widgets.iconButton(gearHolder, U.Gear, SettingsController.toggle)
	gear.Modal = true -- o lobby é um menu: mouse livre no PC
	local chip = Widgets.keyChip(gearHolder, "P", nil)
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.new(0.5, 0, 1, 2)
end

local function buildParty()
	local party, content = Ui.autoPanel("Party", gui, 12)
	party.Position = UDim2.fromOffset(Theme.ScreenMargin, PANEL_TOP)
	party.Size = UDim2.fromScale(0.3, 0)
	Ui.sizeLimit(party, nil, Vector2.new(PANEL_WIDTH, math.huge))
	Ui.list(content, Enum.FillDirection.Vertical, 8)

	Widgets.sectionTitle(content, S.PartyTitle, 0)
	for i = 1, QueueConfig.PartySize do
		local row = Ui.frame(`Member{i}`, content)
		row.Size = UDim2.new(1, 0, 0, MEMBER_HEIGHT)
		row.LayoutOrder = i
		local avatar = Avatars.new(row, MEMBER_HEIGHT - 8)
		avatar.root.Position = UDim2.fromOffset(0, 4)
		local name = Ui.label("Name", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, row)
		name.Position = UDim2.fromOffset(MEMBER_HEIGHT + 2, 6)
		name.Size = UDim2.new(1, -(MEMBER_HEIGHT + 2), 0, 20)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.RichText = true -- elo com ícone e cor (F9)
		local state = Ui.label("State", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, row)
		state.Position = UDim2.fromOffset(MEMBER_HEIGHT + 2, 28)
		state.Size = UDim2.new(1, -(MEMBER_HEIGHT + 2), 0, 16)
		state.TextXAlignment = Enum.TextXAlignment.Left
		memberRows[i] = { root = row, avatar = avatar, name = name, state = state }
	end
	inviteButton = Widgets.button(content, S.Invite, "secondary", {
		size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget),
		textSize = Theme.TextSize.Body,
		order = 10,
		pc = "G",
		pad = "Y",
		modal = true,
	})
	inviteButton.onClick(function()
		setInvitePanel(not invite.isOpen())
	end)
	leaveButton = Widgets.button(content, S.LeaveParty, "secondary", {
		size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget),
		textSize = Theme.TextSize.Body,
		order = 11,
	})
	leaveButton.root.Visible = false
	leaveButton.onClick(function()
		request("LeaveParty")
	end)
end

local function buildMode()
	local mode, content = Ui.autoPanel("Mode", gui, 12)
	mode.AnchorPoint = Vector2.new(1, 0)
	mode.Position = UDim2.new(1, -Theme.ScreenMargin, 0, PANEL_TOP)
	mode.Size = UDim2.fromScale(0.3, 0)
	Ui.sizeLimit(mode, nil, Vector2.new(PANEL_WIDTH + 20, math.huge))
	Ui.list(content, Enum.FillDirection.Vertical, 8)

	local title = Ui.label("Title", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, content)
	title.Size = UDim2.new(1, 0, 0, 28)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = S.ModeTitle
	title.LayoutOrder = 1

	-- "Imagem" do modo: faixa com o mirante e as 4 ilhas desenhados em blocos (arte final na F10)
	local banner = Ui.raised("Banner", content)
	modeBanner = banner
	banner.BackgroundColor3 = Theme.Lobby.ModeBanner
	banner.Size = UDim2.new(1, 0, 0, 74)
	banner.LayoutOrder = 2
	for i, offset in
		{ Vector2.new(-0.28, 0.3), Vector2.new(0.28, 0.3), Vector2.new(-0.28, 0.72), Vector2.new(0.28, 0.72) }
	do
		local island = Ui.frame(`Island{i}`, banner)
		island.AnchorPoint = Vector2.new(0.5, 0.5)
		island.Position = UDim2.fromScale(0.5 + offset.X, offset.Y)
		island.Size = UDim2.fromOffset(34, 14)
		island.BackgroundTransparency = 0
		island.BackgroundColor3 = Theme.Match.IslandFloor
		Ui.corner(island, 4)
	end
	local center = Ui.frame("Mirante", banner)
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.4)
	center.Size = UDim2.fromOffset(40, 40)
	center.Rotation = 45
	center.BackgroundTransparency = 0
	center.BackgroundColor3 = Theme.Match.MiranteFloor
	local vs = Ui.label("Vs", Theme.Font.Title, Theme.TextSize.Label, Theme.Color.TextPrimary, banner)
	vs.AnchorPoint = Vector2.new(0.5, 1)
	vs.Position = UDim2.new(0.5, 0, 1, -4)
	vs.Size = UDim2.new(1, 0, 0, 16)
	vs.Text = S.ModeBanner
	Ui.outlineText(vs)

	local subtitle = Ui.paragraph("Subtitle", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary, content)
	subtitle.Text = S.ModeSubtitle
	subtitle.LayoutOrder = 3
	modeSubtitle = subtitle
	readyLabel = Ui.label("Ready", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.Success, content)
	readyLabel.Size = UDim2.new(1, 0, 0, 20)
	readyLabel.TextXAlignment = Enum.TextXAlignment.Left
	readyLabel.LayoutOrder = 4
	searchLabel = Ui.label("Search", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, content)
	searchLabel.Size = UDim2.new(1, 0, 0, 20)
	searchLabel.TextXAlignment = Enum.TextXAlignment.Left
	searchLabel.LayoutOrder = 5

	playButton = Widgets.button(content, S.Play, "primary", {
		size = UDim2.new(1, 0, 0, Theme.PrimaryButtonMinHeight),
		order = 6,
		pc = "Enter",
		pad = "X",
		modal = true, -- o lobby é um menu: mouse livre no PC
	})
	playButton.onClick(primaryAction)
	cancelButton = Widgets.button(content, S.Cancel, "secondary", {
		size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget),
		textSize = Theme.TextSize.Body,
		order = 7,
	})
	cancelButton.root.Visible = false
	cancelButton.onClick(function()
		request("Cancel")
	end)
end

local function buildNav()
	local nav = Ui.frame("Nav", gui)
	nav.AnchorPoint = Vector2.new(0.5, 1)
	nav.Position = UDim2.new(0.5, 0, 1, -Theme.ScreenMargin)
	nav.Size = UDim2.new(1, -2 * Theme.ScreenMargin, 0, Theme.Touch.MinTarget)
	local layout = Ui.list(nav, Enum.FillDirection.Horizontal, Theme.Space.Small)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local N = S.Nav
	local entries: { { label: string, action: (() -> ())? } } = {
		{ label = N.Play, action = nil },
		{ label = N.Arsenal, action = ArsenalScreen.open },
		{ label = N.Cards, action = CardsScreen.open },
		{ label = N.Maps, action = MapsScreen.open },
		{ label = N.Ranking, action = RankingScreen.open },
		{ label = N.Shop, action = nil },
	}
	for i, entry in entries do
		local isPlay = i == 1
		local button = Widgets.button(nav, entry.label, if isPlay then "primary" else "secondary", {
			size = UDim2.new(1 / #entries, -Theme.Space.Small, 1, 0),
			textSize = Theme.TextSize.Body,
			arrow = false,
			order = i,
			modal = true,
		})
		local action = entry.action
		if isPlay then
			-- Já está no lobby: leva a seleção para o JOGAR
			button.onClick(function()
				if InputDevice.get() == "Gamepad" then
					GuiService.SelectedObject = playButton.root
				end
			end)
		elseif action then
			button.onClick(action)
		else
			-- A Loja (Robux) chega na F11
			button.setEnabled(false)
			button.setText(entry.label .. " · " .. U.Soon)
		end
	end
end

local function buildInvite()
	invite = Widgets.modal("LobbyInvite", 30, {
		title = S.InviteTitle,
		size = UDim2.fromScale(0.46, 0.66),
		maxSize = Vector2.new(480, 440),
	})
	local body = invite.body
	local hint = Ui.label("Hint", Theme.Font.Body, Theme.TextSize.Label, Theme.Color.TextSecondary, body)
	hint.Size = UDim2.new(1, 0, 0, 18)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Text = S.InviteHint

	inviteList = Ui.scroll("List", Enum.ScrollingDirection.Y, body)
	inviteList.Position = UDim2.fromOffset(0, 24)
	inviteList.Size = UDim2.new(1, 0, 1, -24 - Theme.Touch.MinTarget - 10)
	Ui.list(inviteList, Enum.FillDirection.Vertical, 6)
	inviteEmpty = Ui.label("Empty", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary, body)
	inviteEmpty.Position = UDim2.fromOffset(0, 32)
	inviteEmpty.Size = UDim2.new(1, 0, 0, 40)
	inviteEmpty.TextWrapped = true
	inviteEmpty.Text = S.NobodyToInvite

	local friends = Widgets.button(body, S.RobloxFriends, "primary", {
		size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget),
		textSize = Theme.TextSize.Body,
		modal = true,
	})
	friends.root.AnchorPoint = Vector2.new(0, 1)
	friends.root.Position = UDim2.fromScale(0, 1)
	friends.onClick(promptRobloxInvite)
	invite.gui.Parent = player:WaitForChild("PlayerGui")
end

local function buildIncoming()
	local content: Frame
	incomingCard, content = Ui.panel("Incoming", gui, 10)
	incomingCard.AnchorPoint = Vector2.new(0.5, 0)
	incomingCard.Position = UDim2.new(0.5, 0, 0, Theme.ScreenMargin + 52)
	incomingCard.Size = UDim2.new(0.46, 0, 0, 108)
	incomingCard.Visible = false
	Ui.sizeLimit(incomingCard, Vector2.new(300, 108), Vector2.new(460, 108))
	incomingText = Ui.label("Text", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, content)
	incomingText.Size = UDim2.new(1, 0, 0, 36)
	incomingText.TextWrapped = true
	acceptButton = Widgets.button(content, S.Accept, "primary", {
		size = UDim2.new(0.5, -4, 0, Theme.Touch.MinTarget),
		textSize = Theme.TextSize.Body,
		arrow = false,
		pc = "Y",
		modal = true,
	})
	acceptButton.root.AnchorPoint = Vector2.new(0, 1)
	acceptButton.root.Position = UDim2.fromScale(0, 1)
	acceptButton.onClick(function()
		answerInvite(true)
	end)
	declineButton = Widgets.button(content, S.Decline, "secondary", {
		size = UDim2.new(0.5, -4, 0, Theme.Touch.MinTarget),
		textSize = Theme.TextSize.Body,
		pc = "N",
	})
	declineButton.root.AnchorPoint = Vector2.new(1, 1)
	declineButton.root.Position = UDim2.fromScale(1, 1)
	declineButton.onClick(function()
		answerInvite(false)
	end)
end

-- Celular deitado: sem a faixa e a frase do modo, linhas da dupla menores. Os botões continuam com
-- o alvo de toque mínimo (ESTILO 3).
local function applyCompact()
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 720
	local compact = height < COMPACT_BELOW_HEIGHT
	modeBanner.Visible = not compact
	modeSubtitle.Visible = not compact
	local memberHeight = if compact then COMPACT_MEMBER_HEIGHT else MEMBER_HEIGHT
	for _, row in memberRows do
		row.root.Size = UDim2.new(1, 0, 0, memberHeight)
		row.avatar.root.Size = UDim2.fromOffset(memberHeight - 8, memberHeight - 8)
		row.name.Position = UDim2.fromOffset(memberHeight + 2, if compact then 2 else 6)
		row.state.Position = UDim2.fromOffset(memberHeight + 2, if compact then 22 else 28)
	end
end

local function build()
	gui = Ui.screen("LobbyScreen", 10, Enum.ScreenInsets.CoreUISafeInsets)
	buildTop()
	buildParty()
	buildMode()
	buildNav()
	buildInvite()
	buildIncoming()

	noticeLabel = Ui.label("Notice", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, gui)
	noticeLabel.AnchorPoint = Vector2.new(0.5, 1)
	noticeLabel.Position = UDim2.new(0.5, 0, 1, -Theme.ScreenMargin - Theme.Touch.MinTarget - 10)
	noticeLabel.Size = UDim2.new(0.9, 0, 0, 22)
	noticeLabel.TextWrapped = true
	noticeLabel.Visible = false
	Ui.outlineText(noticeLabel)

	applyCompact()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyCompact)
	end
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
			if inviteButton.root.Visible then
				setInvitePanel(not invite.isOpen())
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

local function showCoins(profile: any)
	-- "2.350" (milhar com ponto)
	local text = tostring(profile.coins)
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1.")))
	if string.sub(formatted, 1, 1) == "." then
		formatted = string.sub(formatted, 2)
	end
	coinsLabel.Text = formatted
end

function LobbyScreen.Start()
	requestEvent = Remotes.event("LobbyRequest")
	build()
	bindKeys()
	InputDevice.onChanged(function(device: InputDevice.Device)
		if device == "Gamepad" and GuiService.SelectedObject == nil then
			GuiService.SelectedObject = playButton.root
		end
	end)

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
			GuiService.SelectedObject = acceptButton.root
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
		searchLabel.Visible = searchLabel.Text ~= ""
		local snap = snapshot
		local q = snap and snap.queue
		if snap and snap.state == "Queued" and q and q.startsAt then
			local left = math.max(0, math.ceil(q.startsAt - workspace:GetServerTimeNow()))
			searchLabel.Text = string.format(S.StartsIn, left)
		end
	end)
end

return LobbyScreen
