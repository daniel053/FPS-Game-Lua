--!strict
-- Tela de mapas de duelo (ESTILO T4, tela de informação [PROPOSTA]), aberta pelo lobby (MAPAS).
--   * Esquerda: o desenho do mundo da partida visto de cima — o mirante plano no meio (losango) e
--     as 4 ilhas de duelo em volta, cada uma com o nome. Tocar numa ilha mostra a descrição.
--   * Direita: ILHA CENTRAL (o mirante) e a ilha escolhida, com uma frase de cada (GDD 15).
-- Visual cinza até a F10 (aviso pequeno no rodapé).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local MapConfig = require(Shared.Config.MapConfig)
local Strings = require(Shared.Config.Strings)
local TextUtil = require(Shared.TextUtil)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.Ui)

local Widgets = require(script.Parent.Parent.Common.Ui.Widgets)

local M = Strings.MapsScreen
local POSITIONS: { [string]: Vector2 } = {
	NorthWest = Vector2.new(0.2, 0.22),
	NorthEast = Vector2.new(0.8, 0.22),
	SouthWest = Vector2.new(0.2, 0.78),
	SouthEast = Vector2.new(0.8, 0.78),
}

local MapsScreen = {}

local player = Players.LocalPlayer
local modal: Widgets.Modal
local islandButtons: { [string]: TextButton } = {}
local selectedTitle: TextLabel
local selectedBody: TextLabel
local selected = "map_praca"

local function selectIsland(id: string)
	selected = id
	for mapId, button in islandButtons do
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if mapId == id then Theme.Color.Accent else Theme.Color.PanelBorder
			stroke.Thickness = if mapId == id then Theme.Selected.BorderThickness else 1
		end
	end
	selectedTitle.Text = TextUtil.upper(Strings.Maps[id] or id)
	selectedBody.Text = M.Descriptions[id] or ""
end

local function build()
	modal = Widgets.modal("MapsScreen", 50, { title = M.Title, maxSize = Vector2.new(940, 600) })
	local body = modal.body

	-- Desenho do mundo (esquerda)
	local world = Ui.frame("World", body)
	world.Size = UDim2.new(0.62, -8, 1, -22)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1.4
	aspect.Parent = world

	-- Linhas do mirante até cada ilha
	for _, map in MapConfig.Maps do
		local p = POSITIONS[map.position]
		local link = Ui.frame("Link", world)
		link.AnchorPoint = Vector2.new(0.5, 0.5)
		link.Position = UDim2.fromScale((0.5 + p.X) / 2, (0.5 + p.Y) / 2)
		link.Size = UDim2.new(0.34, 0, 0, 2)
		link.Rotation = math.deg(math.atan2((p.Y - 0.5) / 1.4, p.X - 0.5))
		link.BackgroundTransparency = 0.4
		link.BackgroundColor3 = Theme.Color.PanelBorder
	end

	local mirante = Ui.frame("Mirante", world)
	mirante.AnchorPoint = Vector2.new(0.5, 0.5)
	mirante.Position = UDim2.fromScale(0.5, 0.5)
	mirante.Size = UDim2.fromScale(0.2, 0.28)
	mirante.Rotation = 45
	mirante.BackgroundTransparency = 0
	mirante.BackgroundColor3 = Theme.Match.MiranteFloor
	Ui.stroke(mirante, Theme.Match.MiranteEdge, 2)
	local miranteName = Ui.label("Name", Theme.Font.Title, Theme.TextSize.Body, Theme.Color.Overlay, world)
	miranteName.AnchorPoint = Vector2.new(0.5, 0.5)
	miranteName.Position = UDim2.fromScale(0.5, 0.5)
	miranteName.Size = UDim2.fromOffset(100, 20)
	miranteName.Text = TextUtil.upper(Strings.Maps.mirante)

	for _, map in MapConfig.Maps do
		local p = POSITIONS[map.position]
		local island = Instance.new("TextButton")
		island.Name = map.id
		island.Text = ""
		island.AutoButtonColor = true
		island.AnchorPoint = Vector2.new(0.5, 0.5)
		island.Position = UDim2.fromScale(p.X, p.Y)
		island.Size = UDim2.fromScale(0.3, 0.3)
		island.BackgroundColor3 = Theme.Match.IslandFloor
		Ui.corner(island, 10)
		Ui.stroke(island)
		island.Parent = world
		local label = Ui.label("Name", Theme.Font.Title, Theme.TextSize.Body, Theme.Color.TextPrimary, island)
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.fromScale(0.5, 0.06)
		label.Size = UDim2.new(1, 0, 0, 20)
		label.BackgroundTransparency = 0
		label.BackgroundColor3 = Theme.Color.PanelBase
		label.Text = TextUtil.upper(Strings.Maps[map.id] or map.id)
		island.Activated:Connect(function()
			selectIsland(map.id)
		end)
		islandButtons[map.id] = island
	end

	-- Informações (direita)
	local side, content = Ui.panel("Side", body, 12)
	side.AnchorPoint = Vector2.new(1, 0)
	side.Position = UDim2.fromScale(1, 0)
	side.Size = UDim2.new(0.38, -8, 1, -22)
	Ui.list(content, Enum.FillDirection.Vertical, 6)

	Widgets.sectionTitle(content, M.CentralTitle, 1)
	local miranteTitle =
		Ui.label("MiranteTitle", Theme.Font.Title, Theme.TextSize.PrimaryButton, Theme.Color.TextPrimary, content)
	miranteTitle.Size = UDim2.new(1, 0, 0, 22)
	miranteTitle.TextXAlignment = Enum.TextXAlignment.Left
	miranteTitle.Text = TextUtil.upper(Strings.Maps.mirante)
	miranteTitle.LayoutOrder = 2
	local miranteBody =
		Ui.paragraph("MiranteBody", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary, content)
	miranteBody.Text = M.Descriptions.mirante
	miranteBody.LayoutOrder = 3

	local gap = Ui.frame("Gap", content)
	gap.Size = UDim2.new(1, 0, 0, 8)
	gap.LayoutOrder = 4
	Widgets.sectionTitle(content, M.DuelTitle, 5)
	selectedTitle = Ui.label("Title", Theme.Font.Title, Theme.TextSize.PrimaryButton, Theme.Color.TextPrimary, content)
	selectedTitle.Size = UDim2.new(1, 0, 0, 22)
	selectedTitle.TextXAlignment = Enum.TextXAlignment.Left
	selectedTitle.LayoutOrder = 6
	selectedBody = Ui.paragraph("Body", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary, content)
	selectedBody.LayoutOrder = 7

	local gray = Ui.label("Gray", Theme.Font.Body, Theme.TextSize.Label, Theme.Color.TextSecondary, body)
	gray.AnchorPoint = Vector2.new(0, 1)
	gray.Position = UDim2.fromScale(0, 1)
	gray.Size = UDim2.new(1, 0, 0, 16)
	gray.TextXAlignment = Enum.TextXAlignment.Left
	gray.Text = M.Gray

	selectIsland(selected)
	modal.gui.Parent = player:WaitForChild("PlayerGui")
end

function MapsScreen.open()
	if modal then
		modal.open()
	end
end

function MapsScreen.Start()
	build()
end

return MapsScreen
