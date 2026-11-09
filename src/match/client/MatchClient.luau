--!strict
-- Estado da partida no cliente: guarda a última foto do servidor (MatchState), repassa os eventos
-- (MatchEvent) e manda os pedidos (MatchRequest). Só mostra; quem decide é o servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local MatchTypes = require(Shared.Match.MatchTypes)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Config.Strings)

type Snapshot = MatchTypes.Snapshot
type EventCallback = (data: any) -> ()

local MatchClient = {}

local player = Players.LocalPlayer
local snapshot: Snapshot? = nil
local changedCallbacks: { (Snapshot) -> () } = {}
local eventCallbacks: { [string]: { EventCallback } } = {}
local requestEvent: RemoteEvent? = nil

function MatchClient.isEnabled(): boolean
	return not CombatConfig.TestArena.Enabled
end

function MatchClient.get(): Snapshot?
	return snapshot
end

function MatchClient.onChanged(callback: (Snapshot) -> ())
	table.insert(changedCallbacks, callback)
	if snapshot then
		task.spawn(callback, snapshot)
	end
end

function MatchClient.onEvent(kind: MatchTypes.EventName, callback: EventCallback)
	local list = eventCallbacks[kind]
	if list == nil then
		list = {}
		eventCallbacks[kind] = list
	end
	table.insert(list, callback)
end

function MatchClient.request(kind: MatchTypes.RequestName, arg: any?)
	if requestEvent then
		requestEvent:FireServer(kind, arg)
	end
end

function MatchClient.myTeamId(): string?
	local id = player:GetAttribute(CombatNames.Attr.TeamId)
	return if typeof(id) == "string" then id else nil
end

-- "Mirante", "Island1".."Island4" ou nil
function MatchClient.myLocation(): string?
	local location = player:GetAttribute(MatchTypes.Attr.Location)
	return if typeof(location) == "string" then location else nil
end

function MatchClient.isOnMirante(): boolean
	return MatchClient.myLocation() == MatchTypes.MiranteLocation
end

function MatchClient.myIsland(): number?
	local location = MatchClient.myLocation()
	if location == nil then
		return nil
	end
	local index = string.match(location, "^Island(%d+)$")
	return if index then tonumber(index) else nil
end

function MatchClient.team(id: string?): MatchTypes.TeamView?
	if id == nil or snapshot == nil then
		return nil
	end
	for _, team in snapshot.teams do
		if team.id == id then
			return team
		end
	end
	return nil
end

-- Duelo da dupla nesta rodada (nil = folga, eliminada ou fora da partida).
function MatchClient.duelOf(teamId: string?): MatchTypes.DuelView?
	if teamId == nil or snapshot == nil then
		return nil
	end
	for _, duel in snapshot.duels do
		if duel.a == teamId or duel.b == teamId then
			return duel
		end
	end
	return nil
end

function MatchClient.teamName(id: string?): string
	if id == nil then
		return ""
	end
	return string.format(Strings.Match.TeamName, Strings.Teams[id] or id)
end

-- O parceiro (jogador de verdade) da minha dupla, se estiver no servidor.
function MatchClient.partnerPlayer(): Player?
	local teamId = MatchClient.myTeamId()
	if teamId == nil then
		return nil
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute(CombatNames.Attr.TeamId) == teamId then
			return other
		end
	end
	return nil
end

function MatchClient.Start()
	if not MatchClient.isEnabled() then
		return
	end
	requestEvent = Remotes.event("MatchRequest")
	Remotes.event("MatchState").OnClientEvent:Connect(function(data: Snapshot)
		snapshot = data
		for _, callback in changedCallbacks do
			task.spawn(callback, data)
		end
	end)
	Remotes.event("MatchEvent").OnClientEvent:Connect(function(kind: string, data: any)
		local list = eventCallbacks[kind]
		if list then
			for _, callback in list do
				task.spawn(callback, data)
			end
		end
	end)
end

return MatchClient
