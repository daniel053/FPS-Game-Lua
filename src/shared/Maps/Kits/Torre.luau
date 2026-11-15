--!strict
-- Kit da Torre (KIT-MODULAR seção 5): castelinho em ruínas. Um componente por função, cada um
-- devolve um Model.
--
-- As peças que colidem são as da planta aprovada (blocos e rampas simples). O acabamento (juntas
-- dos blocos de pedra, musgo, tábuas, correntes, folhas de porta) é `Build.Detail`: não colide,
-- não bloqueia tiro e sai no máximo ~0,15 stud da peça que colide. Cores só de `Theme.Maps.Torre`;
-- material liso, sem neon, sem luz e sem texto.
--
-- Convenção de todos os componentes:
--   * `origem` = quadro no centro da base do componente (use `Build.pivot`), no nível do piso;
--   * comprimento/largura no eixo X local; a "frente" (ou o sentido de subida/travessia) é o +Z local;
--   * todo componente é simétrico no X local. Assim a cópia espelhada da planta (x → -x) é o mesmo
--     componente com o giro trocado de sinal (a Torre usa simetria espelhada).

local Build = require(script.Parent.Parent.Build)
local Theme = require(script.Parent.Parent.Parent.Config.Theme)

local COR = Theme.Maps.Torre
local DETALHE = Build.Detail
local LADOS = { -1, 1 }

local Kit = {}

-- Medidas do KIT-MODULAR 5 (studs)
Kit.Medidas = {
	MuralhaComprimento = 16,
	MuralhaEspessura = 3,
	MuralhaAltura = 10,
	AmeiasAltura = 8.5, -- nível 1 do mapa: topo do caminho da muralha com ameias
	AmeiasCaminho = 4, -- largura livre do caminho
	Merlao = Vector3.new(2, 2.5, 1), -- comprimento × altura × espessura
	MerlaoPasso = 4, -- um merlão a cada 4 studs
	Peitoril = 1.5, -- mureta contínua embaixo dos merlões (segura quem anda de costas)
	Degrau = 0.9, -- altura máxima de um degrau
	DegrauFundo = 1.5,
	EscadariaAltura = 7.2, -- módulo do kit: 8 degraus (12 × 6)
	EscadariaLargura = 6, -- com as duas muretas de 1
	PonteComprimento = 10,
	PonteLargura = 5,
	PortaLargura = 10,
	PortaEspessura = 2,
	PortaAltura = 10,
	PortaVao = Vector2.new(4, 6.5), -- largura × altura da passagem
	EstandarteAltura = 11,
	EscombrosMuro = Vector3.new(5, 3.5, 2),
}

local M = Kit.Medidas

local function principal(model: Model, part: BasePart): Model
	model.PrimaryPart = part
	return model
end

-- Blocos grandes do kit (3,2 × 1,6), em fileiras alternadas
local BLOCO = { Comprimento = 3.2, Altura = 1.6, Junta = 0.12 }

-- Juntas dos blocos de pedra numa parede. `centro` é o centro da parede: largura no X local, altura
-- no Y, espessura no Z. As juntas atravessam a espessura e aparecem 0,05 para fora nas duas faces.
-- Para uma face só (parede maciça), passe o centro NA face e `espessura` = 0.
function Kit.Juntas(parent: Instance, centro: CFrame, largura: number, altura: number, espessura: number, cor: Color3?)
	local tom = cor or COR.PedraJunta
	local fiadas = math.max(1, math.floor(altura / BLOCO.Altura + 0.5))
	local passo = altura / fiadas
	local fundo = espessura + 0.1
	for i = 1, fiadas do
		local y = -altura / 2 + i * passo
		if i < fiadas then
			Build.block(
				"Junta",
				Vector3.new(largura - 0.04, BLOCO.Junta, fundo),
				centro * CFrame.new(0, y, 0),
				tom,
				parent,
				DETALHE
			)
		end
		local x = -largura / 2 + (if i % 2 == 0 then BLOCO.Comprimento else BLOCO.Comprimento / 2)
		while x <= largura / 2 - 0.8 do
			Build.block(
				"Junta",
				Vector3.new(BLOCO.Junta, passo, fundo),
				centro * CFrame.new(x, y - passo / 2, 0),
				tom,
				parent,
				DETALHE
			)
			x += BLOCO.Comprimento
		end
	end
end

-- Manchas de musgo na base de uma parede (só embaixo): `pe` é o meio do pé da parede, largura no X.
local function musgoNaBase(model: Model, pe: CFrame, largura: number, espessura: number)
	local manchas = { { -0.3, 0.32, 0.9 }, { 0.12, 0.2, 0.5 }, { 0.36, 0.16, 1.2 } } -- { posição, largura, altura }
	for _, mancha in manchas do
		local w = math.max(0.8, largura * mancha[2])
		Build.block(
			"Musgo",
			Vector3.new(w, mancha[3], espessura + 0.2),
			pe * CFrame.new(largura * mancha[1], mancha[3] / 2, 0),
			COR.Musgo,
			model,
			DETALHE
		)
	end
end

-- Muralha De Pedra (16 × 3 × 10): bloqueia visão. Comprimento no X local. Em ruína a altura varia:
-- 10 = muralha inteira; 3,5 = mureta de meia altura.
function Kit.MuralhaDePedra(parent: Instance, origem: CFrame, comprimento: number?, altura: number?): Model
	local model = Build.model("MuralhaDePedra", parent)
	local l = comprimento or M.MuralhaComprimento
	local h = altura or M.MuralhaAltura
	local e = M.MuralhaEspessura
	local capa = 0.5
	local corpo =
		Build.block("Corpo", Vector3.new(l, h - capa, e), origem * CFrame.new(0, (h - capa) / 2, 0), COR.Pedra, model)
	Build.block("Capa", Vector3.new(l, capa, e), origem * CFrame.new(0, h - capa / 2, 0), COR.PedraEscura, model)
	Kit.Juntas(model, origem * CFrame.new(0, (h - capa) / 2, 0), l, h - capa, e)
	-- Musgo só na base (manchas chapadas, 0,1 para fora da face para não piscar)
	musgoNaBase(model, origem, l, e)
	-- Ruína: pedras soltas que sobraram em cima da capa, numa ponta
	if l >= 5 then
		Build.block(
			"PedraSolta",
			Vector3.new(BLOCO.Comprimento, 0.8, e - 0.4),
			origem * CFrame.new(-l / 2 + 1.8, h + 0.4, 0),
			COR.Pedra,
			model,
			DETALHE
		)
		Build.block(
			"PedraSolta",
			Vector3.new(1.4, 0.5, e - 0.8),
			origem * CFrame.new(-l / 2 + 4.4, h + 0.25, 0.1),
			COR.PedraJunta,
			model,
			DETALHE
		)
	end
	return principal(model, corpo)
end

-- Fileira de ameias: peitoril contínuo (1,5) com merlões de 2 × 1 × 2,5 a cada 4 studs, centrada na
-- origem, ao longo do X local, com 1 de espessura. É o parapeito da Muralha Com Ameias e do Topo.
function Kit.Ameias(parent: Instance, origem: CFrame, comprimento: number): Model
	local model = Build.model("Ameias", parent)
	local merlao = M.Merlao
	local peitoril = Build.block(
		"Peitoril",
		Vector3.new(comprimento, M.Peitoril, merlao.Z),
		origem * CFrame.new(0, M.Peitoril / 2, 0),
		COR.PedraEscura,
		model
	)
	local quantos = math.max(1, math.floor((comprimento + merlao.X) / M.MerlaoPasso))
	local dente = merlao.Y - M.Peitoril
	for i = 1, quantos do
		local x = (i - (quantos + 1) / 2) * M.MerlaoPasso
		Build.block(
			"Merlao",
			Vector3.new(merlao.X, dente, merlao.Z),
			origem * CFrame.new(x, M.Peitoril + dente / 2, 0),
			COR.PedraEscura,
			model
		)
		Build.block(
			"MerlaoTopo",
			Vector3.new(merlao.X + 0.1, 0.12, merlao.Z + 0.1),
			origem * CFrame.new(x, merlao.Y + 0.02, 0),
			COR.PedraClara,
			model,
			DETALHE
		)
	end
	return principal(model, peitoril)
end

-- Muralha Com Ameias (16 × 4 × 8,5): nível 1. Caminho livre de `largura` (4) no topo. O parapeito fica
-- em balanço, 1 stud para fora de cada face (sobre uma mísula), para não roubar o caminho: ameias na
-- frente (+Z, o lado da batalha) e parapeito cheio de 2,5 no fundo (-Z, o lado do vazio).
-- Pegada total no chão: comprimento × (largura + 2).
function Kit.MuralhaComAmeias(parent: Instance, origem: CFrame, comprimento: number?, largura: number?): Model
	local model = Build.model("MuralhaComAmeias", parent)
	local l = comprimento or M.MuralhaComprimento
	local w = largura or M.AmeiasCaminho
	local h = M.AmeiasAltura
	local corpo = Build.block("Corpo", Vector3.new(l, h, w), origem * CFrame.new(0, h / 2, 0), COR.Pedra, model)
	-- Fundo: mísula + parapeito cheio numa peça só (de 1 abaixo do caminho até 2,5 acima)
	local fundo = M.Merlao.Y + 1
	Build.block(
		"ParapeitoFundo",
		Vector3.new(l, fundo, 1),
		origem * CFrame.new(0, h - 1 + fundo / 2, -(w / 2 + 0.5)),
		COR.PedraEscura,
		model
	)
	-- Frente: mísula + fileira de ameias
	Build.block("Misula", Vector3.new(l, 1, 1), origem * CFrame.new(0, h - 0.5, w / 2 + 0.5), COR.PedraEscura, model)
	Kit.Ameias(model, origem * CFrame.new(0, h, w / 2 + 0.5), l)
	Kit.Juntas(model, origem * CFrame.new(0, (h - 1) / 2, 0), l, h - 1, w)
	musgoNaBase(model, origem, l, w)
	return principal(model, corpo)
end

-- Escadaria (módulo do kit: 12 × 6, 8 degraus de 0,9 × 1,5). O pé fica na origem e ela sobe para o
-- +Z local até `altura`; o comprimento sai da altura (degraus de 1,5 de fundo e no máximo 0,9).
-- Quem anda pisa numa RAMPA com a mesma pegada (sem tranco de câmera em primeira pessoa, no
-- celular); os degraus são acabamento por cima dela, em tom claro, para ler a escada de longe.
function Kit.Escadaria(parent: Instance, origem: CFrame, altura: number?, largura: number?): Model
	local model = Build.model("Escadaria", parent)
	local h = altura or M.EscadariaAltura
	local w = largura or M.EscadariaLargura
	local degraus = math.ceil(h / M.Degrau - 1e-6)
	local passo = h / degraus
	local fundo = M.DegrauFundo
	local comprimento = degraus * fundo
	local livre = w - 2
	local rampa =
		Build.ramp("Rampa", origem, Vector2.zero, Vector2.new(0, comprimento), 0, h, livre, COR.PedraEscura, model)
	for i = 1, degraus do
		Build.block(
			"Degrau",
			Vector3.new(livre, passo, fundo),
			origem * CFrame.new(0, (i - 1) * passo, (i - 0.5) * fundo),
			if i % 2 == 0 then COR.Pedra else COR.PedraClara,
			model,
			DETALHE
		)
	end
	-- Mureta lateral dos dois lados, 1,5 acima dos degraus (um bloco baixo + uma cunha por cima)
	local mureta = M.Peitoril
	for _, lado in { -1, 1 } do
		local x = lado * (w / 2 - 0.5)
		Build.block(
			"MuretaBase",
			Vector3.new(1, mureta, comprimento),
			origem * CFrame.new(x, mureta / 2, comprimento / 2),
			COR.PedraEscura,
			model
		)
		Build.ramp(
			"Mureta",
			origem,
			Vector2.new(x, 0),
			Vector2.new(x, comprimento),
			mureta,
			h + mureta,
			1,
			COR.PedraEscura,
			model
		)
	end
	return principal(model, rampa)
end

-- Ponte Levadiça (10 × 5, vão de 10): tábuas sobre o vão, sem guarda-corpo. A origem é o meio do
-- vão, no nível do chão (o topo das tábuas fica rente ao chão); atravessa no Z local. Os 4 postes
-- ficam em terra firme, 1 stud depois de cada ponta.
function Kit.PonteLevadica(parent: Instance, origem: CFrame, comprimento: number?, largura: number?): Model
	local model = Build.model("PonteLevadica", parent)
	local l = comprimento or M.PonteComprimento
	local w = largura or M.PonteLargura
	local espessura = 0.6
	local tabuas = Build.block(
		"Tabuas",
		Vector3.new(w, espessura, l),
		origem * CFrame.new(0, -espessura / 2, 0),
		COR.Madeira,
		model
	)
	-- Frestas entre as tábuas (a cada 1,5)
	local frestas = math.floor((l / 2 - 0.75) / 1.5)
	for k = -frestas, frestas do
		Build.block(
			"Fresta",
			Vector3.new(w + 0.04, espessura + 0.04, 0.12),
			origem * CFrame.new(0, -espessura / 2, k * 1.5),
			COR.MadeiraEscura,
			model,
			DETALHE
		)
	end
	-- Longarinas de ferro embaixo, e uma corrente de cada poste até a beira da ponte
	for _, lado in LADOS do
		for _, ponta in LADOS do
			local alto = Vector3.new(lado * (w / 2 + 0.4), 3.8, ponta * (l / 2 + 1))
			local baixo = Vector3.new(lado * (w / 2 - 0.2), 0.1, ponta * (l / 2 - 5))
			Build.block(
				"Corrente",
				Vector3.new(0.2, 0.2, (alto - baixo).Magnitude),
				origem * CFrame.lookAt((alto + baixo) / 2, baixo),
				COR.Ferro,
				model,
				DETALHE
			)
			Build.block(
				"PosteCinta",
				Vector3.new(0.95, 0.4, 0.95),
				origem * CFrame.new(alto.X, 3.7, alto.Z),
				COR.Ferro,
				model,
				DETALHE
			)
		end
	end
	for _, lado in LADOS do
		Build.block(
			"Longarina",
			Vector3.new(0.4, 0.4, l),
			origem * CFrame.new(lado * (w / 2 - 0.5), -espessura - 0.2, 0),
			COR.Ferro,
			model,
			Build.Detail
		)
		for _, ponta in { -1, 1 } do
			Build.block(
				"Poste",
				Vector3.new(0.8, 4, 0.8),
				origem * CFrame.new(lado * (w / 2 + 0.4), 2, ponta * (l / 2 + 1)),
				COR.Madeira,
				model
			)
		end
	end
	return principal(model, tabuas)
end

-- Porta Em Arco (10 × 2 × 10, vão 4 × 6,5): parede no X local com a passagem aberta no meio
-- (atravessa no Z local). `largura` e `vao` mudam a parede e a passagem (mínimo 4, ideal 6).
function Kit.PortaEmArco(parent: Instance, origem: CFrame, largura: number?, vao: number?): Model
	local model = Build.model("PortaEmArco", parent)
	local w = largura or M.PortaLargura
	local v = vao or M.PortaVao.X
	local h, e, vaoAltura = M.PortaAltura, M.PortaEspessura, M.PortaVao.Y
	local ombreira = (w - v) / 2
	local primeira: BasePart? = nil
	for _, lado in { -1, 1 } do
		local part = Build.block(
			"Ombreira",
			Vector3.new(ombreira, h, e),
			origem * CFrame.new(lado * (v / 2 + ombreira / 2), h / 2, 0),
			COR.Pedra,
			model
		)
		primeira = primeira or part
		Kit.Juntas(model, part.CFrame, ombreira, h, e)
		-- Canto do arco: uma cunha em cada canto de cima da passagem (só acabamento)
		local cunha = 1.4
		Build.wedge(
			"ArcoCanto",
			Vector3.new(e + 0.1, cunha, cunha),
			origem
				* CFrame.fromMatrix(
					Vector3.new(lado * (v / 2 - cunha / 2), vaoAltura - cunha / 2, 0),
					Vector3.new(0, 0, lado),
					Vector3.new(0, -1, 0),
					Vector3.new(lado, 0, 0)
				),
			COR.PedraEscura,
			model,
			DETALHE
		)
		-- Folha da porta aberta, encostada na parede (face -Z: as tochas ficam na +Z): tábuas com 2 cintas de ferro
		local folha = math.min(v / 2, ombreira - 0.4)
		local folhaAltura = vaoAltura - 0.3
		local meio = origem * CFrame.new(lado * (v / 2 + 0.2 + folha / 2), folhaAltura / 2, -(e / 2 + 0.1))
		Build.block("Folha", Vector3.new(folha, folhaAltura, 0.2), meio, COR.Madeira, model, DETALHE)
		for _, y in { -folhaAltura / 4, folhaAltura / 4 } do
			Build.block(
				"Cinta",
				Vector3.new(folha + 0.06, 0.35, 0.28),
				meio * CFrame.new(0, y, 0),
				COR.Ferro,
				model,
				DETALHE
			)
		end
		for k = -1, 1, 2 do
			Build.block(
				"Tabua",
				Vector3.new(0.08, folhaAltura, 0.24),
				meio * CFrame.new(k * folha / 6, 0, 0),
				COR.MadeiraEscura,
				model,
				DETALHE
			)
		end
	end
	Build.block(
		"Arco",
		Vector3.new(v, h - vaoAltura, e),
		origem * CFrame.new(0, vaoAltura + (h - vaoAltura) / 2, 0),
		COR.PedraEscura,
		model
	)
	return principal(model, primeira :: BasePart)
end

-- Estandarte (haste de 0,4 × 11, bandeira de 3 × 5,5): só marca o lugar. A bandeira cai para o +Z
-- local. Creme com faixa e losango no roxo do jogo, nunca na cor de uma equipe. Só o pé colide.
function Kit.Estandarte(parent: Instance, origem: CFrame): Model
	local model = Build.model("Estandarte", parent)
	local h = M.EstandarteAltura
	local pe = Build.block("Pe", Vector3.new(1.2, 0.4, 1.2), origem * CFrame.new(0, 0.2, 0), COR.PedraEscura, model)
	Build.block("Haste", Vector3.new(0.4, h, 0.4), origem * CFrame.new(0, h / 2, 0), COR.Madeira, model, Build.Detail)
	local topo = h - 0.5
	Build.block(
		"Bandeira",
		Vector3.new(0.2, 5.5, 3),
		origem * CFrame.new(0, topo - 2.75, 1.7),
		COR.Estandarte,
		model,
		Build.Detail
	)
	Build.block(
		"Faixa",
		Vector3.new(0.3, 0.8, 3),
		origem * CFrame.new(0, topo - 0.4, 1.7),
		COR.Roxo,
		model,
		Build.Detail
	)
	Build.block(
		"Losango",
		Vector3.new(0.3, 1.4, 1.4),
		origem * CFrame.new(0, topo - 2.9, 1.7) * CFrame.Angles(math.rad(45), 0, 0),
		COR.Roxo,
		model,
		Build.Detail
	)
	return principal(model, pe)
end

-- Tocha (sem brilho): suporte de 0,6 e chama de 1,1, de cor chapada. Sem luz, sem partícula, sem
-- neon. A origem é o ponto da parede onde ela é presa; o +Z local sai da parede. Tudo acabamento.
function Kit.Tocha(parent: Instance, origem: CFrame): Model
	local model = Build.model("Tocha", parent)
	local suporte = Build.block(
		"Suporte",
		Vector3.new(0.6, 0.6, 0.8),
		origem * CFrame.new(0, 0, 0.4),
		COR.Ferro,
		model,
		Build.Detail
	)
	Build.block("Cabo", Vector3.new(0.3, 1.4, 0.3), origem * CFrame.new(0, 0.6, 0.6), COR.Madeira, model, Build.Detail)
	local giro = CFrame.Angles(0, math.rad(45), 0)
	Build.block(
		"Chama",
		Vector3.new(0.7, 0.7, 0.7),
		origem * CFrame.new(0, 1.6, 0.6) * giro,
		COR.Chama,
		model,
		Build.Detail
	)
	Build.block(
		"ChamaPonta",
		Vector3.new(0.4, 0.5, 0.4),
		origem * CFrame.new(0, 2.15, 0.6) * giro,
		COR.ChamaClara,
		model,
		Build.Detail
	)
	return principal(model, suporte)
end

-- Escombros (5 × 2 × 3,5 + pedras): cobertura de meia altura do Pátio. Pedaço de muro no X local,
-- um toco mais baixo numa ponta e duas pedras encostadas. `espelhado` troca a ponta do toco e das
-- pedras (para a cópia do outro lado da ilha).
function Kit.Escombros(parent: Instance, origem: CFrame, espelhado: boolean?): Model
	local model = Build.model("Escombros", parent)
	local s = if espelhado then -1 else 1
	local muro = M.EscombrosMuro
	local corpo = Build.block("Muro", muro, origem * CFrame.new(0, muro.Y / 2, 0), COR.Pedra, model)
	Kit.Juntas(model, corpo.CFrame, muro.X, muro.Y, muro.Z)
	Build.block(
		"Toco",
		Vector3.new(2, 2, muro.Z),
		origem * CFrame.new(s * (muro.X / 2 + 1), 1, 0),
		COR.PedraEscura,
		model
	)
	Build.prism("Pedra", 8, 2.4, 1.6, origem * CFrame.new(s * -1.5, 0.8, muro.Z / 2 + 1.2), COR.PedraEscura, model)
	Build.prism("Pedra", 6, 1.6, 1, origem * CFrame.new(s * 1.2, 0.5, muro.Z / 2 + 0.8), COR.Pedra, model)
	Build.block(
		"Musgo",
		Vector3.new(2, 0.2, muro.Z + 0.2),
		origem * CFrame.new(s * -1, muro.Y + 0.1, 0),
		COR.Musgo,
		model,
		Build.Detail
	)
	return principal(model, corpo)
end

return Kit
