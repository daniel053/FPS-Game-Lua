--!strict
-- Kit da Fábrica (KIT-MODULAR seção 3): um componente por função, cada um devolve um Model.
--
-- As peças que colidem são as da planta aprovada (caixas, cunhas e prismas simples). O acabamento
-- (ondulação, juntas, setas, faixas zebradas, flanges, botões) é `Build.Detail`: não colide, não
-- bloqueia tiro e sai no máximo ~0,15 stud da peça que colide. Cores só de `Theme.Maps.Fabrica`;
-- material liso, sem neon, sem luz e sem texto (setas e faixas zebradas no lugar de palavras).
--
-- Todo componente recebe `origin` (use `Build.pivot`): o ponto no chão, no centro da base do
-- componente. O comprimento fica no eixo X local e a profundidade no eixo Z local. O `Model`
-- devolvido tem o pivô em `origin`.

local Build = require(script.Parent.Parent.Build)
local Theme = require(script.Parent.Parent.Parent.Config.Theme)

local C = Theme.Maps.Fabrica
local DETAIL = Build.Detail
local SIGNS = { -1, 1 }

local v2 = Vector2.new
local v3 = Vector3.new

local Kit = {}

-- Atributo da correia da esteira: `Vector3` unitário com o sentido, no espaço do mundo. Quem
-- carrega o jogador e as caixas é o servidor da partida (`match/server/Conveyors`, GDD 15.5).
Kit.ConveyorAttribute = "Conveyor"
-- Atributo da caixa de papelão que anda na esteira (na peça que colide).
Kit.ConveyorBoxAttribute = "ConveyorBox"

-- Faixa zebrada: listras escuras de 0,5 a cada 1 stud, ao longo do X local de `origin`, sobre uma
-- peça amarela de `length` × `height` × `depth` centrada em `origin` (as listras atravessam a
-- profundidade e aparecem nas duas faces).
local function zebra(model: Model, origin: CFrame, length: number, height: number, depth: number)
	local x = -length / 2 + 0.75
	while x + 0.25 <= length / 2 do
		Build.block(
			"Listra",
			v3(0.5, height + 0.04, depth + 0.04),
			origin * CFrame.new(x, 0, 0),
			C.Metal,
			model,
			DETAIL
		)
		x += 1
	end
end

-- Linhas finas atravessadas num piso (grade ou correia): a cada `step` studs ao longo do X local,
-- com a espessura da peça (aparecem em cima e embaixo).
local function crossLines(
	model: Model,
	origin: CFrame,
	length: number,
	width: number,
	thickness: number,
	step: number,
	color: Color3
)
	local reach = math.floor((length / 2 - 0.5) / step)
	for k = -reach, reach do
		Build.block(
			"Linha",
			v3(0.12, thickness + 0.04, width),
			origin * CFrame.new(k * step, 0, 0),
			color,
			model,
			DETAIL
		)
	end
end

-- Medidas do kit que a planta precisa conhecer para encaixar as peças.
Kit.Sizes = {
	NivelDaPassarela = 6, -- topo do piso da passarela e da plataforma (nível 1)
	GuardaCorpo = 3.2,
	AlturaDaEsteira = 2.5, -- topo da correia (as caixas ficam em cima)
	Plataforma = v2(28, 6), -- comprimento × largura
	AberturaDaPlataforma = 6, -- vão no guarda-corpo, no meio de cada lado comprido
	LarguraDaRampa = 6,
}

export type PassarelaOptions = {
	width: number?, -- largura do piso (padrão do kit: 3)
	pillars: { number }?, -- posição dos pares de pilares ao longo do comprimento (0 = meio)
	rails: boolean?, -- false = sem guarda-corpo
}

-- Pivô do modelo no ponto de origem (base, centro), como pede o KIT-MODULAR seção 0.
local function finish(model: Model, primary: BasePart, origin: CFrame): Model
	primary.PivotOffset = primary.CFrame:ToObjectSpace(origin)
	model.PrimaryPart = primary
	return model
end

-- Guarda-corpo amarelo de 3,2 (aberto: postes, corrimão e barra do meio). O corrimão segura o
-- jogador; o tiro passa entre as barras e por cima. `points` em (x, z) locais; `baseY` = piso.
local function guardRail(model: Model, origin: CFrame, points: { Vector2 }, baseY: number)
	local height = Kit.Sizes.GuardaCorpo
	local function post(p: Vector2)
		Build.block("Poste", v3(0.4, height, 0.4), origin * CFrame.new(p.X, baseY + height / 2, p.Y), C.Aviso, model)
	end
	for i, p in points do
		post(p)
		local nextPoint = points[i + 1]
		if nextPoint then
			Build.wall("Corrimao", origin, p, nextPoint, 0.4, 0.4, C.Aviso, model, baseY + height - 0.4)
			Build.wall("BarraDoMeio", origin, p, nextPoint, 0.3, 0.3, C.Aviso, model, baseY + 1.4, Build.Detail)
			local spans = math.ceil((nextPoint - p).Magnitude / 4)
			for k = 1, spans - 1 do
				post(p:Lerp(nextPoint, k / spans))
			end
		end
	end
end

-- Parede De Galpão: 16 × 1 × 12. Bloqueia visão. Frente no +Z local.
function Kit.ParedeDeGalpao(parent: Instance, origin: CFrame): Model
	local model = Build.model("ParedeDeGalpao", parent)
	local base = Build.block("Tijolo", v3(16, 4, 1), origin * CFrame.new(0, 2, 0), C.Tijolo, model)
	Build.block("Painel", v3(16, 7, 1), origin * CFrame.new(0, 7.5, 0), C.Painel, model)
	Build.block("Topo", v3(16, 1, 1.2), origin * CFrame.new(0, 11.5, 0), C.Metal, model)
	for _, side in SIGNS do
		Build.block("Janelas", v3(14, 2, 0.1), origin * CFrame.new(0, 9, side * 0.55), C.Janela, model, DETAIL)
	end
	-- Caixilhos entre as janelas (4 folhas de cada lado)
	for _, x in { -7, -3.5, 0, 3.5, 7 } do
		Build.block("Caixilho", v3(0.4, 2.3, 1.26), origin * CFrame.new(x, 9, 0), C.Metal, model, DETAIL)
	end
	-- Ondulação larga do painel: uma nervura a cada 2 studs (para na faixa das janelas)
	for k = -3, 3 do
		Build.block("Ondulacao", v3(0.35, 3.8, 1.1), origin * CFrame.new(k * 2, 5.95, 0), C.PainelEscuro, model, DETAIL)
		Build.block("Ondulacao", v3(0.35, 0.9, 1.1), origin * CFrame.new(k * 2, 10.5, 0), C.PainelEscuro, model, DETAIL)
	end
	-- Tijolo: 3 juntas deitadas e as juntas em pé, em amarração
	for row = 1, 4 do
		if row < 4 then
			Build.block("Junta", v3(16.06, 0.1, 1.1), origin * CFrame.new(0, row, 0), C.TijoloEscuro, model, DETAIL)
		end
		local shift = if row % 2 == 0 then 0 else 2
		for x = -6 + shift, 6, 4 do
			Build.block("Junta", v3(0.1, 1, 1.1), origin * CFrame.new(x, row - 0.5, 0), C.TijoloEscuro, model, DETAIL)
		end
	end
	return finish(model, base, origin)
end

-- Esteira: 20 × 4 × 2,5. Meia altura; anda no sentido +X local (atributo `Conveyor` na correia).
function Kit.Esteira(parent: Instance, origin: CFrame): Model
	local model = Build.model("Esteira", parent)
	local top = Kit.Sizes.AlturaDaEsteira
	local base = Build.block("Base", v3(20, top - 0.5, 3.6), origin * CFrame.new(0, (top - 0.5) / 2, 0), C.Metal, model)
	local belt = Build.block("Correia", v3(20, 0.5, 3.2), origin * CFrame.new(0, top - 0.25, 0), C.Borracha, model)
	belt:SetAttribute(Kit.ConveyorAttribute, origin:VectorToWorldSpace(Vector3.xAxis))
	for _, side in SIGNS do
		local rail = origin * CFrame.new(0, top - 0.25, side * 1.8)
		Build.block("Lateral", v3(20, 0.5, 0.4), rail, C.Aviso, model)
		zebra(model, rail, 20, 0.5, 0.4)
	end
	-- Emendas da correia e 3 setas amarelas no sentido do movimento (+X local)
	local surface = origin * CFrame.new(0, top, 0)
	crossLines(model, origin * CFrame.new(0, top - 0.25, 0), 20, 3.2, 0.5, 2, C.Metal)
	for _, x in { -6, 0, 6 } do
		for _, side in SIGNS do
			Build.block(
				"Seta",
				v3(1.7, 0.06, 0.4),
				surface * CFrame.new(x, 0.03, side * 0.52) * CFrame.Angles(0, side * math.rad(38), 0),
				C.Aviso,
				model,
				DETAIL
			)
		end
	end
	-- Pés mais escuros e faixa de segurança pintada no chão, em volta
	for _, x in { -8, 0, 8 } do
		Build.block("Pe", v3(1, top - 0.5, 3.7), origin * CFrame.new(x, (top - 0.5) / 2, 0), C.Borracha, model, DETAIL)
	end
	for _, side in SIGNS do
		Build.block("Seguranca", v3(22.4, 0.04, 0.4), origin * CFrame.new(0, 0.02, side * 3), C.Aviso, model, DETAIL)
		Build.block("Seguranca", v3(0.4, 0.04, 5.6), origin * CFrame.new(side * 11, 0.02, 0), C.Aviso, model, DETAIL)
	end
	return finish(model, base, origin)
end

-- Caixa Na Esteira: cubo de papelão de 2,6 ("grande") ou 2,2 ("pequena"). `origin` em cima da correia.
function Kit.CaixaNaEsteira(parent: Instance, origin: CFrame, tamanho: "grande" | "pequena"): Model
	local model = Build.model("CaixaNaEsteira", parent)
	local size = if tamanho == "grande" then 2.6 else 2.2
	local center = origin * CFrame.new(0, size / 2, 0)
	local box = Build.block("Caixa", Vector3.one * size, center, C.Papelao, model)
	box:SetAttribute(Kit.ConveyorBoxAttribute, true)
	-- Fita no meio (dá a volta na caixa) e etiqueta escura sem texto
	Build.block("Fita", v3(0.5, size + 0.06, size + 0.06), center, C.PapelaoEscuro, model, DETAIL)
	Build.block(
		"Etiqueta",
		v3(0.06, size * 0.25, size * 0.3),
		center * CFrame.new(size / 2, -size * 0.2, size * 0.2),
		C.Borracha,
		model,
		DETAIL
	)
	return finish(model, box, origin)
end

local SHELF_LEVELS = { 0.8, 4.8, 8.8 }
-- Caixas variadas em cada nível (não sobem até o nível de cima: deixam frestas)
local SHELF_BOXES: { { { x: number, w: number, h: number, color: Color3 } } } = {
	{
		{ x = -3.1, w = 2.6, h = 3, color = C.Papelao },
		{ x = -0.3, w = 2.4, h = 2.2, color = C.PapelaoEscuro },
		{ x = 2.9, w = 3, h = 3.4, color = C.Papelao },
	},
	{
		{ x = -2.9, w = 3, h = 2.6, color = C.Maquina },
		{ x = 0.4, w = 2.2, h = 3.2, color = C.Papelao },
		{ x = 3.1, w = 2.4, h = 2.4, color = C.PapelaoEscuro },
	},
	{
		{ x = -3, w = 2.8, h = 2.3, color = C.Papelao },
		{ x = 0.1, w = 2.6, h = 2.6, color = C.Painel },
		{ x = 3.2, w = 2.2, h = 2.1, color = C.Papelao },
	},
}

-- Prateleira Alta: 10 × 3 × 12. Bloqueia visão (a carga fecha até 11; os montantes vão até 12).
function Kit.PrateleiraAlta(parent: Instance, origin: CFrame): Model
	local model = Build.model("PrateleiraAlta", parent)
	-- O miolo que colide é escuro (a sombra entre as caixas); as caixas são placas que atravessam a
	-- profundidade e aparecem dos dois lados. As do nível de cima passam do miolo: vistas do mirante.
	local cargo = Build.block("Carga", v3(9, 11, 2.6), origin * CFrame.new(0, 5.5, 0), C.Borracha, model)
	for _, side in SIGNS do
		Build.block("Montante", v3(0.5, 12, 3), origin * CFrame.new(side * 4.75, 6, 0), C.Tubos, model)
	end
	for level, y in SHELF_LEVELS do
		Build.block("Nivel", v3(9, 0.4, 3), origin * CFrame.new(0, y, 0), C.Metal, model, DETAIL)
		for _, box in SHELF_BOXES[level] do
			Build.block(
				"CaixaNaPrateleira",
				v3(box.w, box.h, 2.74),
				origin * CFrame.new(box.x, y + 0.2 + box.h / 2, 0),
				box.color,
				model,
				DETAIL
			)
		end
	end
	return finish(model, cargo, origin)
end

-- Tubulação: 8 × 4 × 10,5. Cobertura cheia. As costas (-Z local) encostam numa parede.
function Kit.Tubulacao(parent: Instance, origin: CFrame): Model
	local model = Build.model("Tubulacao", parent)
	local base = Build.block("Base", v3(8, 0.5, 4), origin * CFrame.new(0, 0.25, 0), C.Piso, model)
	for _, side in { -1, 1 } do
		Build.prism("Tubo", 8, 2.6, 8.5, origin * CFrame.new(side * 2.6, 4.75, 0), C.Maquina, model)
	end
	Build.prism("TuboDoMeio", 8, 2.6, 7, origin * CFrame.new(0, 4, 0), C.Tubos, model)
	Build.block("Travessa", v3(8, 1.5, 2.6), origin * CFrame.new(0, 9.75, 0), C.Maquina, model)
	-- Flanges (anéis mais escuros) e o registro amarelo no tubo do meio
	for _, side in SIGNS do
		for _, y in { 2, 5, 8 } do
			Build.prism("Flange", 8, 2.9, 0.3, origin * CFrame.new(side * 2.6, y, 0), C.MaquinaEscura, model, DETAIL)
		end
	end
	for _, y in { 2.2, 5.8 } do
		Build.prism("Flange", 8, 2.9, 0.3, origin * CFrame.new(0, y, 0), C.TubosEscuro, model, DETAIL)
	end
	Build.prism(
		"Registro",
		6,
		1.3,
		0.4,
		origin * CFrame.new(0, 4, 1.5) * CFrame.Angles(math.pi / 2, 0, 0),
		C.Aviso,
		model,
		DETAIL
	)
	return finish(model, base, origin)
end

-- Passarela Com Grade: trecho de `length` no eixo X local, piso no nível 1 (6 studs) sobre pilares,
-- guarda-corpo de 3,2 nos dois lados. Passa-se por baixo (vão livre de 5,5).
function Kit.PassarelaComGrade(parent: Instance, origin: CFrame, length: number, options: PassarelaOptions?): Model
	local model = Build.model("PassarelaComGrade", parent)
	local level = Kit.Sizes.NivelDaPassarela
	local width = if options and options.width then options.width else 3
	local deck = Build.block("Piso", v3(length, 0.5, width), origin * CFrame.new(0, level - 0.25, 0), C.Painel, model)
	local pillars = options and options.pillars
	if pillars == nil then
		-- pares nas pontas e, no meio, a cada 12 studs no máximo (módulo do kit)
		local list = {}
		local spans = math.max(1, math.ceil((length - 1) / 12))
		for k = 0, spans do
			table.insert(list, -(length - 1) / 2 + (length - 1) * k / spans)
		end
		pillars = list
	end
	for _, x in pillars :: { number } do
		for _, side in { -1, 1 } do
			local z = side * (width / 2 - 0.5)
			Build.block("Pilar", v3(1, level - 0.5, 1), origin * CFrame.new(x, (level - 0.5) / 2, z), C.Metal, model)
		end
	end
	-- Piso de grade: linhas atravessadas e duas ao comprido
	local deckCenter = origin * CFrame.new(0, level - 0.25, 0)
	crossLines(model, deckCenter, length, width, 0.5, 1.5, C.PainelEscuro)
	for _, side in SIGNS do
		Build.block(
			"Linha",
			v3(length, 0.54, 0.12),
			deckCenter * CFrame.new(0, 0, side * width / 6),
			C.PainelEscuro,
			model,
			DETAIL
		)
	end
	if not (options and options.rails == false) then
		local hx = length / 2 - 0.2
		for _, side in { -1, 1 } do
			local z = side * (width / 2 - 0.2)
			guardRail(model, origin, { v2(-hx, z), v2(hx, z) }, level)
		end
	end
	return finish(model, deck, origin)
end

-- Plataforma De Controle (pedido de registro no KIT-MODULAR): 28 × 6 × 6, bloco fechado (cobertura
-- cheia para quem está no chão) com piso de grade em cima (nível 1) e guarda-corpo em volta, com um
-- vão de 6 no meio de cada lado comprido (de um lado chega a rampa, do outro sai a passarela).
function Kit.PlataformaDeControle(parent: Instance, origin: CFrame): Model
	local model = Build.model("PlataformaDeControle", parent)
	local size = Kit.Sizes.Plataforma
	local level = Kit.Sizes.NivelDaPassarela
	local body = Build.block(
		"Corpo",
		v3(size.X, level - 0.5, size.Y),
		origin * CFrame.new(0, (level - 0.5) / 2, 0),
		C.Tijolo,
		model
	)
	Build.block("Piso", v3(size.X, 0.5, size.Y), origin * CFrame.new(0, level - 0.25, 0), C.Painel, model)
	-- Tijolo com juntas deitadas, janelas chapadas nas pontas dos lados compridos e piso de grade
	for _, y in { 1.4, 2.8, 4.2 } do
		Build.block(
			"Junta",
			v3(size.X + 0.06, 0.1, size.Y + 0.06),
			origin * CFrame.new(0, y, 0),
			C.TijoloEscuro,
			model,
			DETAIL
		)
	end
	for _, side in SIGNS do
		local window = origin * CFrame.new(side * 8.5, 3.5, 0)
		Build.block("Janelas", v3(7, 1.6, size.Y + 0.1), window, C.Janela, model, DETAIL)
		Build.block("Caixilho", v3(0.4, 1.9, size.Y + 0.14), window, C.Metal, model, DETAIL)
	end
	crossLines(model, origin * CFrame.new(0, level - 0.25, 0), size.X, size.Y, 0.5, 2, C.PainelEscuro)
	local hx, hz = size.X / 2 - 0.2, size.Y / 2 - 0.2
	local gap = Kit.Sizes.AberturaDaPlataforma / 2 + 0.2
	for _, side in { -1, 1 } do
		guardRail(
			model,
			origin,
			{ v2(side * gap, hz), v2(side * hx, hz), v2(side * hx, -hz), v2(side * gap, -hz) },
			level
		)
	end
	return finish(model, body, origin)
end

-- Rampa De Acesso (pedido de registro no KIT-MODULAR): subida sem carta até o nível 1. `origin` no
-- chão, embaixo da ponta alta; a rampa desce para o +X local ao longo de `run` studs.
function Kit.RampaDeAcesso(parent: Instance, origin: CFrame, run: number): Model
	local model = Build.model("RampaDeAcesso", parent)
	local ramp = Build.ramp(
		"Rampa",
		origin,
		v2(run, 0),
		Vector2.zero,
		0,
		Kit.Sizes.NivelDaPassarela,
		Kit.Sizes.LarguraDaRampa,
		C.Painel,
		model
	)
	-- Travessas antiderrapantes e laterais amarelas (aviso de beira)
	local level, width = Kit.Sizes.NivelDaPassarela, Kit.Sizes.LarguraDaRampa
	local strips = math.max(2, math.floor(run / 1.5))
	for i = 1, strips do
		local x = (i - 0.5) * run / strips
		Build.block(
			"Travessa",
			v3(0.3, 0.12, width - 0.8),
			origin * CFrame.new(x, level * (1 - x / run) + 0.02, 0),
			C.Metal,
			model,
			DETAIL
		)
	end
	local slope = math.atan2(level, run)
	local length = math.sqrt(run * run + level * level)
	for _, side in SIGNS do
		Build.block(
			"Lateral",
			v3(length, 0.4, 0.3),
			origin
				* CFrame.new(run / 2, level / 2, side * (width / 2 - 0.15))
				* CFrame.Angles(0, 0, -slope)
				* CFrame.new(0, 0.1, 0),
			C.Aviso,
			model,
			DETAIL
		)
	end
	return finish(model, ramp, origin)
end

-- Máquina: 7 × 5 × 7,5. Cobertura cheia (corpo até 6). Painel na frente (+Z local).
function Kit.Maquina(parent: Instance, origin: CFrame): Model
	local model = Build.model("Maquina", parent)
	local base = Build.block("Base", v3(7, 0.5, 5), origin * CFrame.new(0, 0.25, 0), C.Piso, model)
	Build.block("Corpo", v3(6.4, 5.5, 4.4), origin * CFrame.new(0, 3.25, 0), C.Maquina, model)
	Build.block("Tampa", v3(3.4, 0.8, 2.6), origin * CFrame.new(-1, 6.4, 0), C.Maquina, model)
	Build.prism("Chamine", 6, 1, 1.5, origin * CFrame.new(2.2, 6.75, 0.8), C.Metal, model)
	Build.block("Painel", v3(2.4, 1.4, 0.1), origin * CFrame.new(-1.2, 3.8, 2.25), C.Borracha, model, DETAIL)
	-- Botões chapados (sem luz) ao lado do painel
	for i, color in { C.Aviso, C.Painel, C.Tubos } do
		Build.block("Botao", v3(0.4, 0.4, 0.1), origin * CFrame.new(0.4 + i * 0.7, 3.8, 2.25), color, model, DETAIL)
	end
	-- Faixa zebrada na base (nas 4 faces) e frisos mais escuros
	local band = origin * CFrame.new(0, 1, 0)
	Build.block("Faixa", v3(6.5, 0.6, 4.5), band, C.Aviso, model, DETAIL)
	zebra(model, band, 6.5, 0.6, 4.5)
	zebra(model, band * CFrame.Angles(0, math.pi / 2, 0), 4.5, 0.6, 6.5)
	for _, y in { 5.85, 3 } do
		Build.block("Friso", v3(6.5, 0.2, 4.5), origin * CFrame.new(0, y, 0), C.MaquinaEscura, model, DETAIL)
	end
	return finish(model, base, origin)
end

-- Pallet Com Tambores: 6 × 5 × 3,5. Meia altura.
function Kit.PalletComTambores(parent: Instance, origin: CFrame): Model
	local model = Build.model("PalletComTambores", parent)
	local pallet = Build.block("Pallet", v3(6, 0.5, 5), origin * CFrame.new(0, 0.25, 0), C.Papelao, model)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local color = if sx == sz then C.Painel else C.Tubos
			local at = origin * CFrame.new(sx * 1.3, 0.5, sz * 1.2)
			Build.prism("Tambor", 8, 2.4, 3, at * CFrame.new(0, 1.5, 0), color, model)
			for _, y in { 0.8, 2.2 } do
				Build.prism("Cinta", 8, 2.54, 0.25, at * CFrame.new(0, y, 0), C.Metal, model, DETAIL)
			end
		end
	end
	-- Frestas entre as tábuas do pallet
	for _, z in { -1.25, 0, 1.25 } do
		Build.block("Fresta", v3(6.04, 0.54, 0.2), origin * CFrame.new(0, 0.25, z), C.PapelaoEscuro, model, DETAIL)
	end
	return finish(model, pallet, origin)
end

return Kit
