--!strict
-- Tela de Cartas (ESTILO T1, revista pelo dono do projeto na F7; referência
-- docs/referencias/ref-t1-cartas.webp), aberta pelo lobby (CARTAS).
--   * Filtros numa linha: TODAS, por TECLA (C, Q, E, X — a coleção cresce e cada carta tem tecla fixa)
--     e por RARIDADE (nome + ícone, nunca só a cor; com zero cartas o filtro fica apagado).
--   * Carrossel em ordem de tecla: a carta escolhida no centro, maior e com brilho discreto; as
--     vizinhas menores e inclinadas. Celular: arrastar; PC: setas ← → ou roda do mouse.
--   * Embaixo: nome + selo da raridade, a frase do que faz, a linha de atributos (números do
--     CardConfig), EQUIPAR, GIRAR (desativado: GDD 8.9 [ABERTO]) e "na sua coleção".
--   * Aba "Skins de cartas / versos" no rodapé, desativada até a F9.
-- A arte das cartas é da F10: por enquanto, fundo na cor da carta e a tecla grande no meio.
-- A raridade das 4 cartas iniciais é [ABERTO] (GDD 8.9): sem raridade, borda na cor da carta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local CardConfig = require(Shared.Config.CardConfig)
local Strings = require(Shared.Config.Strings)
local TextUtil = require(Shared.TextUtil)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.Ui)

local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local Widgets = require(script.Parent.Parent.Common.Ui.Widgets)

local C = Strings.CardsScreen
local U = Strings.Ui
local KEYS = { "C", "Q", "E", "X" }
local RARITIES = { "Comum", "Epica", "Lendaria", "Celestial" }
local CARD_SIZE = Vector2.new(150, 206)
local SIDE_SCALE = 0.74
local SIDE_STEP = 0.23 -- distância entre as cartas do carrossel (fração da largura)
local SWIPE_PIXELS = 50
local CHIP_HEIGHT = 36

type Chip = { button: TextButton, stroke: UIStroke, label: TextLabel, color: Color3 }

local CardsScreen = {}

local player = Players.LocalPlayer
local modal: Widgets.Modal
local carousel: Frame
local emptyLabel: TextLabel
local info: GuiObject
local nameLabel: TextLabel
local rarityPill: TextLabel
local rarityStroke: UIStroke
local descLabel: TextLabel
local statsLabel: TextLabel
local ownedLabel: TextLabel
local equipButton: Widgets.Button
local keyFilter: string? = nil
local rarityFilter: string? = nil
local chips: { [string]: Chip } = {}
local list: { CardConfig.CardDef } = {}
local index = 1
local tiles: { Frame } = {}

local function owns(id: string): boolean
	local profile = PlayerDataClient.get()
	return profile ~= nil and profile.cards.owned[id] ~= nil
end

local function cardName(id: string): string
	return (Strings.Cards[id] or { name = id }).name
end

local function cardColor(def: CardConfig.CardDef): Color3
	local rarity = def.rarity
	return if rarity then Theme.Rarity[rarity].color else (Theme.Cards[def.id] or Theme.Color.Accent)
end

-- Ordem de exibição: por tecla (C, Q, E, X) e, dentro dela, a ordem do CardConfig.
local function sorted(): { CardConfig.CardDef }
	local result = {}
	for _, key in KEYS do
		for _, def in CardConfig.Cards do
			if def.key == key then
				table.insert(result, def)
			end
		end
	end
	return result
end

local function matches(def: CardConfig.CardDef, key: string?, rarity: string?): boolean
	return (key == nil or def.key == key) and (rarity == nil or def.rarity == rarity)
end

-- Linha de atributos de cada carta, com os números do CardConfig.
local function statsLine(def: CardConfig.CardDef): string
	local S = C.Stats
	local p = def.params
	local parts: { string } = {}
	if def.id == "card_nuvem" then
		parts = {
			string.format(S.Duration, p.Duration),
			string.format(S.Charges, def.charges),
			string.format(S.Radius, p.Radius),
		}
	elseif def.id == "card_impulso" then
		parts = { string.format(S.Height, p.LaunchHeight), string.format(S.Cooldown, def.cooldown or 0) }
	elseif def.id == "card_tremor" then
		parts = {
			string.format(S.Slow, math.floor(p.SlowPercent * 100 + 0.5)),
			string.format(S.Effect, p.DebuffDuration),
			string.format(S.Cooldown, def.cooldown or 0),
		}
	elseif def.id == "card_renascer" then
		parts = {
			string.format(S.Window, p.Window),
			string.format(S.UsesPerRound, CardConfig.UltUsesPerRound),
			string.format(S.Unlocks, CardConfig.UltUnlockRound),
		}
	else
		table.insert(parts, string.format(S.Charges, def.charges))
		if def.cooldown then
			table.insert(parts, string.format(S.Cooldown, def.cooldown))
		end
	end
	return table.concat(parts, "   |   ")
end

-- Carta do carrossel ------------------------------------------------------------------------------

local function makeTile(def: CardConfig.CardDef): Frame
	local color = cardColor(def)
	local tile = Ui.frame(def.id, carousel)
	tile.AnchorPoint = Vector2.new(0.5, 0.5)
	tile.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)

	-- Brilho discreto em volta (só aparece na carta do centro)
	local glow = Ui.frame("Glow", tile)
	glow.Position = UDim2.fromOffset(-6, -6)
	glow.Size = UDim2.new(1, 12, 1, 12)
	glow.BackgroundTransparency = 0.7
	glow.BackgroundColor3 = color
	glow.ZIndex = 0
	Ui.corner(glow, 16)

	local face = Ui.frame("Face", tile)
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundTransparency = 0
	face.BackgroundColor3 = color
	Ui.corner(face, 12)
	-- Fundo: a cor da carta escurecendo para o painel (sem degradê chamativo)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(color:Lerp(Theme.Color.PanelBase, 0.55), Theme.Color.PanelBase)
	gradient.Parent = face
	local rarity = def.rarity
	local border = Ui.stroke(face, color, if rarity then Theme.Rarity[rarity].borderThickness else 3)
	if rarity and Theme.Rarity[rarity].glow == "neon" then
		-- Celestial: neon vermelho pulsando devagar (única exceção de neon forte, ESTILO 2.2)
		local pulse =
			TweenInfo.new(Theme.CelestialPulseSeconds / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		TweenService:Create(border, pulse, { Transparency = 0.5 }):Play()
	end
	-- Moldura interna fina
	local inner = Ui.frame("Inner", face)
	inner.Position = UDim2.fromOffset(7, 7)
	inner.Size = UDim2.new(1, -14, 1, -14)
	Ui.corner(inner, 8)
	local innerStroke = Ui.stroke(inner, color, 1)
	innerStroke.Transparency = 0.5

	local key = Ui.label("Key", Theme.Font.Title, 76, Theme.Color.TextPrimary, face)
	key.AnchorPoint = Vector2.new(0.5, 0.5)
	key.Position = UDim2.fromScale(0.5, 0.42)
	key.Size = UDim2.fromScale(1, 0.5)
	key.Text = def.key
	key.TextStrokeColor3 = color
	key.TextStrokeTransparency = 0.4
	if rarity then
		local icon = Ui.label("Rarity", Theme.Font.Title, Theme.TextSize.Body, color, face)
		icon.Position = UDim2.fromOffset(12, 10)
		icon.Size = UDim2.fromOffset(20, 20)
		icon.Text = Strings.Rarity[rarity].icon
	end
	local name = Ui.label("Name", Theme.Font.Title, Theme.TextSize.PrimaryButton, Theme.Color.TextPrimary, face)
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -14)
	name.Size = UDim2.new(1, -16, 0, 24)
	name.Text = TextUtil.upper(cardName(def.id))
	Ui.outlineText(name)

	if not owns(def.id) then
		local cover = Ui.frame("Locked", face)
		cover.Size = UDim2.fromScale(1, 1)
		cover.BackgroundTransparency = 0.3
		cover.BackgroundColor3 = Theme.Color.Overlay
		cover.ZIndex = 3
		Ui.corner(cover, 12)
		local lock = Ui.label("Lock", Theme.Font.Title, 34, Theme.Color.TextPrimary, cover)
		lock.Size = UDim2.fromScale(1, 1)
		lock.Text = U.Lock
		lock.ZIndex = 3
	end
	local scale = Instance.new("UIScale")
	scale.Parent = tile
	return tile
end

local function layoutTiles(animate: boolean)
	for i, tile in tiles do
		local offset = i - index
		local scale = tile:FindFirstChildOfClass("UIScale") :: UIScale
		local glow = tile:FindFirstChild("Glow") :: Frame?
		if glow then
			glow.Visible = offset == 0
		end
		local target = if offset == 0 then 1 else SIDE_SCALE
		local props = {
			Position = UDim2.fromScale(0.5 + offset * SIDE_STEP, 0.5),
			Rotation = math.clamp(offset, -1, 1) * 7,
		}
		tile.Visible = math.abs(offset) <= 2
		tile.ZIndex = 10 - math.abs(offset)
		if animate then
			local tween = TweenInfo.new(Theme.Animation.TabSwitchTime * 1.5, Enum.EasingStyle.Quad)
			TweenService:Create(tile, tween, props):Play()
			TweenService:Create(scale, tween, { Scale = target }):Play()
		else
			tile.Position = props.Position
			tile.Rotation = props.Rotation
			scale.Scale = target
		end
	end
end

-- Informação da carta escolhida ---------------------------------------------------------------------

local function refreshInfo()
	local def = list[index]
	emptyLabel.Visible = def == nil
	info.Visible = def ~= nil
	if def == nil then
		return
	end
	nameLabel.Text = TextUtil.upper(cardName(def.id))
	local rarity = def.rarity
	if rarity then
		local style = Theme.Rarity[rarity]
		rarityPill.Text = Strings.Rarity[rarity].icon .. " " .. TextUtil.upper(Strings.Rarity[rarity].name)
		rarityPill.TextColor3 = style.color
		rarityStroke.Color = style.color
	else
		rarityPill.Text = TextUtil.upper(C.NoRarity)
		rarityPill.TextColor3 = Theme.Color.TextSecondary
		rarityStroke.Color = Theme.Color.PanelBorder
	end
	descLabel.Text = (Strings.Cards[def.id] or { description = "" }).description
	statsLabel.Text = statsLine(def)
	local has = owns(def.id)
	-- Uma carta por tecla (GDD 8.3): a carta da coleção já é a da tecla dela
	equipButton.setText(if has then C.Equipped .. " " .. U.Check else C.LockedButton)
	equipButton.setEnabled(false)
	ownedLabel.Text = if has then U.Check .. " " .. TextUtil.upper(C.Owned) else U.Lock .. " " .. C.Locked
	ownedLabel.TextColor3 = if has then Theme.Color.Success else Theme.Color.TextSecondary
end

-- Filtros ------------------------------------------------------------------------------------------

local function paintChips()
	local all = sorted()
	for id, chip in chips do
		local isKey = table.find(KEYS, id) ~= nil
		local active = if id == "All"
			then keyFilter == nil and rarityFilter == nil
			elseif isKey then keyFilter == id
			else rarityFilter == id
		-- Quantas cartas o filtro mostraria junto com o outro filtro
		local count = 0
		for _, def in all do
			if
				id == "All"
				or (isKey and matches(def, id, rarityFilter))
				or (not isKey and matches(def, keyFilter, id))
			then
				count += 1
			end
		end
		local empty = count == 0
		chip.button.BackgroundColor3 = if active then Theme.Color.Accent else Theme.Color.PanelRaised
		chip.button.BackgroundTransparency = if empty and not active then 0.5 else 0
		chip.stroke.Color = if active then Theme.Color.Accent else chip.color
		chip.stroke.Transparency = if empty and not active then 0.6 else 0
		chip.label.TextColor3 = if active then Theme.Color.TextPrimary else chip.color
		chip.label.TextTransparency = if empty and not active then 0.5 else 0
	end
end

local function rebuild()
	Ui.clear(carousel)
	table.clear(tiles)
	list = {}
	for _, def in sorted() do
		if matches(def, keyFilter, rarityFilter) then
			table.insert(list, def)
		end
	end
	index = math.clamp(index, 1, math.max(1, #list))
	for _, def in list do
		table.insert(tiles, makeTile(def))
	end
	layoutTiles(false)
	refreshInfo()
	paintChips()
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

local function onChip(id: string)
	if id == "All" then
		keyFilter, rarityFilter = nil, nil
	elseif table.find(KEYS, id) then
		keyFilter = if keyFilter == id then nil else id
	else
		rarityFilter = if rarityFilter == id then nil else id
	end
	index = 1
	rebuild()
end

local function makeChip(parent: Instance, id: string, text: string, color: Color3, order: number, width: number?)
	local button = Instance.new("TextButton")
	button.Name = id
	button.Text = ""
	button.AutoButtonColor = true
	button.LayoutOrder = order
	button.Size =
		UDim2.fromOffset(width or (Ui.textWidth(text, Theme.Font.Title, Theme.TextSize.Body) + 28), CHIP_HEIGHT)
	button.BackgroundColor3 = Theme.Color.PanelRaised
	Ui.corner(button)
	local stroke = Ui.stroke(button, color, 1)
	local label = Ui.label("Label", Theme.Font.Title, Theme.TextSize.Body, color, button)
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	button.Parent = parent
	button.Activated:Connect(function()
		onChip(id)
	end)
	chips[id] = { button = button, stroke = stroke, label = label, color = color }
end

local function divider(parent: Instance, order: number)
	local line = Ui.frame("Divider", parent)
	line.LayoutOrder = order
	line.Size = UDim2.fromOffset(1, CHIP_HEIGHT - 10)
	line.BackgroundTransparency = 0
	line.BackgroundColor3 = Theme.Color.PanelBorder
end

-- Montagem ------------------------------------------------------------------------------------------

local function build()
	modal = Widgets.modal("CardsScreen", 50, {
		title = C.Title,
		size = UDim2.fromScale(0.62, 0.86),
		touchSize = UDim2.fromScale(0.9, 0.95),
		maxSize = Vector2.new(820, 700),
	})
	local body = modal.body

	-- Filtros: TODAS | C Q E X | raridades
	local filters = Ui.scroll("Filters", Enum.ScrollingDirection.X, body)
	filters.Size = UDim2.new(1, 0, 0, CHIP_HEIGHT + 6)
	filters.ScrollBarThickness = 2
	local row = Ui.list(filters, Enum.FillDirection.Horizontal, Theme.Space.Small)
	row.VerticalAlignment = Enum.VerticalAlignment.Top
	makeChip(filters, "All", TextUtil.upper(C.All), Theme.Color.TextSecondary, 1)
	divider(filters, 2)
	for i, key in KEYS do
		makeChip(filters, key, key, Theme.Color.TextPrimary, 2 + i, CHIP_HEIGHT + 6)
	end
	divider(filters, 10)
	for i, rarity in RARITIES do
		local r = Strings.Rarity[rarity]
		makeChip(filters, rarity, r.icon .. " " .. TextUtil.upper(r.name), Theme.Rarity[rarity].color, 10 + i)
	end

	local top = CHIP_HEIGHT + 12
	local line = Ui.frame("Line", body)
	line.Position = UDim2.fromOffset(0, top - 2)
	line.Size = UDim2.new(1, 0, 0, 1)
	line.BackgroundTransparency = 0
	line.BackgroundColor3 = Theme.Color.PanelBorder

	-- Carrossel com setas
	local stage = Ui.frame("Stage", body)
	stage.Position = UDim2.fromOffset(0, top)
	stage.Size = UDim2.new(1, 0, 0.5, -top / 2)
	stage.ClipsDescendants = true
	carousel = Ui.frame("Carousel", stage)
	carousel.Size = UDim2.fromScale(1, 1)
	local cardFit = Instance.new("UIScale")
	cardFit.Parent = carousel
	local function fitCards()
		-- A carta encolhe em tela baixa (celular) para caber inteira
		cardFit.Scale = math.clamp((stage.AbsoluteSize.Y - 16) / CARD_SIZE.Y, 0.55, 1)
	end
	stage:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCards)
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

	-- Arrastar para os lados (toque e mouse) e roda do mouse
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

	-- Informação (metade de baixo, rola só em tela muito baixa)
	local bottom = Ui.scroll("Info", Enum.ScrollingDirection.Y, body)
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.Position = UDim2.new(0, 0, 1, -(Theme.Touch.MinTarget + 6))
	bottom.Size = UDim2.new(1, 0, 0.5, -(Theme.Touch.MinTarget + 6) - top / 2)
	bottom.ScrollBarThickness = 3
	info = bottom
	local layout = Ui.list(bottom, Enum.FillDirection.Vertical, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local titleRow = Ui.frame("TitleRow", bottom)
	titleRow.Size = UDim2.new(1, 0, 0, 32)
	titleRow.LayoutOrder = 1
	local titleLayout = Ui.list(titleRow, Enum.FillDirection.Horizontal, 10)
	titleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	nameLabel = Ui.label("CardName", Theme.Font.Title, Theme.TextSize.Title + 6, Theme.Color.TextPrimary, titleRow)
	nameLabel.AutomaticSize = Enum.AutomaticSize.X
	nameLabel.Size = UDim2.fromOffset(0, 32)
	rarityPill = Ui.label("Rarity", Theme.Font.Title, Theme.TextSize.Label, Theme.Color.TextSecondary, titleRow)
	rarityPill.AutomaticSize = Enum.AutomaticSize.X
	rarityPill.Size = UDim2.fromOffset(0, 24)
	rarityPill.LayoutOrder = 2
	rarityPill.BackgroundTransparency = 0
	rarityPill.BackgroundColor3 = Theme.Color.PanelRaised
	Ui.corner(rarityPill)
	rarityStroke = Ui.stroke(rarityPill, Theme.Color.PanelBorder, 1)
	local pillPad = Instance.new("UIPadding")
	pillPad.PaddingLeft = UDim.new(0, 10)
	pillPad.PaddingRight = UDim.new(0, 10)
	pillPad.Parent = rarityPill

	descLabel = Ui.label("Desc", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextPrimary, bottom)
	descLabel.Size = UDim2.fromScale(0.92, 0)
	descLabel.AutomaticSize = Enum.AutomaticSize.Y
	descLabel.TextWrapped = true
	descLabel.LayoutOrder = 2
	statsLabel = Ui.label("Stats", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, bottom)
	statsLabel.Size = UDim2.new(1, 0, 0, 18)
	statsLabel.LayoutOrder = 3

	local buttons = Ui.frame("Buttons", bottom)
	buttons.Size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget + 6)
	buttons.LayoutOrder = 4
	local buttonLayout = Ui.list(buttons, Enum.FillDirection.Horizontal, Theme.Space.Medium)
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	equipButton = Widgets.button(buttons, C.Equip, "primary", {
		size = UDim2.fromOffset(220, Theme.Touch.MinTarget + 6),
		order = 1,
	})
	-- GIRAR sempre visível embaixo da carta (ESTILO T1), desativado enquanto o GDD 8.9 é [ABERTO]
	local spin = Widgets.button(buttons, C.Spin, "secondary", {
		size = UDim2.fromOffset(150, Theme.Touch.MinTarget + 6),
		textSize = Theme.TextSize.Body,
		arrow = false,
		order = 2,
	})
	spin.setEnabled(false)

	ownedLabel = Ui.label("Owned", Theme.Font.Title, Theme.TextSize.Label, Theme.Color.Success, bottom)
	ownedLabel.Size = UDim2.new(1, 0, 0, 16)
	ownedLabel.LayoutOrder = 5

	-- Rodapé: skins de cartas / versos (F9)
	local skins = Widgets.button(body, C.CardSkins .. " · " .. C.Soon, "secondary", {
		size = UDim2.fromOffset(300, Theme.Touch.MinTarget),
		textSize = Theme.TextSize.Label,
		arrow = false,
	})
	skins.root.AnchorPoint = Vector2.new(0.5, 1)
	skins.root.Position = UDim2.fromScale(0.5, 1)
	skins.setEnabled(false)

	modal.gui.Parent = player:WaitForChild("PlayerGui")
	rebuild()
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
		if input.KeyCode == Enum.KeyCode.Left then
			move(-1)
		elseif input.KeyCode == Enum.KeyCode.Right then
			move(1)
		end
	end)
end

return CardsScreen
