--!strict
-- Cartas no HUD (ESTILO T6, F7). Sem neon no HUD.
--   PC e controle: as cartas embaixo no centro, com o chip da tecla embaixo de cada uma
--     (C/Q/E/X no teclado; LB/RB no controle). Carga, recarga em segundos e cadeado da ult.
--     A dica fixa "[B] Habilidades" fica no bloco de dicas do CombatHUD (GDD 13.3).
--   Celular: botões fixos (GDD 13.1), cada tecla sempre no mesmo lugar, ou onde o jogador colocou no
--     editor de botões (settings.mobileLayout). Tocar usa; Nuvem: segurar mostra o arco e soltar
--     arremessa; segurar as outras abre os detalhes (ESTILO 3).
--   Painel de habilidades (sobre o jogo, metade da tela, sem pausar): B (PC), direcional para baixo
--     (controle) ou toque longo (celular).
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
local TouchLayout = require(Shared.Ui.TouchLayout)
local UiConfig = require(Shared.Config.UiConfig)

local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local Widgets = require(script.Parent.Parent.Common.Ui.Widgets)
local CardController = require(script.Parent.CardController)
local CardArt = require(Shared.Ui.CardArt)
local MatchUi = require(Shared.Ui.Ui)

type CardKey = string -- "C", "Q", "E" ou "X" (Types.CardKey); string por causa do verificador de tipos
type CardView = CardTypes.CardView

local S = Strings.CardHud
local LAYOUT = CombatConfig.TouchLayout
local INPUT = CombatConfig.Input
local KEYS = UiConfig.Keys
local TILE = Theme.Hud.CardTile
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
local panel: Widgets.Modal
local panelList: ScrollingFrame
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
	if open then
		panel.open()
	else
		panel.close()
	end
end

local function togglePanel()
	setPanelOpen(not panel.isOpen())
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

	-- Arte da carta (F10), apagada, atrás do número
	local art = MatchUi.frame("Art", button)
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.6)
	art.Size = UDim2.fromScale(0.62, 0.62)
	CardArt.draw(art, view.id, color, Theme.Hud.CardArtTransparency)

	local value = MatchUi.label("Value", Theme.Font.Number, Theme.TextSize.Title, Theme.Color.TextPrimary, button)
	MatchUi.outlineText(value)
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
	local profile = PlayerDataClient.get()
	local saved = profile and profile.settings.mobileLayout
	for _, view in CardController.getViews() do
		if touch then
			local placement = TouchLayout.resolve(view.key, viewport, saved)
			local tile = makeTile(view, placement.size, touchFolder, true)
			tile.button.Position = placement.position
			bindTouch(tile)
			table.insert(tiles, tile)
		else
			table.insert(tiles, makeTile(view, TILE, row, false))
		end
	end
end

local function signature(): string
	local profile = PlayerDataClient.get()
	local saved = profile and profile.settings.mobileLayout
	local parts: { string } = { InputDevice.get(), if saved then tostring(saved) else "" }
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
	if panel.isOpen() then
		setPanelOpen(true)
	end
end

local function update()
	local visible = aliveInCombat()
	local touch = InputDevice.get() == "Touch"
	row.Visible = visible and not touch
	touchFolder.Visible = visible and touch
	if not visible and panel.isOpen() and not CardController.isActive() then
		panel.close()
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

	-- Painel de habilidades: sobreposto, metade da tela (ESTILO T6). O jogo não pausa: sem escurecer.
	panel = Widgets.modal("AbilitiesPanel", 55, {
		title = S.PanelTitle,
		size = UDim2.fromScale(0.5, 0.6),
		minSize = Vector2.new(320, 240),
		maxSize = Vector2.new(620, 440),
		overlay = false,
	})
	panelList = MatchUi.scroll("List", Enum.ScrollingDirection.Y, panel.body)
	panelList.Size = UDim2.fromScale(1, 1)
	MatchUi.list(panelList, Enum.FillDirection.Vertical, 12)
	panel.gui.Parent = player:WaitForChild("PlayerGui")

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
	PlayerDataClient.onChanged(onChanged) -- layout dos botões editado
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
		if input.KeyCode == KEYS.Abilities or input.KeyCode == KEYS.AbilitiesPad then
			togglePanel()
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return CardHUD
