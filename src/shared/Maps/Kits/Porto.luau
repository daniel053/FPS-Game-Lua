--!strict
-- Kit do Porto (KIT-MODULAR seção 2): um componente por função, cada um devolve um Model.
--
-- `origin` é o quadro do componente (use `Build.pivot`): fica na base, no centro, com o +Y para
-- cima. O que cada eixo local significa está no comentário de cada função.
--
-- As peças que colidem são caixas (ou cunhas) simples, nas medidas do kit; o acabamento (ondulação,
-- portas, ferrugem, tábuas, treliça) é `Build.Detail`: não colide, não bloqueia tiro e sai no
-- máximo ~0,15 stud da peça que colide. Cores só de `Theme.Maps.Porto`; material liso, sem neon,
-- sem luz e sem texto.

local Build = require(script.Parent.Parent.Build)
local PracaKit = require(script.Parent.Praca)
local Theme = require(script.Parent.Parent.Parent.Config.Theme)

local PALETTE = Theme.Maps.Porto
local DETAIL = Build.Detail
local SIGNS = { -1, 1 }

local v3 = Vector3.new

local Kit = {}

-- Cores de contêiner do kit (nunca vermelho: é a cor do inimigo).
export type CorDeConteiner = "Laranja" | "Petroleo" | "Musgo" | "Mostarda"

type Tom = { base: Color3, escuro: Color3 }

local CONTAINER_COLORS: { [CorDeConteiner]: Tom } = {
	Laranja = { base = PALETTE.ConteinerLaranja, escuro = PALETTE.ConteinerLaranjaEscuro },
	Petroleo = { base = PALETTE.ConteinerPetroleo, escuro = PALETTE.ConteinerPetroleoEscuro },
	Musgo = { base = PALETTE.ConteinerMusgo, escuro = PALETTE.ConteinerMusgoEscuro },
	Mostarda = { base = PALETTE.ConteinerMostarda, escuro = PALETTE.ConteinerMostardaEscuro },
}

-- Medidas do kit (studs)
Kit.Conteiner_Comprimento = 20
Kit.Conteiner_Largura = 8
Kit.Conteiner_Altura = 8.5
Kit.Pilha_Vao = 8 -- passagem por baixo da pilha
Kit.Parede_Comprimento = 16
Kit.Parede_Altura = 12
Kit.Torre_Modulo = 4

local C_LEN, C_WID, C_H = Kit.Conteiner_Comprimento, Kit.Conteiner_Largura, Kit.Conteiner_Altura

-- Contêiner ------------------------------------------------------------------------------------
-- Corpo (a única peça que colide) + quadro, ondulação a cada 2 studs (cada placa aparece nos dois
-- lados e no teto, que é o que se vê do mirante), portas com 4 barras de trava na face +X, e
-- ferrugem só embaixo.

local RIB = { Step = 2, Width = 0.5, Out = 0.07 }
local FRAME = { Bar = 0.6, Out = 0.1 }

local function conteiner(name: string, origin: CFrame, cor: CorDeConteiner, model: Model): Part
	local tom = CONTAINER_COLORS[cor]
	local dark = tom.escuro
	local body = Build.block(name, v3(C_LEN, C_H, C_WID), origin * CFrame.new(0, C_H / 2, 0), tom.base, model)

	-- Quadro: uma placa embaixo (aparece nas 4 faces), um aro em cima e os 4 cantos
	local bar, out = FRAME.Bar, FRAME.Out
	Build.block(
		"Quadro",
		v3(C_LEN + 2 * out, bar, C_WID + 2 * out),
		origin * CFrame.new(0, bar / 2, 0),
		dark,
		model,
		DETAIL
	)
	local topY = C_H + 0.04 - bar / 2
	for _, sign in SIGNS do
		Build.block(
			"Quadro",
			v3(C_LEN + 2 * out, bar, 0.5),
			origin * CFrame.new(0, topY, sign * (C_WID / 2 + out - 0.25)),
			dark,
			model,
			DETAIL
		)
		Build.block(
			"Quadro",
			v3(0.5, bar, C_WID + 2 * out),
			origin * CFrame.new(sign * (C_LEN / 2 + out - 0.25), topY, 0),
			dark,
			model,
			DETAIL
		)
		for _, sz in SIGNS do
			Build.block(
				"Quadro",
				v3(0.5, C_H, 0.5),
				origin * CFrame.new(sign * (C_LEN / 2 + out - 0.25), C_H / 2, sz * (C_WID / 2 + out - 0.25)),
				dark,
				model,
				DETAIL
			)
		end
	end

	-- Ondulação: placas em pé que atravessam a largura e passam 0,06 acima do teto
	local ribHeight = C_H + 0.06 - bar
	local reach = math.floor((C_LEN / 2 - 1.5) / RIB.Step)
	for k = -reach, reach do
		Build.block(
			"Ondulacao",
			v3(RIB.Width, ribHeight, C_WID + 2 * RIB.Out),
			origin * CFrame.new(k * RIB.Step, bar + ribHeight / 2, 0),
			dark,
			model,
			DETAIL
		)
	end

	-- Face -X (fundo): 3 nervuras
	for k = -1, 1 do
		Build.block(
			"Ondulacao",
			v3(2 * RIB.Out, C_H - 2 * bar, RIB.Width),
			origin * CFrame.new(-C_LEN / 2, C_H / 2, k * 2),
			dark,
			model,
			DETAIL
		)
	end

	-- Face +X (portas): emenda das duas folhas e 4 barras de trava
	local doorX = C_LEN / 2
	Build.block(
		"Porta",
		v3(0.1, C_H - 2 * bar, 0.14),
		origin * CFrame.new(doorX + 0.02, C_H / 2, 0),
		dark,
		model,
		DETAIL
	)
	for _, z in { -3, -1.2, 1.2, 3 } do
		Build.block(
			"Trava",
			v3(0.16, C_H - 2 * bar - 0.4, 0.16),
			origin * CFrame.new(doorX + 0.08, C_H / 2, z),
			PALETTE.Metal,
			model,
			DETAIL
		)
	end

	-- Ferrugem: uma mancha baixa e um escorrido curto em cada lado comprido
	for _, sign in SIGNS do
		local face = sign * (C_WID / 2 + 0.06)
		local x = sign * 5
		Build.block(
			"Ferrugem",
			v3(2.4, 1.2, 0.12),
			origin * CFrame.new(x, bar + 0.6, face),
			PALETTE.Ferrugem,
			model,
			DETAIL
		)
		Build.block(
			"Ferrugem",
			v3(0.4, 1.5, 0.12),
			origin * CFrame.new(x + 0.6, bar + 1.9, face),
			PALETTE.FerrugemEscura,
			model,
			DETAIL
		)
	end
	return body
end

-- Contêiner (20 × 8 × 8,5): cobertura cheia. Comprimento no X local; portas na face +X.
function Kit.Conteiner(parent: Instance, origin: CFrame, cor: CorDeConteiner): Model
	local model = Build.model("Conteiner_" .. cor, parent)
	model.PrimaryPart = conteiner("Corpo", origin, cor, model)
	return model
end

-- Pilha de contêineres em ponte (2 de altura = 17): dois contêineres no chão, em linha no X local,
-- com um vão de 8 entre eles (passagem), e um terceiro em cima, no meio, apoiado 6 studs em cada
-- um. O topo dos de baixo que sobra (14 de cada lado) é a plataforma do nível 1; o topo do de cima
-- é o nível 2. `corA` é o contêiner do lado -X, `corB` o do +X. As portas dos de baixo dão para fora.
function Kit.PilhaDeConteineres(
	parent: Instance,
	origin: CFrame,
	corA: CorDeConteiner,
	corB: CorDeConteiner,
	corTopo: CorDeConteiner
): Model
	local model = Build.model("PilhaDeConteineres", parent)
	local offset = (Kit.Pilha_Vao + C_LEN) / 2
	local turned = CFrame.Angles(0, math.pi, 0)
	model.PrimaryPart = conteiner("BaseA", origin * CFrame.new(-offset, 0, 0) * turned, corA, model)
	conteiner("BaseB", origin * CFrame.new(offset, 0, 0), corB, model)
	conteiner("Topo", origin * CFrame.new(0, C_H, 0), corTopo, model)
	return model
end

-- Escada de metal: sobe no sentido do +X local, do nível de `origin` (pé, no centro da largura)
-- até `altura` acima, em `comprimento` studs. Colide como rampa lisa (melhor no celular); os degraus
-- são chapas finas em cima da rampa e as duas laterais levam a longarina amarela (aviso de beira).
function Kit.Escada(parent: Instance, origin: CFrame, comprimento: number, altura: number, largura: number): Model
	local model = Build.model("Escada", parent)
	model.PrimaryPart = Build.wedge(
		"Rampa",
		v3(largura, altura, comprimento),
		origin * CFrame.new(comprimento / 2, altura / 2, 0) * CFrame.Angles(0, math.pi / 2, 0),
		PALETTE.Metal,
		model
	)
	local steps = math.max(2, math.round(altura / 0.85))
	local run = comprimento / steps
	for i = 1, steps do
		local x = (i - 0.5) * run
		Build.block(
			"Degrau",
			v3(run * 0.55, 0.14, largura - 0.6),
			origin * CFrame.new(x, altura * x / comprimento + 0.03, 0),
			PALETTE.Chapa,
			model,
			DETAIL
		)
	end
	local slope = math.atan2(altura, comprimento)
	local length = math.sqrt(comprimento * comprimento + altura * altura)
	for _, sign in SIGNS do
		Build.block(
			"Longarina",
			v3(length, 0.4, 0.3),
			origin
				* CFrame.new(comprimento / 2, altura / 2, sign * (largura / 2 - 0.15))
				* CFrame.Angles(0, 0, slope)
				* CFrame.new(0, 0.1, 0),
			PALETTE.Aviso,
			model,
			DETAIL
		)
	end
	return model
end

-- Caixa de madeira: 6 (cobertura cheia; dá para subir pulando) ou 3 (meia altura). É a mesma caixa
-- da Praça (mesma madeira): moldura e travessa diagonal mais escuras.
function Kit.CaixaDeMadeira(parent: Instance, origin: CFrame, tamanho: number): Model
	assert(tamanho == 6 or tamanho == 3, "caixa de madeira de 6 ou de 3")
	local model = PracaKit.CaixaDeMadeira(parent, origin, tamanho)
	model.Name = "CaixaDeMadeira_" .. tamanho
	return model
end

-- Barris (Ø 2,6 × 3,2, 8 lados), em grupo de 2 a 4: cobertura parcial. Não explodem.
-- Petróleo como cor principal; com 3 ou mais, o último é Mostarda. Duas cintas escuras em cada um.
local BARREL_SPOTS = { Vector2.new(-1.4, -1.2), Vector2.new(1.4, -1.2), Vector2.new(0, 1.3), Vector2.new(2.8, 1.3) }
local BARREL = { Diameter = 2.6, Height = 3.2, Bands = { 0.9, 2.3 }, BandHeight = 0.3 }

function Kit.Barris(parent: Instance, origin: CFrame, quantidade: number): Model
	assert(quantidade >= 2 and quantidade <= #BARREL_SPOTS, "grupo de 2 a 4 barris")
	local model = Build.model("Barris", parent)
	for i = 1, quantidade do
		local spot = BARREL_SPOTS[i]
		local color = if i == quantidade and quantidade >= 3
			then PALETTE.ConteinerMostarda
			else PALETTE.ConteinerPetroleo
		local at = origin * CFrame.new(spot.X, 0, spot.Y)
		local parts = Build.prism(
			"Barril",
			8,
			BARREL.Diameter,
			BARREL.Height,
			at * CFrame.new(0, BARREL.Height / 2, 0),
			color,
			model
		)
		if i == 1 then
			model.PrimaryPart = parts[1]
		end
		for _, y in BARREL.Bands do
			Build.prism(
				"Cinta",
				8,
				BARREL.Diameter + 0.16,
				BARREL.BandHeight,
				at * CFrame.new(0, y, 0),
				PALETTE.Metal,
				model,
				DETAIL
			)
		end
		Build.prism(
			"Tampa",
			8,
			BARREL.Diameter - 0.5,
			0.06,
			at * CFrame.new(0, BARREL.Height + 0.03, 0),
			PALETTE.Metal,
			model,
			DETAIL
		)
	end
	return model
end

-- Faixa de aviso de queda (amarela com listras escuras a cada 2 studs): 1 de largura, comprimento
-- no X local, deitada em cima do piso em `origin`. Só acabamento.
function Kit.FaixaDeAviso(parent: Instance, origin: CFrame, comprimento: number): Model
	local model = Build.model("FaixaDeAviso", parent)
	model.PrimaryPart =
		Build.block("Faixa", v3(comprimento, 0.1, 1), origin * CFrame.new(0, 0.05, 0), PALETTE.Aviso, model, DETAIL)
	local x = -comprimento / 2 + 1.5
	while x + 0.5 <= comprimento / 2 do
		Build.block("Listra", v3(1, 0.04, 1), origin * CFrame.new(x, 0.11, 0), PALETTE.Metal, model, DETAIL)
		x += 2
	end
	return model
end

-- Píer de madeira: piso no nível de `origin` (topo das tábuas), comprimento no X local e largura no
-- Z local. O lado +Z encosta no cais; os outros três dão para a água e levam a faixa de aviso.
-- Tábuas de 1,5 em tons alternados; estacas de 6 lados a cada 12 studs, do lado da água.
-- A PrimaryPart é o piso (marcar como chão).
local PLANK = 1.5

function Kit.PierDeMadeira(parent: Instance, origin: CFrame, comprimento: number, largura: number): Model
	local model = Build.model("PierDeMadeira", parent)
	model.PrimaryPart =
		Build.block("Piso", v3(comprimento, 1, largura), origin * CFrame.new(0, -0.5, 0), PALETTE.Madeira, model)
	local planks = math.floor(comprimento / PLANK)
	for i = 1, planks, 2 do
		Build.block(
			"Tabua",
			v3(PLANK - 0.08, 0.05, largura),
			origin * CFrame.new(-comprimento / 2 + (i - 0.5) * PLANK, 0.025, 0),
			PALETTE.MadeiraClara,
			model,
			DETAIL
		)
	end
	-- Viga escura por baixo da beira que dá para a água
	Build.block(
		"Viga",
		v3(comprimento + 0.2, 0.7, 0.5),
		origin * CFrame.new(0, -0.75, -largura / 2 + 0.15),
		PALETTE.MadeiraEscura,
		model,
		DETAIL
	)
	Kit.FaixaDeAviso(model, origin * CFrame.new(0, 0, -largura / 2 + 0.5), comprimento)
	for _, sign in SIGNS do
		local edge = origin * CFrame.new(sign * (comprimento / 2 - 0.5), 0, 0.5) * CFrame.Angles(0, math.pi / 2, 0)
		Kit.FaixaDeAviso(model, edge, largura - 1)
	end
	local reach = math.floor((comprimento / 2 - 1) / 12)
	for k = -reach, reach do
		local at = origin * CFrame.new(k * 12, -5, -largura / 2 + 1)
		Build.prism("Estaca", 6, 1.2, 8, at, PALETTE.MadeiraEscura, model, DETAIL)
	end
	return model
end

-- Água chapada (sem reflexo): placa com o topo no nível de `origin`, comprimento no X local e
-- largura no Z local, com algumas ondinhas mais claras. Não colide e não bloqueia tiro: quem cai
-- atravessa e volta à base (queda detectada por altura).
function Kit.Agua(parent: Instance, origin: CFrame, comprimento: number, largura: number): Model
	local model = Build.model("Agua", parent)
	model.PrimaryPart =
		Build.block("Agua", v3(comprimento, 1, largura), origin * CFrame.new(0, -0.5, 0), PALETTE.Agua, model, DETAIL)
	local waves = math.max(2, math.floor(comprimento / 8))
	for i = 1, waves do
		local x = (i - (waves + 1) / 2) * comprimento / waves
		local z = (if i % 2 == 0 then 1 else -1) * largura * 0.3
		Build.block("Onda", v3(3, 0.04, 0.4), origin * CFrame.new(x, 0.02, z), PALETTE.AguaClara, model, DETAIL)
	end
	return model
end

-- Parede de chapa (16 × 1 × 12): bloqueia a visão. Comprimento no X local. Base de concreto,
-- ondulação a cada 1 stud, topo de metal escuro e ferrugem só no terço de baixo (com escorridos).
local SHEET_RUST = {
	-- { x, largura, altura }
	{ -5, 1.8, 2.4 },
	{ -1.5, 1, 1.4 },
	{ 4.5, 2.2, 1.9 },
}
local SHEET_DRIPS = { { -4.5, 2 }, { 5.1, 1.6 } } -- { x, altura } acima da mancha

function Kit.ParedeDeChapa(parent: Instance, origin: CFrame): Model
	local model = Build.model("ParedeDeChapa", parent)
	local length, height = Kit.Parede_Comprimento, Kit.Parede_Altura
	model.PrimaryPart =
		Build.block("Chapa", v3(length, height, 1), origin * CFrame.new(0, height / 2, 0), PALETTE.Chapa, model)
	local base, cap = 1, 0.5
	Build.block(
		"Base",
		v3(length + 0.3, base, 1.5),
		origin * CFrame.new(0, base / 2, 0),
		PALETTE.Concreto,
		model,
		DETAIL
	)
	Build.block(
		"Topo",
		v3(length + 0.3, cap, 1.4),
		origin * CFrame.new(0, height + 0.05 - cap / 2, 0),
		PALETTE.Metal,
		model,
		DETAIL
	)
	local ribHeight = height - base - cap + 0.05
	for i = 1, length do
		Build.block(
			"Ondulacao",
			v3(0.45, ribHeight, 1.14),
			origin * CFrame.new(-length / 2 + i - 0.5, base + ribHeight / 2, 0),
			PALETTE.ChapaEscura,
			model,
			DETAIL
		)
	end
	for _, patch in SHEET_RUST do
		Build.block(
			"Ferrugem",
			v3(patch[2], patch[3], 1.22),
			origin * CFrame.new(patch[1], base + patch[3] / 2, 0),
			PALETTE.Ferrugem,
			model,
			DETAIL
		)
	end
	for _, drip in SHEET_DRIPS do
		Build.block(
			"Ferrugem",
			v3(0.35, drip[2], 1.24),
			origin * CFrame.new(drip[1], base + 2 + drip[2] / 2, 0),
			PALETTE.FerrugemEscura,
			model,
			DETAIL
		)
	end
	return model
end

-- Torre do guindaste (4 × 4, módulos de 4 de altura), com plataforma no topo. Treliça: 4 montantes,
-- um aro por módulo e uma diagonal por face (em zigue-zague), com ferrugem só no pé. Colide só o
-- miolo (2 × 2) e a plataforma. `lanca` (opcional) é o comprimento da lança no topo, no sentido do
-- +X local (só acabamento: fica acima de tudo), com contrapeso, cabine, cabo e gancho.
function Kit.TorreDoGuindaste(parent: Instance, origin: CFrame, modulos: number, lanca: number?): Model
	local model = Build.model("TorreDoGuindaste", parent)
	local side = Kit.Torre_Modulo
	local height = modulos * side
	local post = side / 2 - 0.25 -- eixo dos montantes
	model.PrimaryPart =
		Build.block("Torre", v3(2, height, 2), origin * CFrame.new(0, height / 2, 0), PALETTE.Metal, model)
	Build.block(
		"Plataforma",
		v3(side + 1, 0.5, side + 1),
		origin * CFrame.new(0, height + 0.25, 0),
		PALETTE.Metal,
		model
	)
	for _, sx in SIGNS do
		for _, sz in SIGNS do
			local at = origin * CFrame.new(sx * post, 0, sz * post)
			Build.block(
				"Montante",
				v3(0.5, height, 0.5),
				at * CFrame.new(0, height / 2, 0),
				PALETTE.Guindaste,
				model,
				DETAIL
			)
			Build.block("Ferrugem", v3(0.58, 3, 0.58), at * CFrame.new(0, 1.5, 0), PALETTE.Ferrugem, model, DETAIL)
		end
	end
	for k = 0, modulos do
		local y = math.clamp(k * side, 0.2, height - 0.2)
		for _, sign in SIGNS do
			Build.block(
				"Aro",
				v3(side, 0.4, 0.4),
				origin * CFrame.new(0, y, sign * post),
				PALETTE.Guindaste,
				model,
				DETAIL
			)
			Build.block(
				"Aro",
				v3(0.4, 0.4, side),
				origin * CFrame.new(sign * post, y, 0),
				PALETTE.Guindaste,
				model,
				DETAIL
			)
		end
	end
	local span = 2 * post
	local diagonal = math.sqrt(span * span + side * side)
	local tilt = math.atan2(side, span)
	for k = 0, modulos - 1 do
		local angle = if k % 2 == 0 then tilt else -tilt
		local mid = origin * CFrame.new(0, (k + 0.5) * side, 0)
		for face = 0, 3 do
			Build.block(
				"Diagonal",
				v3(diagonal, 0.3, 0.3),
				mid * CFrame.Angles(0, face * math.pi / 2, 0) * CFrame.new(0, 0, post) * CFrame.Angles(0, 0, angle),
				PALETTE.GuindasteEscuro,
				model,
				DETAIL
			)
		end
	end
	if lanca and lanca > 0 then
		-- começa 4 studs atrás do eixo da torre (contrapeso)
		local top = origin * CFrame.new(0, height + 0.5, 0)
		local midX = lanca / 2 - side
		for _, sign in SIGNS do
			Build.block(
				"Lanca",
				v3(lanca, 0.5, 0.5),
				top * CFrame.new(midX, 0.9, sign * 0.8),
				PALETTE.Guindaste,
				model,
				DETAIL
			)
		end
		Build.block(
			"Lanca",
			v3(lanca - 6, 0.4, 0.4),
			top * CFrame.new(midX + 1, 2.3, 0),
			PALETTE.Guindaste,
			model,
			DETAIL
		)
		local x = -side + 2
		while x <= lanca - side - 1 do
			Build.block(
				"Travessa",
				v3(0.3, 0.3, 2.1),
				top * CFrame.new(x, 0.9, 0),
				PALETTE.GuindasteEscuro,
				model,
				DETAIL
			)
			Build.block(
				"Travessa",
				v3(0.3, 1.5, 0.3),
				top * CFrame.new(x, 1.6, 0),
				PALETTE.GuindasteEscuro,
				model,
				DETAIL
			)
			x += 4
		end
		Build.block("Contrapeso", v3(3, 2, 2.6), top * CFrame.new(-side + 1.5, 1.2, 0), PALETTE.Metal, model, DETAIL)
		Build.block("Cabine", v3(2.6, 2.2, 2.6), top * CFrame.new(0.5, 1.1, 0), PALETTE.Chapa, model, DETAIL)
		local tip = lanca - side - 1.5
		Build.block("Cabo", v3(0.15, 7, 0.15), top * CFrame.new(tip, 0.9 - 3.5, 0), PALETTE.Metal, model, DETAIL)
		Build.block("Gancho", v3(0.9, 0.9, 0.5), top * CFrame.new(tip, 0.9 - 7.4, 0), PALETTE.Aviso, model, DETAIL)
	end
	return model
end

-- Cabeço de amarração (4 × 4 × 2,6): detalhe da borda do píer. Só a base baixa colide. Poste de
-- metal de 8 lados com chapéu largo e uma faixa amarela na beira da base.
function Kit.CabecoDeAmarracao(parent: Instance, origin: CFrame): Model
	local model = Build.model("CabecoDeAmarracao", parent)
	model.PrimaryPart = Build.block("Base", v3(4, 0.5, 4), origin * CFrame.new(0, 0.25, 0), PALETTE.Concreto, model)
	Build.block("Faixa", v3(4, 0.06, 0.6), origin * CFrame.new(0, 0.53, -1.7), PALETTE.Aviso, model, DETAIL)
	Build.prism("Poste", 8, 2, 1.6, origin * CFrame.new(0, 1.3, 0), PALETTE.Metal, model, DETAIL)
	Build.prism("Chapeu", 8, 2.8, 0.5, origin * CFrame.new(0, 2.35, 0), PALETTE.Metal, model, DETAIL)
	return model
end

-- Vaga pintada no chão do cais: contorno amarelo em volta de um contêiner (comprimento no X local),
-- com 1 stud de folga. Só acabamento; ajuda a ler o pátio de cima.
function Kit.Vaga(parent: Instance, origin: CFrame): Model
	local model = Build.model("Vaga", parent)
	local length, width = C_LEN + 2, C_WID + 2
	for _, sign in SIGNS do
		local long = Build.block(
			"Linha",
			v3(length + 0.4, 0.04, 0.4),
			origin * CFrame.new(0, 0.02, sign * width / 2),
			PALETTE.Aviso,
			model,
			DETAIL
		)
		model.PrimaryPart = model.PrimaryPart or long
		Build.block(
			"Linha",
			v3(0.4, 0.04, width - 0.4),
			origin * CFrame.new(sign * length / 2, 0.02, 0),
			PALETTE.Aviso,
			model,
			DETAIL
		)
	end
	return model
end

return Kit
