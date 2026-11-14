--!strict
-- Ranking global (F9, GDD 9.3 e DADOS-JOGADOR 8), aberto pelo lobby (RANKING).
--   * Os 100 primeiros por PE, com posição, nome, elo (ícone + nome na cor da faixa) e PE.
--   * O ADM fica fixo no topo com o selo ADM, fora da contagem.
--   * A minha linha tem fundo do acento bem leve; embaixo, "Sua posição" (ou "fora dos 100").
--   * O servidor lê o ranking a cada 5 min; abrir a tela só pede a cópia que ele já tem.
-- Celular: rolar com o dedo. PC: roda do mouse. Controle: seleção pelas linhas não é necessária (só leitura).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local RankRules = require(Shared.Progression.RankRules)
local RankingTypes = require(Shared.Progression.RankingTypes)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.Ui)

local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local RankBadge = require(script.Parent.Parent.Common.Ui.RankBadge)
local Widgets = require(script.Parent.Parent.Common.Ui.Widgets)

local R = Strings.Ranking
local ROW_HEIGHT = 36
local POSITION_WIDTH = 48
local POINTS_WIDTH = 90
local TIER_WIDTH = 120

local RankingScreen = {}

local player = Players.LocalPlayer
local modal: Widgets.Modal
local statusLabel: TextLabel
local list: ScrollingFrame
local footer: TextLabel
local board: RankingTypes.Board? = nil
local requestEvent: RemoteEvent

local function myTier(): string
	local profile = PlayerDataClient.get()
	local points = if profile then profile.rank.points else 0
	return RankBadge.rich(RankRules.displayTier(player.UserId, points))
		.. "  "
		.. string.format(Strings.RankPoints, points)
end

local function addRow(order: number, position: string, entry: RankingTypes.Entry, showPoints: boolean)
	local row = Ui.frame("Row", list)
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	row.BackgroundColor3 = Theme.Color.Accent
	local isMe = entry.userId == player.UserId
	row.BackgroundTransparency = if isMe or entry.tier == "Adm" then Theme.RankingMeTransparency else 1
	Ui.corner(row, 6)

	local pos = Ui.label("Position", Theme.Font.Number, Theme.TextSize.Body, Theme.Color.TextSecondary, row)
	pos.Size = UDim2.new(0, POSITION_WIDTH, 1, 0)
	pos.Text = position

	local name = Ui.label("Name", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, row)
	name.Position = UDim2.fromOffset(POSITION_WIDTH, 0)
	name.Size = UDim2.new(1, -(POSITION_WIDTH + TIER_WIDTH + POINTS_WIDTH), 1, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = if isMe then `{entry.name} ({R.You})` else entry.name

	local tier = Ui.label("Tier", Theme.Font.Title, Theme.TextSize.Label, Theme.Color.TextPrimary, row)
	tier.AnchorPoint = Vector2.new(1, 0)
	tier.Position = UDim2.new(1, -POINTS_WIDTH, 0, 0)
	tier.Size = UDim2.new(0, TIER_WIDTH, 1, 0)
	tier.TextXAlignment = Enum.TextXAlignment.Left
	tier.RichText = true
	tier.Text = RankBadge.rich(entry.tier)

	local points = Ui.label("Points", Theme.Font.Number, Theme.TextSize.Body, Theme.Color.TextPrimary, row)
	points.AnchorPoint = Vector2.new(1, 0)
	points.Position = UDim2.new(1, -8, 0, 0)
	points.Size = UDim2.new(0, POINTS_WIDTH - 8, 1, 0)
	points.TextXAlignment = Enum.TextXAlignment.Right
	points.Text = if showPoints then string.format(Strings.RankPoints, entry.points) else R.AdminRow
	points.TextColor3 = if showPoints then Theme.Color.TextPrimary else Theme.Color.TextSecondary
end

local function render()
	Ui.clear(list)
	local current = board
	if current == nil then
		statusLabel.Text = R.Loading
		footer.Text = ""
		return
	end
	local order = 0
	for _, admin in current.admins do
		order += 1
		addRow(order, RankBadge.icon("Adm"), admin, false)
	end
	local mine: number? = nil
	for i, entry in current.entries do
		order += 1
		addRow(order, string.format(R.Position, i), entry, true)
		if entry.userId == player.UserId then
			mine = i
		end
	end
	if not current.available then
		statusLabel.Text = R.Unavailable
	elseif #current.entries == 0 then
		statusLabel.Text = R.Empty
	else
		local minutes = math.floor((os.time() - current.updatedAt) / 60)
		statusLabel.Text = if minutes <= 0 then R.UpdatedNow else string.format(R.UpdatedAgo, minutes)
	end
	if RankRules.isAdmin(player.UserId) then
		footer.Text = myTier()
	elseif mine then
		footer.Text = string.format(R.YourPosition, mine, myTier())
	else
		footer.Text = string.format(R.OutsideTop, myTier())
	end
end

local function build()
	modal = Widgets.modal("RankingScreen", 50, {
		title = R.Title,
		size = UDim2.fromScale(0.56, 0.84),
		touchSize = UDim2.fromScale(0.94, 0.95),
		maxSize = Vector2.new(640, 680),
	})
	local body = modal.body

	local subtitle = Ui.paragraph("Subtitle", Theme.Font.Body, Theme.TextSize.Label, Theme.Color.TextSecondary, body)
	subtitle.Size = UDim2.fromScale(1, 0)
	subtitle.Text = R.Subtitle

	statusLabel = Ui.label("Status", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, body)
	statusLabel.Position = UDim2.fromOffset(0, 34)
	statusLabel.Size = UDim2.new(1, 0, 0, 16)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left

	list = Ui.scroll("List", Enum.ScrollingDirection.Y, body)
	list.Position = UDim2.fromOffset(0, 56)
	list.Size = UDim2.new(1, 0, 1, -56 - 30)
	list.ScrollBarThickness = 4
	Ui.list(list, Enum.FillDirection.Vertical, 2)

	footer = Ui.label("Footer", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, body)
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Size = UDim2.new(1, 0, 0, 24)
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.RichText = true

	modal.gui.Parent = player:WaitForChild("PlayerGui")
	render()
end

function RankingScreen.open()
	if modal == nil then
		return
	end
	modal.open()
	render()
	requestEvent:FireServer()
end

function RankingScreen.Start()
	requestEvent = Remotes.event("RankingRequest")
	build()
	Remotes.event("RankingBoard").OnClientEvent:Connect(function(data: RankingTypes.Board)
		board = data
		if modal.isOpen() then
			render()
		end
	end)
	PlayerDataClient.onChanged(function()
		if modal.isOpen() then
			render()
		end
	end)
end

return RankingScreen
