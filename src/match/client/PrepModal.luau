--!strict
-- Modal de preparação, versão SIMPLES (GDD 4.10 e ESTILO T2; visual final na F7).
--   * Modal sobre o jogo: o mapa continua visível atrás (fundo escurecido, nunca preto opaco).
--   * Etapas no topo: CARTA (na 1ª preparação do jogador; travada depois, com a carta escolhida),
--     PRIMÁRIA (a partir da 3ª rodada) e SECUNDÁRIA.
--   * Etapa CARTA (F4): as cartas básicas que o jogador tem, lado a lado, com a tecla e o que faz;
--     a ult ao lado com cadeado ("Libera na 4ª rodada"). Sem escolha = partida sem carta básica.
--     Raridade das cartas iniciais ainda [ABERTO] (GDD 8.9): borda na cor da carta, sem moldura.
--   * Armas da fase agrupadas por categoria, cada arma uma vez só; a escolhida com borda do acento;
--     barras de dano, cadência e alcance da escolhida.
--   * Rodapé: carta, escolha do parceiro em tempo real, REPETIR ÚLTIMA e CONFIRMAR.
--   * Celular: ~90% × 80% da tela, categorias com rolagem horizontal, cartões de 64 px ou mais.
--   * PC: categorias lado a lado, atalhos 1 a 8 escolhem a arma e Enter confirma.
--   * Controle: o primeiro cartão já vem selecionado.
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
local WeaponConfig = require(Shared.Config.WeaponConfig)

local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local MatchClient = require(script.Parent.MatchClient)
local MatchUi = require(Shared.Ui.ProvisionalUi)

local S = Strings.Match
local CARD_WIDTH = 116
local CARD_HEIGHT = 64
local ABILITY_WIDTH = 170
local ABILITY_HEIGHT = 128
local SEGMENTS = 5
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
local stepBar: Frame
local stepButtons: { [string]: TextButton } = {}
local grid: ScrollingFrame
local statsText: { TextLabel } = {}
local statBars: { { Frame } } = {}
local partnerText: TextLabel
local cardText: TextLabel
local repeatButton: TextButton
local confirmButton: TextButton
local waitingText: TextLabel

local data: MatchTypes.PrepData? = nil
local step: Step = "secondary"
local chosen: { primary: string?, secondary: string? } = {}
local chosenCard: string? = nil
local confirmed = false
local visibleIds: { string } = {}

-- Atributos (0 a 1) para as barras da arma escolhida.
local function stats(def: WeaponConfig.WeaponDef): { number }
	local damage = math.clamp(def.damage * def.pellets / WeaponConfig.MaxSingleShotDamage, 0.05, 1)
	local rate = math.clamp(def.fireRate / 13, 0.05, 1)
	local reach = if def.falloff then def.falloff.finish else def.range
	if def.effectiveRange then
		reach = def.effectiveRange
	end
	return { damage, rate, math.clamp(reach / 120, 0.05, 1) }
end

local function selectedId(): string?
	if step == "primary" then
		return chosen.primary
	elseif step == "secondary" then
		return chosen.secondary
	end
	return nil
end

local function refreshStats()
	local id = selectedId()
	local def = if id then WeaponConfig.get(id) else nil
	for i, segments in statBars do
		local value = if def then stats(def)[i] else 0
		local filled = math.max(if def then 1 else 0, math.round(value * SEGMENTS))
		for s, segment in segments do
			segment.BackgroundColor3 = if s <= filled then Theme.Color.Accent else Theme.Color.PanelRaised
		end
		statsText[i].Visible = def ~= nil
	end
end

local function refreshSteps()
	local current = data
	if current == nil then
		return
	end
	local hasPrimary = #current.primaries > 0
	stepButtons.card.Visible = true
	stepButtons.primary.Visible = hasPrimary
	for name, button in stepButtons do
		local active = name == step
		button.BackgroundColor3 = if active then Theme.Color.Accent else Theme.Color.PanelRaised
		local done = (name == "primary" and chosen.primary ~= nil)
			or (name == "secondary" and chosen.secondary ~= nil)
			or (name == "card" and chosenCard ~= nil)
		local base = if name == "card" then S.StepCard elseif name == "primary" then S.StepPrimary else S.StepSecondary
		if name == "card" and not current.cardStep then
			base = Strings.CardHud.Locked .. base -- travada: a carta vale a partida inteira
		end
		button.Text = if done then base .. " ✓" else base
		button.TextColor3 = if name == "card" and not current.cardStep
			then Theme.Color.TextSecondary
			else Theme.Color.TextPrimary
	end
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
		step = nextWeaponStep() -- escolheu a carta: passa para as armas
		PrepModal.rebuildGrid()
		return
	end
	if step == "primary" then
		chosen.primary = id
		-- Escolheu a primária: passa para a pistola
		step = "secondary"
	elseif step == "secondary" then
		chosen.secondary = id
	end
	sendChoice()
	PrepModal.rebuildGrid()
end

local function makeCard(id: string, order: number, index: number, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Name = id
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	button.BackgroundColor3 = Theme.Color.PanelRaised
	button.AutoButtonColor = true
	button.FontFace = Theme.Font.Title
	button.TextSize = Theme.TextSize.Body
	button.TextColor3 = Theme.Color.TextPrimary
	button.Text = TextUtil.upper(Strings.Weapons[id] or id)
	button.TextWrapped = true
	MatchUi.corner(button)
	local selected = selectedId() == id
	MatchUi.stroke(button, if selected then Theme.Color.Accent else Theme.Color.PanelBorder, if selected then 3 else 1)
	if InputDevice.get() == "KeyboardMouse" and index <= #NUMBER_KEYS then
		local chip = MatchUi.keyChip(tostring(index), button)
		chip.Position = UDim2.fromOffset(4, 4)
	end
	button.Activated:Connect(function()
		choose(id)
	end)
	button.Parent = parent
	return button
end

function PrepModal.rebuildGrid()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(visibleIds)
	refreshSteps()
	refreshStats()
	local current = data
	if current == nil then
		return
	end

	if step == "card" then
		PrepModal.buildCardStep(current)
		return
	end

	local ids: { string } = if step == "primary" then current.primaries else current.secondaries
	local byCategory: { [string]: { string } } = {}
	for _, id in ids do
		local def = WeaponConfig.get(id)
		if def then
			local list = byCategory[def.category] or {}
			byCategory[def.category] = list
			table.insert(list, id)
		end
	end
	local order = 0
	local firstButton: TextButton? = nil
	for categoryIndex, category in CATEGORY_ORDER do
		local list = byCategory[category]
		if list == nil then
			continue
		end
		local column = MatchUi.frame(category, grid)
		column.LayoutOrder = categoryIndex
		column.Size = UDim2.fromOffset(CARD_WIDTH, 0)
		column.AutomaticSize = Enum.AutomaticSize.Y
		MatchUi.list(column, Enum.FillDirection.Vertical, 6)
		local title =
			MatchUi.label("Title", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, column)
		title.Size = UDim2.new(1, 0, 0, 16)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = TextUtil.upper(Strings.WeaponCategories[category] or category)
		for _, id in list do
			order += 1
			table.insert(visibleIds, id)
			local button = makeCard(id, order + 1, #visibleIds, column)
			firstButton = firstButton or button
		end
	end
	if InputDevice.get() == "Gamepad" and firstButton and gui.Enabled then
		GuiService.SelectedObject = firstButton
	end
end

-- Cartão de uma carta (escolha, travada ou a ult com cadeado).
local function makeAbilityCard(
	id: string,
	order: number,
	index: number?,
	selected: boolean,
	note: string?,
	parent: Instance
): TextButton
	local def = CardConfig.get(id)
	local locked = index == nil
	local color = if locked and not selected then Theme.Cards.Locked else (Theme.Cards[id] or Theme.Color.Accent)
	local button = Instance.new("TextButton")
	button.Name = id
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(ABILITY_WIDTH, ABILITY_HEIGHT)
	button.BackgroundColor3 = Theme.Color.PanelRaised
	button.AutoButtonColor = not locked
	button.Text = ""
	button.Selectable = not locked
	MatchUi.corner(button)
	MatchUi.stroke(button, if selected then Theme.Color.Accent else color, if selected then 3 else 2)
	MatchUi.padding(button, 8)

	local title = MatchUi.label("Name", Theme.Font.Title, Theme.TextSize.PrimaryButton, color, button)
	title.Size = UDim2.new(1, -28, 0, 22)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = TextUtil.upper((Strings.Cards[id] or { name = id }).name)
	-- A tecla é parte da carta (fixa, GDD 8.3): sempre aparece
	local keyChip = MatchUi.keyChip(if def then def.key else "?", button)
	keyChip.AnchorPoint = Vector2.new(1, 0)
	keyChip.Position = UDim2.fromScale(1, 0)
	local body = MatchUi.label("Body", Theme.Font.Body, Theme.TextSize.Label, Theme.Color.TextSecondary, button)
	body.Position = UDim2.fromOffset(0, 26)
	body.Size = UDim2.new(1, 0, 1, -26 - 18)
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Text = (Strings.Cards[id] or { description = "" }).description
	if note then
		local noteText =
			MatchUi.label("Note", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextPrimary, button)
		noteText.AnchorPoint = Vector2.new(0, 1)
		noteText.Position = UDim2.fromScale(0, 1)
		noteText.Size = UDim2.new(1, 0, 0, 16)
		noteText.TextXAlignment = Enum.TextXAlignment.Left
		noteText.Text = note
	end
	if index and InputDevice.get() == "KeyboardMouse" and index <= #NUMBER_KEYS then
		local chip = MatchUi.keyChip(tostring(index), button)
		chip.AnchorPoint = Vector2.new(1, 1)
		chip.Position = UDim2.fromScale(1, 1)
	end
	if not locked then
		button.Activated:Connect(function()
			choose(id)
		end)
	end
	button.Parent = parent
	return button
end

-- Etapa CARTA: escolher (1ª preparação) ou ver a carta travada; a ult ao lado.
function PrepModal.buildCardStep(current: MatchTypes.PrepData)
	local column = MatchUi.frame("CardStep", grid)
	column.Size = UDim2.fromOffset(4 * (ABILITY_WIDTH + 12), ABILITY_HEIGHT + 30)
	local hint = MatchUi.label("Hint", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextSecondary, column)
	hint.Size = UDim2.new(1, 0, 0, 20)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	local cards = MatchUi.frame("Cards", column)
	cards.Position = UDim2.fromOffset(0, 28)
	cards.Size = UDim2.new(1, 0, 0, ABILITY_HEIGHT)
	MatchUi.list(cards, Enum.FillDirection.Horizontal, 12)

	local firstButton: TextButton? = nil
	if current.cardStep then
		if #current.cardOptions == 0 then
			hint.Text = S.CardNone
		else
			hint.Text = S.CardChooseHint
			for i, id in current.cardOptions do
				table.insert(visibleIds, id)
				local button = makeAbilityCard(id, i, #visibleIds, chosenCard == id, nil, cards)
				firstButton = firstButton or button
			end
		end
	else
		hint.Text = if chosenCard then S.CardLockedHint else S.CardNotChosen
		if chosenCard then
			makeAbilityCard(chosenCard, 1, nil, true, nil, cards)
		end
	end
	if current.ult then
		local note = if current.ultUnlocked
			then S.UltReady
			else Strings.CardHud.Locked .. string.format(S.UltLocked, CardConfig.UltUnlockRound)
		makeAbilityCard(current.ult, 10, nil, current.ultUnlocked, note, cards)
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

	-- Celular: ocupa quase a tela; PC: tamanho fixo confortável
	local touch = InputDevice.get() == "Touch"
	panel.Size = if touch then UDim2.fromScale(0.92, 0.82) else UDim2.fromScale(0.7, 0.7)
	PrepModal.rebuildGrid()
end

local function build()
	gui = MatchUi.screen("PrepModal", 20, Enum.ScreenInsets.DeviceSafeInsets)
	gui.Enabled = false

	overlay = MatchUi.frame("Overlay", gui)
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Color.Overlay
	overlay.BackgroundTransparency = Theme.Transparency.Overlay

	panel = MatchUi.panel("Panel", gui)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.7, 0.7)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(1000, 560)
	sizeLimit.MinSize = Vector2.new(320, 260)
	sizeLimit.Parent = panel
	MatchUi.padding(panel, 14)

	-- Cabeçalho
	headerText = MatchUi.label("Header", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, panel)
	headerText.Size = UDim2.new(1, -90, 0, 28)
	headerText.TextXAlignment = Enum.TextXAlignment.Left
	timerText = MatchUi.label("Timer", Theme.Font.Number, Theme.TextSize.Title, Theme.Color.TextPrimary, panel)
	timerText.AnchorPoint = Vector2.new(1, 0)
	timerText.Position = UDim2.fromScale(1, 0)
	timerText.Size = UDim2.fromOffset(80, 28)
	timerText.TextXAlignment = Enum.TextXAlignment.Right

	-- Etapas
	stepBar = MatchUi.frame("Steps", panel)
	stepBar.Position = UDim2.fromOffset(0, 34)
	stepBar.Size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget)
	MatchUi.list(stepBar, Enum.FillDirection.Horizontal, 8)
	for i, name: Step in { "card", "primary", "secondary" } :: { Step } do
		local button = MatchUi.button(name, "", false, stepBar)
		button.LayoutOrder = i
		button.Size = UDim2.fromOffset(140, Theme.Touch.MinTarget)
		button.TextSize = Theme.TextSize.Body
		button.Activated:Connect(function()
			if confirmed then
				return
			end
			step = name
			PrepModal.rebuildGrid()
		end)
		stepButtons[name] = button
	end

	-- Grade de armas (rolagem horizontal quando não cabe)
	grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(0, 34 + Theme.Touch.MinTarget + 10)
	grid.Size = UDim2.new(1, 0, 1, -(34 + Theme.Touch.MinTarget + 10) - 150)
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.XY
	grid.ScrollingDirection = Enum.ScrollingDirection.XY
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = Theme.Color.TextSecondary
	grid.Parent = panel
	MatchUi.list(grid, Enum.FillDirection.Horizontal, 12)

	-- Barras de atributos da escolhida
	local statsFrame = MatchUi.frame("Stats", panel)
	statsFrame.AnchorPoint = Vector2.new(0, 1)
	statsFrame.Position = UDim2.new(0, 0, 1, -116)
	statsFrame.Size = UDim2.new(1, 0, 0, 24)
	MatchUi.list(statsFrame, Enum.FillDirection.Horizontal, 18)
	for i, name in { S.StatDamage, S.StatFireRate, S.StatRange } do
		local holder = MatchUi.frame("Stat", statsFrame)
		holder.LayoutOrder = i
		holder.Size = UDim2.fromOffset(170, 24)
		local text =
			MatchUi.label("Name", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, holder)
		text.Size = UDim2.fromOffset(70, 24)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Text = name
		statsText[i] = text
		local segments = {}
		for s = 1, SEGMENTS do
			local seg = MatchUi.frame("Seg", holder)
			seg.BackgroundTransparency = 0
			seg.BackgroundColor3 = Theme.Color.PanelRaised
			seg.Position = UDim2.fromOffset(72 + (s - 1) * 18, 6)
			seg.Size = UDim2.fromOffset(14, 12)
			MatchUi.corner(seg, 2)
			table.insert(segments, seg)
		end
		statBars[i] = segments
	end

	-- Rodapé
	local divider = MatchUi.frame("Divider", panel)
	divider.AnchorPoint = Vector2.new(0, 1)
	divider.Position = UDim2.new(0, 0, 1, -84)
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.BackgroundTransparency = 0
	divider.BackgroundColor3 = Theme.Color.PanelBorder

	cardText = MatchUi.label("Card", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, panel)
	cardText.AnchorPoint = Vector2.new(0, 1)
	cardText.Position = UDim2.new(0, 0, 1, -58)
	cardText.Size = UDim2.new(0.5, 0, 0, 20)
	cardText.TextXAlignment = Enum.TextXAlignment.Left
	partnerText = MatchUi.label("Partner", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextSecondary, panel)
	partnerText.AnchorPoint = Vector2.new(1, 1)
	partnerText.Position = UDim2.new(1, 0, 1, -58)
	partnerText.Size = UDim2.new(0.5, 0, 0, 20)
	partnerText.TextXAlignment = Enum.TextXAlignment.Right
	partnerText.TextTruncate = Enum.TextTruncate.AtEnd

	confirmButton = MatchUi.button("Confirm", S.Confirm .. " ›", true, panel)
	confirmButton.AnchorPoint = Vector2.new(1, 1)
	confirmButton.Position = UDim2.fromScale(1, 1)
	confirmButton.Size = UDim2.fromOffset(180, 48)
	-- Modal = true libera o mouse da primeira pessoa enquanto o modal está aberto (PC).
	confirmButton.Modal = true
	confirmButton.Activated:Connect(confirm)
	repeatButton = MatchUi.button("Repeat", S.RepeatLast, false, panel)
	repeatButton.AnchorPoint = Vector2.new(1, 1)
	repeatButton.Position = UDim2.new(1, -192, 1, 0)
	repeatButton.Size = UDim2.fromOffset(180, 48)
	repeatButton.Activated:Connect(repeatLast)

	-- Depois de confirmar: "Aguardando início · N s" no centro
	waitingText = MatchUi.label("Waiting", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, gui)
	waitingText.AnchorPoint = Vector2.new(0.5, 0.5)
	waitingText.Position = UDim2.fromScale(0.5, 0.42)
	waitingText.Size = UDim2.new(0.9, 0, 0, 32)
	waitingText.Visible = false
	MatchUi.outlineText(waitingText)

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
			PrepModal.rebuildGrid()
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or data == nil or confirmed then
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
