--!strict
-- Kit da Praça (KIT-MODULAR seção 4): um componente por função, cada um devolve um Model.
--
-- Todo componente recebe `origin`: o quadro dele no chão (feito com `Build.pivot`), com o Y local
-- para cima. As peças que colidem são caixas simples; o acabamento (juntas, molduras, telhas) é
-- `Build.Detail`: não colide, não bloqueia tiro e sai no máximo ~0,15 stud da peça que colide.
-- Cores só de `Theme.Maps.Praca`; material liso, sem neon, sem luz e sem texto.
--
-- `scenery = true` (cenário de fora da área de duelo): nenhuma peça do componente colide nem
-- bloqueia tiro, e ele fica fora do minimapa.

local Build = require(script.Parent.Parent.Build)
local Theme = require(script.Parent.Parent.Parent.Config.Theme)

local P = Theme.Maps.Praca
local DETAIL = Build.Detail
local SIGNS = { -1, 1 }

local v2 = Vector2.new
local v3 = Vector3.new

local Kit = {}

export type PassarelaSpec = {
	FlatLength: number, -- trecho plano
	Width: number,
	Height: number,
	RampLength: number, -- cada rampa (uma em cada ponta)
	GuardHeight: number, -- mureta em cima, do lado -Z local
}

export type SobradoOptions = {
	door: Color3?, -- cor da porta (padrão: azul)
	flip: boolean?, -- espelha a fachada (porta do outro lado)
	balcony: boolean?, -- sacada na janela de cima
	scenery: boolean?,
}

export type SceneryOptions = {
	scenery: boolean?,
}

-- Peça de cenário: não colide, não bloqueia tiro e fica fora do minimapa (mas faz sombra).
local function scenic(part: BasePart, scenery: boolean?)
	if scenery then
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part:SetAttribute(Build.DetailAttribute, true)
	end
end

local function scenicAll(parts: { Part }, scenery: boolean?)
	for _, part in parts do
		scenic(part, scenery)
	end
end

-- Muro De Tijolo -------------------------------------------------------------------------------
-- comprimento × espessura × 4 (kit: 12 × 1 × 4; planta: 20 × 2 × 4). Comprimento no X local.
-- Tijolo terracota com juntas em linhas (fiadas de 0,6; tijolos de 2, em amarração) e topo de pedra.

local MURO = { Height = 4, Cap = 0.5, Course = 0.6, Brick = 2, Joint = 0.1, Out = 0.05 }

function Kit.MuroDeTijolo(parent: Instance, origin: CFrame, length: number, thickness: number?): Model
	local t = thickness or 1
	local h = MURO.Height
	local model = Build.model("MuroDeTijolo", parent)
	local body = Build.block("Corpo", v3(length, h, t), origin * CFrame.new(0, h / 2, 0), P.Tijolo, model)
	model.PrimaryPart = body
	-- Topo de pedra: 0,15 para cada lado e 0,1 para cima
	Build.block(
		"Topo",
		v3(length + 0.3, MURO.Cap, t + 0.3),
		origin * CFrame.new(0, h + 0.1 - MURO.Cap / 2, 0),
		P.Pedra,
		model,
		DETAIL
	)
	-- Juntas: placas finas que atravessam o muro e aparecem 0,05 para fora nas duas faces
	local through = t + 2 * MURO.Out
	local brickTop = h + 0.1 - MURO.Cap -- até onde o tijolo aparece
	local courses = math.floor(brickTop / MURO.Course + 0.5)
	for c = 0, courses - 1 do
		if c > 0 then
			Build.block(
				"Junta",
				v3(length + 2 * MURO.Out, MURO.Joint, through),
				origin * CFrame.new(0, c * MURO.Course, 0),
				P.TijoloEscuro,
				model,
				DETAIL
			)
		end
		local x = if c % 2 == 0 then MURO.Brick else MURO.Brick / 2
		while x < length - 0.3 do
			Build.block(
				"Junta",
				v3(MURO.Joint, MURO.Course, through),
				origin * CFrame.new(x - length / 2, (c + 0.5) * MURO.Course, 0),
				P.TijoloEscuro,
				model,
				DETAIL
			)
			x += MURO.Brick
		end
	end
	return model
end

-- Caixa De Madeira -----------------------------------------------------------------------------
-- 6 × 6 × 6 (cobertura cheia) ou 3 × 3 × 3 (meia altura). Moldura e travessa diagonal em madeira
-- mais escura nas 4 faces e no topo (o topo é o que se vê do mirante); linhas de tábua.

function Kit.CaixaDeMadeira(parent: Instance, origin: CFrame, size: number?): Model
	local s = size or 6
	local bar = if s >= 5 then 0.8 else 0.5 -- largura da moldura
	local out = 0.1 -- quanto a moldura sai da caixa
	local dark = P.MadeiraEscura
	local model = Build.model("CaixaDeMadeira", parent)
	local body = Build.block("Corpo", Vector3.one * s, origin * CFrame.new(0, s / 2, 0), P.Madeira, model)
	model.PrimaryPart = body

	-- Moldura: 4 cantos em pé e 8 barras deitadas (cada barra serve a duas faces)
	local edge = s / 2 + out - bar / 2
	local full = s + 2 * out
	for _, sx in SIGNS do
		for _, sz in SIGNS do
			Build.block(
				"Moldura",
				v3(bar, s + out, bar),
				origin * CFrame.new(sx * edge, (s + out) / 2, sz * edge),
				dark,
				model,
				DETAIL
			)
		end
	end
	for _, y in { bar / 2, s + out - bar / 2 } do
		for _, sign in SIGNS do
			Build.block("Moldura", v3(full, bar, bar), origin * CFrame.new(0, y, sign * edge), dark, model, DETAIL)
			Build.block("Moldura", v3(bar, bar, full), origin * CFrame.new(sign * edge, y, 0), dark, model, DETAIL)
		end
	end

	-- Travessa diagonal: sai 0,08 (menos que a moldura, então as pontas somem embaixo dela)
	local opening = s - 2 * (bar - out)
	local braceLength = opening * math.sqrt(2) + 0.4
	local braceWidth = bar * 0.85
	for k = 0, 3 do
		Build.block(
			"Travessa",
			v3(braceLength, braceWidth, 0.16),
			origin
				* CFrame.Angles(0, k * math.pi / 2, 0)
				* CFrame.new(0, s / 2, s / 2)
				* CFrame.Angles(0, 0, math.pi / 4),
			dark,
			model,
			DETAIL
		)
	end
	Build.block(
		"Travessa",
		v3(braceLength, 0.16, braceWidth),
		origin * CFrame.new(0, s, 0) * CFrame.Angles(0, math.pi / 4, 0),
		dark,
		model,
		DETAIL
	)

	-- Linhas de tábua: 2 placas que atravessam a caixa (aparecem nas 4 faces) e 2 linhas no topo
	for i = 1, 2 do
		Build.block("Tabua", v3(s + 0.1, 0.1, s + 0.1), origin * CFrame.new(0, i * s / 3, 0), dark, model, DETAIL)
	end
	for _, sign in SIGNS do
		Build.block("Tabua", v3(0.1, 0.1, opening), origin * CFrame.new(sign * s / 6, s, 0), dark, model, DETAIL)
	end
	return model
end

-- Passarela ------------------------------------------------------------------------------------
-- Componente novo do kit (planta da F10): piso de pedra elevado, guarda-corpo de um lado e rampa
-- nas duas pontas. `origin` = meio do trecho plano, no chão; comprimento no X local; o guarda-corpo
-- fica do lado -Z local (o lado do vazio) e o lado +Z é aberto.
-- Colidem: o piso (caixa), as 2 rampas (cunhas) e o guarda-corpo (caixa).

local STONE = { Block = 4, Courses = 4, Joint = 0.15, Out = 0.05 }

function Kit.Passarela(parent: Instance, origin: CFrame, spec: PassarelaSpec): Model
	local length, width, height = spec.FlatLength, spec.Width, spec.Height
	local ramp, guard = spec.RampLength, spec.GuardHeight
	local dark = P.PedraEscura
	local model = Build.model("Passarela", parent)

	local body = Build.block("Piso", v3(length, height, width), origin * CFrame.new(0, height / 2, 0), P.Pedra, model)
	model.PrimaryPart = body
	for _, sign in SIGNS do
		local foot = v2(sign * (length / 2 + ramp), 0)
		local head = v2(sign * length / 2, 0)
		Build.ramp("Rampa", origin, foot, head, 0, height, width, P.Pedra, model)
	end

	-- Guarda-corpo: mureta de reboco com capa de telha (a mesma cara da mureta da borda)
	local guardZ = -width / 2 + 0.5
	Build.block(
		"GuardaCorpo",
		v3(length + 1, guard, 1),
		origin * CFrame.new(0, height + guard / 2, guardZ),
		P.Reboco,
		model
	)
	Build.block(
		"Capa",
		v3(length + 1.3, 0.5, 1.3),
		origin * CFrame.new(0, height + guard - 0.15, guardZ),
		P.Telha,
		model,
		DETAIL
	)
	Build.block(
		"Rodape",
		v3(length + 1, 0.4, 0.2),
		origin * CFrame.new(0, height + 0.2, guardZ + 0.5),
		dark,
		model,
		DETAIL
	)

	-- Blocos de pedra nas laterais: placas que atravessam o piso e saem 0,05 dos dois lados
	local course = height / STONE.Courses
	local through = width + 2 * STONE.Out
	for c = 0, STONE.Courses - 1 do
		if c > 0 then
			Build.block(
				"Junta",
				v3(length + 2 * STONE.Out, STONE.Joint, through),
				origin * CFrame.new(0, c * course, 0),
				dark,
				model,
				DETAIL
			)
		end
		local x = if c % 2 == 0 then STONE.Block else STONE.Block / 2
		while x < length - 0.5 do
			Build.block(
				"Junta",
				v3(STONE.Joint, course, through),
				origin * CFrame.new(x - length / 2, (c + 0.5) * course, 0),
				dark,
				model,
				DETAIL
			)
			x += STONE.Block
		end
	end

	-- Em cima: friso na beirada aberta e juntas das lajes (0,1 acima do piso)
	local rimZ = width / 2 - 0.45 -- 0,15 para dentro da beirada, para não dividir face com a lateral
	Build.block("Friso", v3(length, 0.1, 0.6), origin * CFrame.new(0, height + 0.05, rimZ), dark, model, DETAIL)
	local slabFrom, slabTo = -width / 2 + 1, rimZ - 0.3 -- do guarda-corpo ao friso
	for k = 1, math.floor(length / STONE.Block) - 1 do
		Build.block(
			"JuntaDoPiso",
			v3(0.3, 0.1, slabTo - slabFrom),
			origin * CFrame.new(k * STONE.Block - length / 2, height + 0.05, (slabFrom + slabTo) / 2),
			dark,
			model,
			DETAIL
		)
	end

	-- Rampas: friso na beirada aberta e 3 frisos atravessados (de cima, mostram que ali é rampa).
	-- Ficam deitados na inclinação, metade para dentro da cunha (saem 0,06).
	local slope = math.atan2(height, ramp)
	local slopeLength = math.sqrt(ramp * ramp + height * height)
	local crossFrom, crossTo = -width / 2 + 0.8, rimZ - 0.3
	for _, sign in SIGNS do
		local tilt = CFrame.Angles(0, 0, -sign * slope)
		Build.block(
			"FrisoDaRampa",
			v3(slopeLength - 0.2, 0.12, 0.6),
			origin * CFrame.new(sign * (length / 2 + ramp / 2), height / 2, rimZ) * tilt,
			dark,
			model,
			DETAIL
		)
		for i = 1, 3 do
			local f = i / 4 -- 0 = pé da rampa, 1 = topo
			Build.block(
				"FrisoDaRampa",
				v3(0.4, 0.12, crossTo - crossFrom),
				origin * CFrame.new(sign * (length / 2 + ramp * (1 - f)), height * f, (crossFrom + crossTo) / 2) * tilt,
				dark,
				model,
				DETAIL
			)
		end
	end
	return model
end

-- Canteiro -------------------------------------------------------------------------------------
-- Triângulo de grama rente ao chão (não protege de tiro). `origin` = meio da base reta; a base vai
-- de -left a +right no X local e a ponta fica em -Z local, a `depth` da base.
-- Colide só a grama (2 cunhas deitadas, `height` de altura); meio-fio e moitas são acabamento.

function Kit.Canteiro(
	parent: Instance,
	origin: CFrame,
	left: number,
	right: number,
	depth: number,
	height: number
): Model
	local model = Build.model("Canteiro", parent)
	local mid, tip = v2(0, 0), v2(0, -depth)
	local corners = { v2(-left, 0), v2(right, 0) }
	for i, corner in corners do
		local grass = Build.floorTriangle("Grama", origin, mid, corner, tip, height, P.Grama, model, height)
		if i == 1 then
			model.PrimaryPart = grass
		end
	end
	-- Meio-fio de pedra nas 3 beiradas (0,1 acima da grama)
	local curb = height + 0.1
	Build.wall("MeioFio", origin, corners[1], corners[2], curb, 0.6, P.Pedra, model, 0, DETAIL)
	for _, corner in corners do
		Build.wall("MeioFio", origin, corner, tip, curb, 0.6, P.Pedra, model, 0, DETAIL)
	end
	-- Moitas baixas com uma flor (posição em fração da base e da profundidade; sempre dentro)
	local tufts = {
		{ u = -0.45, w = 0.2, yaw = 20, flower = P.ToldoCreme },
		{ u = 0.4, w = 0.18, yaw = 50, flower = P.Porta },
		{ u = 0.02, w = 0.52, yaw = 35, flower = P.ToldoCreme },
		{ u = 0.12, w = 0.14, yaw = 70, flower = P.Porta },
	}
	for _, tuft in tufts do
		local x = tuft.u * (if tuft.u < 0 then left else right)
		local at = origin * CFrame.new(x, height, -tuft.w * depth) * CFrame.Angles(0, math.rad(tuft.yaw), 0)
		Build.block("Moita", v3(1.6, 0.6, 1.6), at * CFrame.new(0, 0.3, 0), P.Folhas, model, DETAIL)
		Build.block("Flor", v3(0.5, 0.4, 0.5), at * CFrame.new(0.2, 0.8, -0.1), tuft.flower, model, DETAIL)
	end
	return model
end

-- Sobrado --------------------------------------------------------------------------------------
-- 10 × 8 × 13,5. Reboco creme, telhado de duas águas em telha (cumeeira no X local), porta e
-- janelas chapadas. A fachada (porta) fica do lado +Z local.

local SOBRADO = { Width = 10, Depth = 8, WallHeight = 9, RoofHeight = 4.5, Eave = 0.5 }

function Kit.Sobrado(parent: Instance, origin: CFrame, options: SobradoOptions?): Model
	local opts: SobradoOptions = options or {}
	local w, d, wallH, roofH = SOBRADO.Width, SOBRADO.Depth, SOBRADO.WallHeight, SOBRADO.RoofHeight
	local m = if opts.flip then -1 else 1
	local model = Build.model("Sobrado", parent)

	local body = Build.block("Paredes", v3(w, wallH, d), origin * CFrame.new(0, wallH / 2, 0), P.Reboco, model)
	scenic(body, opts.scenery)
	model.PrimaryPart = body
	Build.block("Rodape", v3(w + 0.2, 1, d + 0.2), origin * CFrame.new(0, 0.5, 0), P.Pedra, model, DETAIL)
	Build.block("Friso", v3(w + 0.16, 0.3, d + 0.16), origin * CFrame.new(0, 4.7, 0), P.Pedra, model, DETAIL)

	-- Telhado: 2 cunhas (a face alta de cada uma fica na cumeeira) com beiral na frente e atrás.
	-- Por dentro, 2 cunhas de reboco um pouco menores saem 0,05 nas pontas: é a empena.
	local run = d / 2 + SOBRADO.Eave
	local gable = roofH - 0.6
	for _, sign in SIGNS do
		-- sign = 1: água da frente (+Z); a cunha desce para o -Z local dela, então é girada 180°
		local turn = if sign == 1 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
		local roof = Build.wedge(
			"Telhado",
			v3(w, roofH, run),
			origin * CFrame.new(0, wallH + roofH / 2, sign * run / 2) * turn,
			P.Telha,
			model
		)
		scenic(roof, opts.scenery)
		Build.wedge(
			"Empena",
			v3(w + 0.1, gable, gable),
			origin * CFrame.new(0, wallH + gable / 2, sign * gable / 2) * turn,
			P.Reboco,
			model,
			DETAIL
		)
		-- Linhas das telhas: descem da cumeeira ao beiral, metade para dentro da cunha
		local slope = math.atan2(roofH, run)
		local slopeLength = math.sqrt(run * run + roofH * roofH)
		for i = -2, 2 do
			Build.block(
				"Telha",
				v3(0.3, 0.12, slopeLength - 0.5),
				origin * CFrame.new(i * 2, wallH + roofH / 2, sign * run / 2) * CFrame.Angles(sign * slope, 0, 0),
				P.TelhaEscura,
				model,
				DETAIL
			)
		end
	end
	Build.block(
		"Cumeeira",
		v3(w + 0.2, 0.35, 0.7),
		origin * CFrame.new(0, wallH + roofH - 0.1, 0),
		P.TelhaEscura,
		model,
		DETAIL
	)

	-- Porta (sai 0,15: mais que o rodapé, para não dividir face com ele)
	Build.block(
		"Porta",
		v3(2.2, 3.8, 0.3),
		origin * CFrame.new(-2.4 * m, 1.9, d / 2),
		opts.door or P.Porta,
		model,
		DETAIL
	)
	-- Janelas: blocos que atravessam a casa e aparecem 0,1 nas duas faces opostas
	local window = P.Janela
	local upper, lower = 6.6, 2.7
	for _, sign in SIGNS do
		Build.block("Janela", v3(1.6, 2.2, d + 0.2), origin * CFrame.new(sign * 2.4, upper, 0), window, model, DETAIL)
		for _, y in { upper, lower } do
			Build.block("Janela", v3(w + 0.2, 2.2, 1.4), origin * CFrame.new(0, y, sign * 1.9), window, model, DETAIL)
		end
	end
	Build.block("Janela", v3(1.6, 2.2, d + 0.2), origin * CFrame.new(2.4 * m, lower, 0), window, model, DETAIL)
	if opts.balcony then
		Build.block(
			"Sacada",
			v3(2.6, 0.3, 1),
			origin * CFrame.new(2.4 * m, upper - 1.25, d / 2 + 0.5),
			P.Pedra,
			model,
			DETAIL
		)
		Build.block(
			"Sacada",
			v3(2.6, 1, 0.15),
			origin * CFrame.new(2.4 * m, upper - 0.6, d / 2 + 0.925),
			P.Metal,
			model,
			DETAIL
		)
	end
	return model
end

-- Árvore Low Poly ------------------------------------------------------------------------------
-- Ø 5,6 × 8,8. Tronco de 6 lados e copa em 3 camadas (de 8 lados: o `Build.prism` faz 6 ou 8).
-- O tronco colide; a copa nunca colide nem bloqueia tiro (decisão do dono, F10).

function Kit.ArvoreLowPoly(parent: Instance, origin: CFrame, options: SceneryOptions?): Model
	local scenery = options ~= nil and options.scenery == true
	local model = Build.model("ArvoreLowPoly", parent)
	local trunk = Build.prism("Tronco", 6, 1.1, 3.2, origin * CFrame.new(0, 1.6, 0), P.Tronco, model)
	scenicAll(trunk, scenery)
	model.PrimaryPart = trunk[1]
	local layers = {
		{ diameter = 5.6, height = 2.4, base = 2.8, turn = 0, color = P.Folhas },
		{ diameter = 4.2, height = 2, base = 5.2, turn = 22.5, color = P.FolhasClaras },
		{ diameter = 2.6, height = 1.6, base = 7.2, turn = 0, color = P.Grama },
	}
	for _, layer in layers do
		local at = origin * CFrame.new(0, layer.base + layer.height / 2, 0) * CFrame.Angles(0, math.rad(layer.turn), 0)
		scenicAll(Build.prism("Copa", 8, layer.diameter, layer.height, at, layer.color, model), true)
	end
	return model
end

-- Poste De Luz ---------------------------------------------------------------------------------
-- 0,7 × 9,8. Haste fina escura e luminária creme apagada (sem luz, sem brilho). O braço aponta
-- para o +Z local. Só a haste colide (caixa de 0,5), e não bloqueia tiro: não vira cobertura.

function Kit.PosteDeLuz(parent: Instance, origin: CFrame, options: SceneryOptions?): Model
	local scenery = options ~= nil and options.scenery == true
	local metal = P.Metal
	local model = Build.model("PosteDeLuz", parent)
	local pole = Build.block(
		"Haste",
		v3(0.5, 9.3, 0.5),
		origin * CFrame.new(0, 4.65, 0),
		metal,
		model,
		{ query = false, shadow = false }
	)
	scenic(pole, scenery)
	model.PrimaryPart = pole
	Build.prism("Base", 6, 1.1, 0.9, origin * CFrame.new(0, 0.45, 0), metal, model, DETAIL)
	Build.block("Ponta", v3(0.3, 0.5, 0.3), origin * CFrame.new(0, 9.55, 0), metal, model, DETAIL)
	Build.block("Braco", v3(0.3, 0.3, 1.6), origin * CFrame.new(0, 9.15, 0.65), metal, model, DETAIL)
	Build.block("Chapeu", v3(1.1, 0.3, 1.1), origin * CFrame.new(0, 8.85, 1.2), metal, model, DETAIL)
	Build.block("Luminaria", v3(0.8, 0.8, 0.8), origin * CFrame.new(0, 8.3, 1.2), P.ToldoCreme, model, DETAIL)
	return model
end

-- Banco De Praça -------------------------------------------------------------------------------
-- 5 × 2 × 2,9. Pés de metal escuro e ripas de madeira; o encosto fica do lado -Z local.
-- Colide uma caixa invisível na altura do assento (dá para subir); nada bloqueia tiro.

function Kit.BancoDePraca(parent: Instance, origin: CFrame): Model
	local model = Build.model("BancoDePraca", parent)
	local seat = Build.block(
		"Assento",
		v3(5, 1.5, 2),
		origin * CFrame.new(0, 0.75, 0),
		P.Madeira,
		model,
		{ transparency = 1, query = false, shadow = false }
	)
	model.PrimaryPart = seat
	for _, sign in SIGNS do
		Build.block("Pe", v3(0.4, 1.4, 1.6), origin * CFrame.new(sign * 2, 0.7, 0.1), P.Metal, model, DETAIL)
		Build.block("Pe", v3(0.4, 1.6, 0.2), origin * CFrame.new(sign * 2, 2.1, -0.9), P.Metal, model, DETAIL)
	end
	for _, z in { -0.35, 0.2, 0.75 } do
		Build.block("Ripa", v3(5, 0.2, 0.45), origin * CFrame.new(0, 1.5, z), P.Madeira, model, DETAIL)
	end
	for _, y in { 2.05, 2.65 } do
		Build.block("Ripa", v3(5, 0.5, 0.2), origin * CFrame.new(0, y, -0.7), P.Madeira, model, DETAIL)
	end
	return model
end

-- Barraca De Feira -----------------------------------------------------------------------------
-- 6 × 4 × 6,5. Toldo listrado creme e verde-petróleo (caído para a frente, +Z local), balcão de
-- madeira e caixotes de frutas em cor chapada.

function Kit.BarracaDeFeira(parent: Instance, origin: CFrame, options: SceneryOptions?): Model
	local scenery = options ~= nil and options.scenery == true
	local model = Build.model("BarracaDeFeira", parent)
	local counter = Build.block("Balcao", v3(5.2, 2.6, 2.8), origin * CFrame.new(0, 1.3, 0.2), P.Madeira, model)
	scenic(counter, scenery)
	model.PrimaryPart = counter
	Build.block("Tampo", v3(5.6, 0.25, 3.2), origin * CFrame.new(0, 2.725, 0.2), P.MadeiraEscura, model, DETAIL)
	-- Postes: os de trás mais altos (o toldo cai para a frente)
	for _, sx in SIGNS do
		Build.block(
			"Poste",
			v3(0.4, 6.3, 0.4),
			origin * CFrame.new(sx * 2.8, 3.15, -1.8),
			P.MadeiraEscura,
			model,
			DETAIL
		)
		Build.block(
			"Poste",
			v3(0.4, 5.7, 0.4),
			origin * CFrame.new(sx * 2.8, 2.85, 1.8),
			P.MadeiraEscura,
			model,
			DETAIL
		)
	end
	local fruits = { P.Telha, P.Grama, P.Folhas }
	for i, fruit in fruits do
		local x = (i - 2) * 1.7
		Build.block("Caixote", v3(1.3, 0.6, 1.3), origin * CFrame.new(x, 3.15, 0.3), P.MadeiraEscura, model, DETAIL)
		Build.block("Frutas", v3(1.05, 0.3, 1.05), origin * CFrame.new(x, 3.5, 0.3), fruit, model, DETAIL)
	end
	-- Toldo: 6 faixas lado a lado, inclinadas 10°
	local tilt = CFrame.Angles(math.rad(10), 0, 0)
	for i = 1, 6 do
		local color = if i % 2 == 1 then P.ToldoCreme else P.ToldoPetroleo
		Build.block("Toldo", v3(1, 0.25, 4.6), origin * CFrame.new(i - 3.5, 6, 0.1) * tilt, color, model, DETAIL)
	end
	return model
end

-- Mureta da borda e pilar ----------------------------------------------------------------------
-- Mureta de praça: reboco creme, capa de telha e rodapé de pedra do lado de dentro. Vai de `a` a
-- `b` (x, z do quadro) como o `Build.wall`; `interior` é um ponto do lado de dentro.
-- Colide só o corpo (1 de espessura, como no bloco cinza).

function Kit.Mureta(parent: Instance, frame: CFrame, a: Vector2, b: Vector2, height: number, interior: Vector2?): Model
	local model = Build.model("Mureta", parent)
	local body = Build.wall("Corpo", frame, a, b, height, 1, P.Reboco, model)
	model.PrimaryPart = body
	local dir = (b - a).Unit
	-- Capa no comprimento exato (as pontas ficam dentro dos pilares)
	Build.wall("Capa", frame, a + dir * 0.65, b - dir * 0.65, 0.5, 1.3, P.Telha, model, height - 0.4, DETAIL)
	if interior then
		local normal = v2(-dir.Y, dir.X)
		if normal:Dot(interior - a) < 0 then
			normal = -normal
		end
		local shift = normal * 0.5
		Build.wall("Rodape", frame, a + shift + dir * 0.1, b + shift - dir * 0.1, 0.6, 0.2, P.Pedra, model, 0, DETAIL)
	end
	return model
end

-- Pilar de pedra com chapéu de telha, para os cantos da mureta (esconde a emenda). Só acabamento.
function Kit.Pilar(parent: Instance, origin: CFrame, railHeight: number): Model
	local model = Build.model("Pilar", parent)
	local h = railHeight + 0.4
	local post = Build.block("Pilar", v3(1.5, h, 1.5), origin * CFrame.new(0, h / 2, 0), P.Pedra, model, DETAIL)
	model.PrimaryPart = post
	Build.block("Chapeu", v3(1.8, 0.3, 1.8), origin * CFrame.new(0, h + 0.15, 0), P.Telha, model, DETAIL)
	return model
end

return Kit
