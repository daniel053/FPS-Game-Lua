--!strict
-- Kit da Fábrica (KIT-MODULAR seção 3), etapa de PLANTA: cada componente em poucos blocos, já na cor
-- e nas medidas do kit. Na etapa de arte o detalhe (ondulação, setas, faixas zebradas, flanges,
-- botões) entra AQUI DENTRO, sem mexer na planta: as assinaturas já são as finais.
--
-- Todo componente recebe `origin` (use `Build.pivot`): o ponto no chão, no centro da base do
-- componente. O comprimento fica no eixo X local e a profundidade no eixo Z local. O `Model`
-- devolvido tem o pivô em `origin`.

local Build = require(script.Parent.Parent.Build)
local Theme = require(script.Parent.Parent.Parent.Config.Theme)

local C = Theme.Maps.Fabrica

local v2 = Vector2.new
local v3 = Vector3.new

local Kit = {}

-- Atributo da correia da esteira: `Vector3` unitário com o sentido, no espaço do mundo. O sistema
-- que carrega o jogador e as caixas entra depois (GDD 15.5); aqui é só a marca.
Kit.ConveyorAttribute = "Conveyor"

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
	for _, side in { -1, 1 } do
		Build.block("Janelas", v3(14, 2, 0.1), origin * CFrame.new(0, 9, side * 0.55), C.Janela, model, Build.Detail)
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
	for _, side in { -1, 1 } do
		Build.block("Lateral", v3(20, 0.5, 0.4), origin * CFrame.new(0, top - 0.25, side * 1.8), C.Aviso, model)
	end
	return finish(model, base, origin)
end

-- Caixa Na Esteira: cubo de papelão de 2,6 ("grande") ou 2,2 ("pequena"). `origin` em cima da correia.
function Kit.CaixaNaEsteira(parent: Instance, origin: CFrame, tamanho: "grande" | "pequena"): Model
	local model = Build.model("CaixaNaEsteira", parent)
	local size = if tamanho == "grande" then 2.6 else 2.2
	local box = Build.block("Caixa", Vector3.one * size, origin * CFrame.new(0, size / 2, 0), C.Papelao, model)
	return finish(model, box, origin)
end

-- Prateleira Alta: 10 × 3 × 12. Bloqueia visão (a carga fecha até 11; os montantes vão até 12).
function Kit.PrateleiraAlta(parent: Instance, origin: CFrame): Model
	local model = Build.model("PrateleiraAlta", parent)
	local cargo = Build.block("Carga", v3(9, 11, 2.6), origin * CFrame.new(0, 5.5, 0), C.Papelao, model)
	for _, side in { -1, 1 } do
		Build.block("Montante", v3(0.5, 12, 3), origin * CFrame.new(side * 4.75, 6, 0), C.Tubos, model)
	end
	for _, y in { 0.8, 4.8, 8.8 } do
		Build.block("Nivel", v3(9, 0.4, 3), origin * CFrame.new(0, y, 0), C.Metal, model, Build.Detail)
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
	return finish(model, ramp, origin)
end

-- Máquina: 7 × 5 × 7,5. Cobertura cheia (corpo até 6). Painel na frente (+Z local).
function Kit.Maquina(parent: Instance, origin: CFrame): Model
	local model = Build.model("Maquina", parent)
	local base = Build.block("Base", v3(7, 0.5, 5), origin * CFrame.new(0, 0.25, 0), C.Piso, model)
	Build.block("Corpo", v3(6.4, 5.5, 4.4), origin * CFrame.new(0, 3.25, 0), C.Maquina, model)
	Build.block("Tampa", v3(3.4, 0.8, 2.6), origin * CFrame.new(-1, 6.4, 0), C.Maquina, model)
	Build.prism("Chamine", 6, 1, 1.5, origin * CFrame.new(2.2, 6.75, 0.8), C.Metal, model)
	Build.block("Painel", v3(2.4, 1.4, 0.1), origin * CFrame.new(-1.2, 3.8, 2.25), C.Borracha, model, Build.Detail)
	return finish(model, base, origin)
end

-- Pallet Com Tambores: 6 × 5 × 3,5. Meia altura.
function Kit.PalletComTambores(parent: Instance, origin: CFrame): Model
	local model = Build.model("PalletComTambores", parent)
	local pallet = Build.block("Pallet", v3(6, 0.5, 5), origin * CFrame.new(0, 0.25, 0), C.Papelao, model)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local color = if sx == sz then C.Painel else C.Tubos
			Build.prism("Tambor", 8, 2.4, 3, origin * CFrame.new(sx * 1.3, 2, sz * 1.2), color, model)
		end
	end
	return finish(model, pallet, origin)
end

return Kit
