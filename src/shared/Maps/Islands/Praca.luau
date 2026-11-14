--!strict
-- Praça (GDD 15.4): planta do dono do projeto (F10), em bloco cinza com as medidas e alturas.
--
-- Duas áreas chanfradas encaixadas, com simetria de giro (o que existe numa metade existe girado
-- 180° na outra: justo para os dois times). Cada metade tem:
--   * a passarela elevada (nível 1) ao longo do lado diagonal, com rampa nas duas pontas;
--   * o muro comprido com a caixa de madeira na ponta;
--   * o canteiro de grama em triângulo (rente ao chão, não protege);
--   * a caixa de madeira encostada na borda.
-- As duas metades se ligam pelo meio (passagem de 18 studs). Sem coreto e sem chafariz (dono, F10).
--
-- Coordenadas (x, z) no quadro da ilha, em studs: x de base a base (a base desta metade fica em
-- x > 70), z de um lado ao outro. Medidas tiradas da planta na escala de 140 studs de área de duelo.

local Build = require(script.Parent.Parent.Build)
local IslandCommon = require(script.Parent.Parent.IslandCommon)
local MapConfig = require(script.Parent.Parent.Parent.Config.MapConfig)
local Theme = require(script.Parent.Parent.Parent.Config.Theme)

local WORLD = MapConfig.World
local GRAY = Theme.Match
local PALETTE = Theme.Maps.Praca

local v2 = Vector2.new

-- Contorno da metade (sentido horário): começo da diagonal, topo da diagonal, chanfro de cima,
-- lado da base, chanfro de baixo, borda de baixo, borda do meio.
local DIAG_START = v2(0, -9) -- no meio da ilha
local DIAG_END = v2(46, -53) -- na borda de cima
local OUTLINE = {
	DIAG_START,
	DIAG_END,
	v2(70, -29),
	v2(70, 29),
	v2(46, 53),
	v2(0, 53),
	v2(0, 9),
}

-- Passarela elevada ao longo da diagonal (por dentro), com rampa nas duas pontas.
local WALK = {
	Height = 5, -- nível 1
	Width = 10,
	Start = 8, -- studs a partir do meio da ilha, ao longo da diagonal (deixa a passagem do meio livre)
	RampLength = 10,
	FlatLength = 32,
	GuardHeight = 3, -- mureta em cima, do lado de fora (lado do vazio)
}

-- Muro comprido com a caixa de madeira na ponta (o "!" da planta)
local WALL = { X = 31.5, FromZ = -3, ToZ = 17, Height = 4, Thickness = 2 }
local WALL_CRATE = { X = 31.5, Z = 20.5, Size = 6 }
-- Caixa encostada na borda de baixo
local EDGE_CRATE = { X = 31, Z = 48.5, Size = 6 }
-- Canteiro de grama em triângulo (o "^" da planta): base reta e ponta
local BED = { Left = v2(22.5, -13.5), Right = v2(51, -13.5), Tip = v2(36.8, -27.8), Height = 0.3 }

local function half(frame: CFrame, folder: Instance)
	local t = WORLD.IslandThickness
	local rail = WORLD.IslandEdgeRail
	local floorOptions = IslandCommon.NoShadow

	-- Chão: 2 retângulos e 3 triângulos (os dois chanfros do lado da base e a diagonal grande)
	local function ground(part: BasePart)
		IslandCommon.ground(part)
	end
	ground(Build.floorRect("Floor", frame, v2(0, -9), v2(46, 53), t, GRAY.IslandFloor, folder, 0, floorOptions))
	ground(Build.floorRect("Floor", frame, v2(46, -29), v2(70, 29), t, GRAY.IslandFloor, folder, 0, floorOptions))
	ground(
		Build.floorTriangle(
			"Floor",
			frame,
			v2(46, -29),
			v2(70, -29),
			v2(46, -53),
			t,
			GRAY.IslandFloor,
			folder,
			0,
			floorOptions
		)
	)
	ground(
		Build.floorTriangle(
			"Floor",
			frame,
			v2(46, 29),
			v2(70, 29),
			v2(46, 53),
			t,
			GRAY.IslandFloor,
			folder,
			0,
			floorOptions
		)
	)
	ground(
		Build.floorTriangle(
			"Floor",
			frame,
			v2(46, -9),
			DIAG_START,
			DIAG_END,
			t,
			GRAY.IslandFloor,
			folder,
			0,
			floorOptions
		)
	)

	-- Rocha embaixo, sempre por dentro do contorno do chão (nos recortes ela aparecia de cima):
	-- afunilando: as duas primeiras logo abaixo do chão, as outras mais fundo
	local rock: { { min: Vector2, max: Vector2, height: number } } = {
		{ min = v2(4, -5), max = v2(42, 49), height = 10 },
		{ min = v2(46, -25), max = v2(66, 25), height = 10 },
		{ min = v2(12, 4), max = v2(40, 40), height = 12 },
		{ min = v2(20, 14), max = v2(32, 30), height = 12 },
	}
	for i, slab in rock do
		local min, max, height = slab.min, slab.max, slab.height
		local top = if i <= 2 then -t else -t - 10 - (i - 3) * 12
		local size = max - min
		local mid = (min + max) / 2
		Build.block(
			"Underside",
			Vector3.new(size.X, height, size.Y),
			frame * CFrame.new(mid.X, top - height / 2, mid.Y),
			GRAY.IslandUnderside,
			folder,
			floorOptions
		)
	end

	-- Mureta na borda (menos na frente da base, que tem a parede com a passagem)
	local baseHalf = WORLD.BaseSize.Y / 2
	local edges = {
		{ OUTLINE[1], OUTLINE[2] },
		{ OUTLINE[2], OUTLINE[3] },
		{ OUTLINE[3], v2(70, -baseHalf) },
		{ v2(70, baseHalf), OUTLINE[4] },
		{ OUTLINE[4], OUTLINE[5] },
		{ OUTLINE[5], OUTLINE[6] },
		{ OUTLINE[6], OUTLINE[7] },
	}
	for _, edge in edges do
		Build.wall("Rail", frame, edge[1], edge[2], rail, 1, GRAY.IslandRail, folder)
	end

	-- Passarela elevada
	local along = (DIAG_END - DIAG_START).Unit
	local inward = v2(-along.Y, along.X) -- para dentro da metade
	if inward:Dot(v2(70, 0) - DIAG_START) < 0 then
		inward = -inward
	end
	local function onWalk(s: number, offset: number?): Vector2
		return DIAG_START + along * s + inward * (offset or WALK.Width / 2)
	end
	local s0 = WALK.Start
	local s1 = s0 + WALK.RampLength
	local s2 = s1 + WALK.FlatLength
	local s3 = s2 + WALK.RampLength
	Build.ramp("WalkRamp", frame, onWalk(s0), onWalk(s1), 0, WALK.Height, WALK.Width, GRAY.IslandRamp, folder)
	Build.ramp("WalkRamp", frame, onWalk(s3), onWalk(s2), 0, WALK.Height, WALK.Width, GRAY.IslandRamp, folder)
	local hw = WALK.Width / 2
	Build.wall("Walkway", frame, onWalk(s1 + hw), onWalk(s2 - hw), WALK.Height, WALK.Width, GRAY.IslandRamp, folder)
	Build.wall(
		"WalkGuard",
		frame,
		onWalk(s1, 0.5),
		onWalk(s2, 0.5),
		WALK.GuardHeight,
		1,
		GRAY.IslandRail,
		folder,
		WALK.Height
	)

	-- Muro comprido + caixa de madeira na ponta
	Build.wall(
		"BrickWall",
		frame,
		v2(WALL.X, WALL.FromZ + WALL.Thickness / 2),
		v2(WALL.X, WALL.ToZ - WALL.Thickness / 2),
		WALL.Height,
		WALL.Thickness,
		GRAY.IslandWall,
		folder
	)
	for _, crate in { WALL_CRATE, EDGE_CRATE } do
		Build.onFloor("Crate", Vector3.one * crate.Size, frame, crate.X, crate.Z, PALETTE.Madeira, folder)
	end

	-- Canteiro de grama (dois triângulos retângulos com o ângulo reto no meio da base)
	local mid = v2(BED.Tip.X, BED.Left.Y)
	for _, corner in { BED.Left, BED.Right } do
		Build.floorTriangle("GrassBed", frame, mid, corner, BED.Tip, BED.Height, PALETTE.Grama, folder, BED.Height)
	end
end

return function(frame: CFrame, folder: Instance)
	half(frame, folder)
	half(IslandCommon.rotated(frame), folder)
end
