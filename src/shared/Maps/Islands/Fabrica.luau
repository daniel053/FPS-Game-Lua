--!strict
-- Fábrica (GDD 15.5): planta em bloco colorido, a partir do desenho do dono do projeto (F10,
-- `docs/referencias/f10/fabrica-0-planta-do-dono.png`), com as peças do kit (KIT-MODULAR 3).
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

	-- Esteiras e caixas (paradas nesta etapa; o sentido fica no atributo da correia)
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
	end,
}

return Fabrica
