--!strict
-- Peças simples de interface para as telas PROVISÓRIAS da partida (F3): HUD da partida, modal de
-- preparação e telas de eliminação/fim. Tudo com Theme e tamanhos mínimos do ESTILO 2.5 e 3.
-- Os componentes definitivos (botões, abas, cartões, modal) são da F7, que substituem estes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local MatchUi = {}

function MatchUi.corner(parent: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.SmallCardCornerRadius)
	corner.Parent = parent
end

function MatchUi.stroke(parent: GuiObject, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.Color.PanelBorder
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function MatchUi.screen(name: string, order: number, insets: Enum.ScreenInsets): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = insets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order
	return gui
end

function MatchUi.frame(name: string, parent: Instance?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

function MatchUi.panel(name: string, parent: Instance?): Frame
	local f = MatchUi.frame(name, parent)
	f.BackgroundColor3 = Theme.Color.PanelBase
	f.BackgroundTransparency = Theme.Transparency.PanelBase
	MatchUi.corner(f)
	MatchUi.stroke(f)
	return f
end

function MatchUi.label(name: string, font: Font, size: number, color: Color3, parent: Instance?): TextLabel
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

-- Contorno escuro no texto solto sobre o jogo (legível em qualquer fundo).
function MatchUi.outlineText(l: TextLabel)
	l.TextStrokeColor3 = Theme.Color.Overlay
	l.TextStrokeTransparency = 0.3
end

function MatchUi.button(name: string, text: string, isPrimary: boolean, parent: Instance?): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = true
	b.Size = UDim2.fromOffset(180, Theme.PrimaryButtonMinHeight)
	b.BackgroundColor3 = if isPrimary then Theme.Color.Accent else Theme.Color.PanelRaised
	b.FontFace = Theme.Font.Title
	b.TextSize = Theme.TextSize.PrimaryButton
	b.TextColor3 = Theme.Color.TextPrimary
	b.Text = text
	MatchUi.corner(b)
	if not isPrimary then
		MatchUi.stroke(b)
	end
	b.Parent = parent
	return b
end

-- Chip de tecla (ESTILO 2.5), só no PC.
function MatchUi.keyChip(text: string, parent: Instance?): TextLabel
	local chip = MatchUi.label("Key", Theme.Font.Title, Theme.TextSize.Label, Theme.Color.TextSecondary, parent)
	chip.Size = UDim2.fromOffset(22, 22)
	chip.BackgroundColor3 = Theme.Color.PanelRaised
	chip.BackgroundTransparency = 0
	chip.Text = text
	MatchUi.corner(chip, 4)
	MatchUi.stroke(chip, Theme.Color.TextSecondary)
	return chip
end

function MatchUi.list(parent: Instance, direction: Enum.FillDirection, padding: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.Padding = UDim.new(0, padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

function MatchUi.padding(parent: Instance, all: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, all)
	p.PaddingBottom = UDim.new(0, all)
	p.PaddingLeft = UDim.new(0, all)
	p.PaddingRight = UDim.new(0, all)
	p.Parent = parent
end

return MatchUi
