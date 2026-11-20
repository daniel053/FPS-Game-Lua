--!strict
-- Arte de fundo das cartas (pedido do dono do projeto depois da F10: "a carta precisa dar vontade de
-- ter"). Fica atrás do desenho da carta (CardArt) e é feita só com formas da interface, na cor da
-- carta, sem imagem de fora:
--   * céu: a cor da carta em cima escurecendo para o painel embaixo;
--   * raios saindo de trás do desenho (feixes que somem nas pontas) e um halo de 3 anéis;
--   * um padrão próprio de cada carta (Nuvem: nuvenzinhas; Impulso: riscos de velocidade subindo;
--     Tremor: cacos de pedra; Renascer: losangos subindo) e pontinhos de "poeira";
--   * sombra embaixo (o nome fica legível) e um filete claro no topo;
--   * brilho de vitrine: uma faixa clara que atravessa a carta UMA vez quando ela é escolhida
--     (sem animação contínua, ESTILO 2.7). Só a Celestial gira os raios devagar.
-- Os raios e o halo são tons claros da própria carta, sem neon (ESTILO 2.6: neon só na moldura).
--
-- `CardBackdrop.draw(parent, cardId, rarity?)` cria um CanvasGroup que preenche o `parent` (recorta os
-- raios girados e respeita o canto arredondado) e devolve { root, shine }.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.Config.Theme)

local B = Theme.CardBackdrop

export type Backdrop = {
	root: CanvasGroup,
	shine: () -> (),
}

local CardBackdrop = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local function frame(parent: Instance, name: string, color: Color3, transparency: number, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function round(f: GuiObject, scale: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale or 0.5, 0)
	c.Parent = f
end

-- Peça centrada em (x, y), tamanho em escala da carta.
local function at(f: GuiObject, x: number, y: number, w: number, h: number, rotation: number?)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.Rotation = rotation or 0
end

-- Quadrado de verdade (lado em escala da LARGURA da carta), centrado em (x, y).
local function square(f: GuiObject, x: number, y: number, side: number, rotation: number?)
	at(f, x, y, side, side, rotation)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.DominantAxis = Enum.DominantAxis.Width
	ratio.Parent = f
end

local function gradient(parent: Instance, rotation: number, color: ColorSequence?, transparency: NumberSequence?)
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	if color then
		g.Color = color
	end
	if transparency then
		g.Transparency = transparency
	end
	g.Parent = parent
	return g
end

-- Gerador fixo por carta: o padrão é sempre o mesmo para a mesma carta.
local function seeded(cardId: string): Random
	local seed = 0
	for i = 1, #cardId do
		seed = (seed * 31 + string.byte(cardId, i)) % 2147483647
	end
	return Random.new(seed)
end

-- Padrões de cada carta --------------------------------------------------------------------------

type Pattern = (layer: Frame, light: Color3, deep: Color3, rng: Random) -> ()

local PATTERNS: { [string]: Pattern } = {
	-- Nuvenzinhas (3 bolas + base) espalhadas no céu
	card_nuvem = function(layer, light, _deep, rng)
		for _, spot in { { 0.18, 0.16, 0.34 }, { 0.84, 0.26, 0.28 }, { 0.16, 0.7, 0.26 }, { 0.86, 0.64, 0.3 } } do
			local x, y, w = spot[1], spot[2], spot[3]
			local t = B.PatternTransparency + rng:NextNumber(-0.05, 0.05)
			local base = frame(layer, "Nuvem", light, t, 2)
			at(base, x, y + w * 0.06, w, w * 0.22)
			round(base)
			for i, dx in { -0.28, 0, 0.26 } do
				local puff = frame(layer, "Bola", light, t, 2)
				square(puff, x + dx * w, y - (if i == 2 then 0.05 else 0.02) * w, w * (if i == 2 then 0.5 else 0.36))
				round(puff)
			end
		end
	end,
	-- Riscos de velocidade subindo (de baixo para cima, levemente inclinados)
	card_impulso = function(layer, light, _deep, rng)
		for i = 1, 9 do
			local x = 0.06 + (i - 1) * 0.11 + rng:NextNumber(-0.02, 0.02)
			local length = rng:NextNumber(0.18, 0.42)
			local streak = frame(layer, "Risco", light, 0, 2)
			at(streak, x, rng:NextNumber(0.25, 0.85), 0.018, length, 8)
			round(streak)
			gradient(
				streak,
				90,
				nil,
				NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.6, B.PatternTransparency),
					NumberSequenceKeypoint.new(1, 1),
				})
			)
		end
	end,
	-- Cacos de pedra (quadrados girados) e uma rachadura no pé da carta
	card_tremor = function(layer, light, deep, rng)
		for _ = 1, 10 do
			local shard = frame(layer, "Caco", if rng:NextNumber() < 0.5 then light else deep, 0, 2)
			shard.BackgroundTransparency = B.PatternTransparency + rng:NextNumber(-0.08, 0.08)
			local edge = rng:NextNumber() < 0.5
			local x = if edge then rng:NextNumber(0.05, 0.25) else rng:NextNumber(0.75, 0.95)
			square(shard, x, rng:NextNumber(0.1, 0.8), rng:NextNumber(0.04, 0.1), rng:NextNumber(0, 90))
		end
		local x = 0.08
		for i = 1, 6 do
			local nx = x + 0.15
			local y1 = 0.86 + (if i % 2 == 0 then 0.03 else -0.02)
			local crack = frame(layer, "Rachadura", deep, 0.25, 2)
			at(crack, (x + nx) / 2, y1, 0.17, 0.012, if i % 2 == 0 then -14 else 14)
			x = nx
		end
	end,
	-- Losangos subindo (renascer) e um anel fino
	card_renascer = function(layer, light, _deep, rng)
		for _ = 1, 9 do
			local side = rng:NextNumber(0.035, 0.08)
			local d = frame(layer, "Losango", light, B.PatternTransparency + rng:NextNumber(-0.05, 0.08), 2)
			local edge = rng:NextNumber() < 0.5
			local x = if edge then rng:NextNumber(0.06, 0.24) else rng:NextNumber(0.76, 0.94)
			square(d, x, rng:NextNumber(0.08, 0.8), side, 45)
		end
		local ring = frame(layer, "Anel", light, 1, 2)
		square(ring, 0.5, B.ArtY, 1.1)
		round(ring)
		local stroke = Instance.new("UIStroke")
		stroke.Color = light
		stroke.Thickness = 2
		stroke.Transparency = B.PatternTransparency
		stroke.Parent = ring
	end,
}

-- Fundo ------------------------------------------------------------------------------------------

function CardBackdrop.draw(parent: GuiObject, cardId: string, rarity: string?): Backdrop
	local main = Theme.Cards[cardId] or Theme.Color.Accent
	local light = main:Lerp(WHITE, B.LightMix)
	local deep = main:Lerp(Theme.Color.PanelBase, B.DeepMix)
	local rng = seeded(cardId)

	local root = Instance.new("CanvasGroup")
	root.Name = "Backdrop"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 1
	root.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, B.CornerRadius)
	corner.Parent = root
	-- Céu: cor da carta em cima, painel escuro embaixo. Fica numa peça própria: um UIGradient direto no
	-- CanvasGroup tingiria o grupo inteiro (raios e halo sumiriam no fundo).
	local sky = frame(root, "Ceu", WHITE, 0, 0)
	sky.Size = UDim2.fromScale(1, 1)
	gradient(
		sky,
		90,
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, main:Lerp(Theme.Color.PanelBase, B.SkyTopMix)),
			ColorSequenceKeypoint.new(0.55, deep),
			ColorSequenceKeypoint.new(1, Theme.Color.PanelBase:Lerp(BLACK, 0.35)),
		})
	)

	-- Raios atrás do desenho
	local rays = frame(root, "Raios", WHITE, 1, 1)
	square(rays, 0.5, B.ArtY, 2.2)
	for i = 1, B.RayCount do
		local ray = frame(rays, "Raio", light, 0, 1)
		at(ray, 0.5, 0.5, B.RayWidth, 1, (i - 1) * 180 / B.RayCount)
		gradient(
			ray,
			90,
			nil,
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, B.RayTransparency + 0.08),
				NumberSequenceKeypoint.new(0.5, B.RayTransparency),
				NumberSequenceKeypoint.new(0.7, B.RayTransparency + 0.08),
				NumberSequenceKeypoint.new(1, 1),
			})
		)
	end
	if rarity and Theme.Rarity[rarity] and Theme.Rarity[rarity].glow == "neon" then
		-- Celestial: os raios giram devagar (a única carta com animação contínua, ESTILO 2.7)
		local info = TweenInfo.new(B.CelestialSpinSeconds, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1)
		TweenService:Create(rays, info, { Rotation = 360 }):Play()
	end

	-- Halo: 3 anéis do mais largo (mais fraco) ao menor
	for i, size in B.HaloSizes do
		local halo = frame(root, "Halo", light, B.HaloTransparency[i], 1)
		square(halo, 0.5, B.ArtY, size)
		round(halo)
	end

	-- Padrão da carta e poeira
	local pattern = PATTERNS[cardId]
	local layer = frame(root, "Padrao", WHITE, 1, 2)
	layer.Size = UDim2.fromScale(1, 1)
	if pattern then
		pattern(layer, light, deep, rng)
	end
	for _ = 1, B.DustCount do
		local dust = frame(layer, "Poeira", WHITE, rng:NextNumber(0.55, 0.85), 2)
		square(dust, rng:NextNumber(0.05, 0.95), rng:NextNumber(0.05, 0.75), rng:NextNumber(0.01, 0.022))
		round(dust)
	end

	-- Sombra embaixo (nome legível) e filete claro no topo
	local shadow = frame(root, "Sombra", BLACK, 0, 3)
	shadow.AnchorPoint = Vector2.new(0, 1)
	shadow.Position = UDim2.fromScale(0, 1)
	shadow.Size = UDim2.fromScale(1, 0.42)
	gradient(
		shadow,
		90,
		nil,
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, B.ShadowTransparency),
		})
	)
	local rim = frame(root, "Filete", WHITE, 0.6, 3)
	rim.Size = UDim2.new(1, 0, 0, 2)
	gradient(
		rim,
		0,
		nil,
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
	)

	-- Brilho de vitrine (uma passada quando a carta é escolhida)
	local band = frame(root, "Brilho", WHITE, 0, 6)
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Size = UDim2.fromScale(0.35, 1.8)
	band.Rotation = 22
	band.Position = UDim2.fromScale(-0.4, 0.5)
	band.Visible = false
	gradient(
		band,
		0,
		nil,
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, B.ShineTransparency),
			NumberSequenceKeypoint.new(1, 1),
		})
	)
	local running: Tween? = nil
	local function shine()
		if running then
			running:Cancel()
		end
		band.Position = UDim2.fromScale(-0.4, 0.5)
		band.Visible = true
		local tween = TweenService:Create(
			band,
			TweenInfo.new(B.ShineSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Position = UDim2.fromScale(1.4, 0.5) }
		)
		tween.Completed:Once(function()
			band.Visible = false
		end)
		running = tween
		tween:Play()
	end

	return { root = root, shine = shine }
end

return CardBackdrop
