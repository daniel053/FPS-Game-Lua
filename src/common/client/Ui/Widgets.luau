--!strict
-- Componentes de interface reutilizáveis (ESTILO 2.5, F7), usados por todas as telas:
--   botão principal e secundário, chip de tecla que acompanha o controle, abas, cartão de item,
--   modal sobre o jogo, barras, barras de atributo, controle deslizante, liga/desliga, escolha,
--   etiqueta de raridade e animações (ESTILO 2.7).
-- Cores e fontes do Theme; textos do Strings. Sem neon (só a moldura Celestial e o item selecionado).

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Config.Strings)
local TextUtil = require(Shared.TextUtil)
local Theme = require(Shared.Config.Theme)
local TextScale = require(Shared.Ui.TextScale)
local Ui = require(Shared.Ui.Ui)

local InputDevice = require(script.Parent.Parent.InputDevice)

local U = Strings.Ui
local ANIM = Theme.Animation

local Widgets = {}

-- Chips de tecla ----------------------------------------------------------------------------------
-- Um chip mostra a tecla do PC e, se houver, o botão do controle; no toque some (ESTILO 3).

type ChipEntry = { chip: TextLabel, pc: string?, pad: string? }
local chips: { [TextLabel]: ChipEntry } = setmetatable({} :: any, { __mode = "k" })

local function refreshChip(entry: ChipEntry, device: InputDevice.Device)
	local text = if device == "KeyboardMouse" then entry.pc elseif device == "Gamepad" then entry.pad else nil
	entry.chip.Visible = text ~= nil
	if text then
		Ui.setChipText(entry.chip, text)
	end
end

-- Chip que aparece só no teclado (pc) e/ou no controle (pad).
function Widgets.keyChip(parent: Instance, pc: string?, pad: string?): TextLabel
	local chip = Ui.keyChip(pc or pad or "", parent)
	local entry = { chip = chip, pc = pc, pad = pad }
	chips[chip] = entry
	refreshChip(entry, InputDevice.get())
	return chip
end

function Widgets.setChipKeys(chip: TextLabel, pc: string?, pad: string?)
	local entry = chips[chip]
	if entry then
		entry.pc, entry.pad = pc, pad
		refreshChip(entry, InputDevice.get())
	end
end

-- "[B] Habilidades": chip + texto, numa linha (dicas fixas do PC, GDD 13.3).
function Widgets.hint(parent: Instance, pc: string?, pad: string?, text: string): Frame
	local row = Ui.frame("Hint", parent)
	row.Size = UDim2.fromOffset(0, 22)
	row.AutomaticSize = Enum.AutomaticSize.X
	local layout = Ui.list(row, Enum.FillDirection.Horizontal, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	local chip = Widgets.keyChip(row, pc, pad)
	chip.LayoutOrder = 1
	local label = Ui.label("Text", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, row)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 22)
	label.Text = text
	label.LayoutOrder = 2
	Ui.outlineText(label)
	-- A linha some junto com o chip (no toque não há dica)
	local function sync()
		row.Visible = chip.Visible
	end
	chip:GetPropertyChangedSignal("Visible"):Connect(sync)
	sync()
	return row
end

-- Animações (ESTILO 2.7) ----------------------------------------------------------------------------

-- Abrir: sobe 24 px e aparece em 0,2 s.
function Widgets.popIn(frame: GuiObject)
	local final = frame:GetAttribute("FinalPosition")
	local target = if typeof(final) == "UDim2" then final else frame.Position
	frame:SetAttribute("FinalPosition", target)
	frame.Position = target + UDim2.fromOffset(0, ANIM.ModalOpenOffset)
	TweenService:Create(frame, TweenInfo.new(ANIM.ModalOpenTime, Enum.EasingStyle.Quad), { Position = target }):Play()
end

-- Seleção de item: aumenta 4% em 0,1 s.
function Widgets.selectPulse(obj: GuiObject)
	local scale = obj:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = obj
	scale.Scale = ANIM.SelectScale
	TweenService:Create(scale, TweenInfo.new(ANIM.SelectTime * 2, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
end

local function tweenColor(obj: GuiObject, color: Color3)
	TweenService:Create(obj, TweenInfo.new(ANIM.TabSwitchTime), { BackgroundColor3 = color }):Play()
end

-- Texto que não cabe numa linha encolhe (até o tamanho de rótulo) em vez de quebrar (botões estreitos
-- em celular pequeno). Volta ao tamanho normal quando o espaço aumenta.
function Widgets.fitText(label: TextLabel)
	label.TextWrapped = false
	label:SetAttribute(TextScale.SelfSizedAttr, true) -- o tamanho do texto das configurações vem daqui
	local base = label.TextSize
	local adjusting = false
	local function fit()
		if adjusting then
			return
		end
		adjusting = true
		label.TextSize = math.floor(base * TextScale.get() + 0.5)
		task.defer(function()
			while not label.TextFits and label.TextSize > Theme.TextSize.Label do
				label.TextSize -= 1
			end
			adjusting = false
		end)
	end
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	label:GetPropertyChangedSignal("Text"):Connect(fit)
	TextScale.onChanged(fit)
	fit()
end

-- Botões ------------------------------------------------------------------------------------------

export type ButtonKind = "primary" | "secondary"

export type Button = {
	root: TextButton,
	label: TextLabel,
	chip: TextLabel?,
	setText: (text: string) -> (),
	setEnabled: (enabled: boolean) -> (),
	setKind: (kind: ButtonKind) -> (),
	isEnabled: () -> boolean,
	onClick: (callback: () -> ()) -> (),
}

export type ButtonOptions = {
	pc: string?, -- chip de tecla no PC (ex.: "Enter")
	pad: string?, -- chip no controle (ex.: "X")
	arrow: boolean?, -- seta "›" no fim (padrão: só no principal)
	modal: boolean?, -- libera o mouse da primeira pessoa enquanto o botão aparece (PC)
	size: UDim2?,
	textSize: number?,
	order: number?,
}

-- Botão principal (fundo do acento, caixa alta, "›", chanfrado) ou secundário (panel.raised + borda).
function Widgets.button(parent: Instance, text: string, kind: ButtonKind, options: ButtonOptions?): Button
	local opts: ButtonOptions = options or {}
	local root = Instance.new("TextButton")
	root.Name = "Button"
	root.Text = ""
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.Size = opts.size or UDim2.fromOffset(200, Theme.PrimaryButtonMinHeight)
	root.LayoutOrder = opts.order or 0
	root.Modal = opts.modal == true
	root.Parent = parent

	local cut = Theme.Chamfer.Button
	local fill = Ui.chamferFill(root, Theme.Color.Accent, 0, cut)
	local border = Ui.chamferBorder(root, Theme.Color.PanelBorder, cut)

	local label = Ui.label(
		"Label",
		Theme.Font.Title,
		opts.textSize or Theme.TextSize.PrimaryButton,
		Theme.Color.TextPrimary,
		root
	)
	label.Size = UDim2.fromScale(1, 1)
	label.ZIndex = 2
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = label
	Widgets.fitText(label)

	local chip: TextLabel? = nil
	if opts.pc or opts.pad then
		local c = Widgets.keyChip(root, opts.pc, opts.pad)
		c.AnchorPoint = Vector2.new(1, 0.5)
		c.Position = UDim2.new(1, -8, 0.5, 0)
		c.ZIndex = 3
		chip = c
		local function room()
			pad.PaddingRight = UDim.new(0, if c.Visible then c.Size.X.Offset + 14 else 10)
		end
		c:GetPropertyChangedSignal("Visible"):Connect(room)
		c:GetPropertyChangedSignal("Size"):Connect(room)
		room()
	end

	local currentKind: ButtonKind = kind
	local enabled = true
	local pressed = false
	local baseText = text
	local callbacks: { () -> () } = {}

	local function render()
		local primary = currentKind == "primary"
		local color = if primary then Theme.Color.Accent else Theme.Color.PanelRaised
		if pressed and enabled then
			color = if primary then Theme.Color.AccentPressed else Theme.Color.PanelBorder
		end
		Ui.setFill(fill, color, if enabled then 0 else Theme.DisabledTransparency)
		border.Visible = not primary
		label.TextColor3 = if enabled then Theme.Color.TextPrimary else Theme.Color.TextSecondary
		local arrow = if opts.arrow == nil then primary else opts.arrow
		local upper = TextUtil.upper(baseText)
		label.Text = if arrow and enabled then upper .. " " .. U.Arrow else upper
	end

	root.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			pressed = true
			render()
		end
	end)
	root.InputEnded:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			pressed = false
			render()
		end
	end)
	root.MouseLeave:Connect(function()
		if pressed then
			pressed = false
			render()
		end
	end)
	root.Activated:Connect(function()
		if not enabled then
			return
		end
		for _, callback in callbacks do
			task.spawn(callback)
		end
	end)

	render()
	return {
		root = root,
		label = label,
		chip = chip,
		setText = function(value: string)
			baseText = value
			render()
		end,
		setEnabled = function(value: boolean)
			enabled = value
			root.Selectable = value
			render()
		end,
		setKind = function(value: ButtonKind)
			currentKind = value
			render()
		end,
		isEnabled = function(): boolean
			return enabled
		end,
		onClick = function(callback: () -> ())
			table.insert(callbacks, callback)
		end,
	}
end

-- Botão quadrado pequeno (voltar "‹", fechar, engrenagem…), com alvo de toque de 44 px.
function Widgets.iconButton(parent: Instance, glyph: string, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = "Icon"
	b.AutoButtonColor = true
	b.Size = UDim2.fromOffset(Theme.Touch.MinTarget, Theme.Touch.MinTarget)
	b.BackgroundColor3 = Theme.Color.PanelRaised
	b.FontFace = Theme.Font.Title
	b.TextSize = Theme.TextSize.Title
	b.TextColor3 = Theme.Color.TextPrimary
	b.Text = glyph
	Ui.corner(b)
	Ui.stroke(b)
	b.Activated:Connect(onClick)
	b.Parent = parent
	return b
end

-- Abas --------------------------------------------------------------------------------------------

export type TabItem = { id: string, label: string }

export type Tabs = {
	root: ScrollingFrame,
	select: (id: string) -> (),
	selected: () -> string?,
	setVisible: (id: string, visible: boolean) -> (),
	setLabel: (id: string, label: string) -> (),
	buttons: { [string]: TextButton },
}

-- Abas em caixa alta: ativa com fundo do acento, inativas panel.raised (ESTILO 2.5). Se não couberem
-- (celular), rolam na horizontal (ESTILO 3). onSelect(id) a cada troca.
function Widgets.tabs(parent: Instance, items: { TabItem }, onSelect: (id: string) -> (), height: number?): Tabs
	local h = height or Theme.Touch.MinTarget
	local root = Ui.scroll("Tabs", Enum.ScrollingDirection.X, parent)
	root.Size = UDim2.new(1, 0, 0, h + 6)
	root.ScrollBarThickness = 3
	local layout = Ui.list(root, Enum.FillDirection.Horizontal, Theme.Space.Small)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top

	local buttons: { [string]: TextButton } = {}
	local fills: { [string]: Frame } = {}
	local current: string? = nil

	local function paint()
		for id, button in buttons do
			local active = id == current
			for _, p in fills[id]:GetChildren() do
				if p:IsA("Frame") then
					tweenColor(p, if active then Theme.Color.Accent else Theme.Color.PanelRaised)
				end
			end
			local text = button:FindFirstChild("Label") :: TextLabel?
			if text then
				text.TextColor3 = if active then Theme.Color.TextPrimary else Theme.Color.TextSecondary
			end
		end
	end

	local tabs: Tabs
	for i, item in items do
		local b = Instance.new("TextButton")
		b.Name = item.id
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.LayoutOrder = i
		-- Largura medida pelo texto (o tamanho automático do Roblox não combina com o fundo chanfrado)
		local text = TextUtil.upper(item.label)
		b.Size = UDim2.fromOffset(Ui.textWidth(text, Theme.Font.Title, Theme.TextSize.Body) + 32, h)
		b.Parent = root
		fills[item.id] = Ui.chamferFill(b, Theme.Color.PanelRaised, 0, Theme.Chamfer.Tab)
		local label = Ui.label("Label", Theme.Font.Title, Theme.TextSize.Body, Theme.Color.TextSecondary, b)
		label.Size = UDim2.fromScale(1, 1)
		label.Text = text
		label.ZIndex = 2
		b.Activated:Connect(function()
			tabs.select(item.id)
		end)
		buttons[item.id] = b
	end

	tabs = {
		root = root,
		buttons = buttons,
		select = function(id: string)
			if not buttons[id] or id == current then
				return
			end
			current = id
			paint()
			onSelect(id)
		end,
		selected = function(): string?
			return current
		end,
		setVisible = function(id: string, visible: boolean)
			local b = buttons[id]
			if b then
				b.Visible = visible
			end
		end,
		setLabel = function(id: string, label: string)
			local b = buttons[id]
			local text = b and b:FindFirstChild("Label") :: TextLabel?
			if text then
				text.Text = TextUtil.upper(label)
			end
		end,
	}
	return tabs
end

-- Cartão de item (arma, skin, carta) --------------------------------------------------------------

export type ItemCard = {
	root: TextButton,
	content: Frame, -- área da imagem/ícone (acima do nome)
	title: TextLabel,
	setSelected: (selected: boolean) -> (),
	setLocked: (locked: boolean, note: string?) -> (),
	setBorder: (color: Color3, thickness: number) -> (),
}

-- panel.raised, imagem no centro, nome em caixa alta embaixo. Selecionado = borda do acento + brilho
-- discreto (accent.glow). Travado = escurecido com cadeado.
function Widgets.itemCard(parent: Instance, title: string, size: UDim2, order: number?): ItemCard
	local root = Instance.new("TextButton")
	root.Name = "Item"
	root.Text = ""
	root.AutoButtonColor = false
	root.Size = size
	root.LayoutOrder = order or 0
	root.BackgroundColor3 = Theme.Color.PanelRaised
	Ui.corner(root)
	local stroke = Ui.stroke(root)
	root.Parent = parent

	local glow = Ui.frame("Glow", root)
	glow.BackgroundTransparency = Theme.Transparency.AccentGlow
	glow.BackgroundColor3 = Theme.Color.AccentGlow
	local g = Theme.Selected.GlowPadding
	glow.Position = UDim2.fromOffset(-g, -g)
	glow.Size = UDim2.new(1, 2 * g, 1, 2 * g)
	glow.ZIndex = 0
	glow.Visible = false
	Ui.corner(glow, Theme.SmallCardCornerRadius + g)

	local content = Ui.frame("Content", root)
	content.Position = UDim2.fromOffset(6, 6)
	content.Size = UDim2.new(1, -12, 1, -12 - 20)

	local titleLabel = Ui.label("Title", Theme.Font.Title, Theme.TextSize.Label + 1, Theme.Color.TextPrimary, root)
	titleLabel.AnchorPoint = Vector2.new(0, 1)
	titleLabel.Position = UDim2.new(0, 4, 1, -4)
	titleLabel.Size = UDim2.new(1, -8, 0, 18)
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Text = TextUtil.upper(title)

	local cover = Ui.frame("Locked", root)
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundColor3 = Theme.Color.Overlay
	cover.BackgroundTransparency = 0.35
	cover.ZIndex = 3
	cover.Visible = false
	Ui.corner(cover)
	local coverText = Ui.label("Text", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextPrimary, cover)
	coverText.Size = UDim2.fromScale(1, 1)
	coverText.TextWrapped = true
	coverText.ZIndex = 3

	local baseColor = Theme.Color.PanelBorder
	local baseThickness = 1
	local selected = false

	local function paint()
		stroke.Color = if selected then Theme.Color.Accent else baseColor
		stroke.Thickness = if selected then Theme.Selected.BorderThickness else baseThickness
		glow.Visible = selected
	end

	return {
		root = root,
		content = content,
		title = titleLabel,
		setSelected = function(value: boolean)
			if value and not selected then
				Widgets.selectPulse(root)
			end
			selected = value
			paint()
		end,
		setLocked = function(locked: boolean, note: string?)
			cover.Visible = locked
			coverText.Text = if note then U.Lock .. "\n" .. note else U.Lock
		end,
		setBorder = function(color: Color3, thickness: number)
			baseColor, baseThickness = color, thickness
			paint()
		end,
	}
end

-- Raridade (ESTILO 2.2): nunca só a cor — sempre o nome e o ícone. Neon forte só na Celestial.
function Widgets.rarityTag(parent: Instance, rarity: string): TextLabel
	local style = Theme.Rarity[rarity]
	local info = Strings.Rarity[rarity]
	local tag = Ui.label("Rarity", Theme.Font.Title, Theme.TextSize.Label, style.color, parent)
	tag.AutomaticSize = Enum.AutomaticSize.X
	tag.Size = UDim2.fromOffset(0, 18)
	tag.Text = info.icon .. " " .. TextUtil.upper(info.name)
	return tag
end

-- Moldura de raridade num cartão: borda na cor da raridade. A Celestial pulsa devagar (~2 s).
function Widgets.rarityFrame(card: ItemCard, rarity: string)
	local style = Theme.Rarity[rarity]
	card.setBorder(style.color, style.borderThickness)
	if style.glow == "neon" then
		local stroke = card.root:FindFirstChildOfClass("UIStroke")
		if stroke then
			local info = TweenInfo.new(
				Theme.CelestialPulseSeconds / 2,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				-1,
				true
			)
			TweenService:Create(stroke, info, { Transparency = 0.5 }):Play()
		end
	end
end

-- Modal sobre o jogo --------------------------------------------------------------------------------

export type Modal = {
	gui: ScreenGui,
	overlay: Frame,
	panel: Frame,
	header: Frame,
	body: Frame,
	title: TextLabel,
	back: TextButton,
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	setTitle: (text: string) -> (),
	onClosed: (callback: () -> ()) -> (),
}

export type ModalOptions = {
	title: string,
	size: UDim2?, -- padrão: 70% × 75% (no celular, 92% × 86%)
	touchSize: UDim2?, -- tamanho no celular quando a tela precisa de mais espaço
	maxSize: Vector2?,
	minSize: Vector2?,
	overlay: boolean?, -- escurecer o jogo atrás (padrão: sim)
	position: UDim2?,
	anchor: Vector2?,
	closeKey: Enum.KeyCode?, -- tecla que também fecha (ex.: P, B)
}

-- Modal (ESTILO 2.5): panel.base sobre bg.overlay. Nunca fundo opaco: o jogo continua visível atrás.
-- O botão "‹" do cabeçalho fecha; Modal = true libera o mouse da primeira pessoa no PC.
function Widgets.modal(name: string, order: number, options: ModalOptions): Modal
	local gui = Ui.screen(name, order, Enum.ScreenInsets.CoreUISafeInsets)
	gui.Enabled = false

	local overlay = Ui.frame("Overlay", gui)
	overlay.Size = UDim2.new(1, 0, 1, 200) -- cobre também a faixa da barra do Roblox
	overlay.Position = UDim2.fromOffset(0, -100)
	overlay.BackgroundColor3 = Theme.Color.Overlay
	overlay.BackgroundTransparency = Theme.Transparency.Overlay
	overlay.Visible = options.overlay ~= false
	overlay.Active = true -- não deixa o toque atravessar para o jogo

	local panel, panelContent = Ui.panel("Panel", gui)
	panel.AnchorPoint = options.anchor or Vector2.new(0.5, 0.5)
	panel.Position = options.position or UDim2.fromScale(0.5, 0.5)
	panel.Size = options.size or UDim2.fromScale(0.7, 0.75)
	panel.Active = true
	Ui.sizeLimit(panel, options.minSize or Vector2.new(320, 240), options.maxSize or Vector2.new(1040, 640))
	local pad = Theme.Space.PanelPadding

	local header = Ui.frame("Header", panelContent)
	header.Position = UDim2.fromOffset(pad, pad - 4)
	header.Size = UDim2.new(1, -2 * pad, 0, Theme.Touch.MinTarget)

	local opened = false
	local closedCallbacks: { () -> () } = {}
	local modal: Modal

	local back = Widgets.iconButton(header, U.Back, function()
		modal.close()
	end)
	back.Modal = true
	local title = Ui.label("Title", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, header)
	title.Position = UDim2.fromOffset(Theme.Touch.MinTarget + 12, 0)
	title.Size = UDim2.new(1, -(Theme.Touch.MinTarget + 12), 1, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = TextUtil.upper(options.title)

	local body = Ui.frame("Body", panelContent)
	body.Position = UDim2.fromOffset(pad, pad + Theme.Touch.MinTarget + 6)
	body.Size = UDim2.new(1, -2 * pad, 1, -(2 * pad + Theme.Touch.MinTarget + 6))

	local function fit()
		local touch = InputDevice.get() == "Touch"
		if touch then
			panel.Size = options.touchSize or options.size or UDim2.fromScale(0.92, 0.86)
		else
			panel.Size = options.size or UDim2.fromScale(0.7, 0.75)
		end
	end

	modal = {
		gui = gui,
		overlay = overlay,
		panel = panel,
		header = header,
		body = body,
		title = title,
		back = back,
		open = function()
			if opened then
				return
			end
			opened = true
			fit()
			gui.Enabled = true
			Widgets.popIn(panel)
			if InputDevice.get() == "Gamepad" then
				GuiService.SelectedObject = back
			end
		end,
		close = function()
			if not opened then
				return
			end
			opened = false
			gui.Enabled = false
			local selected = GuiService.SelectedObject
			if selected and selected:IsDescendantOf(gui) then
				GuiService.SelectedObject = nil
			end
			for _, callback in closedCallbacks do
				task.spawn(callback)
			end
		end,
		isOpen = function(): boolean
			return opened
		end,
		setTitle = function(text: string)
			title.Text = TextUtil.upper(text)
		end,
		onClosed = function(callback: () -> ())
			table.insert(closedCallbacks, callback)
		end,
	}

	if options.closeKey then
		local key = options.closeKey
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if opened and not processed and input.KeyCode == key then
				modal.close()
			end
		end)
	end
	-- Controle: B fecha
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if opened and input.KeyCode == Enum.KeyCode.ButtonB then
			modal.close()
		end
	end)
	return modal
end

-- Barras -------------------------------------------------------------------------------------------

export type Bar = { root: Frame, fill: Frame, set: (fraction: number) -> () }

function Widgets.bar(parent: Instance, color: Color3, size: UDim2): Bar
	local back = Ui.frame("Bar", parent)
	back.Size = size
	back.BackgroundColor3 = Theme.Color.PanelBase
	back.BackgroundTransparency = Theme.Transparency.PanelBase
	Ui.corner(back, 3)
	Ui.stroke(back, Theme.Color.Overlay)
	local fill = Ui.frame("Fill", back)
	fill.BackgroundTransparency = 0
	fill.BackgroundColor3 = color
	fill.Size = UDim2.fromScale(1, 1)
	Ui.corner(fill, 3)
	return {
		root = back,
		fill = fill,
		set = function(fraction: number)
			local f = math.clamp(fraction, 0, 1)
			fill.Size = UDim2.fromScale(f, 1)
			fill.Visible = f > 0
		end,
	}
end

export type StatBars = { root: Frame, set: (values: { number }?) -> () }

-- "Dano ▮▮▮▯▯  Cadência ▮▮▮▮▯  Alcance ▮▮▯▯▯" (ESTILO T2): valores de 0 a 1.
function Widgets.statBars(parent: Instance, names: { string }, segments: number): StatBars
	local root = Ui.frame("Stats", parent)
	root.Size = UDim2.new(1, 0, 0, 24)
	Ui.list(root, Enum.FillDirection.Horizontal, 0)
	local rows: { { Frame } } = {}
	for i, name in names do
		-- Cada atributo ocupa uma fatia igual da largura (cabe em celular pequeno)
		local holder = Ui.frame("Stat", root)
		holder.LayoutOrder = i
		holder.Size = UDim2.fromScale(1 / #names, 1)
		local text = Ui.label("Name", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, holder)
		text.Size = UDim2.fromOffset(64, 24)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Text = name
		local list = {}
		for s = 1, segments do
			local seg = Ui.frame("Seg", holder)
			seg.BackgroundTransparency = 0
			seg.BackgroundColor3 = Theme.Color.PanelRaised
			seg.Position = UDim2.fromOffset(64 + (s - 1) * 16, 6)
			seg.Size = UDim2.fromOffset(12, 12)
			Ui.corner(seg, 2)
			table.insert(list, seg)
		end
		rows[i] = list
	end
	return {
		root = root,
		set = function(values: { number }?)
			root.Visible = values ~= nil
			if values == nil then
				return
			end
			for i, list in rows do
				local filled = math.max(1, math.round((values[i] or 0) * segments))
				for s, seg in list do
					seg.BackgroundColor3 = if s <= filled then Theme.Color.Accent else Theme.Color.PanelRaised
				end
			end
		end,
	}
end

-- Controles de configuração ------------------------------------------------------------------------

export type Slider = { frame: Frame, set: (value: number) -> (), get: () -> number }

-- Controle deslizante: arrastar na barra (toque e mouse) e botões − e + (controle e toque preciso).
function Widgets.slider(
	parent: Instance,
	title: string,
	minValue: number,
	maxValue: number,
	step: number,
	value: number,
	format: (number) -> string,
	onChange: (number) -> ()
): Slider
	local button = Theme.Touch.MinTarget
	local frame = Ui.frame("Slider", parent)
	frame.Size = UDim2.new(1, 0, 0, 24 + button + 2)

	local label = Ui.label("Title", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, frame)
	label.Size = UDim2.new(1, -70, 0, 20)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = title

	local valueLabel = Ui.label("Value", Theme.Font.Number, Theme.TextSize.Body, Theme.Color.TextPrimary, frame)
	valueLabel.AnchorPoint = Vector2.new(1, 0)
	valueLabel.Position = UDim2.fromScale(1, 0)
	valueLabel.Size = UDim2.fromOffset(70, 20)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right

	local current = value
	local set: (number, boolean) -> ()

	local minus = Widgets.iconButton(frame, U.Minus, function()
		set(current - step, true)
	end)
	minus.Position = UDim2.fromOffset(0, 24)
	minus.Modal = true
	local plus = Widgets.iconButton(frame, U.Plus, function()
		set(current + step, true)
	end)
	plus.AnchorPoint = Vector2.new(1, 0)
	plus.Position = UDim2.new(1, 0, 0, 24)

	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.Text = ""
	track.AutoButtonColor = false
	track.Selectable = false
	track.BackgroundColor3 = Theme.Color.PanelRaised
	track.Position = UDim2.fromOffset(button + 10, 24 + button / 2 - 8)
	track.Size = UDim2.new(1, -2 * (button + 10), 0, 16)
	Ui.corner(track, 8)
	Ui.stroke(track)
	track.Parent = frame

	local fill = Ui.frame("Fill", track)
	fill.BackgroundColor3 = Theme.Color.Accent
	fill.BackgroundTransparency = 0
	fill.Size = UDim2.fromScale(0, 1)
	Ui.corner(fill, 8)

	local function render()
		local alpha = if maxValue > minValue then (current - minValue) / (maxValue - minValue) else 0
		fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
		valueLabel.Text = format(current)
	end

	set = function(v: number, notify: boolean)
		local snapped = math.floor((v - minValue) / step + 0.5) * step + minValue
		snapped = math.clamp(snapped, minValue, maxValue)
		snapped = math.floor(snapped * 1000 + 0.5) / 1000
		if snapped == current then
			render()
			return
		end
		current = snapped
		render()
		if notify then
			onChange(current)
		end
	end

	local function fromX(x: number)
		local alpha = (x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		set(minValue + math.clamp(alpha, 0, 1) * (maxValue - minValue), true)
	end

	local dragging = false
	track.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not dragging then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	render()
	return {
		frame = frame,
		set = function(v: number)
			set(v, false)
		end,
		get = function(): number
			return current
		end,
	}
end

export type Choice = { frame: Frame, set: (id: string) -> () }

-- Linha com título e opções lado a lado (a escolhida com o acento). Também serve para liga/desliga.
function Widgets.choice(
	parent: Instance,
	title: string,
	options: { TabItem },
	value: string,
	onChange: (id: string) -> ()
): Choice
	local frame = Ui.frame("Choice", parent)
	frame.Size = UDim2.new(1, 0, 0, 24 + Theme.Touch.MinTarget)
	local label = Ui.label("Title", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, frame)
	label.Size = UDim2.new(1, 0, 0, 20)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = title
	local row = Ui.frame("Options", frame)
	row.Position = UDim2.fromOffset(0, 24)
	row.Size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget)
	Ui.list(row, Enum.FillDirection.Horizontal, Theme.Space.Small)

	local current = value
	local buttons: { [string]: TextButton } = {}
	local function paint()
		for id, b in buttons do
			local active = id == current
			b.BackgroundColor3 = if active then Theme.Color.Accent else Theme.Color.PanelRaised
			b.TextColor3 = if active then Theme.Color.TextPrimary else Theme.Color.TextSecondary
		end
	end
	for i, option in options do
		local b = Instance.new("TextButton")
		b.Name = option.id
		b.LayoutOrder = i
		b.AutoButtonColor = true
		b.Size = UDim2.fromOffset(0, Theme.Touch.MinTarget)
		b.AutomaticSize = Enum.AutomaticSize.X
		b.FontFace = Theme.Font.Title
		b.TextSize = Theme.TextSize.Body
		b.Text = TextUtil.upper(option.label)
		Ui.corner(b)
		Ui.stroke(b)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 14)
		pad.PaddingRight = UDim.new(0, 14)
		pad.Parent = b
		b.Parent = row
		b.Activated:Connect(function()
			if current ~= option.id then
				current = option.id
				paint()
				onChange(option.id)
			end
		end)
		buttons[option.id] = b
	end
	paint()
	return {
		frame = frame,
		set = function(id: string)
			current = id
			paint()
		end,
	}
end

-- Liga/desliga como escolha de duas opções (SIM / NÃO).
function Widgets.toggle(parent: Instance, title: string, value: boolean, onChange: (boolean) -> ()): Choice
	return Widgets.choice(
		parent,
		title,
		{
			{ id = "on", label = U.On },
			{ id = "off", label = U.Off },
		},
		if value then "on" else "off",
		function(id: string)
			onChange(id == "on")
		end
	)
end

-- Título pequeno de seção (caixa alta, text.secondary).
function Widgets.sectionTitle(parent: Instance, text: string, order: number?): TextLabel
	local l = Ui.label("Section", Theme.Font.Title, Theme.TextSize.Body, Theme.Color.TextSecondary, parent)
	l.Size = UDim2.new(1, 0, 0, 20)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = TextUtil.upper(text)
	l.LayoutOrder = order or 0
	return l
end

-- Fica numa subpasta (o Loader não chama Start aqui): liga a troca de controle ao carregar.
InputDevice.onChanged(function(device: InputDevice.Device)
	for _, entry in chips do
		refreshChip(entry, device)
	end
end)

return Widgets
