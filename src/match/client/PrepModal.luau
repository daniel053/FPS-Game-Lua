--!strict
-- Modal de preparação (GDD 4.10 e ESTILO T2, visual final da F7).
--   * Modal sobre o jogo: o mapa continua visível atrás (bg.overlay), nunca fundo preto opaco.
--   * Cabeçalho "RODADA 3 · ARMAS MÉDIAS" e o tempo.
--   * Etapas como abas: CARTA (na 1ª preparação do jogador; travada depois, com a carta escolhida),
--     PRIMÁRIA (a partir da 3ª rodada) e SECUNDÁRIA.
--   * Etapa CARTA: as cartas básicas que o jogador tem, lado a lado, com a tecla e o que faz; a ult
--     ao lado com cadeado ("Libera na 4ª rodada"). Sem escolha = partida sem carta básica.
--     Raridade das cartas iniciais ainda [ABERTO] (GDD 8.9): borda na cor da carta, sem moldura.
--   * Armas da fase agrupadas por categoria, cada arma UMA vez só (cartão com a arma em 3D pequena e
--     o nome); a escolhida com borda do acento e brilho discreto; barras de dano, cadência e alcance.
--   * Rodapé: carta escolhida, escolha do parceiro em tempo real, REPETIR ÚLTIMA e CONFIRMAR.
--   * Celular: ~92% × 86% da tela, uma aba por categoria (GDD 4.10), cartões de 64 px ou mais.
--   * PC: categorias lado a lado; atalhos 1 a 8 escolhem e Enter confirma (chips visíveis).
--   * Controle: o primeiro cartão já vem selecionado; X confirma.
-- Toda escolha vai para o servidor na hora (o parceiro vê); o servidor valida tudo.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local CardConfig = require(Shared.Config.CardConfig)
local MatchTypes = require(Shared.Match.MatchTypes)
local Strings = require(Shared.Config.Strings)
local TextUtil = require(Shared.TextUtil)
local Theme = require(Shared.Config.Theme)
local CardArt = require(Shared.Ui.CardArt)
local Ui = require(Shared.Ui.Ui)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponStats = require(Shared.Combat.WeaponStats)

local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local WeaponPreview = require(script.Parent.Parent.Common.Ui.WeaponPreview)
local Widgets = require(script.Parent.Parent.Common.Ui.Widgets)
local MatchClient = require(script.Parent.MatchClient)

local S = Strings.Match
local CARD_WIDTH = 116
local CARD_HEIGHT = 84
local ABILITY_WIDTH = 170
local ABILITY_HEIGHT = 116
local SEGMENTS = 5
local STATS_HEIGHT = 30
local FOOTER_HEIGHT = 52
local CATEGORY_ORDER = { "Pistol", "SMG", "Shotgun", "LightRifle", "Rifle", "Sniper", "MachineGun" }
local NUMBER_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
}

type Step = "card" | "primary" | "secondary"

local PrepModal = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local overlay: Frame
local panel: Frame
local headerText: TextLabel
local timerText: TextLabel
local steps: Widgets.Tabs
local categoryTabs: Widgets.Tabs? = nil
local categoryHolder: Frame
local grid: ScrollingFrame
local statsHolder: Frame
local placeGrid: () -> ()
local stats: Widgets.StatBars
local partnerText: TextLabel
local cardText: TextLabel
local repeatButton: Widgets.Button
local confirmButton: Widgets.Button
local waitingText: TextLabel

local data: MatchTypes.PrepData? = nil
local step: Step = "secondary"
local chosen: { primary: string?, secondary: string? } = {}
local chosenCard: string? = nil
local confirmed = false
local visibleIds: { string } = {}
local cards: { [string]: Widgets.ItemCard } = {}
local touchCategory: string? = nil
local tabsKey = ""
local syncingTabs = false

local function selectedId(): string?
	if step == "primary" then
		return chosen.primary
	elseif step == "secondary" then
		return chosen.secondary
	end
	return chosenCard
end

local function refreshStats()
	local id = if step ~= "card" then selectedId() else nil
	local values = if id then WeaponStats.get(id) else nil
	stats.set(if values then { values.damage, values.fireRate, values.range } else nil)
end

local function refreshSelection()
	local id = selectedId()
	for cardId, card in cards do
		card.setSelected(cardId == id)
	end
	refreshStats()
end

local function stepLabel(name: Step): string
	local current = data
	local base = if name == "card" then S.StepCard elseif name == "primary" then S.StepPrimary else S.StepSecondary
	if name == "card" and current and not current.cardStep then
		return Strings.CardHud.Locked .. base -- travada: a carta vale a partida inteira
	end
	local done = (name == "primary" and chosen.primary ~= nil)
		or (name == "secondary" and chosen.secondary ~= nil)
		or (name == "card" and chosenCard ~= nil)
	return if done then base .. " " .. Strings.Ui.Check else base
end

local function refreshSteps()
	local current = data
	if current == nil then
		return
	end
	steps.setVisible("primary", #current.primaries > 0)
	for _, name in { "card", "primary", "secondary" } do
		steps.setLabel(name, stepLabel(name :: Step))
	end
	syncingTabs = true
	steps.select(step)
	syncingTabs = false
end

local function sendChoice()
	MatchClient.request("PrepChoose", { primary = chosen.primary, secondary = chosen.secondary })
end

local function cardLabel(id: string?): string
	local def = if id then CardConfig.get(id) else nil
	if id == nil or def == nil then
		return "—"
	end
	return string.format(S.CardWithKey, (Strings.Cards[id] or { name = id }).name, def.key)
end

local function refreshCardText()
	cardText.Text = if chosenCard then string.format(S.YourCard, cardLabel(chosenCard)) else S.YourCardNone
end

local function nextWeaponStep(): Step
	local current = data
	return if current and #current.primaries > 0 then "primary" else "secondary"
end

local function chooseCard(id: string)
	local current = data
	if current == nil or not current.cardStep or not table.find(current.cardOptions, id) then
		return
	end
	chosenCard = id
	MatchClient.request("PrepCard", id)
	refreshCardText()
end

local function choose(id: string)
	if confirmed then
		return
	end
	if step == "card" then
		chooseCard(id)
		refreshSelection()
		step = nextWeaponStep() -- escolheu a carta: passa para as armas
		PrepModal.rebuildGrid()
		return
	end
	if step == "primary" then
		chosen.primary = id
		sendChoice()
		-- Escolheu a primária: passa para a pistola
		step = "secondary"
		PrepModal.rebuildGrid()
		return
	end
	chosen.secondary = id
	sendChoice()
	refreshSelection()
	refreshSteps()
end

-- Cartão de arma: a arma em 3D pequena e o nome (ESTILO T2: cada arma uma vez só).
local function weaponCard(id: string, order: number, index: number, parent: Instance): Widgets.ItemCard
	local card = Widgets.itemCard(parent, Strings.Weapons[id] or id, UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT), order)
	card.root.Name = id
	local look = Theme.WeaponLook[id]
	card.setMarker(if look then look.accent else nil)
	WeaponPreview.new(card.content, false).set(id)
	if index <= #NUMBER_KEYS then
		local chip = Widgets.keyChip(card.root, tostring(index), nil)
		chip.Position = UDim2.fromOffset(4, 4)
		chip.ZIndex = 4
	end
	card.root.Activated:Connect(function()
		choose(id)
	end)
	cards[id] = card
	return card
end

local function categoryOf(id: string): string
	local def = WeaponConfig.get(id)
	return if def then def.category else "Pistol"
end

local function clearGrid()
	Ui.clear(grid)
	table.clear(visibleIds)
	table.clear(cards)
end

-- Abas de categoria (só no celular): uma por categoria presente na etapa.
local function rebuildCategoryTabs(categories: { string })
	local touch = InputDevice.get() == "Touch"
	local key = (if touch then "T:" else "") .. table.concat(categories, ",")
	if key == tabsKey and categoryTabs then
		return
	end
	tabsKey = key
	if categoryTabs then
		categoryTabs.root:Destroy()
		categoryTabs = nil
	end
	categoryHolder.Visible = touch and #categories > 1
	if not categoryHolder.Visible then
		return
	end
	local items = {}
	for _, category in categories do
		table.insert(items, { id = category, label = Strings.WeaponCategories[category] or category })
	end
	local tabs = Widgets.tabs(categoryHolder, items, function(id: string)
		if touchCategory ~= id then
			touchCategory = id
			PrepModal.rebuildGrid()
		end
	end, Theme.Touch.MinTarget - 6)
	categoryTabs = tabs
	tabs.select(touchCategory or categories[1])
end

function PrepModal.rebuildGrid()
	clearGrid()
	refreshSteps()
	local current = data
	if current == nil then
		return
	end
	statsHolder.Visible = step ~= "card" -- barras só fazem sentido para armas
	placeGrid()
	if step == "card" then
		categoryHolder.Visible = false
		tabsKey = ""
		PrepModal.buildCardStep(current)
		refreshSelection()
		return
	end

	local ids: { string } = if step == "primary" then current.primaries else current.secondaries
	local byCategory: { [string]: { string } } = {}
	local present: { string } = {}
	for _, id in ids do
		local category = categoryOf(id)
		local list = byCategory[category]
		if list == nil then
			list = {}
			byCategory[category] = list
		end
		table.insert(list, id)
	end
	for _, category in CATEGORY_ORDER do
		if byCategory[category] then
			table.insert(present, category)
		end
	end

	local touch = InputDevice.get() == "Touch"
	if touch then
		-- A aba começa na categoria da arma escolhida
		local selected = selectedId()
		if touchCategory == nil or byCategory[touchCategory] == nil then
			touchCategory = if selected then categoryOf(selected) else present[1]
		end
	end
	rebuildCategoryTabs(present)

	local order = 0
	local firstButton: TextButton? = nil
	for categoryIndex, category in present do
		if touch and #present > 1 and category ~= touchCategory then
			continue
		end
		local column = Ui.frame(category, grid)
		column.LayoutOrder = categoryIndex
		column.Size = UDim2.fromOffset(CARD_WIDTH, 0)
		column.AutomaticSize = Enum.AutomaticSize.XY
		Ui.list(column, Enum.FillDirection.Vertical, Theme.Space.Small)
		local title = Widgets.sectionTitle(column, Strings.WeaponCategories[category] or category)
		title.TextSize = Theme.TextSize.Label
		local holder = Ui.frame("Cards", column)
		holder.LayoutOrder = 1
		holder.Size = UDim2.fromOffset(0, 0)
		holder.AutomaticSize = Enum.AutomaticSize.XY
		-- Celular (uma categoria por aba) ou uma categoria só: cartões em linha; PC: uma coluna por categoria
		local inRow = touch or #present == 1
		Ui.list(holder, if inRow then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical, Theme.Space.Small)
		for _, id in byCategory[category] do
			order += 1
			table.insert(visibleIds, id)
			local card = weaponCard(id, order, #visibleIds, holder)
			firstButton = firstButton or card.root
		end
	end
	refreshSelection()
	if InputDevice.get() == "Gamepad" and firstButton and gui.Enabled then
		GuiService.SelectedObject = firstButton
	end
end

-- Cartão de uma carta (escolha, travada ou a ult com cadeado).
local function abilityCard(id: string, order: number, index: number?, note: string?, parent: Instance)
	local def = CardConfig.get(id)
	local locked = index == nil
	local color = if locked
			and chosenCard ~= id
			and note == nil
		then Theme.Cards.Locked
		else (Theme.Cards[id] or Theme.Color.Accent)
	local card = Widgets.itemCard(parent, "", UDim2.fromOffset(ABILITY_WIDTH, ABILITY_HEIGHT), order)
	card.root.Name = id
	card.root.Selectable = not locked
	card.setBorder(color, 2)
	card.title.Visible = false
	local content = card.content
	content.Size = UDim2.new(1, -12, 1, -12)

	-- Arte da carta (F10), pequena, antes do nome
	local art = Ui.frame("Art", content)
	art.Size = UDim2.fromOffset(24, 24)
	art.Position = UDim2.fromOffset(-2, -2)
	CardArt.draw(art, id, color)
	local title = Ui.label("Name", Theme.Font.Title, Theme.TextSize.PrimaryButton, color, content)
	title.Position = UDim2.fromOffset(26, 0)
	title.Size = UDim2.new(1, -28 - 26, 0, 22)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = TextUtil.upper((Strings.Cards[id] or { name = id }).name)
	-- A tecla é parte da carta (fixa, GDD 8.3): sempre aparece
	local key = Ui.keyChip(if def then def.key else "?", content)
	key.AnchorPoint = Vector2.new(1, 0)
	key.Position = UDim2.fromScale(1, 0)
	local body = Ui.label("Body", Theme.Font.Body, Theme.TextSize.Label, Theme.Color.TextSecondary, content)
	body.Position = UDim2.fromOffset(0, 26)
	body.Size = UDim2.new(1, 0, 1, -26 - 18)
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Text = (Strings.Cards[id] or { description = "" }).description
	if note then
		local noteText = Ui.label("Note", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextPrimary, content)
		noteText.AnchorPoint = Vector2.new(0, 1)
		noteText.Position = UDim2.fromScale(0, 1)
		noteText.Size = UDim2.new(1, 0, 0, 16)
		noteText.TextXAlignment = Enum.TextXAlignment.Left
		noteText.Text = note
	end
	if index and index <= #NUMBER_KEYS then
		local chip = Widgets.keyChip(content, tostring(index), nil)
		chip.AnchorPoint = Vector2.new(1, 1)
		chip.Position = UDim2.fromScale(1, 1)
	end
	if not locked then
		card.root.Activated:Connect(function()
			choose(id)
		end)
		cards[id] = card
	elseif chosenCard == id then
		card.setSelected(true)
	end
	return card
end

-- Etapa CARTA: escolher (1ª preparação) ou ver a carta travada; a ult ao lado.
function PrepModal.buildCardStep(current: MatchTypes.PrepData)
	local column = Ui.frame("CardStep", grid)
	column.Size = UDim2.fromOffset(4 * (ABILITY_WIDTH + 12), ABILITY_HEIGHT + 34)
	local hint = Ui.label("Hint", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, column)
	hint.Size = UDim2.fromOffset(3 * (ABILITY_WIDTH + 12), 30)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextYAlignment = Enum.TextYAlignment.Top
	hint.TextWrapped = true
	local row = Ui.frame("Cards", column)
	row.Position = UDim2.fromOffset(4, 34)
	row.Size = UDim2.new(1, 0, 0, ABILITY_HEIGHT)
	Ui.list(row, Enum.FillDirection.Horizontal, 12)

	local firstButton: TextButton? = nil
	if current.cardStep then
		if #current.cardOptions == 0 then
			hint.Text = S.CardNone
		else
			hint.Text = S.CardChooseHint
			for i, id in current.cardOptions do
				table.insert(visibleIds, id)
				local card = abilityCard(id, i, #visibleIds, nil, row)
				firstButton = firstButton or card.root
			end
		end
	else
		hint.Text = if chosenCard then S.CardLockedHint else S.CardNotChosen
		if chosenCard then
			abilityCard(chosenCard, 1, nil, nil, row)
		end
	end
	if current.ult then
		local note = if current.ultUnlocked
			then S.UltReady
			else Strings.CardHud.Locked .. string.format(S.UltLocked, CardConfig.UltUnlockRound)
		local ult = abilityCard(current.ult, 10, nil, note, row)
		if not current.ultUnlocked then
			ult.setBorder(Theme.Cards.Locked, 2)
		end
	end
	if InputDevice.get() == "Gamepad" and firstButton and gui.Enabled then
		GuiService.SelectedObject = firstButton
	end
end

local function refreshPartner(partner: MatchTypes.PartnerChoiceData?)
	if partner == nil then
		partnerText.Text = S.NoPartner
		return
	end
	local parts = {}
	for _, id in { partner.primary, partner.secondary } do
		if id then
			table.insert(parts, Strings.Weapons[id] or id)
		end
	end
	local card = partner.card
	if card then
		table.insert(parts, (Strings.Cards[card] or { name = card }).name)
	end
	if #parts == 0 then
		partnerText.Text = string.format(S.PartnerChoosing, partner.name)
		return
	end
	local text = table.concat(parts, " + ")
	if card then
		-- "Vespa + Bolinha · Impulso" (ESTILO T2)
		local weapons = table.concat(parts, " + ", 1, #parts - 1)
		local cardName = parts[#parts]
		text = if weapons ~= "" then `{weapons} · {cardName}` else cardName
	end
	if partner.confirmed then
		text = string.format(S.PartnerConfirmed, text)
	end
	partnerText.Text = string.format(S.PartnerChoice, partner.name, text)
end

local function close()
	data = nil
	gui.Enabled = false
	waitingText.Visible = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
end

local function confirm()
	if data == nil or confirmed then
		return
	end
	confirmed = true
	MatchClient.request("PrepConfirm")
	overlay.Visible = false
	panel.Visible = false
	waitingText.Visible = true
end

local function repeatLast()
	local current = data
	local profile = PlayerDataClient.get()
	if current == nil or profile == nil then
		confirm()
		return
	end
	local memory = profile.loadout
	-- Etapa da carta aberta: repete também a carta da última partida, se ainda tiver
	local lastCard = memory.lastCard
	if current.cardStep and lastCard and table.find(current.cardOptions, lastCard) then
		chooseCard(lastCard)
	end
	local primary = memory.lastPrimaryByPhase[current.phaseId]
	if primary and table.find(current.primaries, primary) then
		chosen.primary = primary
	end
	local secondary = memory.lastSecondary
	if secondary and table.find(current.secondaries, secondary) then
		chosen.secondary = secondary
	end
	sendChoice()
	confirm()
end

local function open(prep: MatchTypes.PrepData)
	data = prep
	confirmed = false
	chosen = { primary = prep.primary, secondary = prep.secondary }
	chosenCard = prep.card
	touchCategory = nil
	-- 1ª preparação com cartas: começa pela carta (ESTILO T2: Carta → Primária → Secundária)
	if prep.cardStep and #prep.cardOptions > 0 then
		step = "card"
	else
		step = if #prep.primaries > 0 then "primary" else "secondary"
	end
	local phaseName = TextUtil.upper(Strings.WeaponPhases[prep.phaseId] or "")
	headerText.Text = string.format(S.RoundPhase, prep.round, phaseName)
	refreshCardText()
	refreshPartner(nil)
	gui.Enabled = true
	overlay.Visible = true
	panel.Visible = true
	waitingText.Visible = false

	-- Celular: ocupa quase a tela; PC: tamanho confortável
	local touch = InputDevice.get() == "Touch"
	panel.Size = if touch then UDim2.fromScale(0.92, 0.86) else UDim2.fromScale(0.72, 0.74)
	Widgets.popIn(panel)
	PrepModal.rebuildGrid()
end

local function build()
	gui = Ui.screen("PrepModal", 20, Enum.ScreenInsets.CoreUISafeInsets)
	gui.Enabled = false

	overlay = Ui.frame("Overlay", gui)
	overlay.Size = UDim2.new(1, 0, 1, 200)
	overlay.Position = UDim2.fromOffset(0, -100)
	overlay.BackgroundColor3 = Theme.Color.Overlay
	overlay.BackgroundTransparency = Theme.Transparency.Overlay

	local content: Frame
	panel, content = Ui.panel("Panel", gui, Theme.Space.PanelPadding)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.72, 0.74)
	Ui.sizeLimit(panel, Vector2.new(340, 300), Vector2.new(1040, 600))

	-- Cabeçalho
	headerText = Ui.label("Header", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, content)
	headerText.Size = UDim2.new(1, -90, 0, 28)
	headerText.TextXAlignment = Enum.TextXAlignment.Left
	headerText.TextTruncate = Enum.TextTruncate.AtEnd
	timerText = Ui.label("Timer", Theme.Font.Number, Theme.TextSize.Title, Theme.Color.TextPrimary, content)
	timerText.AnchorPoint = Vector2.new(1, 0)
	timerText.Position = UDim2.fromScale(1, 0)
	timerText.Size = UDim2.fromOffset(80, 28)
	timerText.TextXAlignment = Enum.TextXAlignment.Right

	-- Etapas (abas)
	local stepHolder = Ui.frame("Steps", content)
	stepHolder.Position = UDim2.fromOffset(0, 34)
	stepHolder.Size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget + 6)
	steps = Widgets.tabs(stepHolder, {
		{ id = "card", label = S.StepCard },
		{ id = "primary", label = S.StepPrimary },
		{ id = "secondary", label = S.StepSecondary },
	}, function(id: string)
		if syncingTabs or confirmed or data == nil then
			return
		end
		step = id :: Step
		touchCategory = nil
		PrepModal.rebuildGrid()
	end)

	-- Abas de categoria (celular)
	local gridTop = 34 + Theme.Touch.MinTarget + 12
	categoryHolder = Ui.frame("Categories", content)
	categoryHolder.Position = UDim2.fromOffset(0, gridTop)
	categoryHolder.Size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget)
	categoryHolder.Visible = false

	-- Grade (rolagem quando não cabe)
	grid = Ui.scroll("Grid", Enum.ScrollingDirection.XY, content)
	grid.Size = UDim2.new(1, 0, 1, -gridTop - FOOTER_HEIGHT - STATS_HEIGHT - 10)
	grid.Position = UDim2.fromOffset(0, gridTop)
	local layout = Ui.list(grid, Enum.FillDirection.Horizontal, 14)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	local gridPad = Instance.new("UIPadding")
	gridPad.PaddingTop = UDim.new(0, 6)
	gridPad.PaddingLeft = UDim.new(0, 6)
	gridPad.Parent = grid
	placeGrid = function()
		local offset = if categoryHolder.Visible then Theme.Touch.MinTarget + 6 else 0
		local bottom = FOOTER_HEIGHT + 10 + (if statsHolder and statsHolder.Visible then STATS_HEIGHT else 0)
		grid.Position = UDim2.fromOffset(0, gridTop + offset)
		grid.Size = UDim2.new(1, 0, 1, -(gridTop + offset) - bottom)
	end
	categoryHolder:GetPropertyChangedSignal("Visible"):Connect(placeGrid)

	-- Barras de atributos da escolhida (sem segunda imagem da arma), logo acima do rodapé
	statsHolder = Ui.frame("StatsHolder", content)
	statsHolder.AnchorPoint = Vector2.new(0, 1)
	statsHolder.Position = UDim2.new(0, 0, 1, -FOOTER_HEIGHT - 6)
	statsHolder.Size = UDim2.new(1, 0, 0, STATS_HEIGHT)
	stats = Widgets.statBars(statsHolder, { S.StatDamage, S.StatFireRate, S.StatRange }, SEGMENTS)
	stats.root.Position = UDim2.fromOffset(0, 2)
	local divider = Ui.frame("Divider", statsHolder)
	divider.AnchorPoint = Vector2.new(0, 1)
	divider.Position = UDim2.fromScale(0, 1)
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.BackgroundTransparency = 0
	divider.BackgroundColor3 = Theme.Color.PanelBorder

	-- Rodapé: carta e parceiro à esquerda, REPETIR ÚLTIMA e CONFIRMAR à direita
	local footer = Ui.frame("Footer", content)
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT)

	cardText = Ui.label("Card", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, footer)
	cardText.Position = UDim2.fromOffset(0, 4)
	cardText.Size = UDim2.new(0.42, 0, 0, 20)
	cardText.TextXAlignment = Enum.TextXAlignment.Left
	cardText.TextTruncate = Enum.TextTruncate.AtEnd
	partnerText = Ui.label("Partner", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, footer)
	partnerText.Position = UDim2.fromOffset(0, 26)
	partnerText.Size = UDim2.new(0.42, 0, 0, 24)
	partnerText.TextXAlignment = Enum.TextXAlignment.Left
	partnerText.TextYAlignment = Enum.TextYAlignment.Top
	partnerText.TextWrapped = true

	local buttons = Ui.frame("Buttons", footer)
	buttons.AnchorPoint = Vector2.new(1, 1)
	buttons.Position = UDim2.fromScale(1, 1)
	buttons.Size = UDim2.new(0.58, 0, 0, FOOTER_HEIGHT - 4)
	local buttonList = Ui.list(buttons, Enum.FillDirection.Horizontal, Theme.Space.Medium)
	buttonList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	repeatButton = Widgets.button(buttons, S.RepeatLast, "secondary", {
		size = UDim2.new(0.42, -6, 1, 0),
		textSize = Theme.TextSize.Body,
		order = 1,
		modal = true, -- libera o mouse da primeira pessoa enquanto o modal está aberto (PC)
	})
	repeatButton.onClick(repeatLast)
	confirmButton = Widgets.button(buttons, S.Confirm, "primary", {
		size = UDim2.new(0.58, -6, 1, 0),
		order = 2,
		pc = Strings.Tutorial.ContinueKey,
		pad = "X",
	})
	confirmButton.onClick(confirm)

	-- Depois de confirmar: "Aguardando início · N s" no centro
	waitingText = Ui.label("Waiting", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, gui)
	waitingText.AnchorPoint = Vector2.new(0.5, 0.5)
	waitingText.Position = UDim2.fromScale(0.5, 0.42)
	waitingText.Size = UDim2.new(0.9, 0, 0, 32)
	waitingText.Visible = false
	Ui.outlineText(waitingText)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function PrepModal.Start()
	if not MatchClient.isEnabled() then
		return
	end
	build()
	MatchClient.onEvent("PrepOpen", open)
	MatchClient.onEvent("PrepPartner", refreshPartner)
	MatchClient.onEvent("PrepClose", close)
	MatchClient.onChanged(function(snapshot: MatchTypes.Snapshot)
		-- As mensagens de estado e de evento podem chegar fora de ordem: só fecha quando a rodada
		-- do modal já passou da preparação (o servidor também manda PrepClose).
		local current = data
		if current == nil then
			return
		end
		local stale = snapshot.round > current.round
			or (snapshot.round == current.round and snapshot.phase ~= "Prep" and snapshot.phase ~= "Draw")
		if stale then
			close()
		end
	end)
	InputDevice.onChanged(function()
		if data and not confirmed then
			tabsKey = ""
			PrepModal.rebuildGrid()
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if data == nil or confirmed then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonX then
			confirm()
			return
		end
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
			confirm()
			return
		end
		local index = table.find(NUMBER_KEYS, input.KeyCode)
		if index and visibleIds[index] then
			choose(visibleIds[index])
		end
	end)

	RunService.RenderStepped:Connect(function()
		local current = data
		if current == nil then
			return
		end
		local left = math.max(0, math.ceil(current.endsAt - workspace:GetServerTimeNow()))
		timerText.Text = `⏱ {left}`
		waitingText.Text = string.format(S.WaitingStart, left)
	end)
end

return PrepModal
