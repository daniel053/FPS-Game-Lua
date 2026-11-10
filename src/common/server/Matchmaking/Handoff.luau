--!strict
-- Entregas entre places pelo MemoryStore, nunca pelos dados de teleporte (que passam pelo cliente
-- e podem ser adulterados — DADOS-JOGADOR 5.3):
--   * MatchHandoff: lobby -> servidor de partida. Quem vai jogar, as duplas fixas e a faixa.
--     Chave = PrivateServerId do servidor reservado (o servidor de partida lê game.PrivateServerId).
--   * LobbyHandoff: partida -> lobby. "Entrar direto na fila" (Nova partida) e "dupla fixa com X".
--     Chave = u_<UserId>; o lobby lê e apaga ao receber o jogador.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local QueueConfig = require(Shared.Config.QueueConfig)

local MemoryMaps = require(script.Parent.MemoryMaps)

export type MatchHandoff = {
	matchId: string,
	userIds: { number },
	duos: { { number } },
	pool: string, -- "Aprendizes", "Experientes" ou "Mistura"
	createdAt: number,
}

export type LobbyHandoff = {
	autoQueue: boolean, -- entrar direto na fila ao chegar
	priority: boolean, -- passa na frente (a partida não aconteceu)
	partyWith: number?, -- UserId do parceiro (dupla fixa); vale só se os dois apontarem um para o outro
	at: number,
}

local Handoff = {}

local function asNumberList(value: any): { number }?
	if typeof(value) ~= "table" then
		return nil
	end
	local list: { number } = {}
	for _, v in value do
		if typeof(v) ~= "number" then
			return nil
		end
		table.insert(list, v)
	end
	return list
end

function Handoff.writeMatch(privateServerId: string, data: MatchHandoff): boolean
	local map = MemoryMaps.get(MemoryMaps.Names.MatchHandoff)
	local ok = MemoryMaps.retry("gravar MatchHandoff", function()
		return map:SetAsync(privateServerId, data, QueueConfig.Store.MatchHandoffTtlSeconds)
	end)
	return ok
end

-- Lê a composição da partida, tentando até `timeoutSeconds` (o lobby grava antes de teleportar,
-- mas o MemoryStore pode demorar um instante).
function Handoff.readMatchAsync(privateServerId: string, timeoutSeconds: number): MatchHandoff?
	local map = MemoryMaps.get(MemoryMaps.Names.MatchHandoff)
	local deadline = os.clock() + timeoutSeconds
	repeat
		local ok, raw = pcall(function()
			return map:GetAsync(privateServerId)
		end)
		if ok and typeof(raw) == "table" then
			local userIds = asNumberList(raw.userIds)
			local duosRaw = raw.duos
			local duos: { { number } } = {}
			if typeof(duosRaw) == "table" then
				for _, pair in duosRaw do
					local list = asNumberList(pair)
					if list and #list == 2 then
						table.insert(duos, list)
					end
				end
			end
			if userIds and typeof(raw.matchId) == "string" then
				return {
					matchId = raw.matchId,
					userIds = userIds,
					duos = duos,
					pool = if typeof(raw.pool) == "string" then raw.pool else "",
					createdAt = if typeof(raw.createdAt) == "number" then raw.createdAt else 0,
				}
			end
		elseif not ok then
			warn(`[Fila] Ler MatchHandoff falhou: {raw}`)
		end
		task.wait(1)
	until os.clock() >= deadline
	return nil
end

function Handoff.writeLobby(userId: number, data: LobbyHandoff): boolean
	local map = MemoryMaps.get(MemoryMaps.Names.LobbyHandoff)
	local ok = MemoryMaps.retry("gravar LobbyHandoff", function()
		return map:SetAsync(`u_{userId}`, data, QueueConfig.Store.LobbyHandoffTtlSeconds)
	end)
	return ok
end

-- Lê e apaga (vale uma vez só).
function Handoff.takeLobby(userId: number): LobbyHandoff?
	local map = MemoryMaps.get(MemoryMaps.Names.LobbyHandoff)
	local key = `u_{userId}`
	local ok, raw = MemoryMaps.retry("ler LobbyHandoff", function()
		return map:GetAsync(key)
	end)
	if not ok or typeof(raw) ~= "table" then
		return nil
	end
	task.spawn(function()
		MemoryMaps.retry("apagar LobbyHandoff", function()
			map:RemoveAsync(key)
			return true
		end)
	end)
	return {
		autoQueue = raw.autoQueue == true,
		priority = raw.priority == true,
		partyWith = if typeof(raw.partyWith) == "number" then raw.partyWith else nil,
		at = if typeof(raw.at) == "number" then raw.at else 0,
	}
end

return Handoff
