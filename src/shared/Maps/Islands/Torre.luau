--!strict
-- Torre (GDD 15.7): planta aprovada pelo dono do projeto (F10), sobre o contorno dele
-- (`docs/referencias/f10/torre-0-planta-do-dono.png`, medido em pixels: 148 px = 140 studs), com a
-- arte do kit (KIT-MODULAR 5).
--
-- Simetria ESPELHADA (x → -x): o contorno do dono só é simétrico assim (lado -Z chanfrado, lado +Z
-- reto com um recorte). A metade +X é montada com `lado = 1` e a outra com `lado = -1`; as peças do
-- meio (Topo, Ponte, guarita) são montadas uma vez só.
--
--   * Vão central em colchete, aberto para o +Z. Na "península" de dentro do colchete fica o TOPO:
--     baluarte maciço de 12 studs, com ameias, bem no centro (igual para os dois times).
--   * ESCADARIA: dois lances espelhados encostados no Topo, um de cada time, que se encontram na
--     sacada do meio. Única subida sem carta.
--   * PONTE: tábuas de 47 × 5 sobre o vão, coladas na face do Topo (rota do meio, sem cobertura).
--   * MURALHA: caminho de ronda (nível 1, 8,5) acompanhando o recorte do lado -Z, o mais longe do
--     mirante (nada fica escondido atrás dela), com uma escada em cada ponta e a guarita no meio.
--   * PÁTIO: lado +Z (o do mirante), só com peças baixas ou de topo para quem assiste.
--
-- Coordenadas (x, z) no quadro da ilha: x de base a base, z de um lado ao outro (+Z = mirante).

local Build = require(script.Parent.Parent.Build)
local Detalhe = require(script.Parent.Parent.Kits.Detalhe)
local IslandCommon = require(script.Parent.Parent.IslandCommon)
local Kit = require(script.Parent.Parent.Kits.Torre)
local MapConfig = require(script.Parent.Parent.Parent.Config.MapConfig)
local Theme = require(script.Parent.Parent.Parent.Config.Theme)

local WORLD = MapConfig.World
local COR = Theme.Maps.Torre

local v2 = Vector2.new
local LADOS = { -1, 1 }

type Rect = { x0: number, x1: number, z0: number, z1: number }
type Peca = { x: number, z: number, giro: number }

-- Contorno da metade +X (planta do dono) ---------------------------------------------------------
local BORDA = {
	Lado = 52.5, -- |z| máximo
	Recuo = 31, -- z do fundo dos recortes (o chanfrado em -Z e o reto em +Z)
	RecorteMeio = 6.5, -- os dois recortes têm o fundo em |x| ≤ 6,5
	LoboDe = 28, -- lado -Z: a borda de fora vai de x = 28 a 48,5 (chanfros de 45° dos dois lados)
	LoboAte = 48.5,
}

-- Vão central: |x| ≤ 23,5 e |z| ≤ 13, menos a península (chão que entra no vão pelo +Z)
local VAO = { X = 23.5, Z = 13 }
local PENINSULA = { Meio = 8.5, Ponta = 18.5, Chanfro = 10 } -- face reta em z = 0, |x| ≤ 8,5

-- Chão da metade (retângulos) e os 2 triângulos do lado chanfrado
local CHAO: { Rect } = {
	{ x0 = 0, x1 = 70, z0 = -31, z1 = -13 }, -- faixa da Muralha
	{ x0 = 28, x1 = 48.5, z0 = -52.5, z1 = -31 }, -- lobo
	{ x0 = 23.5, x1 = 70, z0 = -13, z1 = 13 }, -- Meio (na frente da base)
	{ x0 = 0, x1 = 70, z0 = 13, z1 = 31 }, -- faixa da Escadaria e do Pátio
	{ x0 = 6.5, x1 = 70, z0 = 31, z1 = 52.5 }, -- Pátio de fora
}
local CHAO_TRIANGULOS = {
	{ canto = v2(28, -31), a = v2(6.5, -31), b = v2(28, -52.5) },
	{ canto = v2(48.5, -31), a = v2(70, -31), b = v2(48.5, -52.5) },
}

-- Rocha embaixo, sempre por dentro do contorno e longe do vão (nunca aparece de cima)
local ROCHA: { Rect } = {
	{ x0 = 27, x1 = 66, z0 = -28, z1 = 49 },
	{ x0 = 31, x1 = 46, z0 = -49, z1 = -28 },
	{ x0 = 0, x1 = 27, z0 = -28, z1 = -16 },
	{ x0 = 0, x1 = 27, z0 = 16, z1 = 28 },
	{ x0 = 10, x1 = 27, z0 = 28, z1 = 49 },
	{ x0 = 0, x1 = 10, z0 = 4, z1 = 16 }, -- embaixo do Topo
}
local ROCHA_FUNDA: { Rect } = {
	{ x0 = 32, x1 = 60, z0 = -22, z1 = 42 },
	{ x0 = 0, x1 = 32, z0 = 18, z1 = 26 },
}

-- Topo: baluarte maciço em cima da península, com a sacada (onde os dois lances chegam)
local TOPO = {
	Altura = 12, -- nível 2
	SacadaMeio = 3, -- sacada: |x| ≤ 3
	SacadaAte = 24, -- de z = 13 até 24 (tapa metade da passagem do lado +Z)
}
-- Lance da escadaria do Topo: pé em x = 24, sobe para o meio encostado na face z = 13
local LANCE = { PeX = 24, Z = 16, Largura = 6 }

-- Ponte: de uma beira do vão à outra, colada (0,5) na face do Topo
local PONTE = { Z = -3, Largura = 5 }

-- Muralha (lado -Z): guarita no fundo do recorte, lance diagonal acompanhando a borda, patamar e
-- escada descendo para o lobo
local MURALHA = {
	GuaritaZ = -27, -- meio do caminho da guarita (caminho de 6: cabe o ponto de escudo)
	GuaritaComprimento = 18,
	GuaritaCaminho = 6,
	PatamarZ = -49.5, -- meio do patamar (pegada z = -52,5 a -46,5)
	PatamarAte = 37,
	EscadaX = 34, -- escada de x = 31 a 37, descendo de z = -46,5 até -31,5
	EscadaPeZ = -31.5,
}

-- Peças altas (10), todas atravessadas (de topo para o mirante): quebram as linhas ao longo das rotas
local MURO_DO_PORTAO = { X = 45, PortaZ = -12, MuroZ = -1.5, MuroComprimento = 11 } -- z de -17 a 4
local ESPORAO = { Z = -21, Comprimento = 4 } -- embaixo da guarita, z de -23 a -19
local TOCO_MURALHA = { X = 16, Z = -16, Comprimento = 6 } -- na beira do vão, z de -19 a -13
local TOCO_PATIO = { X = 14, Z = 27.5, Comprimento = 7 } -- z de 24 a 31
local PORTA_PATIO = { X = 36, Z = 27 } -- porta em arco solta, z de 22 a 32
-- Mureta em ruína (meia altura) entre a faixa da Escadaria e o Pátio de fora (o traço do dono)
local MURETA_PATIO = { X = 21.5, Z = 31, Comprimento = 12, Altura = 3.5 }

-- Acabamento do chão (não muda cobertura nem rota): lajes na cabeça da Ponte (do vão até o muro do
-- portão), e manchas de musgo rentes ao chão { x, z, largura, fundo }.
local CAMINHO = { De = 25, Ate = 43, Laje = 3, Vao = 0.4 }
local MUSGO_NO_CHAO = {
	{ 12, -22, 5, 3 },
	{ 40, -40, 4, 6 },
	{ 60, -20, 6, 3 },
	{ 52, 10, 4, 4 },
	{ 30, 20, 5, 3 },
	{ 62, 44, 6, 4 },
	{ 14, 46, 4, 5 },
	{ 40, 34, 3, 5 },
}

local ESCOMBROS: { Peca } = {
	{ x = 31, z = -9, giro = 90 }, -- cabeça da Ponte
	{ x = 33, z = 7, giro = 90 }, -- Meio, a caminho da Escadaria
	{ x = 46, z = -36, giro = 90 }, -- lobo, a caminho da escada da Muralha
	{ x = 23, z = -27, giro = 45 }, -- entrada da passagem da Muralha
	{ x = 50, z = 24, giro = 90 }, -- Pátio
	{ x = 44, z = 42, giro = 90 }, -- Pátio de fora
	{ x = 20, z = 42, giro = 90 }, -- canto do recorte (duelo por cima do recorte)
	{ x = 58, z = -24, giro = 0 }, -- saída esquerda da base
}

-- Pontos de escudo no eixo do meio (mesma distância das duas bases): um no chão da passagem do
-- lado +Z, embaixo da sacada; outro em cima da guarita (nível 1).
local ESCUDO_Z = 27

-- Passada de detalhe (depois da F10, Kits/Detalhe): só acabamento, nada colide nem muda a planta.
-- Posições na metade +X; a outra é o espelho (x → -x). -------------------------------------------

-- Lajes soltas { x, z, tamanho, giro }: da porta da base até o portão e até o Pátio
local LAJES_SOLTAS = {
	{ 66, -2, 2.6, 10 },
	{ 62.2, -4.4, 2.2, -15 },
	{ 58.4, -6.6, 2.6, 20 },
	{ 54.6, -8.8, 2.2, 5 },
	{ 50.8, -10.6, 2.6, -10 },
	{ 64, 5.5, 2.4, -20 },
	{ 60.2, 8.5, 2.2, 15 },
	{ 56.4, 11.6, 2.6, -5 },
	{ 52.6, 14.8, 2.2, 25 },
}
-- Mais musgo rente ao chão { x, z, diâmetro }
local MUSGO_EXTRA = { { 36, -24, 2.4 }, { 58, 36, 2.6 }, { 26, 46, 2 }, { 62, -40, 2.2 } }
-- Tufos de mato { x, z, escala }: pé dos muros, cantos de mureta, frestas
local MATO = {
	{ 58, -27, 1 },
	{ 68.6, -30, 1 },
	{ 47, -51, 0.9 },
	{ 46.9, 2, 1 },
	{ 43.2, -4, 0.9 },
	{ 17.8, -18, 0.9 },
	{ 12.2, 25, 1 },
	{ 37.6, 23, 0.9 },
	{ 68.4, 20.2, 1.1 },
	{ 68.6, 51.3, 1 },
	{ 8, 51.4, 0.9 },
	{ 26, 36, 0.7 },
	{ 54, 44, 0.8 },
	{ 30, -36, 0.8 },
}
-- Pedrinhas soltas { x, z, giro }
local PEDRINHAS = { { 33.5, -11.5, 0 }, { 48.5, -33, 40 }, { 52.5, 21.5, 80 }, { 22.5, 44.5, 20 }, { 47.4, -18.5, 60 } }
local FACE_DA_BASE = WORLD.BodySize.X / 2 - 0.75
local TOCHA_DA_BASE = { Y = 4.5, Z = 16 } -- longe dos estandartes (z = ±10)

local function vestir(folder: Instance, em: (number, number, number?, number?) -> CFrame, lado: number)
	local cores = COR.Detalhe

	-- Chão: lajes soltas, musgo e pedrinhas
	for i, laje in LAJES_SOLTAS do
		local tom = if i % 2 == 0 then COR.PedraClara else COR.Pedra
		Detalhe.Placa(folder, em(laje[1], laje[2], laje[4]), v2(laje[3], laje[3]), tom)
	end
	for _, mancha in MUSGO_EXTRA do
		Detalhe.Mancha(folder, em(mancha[1], mancha[2]), mancha[3], cores)
	end
	for _, pedra in PEDRINHAS do
		Detalhe.Pedrinhas(folder, em(pedra[1], pedra[2], pedra[3]), cores)
	end

	-- Sombra pintada no pé dos muros, tocos, portas e escombros
	local portao = MURO_DO_PORTAO
	local portaoDe = portao.PortaZ - Kit.Medidas.PortaLargura / 2
	local portaoAte = portao.MuroZ + portao.MuroComprimento / 2
	local espessura = Kit.Medidas.MuralhaEspessura + 1.2
	Detalhe.Sombra(
		folder,
		em(portao.X, (portaoDe + portaoAte) / 2, 90),
		v2(portaoAte - portaoDe + 1.2, espessura),
		cores
	)
	Detalhe.Sombra(folder, em(TOCO_MURALHA.X, TOCO_MURALHA.Z, 90), v2(TOCO_MURALHA.Comprimento + 1.2, espessura), cores)
	Detalhe.Sombra(folder, em(TOCO_PATIO.X, TOCO_PATIO.Z, 90), v2(TOCO_PATIO.Comprimento + 1.2, espessura), cores)
	Detalhe.Sombra(folder, em(PORTA_PATIO.X, PORTA_PATIO.Z, 90), v2(Kit.Medidas.PortaLargura + 1.2, 3.2), cores)
	Detalhe.Sombra(folder, em(MURETA_PATIO.X, MURETA_PATIO.Z, 0), v2(MURETA_PATIO.Comprimento + 1.2, espessura), cores)
	for _, peca in ESCOMBROS do
		Detalhe.Sombra(folder, em(peca.x, peca.z, peca.giro), v2(6, 4), cores)
	end
	local baseHalf = WORLD.BaseSize.Y / 2
	local door = WORLD.BaseDoorWidth / 2
	for _, sinal in LADOS do
		Detalhe.Sombra(
			folder,
			em(FACE_DA_BASE - 0.4, sinal * (door + baseHalf) / 2, 90),
			v2(baseHalf - door, 0.8),
			cores
		)
	end

	-- Base: anel de pedra clara em volta de onde se nasce (sem hachura: é um castelo)
	Detalhe.MarcaDeBase(
		folder,
		em(WORLD.BodySize.X / 2 + WORLD.BaseSize.X / 2, 0, if lado == 1 then 0 else 180),
		WORLD.BaseSize.X,
		WORLD.BaseSize.Y,
		cores.Pintura,
		false
	)

	-- Ambiente: mato e hera nos muros
	for _, mato in MATO do
		Detalhe.Mato(folder, em(mato[1], mato[2], mato[1] * 37 % 360), mato[3], cores)
	end
	local meiaEspessura = Kit.Medidas.MuralhaEspessura / 2 + 0.08 -- com as juntas
	Detalhe.Hera(folder, em(portao.X + meiaEspessura, 1, 90), 7, cores)
	Detalhe.Hera(folder, em(portao.X - meiaEspessura, -3, -90), 5, cores)
	Detalhe.Hera(folder, em(TOCO_PATIO.X + meiaEspessura, 27, 90), 6, cores)
	Detalhe.Hera(folder, em(FACE_DA_BASE, -12, -90), 5, cores)

	-- Luzes reais: as duas tochas do portão (montadas em `metade`) e duas na parede da base
	for _, sinal in LADOS do
		local z = sinal * TOCHA_DA_BASE.Z
		Kit.Tocha(folder, em(FACE_DA_BASE, z, -90, TOCHA_DA_BASE.Y), true)
		Detalhe.ManchaDeLuz(folder, em(FACE_DA_BASE - Kit.Tocha_Alcance - 1.5, z), 5, cores)
	end
end

local function retangulo(lado: number, r: Rect): (Vector2, Vector2)
	local xa, xb = lado * r.x0, lado * r.x1
	return v2(math.min(xa, xb), r.z0), v2(math.max(xa, xb), r.z1)
end

local function metade(frame: CFrame, folder: Instance, lado: number)
	local t = WORLD.IslandThickness
	local mureta = WORLD.IslandEdgeRail
	local semSombra = IslandCommon.NoShadow
	local leste: "east" | "west" = if lado == 1 then "east" else "west"

	-- Ponto (x, z) da metade +X no lado certo, e quadro de um componente (giro espelhado junto)
	local function p(x: number, z: number): Vector2
		return v2(lado * x, z)
	end
	local function em(x: number, z: number, giro: number?, y: number?): CFrame
		return Build.pivot(frame, p(x, z), lado * (giro or 0), y)
	end

	-- Chão ------------------------------------------------------------------------------------------
	for _, r in CHAO do
		local min, max = retangulo(lado, r)
		IslandCommon.ground(Build.floorRect("Floor", frame, min, max, t, COR.Terra, folder, 0, semSombra))
	end
	for _, tri in CHAO_TRIANGULOS do
		IslandCommon.ground(
			Build.floorTriangle(
				"Floor",
				frame,
				p(tri.canto.X, tri.canto.Y),
				p(tri.a.X, tri.a.Y),
				p(tri.b.X, tri.b.Y),
				t,
				COR.Terra,
				folder,
				0,
				semSombra
			)
		)
	end
	for nivel, lista in { ROCHA, ROCHA_FUNDA } do
		local altura = if nivel == 1 then 10 else 12
		local topo = if nivel == 1 then -t else -t - 10
		for _, r in lista do
			local min, max = retangulo(lado, r)
			Build.floorRect("Underside", frame, min, max, altura, COR.PedraEscura, folder, topo, semSombra)
		end
	end

	-- Acabamento do chão: lajes do caminho (duas fileiras, na largura da Ponte) e musgo
	local laje = CAMINHO.Laje
	local x = CAMINHO.De
	local fileira = 0
	while x + laje <= CAMINHO.Ate do
		for _, dz in LADOS do
			local z = PONTE.Z + dz * (laje + CAMINHO.Vao) / 2
			local a, b = p(x, z - laje / 2), p(x + laje, z + laje / 2)
			Build.floorRect(
				"Laje",
				frame,
				v2(math.min(a.X, b.X), a.Y),
				v2(math.max(a.X, b.X), b.Y),
				0.04,
				if (fileira + (if dz == 1 then 1 else 0)) % 2 == 0 then COR.PedraClara else COR.Pedra,
				folder,
				0.04,
				Build.Detail
			)
		end
		x += laje + CAMINHO.Vao
		fileira += 1
	end
	for _, mancha in MUSGO_NO_CHAO do
		local a = p(mancha[1] - mancha[3] / 2, mancha[2] - mancha[4] / 2)
		local b = p(mancha[1] + mancha[3] / 2, mancha[2] + mancha[4] / 2)
		Build.floorRect(
			"Musgo",
			frame,
			v2(math.min(a.X, b.X), a.Y),
			v2(math.max(a.X, b.X), b.Y),
			0.03,
			COR.Musgo,
			folder,
			0.03,
			Build.Detail
		)
	end

	-- Mureta (3) nas bordas de fora e também na beira do vão, menos na cabeça da Ponte: a queda é
	-- sempre por escolha (pular a mureta), nunca por andar de costas num tiroteio.
	local base = WORLD.BaseSize.Y / 2
	local bordas = {
		{ v2(70, -BORDA.Recuo), v2(BORDA.LoboAte, -BORDA.Lado) },
		{ v2(BORDA.LoboAte, -BORDA.Lado), v2(MURALHA.PatamarAte, -BORDA.Lado) },
		{ v2(70, -BORDA.Recuo), v2(70, -base) },
		{ v2(70, base), v2(70, BORDA.Lado) },
		{ v2(70, BORDA.Lado), v2(BORDA.RecorteMeio, BORDA.Lado) },
		{ v2(BORDA.RecorteMeio, BORDA.Lado), v2(BORDA.RecorteMeio, BORDA.Recuo) },
		{ v2(BORDA.RecorteMeio, BORDA.Recuo), v2(0, BORDA.Recuo) },
		-- beira do vão
		{ v2(0, -VAO.Z), v2(VAO.X, -VAO.Z) },
		{ v2(VAO.X, -VAO.Z), v2(VAO.X, PONTE.Z - PONTE.Largura / 2 - 1) },
		{ v2(VAO.X, PONTE.Z + PONTE.Largura / 2 + 1), v2(VAO.X, VAO.Z) },
		{ v2(VAO.X, VAO.Z), v2(PENINSULA.Ponta, VAO.Z) },
	}
	for _, borda in bordas do
		Build.wall("Rail", frame, p(borda[1].X, borda[1].Y), p(borda[2].X, borda[2].Y), mureta, 1, COR.Pedra, folder)
	end

	-- Topo: as pontas chanfradas do baluarte (o miolo é montado uma vez só, em `meio`) ---------------
	local topo = TOPO.Altura
	local corpo = topo + t -- o baluarte desce até o fundo do chão (é a parede do vão)
	local pen = PENINSULA
	local quina = VAO.Z - pen.Chanfro -- z onde o chanfro acaba (10)
	do
		local min, max = retangulo(lado, { x0 = pen.Meio, x1 = pen.Ponta, z0 = quina, z1 = VAO.Z })
		Build.floorRect("Topo", frame, min, max, corpo, COR.Pedra, folder, topo)
		Build.floorTriangle(
			"Topo",
			frame,
			p(pen.Meio, quina),
			p(pen.Ponta, quina),
			p(pen.Meio, 0),
			corpo,
			COR.Pedra,
			folder,
			topo
		)
	end
	-- Ameias do Topo: no chanfro, na ponta e ao lado do lance (0,5 para dentro da beira)
	Kit.Ameias(folder, em((pen.Meio + pen.Ponta) / 2 - 0.35, quina / 2 + 0.35, -45, topo), 13)
	Kit.Ameias(folder, em(pen.Ponta - 0.5, (quina + VAO.Z) / 2, 90, topo), VAO.Z - quina)
	Kit.Ameias(folder, em(11, VAO.Z - 0.5, 0, topo), 14)
	-- Lado da sacada, depois da chegada do lance
	local sacadaLivre = LANCE.Z + LANCE.Largura / 2 -- 19
	Kit.Ameias(
		folder,
		em(TOPO.SacadaMeio - 0.5, (sacadaLivre + TOPO.SacadaAte) / 2, 90, topo),
		TOPO.SacadaAte - sacadaLivre
	)

	-- Escadaria: lance deste time, do pé (x = 24) até a sacada (x = 3) --------------------------------
	Kit.Escadaria(folder, em(LANCE.PeX, LANCE.Z, -90), topo, LANCE.Largura)

	-- Muralha: lance diagonal acompanhando a borda, do lado da guarita até o nó do patamar ----------
	local e1 = v2(BORDA.RecorteMeio, -BORDA.Recuo)
	local e2 = v2(BORDA.LoboDe, -BORDA.Lado)
	local ao = (e2 - e1).Unit -- ao longo da borda
	local dentro = v2(-ao.Y, ao.X) -- para dentro da ilha
	local pegada = Kit.Medidas.AmeiasCaminho + 2
	local eixo = e1 + dentro * (pegada / 2) -- eixo do caminho, na altura do começo da borda
	local de = -1.5 -- começa encostado na guarita (sem buraco e sem invadir o caminho dela)
	local ate = (eixo.Y - MURALHA.PatamarZ) / -ao.Y -- até o eixo do patamar
	local centro = eixo + ao * ((de + ate) / 2)
	local giro = math.deg(math.atan2(-ao.Y, ao.X)) -- 45°: a frente (+Z local) fica para dentro
	Kit.MuralhaComAmeias(folder, em(centro.X, centro.Y, giro), ate - de)
	-- Nó de 8 lados onde a diagonal vira o patamar (fecha a quina sem sair do contorno)
	local no = eixo + ao * ate
	local nivel1 = Kit.Medidas.AmeiasAltura
	Build.prism("MuralhaNo", 8, pegada, nivel1, em(no.X, no.Y, 0, nivel1 / 2), COR.Pedra, folder)
	-- Patamar, com parapeito do lado do vazio e na ponta
	local patamarDe, patamarAte = math.floor(no.X), MURALHA.PatamarAte
	local fora, dentroZ = MURALHA.PatamarZ - pegada / 2, MURALHA.PatamarZ + pegada / 2
	do
		local min, max = retangulo(lado, { x0 = patamarDe, x1 = patamarAte, z0 = fora, z1 = dentroZ })
		Build.floorRect("MuralhaPatamar", frame, min, max, nivel1, COR.Pedra, folder, nivel1)
	end
	local parapeito = Kit.Medidas.Merlao.Y
	Build.wall(
		"MuralhaParapeito",
		frame,
		p(patamarDe + 0.5, fora + 0.5),
		p(patamarAte - 0.5, fora + 0.5),
		parapeito,
		1,
		COR.PedraEscura,
		folder,
		nivel1
	)
	Build.wall(
		"MuralhaParapeito",
		frame,
		p(patamarAte - 0.5, fora + 0.5),
		p(patamarAte - 0.5, dentroZ - 0.5),
		parapeito,
		1,
		COR.PedraEscura,
		folder,
		nivel1
	)
	-- Escada da Muralha: pé no lobo, sobe para o -Z até o patamar (de topo para o mirante)
	Kit.Escadaria(folder, em(MURALHA.EscadaX, MURALHA.EscadaPeZ, 180), nivel1)

	-- Peças altas atravessadas ------------------------------------------------------------------------
	local portao = MURO_DO_PORTAO
	Kit.PortaEmArco(folder, em(portao.X, portao.PortaZ, 90))
	Kit.MuralhaDePedra(folder, em(portao.X, portao.MuroZ, 90), portao.MuroComprimento)
	Kit.MuralhaDePedra(folder, em(TOCO_MURALHA.X, TOCO_MURALHA.Z, 90), TOCO_MURALHA.Comprimento)
	Kit.MuralhaDePedra(folder, em(TOCO_PATIO.X, TOCO_PATIO.Z, 90), TOCO_PATIO.Comprimento)
	Kit.PortaEmArco(folder, em(PORTA_PATIO.X, PORTA_PATIO.Z, 90))
	Kit.MuralhaDePedra(folder, em(MURETA_PATIO.X, MURETA_PATIO.Z, 0), MURETA_PATIO.Comprimento, MURETA_PATIO.Altura)
	for _, peca in ESCOMBROS do
		Kit.Escombros(folder, em(peca.x, peca.z, peca.giro), lado == -1)
	end

	-- Detalhes: tochas em par no portão (face da base) e na ponta da sacada; estandartes na base ----
	local face = portao.X + Kit.Medidas.PortaEspessura / 2
	local vao = Kit.Medidas.PortaVao.X / 2 + 1.5
	for _, z in { portao.PortaZ - vao, portao.PortaZ + vao } do
		Kit.Tocha(folder, em(face, z, 90, 5), true) -- acesas (passada de detalhe)
		Detalhe.ManchaDeLuz(folder, em(face + Kit.Tocha_Alcance + 1.5, z), 4, COR.Detalhe)
	end
	Kit.Tocha(folder, em(2, TOPO.SacadaAte, 0, 8))
	for _, z in { -10, 10 } do
		Kit.Estandarte(folder, em(67, z, 0))
	end
	vestir(folder, em, lado)

	-- Zonas da metade (pings) -----------------------------------------------------------------------
	local zonas: { { id: string, r: Rect } } = {
		{ id = "muralha", r = { x0 = 0, x1 = 70, z0 = -52.5, z1 = -13 } },
		{ id = "meio", r = { x0 = 23.5, x1 = 70, z0 = -13, z1 = 13 } },
		{ id = "escadaria", r = { x0 = 3, x1 = 24, z0 = 13, z1 = 24 } },
		{ id = "escadaria", r = { x0 = 0, x1 = 24, z0 = 24, z1 = 31 } },
		{ id = "patio", r = { x0 = 24, x1 = 70, z0 = 13, z1 = 31 } },
		{ id = "patio", r = { x0 = 0, x1 = 70, z0 = 31, z1 = 52.5 } },
	}
	for _, zona in zonas do
		local min, max = retangulo(lado, zona.r)
		IslandCommon.zone(frame, folder, zona.id, min, max, leste)
	end
end

-- Peças do eixo do meio (uma vez só) --------------------------------------------------------------
local function meio(frame: CFrame, folder: Instance)
	local t = WORLD.IslandThickness
	local topo = TOPO.Altura
	local pen = PENINSULA
	local function em(x: number, z: number, giro: number?, y: number?): CFrame
		return Build.pivot(frame, v2(x, z), giro, y)
	end

	-- Miolo do Topo e a sacada
	Build.floorRect("Topo", frame, v2(-pen.Meio, 0), v2(pen.Meio, VAO.Z), topo + t, COR.Pedra, folder, topo)
	Build.floorRect(
		"TopoSacada",
		frame,
		v2(-TOPO.SacadaMeio, VAO.Z),
		v2(TOPO.SacadaMeio, TOPO.SacadaAte),
		topo,
		COR.Pedra,
		folder,
		topo
	)
	-- Juntas de pedra na face do Topo que dá para a Ponte (o baluarte é maciço: só a face)
	Kit.Juntas(folder, em(0, 0, 0, (topo - t) / 2), pen.Meio * 2, topo + t, 0)
	Kit.Ameias(folder, em(0, 0.5, 0, topo), pen.Meio * 2) -- face do vão (em cima da Ponte)
	Kit.Ameias(folder, em(0, TOPO.SacadaAte - 0.5, 0, topo), TOPO.SacadaMeio * 2 - 2) -- ponta da sacada
	Kit.Estandarte(folder, em(0, 3, 0, topo))

	-- Ponte: de uma beira do vão à outra
	Kit.PonteLevadica(folder, em(0, PONTE.Z, 90), VAO.X * 2, PONTE.Largura)

	-- Guarita da Muralha (frente para dentro) e o esporão embaixo dela
	Kit.MuralhaComAmeias(folder, em(0, MURALHA.GuaritaZ, 0), MURALHA.GuaritaComprimento, MURALHA.GuaritaCaminho)
	Kit.MuralhaDePedra(folder, em(0, ESPORAO.Z, 90), ESPORAO.Comprimento)

	-- Pontos de escudo
	IslandCommon.shieldPoint(frame, folder, 0, ESCUDO_Z)
	IslandCommon.shieldPoint(frame, folder, 0, -ESCUDO_Z, Kit.Medidas.AmeiasAltura)

	-- Zonas do meio
	IslandCommon.zone(frame, folder, "ponte", v2(-VAO.X, -VAO.Z), v2(VAO.X, 0))
	IslandCommon.zone(frame, folder, "topo", v2(-VAO.X, 0), v2(VAO.X, VAO.Z))
	IslandCommon.zone(frame, folder, "topo", v2(-TOPO.SacadaMeio, VAO.Z), v2(TOPO.SacadaMeio, TOPO.SacadaAte))
end

local Torre: IslandCommon.Island = {
	style = {
		floor = COR.Terra,
		rail = COR.Pedra,
		wall = COR.PedraEscura,
		underside = COR.PedraEscura,
	},
	build = function(frame: CFrame, folder: Instance)
		metade(frame, folder, 1)
		metade(frame, folder, -1)
		meio(frame, folder)
	end,
}

return Torre
