--!strict
-- Cartas no HUD, versão PROVISÓRIA (FASES F4; visual final na F7). Sem neon no HUD (ESTILO T6).
--   PC e controle: as cartas embaixo no centro, com o chip da tecla embaixo de cada uma
--     (C/Q/E/X no teclado; LB/RB no controle). Carga, recarga em segundos e cadeado da ult.
--     Dica fixa "[B] Habilidades" no canto inferior esquerdo, acima da vida (GDD 13.3).
--   Celular: botões fixos (GDD 13.1), cada tecla sempre no mesmo lugar. Tocar usa; Nuvem: segurar
--     mostra o arco e soltar arremessa; segurar as outras abre os detalhes (ESTILO 3).
--   Painel de habilidades: B (PC), direcional para baixo (controle) ou toque longo (celular).
--   Avisos: contagem do Renascer e "atingido pelo Tremor".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local CardConfig = require(Shared.Config.CardConfig)
local CardState = require(Shared.Cards.CardState)
local CardTypes = require(Shared.Cards.CardTypes)
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local Strings = require(Shared.Config.Strings)
local TextUtil = require(Shared.TextUtil)
local Theme = require(Shared.Config.Theme)

local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local CardController = require(script.Parent.CardController)
local MatchUi = require(script.Parent.MatchUi)

type CardKey = string -- "C", "Q", "E" ou "X" (Types.CardKey); string por causa do verificador de tipos
type CardView = CardTypes.CardView

local S = Strings.CardHud
local LAYOUT = CombatConfig.TouchLayout
local INPUT = CombatConfig.Input
local TILE = 60
local MARGIN = Theme.ScreenMargin

type Tile = {
	view: CardView,
	button: TextButton,
	name: TextLabel,
	value: TextLabel,
	cover: Frame,
	stroke: UIStroke,
	chip: TextLabel?,
}

local CardHUD = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local row: Frame
local touchFolder: Frame
local hint: Frame
local panel: Frame
local panelList: Frame
local statusText: TextLabel
local tremorText: TextLabel
local tiles: { Tile } = {}
local shownKey = ""
local tremorUntil = 0
local revivedUntil = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function cardName(id: string): string
	local entry = Strings.Cards[id]
	return if entry then entry.name else id
end

local function aliveInCombat(): boolean
	local character = player.Character
	return character ~= nil
		and character:GetAttribute(CombatNames.Attr.Alive) == true
		and CardController.isActive()
		and #CardController.getViews() > 0
end

local function keyLabel(key: CardKey): string
	if InputDevice.get() == "Gamepad" then
		return if key == CardConfig.UltKey then S.GamepadUlt else S.GamepadBasic
	end
	return key
end

-- Painel de habilidades -----------------------------------------------------------------------------

local function setPanelOpen(open: boolean)
	if open then
		CardController.cancelHold()
		for _, child in panelList:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local views = CardController.getViews()
		if #views == 0 then
			local empty =
				MatchUi.label("Empty", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary, panelList)
			empty.Size = UDim2.new(1, 0, 0, 24)
			empty.TextXAlignment = Enum.TextXAlignment.Left
			empty.Text = S.PanelEmpty
		end
		for i, view in views do
			local def = CardConfig.get(view.id)
			local entry = MatchUi.frame(view.id, panelList)
			entry.LayoutOrder = if view.key == CardConfig.UltKey then 10 else i
			entry.Size = UDim2.fromScale(1, 0)
			entry.AutomaticSize = Enum.AutomaticSize.Y
			MatchUi.list(entry, Enum.FillDirection.Vertical, 2)
			local title = MatchUi.label(
				"Title",
				Theme.Font.Title,
				Theme.TextSize.PrimaryButton,
				Theme.Cards[view.id] or Theme.Color.TextPrimary,
				entry
			)
			title.Size = UDim2.new(1, 0, 0, 22)
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Text = string.format(S.PanelLine, TextUtil.upper(cardName(view.id)), keyLabel(view.key))
			title.LayoutOrder = 1
			local body = MatchUi.label("Body", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextPrimary, entry)
			body.Size = UDim2.fromScale(1, 0)
			body.AutomaticSize = Enum.AutomaticSize.Y
			body.TextWrapped = true
			body.TextXAlignment = Enum.TextXAlignment.Left
			body.Text = (Strings.Cards[view.id] or { description = "" }).description
			body.LayoutOrder = 2
			local extra =
				MatchUi.label("Extra", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, entry)
			extra.Size = UDim2.new(1, 0, 0, 16)
			extra.TextXAlignment = Enum.TextXAlignment.Left
			extra.LayoutOrder = 3
			if view.locked then
				extra.Text = string.format(S.PanelUltLocked, CardConfig.UltUnlockRound)
			elseif def and def.cooldown then
				extra.Text = string.format(S.PanelRecharge, def.cooldown)
			else
				extra.Text = string.format(S.PanelNoRecharge, view.maxCharges)
			end
		end
	end
	panel.Visible = open
end

local function togglePanel()
	setPanelOpen(not panel.Visible)
end

-- Cartas -----------------------------------------------------------------------------------------

local function makeTile(view: CardView, size: number, parent: Instance, round: boolean): Tile
	local color = if view.locked then Theme.Cards.Locked else (Theme.Cards[view.id] or Theme.Color.Accent)
	local button = Instance.new("TextButton")
	button.Name = view.key
	button.Text = ""
	button.AutoButtonColor = false
	button.AnchorPoint = if round then Vector2.new(0.5, 0.5) else Vector2.zero
	button.Size = UDim2.fromOffset(size, size)
	button.BackgroundColor3 = Theme.Color.PanelBase
	button.BackgroundTransparency = if round then LAYOUT.ButtonTransparency else Theme.Transparency.PanelBase
	button.LayoutOrder = if view.key == CardConfig.UltKey then 10 else (table.find(CardConfig.BasicKeys, view.key) or 1)
	MatchUi.corner(button, if round then size // 2 else Theme.SmallCardCornerRadius)
	local stroke = MatchUi.stroke(button, color, 2)
	button.Parent = parent

	local name = MatchUi.label("Name", Theme.Font.Title, Theme.TextSize.Label, color, button)
	name.Position = UDim2.fromOffset(0, if round then size * 0.18 else 4)
	name.Size = UDim2.new(1, 0, 0, 14)
	name.Text = TextUtil.upper(cardName(view.id))
	name.TextScaled = true
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MaxTextSize = Theme.TextSize.Label
	nameLimit.Parent = name

	local value = MatchUi.label("Value", Theme.Font.Number, Theme.TextSize.Title, Theme.Color.TextPrimary, button)
	value.AnchorPoint = Vector2.new(0.5, 0.5)
	value.Position = UDim2.fromScale(0.5, 0.62)
	value.Size = UDim2.new(1, 0, 0, 26)

	local cover = MatchUi.frame("Cover", button)
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundColor3 = Theme.Color.Overlay
	cover.BackgroundTransparency = 0.45
	cover.ZIndex = 0
	cover.Visible = false
	MatchUi.corner(cover, if round then size // 2 else Theme.SmallCardCornerRadius)

	local chip: TextLabel? = nil
	if not round then
		local c = MatchUi.keyChip(keyLabel(view.key), button)
		c.AnchorPoint = Vector2.new(0.5, 0)
		c.Position = UDim2.new(0.5, 0, 1, 4)
		c.Size = UDim2.fromOffset(if InputDevice.get() == "Gamepad" then 30 else 22, 22)
		chip = c
	end
	return { view = view, button = button, name = name, value = value, cover = cover, stroke = stroke, chip = chip }
end

local function bindTouch(tile: Tile)
	local key = tile.view.key
	local downAt: number? = nil
	local opened = false
	local isNuvem = tile.view.id == "card_nuvem"
	tile.button.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if tile.view.locked then
			togglePanel() -- ult travada: tocar mostra quando libera
			return
		end
		downAt = os.clock()
		opened = false
		tile.button.BackgroundColor3 = Theme.Color.AccentPressed
		if isNuvem then
			CardController.press(key) -- segurando: mostra o arco
			return
		end
		local myDown = downAt
		task.delay(INPUT.TouchCardDetailsHoldSeconds, function()
			if downAt == myDown then
				opened = true
				setPanelOpen(true)
			end
		end)
	end)
	tile.button.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch or downAt == nil then
			return
		end
		downAt = nil
		tile.button.BackgroundColor3 = Theme.Color.PanelBase
		if isNuvem then
			CardController.release(key) -- soltou: arremessa
		elseif not opened then
			CardController.press(key)
		end
	end)
end

local function rebuild()
	for _, tile in tiles do
		tile.button:Destroy()
	end
	table.clear(tiles)
	local touch = InputDevice.get() == "Touch"
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 400)
	local layout = if math.min(viewport.X, viewport.Y) >= LAYOUT.LargeScreenMinSide then LAYOUT.Large else LAYOUT.Small
	for _, view in CardController.getViews() do
		if touch then
			local tile = makeTile(view, layout.CardSize, touchFolder, true)
			local center = layout.Cards[view.key] or Vector2.new(-75, -345)
			tile.button.Position = UDim2.new(1, center.X, 1, center.Y)
			bindTouch(tile)
			table.insert(tiles, tile)
		else
			table.insert(tiles, makeTile(view, TILE, row, false))
		end
	end
end

local function signature(): string
	local parts = { InputDevice.get() }
	for _, view in CardController.getViews() do
		table.insert(parts, `{view.key}:{view.id}:{view.locked}`)
	end
	return table.concat(parts, "|")
end

local function onChanged()
	local key = signature()
	if key ~= shownKey then
		shownKey = key
		rebuild()
	end
	if panel.Visible then
		setPanelOpen(true)
	end
end

local function update()
	local visible = aliveInCombat()
	local touch = InputDevice.get() == "Touch"
	row.Visible = visible and not touch
	touchFolder.Visible = visible and touch
	hint.Visible = visible and not touch
	if not visible and panel.Visible and not CardController.isActive() then
		panel.Visible = false
	end

	local t = now()
	for _, tile in tiles do
		local view = tile.view
		if view.locked then
			tile.value.Text = S.Locked .. string.format(S.UltLockedShort, CardConfig.UltUnlockRound)
			tile.value.TextSize = Theme.TextSize.Body
			tile.cover.Visible = true
			continue
		end
		local state = CardController.getState(view.key)
		if state == nil then
			continue
		end
		CardState.update(state, t)
		local recharge = CardState.secondsToRecharge(state, t)
		if state.charges <= 0 and recharge > 0 then
			tile.value.Text = string.format(S.Recharge, math.ceil(recharge))
			tile.cover.Visible = true
		elseif state.charges <= 0 then
			tile.value.Text = "0"
			tile.cover.Visible = true
		else
			tile.value.Text = if state.maxCharges > 1 then string.format(S.Charges, state.charges) else ""
			tile.cover.Visible = false
		end
		tile.value.TextSize = Theme.TextSize.Title
	end

	-- Renascer: contagem enquanto a marca vale
	local endsAt = CardController.renascerEndsAt()
	if endsAt and endsAt > t then
		statusText.Text = string.format(S.RenascerActive, math.ceil(endsAt - t))
		statusText.TextColor3 = Theme.Cards.card_renascer
		statusText.Visible = true
	elseif os.clock() < revivedUntil then
		statusText.Text = S.RenascerRevived
		statusText.TextColor3 = Theme.Cards.card_renascer
		statusText.Visible = true
	else
		statusText.Visible = false
	end
	tremorText.Visible = os.clock() < tremorUntil
end

local function build()
	gui = MatchUi.screen("CardHUD", 2, Enum.ScreenInsets.DeviceSafeInsets)

	row = MatchUi.frame("Cards", gui)
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.new(0.5, 0, 1, -MARGIN - 26)
	row.Size = UDim2.fromOffset(4 * (TILE + 10), TILE)
	local list = MatchUi.list(row, Enum.FillDirection.Horizontal, 10)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center

	touchFolder = MatchUi.frame("TouchCards", gui)
	touchFolder.Size = UDim2.fromScale(1, 1)

	-- Dica fixa no PC (GDD 13.3): canto inferior esquerdo, acima da vida
	hint = MatchUi.frame("Hint", gui)
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, MARGIN, 1, -MARGIN - 62)
	hint.Size = UDim2.fromOffset(200, 22)
	local chip = MatchUi.keyChip(S.PanelKey, hint)
	chip.Name = "Key"
	local hintText = MatchUi.label("Text", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, hint)
	hintText.Position = UDim2.fromOffset(28, 0)
	hintText.Size = UDim2.new(1, -28, 1, 0)
	hintText.TextXAlignment = Enum.TextXAlignment.Left
	hintText.Text = S.PanelHint
	InputDevice.onChanged(function(device: InputDevice.Device)
		chip.Text = if device == "Gamepad" then "↓" else S.PanelKey
	end)

	-- Painel de habilidades: sobreposto, metade da tela (ESTILO T6). O jogo não pausa.
	panel = MatchUi.panel("Abilities", gui)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.45)
	panel.Size = UDim2.fromScale(0.5, 0.5)
	panel.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(300, 220)
	limit.MaxSize = Vector2.new(620, 420)
	limit.Parent = panel
	MatchUi.padding(panel, 14)
	local title = MatchUi.label("Title", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, panel)
	title.Size = UDim2.new(1, 0, 0, 26)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = S.PanelTitle
	panelList = MatchUi.frame("List", panel)
	panelList.Position = UDim2.fromOffset(0, 34)
	panelList.Size = UDim2.new(1, 0, 1, -34 - 52)
	MatchUi.list(panelList, Enum.FillDirection.Vertical, 10)
	local close = MatchUi.button("Close", S.PanelClose, false, panel)
	close.AnchorPoint = Vector2.new(1, 1)
	close.Position = UDim2.fromScale(1, 1)
	close.Size = UDim2.fromOffset(140, Theme.Touch.MinTarget)
	close.Modal = true -- libera o mouse da primeira pessoa enquanto o painel está aberto (PC)
	close.Activated:Connect(function()
		setPanelOpen(false)
	end)

	statusText = MatchUi.label("Status", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, gui)
	statusText.AnchorPoint = Vector2.new(0.5, 0.5)
	statusText.Position = UDim2.fromScale(0.5, 0.62)
	statusText.Size = UDim2.fromOffset(360, 30)
	statusText.Visible = false
	MatchUi.outlineText(statusText)

	tremorText = MatchUi.label("Tremor", Theme.Font.Title, Theme.TextSize.PrimaryButton, Theme.Cards.card_tremor, gui)
	tremorText.AnchorPoint = Vector2.new(0.5, 0.5)
	tremorText.Position = UDim2.fromScale(0.5, 0.67)
	tremorText.Size = UDim2.fromOffset(360, 26)
	tremorText.Text = S.Tremored
	tremorText.Visible = false
	MatchUi.outlineText(tremorText)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function CardHUD.Start()
	build()
	CardController.onChanged(onChanged)
	CardController.onEvent(function(kind: string, data: any)
		if kind == "Tremored" then
			local untilT = (data :: CardTypes.TremoredData).untilT
			tremorUntil = os.clock() + math.max(0, untilT - now())
		elseif kind == "Renascer" and (data :: CardTypes.RenascerData).revived then
			revivedUntil = os.clock() + 1.5
		end
	end)
	InputDevice.onChanged(onChanged)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			shownKey = ""
			onChanged()
		end)
	end
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == INPUT.AbilitiesPanelKey or input.KeyCode == INPUT.AbilitiesPanelGamepadButton then
			togglePanel()
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return CardHUD
