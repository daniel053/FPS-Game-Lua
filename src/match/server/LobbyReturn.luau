--!strict
-- Volta ao lobby a partir da partida (GDD 4.8 e 4.9): "Nova partida", fim da partida, ausência e
-- partida que não aconteceu (F5).
-- Antes de teleportar, salva e libera o perfil (DADOS-JOGADOR 5.3). O que o lobby precisa saber
-- (entrar direto na fila, dupla fixa, passar na frente) vai pelo LobbyHandoff no MemoryStore, não
-- pelos dados de teleporte, que passam pelo cliente.
-- A dupla que segue junta viaja num teleporte só, e cai no mesmo servidor de lobby.
-- No Studio o teleporte não funciona: devolve false e o MatchService avisa o jogador.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage.Shared
local Env = require(Shared.Env)

local DataService = require(ServerScriptService.Common.DataService)
local Handoff = require(ServerScriptService.Common.Matchmaking.Handoff)
local MemoryMaps = require(ServerScriptService.Common.Matchmaking.MemoryMaps)

export type ReturnReason = "NewMatch" | "MatchEnded" | "Afk" | "NotEnoughPlayers" | "NotExpected"

export type ReturnOptions = {
	autoQueue: boolean?, -- entra direto na fila ao chegar ao lobby
	priority: boolean?, -- passa na frente na fila (a partida não aconteceu)
	together: boolean?, -- os 2 jogadores são uma dupla fixa: viajam juntos
}

local LobbyReturn = {}

-- Teleporta `players` juntos para o lobby. Devolve false se não deu (Studio, place sem ID, erro).
function LobbyReturn.send(players: { Player }, reason: ReturnReason, options: ReturnOptions?): boolean
	if #players == 0 then
		return true
	end
	local placeId = Env.getPlaceId("Lobby")
	if Env.IsStudio or placeId == 0 then
		return false
	end
	local opts: ReturnOptions = options or {}
	local together = opts.together == true and #players == 2

	-- Entrega para o lobby (mesmo sem nada especial, apaga uma entrega antiga do jogador).
	for i, player in players do
		local partner = if together then players[3 - i] else nil
		Handoff.writeLobby(player.UserId, {
			autoQueue = opts.autoQueue == true,
			priority = opts.priority == true,
			partyWith = if partner then partner.UserId else nil,
			at = MemoryMaps.now(),
		})
	end

	-- Salva e libera os perfis em paralelo.
	local released: { Player } = {}
	local pending = #players
	for _, player in players do
		task.spawn(function()
			if DataService.releaseForTeleportAsync(player) then
				table.insert(released, player)
			else
				DataService.reopenAfterFailedTeleport(player)
			end
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait(0.1)
	end
	if #released == 0 then
		return false
	end

	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions:SetTeleportData({ from = "Match", reason = reason })
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(placeId, released, teleportOptions)
	end)
	if not ok then
		warn(`[Partida] Teleporte para o lobby falhou: {err}`)
		for _, player in released do
			DataService.reopenAfterFailedTeleport(player)
		end
		return false
	end
	return #released == #players
end

function LobbyReturn.Start()
	TeleportService.TeleportInitFailed:Connect(function(player: Player)
		DataService.reopenAfterFailedTeleport(player)
	end)
end

return LobbyReturn
