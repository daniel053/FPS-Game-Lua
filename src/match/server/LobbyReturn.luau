--!strict
-- Volta ao lobby a partir da partida (GDD 4.8 e 4.9): "Nova partida", fim da partida e ausência.
-- Antes de teleportar, salva e libera o perfil (DADOS-JOGADOR 5.3). Quem escolheu seguir com o
-- parceiro vai junto, com a informação no TeleportData (a fila do lobby usa na F5).
-- No Studio o teleporte não funciona: devolve false e o MatchService avisa o jogador.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage.Shared
local Env = require(Shared.Env)

local DataService = require(ServerScriptService.Common.DataService)

export type ReturnReason = "NewMatch" | "MatchEnded" | "Afk"

local LobbyReturn = {}

-- Teleporta `players` juntos para o lobby. `partyWith[player]` = UserId do parceiro que vai junto
-- como dupla fixa. Devolve false se não deu (Studio, place sem ID, erro do Roblox).
function LobbyReturn.send(players: { Player }, reason: ReturnReason, partyWith: { [Player]: number }?): boolean
	if #players == 0 then
		return true
	end
	local placeId = Env.getPlaceId("Lobby")
	if Env.IsStudio or placeId == 0 then
		return false
	end

	local released: { Player } = {}
	for _, player in players do
		if DataService.releaseForTeleportAsync(player) then
			table.insert(released, player)
		else
			DataService.reopenAfterFailedTeleport(player)
		end
	end
	if #released == 0 then
		return false
	end

	local allOk = true
	for _, player in released do
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({
			from = "Match",
			reason = reason,
			partyWith = if partyWith then partyWith[player] else nil,
		})
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(placeId, { player }, options)
		end)
		if not ok then
			allOk = false
			warn(`[Partida] Teleporte para o lobby falhou ({player.UserId}): {err}`)
			DataService.reopenAfterFailedTeleport(player)
		end
	end
	return allOk
end

function LobbyReturn.Start()
	TeleportService.TeleportInitFailed:Connect(function(player: Player)
		DataService.reopenAfterFailedTeleport(player)
	end)
end

return LobbyReturn
