--!strict
-- Denunciar ou bloquear (GDD 12.4, F8), aberto pelo placar (Tab) e pela tela final.
-- O jogo não consegue abrir a denúncia do Roblox para um jogador (a API não está disponível para
-- jogos): a tela explica o caminho pelo menu do Roblox e oferece BLOQUEAR, que é o pedido nativo do
-- Roblox (StarterGui:SetCore "PromptBlockPlayer"). Nada é guardado pelo jogo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.Ui)

local Avatars = require(script.Parent.Parent.Common.Ui.Avatars)
local Widgets = require(script.Parent.Parent.Common.Ui.Widgets)

local S = Strings.Social
local ROW_HEIGHT = 52

local ReportPanel = {}

local player = Players.LocalPlayer
local modal: Widgets.Modal? = nil
local list: ScrollingFrame

local function render()
	for _, child in list:GetChildren() do
		if child.Name == "Player" or child.Name == "Empty" then
			child:Destroy()
		end
	end
	local others = 0
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		others += 1
		local row = Ui.raised("Player", list)
		row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
		row.LayoutOrder = others
		local avatar = Avatars.new(row, ROW_HEIGHT - 12)
		avatar.root.Position = UDim2.fromOffset(8, 6)
		Avatars.set(avatar, other.UserId, other.DisplayName, Theme.Color.PanelBorder, false)
		local name = Ui.label("Name", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, row)
		name.Position = UDim2.fromOffset(ROW_HEIGHT + 4, 0)
		name.Size = UDim2.new(1, -(ROW_HEIGHT + 150), 1, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = `{other.DisplayName} (@{other.Name})`
		local block = Widgets.button(row, S.Block, "secondary", {
			size = UDim2.fromOffset(130, Theme.Touch.MinTarget),
			textSize = Theme.TextSize.Label,
			arrow = false,
			modal = true,
		})
		block.root.AnchorPoint = Vector2.new(1, 0.5)
		block.root.Position = UDim2.new(1, -6, 0.5, 0)
		local target = other
		block.onClick(function()
			pcall(function()
				StarterGui:SetCore("PromptBlockPlayer", target)
			end)
		end)
	end
	if others == 0 then
		local empty = Ui.label("Empty", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextSecondary, list)
		empty.Size = UDim2.new(1, 0, 0, 30)
		empty.Text = S.NoOneToReport
	end
end

local function build(): Widgets.Modal
	local m = Widgets.modal("ReportPanel", 60, {
		title = S.ReportTitle,
		size = UDim2.fromScale(0.55, 0.7),
		maxSize = Vector2.new(620, 520),
	})
	-- Uma lista só, que rola: a explicação primeiro e os jogadores embaixo (cabe em tela pequena)
	list = Ui.scroll("List", Enum.ScrollingDirection.Y, m.body)
	list.Size = UDim2.fromScale(1, 1)
	Ui.list(list, Enum.FillDirection.Vertical, 6)
	local help = Ui.paragraph("Help", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary, list)
	help.Size = UDim2.new(1, -8, 0, 0)
	help.LayoutOrder = 0
	help.Text = S.ReportHelp
	m.gui.Parent = player:WaitForChild("PlayerGui")
	return m
end

function ReportPanel.open()
	local m = modal or build()
	modal = m
	render()
	m.open()
end

return ReportPanel
