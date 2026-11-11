--!strict
-- Tela de Cartas (ESTILO T1, F7), aberta pelo lobby (CARTAS) e pela aba Habilidade do Arsenal.
--   * Filtros por raridade no topo, sempre com nome e ícone (nunca só a cor).
--   * Carrossel: a carta escolhida no centro, maior; as vizinhas menores e inclinadas.
--     Celular: arrastar para os lados; PC: setas ← → ou roda do mouse; controle: direcional.
--   * Informação: nome, tecla fixa (chip), raridade, uma frase do que faz, se o jogador tem.
--   * GIRAR sempre visível embaixo da carta, mas DESATIVADO: o funcionamento é [ABERTO] (GDD 8.9).
--   * A raridade das 4 cartas iniciais também é [ABERTO]: elas aparecem em "Todas", com a borda na
--     cor da carta e "Raridade a definir"; os filtros de raridade ficam vazios.
--   * Cartas que o jogador não tem: escurecidas com cadeado.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local CardConfig = require(Shared.Config.CardConfig)
local Strings = require(Shared.Config.Strings)
local TextUtil = require(Shared.TextUtil)
local Theme = require(Shared.Config.Theme)
local Types = require(Shared.Types)
local Ui = require(Shared.Ui.Ui)

local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local Widgets = require(script.Parent.Parent.Common.Ui.Widgets)

local C = Strings.CardsScreen
local U = Strings.Ui
local RARITIES: { Types.Rarity } = { "Comum", "Epica", "Lendaria", "Celestial" }
local CENTER_SIZE = Vector2.new(150, 200)
local SIDE_SCALE = 0.72
local SWIPE_PIXELS = 50

local CardsScreen = {}

local player = Players.LocalPlayer
local modal: Widgets.Modal
local carousel: Frame
local emptyLabel: TextLabel
local nameLabel: TextLabel
local keyChip: TextLabel
local rarityHolder: Frame
local descLabel: TextLabel
local ownedLabel: TextLabel
local filter = "All"
local list: { CardConfig.CardDef } = {}
local index = 1
local tiles: { Frame } = {}

local function owns(id: string): boolean
	local profile = PlayerDataClient.get()
	return profile ~= nil and profile.cards.owned[id] ~= nil
end

local function filtered(): { CardConfig.CardDef }
	local result = {}
	for _, def in CardConfig.Cards do
		if filter == "All" or def.rarity == filter then
			table.insert(result, def)
		end
	end
	return result
end

-- Uma carta do carrossel: moldura na cor da raridade (ou da carta, sem raridade), nome e tecla.
local function makeTile(def: CardConfig.CardDef): Frame
	local tile = Ui.frame(def.id, carousel)
	tile.AnchorPoint = Vector2.new(0.5, 0.5)
	tile.Size = UDim2.fromOffset(CENTER_SIZE.X, CENTER_SIZE.Y)
	tile.BackgroundTransparency = 0
	tile.BackgroundColor3 = Theme.Color.PanelRaised
	Ui.corner(tile, 10)
	local rarity = def.rarity
	local color = if rarity then Theme.Rarity[rarity].color else (Theme.Cards[def.id] or Theme.Color.Accent)
	local stroke = Ui.stroke(tile, color, if rarity then Theme.Rarity[rarity].borderThickness else 3)
	if rarity and Theme.Rarity[rarity].glow == "neon" then
		-- Celestial: neon vermelho pulsando devagar (única exceção de neon forte, ESTILO 2.2)
		local info =
			TweenInfo.new(Theme.CelestialPulseSeconds / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		TweenService:Create(stroke, info, { Transparency = 0.5 }):Play()
	end

	-- Símbolo da carta: a tecla grande no meio, na cor da carta
	local symbol = Ui.label("Symbol", Theme.Font.Title, 64, color, tile)
	symbol.AnchorPoint = Vector2.new(0.5, 0.5)
	symbol.Position = UDim2.fromScale(0.5, 0.42)
	symbol.Size = UDim2.fromScale(1, 0.5)
	symbol.Text = def.key
	local name = Ui.label("Name", Theme.Font.Title, Theme.TextSize.PrimaryButton, Theme.Color.TextPrimary, tile)
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -10)
	name.Size = UDim2.new(1, -12, 0, 24)
	name.Text = TextUtil.upper((Strings.Cards[def.id] or { name = def.id }).name)

	if not owns(def.id) then
		local cover = Ui.frame("Locked", tile)
		cover.Size = UDim2.fromScale(1, 1)
		cover.BackgroundTransparency = 0.3
		cover.BackgroundColor3 = Theme.Color.Overlay
		Ui.corner(cover, 10)
		local lock = Ui.label("Lock", Theme.Font.Title, 34, Theme.Color.TextPrimary, cover)
		lock.Size = UDim2.fromScale(1, 1)
		lock.Text = U.Lock
	end
	local scale = Instance.new("UIScale")
	scale.Parent = tile
	return tile
end

local function layoutTiles(animate: boolean)
	for i, tile in tiles do
		local offset = i - index
		local scale = tile:FindFirstChildOfClass("UIScale") :: UIScale
		local target = if offset == 0 then 1 else SIDE_SCALE
		local x = 0.5 + offset * 0.24
		local props = { Position = UDim2.fromScale(x, 0.5), Rotation = math.clamp(offset, -1, 1) * 6 }
		tile.Visible = math.abs(offset) <= 2
		tile.ZIndex = 10 - math.abs(offset)
		if animate then
			local info = TweenInfo.new(Theme.Animation.TabSwitchTime * 1.5, Enum.EasingStyle.Quad)
			TweenService:Create(tile, info, props):Play()
			TweenService:Create(scale, info, { Scale = target }):Play()
		else
			tile.Position = props.Position
			tile.Rotation = props.Rotation
			scale.Scale = target
		end
	end
end

local function refreshInfo()
	local def = list[index]
	emptyLabel.Visible = def == nil
	for _, obj in { nameLabel, keyChip, descLabel, ownedLabel } :: { GuiObject } do
		obj.Visible = def ~= nil
	end
	Ui.clear(rarityHolder)
	if def == nil then
		return
	end
	nameLabel.Text = TextUtil.upper((Strings.Cards[def.id] or { name = def.id }).name)
	Ui.setChipText(keyChip, def.key)
	local rarity = def.rarity
	if rarity then
		Widgets.rarityTag(rarityHolder, rarity)
	else
		local none =
			Ui.label("NoRarity", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, rarityHolder)
		none.AutomaticSize = Enum.AutomaticSize.X
		none.Size = UDim2.fromOffset(0, 18)
		none.Text = C.NoRarity
	end
	descLabel.Text = (Strings.Cards[def.id] or { description = "" }).description
	local has = owns(def.id)
	ownedLabel.Text = if has then U.Check .. " " .. C.Owned else U.Lock .. " " .. C.Locked
	ownedLabel.TextColor3 = if has then Theme.Color.Success else Theme.Color.TextSecondary
end

local function rebuild()
	Ui.clear(carousel)
	table.clear(tiles)
	list = filtered()
	index = math.clamp(index, 1, math.max(1, #list))
	for _, def in list do
		table.insert(tiles, makeTile(def))
	end
	layoutTiles(false)
	refreshInfo()
end

local function move(delta: number)
	if #list == 0 then
		return
	end
	local nextIndex = math.clamp(index + delta, 1, #list)
	if nextIndex ~= index then
		index = nextIndex
		layoutTiles(true)
		refreshInfo()
	end
end

local function build()
	modal = Widgets.modal("CardsScreen", 50, { title = C.Title, maxSize = Vector2.new(900, 600) })
	local body = modal.body

	-- Filtros por raridade (nome + ícone)
	local items = { { id = "All", label = C.All } }
	for _, rarity in RARITIES do
		local info = Strings.Rarity[rarity]
		table.insert(items, { id = rarity, label = info.icon .. " " .. info.name })
	end
	local filters = Widgets.tabs(body, items, function(id: string)
		filter = id
		index = 1
		rebuild()
	end, Theme.Touch.MinTarget - 6)
	-- Ícones das raridades na cor da raridade (o nome escrito garante a leitura para daltônicos)
	for _, rarity in RARITIES do
		local button = filters.buttons[rarity]
		local label = button and button:FindFirstChild("Label") :: TextLabel?
		if label then
			label.TextColor3 = Theme.Rarity[rarity].color
		end
	end

	-- Carrossel (metade de cima) com setas
	local stage = Ui.frame("Stage", body)
	stage.Position = UDim2.fromOffset(0, Theme.Touch.MinTarget + 6)
	stage.Size = UDim2.new(1, 0, 0.62, -(Theme.Touch.MinTarget + 6))
	stage.ClipsDescendants = true
	carousel = Ui.frame("Carousel", stage)
	carousel.Size = UDim2.fromScale(1, 1)
	emptyLabel = Ui.label("Empty", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextSecondary, stage)
	emptyLabel.Size = UDim2.fromScale(1, 1)
	emptyLabel.Text = C.Empty
	local left = Widgets.iconButton(stage, U.Back, function()
		move(-1)
	end)
	left.AnchorPoint = Vector2.new(0, 0.5)
	left.Position = UDim2.fromScale(0, 0.5)
	left.ZIndex = 20
	local right = Widgets.iconButton(stage, U.Arrow, function()
		move(1)
	end)
	right.AnchorPoint = Vector2.new(1, 0.5)
	right.Position = UDim2.fromScale(1, 0.5)
	right.ZIndex = 20

	-- Arrastar para os lados (toque e mouse)
	local dragStart: Vector3? = nil
	stage.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			dragStart = input.Position
		end
	end)
	stage.InputEnded:Connect(function(input: InputObject)
		local start = dragStart
		if start == nil then
			return
		end
		dragStart = nil
		local dx = input.Position.X - start.X
		if math.abs(dx) >= SWIPE_PIXELS then
			move(if dx < 0 then 1 else -1)
		end
	end)
	stage.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			move(if input.Position.Z < 0 then 1 else -1)
		end
	end)

	-- Informação da carta + GIRAR
	local info = Ui.frame("Info", body)
	info.AnchorPoint = Vector2.new(0.5, 1)
	info.Position = UDim2.fromScale(0.5, 1)
	info.Size = UDim2.new(1, 0, 0.38, -4)
	local layout = Ui.list(info, Enum.FillDirection.Vertical, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local titleRow = Ui.frame("TitleRow", info)
	titleRow.Size = UDim2.new(1, 0, 0, 26)
	titleRow.LayoutOrder = 1
	local titleLayout = Ui.list(titleRow, Enum.FillDirection.Horizontal, 8)
	titleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	nameLabel = Ui.label("Name", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, titleRow)
	nameLabel.AutomaticSize = Enum.AutomaticSize.X
	nameLabel.Size = UDim2.fromOffset(0, 26)
	keyChip = Ui.keyChip("C", titleRow)
	keyChip.LayoutOrder = 2
	rarityHolder = Ui.frame("Rarity", titleRow)
	rarityHolder.AutomaticSize = Enum.AutomaticSize.X
	rarityHolder.Size = UDim2.fromOffset(0, 18)
	rarityHolder.LayoutOrder = 3

	descLabel = Ui.label("Desc", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary, info)
	descLabel.Size = UDim2.new(0.9, 0, 0, 36)
	descLabel.TextWrapped = true
	descLabel.LayoutOrder = 2
	ownedLabel = Ui.label("Owned", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.Success, info)
	ownedLabel.Size = UDim2.new(1, 0, 0, 16)
	ownedLabel.LayoutOrder = 3

	-- GIRAR: sempre visível, desativado enquanto o funcionamento é [ABERTO] (GDD 8.9)
	local spin = Widgets.button(info, C.Spin, "primary", {
		size = UDim2.fromOffset(200, Theme.Touch.MinTarget),
		textSize = Theme.TextSize.Body,
		arrow = false,
		order = 4,
	})
	spin.setEnabled(false)
	local soon = Ui.label("Soon", Theme.Font.Body, Theme.TextSize.Label, Theme.Color.TextSecondary, info)
	soon.Size = UDim2.new(1, 0, 0, 16)
	soon.Text = C.SpinSoon
	soon.LayoutOrder = 5

	modal.gui.Parent = player:WaitForChild("PlayerGui")
	filters.select("All")
end

function CardsScreen.open()
	if modal == nil then
		return
	end
	rebuild()
	modal.open()
end

function CardsScreen.Start()
	build()
	PlayerDataClient.onChanged(function()
		if modal.isOpen() then
			rebuild()
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not modal.isOpen() or processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.DPadLeft then
			move(-1)
		elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.DPadRight then
			move(1)
		end
	end)
end

return CardsScreen
