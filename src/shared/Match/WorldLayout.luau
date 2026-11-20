--!strict
-- Posições do mundo da partida (mirante + 4 ilhas), calculadas de MapConfig.World.
-- Usado pelo servidor (montar o mundo, nascer, zona) e pelo cliente (minimapa, zona, mirante).
--
-- Cada ilha tem um "quadro" (CFrame) no centro do chão: o eixo X local vai de uma base à outra e fica
-- tangente ao mirante; o eixo Z local aponta para longe/perto do mirante. As bases ficam nas pontas
-- do eixo X, fora da área de duelo.

local MapConfig = require(script.Parent.Parent.Config.MapConfig)
local MatchConfig = require(script.Parent.Parent.Config.MatchConfig)

local WORLD = MapConfig.World

local WorldLayout = {}

function WorldLayout.islandCount(): number
	return #MapConfig.Maps
end

function WorldLayout.mapId(island: number): string
	return MapConfig.Maps[island].id
end

-- Quadro da ilha: no centro do topo do chão, com o eixo X local de base a base.
function WorldLayout.islandFrame(island: number): CFrame
	local position: string = MapConfig.Maps[island].position
	local direction = MapConfig.PositionDirection[position] * WORLD.IslandDistance
	local yaw = math.rad(MapConfig.PositionYaw[position])
	return CFrame.new(direction.X, WORLD.IslandFloorY, direction.Y) * CFrame.Angles(0, yaw, 0)
end

-- Centro da ilha no nível do chão.
function WorldLayout.islandCenter(island: number): Vector3
	return WorldLayout.islandFrame(island).Position
end

-- Meio comprimento da ilha inteira (área de duelo + uma base), no eixo X local.
function WorldLayout.islandHalfLength(): number
	return WORLD.BodySize.X / 2 + WORLD.BaseSize.X
end

-- Tamanho da ilha inteira nos eixos do mundo (X, Z), para o minimapa.
function WorldLayout.islandExtent(island: number): Vector2
	local length = WorldLayout.islandHalfLength() * 2
	local depth = WORLD.BodySize.Y
	if MapConfig.PositionYaw[MapConfig.Maps[island].position] % 180 == 0 then
		return Vector2.new(length, depth)
	end
	return Vector2.new(depth, length)
end

-- Centro de cada base no chão. `side` 1 = ponta -X local, 2 = ponta +X local.
function WorldLayout.baseCenter(island: number, side: number): Vector3
	local x = WORLD.BodySize.X / 2 + WORLD.BaseSize.X / 2
	return WorldLayout.islandFrame(island) * Vector3.new(if side == 1 then -x else x, 0, 0)
end

function WorldLayout.miranteCenter(): Vector3
	return Vector3.new(0, WORLD.MiranteFloorY, 0)
end

-- Distância do centro do mirante até o meio de cada lado do octógono.
function WorldLayout.miranteApothem(): number
	return WORLD.MiranteWidth / 2
end

-- Lado do octógono regular com a largura do mirante.
function WorldLayout.miranteSide(): number
	return WORLD.MiranteWidth / (1 + math.sqrt(2))
end

-- Ponto de nascer na base. `side` 1 ou 2 (pontas da ilha); `slot` 1 ou 2.
-- Olhando para o centro da ilha.
function WorldLayout.baseSpawn(island: number, side: number, slot: number): CFrame
	local frame = WorldLayout.islandFrame(island)
	local x = WORLD.BodySize.X / 2 + WORLD.BaseSize.X / 2
	local localX = if side == 1 then -x else x
	local localZ = (if slot == 1 then -1 else 1) * WORLD.BaseSpawnSpread / 2
	local position = frame * Vector3.new(localX, 3, localZ)
	local target = frame * Vector3.new(0, 3, localZ)
	return CFrame.lookAt(position, target)
end

-- Quadro da base: no centro do chão da base, com o eixo X local apontando para fora da ilha (a frente,
-- com a passagem, fica em x = -BaseSize.X / 2; o fundo em +BaseSize.X / 2).
function WorldLayout.baseFrame(island: number, side: number): CFrame
	local frame = WorldLayout.islandFrame(island)
	if side == 1 then
		frame = frame * CFrame.Angles(0, math.pi, 0)
	end
	return frame * CFrame.new(WORLD.BodySize.X / 2 + WORLD.BaseSize.X / 2, 0, 0)
end

-- Um painel da parede invisível da base: fino no eixo Z local; `glass` = mostra o vidro ao chegar perto.
export type BarrierPanel = { cframe: CFrame, size: Vector3, glass: boolean }

-- Painéis da parede invisível em volta da base (MapConfig.BaseBarrier): na passagem (com vidro), em
-- cima das duas paredes da frente (só colisão, a parede de verdade já mostra o limite) e por dentro
-- das muretas dos lados e do fundo (com vidro).
function WorldLayout.basePanels(island: number, side: number): { BarrierPanel }
	local base = WorldLayout.baseFrame(island, side)
	local height = MapConfig.BaseBarrier.Height
	local half = WORLD.BaseSize.X / 2
	local hz = WORLD.BaseSize.Y / 2
	local door = WORLD.BaseDoorWidth / 2
	local frontX = -half + 1.25 -- logo depois da face de dentro da parede da frente (1,5 de espessura)
	local backX = half - 1 -- logo antes da mureta do fundo (1 de espessura)
	local sideZ = hz - 1
	local y = height / 2
	local across = CFrame.Angles(0, math.pi / 2, 0) -- painel de frente para o eixo X
	local panels: { BarrierPanel } = {
		{ cframe = base * CFrame.new(frontX, y, 0) * across, size = Vector3.new(door * 2, height, 1), glass = true },
		{ cframe = base * CFrame.new(backX, y, 0) * across, size = Vector3.new(hz * 2, height, 1), glass = true },
	}
	for _, sign in { -1, 1 } do
		table.insert(panels, {
			cframe = base * CFrame.new(frontX, y, sign * (door + hz) / 2) * across,
			size = Vector3.new(hz - door, height, 1),
			glass = false,
		})
		table.insert(panels, {
			cframe = base * CFrame.new((frontX + backX) / 2, y, sign * sideZ),
			size = Vector3.new(backX - frontX, height, 1),
			glass = true,
		})
	end
	return panels
end

-- Está dentro da base (no chão, por X e Z), com `margin` studs de folga para fora?
function WorldLayout.insideBase(island: number, side: number, position: Vector3, margin: number): boolean
	local p = WorldLayout.baseFrame(island, side):PointToObjectSpace(position)
	return math.abs(p.X) <= WORLD.BaseSize.X / 2 + margin and math.abs(p.Z) <= WORLD.BaseSize.Y / 2 + margin
end

-- Raio da zona no começo: cobre a ilha inteira (com as bases) com folga.
function WorldLayout.zoneStartRadius(): number
	local half = Vector2.new(WorldLayout.islandHalfLength(), WORLD.BodySize.Y / 2)
	return half.Magnitude + MatchConfig.Zone.StartMargin
end

-- Raio da zona `seconds` depois do começo do combate (GDD 4.4).
function WorldLayout.zoneRadius(secondsIntoCombat: number): number
	local zone = MatchConfig.Zone
	local startRadius = WorldLayout.zoneStartRadius()
	if secondsIntoCombat <= zone.StartsAt then
		return startRadius
	end
	local alpha = math.clamp((secondsIntoCombat - zone.StartsAt) / zone.CloseDuration, 0, 1)
	return startRadius + (zone.FinalRadius - startRadius) * alpha
end

-- Qual ilha fica embaixo deste ponto (por X e Z), ou nil.
function WorldLayout.islandAt(position: Vector3): number?
	local halfLength = WorldLayout.islandHalfLength()
	local halfDepth = WORLD.BodySize.Y / 2
	for i = 1, WorldLayout.islandCount() do
		local p = WorldLayout.islandFrame(i):PointToObjectSpace(position)
		if math.abs(p.X) <= halfLength + 2 and math.abs(p.Z) <= halfDepth + 2 then
			return i
		end
	end
	return nil
end

return WorldLayout
