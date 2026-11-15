--!strict
-- Mundo da partida (GDD 6.5 e 15.3): mirante octogonal no centro e as 4 ilhas de duelo nos lados,
-- mais abaixo. O mundo fica salvo no place (montado pelo `Shared/Maps/WorldBuilder.bake`, para
-- aparecer ao abrir o Studio). Ao iniciar, o servidor confere se a cópia salva é igual à que o
-- código monta hoje: se for, usa a salva; se não for (ou não existir), monta de novo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local WorldBuilder = require(Shared.Maps.WorldBuilder)
local WorldLayout = require(Shared.Match.WorldLayout)

local MatchWorld = {}

function MatchWorld.build()
	WorldBuilder.applyLighting()
	local saved = workspace:FindFirstChild(WorldBuilder.FolderName)
	local upToDate = false
	if saved then
		local fresh = WorldBuilder.build()
		upToDate = WorldBuilder.sameWorld(saved, fresh)
		fresh:Destroy()
	end
	if not upToDate then
		local world = WorldBuilder.install(workspace)
		if saved then
			-- Aviso para quem desenvolve: o mapa do place está velho (README, "Mapa salvo no place").
			world:SetAttribute(WorldBuilder.RebuiltAttribute, true)
			warn("[MatchWorld] O mundo salvo no place está diferente do código: montado de novo.")
		end
	end
	WorldBuilder.hideSpawn(workspace)
end

-- Ponto aleatório perto do centro do mirante, olhando para fora.
function MatchWorld.miranteSpawn(): CFrame
	local center = WorldLayout.miranteCenter()
	local angle = math.random() * math.pi * 2
	local radius = math.random() * WorldLayout.miranteSide() * 0.4
	local position = center + Vector3.new(math.cos(angle) * radius, 3, math.sin(angle) * radius)
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	return CFrame.lookAt(position, position + outward)
end

-- Pódio: centro do mirante (cerimônia de campeão).
function MatchWorld.podiumSpawn(slot: number): CFrame
	local center = WorldLayout.miranteCenter()
	local position = center + Vector3.new((slot - 1.5) * 4, 3, 0)
	return CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
end

return MatchWorld
