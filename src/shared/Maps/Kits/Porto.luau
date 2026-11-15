--!strict
-- Kit do Porto (KIT-MODULAR seção 2): um componente por função, cada um devolve um Model.
--
-- ETAPA DE PLANTA: cada componente é um bloco (ou poucos) já na cor e nas medidas do kit. Na etapa
-- de arte o detalhe (ondulação, portas, ferrugem, tábuas, treliça) entra AQUI DENTRO, sem mudar as
-- assinaturas nem a planta em Islands/Porto.
--
-- `origin` é o quadro do componente (use `Build.pivot`): fica na base, no centro, com o +Y para
-- cima. O que cada eixo local significa está no comentário de cada função.

local Build = require(script.Parent.Parent.Build)
local Theme = require(script.Parent.Parent.Parent.Config.Theme)

local PALETTE = Theme.Maps.Porto

local Kit = {}

-- Cores de contêiner do kit (nunca vermelho: é a cor do inimigo).
export type CorDeConteiner = "Laranja" | "Petroleo" | "Musgo" | "Mostarda"

local CONTAINER_COLORS: { [CorDeConteiner]: Color3 } = {
	Laranja = PALETTE.ConteinerLaranja,
	Petroleo = PALETTE.ConteinerPetroleo,
	Musgo = PALETTE.ConteinerMusgo,
	Mostarda = PALETTE.ConteinerMostarda,
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

local function containerBody(name: string, origin: CFrame, cor: CorDeConteiner, model: Model): Part
	return Build.block(
		name,
		Vector3.new(C_LEN, C_H, C_WID),
		origin * CFrame.new(0, C_H / 2, 0),
		CONTAINER_COLORS[cor],
		model
	)
end

-- Contêiner (20 × 8 × 8,5): cobertura cheia. Comprimento no X local; portas na face +X (arte).
function Kit.Conteiner(parent: Instance, origin: CFrame, cor: CorDeConteiner): Model
	local model = Build.model("Conteiner_" .. cor, parent)
	model.PrimaryPart = containerBody("Corpo", origin, cor, model)
	return model
end

-- Pilha de contêineres em ponte (2 de altura = 17): dois contêineres no chão, em linha no X local,
-- com um vão de 8 entre eles (passagem), e um terceiro em cima, no meio, apoiado 6 studs em cada
-- um. O topo dos de baixo que sobra (14 de cada lado) é a plataforma do nível 1; o topo do de cima
-- é o nível 2. `corA` é o contêiner do lado -X, `corB` o do +X.
function Kit.PilhaDeConteineres(
	parent: Instance,
	origin: CFrame,
	corA: CorDeConteiner,
	corB: CorDeConteiner,
	corTopo: CorDeConteiner
): Model
	local model = Build.model("PilhaDeConteineres", parent)
	local offset = (Kit.Pilha_Vao + C_LEN) / 2
	model.PrimaryPart = containerBody("BaseA", origin * CFrame.new(-offset, 0, 0), corA, model)
	containerBody("BaseB", origin * CFrame.new(offset, 0, 0), corB, model)
	containerBody("Topo", origin * CFrame.new(0, C_H, 0), corTopo, model)
	return model
end

-- Escada de metal: sobe no sentido do +X local, do nível de `origin` (pé, no centro da largura)
-- até `altura` acima, em `comprimento` studs. Colide como rampa lisa (melhor no celular); os degraus
-- e o corrimão entram na arte como acabamento.
function Kit.Escada(parent: Instance, origin: CFrame, comprimento: number, altura: number, largura: number): Model
	local model = Build.model("Escada", parent)
	model.PrimaryPart = Build.wedge(
		"Rampa",
		Vector3.new(largura, altura, comprimento),
		origin * CFrame.new(comprimento / 2, altura / 2, 0) * CFrame.Angles(0, math.pi / 2, 0),
		PALETTE.Metal,
		model
	)
	return model
end

-- Caixa de madeira: 6 (cobertura cheia; dá para subir pulando) ou 3 (meia altura).
function Kit.CaixaDeMadeira(parent: Instance, origin: CFrame, tamanho: number): Model
	assert(tamanho == 6 or tamanho == 3, "caixa de madeira de 6 ou de 3")
	local model = Build.model("CaixaDeMadeira_" .. tamanho, parent)
	model.PrimaryPart =
		Build.block("Caixa", Vector3.one * tamanho, origin * CFrame.new(0, tamanho / 2, 0), PALETTE.Madeira, model)
	return model
end

-- Barris (Ø 2,6 × 3,2, 8 lados), em grupo de 2 a 4: cobertura parcial. Não explodem.
-- Petróleo como cor principal; com 3 ou mais, o último é Mostarda.
local BARREL_SPOTS = { Vector2.new(-1.4, -1.2), Vector2.new(1.4, -1.2), Vector2.new(0, 1.3), Vector2.new(2.8, 1.3) }

function Kit.Barris(parent: Instance, origin: CFrame, quantidade: number): Model
	assert(quantidade >= 2 and quantidade <= #BARREL_SPOTS, "grupo de 2 a 4 barris")
	local model = Build.model("Barris", parent)
	for i = 1, quantidade do
		local spot = BARREL_SPOTS[i]
		local color = if i == quantidade and quantidade >= 3
			then PALETTE.ConteinerMostarda
			else PALETTE.ConteinerPetroleo
		local parts = Build.prism("Barril", 8, 2.6, 3.2, origin * CFrame.new(spot.X, 1.6, spot.Y), color, model)
		if i == 1 then
			model.PrimaryPart = parts[1]
		end
	end
	return model
end

-- Faixa de aviso de queda (amarela; as listras pretas entram na arte): 1 de largura, comprimento
-- no X local, deitada em cima do piso em `origin`. Só acabamento.
function Kit.FaixaDeAviso(parent: Instance, origin: CFrame, comprimento: number): Model
	local model = Build.model("FaixaDeAviso", parent)
	model.PrimaryPart = Build.block(
		"Faixa",
		Vector3.new(comprimento, 0.1, 1),
		origin * CFrame.new(0, 0.05, 0),
		PALETTE.Aviso,
		model,
		Build.Detail
	)
	return model
end

-- Píer de madeira: piso no nível de `origin` (topo das tábuas), comprimento no X local e largura no
-- Z local. O lado +Z encosta no cais; os outros três dão para a água e levam a faixa de aviso.
-- Estacas de 6 lados a cada 12 studs, do lado da água. A PrimaryPart é o piso (marcar como chão).
function Kit.PierDeMadeira(parent: Instance, origin: CFrame, comprimento: number, largura: number): Model
	local model = Build.model("PierDeMadeira", parent)
	model.PrimaryPart = Build.block(
		"Piso",
		Vector3.new(comprimento, 1, largura),
		origin * CFrame.new(0, -0.5, 0),
		PALETTE.Madeira,
		model
	)
	Kit.FaixaDeAviso(model, origin * CFrame.new(0, 0, -largura / 2 + 0.5), comprimento)
	for _, sign in { -1, 1 } do
		local edge = origin * CFrame.new(sign * (comprimento / 2 - 0.5), 0, 0.5) * CFrame.Angles(0, math.pi / 2, 0)
		Kit.FaixaDeAviso(model, edge, largura - 1)
	end
	local reach = math.floor((comprimento / 2 - 1) / 12)
	for k = -reach, reach do
		local at = origin * CFrame.new(k * 12, -5, -largura / 2 + 1)
		Build.prism("Estaca", 6, 1.2, 8, at, PALETTE.Madeira, model, Build.Detail)
	end
	return model
end

-- Água chapada: placa com o topo no nível de `origin`, comprimento no X local e largura no Z local.
-- Não colide e não bloqueia tiro: quem cai atravessa e volta à base (queda detectada por altura).
function Kit.Agua(parent: Instance, origin: CFrame, comprimento: number, largura: number): Model
	local model = Build.model("Agua", parent)
	model.PrimaryPart = Build.block(
		"Agua",
		Vector3.new(comprimento, 1, largura),
		origin * CFrame.new(0, -0.5, 0),
		PALETTE.Agua,
		model,
		Build.Detail
	)
	return model
end

-- Parede de chapa (16 × 1 × 12): bloqueia a visão. Comprimento no X local.
function Kit.ParedeDeChapa(parent: Instance, origin: CFrame): Model
	local model = Build.model("ParedeDeChapa", parent)
	local height = Kit.Parede_Altura
	model.PrimaryPart = Build.block(
		"Chapa",
		Vector3.new(Kit.Parede_Comprimento, height, 1),
		origin * CFrame.new(0, height / 2, 0),
		PALETTE.Chapa,
		model
	)
	return model
end

-- Torre do guindaste (4 × 4, módulos de 4 de altura), com plataforma no topo. `lanca` (opcional) é
-- o comprimento da lança no topo, no sentido do +X local (só acabamento: fica acima de tudo).
function Kit.TorreDoGuindaste(parent: Instance, origin: CFrame, modulos: number, lanca: number?): Model
	local model = Build.model("TorreDoGuindaste", parent)
	local side = Kit.Torre_Modulo
	local height = modulos * side
	model.PrimaryPart = Build.block(
		"Torre",
		Vector3.new(side, height, side),
		origin * CFrame.new(0, height / 2, 0),
		PALETTE.Guindaste,
		model
	)
	Build.block(
		"Plataforma",
		Vector3.new(side + 1, 0.5, side + 1),
		origin * CFrame.new(0, height + 0.25, 0),
		PALETTE.Metal,
		model
	)
	if lanca and lanca > 0 then
		-- começa 4 studs atrás do eixo da torre (contrapeso)
		Build.block(
			"Lanca",
			Vector3.new(lanca, 2, 2),
			origin * CFrame.new(lanca / 2 - side, height + 1.5, 0),
			PALETTE.Guindaste,
			model,
			Build.Detail
		)
	end
	return model
end

-- Cabeço de amarração (4 × 4 × 2,6): detalhe da borda do píer. Só a base baixa colide.
function Kit.CabecoDeAmarracao(parent: Instance, origin: CFrame): Model
	local model = Build.model("CabecoDeAmarracao", parent)
	model.PrimaryPart =
		Build.block("Base", Vector3.new(4, 0.5, 4), origin * CFrame.new(0, 0.25, 0), PALETTE.Concreto, model)
	Build.prism("Poste", 8, 2, 2.1, origin * CFrame.new(0, 1.55, 0), PALETTE.Metal, model, Build.Detail)
	return model
end

return Kit
