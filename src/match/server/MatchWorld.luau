--!strict
-- Mundo da partida (GDD 6.5 e 15.3): mirante octogonal no centro e as 4 ilhas de duelo nos lados,
-- mais abaixo. Montado por código ao iniciar o servidor (nada fica salvo no place), pelo
-- `Shared/Maps/WorldBuilder`, o mesmo usado pelo lobby e pela prévia no Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local WorldBuilder = require(Shared.Maps.WorldBuilder)
local WorldLayout = require(Shared.Match.WorldLayout)

local MatchWorld = {}

function MatchWorld.build()
	local existing = workspace:FindFirstChild(WorldBuilder.FolderName)
	if existing then
		existing:Destroy()
	end
	WorldBuilder.applyLighting()
	WorldBuilder.build().Parent = workspace
	-- O SpawnLocation do place fica embaixo do mirante e aparecia pelo vidro: vai para o centro do
	-- mirante, invisível e sem colisão (quem entra aparece ali até o servidor posicionar).
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child.Transparency = 1
			child.CanCollide = false
			child.CanQuery = false
			child.CastShadow = false
			for _, decal in child:GetChildren() do
				if decal:IsA("Decal") then
					decal:Destroy()
				end
			end
			child.CFrame = CFrame.new(WorldLayout.miranteCenter() + Vector3.new(0, child.Size.Y / 2, 0))
		end
	end
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
