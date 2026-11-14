--!strict
-- Placar da partida (GDD 13.3, ESTILO 3 e T6), no lugar da lista de jogadores do Roblox (desligada).
--   * PC: segurar Tab mostra; controle: direcional para a esquerda liga e desliga; celular: botão
--     PLACAR no topo, ao lado da engrenagem.
--   * Todas as duplas: cor (com o nome da cor, nunca só a cor), jogadores com avatar e abates, vidas
--     (ou vitórias na final) e situação (duelando e onde, folga, mirante, colocação, campeã).
--   * A minha dupla aparece primeiro, com fundo do acento bem leve. Ícone do elo antes do nome (F9).
-- Só mostra; o jogo não pausa e o mouse continua preso.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local CombatNames = require(Shared.Combat.CombatNames)
local MatchConfig = require(Shared.Config.MatchConfig)
local MatchTypes = require(Shared.Match.MatchTypes)
local RankRules = require(Shared.Progression.RankRules)
local Strings = require(Shared.Config.Strings)
local TeamColors = require(Shared.Config.TeamColors)
local TextUtil = require(Shared.TextUtil)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.Ui)
local UiConfig = require(Shared.Config.UiConfig)
local WorldLayout = require(Shared.Match.WorldLayout)

local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local Avatars = require(script.Parent.Parent.Common.Ui.Avatars)
local RankBadge = require(script.Parent.Parent.Common.Ui.RankBadge)
local Widgets = require(script.Parent.Parent.Common.Ui.Widgets)
local MatchClient = require(script.Parent.MatchClient)
local ReportPanel = require(script.Parent.ReportPanel)

local S = Strings.Scoreboard
local M = Strings.Match
local KEYS = UiConfig.Keys
local ROW_HEIGHT = 34

local Scoreboard = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local panel: Frame
local roundLabel: TextLabel
local list: ScrollingFrame
local buttonGui: ScreenGui
local touchButton: Widgets.Button
local shown = false

local function setCoreList(enabled: boolean)
	-- SetCoreGuiEnabled pode falhar se o Roblox ainda não carregou a interface: tenta algumas vezes
	task.spawn(function()
		for _ = 1, 10 do
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, enabled)
			end)
			if ok then
				return
			end
			task.wait(1)
		end
	end)
end

local function statusOf(snapshot: MatchTypes.Snapshot, team: MatchTypes.TeamView): (string, Color3)
	if snapshot.championId == team.id then
		return S.Champion, Theme.Color.Coin
	elseif team.eliminated then
		return string.format(S.Eliminated, team.placement or 0), Theme.Color.TextSecondary
	elseif snapshot.bye == team.id then
		return S.Bye, Theme.Color.TextSecondary
	end
	local duel = MatchClient.duelOf(team.id)
	if duel and (snapshot.phase == "Prep" or snapshot.phase == "Combat" or snapshot.phase == "Draw") then
		return string.format(S.Dueling, Strings.Maps[WorldLayout.mapId(duel.island)] or ""), Theme.Color.TextPrimary
	end
	return S.Waiting, Theme.Color.TextSecondary
end

local function livesText(snapshot: MatchTypes.Snapshot, team: MatchTypes.TeamView): string
	if snapshot.isFinal then
		return string.format(M.Wins, team.roundWins)
	end
	return string.rep(M.Life, team.lives) .. string.rep(M.LifeLost, math.max(0, MatchConfig.MaxLives - team.lives))
end

-- Elo de cada jogador (atributo RankTier no Player, RankService, F9). Bots e quem saiu: nada.
local function rankOf(userId: number): string?
	local p = Players:GetPlayerByUserId(userId)
	local tier = p and p:GetAttribute(RankRules.Attr.Tier)
	return if typeof(tier) == "string" then tier else nil
end

local function killsOf(userId: number): number
	local p = Players:GetPlayerByUserId(userId)
	local kills = p and p:GetAttribute(CombatNames.Attr.Kills)
	return if typeof(kills) == "number" then kills else 0
end

local function header(order: number)
	local row = Ui.frame("Header", list)
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 18)
	local function col(text: string, x: number, w: number, align: Enum.TextXAlignment)
		local l = Ui.label("Col", Theme.Font.Title, Theme.TextSize.Label, Theme.Color.TextSecondary, row)
		l.Position = UDim2.fromScale(x, 0)
		l.Size = UDim2.fromScale(w, 1)
		l.TextXAlignment = align
		l.Text = TextUtil.upper(text)
	end
	col(S.Team, 0, 0.5, Enum.TextXAlignment.Left)
	col(S.Lives, 0.5, 0.18, Enum.TextXAlignment.Center)
	col(S.Status, 0.68, 0.32, Enum.TextXAlignment.Right)
end

local function teamBlock(snapshot: MatchTypes.Snapshot, team: MatchTypes.TeamView, order: number, mine: boolean)
	local block = Ui.frame("Team", list)
	block.LayoutOrder = order
	block.Size = UDim2.fromScale(1, 0)
	block.AutomaticSize = Enum.AutomaticSize.Y
	if mine then
		block.BackgroundTransparency = Theme.ScoreboardMineTransparency
		block.BackgroundColor3 = Theme.Color.Accent
		Ui.corner(block)
	end
	local inner = Ui.frame("Inner", block)
	inner.Size = UDim2.fromScale(1, 0)
	inner.AutomaticSize = Enum.AutomaticSize.Y
	Ui.padding(inner, 6)
	Ui.list(inner, Enum.FillDirection.Vertical, 2)
	local color = TeamColors.getColor(team.id)
	local faded = team.eliminated

	local top = Ui.frame("Top", inner)
	top.Size = UDim2.new(1, 0, 0, 20)
	local swatch = Ui.frame("Color", top)
	swatch.BackgroundTransparency = if faded then 0.6 else 0
	swatch.BackgroundColor3 = color
	swatch.Size = UDim2.fromOffset(12, 12)
	swatch.Position = UDim2.fromOffset(0, 4)
	Ui.corner(swatch, 3)
	local name = Ui.label("Name", Theme.Font.Title, Theme.TextSize.Body, Theme.Color.TextPrimary, top)
	name.Position = UDim2.fromOffset(18, 0)
	name.Size = UDim2.new(0.5, -18, 1, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = TextUtil.upper(MatchClient.teamName(team.id))
	name.TextColor3 = if faded then Theme.Color.TextSecondary else Theme.Color.TextPrimary
	local lives = Ui.label("Lives", Theme.Font.Title, Theme.TextSize.Body, Theme.Color.Hp, top)
	lives.Position = UDim2.fromScale(0.5, 0)
	lives.Size = UDim2.fromScale(0.18, 1)
	lives.Text = if faded then "" else livesText(snapshot, team)
	local statusText, statusColor = statusOf(snapshot, team)
	local status = Ui.label("Status", Theme.Font.BodyStrong, Theme.TextSize.Label, statusColor, top)
	status.Position = UDim2.fromScale(0.68, 0)
	status.Size = UDim2.fromScale(0.32, 1)
	status.TextXAlignment = Enum.TextXAlignment.Right
	status.TextTruncate = Enum.TextTruncate.AtEnd
	status.Text = statusText

	for i, member in team.members do
		local row = Ui.frame("Member", inner)
		row.LayoutOrder = 1 + i
		row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT - 6)
		local avatar = Avatars.new(row, ROW_HEIGHT - 10)
		avatar.root.Position = UDim2.fromOffset(18, 2)
		Avatars.set(avatar, member.userId, member.name, color, faded or not member.connected)
		local label = Ui.label("Name", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, row)
		label.Position = UDim2.fromOffset(18 + ROW_HEIGHT, 0)
		label.Size = UDim2.new(0.6, -(18 + ROW_HEIGHT), 1, 0)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		local suffix = if member.userId == player.UserId
			then " · " .. S.You
			elseif member.isBot then " · " .. S.Bot
			elseif not member.connected then " · " .. S.Offline
			else ""
		label.RichText = true
		local rank = rankOf(member.userId)
		label.Text = (if rank then RankBadge.richIcon(rank) .. " " else "") .. RankBadge.escape(member.name .. suffix)
		label.TextColor3 = if faded or not member.connected then Theme.Color.TextSecondary else Theme.Color.TextPrimary
		local kills = Ui.label("Kills", Theme.Font.Number, Theme.TextSize.Body, Theme.Color.TextPrimary, row)
		kills.AnchorPoint = Vector2.new(1, 0)
		kills.Position = UDim2.fromScale(1, 0)
		kills.Size = UDim2.fromScale(0.4, 1)
		kills.TextXAlignment = Enum.TextXAlignment.Right
		kills.Text = string.format("%s %d", S.Kills, killsOf(member.userId))
		kills.TextColor3 = Theme.Color.TextSecondary
	end
end

local function render()
	if not shown then
		return
	end
	local snapshot = MatchClient.get()
	Ui.clear(list)
	if snapshot == nil then
		return
	end
	roundLabel.Text = if snapshot.round > 0 then string.format(M.Round, snapshot.round) else ""
	header(0)
	local mine = MatchClient.myTeamId()
	for i, team in snapshot.teams do
		local order = if team.id == mine then 1 elseif team.eliminated then 200 + (team.placement or 0) else 10 + i
		teamBlock(snapshot, team, order, team.id == mine)
	end
end

local function setShown(value: boolean)
	shown = value
	gui.Enabled = value
	if touchButton then
		touchButton.setKind(if value then "primary" else "secondary")
	end
	render()
end

local function build()
	gui = Ui.screen("Scoreboard", 45, Enum.ScreenInsets.CoreUISafeInsets)
	gui.Enabled = false
	local content: Frame
	panel, content = Ui.panel("Panel", gui, Theme.Space.PanelPadding)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.62, 0.72)
	Ui.sizeLimit(panel, Vector2.new(340, 220), Vector2.new(760, 560))

	local title = Ui.label("Title", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, content)
	title.Size = UDim2.new(0.6, 0, 0, 28)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = S.Title
	-- Denunciar sempre acessível (GDD 12.4, F8). No PC o botão libera o mouse enquanto o placar está aberto.
	local report = Widgets.button(content, Strings.Social.Report, "secondary", {
		size = UDim2.fromOffset(120, 28),
		textSize = Theme.TextSize.Label,
		arrow = false,
		modal = true,
	})
	report.root.AnchorPoint = Vector2.new(1, 0)
	report.root.Position = UDim2.fromScale(1, 0)
	report.onClick(function()
		if UiConfig.Scoreboard.HoldToShow and InputDevice.get() ~= "Touch" then
			setShown(false)
		end
		ReportPanel.open()
	end)
	roundLabel = Ui.label("Round", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextSecondary, content)
	roundLabel.AnchorPoint = Vector2.new(1, 0)
	roundLabel.Position = UDim2.new(1, -132, 0, 0)
	roundLabel.Size = UDim2.new(0.4, -132, 0, 28)
	roundLabel.TextXAlignment = Enum.TextXAlignment.Right

	list = Ui.scroll("List", Enum.ScrollingDirection.Y, content)
	list.Position = UDim2.fromOffset(0, 36)
	list.Size = UDim2.new(1, 0, 1, -36)
	Ui.list(list, Enum.FillDirection.Vertical, 6)
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Celular: botão PLACAR no topo esquerdo
	buttonGui = Ui.screen("ScoreboardButton", 6, Enum.ScreenInsets.CoreUISafeInsets)
	touchButton = Widgets.button(buttonGui, S.Button, "secondary", {
		size = UDim2.fromOffset(96, Theme.Touch.MinTarget),
		textSize = Theme.TextSize.Label,
	})
	-- Embaixo da engrenagem (coluna da esquerda), longe do placar do topo
	touchButton.root.Position =
		UDim2.fromOffset(Theme.ScreenMargin, Theme.ScreenMargin / 2 + Theme.Touch.MinTarget + Theme.Space.Small)
	touchButton.onClick(function()
		setShown(not shown)
	end)
	buttonGui.Parent = player:WaitForChild("PlayerGui")
end

local function refreshButton()
	buttonGui.Enabled = InputDevice.get() == "Touch"
end

function Scoreboard.Start()
	if not MatchClient.isEnabled() then
		return
	end
	setCoreList(false)
	build()
	refreshButton()
	InputDevice.onChanged(refreshButton)
	MatchClient.onChanged(render)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == KEYS.Scoreboard then
			setShown(if UiConfig.Scoreboard.HoldToShow then true else not shown)
		elseif input.KeyCode == KEYS.ScoreboardPad then
			setShown(not shown)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == KEYS.Scoreboard and UiConfig.Scoreboard.HoldToShow then
			setShown(false)
		end
	end)
	-- Abates mudam sem foto nova da partida: atualiza enquanto o placar está aberto
	task.spawn(function()
		while true do
			task.wait(1)
			if shown then
				render()
			end
		end
	end)
end

return Scoreboard
