--!strict
-- Acesso ao MemoryStore da fila e das entregas entre places (DADOS-JOGADOR seção 2).
-- Nada aqui é dado do jogador: tudo expira sozinho.
--
-- Nomes: prefixo DEV_ em teste (como os DataStores) e sufixo _Studio dentro do Studio, para os
-- testes no Studio não se misturarem com os servidores publicados de teste.

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Env = require(Shared.Env)
local QueueConfig = require(Shared.Config.QueueConfig)

local MemoryMaps = {}

MemoryMaps.Names = {
	Queue = "MatchQueue_v1", -- fichas da fila (uma por grupo)
	Control = "MatchQueueControl_v1", -- trava do lobby líder, estado da fila, "começar já" (teste)
	MatchHandoff = "MatchHandoff_v1", -- composição da partida, pela PrivateServerId do servidor reservado
	LobbyHandoff = "LobbyHandoff_v1", -- volta da partida: entrar direto na fila, dupla fixa
}

function MemoryMaps.fullName(baseName: string): string
	return Env.dataStoreName(baseName) .. (if Env.IsStudio then "_Studio" else "")
end

local cache: { [string]: MemoryStoreSortedMap } = {}

function MemoryMaps.get(baseName: string): MemoryStoreSortedMap
	local name = MemoryMaps.fullName(baseName)
	local cached = cache[name]
	if cached then
		return cached
	end
	local map = MemoryStoreService:GetSortedMap(name)
	cache[name] = map
	return map
end

-- Repete com espera crescente (0,5 s, 1 s…). Devolve (true, resultado) ou (false, erro).
function MemoryMaps.retry<T>(label: string, fn: () -> T): (boolean, any)
	local lastErr: any = nil
	for attempt = 1, QueueConfig.Store.Retries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		if attempt < QueueConfig.Store.Retries then
			task.wait(0.5 * 2 ^ (attempt - 1))
		end
	end
	warn(`[Fila] {label} falhou: {lastErr}`)
	return false, lastErr
end

-- Relógio comum entre servidores (segundos).
function MemoryMaps.now(): number
	return DateTime.now().UnixTimestampMillis / 1000
end

return MemoryMaps
