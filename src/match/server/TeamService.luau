--!strict
-- Duplas de TESTE da F2: quem entra vai para a dupla com menos gente entre as duas primeiras cores
-- (2 jogadores = inimigos; 3 ou 4 = 2v1 / 2v2). A formação de duplas de verdade é da F3 (GDD 4.2).
-- O atributo TeamId fica no Player e no modelo do combatente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatNames = require(Shared.Combat.CombatNames)
local TeamColors = require(Shared.Config.TeamColors)

local TEST_TEAMS: { string } = { TeamColors.Order[1], TeamColors.Order[2] }

type ChangedCallback = (player: Player, teamId: string) -> ()

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

local function set(player: Player, teamId: string)
	teams[player] = teamId
	player:SetAttribute(CombatNames.Attr.TeamId, teamId)
	for _, callback in changedCallbacks do
		task.spawn(callback, player, teamId)
	end
end

function TeamService.get(player: Player): string
	local teamId = teams[player]
	if teamId then
		return teamId
	end
	-- Ainda sem dupla: escolhe a que tem menos gente.
	local best = TEST_TEAMS[1]
	for _, id in TEST_TEAMS do
		if countIn(id) < countIn(best) then
			best = id
		end
	end
	set(player, best)
	return best
end

-- Painel de teste: passa para a próxima dupla de teste.
function TeamService.cycle(player: Player): string
	local current = TeamService.get(player)
	local index = table.find(TEST_TEAMS, current) or 0
	local nextId = TEST_TEAMS[index % #TEST_TEAMS + 1]
	set(player, nextId)
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
