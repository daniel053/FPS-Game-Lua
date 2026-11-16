--!strict
-- Zonas com nome dos mapas (GDD 15.1): em que zona um ponto está e como ela se chama. As zonas são
-- as caixas invisíveis criadas por `IslandCommon.zone` (atributo `MapZone`, tag `MapZone`).
-- Usado pelo servidor para dar nome ao lugar de um ping.

local CollectionService = game:GetService("CollectionService")

local IslandCommon = require(script.Parent.IslandCommon)
local Strings = require(script.Parent.Parent.Config.Strings)

local Zones = {}

-- Zona (id e lado) em que `position` está, entre as `parts` dadas.
function Zones.find(position: Vector3, parts: { Instance }): (string?, string?)
	for _, part in parts do
		if part:IsA("BasePart") then
			local zoneId = part:GetAttribute(IslandCommon.ZoneAttribute)
			if typeof(zoneId) == "string" then
				local p = part.CFrame:PointToObjectSpace(position)
				local half = part.Size / 2
				if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
					local side = part:GetAttribute(IslandCommon.ZoneSideAttribute)
					return zoneId, if typeof(side) == "string" then side else nil
				end
			end
		end
	end
	return nil, nil
end

-- Zona do mundo da partida em que `position` está.
function Zones.at(position: Vector3): (string?, string?)
	return Zones.find(position, CollectionService:GetTagged(IslandCommon.ZoneTag))
end

-- Nome para mostrar: "Muro Leste", "Guindaste". Devolve nil se a zona não tem nome.
function Zones.name(zoneId: string?, side: string?): string?
	local name = if zoneId then Strings.Zones[zoneId] else nil
	if name == nil then
		return nil
	end
	local sideName = if side then Strings.ZoneSides[side] else nil
	return if sideName then `{name} {sideName}` else name
end

return Zones
