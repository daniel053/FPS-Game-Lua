--!strict
-- Posições do mundo da partida (mirante + 4 ilhas), calculadas de MapConfig.Gray.
-- Usado pelo servidor (montar o mundo, nascer, zona) e pelo cliente (desenhar a zona).

local MapConfig = require(script.Parent.Parent.Config.MapConfig)
local MatchConfig = require(script.Parent.Parent.Config.MatchConfig)

local GRAY = MapConfig.Gray

local WorldLayout = {}

function WorldLayout.islandCount(): number
	return #MapConfig.Maps
end

function WorldLayout.mapId(island: number): string
	return MapConfig.Maps[island].id
end

-- Centro da ilha no nível do chão.
function WorldLayout.islandCenter(island: number): Vector3
	local center = GRAY.IslandCenters[MapConfig.Maps[island].position]
	return Vector3.new(center.X, GRAY.IslandFloorY, center.Y)
end

function WorldLayout.miranteCenter(): Vector3
	return Vector3.new(0, GRAY.MiranteFloorY, 0)
end

-- Ponto de nascer na base. `side` 1 = lado oeste da ilha, 2 = lado leste; `slot` 1 ou 2.
-- Olhando para o centro da ilha.
function WorldLayout.baseSpawn(island: number, side: number, slot: number): CFrame
	local center = WorldLayout.islandCenter(island)
	local dx = GRAY.IslandSize.X / 2 - GRAY.BaseInset
	local x = if side == 1 then center.X - dx else center.X + dx
	local z = center.Z + (if slot == 1 then -1 else 1) * GRAY.BaseSpawnSpread / 2
	local position = Vector3.new(x, GRAY.IslandFloorY + 3, z)
	return CFrame.lookAt(position, Vector3.new(center.X, position.Y, z))
end

-- Raio da zona no começo: cobre a ilha inteira com folga.
function WorldLayout.zoneStartRadius(): number
	local half = GRAY.IslandSize / 2
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
	local half = GRAY.IslandSize / 2
	for i = 1, WorldLayout.islandCount() do
		local center = WorldLayout.islandCenter(i)
		if math.abs(position.X - center.X) <= half.X + 2 and math.abs(position.Z - center.Z) <= half.Y + 2 then
			return i
		end
	end
	return nil
end

return WorldLayout
