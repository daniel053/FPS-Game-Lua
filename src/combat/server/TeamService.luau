--!strict
-- Dupla (cor da equipe) de cada jogador. O atributo TeamId fica no Player e no modelo do combatente.
--   Partida (F3): o MatchService forma as duplas (GDD 4.2) e chama TeamService.set.
--   Arena de teste (F2): quem entra vai para a dupla com menos gente entre as duas primeiras cores
--   (assignBalanced) e o painel TESTE troca (cycle).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatNames = require(Shared.Combat.CombatNames)
local TeamColors = require(Shared.Config.TeamColors)

local TEST_TEAMS: { string } = { TeamColors.Order[1], TeamColors.Order[2] }

type ChangedCallback = (player: Player, teamId: string?) -> ()

local TeamService = {}

local teams: { [Player]: string } = {}
local changedCallbacks: { ChangedCallback } = {}

local function countIn(teamId: string): number
	local count = 0
	for _, id in teams do
		if id == teamId then
			count += 1
		end
	end
	return count
end

function TeamService.set(player: Player, teamId: string?)
	if teamId then
		teams[player] = teamId
	else
		teams[player] = nil
	end
	player:SetAttribute(CombatNames.Attr.TeamId, teamId)
	for _, callback in changedCallbacks do
		task.spawn(callback, player, teamId)
	end
end

function TeamService.get(player: Player): string?
	return teams[player]
end

-- Arena de teste: a dupla de teste com menos gente.
function TeamService.assignBalanced(player: Player): string
	local best = TEST_TEAMS[1]
	for _, id in TEST_TEAMS do
		if countIn(id) < countIn(best) then
			best = id
		end
	end
	TeamService.set(player, best)
	return best
end

-- Painel de teste (arena de teste): passa para a próxima dupla de teste.
function TeamService.cycle(player: Player): string
	local current = TeamService.get(player) or TeamService.assignBalanced(player)
	local index = table.find(TEST_TEAMS, current) or 0
	local nextId = TEST_TEAMS[index % #TEST_TEAMS + 1]
	TeamService.set(player, nextId)
	return nextId
end

function TeamService.onChanged(callback: ChangedCallback)
	table.insert(changedCallbacks, callback)
end

function TeamService.Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		teams[player] = nil
	end)
end

return TeamService
