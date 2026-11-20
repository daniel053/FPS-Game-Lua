--!strict
-- Fábrica (GDD 15.5): planta aprovada pelo dono do projeto (F10), a partir do desenho dele
-- (`docs/referencias/f10/fabrica-0-planta-do-dono.png`), com a arte do kit (KIT-MODULAR 3).
--
-- Simetria de giro: o que existe numa metade existe girado 180° na outra (justo para os dois
-- times). Cada metade (a base fica em x > 70) tem:
--   * Controle (o "I" do desenho, no centro): plataforma fechada de 6 de altura atravessada na
--     frente da base (quebra a linha base a base), com rampa de frente para a base; as duas
--     plataformas se ligam por uma passarela com grade sobre pilares (passa-se por baixo);
--   * Depósito (o "L", do lado -Z): duas prateleiras altas em linha e uma máquina no pé, mais um
--     corredor de prateleiras atrás e a tubulação na parede do fundo;
--   * Esteira (a linha comprida, do lado +Z): duas esteiras em linha com um vão de 6 entre elas,
--     andando para fora (+Z), com caixas de papelão em cima;
--   * um ponto de escudo no meio de cada corredor lateral.
--
-- Coordenadas (x, z) no quadro da ilha, em studs: x de base a base, z de um lado ao outro (o
-- mirante fica do lado -Z). Medidas tiradas do desenho na escala de 140 studs de área de duelo
-- (148 px = 140 studs).

local Build = require(script.Parent.Parent.Build)
local Detalhe = require(script.Parent.Parent.Kits.Detalhe)
local IslandCommon = require(script.Parent.Parent.IslandCommon)
local Kit = require(script.Parent.Parent.Kits.Fabrica)
local MapConfig = require(script.Parent.Parent.Parent.Config.MapConfig)
local Theme = require(script.Parent.Parent.Parent.Config.Theme)

local WORLD = MapConfig.World
local PALETTE = Theme.Maps.Fabrica

local v2 = Vector2.new

type Placement = { at: Vector2, yaw: number }

-- Contorno da metade: cintura estreita no meio da ilha, chanfro do lado -Z, degrau reto do lado +Z.
local EDGE = 52.5 -- meia largura da ilha
local WAIST = 38.5 -- meia largura na cintura
local WAIST_END = 21 -- até onde vai a cintura (x)
local CHAMFER_END = 48 -- onde o chanfro chega na borda (x)
local BASE_X = 70 -- frente da base

-- Controle: plataforma (28 × 6, ao longo de z), rampa de frente para a base e passarela até o meio.
local PLATFORM: Placement = { at = v2(18, 0), yaw = 90 }
local RAMP = { Head = v2(21, 0), Run = 12 } -- desce para a base (+x)
local BRIDGE = { Length = 30, Width = 6, Pillars = { -7.5, 7.5 } } -- inteira, centrada na ilha

-- Depósito: o "L" (braço de duas prateleiras ao longo de z + máquina no pé, virada para a base) e o
-- corredor de prateleiras atrás. Prateleiras sempre ao longo de z: de lado para o mirante.
local SHELVES: { Placement } = {
	{ at = v2(40, -7), yaw = 90 }, -- braço do L
	{ at = v2(40, -17), yaw = 90 },
	{ at = v2(48.5, -37), yaw = 90 }, -- corredor de 8 entre estas duas
	{ at = v2(59.5, -37), yaw = 90 },
}
local MACHINES: { Placement } = {
	{ at = v2(45, -19.5), yaw = 0 }, -- pé do L
	{ at = v2(40, 15.5), yaw = 90 }, -- pátio da Esteira, entre a rampa e a esteira
	{ at = v2(12.5, 27.5), yaw = 90 }, -- corredor lateral +Z
}
local PIPES: { Placement } = {
	{ at = v2(67.5, -26), yaw = -90 }, -- parede do fundo do Depósito
	{ at = v2(23.5, 45), yaw = 90 }, -- parede do degrau, no canto da Esteira
}
local PALLETS: { Placement } = {
	{ at = v2(58, -13.5), yaw = 0 }, -- à direita da porta da base
	{ at = v2(29, -30.5), yaw = 0 }, -- entrada do Depósito
	{ at = v2(11.5, -26), yaw = 90 }, -- corredor lateral -Z
	{ at = v2(33, 32.5), yaw = 0 }, -- pátio da Esteira
	{ at = v2(44, 44), yaw = 0 },
}

-- Esteira: duas em linha em x = 56 (z de 4 a 24 e de 30 a 50), andando para +z (giro de -90).
local CONVEYOR_YAW = -90
local CONVEYORS = { v2(56, 14), v2(56, 40) }
local CONVEYOR_BOXES: { { at: Vector2, size: "grande" | "pequena" } } = {
	{ at = v2(56, 9), size = "grande" },
	{ at = v2(56, 18.5), size = "pequena" },
	{ at = v2(56, 36), size = "grande" },
	{ at = v2(56, 45), size = "pequena" },
}

-- Paredes de galpão (cenário nas bordas, sempre ao longo de z: de lado para o mirante).
local WALLS: { Placement } = {
	{ at = v2(BASE_X, 29), yaw = -90 }, -- dos dois lados da parede da base
	{ at = v2(BASE_X, 45), yaw = -90 },
	{ at = v2(BASE_X, -29), yaw = -90 },
	{ at = v2(BASE_X, -45), yaw = -90 },
	{ at = v2(WAIST_END, 45), yaw = 90 }, -- degrau da cintura
}

-- Ponto de escudo: no meio do corredor lateral (o outro vem do giro).
local SHIELD = v2(0, 26)

-- Passada de detalhe (depois da F10, Kits/Detalhe): só acabamento, nada colide nem muda a planta.
-- Posições na metade do leste; a outra é a mesma girada 180°. -----------------------------------------

-- Placas do piso em outro tom { x0, z0, x1, z1 }
local LIGHT_SLABS = {
	{ 14, 14, 28, 38.5 },
	{ 42, -14, 56, 14 },
	{ 28, -38.5, 42, -14 },
	{ 56, -30, 70, -14 },
}
-- Rachaduras { x, z, comprimento, giro } e manchas de óleo { x, z, diâmetro }
local CRACKS = { { 34, 22, 3.5, 15 }, { 50, -28, 3, -20 }, { 8, -20, 4, 30 }, { 62, 40, 3, 10 } }
local OIL = { { 50, -5, 3 }, { 26, 20, 2.4 }, { 60, -22, 2.2 }, { 35, -24, 2 }, { 48, 30, 2.6 }, { 6, 10, 2 } }
-- Tufos de mato { x, z, escala }: cantos de mureta e pé das paredes
local PLANTS = {
	{ 3, -37.4, 0.9 },
	{ 19.5, 37.4, 0.8 },
	{ 68.6, 51.4, 1 },
	{ 49, -51.4, 0.8 },
	{ 22.3, 51.4, 1 },
	{ 68.6, 20.2, 1.1 },
}
local BASE_WALL_FACE = BASE_X - 0.75 -- face da parede da base que dá para a área de duelo
local SHED_FACE = BASE_X - 0.67 -- face das paredes de galpão (com a ondulação)
local WALL_LAMP_Y = 5.6
local BRIDGE_CEILING = 5.5 -- vão livre embaixo da passarela

local function dress(frame: CFrame, folder: Instance)
	local cores = PALETTE.Detalhe
	local function at(x: number, z: number, yaw: number?, y: number?): CFrame
		return Build.pivot(frame, v2(x, z), yaw, y)
	end
	local margin = v2(1.2, 1.2)

	-- Chão: placas, rachaduras, óleo
	for _, slab in LIGHT_SLABS do
		local size = v2(slab[3] - slab[1], slab[4] - slab[2])
		Detalhe.Placa(folder, at((slab[1] + slab[3]) / 2, (slab[2] + slab[4]) / 2), size, cores.Placa)
	end
	for _, crack in CRACKS do
		Detalhe.Rachadura(folder, at(crack[1], crack[2], crack[4]), crack[3], cores)
	end
	for _, oil in OIL do
		Detalhe.Mancha(folder, at(oil[1], oil[2]), oil[3], cores)
	end

	-- Sombra pintada no pé do que fica em pé
	Detalhe.Sombra(folder, at(PLATFORM.at.X, PLATFORM.at.Y, PLATFORM.yaw), Kit.Sizes.Plataforma + margin, cores)
	for _, shelf in SHELVES do
		Detalhe.Sombra(folder, at(shelf.at.X, shelf.at.Y, shelf.yaw), v2(10, 3) + margin, cores)
	end
	for _, machine in MACHINES do
		Detalhe.Sombra(folder, at(machine.at.X, machine.at.Y, machine.yaw), v2(7, 5) + margin, cores)
	end
	for _, pipes in PIPES do
		Detalhe.Sombra(folder, at(pipes.at.X, pipes.at.Y, pipes.yaw), v2(8, 4) + margin, cores)
	end
	for _, pallet in PALLETS do
		Detalhe.Sombra(folder, at(pallet.at.X, pallet.at.Y, pallet.yaw), v2(7, 6), cores)
	end
	for _, wall in WALLS do
		local x = if wall.at.X >= BASE_X then SHED_FACE - 0.4 else wall.at.X + 0.9
		Detalhe.Sombra(folder, at(x, wall.at.Y, 90), v2(16, 0.8), cores)
	end
	local baseHalf = WORLD.BaseSize.Y / 2
	local door = WORLD.BaseDoorWidth / 2
	for _, sign in { -1, 1 } do
		Detalhe.Sombra(
			folder,
			at(BASE_WALL_FACE - 0.4, sign * (door + baseHalf) / 2, 90),
			v2(baseHalf - door, 0.8),
			cores
		)
	end

	-- Pintura: faixa de pedestre amarela na porta da base, seta e linha tracejada até a rampa, áreas
	-- hachuradas no pé da rampa, ao lado da tubulação e na frente da máquina do Depósito
	Detalhe.FaixaDePedestre(folder, at(63, 0), 5, 12, cores.Aviso)
	Detalhe.Seta(folder, at(40, 5, 180), 5, cores.Pintura)
	Detalhe.Linha(folder, at(52, 5), 16, cores.Pintura, true)
	Detalhe.AreaHachurada(folder, at(RAMP.Head.X + RAMP.Run + 1.5, 0), 3, Kit.Sizes.LarguraDaRampa, cores.Aviso)
	Detalhe.AreaHachurada(folder, at(63, -26), 3, 8, cores.Aviso)
	Detalhe.AreaHachurada(folder, at(45, -25.5), 7, 3, cores.Aviso)
	Detalhe.MarcaDeBase(
		folder,
		at(BASE_X + WORLD.BaseSize.X / 2, 0),
		WORLD.BaseSize.X,
		WORLD.BaseSize.Y,
		cores.Pintura,
		true
	)

	-- Ambiente: mato, hera, extintores, quadros elétricos, cones e pallets soltos
	for _, plant in PLANTS do
		Detalhe.Mato(folder, at(plant[1], plant[2], plant[1] * 37 % 360), plant[3], cores)
	end
	Detalhe.Hera(folder, at(SHED_FACE, 41, -90), 7, cores)
	Detalhe.Hera(folder, at(BASE_WALL_FACE, -17, -90), 4.5, cores)
	local platformEast = PLATFORM.at.X + Kit.Sizes.Plataforma.Y / 2 + 0.12
	local platformWest = PLATFORM.at.X - Kit.Sizes.Plataforma.Y / 2 - 0.12
	Detalhe.Extintor(folder, at(SHED_FACE, 25, -90), cores)
	Detalhe.Extintor(folder, at(platformEast, -9, 90), cores)
	Detalhe.QuadroEletrico(folder, at(SHED_FACE, -34.5, -90), cores)
	Detalhe.QuadroEletrico(folder, at(platformWest, 9, -90), cores)
	for _, sign in { -1, 1 } do
		Detalhe.Cone(folder, at(RAMP.Head.X + RAMP.Run + 3.8, sign * 3.8), cores)
	end
	Detalhe.Pallets(folder, at(66.8, 16, 0), 2, cores)

	-- Luzes reais (4 por metade): dos dois lados da porta da base, embaixo da passarela e na
	-- parede de galpão da Esteira. Só pintadas: no fundo do Depósito e na face da plataforma.
	for _, sign in { -1, 1 } do
		Detalhe.Luminaria(folder, at(BASE_WALL_FACE, sign * 10, -90, WALL_LAMP_Y), cores, true)
		Detalhe.ManchaDeLuz(folder, at(BASE_WALL_FACE - 3, sign * 10), 6, cores)
	end
	Detalhe.LuminariaDeTeto(folder, at(4, 0, 90, BRIDGE_CEILING), cores, true, 0)
	Detalhe.ManchaDeLuz(folder, at(4, 0), 4, cores)
	Detalhe.Luminaria(folder, at(SHED_FACE, 45, -90, 9), cores, true)
	Detalhe.ManchaDeLuz(folder, at(SHED_FACE - 3, 45), 6, cores)
	Detalhe.Luminaria(folder, at(SHED_FACE, -45, -90, 9), cores, false)
	Detalhe.ManchaDeLuz(folder, at(SHED_FACE - 3, -45), 6, cores)
	Detalhe.Luminaria(folder, at(platformWest, -9, -90, 4.5), cores, false)
	Detalhe.ManchaDeLuz(folder, at(platformWest - 2.5, -9), 4, cores)
end

local function half(frame: CFrame, folder: Instance, side: "east" | "west")
	local t = WORLD.IslandThickness
	local rail = WORLD.IslandEdgeRail
	local floorOptions = IslandCommon.NoShadow

	-- Chão: 3 retângulos e o triângulo do chanfro
	local function floor(min: Vector2, max: Vector2)
		IslandCommon.ground(Build.floorRect("Floor", frame, min, max, t, PALETTE.Piso, folder, 0, floorOptions))
	end
	floor(v2(0, -WAIST), v2(WAIST_END, WAIST))
	floor(v2(WAIST_END, -WAIST), v2(BASE_X, EDGE))
	floor(v2(CHAMFER_END, -EDGE), v2(BASE_X, -WAIST))
	IslandCommon.ground(
		Build.floorTriangle(
			"Floor",
			frame,
			v2(CHAMFER_END, -WAIST),
			v2(WAIST_END, -WAIST),
			v2(CHAMFER_END, -EDGE),
			t,
			PALETTE.Piso,
			folder,
			0,
			floorOptions
		)
	)

	-- Juntas do piso (acabamento): uma a cada 14 studs, na largura da cintura
	for k = 1, 4 do
		local x = k * 14
		Build.floorRect(
			"Junta",
			frame,
			v2(x - 0.12, -WAIST),
			v2(x + 0.12, WAIST),
			0.03,
			PALETTE.PisoFaixa,
			folder,
			0.03,
			Build.Detail
		)
	end

	-- Rocha embaixo, sempre por dentro do contorno do chão: 3 placas logo abaixo, 2 mais fundo
	local rock: { { min: Vector2, max: Vector2, top: number, height: number } } = {
		{ min = v2(0, -34), max = v2(66, 34), top = -t, height = 10 },
		{ min = v2(25, 34), max = v2(66, 48), top = -t, height = 10 },
		{ min = v2(50, -48), max = v2(66, -34), top = -t, height = 10 },
		{ min = v2(0, -24), max = v2(48, 24), top = -t - 10, height = 12 },
		{ min = v2(0, -12), max = v2(26, 12), top = -t - 22, height = 12 },
	}
	for _, slab in rock do
		local size = slab.max - slab.min
		local mid = (slab.min + slab.max) / 2
		Build.block(
			"Underside",
			Vector3.new(size.X, slab.height, size.Y),
			frame * CFrame.new(mid.X, slab.top - slab.height / 2, mid.Y),
			PALETTE.Rocha,
			folder,
			floorOptions
		)
	end

	-- Mureta na borda. Onde há parede de galpão não há mureta, e as pontas param na face da parede
	-- (a mureta ganha meio stud em cada ponta) para duas cores não ficarem no mesmo plano.
	local edges = {
		{ v2(0.5, -WAIST), v2(WAIST_END, -WAIST) },
		{ v2(WAIST_END, -WAIST), v2(CHAMFER_END, -EDGE) },
		{ v2(CHAMFER_END, -EDGE), v2(BASE_X - 1, -EDGE) },
		{ v2(WAIST_END + 1, EDGE), v2(BASE_X - 1, EDGE) },
		{ v2(0.5, WAIST), v2(WAIST_END - 1, WAIST) },
	}
	for _, edge in edges do
		Build.wall("Rail", frame, edge[1], edge[2], rail, 1, PALETTE.Metal, folder)
	end
	for _, wall in WALLS do
		Kit.ParedeDeGalpao(folder, Build.pivot(frame, wall.at, wall.yaw))
	end

	-- Controle
	Kit.PlataformaDeControle(folder, Build.pivot(frame, PLATFORM.at, PLATFORM.yaw))
	Kit.RampaDeAcesso(folder, Build.pivot(frame, RAMP.Head, 0), RAMP.Run)

	-- Depósito, máquinas, tubulações e pallets
	for _, shelf in SHELVES do
		Kit.PrateleiraAlta(folder, Build.pivot(frame, shelf.at, shelf.yaw))
	end
	for _, machine in MACHINES do
		Kit.Maquina(folder, Build.pivot(frame, machine.at, machine.yaw))
	end
	for _, pipes in PIPES do
		Kit.Tubulacao(folder, Build.pivot(frame, pipes.at, pipes.yaw))
	end
	for _, pallet in PALLETS do
		Kit.PalletComTambores(folder, Build.pivot(frame, pallet.at, pallet.yaw))
	end

	-- Esteiras e caixas (montadas paradas; o servidor da partida liga o movimento: `Conveyors`)
	for _, at in CONVEYORS do
		Kit.Esteira(folder, Build.pivot(frame, at, CONVEYOR_YAW))
	end
	for _, box in CONVEYOR_BOXES do
		Kit.CaixaNaEsteira(folder, Build.pivot(frame, box.at, 0, Kit.Sizes.AlturaDaEsteira), box.size)
	end

	IslandCommon.shieldPoint(frame, folder, SHIELD.X, SHIELD.Y)

	-- Zonas da metade (o Controle, no centro, é um só)
	local controlHalf = Kit.Sizes.Plataforma.X / 2
	local midHalf = 8
	IslandCommon.zone(frame, folder, "meio", v2(WAIST_END, -midHalf), v2(BASE_X, midHalf), side)
	IslandCommon.zone(frame, folder, "esteira", v2(WAIST_END, midHalf), v2(BASE_X, EDGE), side)
	IslandCommon.zone(frame, folder, "esteira", v2(0, controlHalf), v2(WAIST_END, EDGE), side)
	IslandCommon.zone(frame, folder, "deposito", v2(WAIST_END, -EDGE), v2(BASE_X, -midHalf), side)
	IslandCommon.zone(frame, folder, "deposito", v2(0, -EDGE), v2(WAIST_END, -controlHalf), side)
end

local Fabrica: IslandCommon.Island = {
	style = {
		floor = PALETTE.Piso,
		rail = PALETTE.Metal,
		wall = PALETTE.Tijolo,
		underside = PALETTE.Rocha,
	},
	build = function(frame: CFrame, folder: Instance)
		half(frame, folder, "east")
		half(IslandCommon.rotated(frame), folder, "west")
		-- Passarela do Controle (a alma do "I"): uma peça só, de plataforma a plataforma
		Kit.PassarelaComGrade(
			folder,
			Build.pivot(frame, Vector2.zero, 0),
			BRIDGE.Length,
			{ width = BRIDGE.Width, pillars = BRIDGE.Pillars }
		)
		local controlHalf = Kit.Sizes.Plataforma.X / 2
		IslandCommon.zone(frame, folder, "controle", v2(-WAIST_END, -controlHalf), v2(WAIST_END, controlHalf))
		-- Detalhe: área hachurada embaixo da passarela (uma peça só, já simétrica) e cada metade
		Detalhe.AreaHachurada(folder, Build.pivot(frame, Vector2.zero), 8, BRIDGE.Width, PALETTE.Detalhe.Aviso)
		dress(frame, folder)
		dress(IslandCommon.rotated(frame), folder)
	end,
}

return Fabrica
