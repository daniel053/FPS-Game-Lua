--!strict
-- Praça (GDD 15.4): planta do dono do projeto (F10), com a arte final do kit da Praça
-- (KIT-MODULAR 4, `Maps/Kits/Praca`).
--
-- Duas áreas chanfradas encaixadas, com simetria de giro (o que existe numa metade existe girado
-- 180° na outra: justo para os dois times). Cada metade tem:
--   * a passarela elevada (nível 1) ao longo do lado diagonal, com rampa nas duas pontas;
--   * o muro comprido com a caixa de madeira na ponta;
--   * o canteiro de grama em triângulo (rente ao chão, não protege);
--   * a caixa de madeira encostada na borda.
-- As duas metades se ligam pelo meio (passagem de 18 studs). Sem coreto e sem chafariz (dono, F10).
--
-- As peças que colidem estão nas mesmas posições e tamanhos do bloco cinza aprovado. A arte entra
-- como acabamento (não colide) e como moldura FORA da área de duelo: ilhotas com sobrados, árvores
-- e barraca, que não colidem nem bloqueiam tiro (quem pula a mureta cai como antes).
--
-- Coordenadas (x, z) no quadro da ilha, em studs: x de base a base (a base desta metade fica em
-- x > 70), z de um lado ao outro (o mirante fica do lado -z). Medidas tiradas da planta na escala
-- de 140 studs de área de duelo.

local Build = require(script.Parent.Parent.Build)
local IslandCommon = require(script.Parent.Parent.IslandCommon)
local Kit = require(script.Parent.Parent.Kits.Praca)
local MapConfig = require(script.Parent.Parent.Parent.Config.MapConfig)
local Theme = require(script.Parent.Parent.Parent.Config.Theme)

local WORLD = MapConfig.World
local PALETTE = Theme.Maps.Praca
local DETAIL = Build.Detail

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
local INTERIOR = v2(35, 10) -- um ponto dentro da metade (diz qual é o lado de dentro das muretas)
local CHAMFER_SUM = 99 -- nos chanfros, x - z = 99 (o de cima) e x + z = 99 (o de baixo)

-- Passarela elevada ao longo da diagonal (por dentro), com rampa nas duas pontas.
local WALK = {
	Height = 5, -- nível 1
	Width = 10,
	Start = 8, -- studs a partir do meio da ilha, ao longo da diagonal (deixa a passagem do meio livre)
	RampLength = 10,
	FlatLength = 32,
	GuardHeight = 3, -- mureta em cima, do lado de fora (lado do vazio)
}

-- Muro comprido (altura 4, a do kit) com a caixa de madeira na ponta (o "!" da planta)
local WALL = { X = 31.5, FromZ = -3, ToZ = 17, Thickness = 2 }
local WALL_CRATE = { X = 31.5, Z = 20.5, Size = 6 }
-- Caixa encostada na borda de baixo
local EDGE_CRATE = { X = 31, Z = 48.5, Size = 6 }
-- Canteiro de grama em triângulo (o "^" da planta): base reta e ponta
local BED = { Left = v2(22.5, -13.5), Right = v2(51, -13.5), Tip = v2(36.8, -27.8), Height = 0.3 }

-- Lajotas do chão (acabamento, 0,1 acima do chão): juntas a cada 8 studs e faixa junto à mureta
local TILE = { Step = 8, Joint = 0.5, Height = 0.1, Band = 2 }

-- Parede da frente da base: medidas do IslandCommon (que não exporta); se mudarem lá, mudar aqui.
local BASE_WALL = { Height = 7, Thickness = 1.5 }

-- Pontos de escudo: no chão aberto de cada metade, no meio de uma lajota. Ver o relatório da F10:
-- à vista das duas passarelas e da passagem do meio, a ~20 studs da cobertura mais próxima.
local SHIELD = v2(12, 28)

-- Postes e bancos dentro da área de duelo, sempre encostados na mureta (não bloqueiam tiro).
-- `yaw`: para onde aponta o braço do poste / a frente do banco (0 = +z, 90 = +x, 180 = -z).
local POSTS = {
	{ at = v2(6, 52.25), yaw = 180 },
	{ at = v2(22, 52.25), yaw = 180 },
	{ at = v2(42, 52.25), yaw = 180 },
	{ at = v2(0.75, 20), yaw = 90 },
	{ at = v2(0.75, 40), yaw = 90 },
	{ at = v2(69.25, -25), yaw = -90 },
	{ at = v2(69.25, 25), yaw = -90 },
}
local BENCHES = {
	{ at = v2(14, 51.5), yaw = 180 },
	{ at = v2(38, 51.5), yaw = 180 },
	{ at = v2(1.5, 30), yaw = 90 },
}

-- Zonas (pings): a metade de cima (z < -9) é dividida em degraus ao longo da diagonal, entre a
-- Passarela (lado do meio) e o Canteiro (lado da base). Cada degrau: de z[i] a z[i + 1], corte em x[i].
local ZONE_MID = 14 -- meia largura da zona "Meio"
local ZONE_STEPS = {
	Z = { -52.5, -44, -35, -26, -17.5, -9 },
	X = { 56, 47, 38, 29, 20 },
}

-- Vetor para dentro da metade, perpendicular à borda a → b.
local function inwardNormal(a: Vector2, b: Vector2): Vector2
	local dir = (b - a).Unit
	local normal = v2(-dir.Y, dir.X)
	if normal:Dot(INTERIOR - a) < 0 then
		normal = -normal
	end
	return normal
end

-- Trecho do chão da metade numa linha de z fixo (de x mínimo a x máximo).
local function xRange(z: number): (number, number)
	local diagonal = (DIAG_END.X - DIAG_START.X) / (DIAG_START.Y - DIAG_END.Y)
	local minX = if z < DIAG_START.Y then (DIAG_START.Y - z) * diagonal else 0
	local maxX = math.min(OUTLINE[3].X, CHAMFER_SUM + z, CHAMFER_SUM - z)
	return minX, maxX
end

-- Trecho do chão da metade numa linha de x fixo (de z mínimo a z máximo).
local function zRange(x: number): (number, number)
	if x <= DIAG_END.X then
		local diagonal = (DIAG_START.Y - DIAG_END.Y) / (DIAG_END.X - DIAG_START.X)
		return DIAG_START.Y - x * diagonal, OUTLINE[5].Y
	end
	return x - CHAMFER_SUM, CHAMFER_SUM - x
end

-- Chão de lajota clara: as 5 peças grandes do bloco cinza, mais as juntas e a faixa da borda.
local function floor(frame: CFrame, folder: Instance)
	local t = WORLD.IslandThickness
	local color = PALETTE.Piso
	local options = IslandCommon.NoShadow
	IslandCommon.ground(Build.floorRect("Floor", frame, v2(0, -9), v2(46, 53), t, color, folder, 0, options))
	IslandCommon.ground(Build.floorRect("Floor", frame, v2(46, -29), v2(70, 29), t, color, folder, 0, options))
	local triangles = {
		{ v2(46, -29), v2(70, -29), v2(46, -53) }, -- chanfro de cima
		{ v2(46, 29), v2(70, 29), v2(46, 53) }, -- chanfro de baixo
		{ v2(46, -9), DIAG_START, DIAG_END }, -- diagonal grande
	}
	for _, tri in triangles do
		IslandCommon.ground(Build.floorTriangle("Floor", frame, tri[1], tri[2], tri[3], t, color, folder, 0, options))
	end

	local model = Build.model("Lajotas", folder)
	local h, half = TILE.Height, TILE.Joint / 2
	local line = PALETTE.PisoFaixa
	-- Juntas: as pontas ficam embaixo das muretas
	for i = -6, 6 do
		local z = i * TILE.Step
		local minX, maxX = xRange(z)
		Build.floorRect("Junta", frame, v2(minX, z - half), v2(maxX, z + half), h, line, model, h, DETAIL)
	end
	for i = 1, 8 do
		local x = i * TILE.Step
		local minZ, maxZ = zRange(x)
		Build.floorRect("Junta", frame, v2(x - half, minZ), v2(x + half, maxZ), h, line, model, h, DETAIL)
	end
	-- Faixa junto à mureta (menos na diagonal, que fica embaixo da passarela), no comprimento exato
	-- de cada borda: nos cantos as faixas se sobrepõem e nada sai para fora da mureta.
	for i = 2, 6 do
		local a, b = OUTLINE[i], OUTLINE[i + 1]
		local dir = (b - a).Unit
		local shift = inwardNormal(a, b) * (0.5 + TILE.Band / 2)
		local trim = dir * (TILE.Band / 2)
		Build.wall("Faixa", frame, a + shift + trim, b + shift - trim, h, TILE.Band, line, model, 0, DETAIL)
	end
end

-- Rocha embaixo, sempre por dentro do contorno do chão (nos recortes ela aparecia de cima):
-- afunilando: as duas primeiras logo abaixo do chão (terra), as outras mais fundo (rocha escura).
local function rock(frame: CFrame, folder: Instance)
	local t = WORLD.IslandThickness
	local slabs: { { min: Vector2, max: Vector2, height: number } } = {
		{ min = v2(4, -5), max = v2(42, 49), height = 10 },
		{ min = v2(46, -25), max = v2(66, 25), height = 10 },
		{ min = v2(12, 4), max = v2(40, 40), height = 12 },
		{ min = v2(20, 14), max = v2(32, 30), height = 12 },
	}
	for i, slab in slabs do
		local top = if i <= 2 then -t else -t - 10 - (i - 3) * 12
		local color = if i <= 2 then PALETTE.Terra else PALETTE.TerraEscura
		Build.floorRect("Underside", frame, slab.min, slab.max, slab.height, color, folder, top, IslandCommon.NoShadow)
	end
end

-- Mureta na borda (menos na frente da base, que tem a parede com a passagem) e pilar em cada canto.
local function rails(frame: CFrame, folder: Instance)
	local rail = WORLD.IslandEdgeRail
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
		Kit.Mureta(folder, frame, edge[1], edge[2], rail, INTERIOR)
	end
	-- O canto 1 desta metade é o canto 7 da outra
	for i = 2, #OUTLINE do
		Kit.Pilar(folder, Build.pivot(frame, OUTLINE[i]), rail)
	end
end

-- Acabamento da base desta metade (as peças da base são do IslandCommon): capa de telha nas
-- muretas e na parede da frente, e rodapé de pedra na parede.
local function baseTrim(frame: CFrame, folder: Instance)
	local model = Build.model("AcabamentoDaBase", folder)
	local x0 = WORLD.BodySize.X / 2
	local x1 = x0 + WORLD.BaseSize.X
	local hz = WORLD.BaseSize.Y / 2
	local door = WORLD.BaseDoorWidth / 2
	local capY = WORLD.IslandEdgeRail - 0.4
	local tile, stone = PALETTE.Telha, PALETTE.Pedra
	Build.wall("Capa", frame, v2(x1, -hz), v2(x1, hz), 0.5, 1.3, tile, model, capY, DETAIL)
	for _, sign in { -1, 1 } do
		Build.wall("Capa", frame, v2(x0 + 1, sign * hz), v2(x1, sign * hz), 0.5, 1.3, tile, model, capY, DETAIL)
		local a, b = v2(x0, sign * door), v2(x0, sign * hz)
		local wallCapY = BASE_WALL.Height - 0.4
		Build.wall("CapaDaParede", frame, a, b, 0.5, BASE_WALL.Thickness + 0.3, tile, model, wallCapY, DETAIL)
		Build.wall("RodapeDaParede", frame, a, b, 0.8, BASE_WALL.Thickness + 0.2, stone, model, 0, DETAIL)
	end
end

-- Ilhota de rocha fora da área de duelo (moldura): grama em cima, terra e rocha embaixo. Não colide.
local function islet(frame: CFrame, folder: Instance, min: Vector2, max: Vector2, topY: number): Model
	local model = Build.model("Ilhota", folder)
	model.PrimaryPart = Build.floorRect("Grama", frame, min, max, 1, PALETTE.Grama, model, topY, DETAIL)
	local inset = v2(1.5, 1.5)
	Build.floorRect("Terra", frame, min + inset, max - inset, 5, PALETTE.Terra, model, topY - 1, DETAIL)
	Build.floorRect("Rocha", frame, min + inset * 3, max - inset * 3, 5, PALETTE.TerraEscura, model, topY - 6, DETAIL)
	return model
end

-- Moldura: 4 ilhotas por metade, todas fora da mureta, com sobrados, árvores e barraca de feira.
-- Tudo aqui é cenário (`scenery`): não colide e não bloqueia tiro.
local function scenery(frame: CFrame, folder: Instance)
	local model = Build.model("Moldura", folder)
	local SCENERY = { scenery = true }
	local function tree(x: number, z: number, y: number)
		Kit.ArvoreLowPoly(model, Build.pivot(frame, v2(x, z), 0, y), SCENERY)
	end

	-- 1. No recorte ao lado da passarela (do outro lado da diagonal): sobrado e 2 árvores
	local notchY = -2
	islet(frame, model, v2(6, -59), v2(24, -41), notchY)
	Kit.Sobrado(model, Build.pivot(frame, v2(17.5, -52), 0, notchY), { balcony = true, scenery = true })
	tree(9.5, -45, notchY)
	tree(21, -44, notchY)

	-- 2. Além do chanfro de cima, ao lado da base: sobrado e árvore
	local upperY = -3
	islet(frame, model, v2(66, -57), v2(86, -41), upperY)
	Kit.Sobrado(
		model,
		Build.pivot(frame, v2(78, -50), 0, upperY),
		{ door = PALETTE.ToldoPetroleo, flip = true, scenery = true }
	)
	tree(69.5, -45, upperY)

	-- 3. Além do chanfro de baixo, ao lado da base: sobrado (de frente para a praça) e árvore
	local lowerY = -3
	islet(frame, model, v2(64, 43), v2(86, 59), lowerY)
	Kit.Sobrado(model, Build.pivot(frame, v2(77, 52), 180, lowerY), { door = PALETTE.Folhas, scenery = true })
	tree(68, 47.5, lowerY)

	-- 4. Além da borda de baixo: a rua, com 2 sobrados, a barraca de feira, um poste e 2 árvores
	local streetY = -2
	islet(frame, model, v2(4, 60), v2(44, 76), streetY)
	Build.floorRect("Calcada", frame, v2(10, 61), v2(42, 64.5), 0.1, PALETTE.Piso, model, streetY + 0.1, DETAIL)
	Kit.Sobrado(model, Build.pivot(frame, v2(15, 69), 180, streetY), { balcony = true, scenery = true })
	Kit.Sobrado(
		model,
		Build.pivot(frame, v2(27, 69), 180, streetY),
		{ door = PALETTE.ToldoPetroleo, flip = true, balcony = true, scenery = true }
	)
	Kit.BarracaDeFeira(model, Build.pivot(frame, v2(38, 67), 180, streetY), SCENERY)
	Kit.PosteDeLuz(model, Build.pivot(frame, v2(21, 62), 180, streetY), SCENERY)
	tree(7, 64, streetY)
	tree(40.5, 72.5, streetY)
end

local function half(frame: CFrame, folder: Instance)
	floor(frame, folder)
	rock(frame, folder)
	rails(frame, folder)
	baseTrim(frame, folder)

	-- Passarela elevada: o quadro dela fica no meio do trecho plano, com o X local ao longo da
	-- diagonal e o +Z local para dentro da metade (o guarda-corpo fica do lado do vazio).
	local along = (DIAG_END - DIAG_START).Unit
	local inward = inwardNormal(DIAG_START, DIAG_END)
	local middle = WALK.Start + WALK.RampLength + WALK.FlatLength / 2
	local center = DIAG_START + along * middle + inward * (WALK.Width / 2)
	local yaw = math.deg(math.atan2(-along.Y, along.X))
	Kit.Passarela(folder, Build.pivot(frame, center, yaw), {
		FlatLength = WALK.FlatLength,
		Width = WALK.Width,
		Height = WALK.Height,
		RampLength = WALK.RampLength,
		GuardHeight = WALK.GuardHeight,
	})

	-- Muro comprido + caixa de madeira na ponta; caixa na borda
	local wallMid = v2(WALL.X, (WALL.FromZ + WALL.ToZ) / 2)
	Kit.MuroDeTijolo(folder, Build.pivot(frame, wallMid, 90), WALL.ToZ - WALL.FromZ, WALL.Thickness)
	for _, crate in { WALL_CRATE, EDGE_CRATE } do
		Kit.CaixaDeMadeira(folder, Build.pivot(frame, v2(crate.X, crate.Z)), crate.Size)
	end

	-- Canteiro de grama (ponta para o lado -z)
	Kit.Canteiro(
		folder,
		Build.pivot(frame, v2(BED.Tip.X, BED.Left.Y)),
		BED.Tip.X - BED.Left.X,
		BED.Right.X - BED.Tip.X,
		BED.Left.Y - BED.Tip.Y,
		BED.Height
	)

	for _, post in POSTS do
		Kit.PosteDeLuz(folder, Build.pivot(frame, post.at, post.yaw))
	end
	for _, bench in BENCHES do
		Kit.BancoDePraca(folder, Build.pivot(frame, bench.at, bench.yaw))
	end

	scenery(frame, folder)
end

-- Rosácea no chão do meio da ilha (só acabamento): marca o "Meio" para quem vê de cima.
local function centerpiece(frame: CFrame, folder: Instance)
	local model = Build.model("Rosacea", folder)
	Build.prism("Anel", 8, 14, 0.1, frame * CFrame.new(0, 0.05, 0), PALETTE.PisoFaixa, model, DETAIL)
	Build.prism("Miolo", 8, 12, 0.16, frame * CFrame.new(0, 0.08, 0), PALETTE.Piso, model, DETAIL)
	local turn = CFrame.Angles(0, math.rad(22.5), 0)
	Build.prism("Centro", 8, 5, 0.22, frame * CFrame.new(0, 0.11, 0) * turn, PALETTE.Telha, model, DETAIL)
end

-- Zonas com nome: cobrem a área de duelo inteira, sem sobrepor.
local function zones(frame: CFrame, folder: Instance)
	local halfBody = WORLD.BodySize / 2
	local midZ = DIAG_START.Y -- -9: a passagem do meio vai de -9 a 9
	IslandCommon.zone(frame, folder, "meio", v2(-ZONE_MID, midZ), v2(ZONE_MID, -midZ))
	for _, s in { 1, -1 } do
		local side: "east" | "west" = if s == 1 then "east" else "west"
		local function zone(id: string, min: Vector2, max: Vector2)
			IslandCommon.zone(frame, folder, id, min * s, max * s, side)
		end
		-- Muro: tudo do lado de baixo (z > -9), menos o Meio
		zone("muro", v2(ZONE_MID, midZ), v2(halfBody.X, halfBody.Y))
		zone("muro", v2(0, -midZ), v2(ZONE_MID, halfBody.Y))
		-- Passarela e Canteiro: degraus ao longo da diagonal
		for i, x in ZONE_STEPS.X do
			local z0, z1 = ZONE_STEPS.Z[i], ZONE_STEPS.Z[i + 1]
			zone("passarela", v2(0, z0), v2(x, z1))
			zone("canteiro", v2(x, z0), v2(halfBody.X, z1))
		end
	end
end

local Praca: IslandCommon.Island = {
	style = {
		floor = PALETTE.Piso,
		rail = PALETTE.Reboco,
		wall = PALETTE.Reboco,
		underside = PALETTE.Terra,
	},
	build = function(frame: CFrame, folder: Instance)
		half(frame, folder)
		half(IslandCommon.rotated(frame), folder)
		centerpiece(frame, folder)
		zones(frame, folder)
		IslandCommon.shieldPoint(frame, folder, SHIELD.X, SHIELD.Y)
		IslandCommon.shieldPoint(frame, folder, -SHIELD.X, -SHIELD.Y)
	end,
}

return Praca
