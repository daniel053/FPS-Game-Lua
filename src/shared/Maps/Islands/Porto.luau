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
		zones(frame, folder)
	end,
}

return Porto
