--!strict
-- Peças de detalhe comuns às ilhas Fábrica, Praça e Torre (passada de detalhe depois da F10, a
-- mesma estratégia do Porto: pintura no chão, áreas bem marcadas, sombra pintada, mato e hera,
-- itens pequenos, luminárias e poucas luzes reais). As cores vêm de `Theme.Maps.<Mapa>.Detalhe`.
--
-- Tudo aqui é acabamento: não colide e não bloqueia tiro. A pintura no chão fica rente, em
-- camadas (o topo de cada uma mais alto que a de baixo) e sempre por baixo das juntas e faixas que
-- os kits já têm. Peças de parede: `origin` no pé da parede (ou no ponto onde são presas), com o +Z
-- local saindo da parede e o X local ao longo dela.

local Build = require(script.Parent.Parent.Build)
local MapConfig = require(script.Parent.Parent.Parent.Config.MapConfig)

local DETAIL = Build.Detail
local SIGNS = { -1, 1 }
local LIGHTS = MapConfig.SceneLights

local v3 = Vector3.new

local Detalhe = {}

-- Cores de um mapa para as peças de detalhe (Theme.Maps.<Mapa>.Detalhe).
export type Cores = {
	Pintura: Color3, -- linhas, setas, faixa de pedestre, marca da base
	Aviso: Color3, -- áreas hachuradas de perigo
	Placa: Color3, -- placas do piso em outro tom
	Sombra: Color3, -- sombra pintada no pé das peças
	Mancha: Color3, -- óleo, sujeira ou musgo
	Rachadura: Color3,
	Folhas: Color3,
	FolhasEscuras: Color3,
	Metal: Color3,
	Vaso: Color3,
	Terra: Color3,
	Extintor: Color3, -- nunca vermelho (cor do inimigo)
	Caixa: Color3, -- quadro elétrico e lixeira
	CaixaEscura: Color3,
	Cone: Color3,
	Madeira: Color3,
	MadeiraClara: Color3,
	MadeiraEscura: Color3,
	Pedra: Color3,
	PedraEscura: Color3,
	LuzCreme: Color3, -- lente das luminárias (sem neon)
	LuzNoChao: Color3, -- mancha de luz pintada no chão
	LuzQuente: Color3, -- cor das luzes reais
}

local LAYER = {
	Placa = 0.01,
	Sombra = 0.014,
	Luz = 0.018,
	Mancha = 0.021,
	Pintura = 0.025,
}
Detalhe.Camadas = LAYER

local LINE = 0.4 -- largura das linhas pintadas
local HATCH_STEP = 2.4 -- distância (no comprimento) entre as diagonais da hachura

-- Retângulo pintado no chão, com o topo na `altura`: comprimento no X local, largura no Z local.
local function paint(name: string, size: Vector2, at: CFrame, altura: number, color: Color3, model: Model): Part
	return Build.block(name, v3(size.X, altura, size.Y), at * CFrame.new(0, altura / 2, 0), color, model, DETAIL)
end

-- Luz real dentro de `part`: branco-quente (cor do mapa), fraca, sem sombra; apaga na versão leve.
function Detalhe.luz(part: BasePart, cores: Cores): PointLight
	return Build.light(part, cores.LuzQuente, LIGHTS.Brightness, LIGHTS.Range)
end

-- Chão ---------------------------------------------------------------------------------------------

-- Placa (ou laje) em outro tom; `cor` padrão: `cores.Placa`.
function Detalhe.Placa(parent: Instance, origin: CFrame, tamanho: Vector2, cor: Color3): Model
	local model = Build.model("PlacaDoPiso", parent)
	model.PrimaryPart = paint("Placa", tamanho, origin, LAYER.Placa, cor, model)
	return model
end

-- Sombra pintada (falso contato) embaixo de uma peça: retângulo um pouco maior que ela.
function Detalhe.Sombra(parent: Instance, origin: CFrame, tamanho: Vector2, cores: Cores): Model
	local model = Build.model("SombraPintada", parent)
	model.PrimaryPart = paint("Sombra", tamanho, origin, LAYER.Sombra, cores.Sombra, model)
	return model
end

-- Mancha (óleo, sujeira ou musgo): octógono com um respingo menor ao lado.
function Detalhe.Mancha(parent: Instance, origin: CFrame, diametro: number, cores: Cores): Model
	local model = Build.model("ManchaDeOleo", parent)
	local h = LAYER.Mancha
	model.PrimaryPart =
		Build.prism("Mancha", 8, diametro, h, origin * CFrame.new(0, h / 2, 0), cores.Mancha, model, DETAIL)[1]
	Build.prism(
		"Mancha",
		6,
		diametro * 0.35,
		h,
		origin * CFrame.new(diametro * 0.62, h / 2, diametro * 0.3),
		cores.Mancha,
		model,
		DETAIL
	)
	return model
end

-- Rachadura: três trechos finos com desvios pequenos (nunca formam uma letra), ao longo do X local.
local CRACK_TURNS = { 0.18, -0.22, 0.12 }

function Detalhe.Rachadura(parent: Instance, origin: CFrame, comprimento: number, cores: Cores): Model
	local model = Build.model("Rachadura", parent)
	local step = comprimento / #CRACK_TURNS
	local at = origin * CFrame.new(-comprimento / 2, 0, 0)
	for _, turn in CRACK_TURNS do
		local heading = CFrame.Angles(0, turn, 0)
		local part = paint(
			"Rachadura",
			Vector2.new(step + 0.12, 0.14),
			at * heading * CFrame.new(step / 2, 0, 0),
			LAYER.Mancha,
			cores.Rachadura,
			model
		)
		model.PrimaryPart = model.PrimaryPart or part
		at = at * heading * CFrame.new(step, 0, 0) * heading:Inverse()
	end
	return model
end

-- Linha pintada ao longo do X local; `tracejada` = traços de 2 com vão de 1,5.
function Detalhe.Linha(parent: Instance, origin: CFrame, comprimento: number, cor: Color3, tracejada: boolean?): Model
	local model = Build.model("LinhaPintada", parent)
	if not tracejada then
		model.PrimaryPart = paint("Linha", Vector2.new(comprimento, LINE), origin, LAYER.Pintura, cor, model)
		return model
	end
	local dash, gap = 2, 1.5
	local x = -comprimento / 2
	while x + dash <= comprimento / 2 + 1e-3 do
		local part =
			paint("Traco", Vector2.new(dash, LINE), origin * CFrame.new(x + dash / 2, 0, 0), LAYER.Pintura, cor, model)
		model.PrimaryPart = model.PrimaryPart or part
		x += dash + gap
	end
	return model
end

-- Faixa de pedestre: barras de 1 de largura no sentido do X local (`comprimento`), a cada 2 studs
-- ao longo do Z local (`largura`).
function Detalhe.FaixaDePedestre(
	parent: Instance,
	origin: CFrame,
	comprimento: number,
	largura: number,
	cor: Color3
): Model
	local model = Build.model("FaixaDePedestre", parent)
	local bars = math.floor(largura / 2)
	for i = 1, bars do
		local z = (i - (bars + 1) / 2) * 2
		local part =
			paint("Barra", Vector2.new(comprimento, 1), origin * CFrame.new(0, 0, z), LAYER.Pintura, cor, model)
		model.PrimaryPart = model.PrimaryPart or part
	end
	return model
end

-- Seta no chão apontando para o +X local (sem texto).
function Detalhe.Seta(parent: Instance, origin: CFrame, comprimento: number, cor: Color3): Model
	local model = Build.model("Seta", parent)
	local head = 1.6
	model.PrimaryPart = paint(
		"Haste",
		Vector2.new(comprimento - head * 0.5, 0.6),
		origin * CFrame.new(-head * 0.25, 0, 0),
		LAYER.Pintura,
		cor,
		model
	)
	for _, sign in SIGNS do
		paint(
			"Ponta",
			Vector2.new(head * 1.3, 0.6),
			origin
				* CFrame.new(comprimento / 2, 0, 0)
				* CFrame.Angles(0, sign * math.rad(40), 0)
				* CFrame.new(-head * 0.6, 0, 0),
			LAYER.Pintura,
			cor,
			model
		)
	end
	return model
end

-- Área hachurada (manter livre / perigo): contorno e diagonais a 45°. Comprimento no X local,
-- largura no Z local.
function Detalhe.AreaHachurada(
	parent: Instance,
	origin: CFrame,
	comprimento: number,
	largura: number,
	cor: Color3
): Model
	local model = Build.model("AreaHachurada", parent)
	local h = LAYER.Pintura
	for _, sign in SIGNS do
		local long = paint(
			"Contorno",
			Vector2.new(comprimento, LINE),
			origin * CFrame.new(0, 0, sign * (largura / 2 - LINE / 2)),
			h,
			cor,
			model
		)
		model.PrimaryPart = model.PrimaryPart or long
		paint(
			"Contorno",
			Vector2.new(LINE, largura - 2 * LINE),
			origin * CFrame.new(sign * (comprimento / 2 - LINE / 2), 0, 0),
			h,
			cor,
			model
		)
	end
	-- Diagonais x - z = c, cortadas no miolo do contorno
	local hx, hz = comprimento / 2 - LINE, largura / 2 - LINE
	local c = -(hx + hz) + HATCH_STEP / 2
	while c < hx + hz do
		local x1, x2 = math.max(-hx, -hz + c), math.min(hx, hz + c)
		if x2 - x1 > 0.3 then
			local mx = (x1 + x2) / 2
			paint(
				"Hachura",
				Vector2.new((x2 - x1) * math.sqrt(2), LINE),
				origin * CFrame.new(mx, 0, mx - c) * CFrame.Angles(0, -math.pi / 4, 0),
				h,
				cor,
				model
			)
		end
		c += HATCH_STEP
	end
	return model
end

-- Anel no chão (octógono de linhas), com o `diametro` de face a face.
function Detalhe.Anel(parent: Instance, origin: CFrame, diametro: number, cor: Color3, largura: number?): Model
	local model = Build.model("AnelPintado", parent)
	local line = largura or LINE
	local r = diametro / 2
	local side = 2 * r * math.tan(math.pi / 8) + line
	for k = 0, 7 do
		local a = k * math.pi / 4
		local part = paint(
			"Anel",
			Vector2.new(side, line),
			origin * CFrame.new(r * math.cos(a), 0, r * math.sin(a)) * CFrame.Angles(0, -(a + math.pi / 2), 0),
			LAYER.Pintura,
			cor,
			model
		)
		model.PrimaryPart = model.PrimaryPart or part
	end
	return model
end

-- Marca da base (sem letra): anel em volta de onde se nasce (centro da base) e, se `hachura`, área
-- hachurada no fundo. `origin` no centro do piso da base, com o +X local apontando para o fundo.
function Detalhe.MarcaDeBase(
	parent: Instance,
	origin: CFrame,
	fundo: number,
	largura: number,
	cor: Color3,
	hachura: boolean
): Model
	local model = Build.model("MarcaDeBase", parent)
	model.PrimaryPart = Detalhe.Anel(model, origin, 10, cor, 0.6).PrimaryPart
	if hachura then
		Detalhe.AreaHachurada(model, origin * CFrame.new(fundo / 2 - 6, 0, 0), 8, largura - 20, cor)
	end
	return model
end

-- Mancha de luz pintada no chão, embaixo de uma luminária (octógono num tom mais claro e quente).
function Detalhe.ManchaDeLuz(parent: Instance, origin: CFrame, diametro: number, cores: Cores): Model
	local model = Build.model("ManchaDeLuz", parent)
	local h = LAYER.Luz
	model.PrimaryPart =
		Build.prism("Luz", 8, diametro, h, origin * CFrame.new(0, h / 2, 0), cores.LuzNoChao, model, DETAIL)[1]
	return model
end

-- Plantas -----------------------------------------------------------------------------------------

-- Mato: tufo de 3 folhas em cunha (frestas, cantos e pé de parede).
local BLADES = {
	{ yaw = 0, height = 1.1 },
	{ yaw = 2.1, height = 0.8 },
	{ yaw = 4.2, height = 0.95 },
}

function Detalhe.Mato(parent: Instance, origin: CFrame, escala: number, cores: Cores): Model
	local model = Build.model("Mato", parent)
	local depth = 0.7 * escala
	for i, blade in BLADES do
		local h = blade.height * escala
		local part = Build.wedge(
			"Folha",
			v3(0.22 * escala, h, depth),
			origin * CFrame.Angles(0, blade.yaw, 0) * CFrame.new(0, h / 2, -depth / 2),
			if i % 2 == 0 then cores.FolhasEscuras else cores.Folhas,
			model,
			DETAIL
		)
		model.PrimaryPart = model.PrimaryPart or part
	end
	return model
end

-- Hera subindo a parede: três ramos finos com folhas em losango dos dois lados, até a `altura`.
local IVY_STEMS = {
	-- { x, fração da altura }
	{ -0.7, 1 },
	{ 0.2, 0.7 },
	{ 0.95, 0.45 },
}
local IVY_LEAF = { Size = 0.55, Step = 0.55, Side = 0.22 }

function Detalhe.Hera(parent: Instance, origin: CFrame, altura: number, cores: Cores): Model
	local model = Build.model("Hera", parent)
	for s, stem in IVY_STEMS do
		local h = altura * stem[2]
		local part = Build.block(
			"Ramo",
			v3(0.12, h, 0.06),
			origin * CFrame.new(stem[1], h / 2, 0.03),
			cores.FolhasEscuras,
			model,
			DETAIL
		)
		model.PrimaryPart = model.PrimaryPart or part
		local leaves = math.max(1, math.floor(h / IVY_LEAF.Step))
		for i = 1, leaves do
			local side = if (i + s) % 2 == 0 then 1 else -1
			Build.block(
				"Folha",
				v3(IVY_LEAF.Size, IVY_LEAF.Size, 0.06),
				origin
					* CFrame.new(stem[1] + side * IVY_LEAF.Side, (i - 0.4) * IVY_LEAF.Step, 0.08 + (i % 2) * 0.03)
					* CFrame.Angles(0, 0, math.pi / 4),
				if (i + s) % 3 == 0 then cores.FolhasEscuras else cores.Folhas,
				model,
				DETAIL
			)
		end
	end
	return model
end

-- Floreira (2,4 × 1 × 1,2) com dois tufos de mato. Comprimento no X local.
function Detalhe.Floreira(parent: Instance, origin: CFrame, cores: Cores): Model
	local model = Build.model("Floreira", parent)
	model.PrimaryPart = Build.block("Vaso", v3(2.4, 1, 1.2), origin * CFrame.new(0, 0.5, 0), cores.Vaso, model, DETAIL)
	Build.block("Terra", v3(2.1, 0.06, 0.9), origin * CFrame.new(0, 1.02, 0), cores.Terra, model, DETAIL)
	Detalhe.Mato(model, origin * CFrame.new(-0.6, 1, 0), 0.9, cores)
	Detalhe.Mato(model, origin * CFrame.new(0.6, 1, 0) * CFrame.Angles(0, 1, 0), 1.1, cores)
	return model
end

-- Itens pequenos ----------------------------------------------------------------------------------

-- Extintor de parede (nunca vermelho), com placa clara atrás, suporte e mangueira.
function Detalhe.Extintor(parent: Instance, origin: CFrame, cores: Cores): Model
	local model = Build.model("Extintor", parent)
	model.PrimaryPart =
		Build.block("Placa", v3(1.1, 2.2, 0.06), origin * CFrame.new(0, 2.3, 0.03), cores.LuzCreme, model, DETAIL)
	Build.block("Suporte", v3(0.7, 0.25, 0.3), origin * CFrame.new(0, 1.55, 0.2), cores.Metal, model, DETAIL)
	Build.prism("Corpo", 6, 0.7, 1.5, origin * CFrame.new(0, 2.3, 0.45), cores.Extintor, model, DETAIL)
	Build.block("Valvula", v3(0.3, 0.3, 0.3), origin * CFrame.new(0, 3.2, 0.45), cores.Metal, model, DETAIL)
	Build.block("Mangueira", v3(0.12, 0.9, 0.12), origin * CFrame.new(0.42, 2.5, 0.45), cores.Metal, model, DETAIL)
	return model
end

-- Quadro elétrico de parede: caixa com emenda da porta, faixa de aviso e conduíte até o chão.
function Detalhe.QuadroEletrico(parent: Instance, origin: CFrame, cores: Cores): Model
	local model = Build.model("QuadroEletrico", parent)
	model.PrimaryPart =
		Build.block("Caixa", v3(2, 2.6, 0.6), origin * CFrame.new(0, 3.3, 0.3), cores.Caixa, model, DETAIL)
	Build.block("Porta", v3(0.06, 2.3, 0.04), origin * CFrame.new(0, 3.25, 0.62), cores.CaixaEscura, model, DETAIL)
	Build.block("Faixa", v3(2, 0.2, 0.06), origin * CFrame.new(0, 4.45, 0.63), cores.Aviso, model, DETAIL)
	Build.block("Conduite", v3(0.25, 2, 0.25), origin * CFrame.new(0.6, 1, 0.2), cores.Metal, model, DETAIL)
	return model
end

-- Cone de sinalização (1,3 de altura).
function Detalhe.Cone(parent: Instance, origin: CFrame, cores: Cores): Model
	local model = Build.model("Cone", parent)
	model.PrimaryPart =
		Build.block("Base", v3(1.1, 0.15, 1.1), origin * CFrame.new(0, 0.075, 0), cores.Metal, model, DETAIL)
	Build.prism("Corpo", 6, 0.8, 0.5, origin * CFrame.new(0, 0.4, 0), cores.Cone, model, DETAIL)
	Build.prism("Faixa", 6, 0.6, 0.25, origin * CFrame.new(0, 0.775, 0), cores.LuzCreme, model, DETAIL)
	Build.prism("Ponta", 6, 0.4, 0.4, origin * CFrame.new(0, 1.1, 0), cores.Cone, model, DETAIL)
	return model
end

-- Pilha de pallets de madeira (3 × 3, 0,42 de altura cada).
function Detalhe.Pallets(parent: Instance, origin: CFrame, quantidade: number, cores: Cores): Model
	local model = Build.model("Pallets", parent)
	for i = 0, quantidade - 1 do
		local base = origin * CFrame.new(0, i * 0.42, 0) * CFrame.Angles(0, (i % 2) * 0.12, 0)
		for _, z in { -1.2, 0, 1.2 } do
			local runner = Build.block(
				"Travessa",
				v3(3, 0.3, 0.4),
				base * CFrame.new(0, 0.15, z),
				cores.MadeiraEscura,
				model,
				DETAIL
			)
			model.PrimaryPart = model.PrimaryPart or runner
		end
		for k = -2, 2 do
			Build.block(
				"Tabua",
				v3(0.5, 0.12, 3),
				base * CFrame.new(k * 0.625, 0.36, 0),
				if k % 2 == 0 then cores.Madeira else cores.MadeiraClara,
				model,
				DETAIL
			)
		end
	end
	return model
end

-- Lixeira de praça (1 × 1,3): corpo de 8 lados com tampa e duas cintas.
function Detalhe.Lixeira(parent: Instance, origin: CFrame, cores: Cores): Model
	local model = Build.model("Lixeira", parent)
	model.PrimaryPart = Build.prism("Corpo", 8, 1, 1.1, origin * CFrame.new(0, 0.55, 0), cores.Caixa, model, DETAIL)[1]
	for _, y in { 0.25, 0.85 } do
		Build.prism("Cinta", 8, 1.08, 0.12, origin * CFrame.new(0, y, 0), cores.CaixaEscura, model, DETAIL)
	end
	Build.prism("Tampa", 8, 1.15, 0.18, origin * CFrame.new(0, 1.2, 0), cores.Metal, model, DETAIL)
	return model
end

-- Pedrinhas soltas: 3 pedras baixas de 6 lados, em dois tons.
local PEBBLES = {
	-- { x, z, diâmetro, altura }
	{ 0, 0, 1.1, 0.5 },
	{ 0.9, 0.5, 0.7, 0.35 },
	{ -0.6, 0.8, 0.6, 0.3 },
}

function Detalhe.Pedrinhas(parent: Instance, origin: CFrame, cores: Cores): Model
	local model = Build.model("Pedrinhas", parent)
	for i, pebble in PEBBLES do
		local part = Build.prism(
			"Pedra",
			6,
			pebble[3],
			pebble[4],
			origin * CFrame.new(pebble[1], pebble[4] / 2, pebble[2]) * CFrame.Angles(0, i * 0.7, 0),
			if i == 2 then cores.PedraEscura else cores.Pedra,
			model,
			DETAIL
		)[1]
		model.PrimaryPart = model.PrimaryPart or part
	end
	return model
end

-- Luminárias ----------------------------------------------------------------------------------------

local function lamp(model: Model, at: CFrame, cores: Cores, luzReal: boolean?)
	Build.block("Cupula", v3(1.3, 0.45, 1.1), at, cores.Metal, model, DETAIL)
	local lens = Build.block("Lente", v3(1.1, 0.08, 0.9), at * CFrame.new(0, -0.26, 0), cores.LuzCreme, model, DETAIL)
	if luzReal then
		Detalhe.luz(lens, cores)
	end
end

-- Luminária de parede: `origin` no ponto da parede onde ela é presa (+Z local saindo da parede).
function Detalhe.Luminaria(parent: Instance, origin: CFrame, cores: Cores, luzReal: boolean?): Model
	local model = Build.model("Luminaria", parent)
	model.PrimaryPart =
		Build.block("Braco", v3(0.25, 0.25, 1), origin * CFrame.new(0, 0, 0.5), cores.Metal, model, DETAIL)
	lamp(model, origin * CFrame.new(0, 0, 1.3), cores, luzReal)
	return model
end

-- Luminária de teto: `origin` no teto; a cúpula fica `haste` abaixo dele (0 = colada no teto).
function Detalhe.LuminariaDeTeto(
	parent: Instance,
	origin: CFrame,
	cores: Cores,
	luzReal: boolean?,
	haste: number?
): Model
	local model = Build.model("LuminariaDeTeto", parent)
	local drop = haste or 0.6
	model.PrimaryPart = Build.block(
		"Haste",
		v3(0.15, math.max(drop, 0.1), 0.15),
		origin * CFrame.new(0, -math.max(drop, 0.1) / 2, 0),
		cores.Metal,
		model,
		DETAIL
	)
	lamp(model, origin * CFrame.new(0, -drop - 0.22, 0), cores, luzReal)
	return model
end

return Detalhe
