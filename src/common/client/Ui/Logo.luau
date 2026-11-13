--!strict
-- Logo PROVISÓRIA (ESTILO 2.4 [ABERTO]): o nome do jogo em Oswald negrito, branco, com um símbolo
-- simples roxo com brilho (carta com uma estrela). O brilho da logo é uma das exceções de neon
-- (ESTILO 2.6). Proibido: letra "V", forma de presa, vermelho.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.Ui)

local Logo = {}

-- Logo com o símbolo e o nome; `subtitle` (ex.: "LOBBY") ao lado, opcional.
function Logo.new(parent: Instance, height: number, subtitle: string?): Frame
	local root = Ui.frame("Logo", parent)
	root.Size = UDim2.fromOffset(0, height)
	root.AutomaticSize = Enum.AutomaticSize.X
	local layout = Ui.list(root, Enum.FillDirection.Horizontal, 10)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center

	-- Símbolo: carta inclinada roxa com brilho e uma estrela
	local symbolBox = Ui.frame("Symbol", root)
	symbolBox.Size = UDim2.fromOffset(height, height)
	local card = Ui.frame("Card", symbolBox)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(0.62, 0.86)
	card.Rotation = -12
	card.BackgroundTransparency = 0
	card.BackgroundColor3 = Theme.Color.Accent
	Ui.corner(card, 5)
	local glow = Ui.stroke(card, Theme.Color.AccentGlow, 3)
	glow.Transparency = 0.2
	local arrow = Ui.label("Arrow", Theme.Font.Title, math.floor(height * 0.5), Theme.Color.TextPrimary, card)
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.Text = Strings.Logo.Symbol

	local name = Ui.label("Name", Theme.Font.Title, math.floor(height * 0.55), Theme.Color.TextPrimary, root)
	name.AutomaticSize = Enum.AutomaticSize.X
	name.Size = UDim2.fromOffset(0, height)
	name.Text = Strings.GameName
	name.LayoutOrder = 2
	Ui.outlineText(name)

	if subtitle then
		local divider = Ui.frame("Divider", root)
		divider.Size = UDim2.fromOffset(2, math.floor(height * 0.6))
		divider.BackgroundTransparency = 0
		divider.BackgroundColor3 = Theme.Color.TextSecondary
		divider.LayoutOrder = 3
		local sub = Ui.label("Subtitle", Theme.Font.Title, math.floor(height * 0.55), Theme.Color.TextPrimary, root)
		sub.AutomaticSize = Enum.AutomaticSize.X
		sub.Size = UDim2.fromOffset(0, height)
		sub.Text = subtitle
		sub.LayoutOrder = 4
		Ui.outlineText(sub)
	end
	return root
end

return Logo
