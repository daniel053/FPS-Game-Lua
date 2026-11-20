--!strict
-- Porto (GDD 15.6): planta aprovada pelo dono do projeto (F10), a partir do desenho dele
-- (docs/referencias/f10/porto-0-planta-do-dono.png), com a arte do kit (KIT-MODULAR 2).
--
-- Pátio de contêineres com SIMETRIA DE GIRO (o que existe numa metade existe girado 180° na outra):
--   * Guindaste (centro): pilha em ponte, fina e comprida no sentido norte-sul. Dois contêineres no
--     chão com um vão de 8 no meio (a rota do meio passa por baixo) e um em cima (nível 2 = 17).
--     Cada ponta da pilha é uma plataforma (nível 1 = 8,5) com uma escada do chão (a do norte sobe
--     pelo lado leste, a do sul pelo lado oeste) e outra até o topo.
--   * Pátio (leste e oeste): dois contêineres em pé, em linha, com um portão de 8 entre eles. Um
--     deles fica na frente da porta da base e quebra a linha reta base a base. Do lado "fraco" de
--     cada time: parede de chapa e caixas de madeira.
--   * Píer (bordas norte e sul, no recorte do contorno): tablado de madeira sobre a água, sem
--     mureta (faixa de aviso), com o ponto de escudo no meio. Cair na água volta à base.
--
-- Coordenadas (x, z) no quadro da ilha, em studs: x de base a base (+x = leste, direita do desenho),
-- z de um lado ao outro (+z = sul, parte de baixo do desenho, lado do mirante). Medidas do contorno
-- tiradas do desenho na escala de 140 studs de base a base (1 pixel = 0,946 stud).

local Build = require(script.Parent.Parent.Build)
local IslandCommon = require(script.Parent.Parent.IslandCommon)
local Kit = require(script.Parent.Parent.Kits.Porto)
local MapConfig = require(script.Parent.Parent.Parent.Config.MapConfig)
local Theme = require(script.Parent.Parent.Parent.Config.Theme)

local WORLD = MapConfig.World
local PALETTE = Theme.Maps.Porto

local v2 = Vector2.new

-- Contorno: retângulo de 140 × 105 com um recorte (água) no meio das bordas norte e sul.
local HALF_X = 70
local HALF_Z = 52.5
local NOTCH = { HalfWidth = 21, Depth = 8.5 } -- 42 × 8,5 no desenho
local QUAY_Z = HALF_Z - NOTCH.Depth -- 44: beira do cais (onde o concreto acaba no recorte)
local WATER_DROP = 3 -- a água fica 3 studs abaixo do chão
local JOINT_STEP = 14 -- juntas do piso de concreto (só acabamento)
local JOINT_Z = 22

-- Pilha do Guindaste (no centro, comprimento no sentido norte-sul). Ocupa |x| ≤ 4, |z| ≤ 24; o vão
-- por baixo é |z| ≤ 4; o contêiner de cima é |z| ≤ 10.
local STACK = { HalfWidth = 4, End = 24, TopEnd = 10 }
-- Escada do chão até a plataforma (nível 1), encostada na ponta norte da pilha, pelo lado leste
local STAIR_LOW = { Z = -21, FootX = 16, Length = 12, Width = 6 }
-- Escada da plataforma até o topo (nível 2), em cima do contêiner de baixo, na largura toda
local STAIR_HIGH = { FootZ = -18, Length = 8, Width = 8 }

-- Uma metade (a do time do leste; a outra é esta girada 180°) -----------------------------------------

-- Contêineres em pé do pátio (comprimento norte-sul): o da frente da porta e o do norte, em linha,
-- com o portão de 8 studs entre eles (z de -15 a -7).
local YARD_CONTAINERS = {
	Front = v2(38, 3), -- x 34..42, z -7..13: tapa a porta da base para quem olha do outro lado
	North = v2(38, -25), -- x 34..42, z -35..-15
}
-- Parede de chapa (16 × 1 × 12), no sentido norte-sul: protege o lado sul do pátio de quem está no topo
local SHEET_WALL = v2(30, 32) -- z 24..40
-- Caixas de madeira { x, z, tamanho }
local CRATES = {
	{ 38, 16, 6 }, -- escadinha na ponta sul do contêiner da frente: 3 → 6 → 8,5 (sobe pulando)
	{ 36.5, 20.5, 3 },
	{ 54, 30, 6 }, -- lado sul do pátio
	{ 58.5, 28.5, 3 },
	{ 57, -45, 6 }, -- canto nordeste: ponta da linha de visão longa do cais norte
	{ 52.5, -46.5, 3 },
	{ 18, 4, 6 }, -- no meio, entre o portão do pátio e o vão da pilha
	{ 22.5, 2.5, 3 },
	{ -9, -39, 6 }, -- beira do cais norte, do lado oeste do píer
	{ -4.5, -40.5, 3 },
	{ 6.5, -45.5, 3 }, -- em cima do píer, ao lado do ponto de escudo
}
-- Grupos de barris { x, z, quantidade }
local BARRELS = {
	{ 54, -18, 3 }, -- entre a porta da base e o portão do pátio
	{ 25, -15, 2 }, -- a caminho do pé da escada
	{ 45, 40, 2 }, -- borda sul
	{ 62, 45, 3 }, -- canto sudeste
}

-- Píer do norte: tablado de 30 × 6 colado no cais; sobram 6 de água em cada ponta do recorte e 2,5
-- do lado de fora.
local PIER = { Length = 30, Width = 6 }
local PIER_Z = -(QUAY_Z + PIER.Width / 2) -- centro do tablado
local BOLLARDS_X = { -12, 12 } -- cabeços de amarração (a cada 12, com o ponto de escudo no meio)
local SHIELD = v2(0, -46.5)
-- Torre do guindaste: em pé dentro da água, na ponta leste do recorte (fora do caminho); a lança
-- aponta para o pátio, acima de tudo.
local CRANE = { At = v2(18, -48), Modules = 6, Jib = 30 }

-- Passada de detalhe (depois da F10): só acabamento, nada colide nem muda a planta. Posições na
-- metade do leste; a outra é a mesma girada 180°. ---------------------------------------------------

-- Placas de concreto em outro tom { x0, z0, x1, z1 }: células entre as juntas do piso
local LIGHT_SLABS = {
	{ 14, -44, 28, -22 },
	{ 42, -22, 56, 22 },
	{ 28, 22, 42, 44 },
	{ 56, -44, 70, -22 },
	{ 0, 22, 14, 44 },
}
-- Rachaduras { x, z, comprimento, giro em graus }
local CRACKS = {
	{ 24, -30, 4, 20 },
	{ 48, 12, 3.5, -30 },
	{ 60, -8, 3, 20 },
	{ 10, 34, 4, 10 },
	{ 52, 40, 3, -60 },
	{ 32, -40, 3.5, 40 },
}
-- Manchas de óleo { x, z, diâmetro }
local OIL = {
	{ 46, -4, 2.6 },
	{ 20, -29, 2.2 },
	{ 58, 20, 3 },
	{ 9, 14, 2 },
}
local BORDER_LINE = 3 -- linha branca a 3 studs da mureta
local GATE_Z = -11 -- meio do portão do pátio
-- Tufos de mato { x, z, escala }: frestas, cantos de mureta e pé das paredes
local PLANTS = {
	{ 66.5, -51.3, 1 },
	{ 66.5, 51.3, 0.9 },
	{ 23.6, -51.2, 0.8 },
	{ 23.6, 51.2, 1.1 },
	{ 29, 24.8, 1 },
	{ 31.2, 39.3, 0.9 },
	{ 68.4, 20.4, 1.1 },
	{ 28.1, -22.2, 0.7 },
	{ 42.1, 22.2, 0.8 },
	{ 56.1, -40, 0.7 },
	{ 42.7, 12.8, 0.9 },
	{ 60.6, -47.6, 1 },
	{ 50.6, 32.6, 0.9 },
}
-- Parede da frente da base (face que dá para a área de duelo) e altura das luminárias nela
local BASE_WALL_FACE = HALF_X - 0.75
local WALL_LAMP_Y = 5.6
local WALL_LAMP_Z = 10 -- uma de cada lado da passagem, em cima de uma floreira

local function dress(frame: CFrame, folder: Instance)
	local function at(x: number, z: number, yaw: number?, y: number?): CFrame
		return Build.pivot(frame, v2(x, z), yaw, y)
	end
	local level1 = Kit.Conteiner_Altura

	-- Chão: placas claras, rachaduras e manchas de óleo
	for _, slab in LIGHT_SLABS do
		local size = v2(slab[3] - slab[1], slab[4] - slab[2])
		Kit.PlacaDoPiso(folder, at((slab[1] + slab[3]) / 2, (slab[2] + slab[4]) / 2), size)
	end
	for _, crack in CRACKS do
		Kit.Rachadura(folder, at(crack[1], crack[2], crack[4]), crack[3])
	end
	for _, oil in OIL do
		Kit.ManchaDeOleo(folder, at(oil[1], oil[2]), oil[3])
	end

	-- Sombra pintada na base do que fica em pé (dá peso às peças)
	local margin = 1.2
	for _, spot in { YARD_CONTAINERS.Front, YARD_CONTAINERS.North } do
		Kit.SombraPintada(
			folder,
			at(spot.X, spot.Y, 90),
			v2(Kit.Conteiner_Comprimento, Kit.Conteiner_Largura) + v2(margin, margin)
		)
	end
	local stackOffset = (Kit.Pilha_Vao + Kit.Conteiner_Comprimento) / 2
	Kit.SombraPintada(
		folder,
		at(0, -stackOffset, 90),
		v2(Kit.Conteiner_Comprimento, Kit.Conteiner_Largura) + v2(margin, margin)
	)
	Kit.SombraPintada(folder, at(SHEET_WALL.X, SHEET_WALL.Y, 90), v2(Kit.Parede_Comprimento + margin, 2.6))
	for _, crate in CRATES do
		Kit.SombraPintada(folder, at(crate[1], crate[2]), v2(crate[3] + 0.8, crate[3] + 0.8))
	end
	local baseHalf = WORLD.BaseSize.Y / 2
	local door = WORLD.BaseDoorWidth / 2
	for _, sign in { -1, 1 } do
		local mid = sign * (door + baseHalf) / 2
		Kit.SombraPintada(folder, at(BASE_WALL_FACE - 0.4, mid, 90), v2(baseHalf - door, 0.8))
		-- pé da mureta norte/sul e leste
		local edgeZ = sign * (HALF_Z - 0.5 - 0.4)
		local railStart = NOTCH.HalfWidth + 1.5
		Kit.SombraPintada(folder, at((railStart + HALF_X) / 2, edgeZ), v2(HALF_X - railStart, 0.8))
		local eastMid = sign * (HALF_Z + baseHalf) / 2
		Kit.SombraPintada(folder, at(HALF_X - 0.9, eastMid, 90), v2(HALF_Z - baseHalf, 0.8))
	end

	-- Pintura: linha da borda, faixa de pedestre na porta da base, seta e linha tracejada até o
	-- portão do pátio, áreas hachuradas no portão e no pé da escada
	local lineStart = NOTCH.HalfWidth + 1.5 + 2.5
	local lineEnd = HALF_X - BORDER_LINE
	for _, sign in { -1, 1 } do
		Kit.LinhaPintada(folder, at((lineStart + lineEnd) / 2, sign * (HALF_Z - BORDER_LINE)), lineEnd - lineStart)
		local z0, z1 = baseHalf + 3, HALF_Z - BORDER_LINE
		Kit.LinhaPintada(folder, at(lineEnd, sign * (z0 + z1) / 2, 90), z1 - z0)
	end
	Kit.FaixaDePedestre(folder, at(62.5, 0), 5, 12)
	Kit.Seta(folder, at(50, GATE_Z, 180), 5)
	Kit.LinhaPintada(folder, at(60.5, GATE_Z), 11, true)
	Kit.AreaHachurada(folder, at(YARD_CONTAINERS.Front.X, GATE_Z), Kit.Conteiner_Largura, 5, PALETTE.Aviso)
	Kit.AreaHachurada(folder, at(STAIR_LOW.FootX + 2, STAIR_LOW.Z), 4, STAIR_LOW.Width, PALETTE.Aviso)

	-- Base: anel em volta de onde se nasce e hachura no fundo
	local baseCenter = HALF_X + WORLD.BaseSize.X / 2
	Kit.MarcaDeBase(folder, at(baseCenter, 0), WORLD.BaseSize.X, WORLD.BaseSize.Y)

	-- Parede da frente da base: floreiras e luminárias (luz real) dos dois lados da passagem,
	-- extintor, quadro elétrico e hera
	for _, sign in { -1, 1 } do
		local z = sign * WALL_LAMP_Z
		Kit.Floreira(folder, at(BASE_WALL_FACE - 0.65, z, 90))
		Kit.Luminaria(folder, at(BASE_WALL_FACE, z, -90, WALL_LAMP_Y), true)
		Kit.ManchaDeLuz(folder, at(BASE_WALL_FACE - 3, z), 6)
	end
	Kit.QuadroEletrico(folder, at(BASE_WALL_FACE, -17, -90))
	Kit.Extintor(folder, at(BASE_WALL_FACE, 15, -90))
	Kit.Hera(folder, at(BASE_WALL_FACE, 19, -90), 5)
	Kit.Hera(folder, at(BASE_WALL_FACE, -13.5, -90), 3.5)

	-- Parede de chapa: hera do lado de fora, extintor do lado do meio
	local sheetHalf = 0.63 -- meia espessura com a ondulação e a ferrugem
	Kit.Hera(folder, at(SHEET_WALL.X + sheetHalf, SHEET_WALL.Y + 4, 90), 6)
	Kit.Extintor(folder, at(SHEET_WALL.X - sheetHalf, SHEET_WALL.Y - 1, -90))

	-- Ambiente: mato, boias na mureta, cones no pé da escada, pallets e corda no píer
	for _, plant in PLANTS do
		Kit.Mato(folder, at(plant[1], plant[2], plant[1] * 37 % 360), plant[3])
	end
	local railFace = HALF_Z - 0.5
	Kit.Boia(folder, at(25, -railFace, 0))
	Kit.Boia(folder, at(40, railFace, 180))
	for _, sign in { -1, 1 } do
		Kit.Cone(folder, at(STAIR_LOW.FootX + 4.8, STAIR_LOW.Z + sign * (STAIR_LOW.Width / 2 + 0.8)))
	end
	Kit.Pallets(folder, at(HALF_X - 2.3, -40, 10), 3)
	Kit.RoloDeCorda(folder, at(7.5, PIER_Z - 1.2))

	-- Luzes: embaixo da pilha (teto do vão), poste no canto do píer (luz real) e postes nos cantos
	-- do cais (só pintados)
	Kit.LuminariaDeTeto(folder, at(0, -2, 0, level1), true)
	Kit.ManchaDeLuz(folder, at(0, -2), 5)
	local pierPole = v2(17, -42.4)
	Kit.PosteDoCais(folder, at(pierPole.X, pierPole.Y, 180), true)
	Kit.ManchaDeLuz(folder, at(pierPole.X - Kit.Poste_Alcance, -42), 4)
	for _, sign in { -1, 1 } do
		local corner = v2(HALF_X - 1.8, sign * (HALF_Z - 1.9))
		Kit.PosteDoCais(folder, at(corner.X, corner.Y, sign * 135), false)
		local reach = Kit.Poste_Alcance / math.sqrt(2)
		Kit.ManchaDeLuz(folder, at(corner.X - reach, corner.Y - sign * reach), 5)
	end
end

local function half(frame: CFrame, folder: Instance, front: Kit.CorDeConteiner, north: Kit.CorDeConteiner)
	local function at(x: number, z: number, yaw: number?, y: number?): CFrame
		return Build.pivot(frame, v2(x, z), yaw, y)
	end

	-- Mureta na borda: menos na frente da base (parede com a passagem) e no recorte da água
	local rail = WORLD.IslandEdgeRail
	local baseHalf = WORLD.BaseSize.Y / 2
	local notchEnd = NOTCH.HalfWidth + 1.5 -- a mureta acaba 1 stud antes do recorte (onde fica a faixa de aviso)
	local edges = {
		{ v2(notchEnd, -HALF_Z), v2(HALF_X, -HALF_Z) },
		{ v2(HALF_X, -HALF_Z), v2(HALF_X, -baseHalf) },
		{ v2(HALF_X, baseHalf), v2(HALF_X, HALF_Z) },
		{ v2(notchEnd, HALF_Z), v2(HALF_X, HALF_Z) },
	}
	for _, edge in edges do
		Build.wall("Rail", frame, edge[1], edge[2], rail, 1, PALETTE.Metal, folder)
	end

	-- Pátio: cada contêiner na sua vaga pintada
	for _, spot in { { at = YARD_CONTAINERS.Front, cor = front }, { at = YARD_CONTAINERS.North, cor = north } } do
		local origin = at(spot.at.X, spot.at.Y, 90)
		Kit.Conteiner(folder, origin, spot.cor)
		Kit.Vaga(folder, origin)
	end
	Kit.ParedeDeChapa(folder, at(SHEET_WALL.X, SHEET_WALL.Y, 90))
	for _, crate in CRATES do
		Kit.CaixaDeMadeira(folder, at(crate[1], crate[2]), crate[3])
	end
	for _, group in BARRELS do
		Kit.Barris(folder, at(group[1], group[2]), group[3])
	end

	-- Escadas da ponta norte da pilha: do chão à plataforma (sobe para o oeste) e da plataforma ao
	-- topo (sobe para o sul)
	local level1 = Kit.Conteiner_Altura
	Kit.Escada(folder, at(STAIR_LOW.FootX, STAIR_LOW.Z, 180), STAIR_LOW.Length, level1, STAIR_LOW.Width)
	Kit.Escada(folder, at(0, STAIR_HIGH.FootZ, -90, level1), STAIR_HIGH.Length, level1, STAIR_HIGH.Width)

	-- Píer do norte: água no recorte inteiro, tablado, faixa de aviso nas beiras de concreto que dão
	-- para a água, cabeços, torre do guindaste e ponto de escudo
	local notchWidth = NOTCH.HalfWidth * 2
	Kit.Agua(folder, at(0, -(QUAY_Z + NOTCH.Depth / 2), 0, -WATER_DROP), notchWidth, NOTCH.Depth)
	local pier = Kit.PierDeMadeira(folder, at(0, PIER_Z), PIER.Length, PIER.Width)
	if pier.PrimaryPart then
		IslandCommon.ground(pier.PrimaryPart)
	end
	local slip = NOTCH.HalfWidth - PIER.Length / 2 -- 6: água em cada ponta do tablado
	for _, sign in { -1, 1 } do
		-- beira do cais (z = -44) e lateral do recorte (x = ±21), por dentro do concreto
		local quayX = sign * (PIER.Length / 2 + (slip + 1) / 2)
		Kit.FaixaDeAviso(folder, at(quayX, -QUAY_Z + 0.5), slip + 1)
		Kit.FaixaDeAviso(folder, at(sign * (NOTCH.HalfWidth + 0.5), -(QUAY_Z + NOTCH.Depth / 2), 90), NOTCH.Depth)
	end
	for _, x in BOLLARDS_X do
		Kit.CabecoDeAmarracao(folder, at(x, PIER_Z))
	end
	Kit.TorreDoGuindaste(folder, at(CRANE.At.X, CRANE.At.Y, -90, -WATER_DROP - 1), CRANE.Modules, CRANE.Jib)
	IslandCommon.shieldPoint(frame, folder, SHIELD.X, SHIELD.Y)
end

-- Peças únicas (já simétricas) ---------------------------------------------------------------------

local function floor(frame: CFrame, folder: Instance)
	local t = WORLD.IslandThickness
	local options = IslandCommon.NoShadow
	-- Chão de concreto: o miolo e os 4 cantos ao lado dos recortes
	local rects = { { v2(-HALF_X, -QUAY_Z), v2(HALF_X, QUAY_Z) } }
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local a, b = v2(sx * NOTCH.HalfWidth, sz * QUAY_Z), v2(sx * HALF_X, sz * HALF_Z)
			table.insert(
				rects,
				{ v2(math.min(a.X, b.X), math.min(a.Y, b.Y)), v2(math.max(a.X, b.X), math.max(a.Y, b.Y)) }
			)
		end
	end
	for _, rect in rects do
		IslandCommon.ground(Build.floorRect("Floor", frame, rect[1], rect[2], t, PALETTE.Concreto, folder, 0, options))
	end

	-- Juntas do piso (acabamento): uma a cada 14 studs de base a base e duas ao comprido
	local joint = { Width = 0.25, Height = 0.03 }
	for k = -4, 4 do
		local x = k * JOINT_STEP
		local a, b = v2(x - joint.Width / 2, -QUAY_Z), v2(x + joint.Width / 2, QUAY_Z)
		Build.floorRect("Junta", frame, a, b, joint.Height, PALETTE.ConcretoEscuro, folder, joint.Height, Build.Detail)
	end
	for _, sz in { -1, 1 } do
		local z = sz * JOINT_Z
		local a, b = v2(-HALF_X, z - joint.Width / 2), v2(HALF_X, z + joint.Width / 2)
		Build.floorRect("Junta", frame, a, b, joint.Height, PALETTE.ConcretoEscuro, folder, joint.Height, Build.Detail)
	end

	-- Rocha embaixo, sempre por dentro do contorno do chão (nada embaixo dos recortes: quem cai na
	-- água continua caindo), afunilando
	local rock = {
		{ half = v2(66, 40), height = 10 },
		{ half = v2(52, 30), height = 12 },
		{ half = v2(34, 18), height = 12 },
		{ half = v2(16, 8), height = 12 },
	}
	local top = -t
	for _, slab in rock do
		Build.block(
			"Underside",
			Vector3.new(slab.half.X * 2, slab.height, slab.half.Y * 2),
			frame * CFrame.new(0, top - slab.height / 2, 0),
			PALETTE.Rocha,
			folder,
			options
		)
		top -= slab.height
	end
end

-- Zonas (nomes dos pings): cobrem a área de duelo inteira, sem sobrepor.
local function zones(frame: CFrame, folder: Instance)
	local zone = IslandCommon.zone
	zone(frame, folder, "guindaste", v2(-14, -30), v2(14, 30))
	zone(frame, folder, "pier", v2(-30, -HALF_Z), v2(30, -30))
	zone(frame, folder, "pier", v2(-30, 30), v2(30, HALF_Z))
	zone(frame, folder, "meio", v2(14, -30), v2(30, 30), "east")
	zone(frame, folder, "meio", v2(-30, -30), v2(-14, 30), "west")
	zone(frame, folder, "patio", v2(30, -HALF_Z), v2(HALF_X, HALF_Z), "east")
	zone(frame, folder, "patio", v2(-HALF_X, -HALF_Z), v2(-30, HALF_Z), "west")
end

local Porto: IslandCommon.Island = {
	style = {
		floor = PALETTE.Concreto,
		rail = PALETTE.Metal,
		wall = PALETTE.Chapa,
		underside = PALETTE.Rocha,
	},
	build = function(frame: CFrame, folder: Instance)
		floor(frame, folder)
		-- Pilha do Guindaste: comprimento no sentido norte-sul (o contêiner A fica ao sul)
		assert(STACK.End == Kit.Pilha_Vao / 2 + Kit.Conteiner_Comprimento, "pilha fora das medidas do kit")
		Kit.PilhaDeConteineres(folder, Build.pivot(frame, v2(0, 0), 90), "Musgo", "Petroleo", "Laranja")
		half(frame, folder, "Laranja", "Petroleo")
		half(IslandCommon.rotated(frame), folder, "Mostarda", "Musgo")
		-- Detalhe: o vão por baixo da pilha (uma peça só, já simétrica) e cada metade
		Kit.AreaHachurada(folder, Build.pivot(frame, v2(0, 0)), Kit.Pilha_Vao, Kit.Pilha_Vao, PALETTE.Aviso)
		dress(frame, folder)
		dress(IslandCommon.rotated(frame), folder)
		zones(frame, folder)
	end,
}

return Porto
