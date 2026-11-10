--!strict
-- Peças básicas de interface (F7): telas, quadros, textos, listas e o painel com cantos chanfrados.
-- Tudo com cores e fontes do Theme (ESTILO 2). Os componentes prontos (botões, abas, cartões, modal,
-- barras…) ficam em Widgets.luau e são montados com estas peças.
--
-- Canto chanfrado: o Roblox não recorta em diagonal. O painel é montado com 3 retângulos que não se
-- sobrepõem (a transparência fica igual em tudo) e 2 quadradinhos com um UIGradient a 45° que deixa
-- só metade visível (um triângulo). O corte fica no canto superior esquerdo e no inferior direito.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TextService = game:GetService("TextService")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local TextScale = require(script.Parent.TextScale)

local Ui = {}

function Ui.corner(parent: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.SmallCardCornerRadius)
	corner.Parent = parent
end

function Ui.stroke(parent: GuiObject, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.Color.PanelBorder
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

-- ScreenGui do jogo. Os textos acompanham o tamanho escolhido nas configurações (TextScale).
function Ui.screen(name: string, order: number, insets: Enum.ScreenInsets): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = insets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order
	TextScale.track(gui)
	return gui
end

function Ui.frame(name: string, parent: Instance?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

function Ui.label(name: string, font: Font, size: number, color: Color3, parent: Instance?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.Text = ""
	l.Parent = parent
	return l
end

-- Texto que se ajusta à altura do conteúdo (descrições).
function Ui.paragraph(name: string, font: Font, size: number, color: Color3, parent: Instance?): TextLabel
	local l = Ui.label(name, font, size, color, parent)
	l.Size = UDim2.fromScale(1, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	return l
end

-- Contorno escuro no texto solto sobre o jogo (legível em qualquer fundo).
function Ui.outlineText(l: TextLabel)
	l.TextStrokeColor3 = Theme.Color.Overlay
	l.TextStrokeTransparency = 0.3
end

function Ui.list(parent: Instance, direction: Enum.FillDirection, padding: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.Padding = UDim.new(0, padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

function Ui.padding(parent: Instance, all: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, all)
	p.PaddingBottom = UDim.new(0, all)
	p.PaddingLeft = UDim.new(0, all)
	p.PaddingRight = UDim.new(0, all)
	p.Parent = parent
end

function Ui.sizeLimit(parent: GuiObject, minSize: Vector2?, maxSize: Vector2?)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = minSize or Vector2.zero
	limit.MaxSize = maxSize or Vector2.new(math.huge, math.huge)
	limit.Parent = parent
end

function Ui.scroll(name: string, direction: Enum.ScrollingDirection, parent: Instance?): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.Name = name
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = if direction == Enum.ScrollingDirection.X
		then Enum.AutomaticSize.X
		elseif direction == Enum.ScrollingDirection.Y then Enum.AutomaticSize.Y
		else Enum.AutomaticSize.XY
	s.ScrollingDirection = direction
	s.ScrollBarThickness = 4
	s.ScrollBarImageColor3 = Theme.Color.TextSecondary
	s.Selectable = false
	s.Parent = parent
	return s
end

-- Canto chanfrado ---------------------------------------------------------------------------------

local HALF = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 1),
	NumberSequenceKeypoint.new(0.501, 0),
	NumberSequenceKeypoint.new(1, 0),
})

local function piece(parent: Instance, position: UDim2, size: UDim2): Frame
	local f = Ui.frame("Piece", parent)
	f.BackgroundTransparency = 0
	f.Position = position
	f.Size = size
	return f
end

local function triangle(parent: Instance, position: UDim2, cut: number, rotation: number): Frame
	local f = piece(parent, position, UDim2.fromOffset(cut, cut))
	f.Name = "Corner"
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = HALF
	gradient.Parent = f
	return f
end

local function line(parent: Instance, position: UDim2, size: UDim2): Frame
	local f = piece(parent, position, size)
	f.Name = "Edge"
	return f
end

-- Fundo chanfrado que ocupa o pai inteiro (fica atrás dos outros filhos: ZIndex 0).
-- Devolve o quadro "Fill"; a cor muda com Ui.setFill.
function Ui.chamferFill(parent: GuiObject, color: Color3, transparency: number, cut: number): Frame
	local fill = Ui.frame("Fill", parent)
	fill.Size = UDim2.fromScale(1, 1)
	fill.ZIndex = 0
	piece(fill, UDim2.fromOffset(0, cut), UDim2.new(1, 0, 1, -2 * cut))
	piece(fill, UDim2.fromOffset(cut, 0), UDim2.new(1, -cut, 0, cut))
	piece(fill, UDim2.new(0, 0, 1, -cut), UDim2.new(1, -cut, 0, cut))
	triangle(fill, UDim2.fromOffset(0, 0), cut, 45)
	triangle(fill, UDim2.new(1, -cut, 1, -cut), cut, 225)
	Ui.setFill(fill, color, transparency)
	return fill
end

function Ui.setFill(fill: Frame, color: Color3, transparency: number?)
	for _, child in fill:GetChildren() do
		if child:IsA("Frame") then
			child.BackgroundColor3 = color
			if transparency then
				child.BackgroundTransparency = transparency
			end
		end
	end
end

-- Borda fina que acompanha o chanfro (os lados retos e as duas diagonais).
function Ui.chamferBorder(parent: GuiObject, color: Color3, cut: number, thickness: number?): Frame
	local t = thickness or 1
	local border = Ui.frame("Border", parent)
	border.Size = UDim2.fromScale(1, 1)
	border.ZIndex = 0
	line(border, UDim2.fromOffset(cut, 0), UDim2.new(1, -cut, 0, t)) -- topo
	line(border, UDim2.new(1, -t, 0, 0), UDim2.new(0, t, 1, -cut)) -- direita
	line(border, UDim2.new(0, 0, 1, -t), UDim2.new(1, -cut, 0, t)) -- baixo
	line(border, UDim2.fromOffset(0, cut), UDim2.new(0, t, 1, -cut)) -- esquerda
	local diagonal = math.sqrt(2) * cut
	for _, corner in { UDim2.fromOffset(cut / 2, cut / 2), UDim2.new(1, -cut / 2, 1, -cut / 2) } do
		local d = line(border, corner, UDim2.fromOffset(diagonal, t))
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Rotation = -45
	end
	Ui.setFill(border, color, 0)
	return border
end

-- Painel do jogo (ESTILO 2.5): fundo panel.base translúcido com cantos chanfrados e borda fina.
-- Devolve (painel, conteúdo). O fundo é feito de peças filhas do painel, então listas e espaçamentos
-- (UIListLayout, UIPadding) vão sempre no CONTEÚDO, nunca no painel. `padding` já vem aplicado.
function Ui.panel(name: string, parent: Instance?, padding: number?, cut: number?): (Frame, Frame)
	local f = Ui.frame(name, parent)
	local c = cut or Theme.Chamfer.Panel
	Ui.chamferFill(f, Theme.Color.PanelBase, Theme.Transparency.PanelBase, c)
	Ui.chamferBorder(f, Theme.Color.PanelBorder, c)
	local content = Ui.frame("Content", f)
	content.Size = UDim2.fromScale(1, 1)
	content.ZIndex = 1
	if padding then
		Ui.padding(content, padding)
	end
	return f, content
end

-- Painel que cresce com o conteúdo (AutomaticSize Y): o conteúdo define a altura.
function Ui.autoPanel(name: string, parent: Instance?, padding: number?): (Frame, Frame)
	local f, content = Ui.panel(name, parent, padding)
	f.AutomaticSize = Enum.AutomaticSize.Y
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Size = UDim2.fromScale(1, 0)
	return f, content
end

-- Cartão pequeno (ESTILO 2.5): panel.raised com canto arredondado de 6 px e borda.
function Ui.raised(name: string, parent: Instance?): Frame
	local f = Ui.frame(name, parent)
	f.BackgroundTransparency = 0
	f.BackgroundColor3 = Theme.Color.PanelRaised
	Ui.corner(f)
	Ui.stroke(f)
	return f
end

-- Chip de tecla (ESTILO 2.5): quadradinho com a letra, fundo panel.raised e borda text.secondary.
function Ui.keyChip(text: string, parent: Instance?): TextLabel
	local chip = Ui.label("Key", Theme.Font.Title, Theme.TextSize.Label, Theme.Color.TextSecondary, parent)
	chip.BackgroundColor3 = Theme.Color.PanelRaised
	chip.BackgroundTransparency = 0
	Ui.setChipText(chip, text)
	Ui.corner(chip, 4)
	Ui.stroke(chip, Theme.Color.TextSecondary)
	return chip
end

-- Texto do chip; a largura acompanha o texto (ex.: "Tab", "Enter", "LB").
function Ui.setChipText(chip: TextLabel, text: string)
	local n = utf8.len(text) or #text
	chip.Text = text
	chip.Size = UDim2.fromOffset(22 + 8 * math.max(0, n - 1), 22)
end

-- Botão provisório com o visual antigo (só para ferramentas de teste). As telas usam Widgets.
function Ui.button(name: string, text: string, isPrimary: boolean, parent: Instance?): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = true
	b.Size = UDim2.fromOffset(180, Theme.PrimaryButtonMinHeight)
	b.BackgroundColor3 = if isPrimary then Theme.Color.Accent else Theme.Color.PanelRaised
	b.FontFace = Theme.Font.Title
	b.TextSize = Theme.TextSize.PrimaryButton
	b.TextColor3 = Theme.Color.TextPrimary
	b.Text = text
	Ui.corner(b)
	if not isPrimary then
		Ui.stroke(b)
	end
	b.Parent = parent
	return b
end

-- Largura do texto em pixels (para botões e abas com largura fixa). Pode esperar (yield) na primeira
-- vez de cada fonte; se falhar, usa uma estimativa.
function Ui.textWidth(text: string, font: Font, size: number): number
	local params = Instance.new("GetTextBoundsParams")
	params.Text = text
	params.Font = font
	params.Size = size
	params.Width = math.huge
	local ok, bounds = pcall(function(): Vector2
		return TextService:GetTextBoundsAsync(params)
	end)
	if ok and typeof(bounds) == "Vector2" then
		return math.ceil(bounds.X)
	end
	return math.ceil((utf8.len(text) or #text) * size * 0.6)
end

function Ui.clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return Ui
