--!strict
-- Tela de Cartas (ESTILO T1), aberta pelo lobby (CARTAS). Revista pelo dono do projeto na F7 e de novo
-- depois da F10 ("a carta precisa dar vontade de ter", com a apresentação de coleção dos FPS táticos
-- como inspiração, adaptada):
--   * Filtros numa linha: TODAS, por TECLA (C, Q, E, X — a coleção cresce e cada carta tem tecla fixa)
--     e por RARIDADE (nome + ícone, nunca só a cor; com zero cartas o filtro fica apagado).
--   * Duas colunas. À esquerda, o PALCO: carrossel em ordem de tecla, a carta escolhida no centro,
--     maior, com a luz do palco na cor dela e um pedestal; as vizinhas menores e inclinadas. Celular:
--     arrastar; PC: setas ← → ou roda do mouse. Cada carta tem arte de fundo (CardBackdrop) e o
--     desenho dela (CardArt); ao ser escolhida, um brilho atravessa a carta uma vez.
--   * À direita, a FICHA: tecla e raridade, nome grande, a frase do que faz, os atributos em blocos
--     (números do CardConfig), EQUIPAR, GIRAR (vira a carta para ver o verso, F9; R no PC), "na sua
--     coleção" e o botão (desativado) de skins de cartas / versos.
--   * Carta que o jogador não tem: a arte continua à mostra, acinzentada, com cadeado e a faixa
--     BLOQUEADA (dá para ver o que falta conquistar).
-- As 4 cartas iniciais são Comuns (F9, GDD 8.9): moldura na cor da raridade.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local CardBackdrop = require(Shared.Ui.CardBackdrop)
local CardConfig = require(Shared.Config.CardConfig)
local Strings = require(Shared.Config.Strings)
local TextUtil = require(Shared.TextUtil)
local Theme = require(Shared.Config.Theme)
local CardArt = require(Shared.Ui.CardArt)
local Ui = require(Shared.Ui.Ui)

local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local Widgets = require(script.Parent.Parent.Common.Ui.Widgets)

local C = Strings.CardsScreen
local U = Strings.Ui
local KEYS = { "C", "Q", "E", "X" }
local RARITIES = { "Comum", "Epica", "Lendaria", "Celestial" }
local CARD_SIZE = Vector2.new(170, 236)
local SIDE_SCALE = 0.72
local SIDE_STEP = 0.29 -- distância entre as cartas do carrossel (fração da largura do palco)
local SWIPE_PIXELS = 50
local CHIP_HEIGHT = 36
local STAGE_WIDTH = 0.56 -- fração do corpo da tela para o palco; o resto é a ficha
local STAT_HEIGHT = 54
local LOCKED_TINT = Color3.fromRGB(150, 152, 168) -- carta bloqueada: arte acinzentada

type Chip = { button: TextButton, stroke: UIStroke, label: TextLabel, color: Color3 }
type StatTile = { icon: string, value: string, label: string }

local CardsScreen = {}

local player = Players.LocalPlayer
local modal: Widgets.Modal
local carousel: Frame
local stageGlows: { Frame } = {}
local emptyLabel: TextLabel
local info: GuiObject
local keyTag: TextLabel
local nameLabel: TextLabel
local nameBar: Frame
local watermark: TextLabel
local rarityPill: TextLabel
local rarityStroke: UIStroke
local descLabel: TextLabel
local statsGrid: Frame
local ownedLabel: TextLabel
local equipButton: Widgets.Button
local keyFilter: string? = nil
local rarityFilter: string? = nil
local chips: { [string]: Chip } = {}
local list: { CardConfig.CardDef } = {}
local index = 1
local tiles: { Frame } = {}
local shines: { [Frame]: () -> () } = {}

local function owns(id: string): boolean
	local profile = PlayerDataClient.get()
	return profile ~= nil and profile.cards.owned[id] ~= nil
end

local function cardName(id: string): string
	return (Strings.Cards[id] or { name = id }).name
end

-- Cor da carta e cor da moldura (a da raridade, ESTILO 2.2; sem raridade = a da carta).
local function cardColor(def: CardConfig.CardDef): Color3
	return Theme.Cards[def.id] or Theme.Color.Accent
end

local function frameColor(def: CardConfig.CardDef): Color3
	local rarity = def.rarity
	return if rarity then Theme.Rarity[rarity].color else cardColor(def)
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

-- Atributos de cada carta, com os números do CardConfig.
local function stat(name: string, value: number): StatTile
	local s = C.Stats[name]
	return { icon = s.icon, value = string.format(s.value, value), label = s.label }
end

local function statsOf(def: CardConfig.CardDef): { StatTile }
	local p = def.params
	if def.id == "card_nuvem" then
		return { stat("Duration", p.Duration), stat("Charges", def.charges), stat("Radius", p.Radius) }
	elseif def.id == "card_impulso" then
		return { stat("Height", p.LaunchHeight), stat("Cooldown", def.cooldown or 0) }
	elseif def.id == "card_tremor" then
		return {
			stat("Slow", math.floor(p.SlowPercent * 100 + 0.5)),
			stat("Effect", p.DebuffDuration),
			stat("Cooldown", def.cooldown or 0),
		}
	elseif def.id == "card_renascer" then
		return {
			stat("Window", p.Window),
			stat("UsesPerRound", CardConfig.UltUsesPerRound),
			stat("Unlocks", CardConfig.UltUnlockRound),
		}
	end
	local parts = { stat("Charges", def.charges) }
	if def.cooldown then
		table.insert(parts, stat("Cooldown", def.cooldown))
	end
	return parts
end

-- Carta do carrossel ------------------------------------------------------------------------------

local function makeTile(def: CardConfig.CardDef): Frame
	local color = cardColor(def)
	local rarity = def.rarity
	local has = owns(def.id)
	local tile = Ui.frame(def.id, carousel)
	tile.AnchorPoint = Vector2.new(0.5, 0.5)
	tile.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)

	-- Brilho discreto em volta (só aparece na carta do centro)
	local glow = Ui.frame("Glow", tile)
	glow.Position = UDim2.fromOffset(-7, -7)
	glow.Size = UDim2.new(1, 14, 1, 14)
	glow.BackgroundTransparency = 0.72
	glow.BackgroundColor3 = frameColor(def)
	glow.ZIndex = 0
	Ui.corner(glow, 18)

	local face = Ui.frame("Face", tile)
	face.AnchorPoint = Vector2.new(0.5, 0) -- GIRAR estreita a carta pelo meio
	face.Position = UDim2.fromScale(0.5, 0)
	face.Size = UDim2.fromScale(1, 1)
	face.ClipsDescendants = true
	Ui.corner(face, Theme.CardBackdrop.CornerRadius)

	-- Arte de fundo (raios, halo, padrão da carta, sombra) e o brilho que passa ao escolher
	local backdrop = CardBackdrop.draw(face, def.id, rarity)
	shines[tile] = backdrop.shine
	if not has then
		backdrop.root.GroupColor3 = LOCKED_TINT
	end
	local border = Ui.stroke(face, frameColor(def), if rarity then Theme.Rarity[rarity].borderThickness else 3)
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
	inner.ZIndex = 4
	Ui.corner(inner, 8)
	local innerStroke = Ui.stroke(inner, color:Lerp(Color3.new(1, 1, 1), 0.4), 1)
	innerStroke.Transparency = 0.45

	-- Desenho da carta (F10) no meio; a tecla fixa num chip no canto de cima
	local artHolder = Ui.frame("Art", face)
	artHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	artHolder.Position = UDim2.fromScale(0.5, Theme.CardBackdrop.ArtY)
	artHolder.Size = UDim2.fromScale(0.74, 0.5)
	artHolder.ZIndex = 4
	if CardArt.draw(artHolder, def.id, if has then color else color:Lerp(LOCKED_TINT, 0.6)) == nil then
		local key = Ui.label("Key", Theme.Font.Title, 76, Theme.Color.TextPrimary, artHolder)
		key.Size = UDim2.fromScale(1, 1)
		key.Text = def.key
		key.ZIndex = 4
	end
	local keyChip = Ui.keyChip(def.key, face)
	keyChip.AnchorPoint = Vector2.new(1, 0)
	keyChip.Position = UDim2.new(1, -12, 0, 12)
	keyChip.ZIndex = 5
	if rarity then
		local icon = Ui.label("Rarity", Theme.Font.Title, Theme.TextSize.Body, frameColor(def), face)
		icon.Position = UDim2.fromOffset(14, 12)
		icon.Size = UDim2.fromOffset(20, 20)
		icon.Text = Strings.Rarity[rarity].icon
		icon.ZIndex = 5
		Ui.outlineText(icon)
	end
	-- Nome embaixo, sobre a sombra da arte, com um filete na cor da raridade
	local name = Ui.label("Name", Theme.Font.Title, Theme.TextSize.PrimaryButton + 4, Theme.Color.TextPrimary, face)
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -22)
	name.Size = UDim2.new(1, -16, 0, 28)
	name.Text = TextUtil.upper(cardName(def.id))
	name.ZIndex = 5
	Ui.outlineText(name)
	local line = Ui.frame("Line", face)
	line.AnchorPoint = Vector2.new(0.5, 1)
	line.Position = UDim2.new(0.5, 0, 1, -16)
	line.Size = UDim2.new(0.36, 0, 0, 3)
	line.BackgroundTransparency = 0
	line.BackgroundColor3 = frameColor(def)
	line.ZIndex = 5
	Ui.corner(line, 2)

	if not has then
		-- Cadeado no meio e a faixa BLOQUEADA atravessando a carta: a arte continua à mostra
		local lock = Ui.label("Lock", Theme.Font.Title, 22, Theme.Color.TextPrimary, face)
		lock.AnchorPoint = Vector2.new(0.5, 0.5)
		lock.Position = UDim2.fromScale(0.5, Theme.CardBackdrop.ArtY)
		lock.Size = UDim2.fromOffset(46, 46)
		lock.BackgroundTransparency = 0.15
		lock.BackgroundColor3 = Theme.Color.Overlay
		lock.Text = U.Lock
		lock.ZIndex = 7
		Ui.corner(lock, 23)
		Ui.stroke(lock, Theme.Color.TextSecondary, 1)
		local ribbon = Ui.label("Ribbon", Theme.Font.Title, Theme.TextSize.Label, Theme.Color.TextPrimary, face)
		ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
		ribbon.Position = UDim2.fromScale(0.5, 0.7)
		ribbon.Size = UDim2.new(1, 0, 0, 20)
		ribbon.BackgroundTransparency = 0.25
		ribbon.BackgroundColor3 = Theme.Color.Overlay
		ribbon.Text = C.LockedRibbon
		ribbon.ZIndex = 7
	end

	-- Verso (GIRAR, F9): a cor da carta mais escura, a moldura da raridade e o símbolo do jogo no meio
	local back = Ui.frame("Back", tile)
	back.AnchorPoint = Vector2.new(0.5, 0)
	back.Position = UDim2.fromScale(0.5, 0)
	back.Size = UDim2.fromScale(0, 1)
	back.BackgroundTransparency = 0
	back.BackgroundColor3 = color:Lerp(Theme.Color.PanelBase, 0.7)
	back.ClipsDescendants = true
	back.Visible = false
	Ui.corner(back, Theme.CardBackdrop.CornerRadius)
	Ui.stroke(back, frameColor(def), if rarity then Theme.Rarity[rarity].borderThickness else 3)
	local backInner = Ui.frame("Inner", back)
	backInner.Position = UDim2.fromOffset(7, 7)
	backInner.Size = UDim2.new(1, -14, 1, -14)
	Ui.corner(backInner, 8)
	Ui.stroke(backInner, color, 1).Transparency = 0.5
	local symbol = Ui.label("Symbol", Theme.Font.Title, 64, color, back)
	symbol.AnchorPoint = Vector2.new(0.5, 0.5)
	symbol.Position = UDim2.fromScale(0.5, 0.44)
	symbol.Size = UDim2.fromScale(1, 0.5)
	symbol.Text = Strings.Logo.Symbol
	local gameName = Ui.label("GameName", Theme.Font.Title, Theme.TextSize.Label, Theme.Color.TextSecondary, back)
	gameName.AnchorPoint = Vector2.new(0.5, 1)
	gameName.Position = UDim2.new(0.5, 0, 1, -16)
	gameName.Size = UDim2.new(1, -16, 0, 18)
	gameName.TextWrapped = true
	gameName.Text = TextUtil.upper(Strings.GameName)

	local scale = Instance.new("UIScale")
	scale.Parent = tile
	return tile
end

-- GIRAR (F9, decisão do dono: visualização, GDD 8.9): a carta estreita até sumir, troca de lado
-- (frente ↔ verso) e volta a abrir. Sem sorteio e sem custo.
local flipping: { [Frame]: boolean } = {}
local function flipTile(tile: Frame)
	if flipping[tile] then
		return
	end
	local face = tile:FindFirstChild("Face") :: Frame?
	local back = tile:FindFirstChild("Back") :: Frame?
	if face == nil or back == nil then
		return
	end
	flipping[tile] = true
	local showing = if back.Visible then back else face
	local hidden = if back.Visible then face else back
	local half = TweenInfo.new(Theme.Animation.CardFlipTime / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local close = TweenService:Create(showing, half, { Size = UDim2.fromScale(0, 1) })
	close.Completed:Once(function()
		showing.Visible = false
		hidden.Size = UDim2.fromScale(0, 1)
		hidden.Visible = true
		local open = TweenService:Create(
			hidden,
			TweenInfo.new(Theme.Animation.CardFlipTime / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(1, 1) }
		)
		open.Completed:Once(function()
			flipping[tile] = nil
		end)
		open:Play()
	end)
	close:Play()
end

local function flipCurrent()
	local tile = tiles[index]
	if tile then
		flipTile(tile)
	end
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
			Position = UDim2.fromScale(0.5 + offset * SIDE_STEP, 0.47),
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
	-- Luz do palco na cor da carta escolhida e o brilho que atravessa a carta
	local def = list[index]
	if def then
		for _, glow in stageGlows do
			TweenService:Create(glow, TweenInfo.new(0.3), { BackgroundColor3 = cardColor(def) }):Play()
		end
		local shine = shines[tiles[index]]
		if shine then
			shine()
		end
	end
end

-- Ficha da carta escolhida ----------------------------------------------------------------------------

local function makeStat(parent: Instance, tileInfo: StatTile, order: number)
	local tile = Ui.raised("Stat", parent)
	tile.LayoutOrder = order
	local value = Ui.label("Value", Theme.Font.Number, Theme.TextSize.PrimaryButton + 2, Theme.Color.TextPrimary, tile)
	value.Position = UDim2.fromOffset(10, 6)
	value.Size = UDim2.new(1, -16, 0, 24)
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Text = tileInfo.icon .. " " .. tileInfo.value
	local label = Ui.label("Label", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, tile)
	label.Position = UDim2.fromOffset(10, 30)
	label.Size = UDim2.new(1, -16, 0, 16)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = TextUtil.upper(tileInfo.label)
end

local function refreshInfo()
	local def = list[index]
	emptyLabel.Visible = def == nil
	info.Visible = def ~= nil
	if def == nil then
		return
	end
	local color = cardColor(def)
	keyTag.Text = string.format(C.KeyTag, def.key)
	nameLabel.Text = TextUtil.upper(cardName(def.id))
	nameBar.BackgroundColor3 = color
	watermark.Text = def.key
	watermark.TextColor3 = color
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
	for _, child in statsGrid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, tileInfo in statsOf(def) do
		makeStat(statsGrid, tileInfo, i)
	end
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
	table.clear(shines)
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

-- Palco: luz em 3 círculos na cor da carta escolhida, pedestal embaixo, carrossel e setas.
local function buildStage(body: Frame, top: number)
	local stage = Ui.frame("Stage", body)
	stage.Position = UDim2.fromOffset(0, top)
	stage.Size = UDim2.new(STAGE_WIDTH, -6, 1, -top)
	stage.ClipsDescendants = true

	for i, size in { 1.2, 0.95, 0.7 } do
		local glow = Ui.frame("Light", stage)
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.47)
		glow.Size = UDim2.fromScale(size, size)
		glow.BackgroundTransparency = Theme.CardBackdrop.StageGlowTransparency[i]
		glow.BackgroundColor3 = Theme.Color.Accent
		glow.ZIndex = 0
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.AspectRatio = 1
		ratio.DominantAxis = Enum.DominantAxis.Height
		ratio.Parent = glow
		Ui.corner(glow, 9999)
		table.insert(stageGlows, glow)
	end
	local pedestal = Ui.frame("Pedestal", stage)
	pedestal.AnchorPoint = Vector2.new(0.5, 0.5)
	pedestal.Position = UDim2.fromScale(0.5, 0.93)
	pedestal.Size = UDim2.fromScale(0.42, 0.045)
	pedestal.BackgroundTransparency = 0
	pedestal.BackgroundColor3 = Theme.Color.Accent
	pedestal.ZIndex = 0
	Ui.corner(pedestal, 9999)
	-- Mancha de luz no chão: some para as pontas
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = pedestal
	table.insert(stageGlows, pedestal)

	carousel = Ui.frame("Carousel", stage)
	carousel.Size = UDim2.fromScale(1, 1)
	local cardFit = Instance.new("UIScale")
	cardFit.Parent = carousel
	local function fitCards()
		-- A carta encolhe em tela baixa (celular) para caber inteira
		cardFit.Scale = math.clamp((stage.AbsoluteSize.Y - 24) / CARD_SIZE.Y, 0.5, 1.15)
	end
	stage:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCards)
	emptyLabel = Ui.label("Empty", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextSecondary, stage)
	emptyLabel.Size = UDim2.fromScale(1, 1)
	emptyLabel.Text = C.Empty
	local left = Widgets.iconButton(stage, U.Back, function()
		move(-1)
	end)
	left.AnchorPoint = Vector2.new(0, 0.5)
	left.Position = UDim2.fromScale(0, 0.47)
	left.ZIndex = 20
	local right = Widgets.iconButton(stage, U.Arrow, function()
		move(1)
	end)
	right.AnchorPoint = Vector2.new(1, 0.5)
	right.Position = UDim2.fromScale(1, 0.47)
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
end

-- Ficha: tecla e raridade, nome, frase, atributos, botões e skins (rola só em tela muito baixa).
local function buildInfo(body: Frame, top: number)
	local panel = Ui.raised("Info", body)
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, 0, 0, top)
	panel.Size = UDim2.new(1 - STAGE_WIDTH, -6, 1, -top)
	info = panel

	-- Marca d'água: a tecla gigante no canto da ficha, na cor da carta
	watermark = Ui.label("Watermark", Theme.Font.Title, 220, Theme.Color.Accent, panel)
	watermark.AnchorPoint = Vector2.new(1, 1)
	watermark.Position = UDim2.new(1, -12, 1, -14)
	watermark.Size = UDim2.fromOffset(200, 220)
	watermark.TextXAlignment = Enum.TextXAlignment.Right
	watermark.TextTransparency = 0.9

	local scroll = Ui.scroll("Scroll", Enum.ScrollingDirection.Y, panel)
	scroll.Position = UDim2.fromOffset(14, 12)
	scroll.Size = UDim2.new(1, -20, 1, -24)
	scroll.ScrollBarThickness = 3
	Ui.list(scroll, Enum.FillDirection.Vertical, 8)

	local tags = Ui.frame("Tags", scroll)
	tags.Size = UDim2.new(1, -8, 0, 24)
	tags.LayoutOrder = 1
	local tagLayout = Ui.list(tags, Enum.FillDirection.Horizontal, 8)
	tagLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local function pill(name: string, order: number): (TextLabel, UIStroke)
		local p = Ui.label(name, Theme.Font.Title, Theme.TextSize.Label, Theme.Color.TextSecondary, tags)
		p.AutomaticSize = Enum.AutomaticSize.X
		p.Size = UDim2.fromOffset(0, 24)
		p.LayoutOrder = order
		p.BackgroundTransparency = 0
		p.BackgroundColor3 = Theme.Color.PanelBase
		Ui.corner(p)
		local stroke = Ui.stroke(p, Theme.Color.PanelBorder, 1)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = p
		return p, stroke
	end
	keyTag = pill("KeyTag", 1)
	keyTag.TextColor3 = Theme.Color.TextPrimary
	rarityPill, rarityStroke = pill("Rarity", 2)

	nameLabel = Ui.label("CardName", Theme.Font.Title, Theme.TextSize.Title + 16, Theme.Color.TextPrimary, scroll)
	nameLabel.Size = UDim2.new(1, -8, 0, 42)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.LayoutOrder = 2
	nameBar = Ui.frame("NameBar", scroll)
	nameBar.Size = UDim2.fromOffset(56, 4)
	nameBar.BackgroundTransparency = 0
	nameBar.LayoutOrder = 3
	Ui.corner(nameBar, 2)

	descLabel = Ui.label("Desc", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextPrimary, scroll)
	descLabel.Size = UDim2.new(1, -8, 0, 0)
	descLabel.AutomaticSize = Enum.AutomaticSize.Y
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.LayoutOrder = 4

	statsGrid = Ui.frame("Stats", scroll)
	statsGrid.Size = UDim2.new(1, -8, 0, STAT_HEIGHT)
	statsGrid.LayoutOrder = 5
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.CellSize = UDim2.new(1 / 3, -4, 0, STAT_HEIGHT)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = statsGrid

	local buttons = Ui.frame("Buttons", scroll)
	buttons.Size = UDim2.new(1, -8, 0, Theme.Touch.MinTarget + 6)
	buttons.LayoutOrder = 6
	Ui.list(buttons, Enum.FillDirection.Horizontal, Theme.Space.Small)
	equipButton = Widgets.button(buttons, C.Equip, "primary", {
		size = UDim2.new(0.6, -Theme.Space.Small, 1, 0),
		textSize = Theme.TextSize.Body,
		order = 1,
	})
	-- GIRAR sempre visível embaixo da carta (ESTILO T1): vira a carta para ver o verso (GDD 8.9, F9)
	local spin = Widgets.button(buttons, C.Spin, "secondary", {
		size = UDim2.fromScale(0.4, 1),
		textSize = Theme.TextSize.Body,
		arrow = false,
		order = 2,
		pc = "R",
	})
	spin.onClick(flipCurrent)

	ownedLabel = Ui.label("Owned", Theme.Font.Title, Theme.TextSize.Label, Theme.Color.Success, scroll)
	ownedLabel.Size = UDim2.new(1, -8, 0, 16)
	ownedLabel.TextXAlignment = Enum.TextXAlignment.Left
	ownedLabel.LayoutOrder = 7

	-- Skins de cartas / versos (depois da F9: o catálogo inicial só tem skins de arma)
	local skins = Widgets.button(scroll, C.CardSkins .. " · " .. C.Soon, "secondary", {
		size = UDim2.new(1, -8, 0, Theme.Touch.MinTarget),
		textSize = Theme.TextSize.Label,
		arrow = false,
		order = 8,
	})
	skins.setEnabled(false)
end

local function build()
	modal = Widgets.modal("CardsScreen", 50, {
		title = C.Title,
		size = UDim2.fromScale(0.8, 0.86),
		touchSize = UDim2.fromScale(0.97, 0.95),
		maxSize = Vector2.new(1100, 700),
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
	buildStage(body, top)
	buildInfo(body, top)

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
		elseif input.KeyCode == Enum.KeyCode.R then
			flipCurrent()
		end
	end)
end

return CardsScreen
