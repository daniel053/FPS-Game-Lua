--!strict
-- Arte das cartas (FASES F10, ESTILO T1): um desenho próprio de cada carta, feito com formas da
-- interface (círculos, barras e losangos), na cor da carta e num tom mais escuro dela. Sem imagem de
-- fora, sem brilho (o brilho é só da moldura de raridade). Usado na tela de Cartas, no HUD (cartas e
-- painel B), no modal de preparação e no tutorial.
--
--   * Nuvem: nuvem de desenho animado (bolas e base reta) com a bolinha arremessada em arco.
--   * Impulso: duas setas para cima saindo de uma linha de chão, com riscos de velocidade.
--   * Tremor: linha de chão com uma rachadura em zigue-zague e pedras saltando.
--   * Renascer: seta circular de volta em volta de um losango (a marca).
--
-- `CardArt.draw(parent, cardId, color)` preenche o `parent` inteiro (escala, serve para qualquer
-- tamanho) e devolve a moldura do desenho.

local Theme = require(script.Parent.Parent.Config.Theme)

local CardArt = {}

type Draw = (canvas: Frame, main: Color3, dark: Color3, light: Color3) -> ()

local function piece(canvas: Frame, name: string, color: Color3, cx: number, cy: number, w: number, h: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(cx, cy)
	f.Size = UDim2.fromScale(w, h)
	f.Parent = canvas
	return f
end

-- Círculo (o canvas é quadrado, então w = h dá um círculo).
local function circle(canvas: Frame, color: Color3, cx: number, cy: number, d: number, z: number?): Frame
	local f = piece(canvas, "Circulo", color, cx, cy, d, d)
	f.ZIndex = z or 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	return f
end

-- Barra girada (`angle` em graus), com cantos arredondados.
local function bar(
	canvas: Frame,
	color: Color3,
	cx: number,
	cy: number,
	length: number,
	thick: number,
	angle: number,
	z: number?
): Frame
	local f = piece(canvas, "Barra", color, cx, cy, length, thick)
	f.Rotation = angle
	f.ZIndex = z or 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	return f
end

local function diamond(canvas: Frame, color: Color3, cx: number, cy: number, size: number, z: number?): Frame
	local f = piece(canvas, "Losango", color, cx, cy, size, size)
	f.Rotation = 45
	f.ZIndex = z or 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.15, 0)
	corner.Parent = f
	return f
end

-- Seta: duas barras em "^" com a ponta em (cx, cy), apontando para `angle` (0 = para cima).
local function chevron(
	canvas: Frame,
	color: Color3,
	cx: number,
	cy: number,
	size: number,
	thick: number,
	angle: number,
	z: number?
)
	local rad = math.rad(angle)
	for _, side in { -1, 1 } do
		local a = rad + side * math.rad(135)
		-- meio da barra: metade do comprimento para trás da ponta, na direção da asa
		local dx, dy = math.sin(a), -math.cos(a) -- na tela (Y para baixo)
		bar(canvas, color, cx + dx * size / 2, cy + dy * size / 2, size, thick, math.deg(math.atan2(dy, dx)), z)
	end
end

local ART: { [string]: Draw } = {
	card_nuvem = function(canvas, main, dark, light)
		-- arco da bolinha (de baixo à esquerda até a nuvem)
		for i, p in { { 0.12, 0.78 }, { 0.2, 0.6 }, { 0.3, 0.47 } } do
			circle(canvas, light, p[1], p[2], 0.05 + i * 0.012)
		end
		-- nuvem: base reta + 4 bolas, sombra embaixo
		circle(canvas, dark, 0.47, 0.66, 0.26)
		circle(canvas, dark, 0.7, 0.66, 0.24)
		local base = piece(canvas, "Base", main, 0.6, 0.62, 0.56, 0.16)
		base.ZIndex = 2
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = base
		circle(canvas, main, 0.42, 0.52, 0.26, 2)
		circle(canvas, main, 0.6, 0.42, 0.34, 2)
		circle(canvas, main, 0.78, 0.53, 0.24, 2)
		circle(canvas, light, 0.55, 0.36, 0.1, 3) -- brilho fosco em cima
	end,

	card_impulso = function(canvas, main, dark, light)
		bar(canvas, dark, 0.5, 0.84, 0.7, 0.06, 0) -- chão
		bar(canvas, dark, 0.5, 0.78, 0.36, 0.05, 0)
		chevron(canvas, main, 0.5, 0.3, 0.3, 0.11, 0, 2)
		chevron(canvas, main, 0.5, 0.52, 0.3, 0.11, 0, 2)
		-- riscos de velocidade dos lados
		for _, p in { { 0.2, 0.42, 0.18 }, { 0.8, 0.42, 0.18 }, { 0.26, 0.64, 0.12 }, { 0.74, 0.64, 0.12 } } do
			bar(canvas, light, p[1], p[2], 0.05, p[3], 0)
		end
	end,

	card_tremor = function(canvas, main, _dark, light)
		bar(canvas, light, 0.5, 0.74, 0.86, 0.05, 0) -- chão
		-- rachadura em zigue-zague, da esquerda para a direita
		local zig = { { 0.12, 0.7 }, { 0.3, 0.6 }, { 0.44, 0.76 }, { 0.6, 0.58 }, { 0.74, 0.74 }, { 0.9, 0.62 } }
		for i = 1, #zig - 1 do
			local a, b = zig[i], zig[i + 1]
			local dx, dy = b[1] - a[1], b[2] - a[2]
			local length = math.sqrt(dx * dx + dy * dy) + 0.04
			bar(canvas, main, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, length, 0.11, math.deg(math.atan2(dy, dx)), 2)
		end
		-- pedras saltando
		diamond(canvas, main, 0.3, 0.38, 0.16, 2)
		diamond(canvas, light, 0.56, 0.26, 0.12, 2)
		diamond(canvas, main, 0.76, 0.4, 0.14, 2)
		for _, p in { { 0.3, 0.52 }, { 0.76, 0.53 } } do
			bar(canvas, light, p[1], p[2], 0.04, 0.08, 0)
		end
	end,

	card_renascer = function(canvas, main, dark, light)
		-- seta circular: anel aberto feito de barras curtas (escala com a carta, ao contrário de um
		-- UIStroke, que tem espessura em pixels), com a ponta da seta
		for k = 0, 10 do
			local a = math.rad(k * 30 + 40)
			local r = 0.3
			bar(canvas, main, 0.5 + math.sin(a) * r, 0.52 - math.cos(a) * r, 0.18, 0.09, k * 30 + 40, 2)
		end
		-- ponta da seta no fim do anel (em cima), apontando no sentido da volta (horário)
		local tip = math.rad(14)
		chevron(canvas, main, 0.5 + math.sin(tip) * 0.3, 0.52 - math.cos(tip) * 0.3, 0.17, 0.09, 14 + 90, 3)
		-- a marca no meio
		diamond(canvas, dark, 0.5, 0.52, 0.22, 2)
		diamond(canvas, light, 0.5, 0.52, 0.11, 3)
	end,
}

-- Desenha a carta `cardId` dentro de `parent` (ocupa tudo, quadrado e centralizado). `color` = a cor
-- da carta (ou a de carta travada). Carta sem desenho: nada (devolve nil).
-- `transparency` (opcional): o desenho mais apagado (HUD, atrás do número de cargas).
function CardArt.draw(parent: GuiObject, cardId: string, color: Color3?, transparency: number?): Frame?
	local draw = ART[cardId]
	if draw == nil then
		return nil
	end
	local main = color or Theme.Cards[cardId] or Theme.Color.Accent
	local canvas = Instance.new("Frame")
	canvas.Name = "CardArt"
	canvas.BackgroundTransparency = 1
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.ZIndex = parent.ZIndex
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = canvas
	draw(canvas, main, main:Lerp(Color3.new(0, 0, 0), 0.35), main:Lerp(Color3.new(1, 1, 1), 0.45))
	-- as peças herdam a camada do pai, para ficar por cima do fundo da carta
	for _, child in canvas:GetChildren() do
		if child:IsA("GuiObject") then
			child.ZIndex += parent.ZIndex
			if transparency then
				child.BackgroundTransparency = math.max(child.BackgroundTransparency, transparency)
			end
		end
	end
	canvas.Parent = parent
	return canvas
end

function CardArt.has(cardId: string): boolean
	return ART[cardId] ~= nil
end

return CardArt
