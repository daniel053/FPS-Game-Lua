--!strict
-- Teleportes do tutorial (F6):
--   * Lobby -> Tutorial: jogador novo (tutorialDone = false), num servidor reservado só para ele;
--   * Tutorial -> Lobby: terminou, ou já tinha terminado antes (nunca mais fica no tutorial).
-- Antes de teleportar, salva e libera o perfil (DADOS-JOGADOR 5.3). No Studio não há teleporte:
-- devolve false e quem chamou avisa o jogador.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage.Shared
local Env = require(Shared.Env)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)

local PlaceTeleport = {}

local function send(player: Player, target: Types.PlaceName, reserve: boolean, reason: string): boolean
	local placeId = Env.getPlaceId(target)
	if Env.IsStudio or placeId == 0 or placeId == game.PlaceId then
		return false
	end
	local accessCode: string? = nil
	if reserve then
		-- Um servidor reservado só para este jogador
		local reserved, code = pcall(function(): string
			return (TeleportService:ReserveServerAsync(placeId))
		end)
		if not reserved then
			warn(`[Teleporte] Não deu para reservar servidor do {target}: {code}`)
			return false
		end
		accessCode = code
	end
	local data = { from = Env.getCurrentPlace(), reason = reason }

	if not DataService.releaseForTeleportAsync(player) then
		DataService.reopenAfterFailedTeleport(player)
		return false
	end
	local ok, err = pcall(function()
		if accessCode then
			TeleportService:TeleportToPrivateServer(placeId, accessCode, { player }, nil, data)
		else
			local options = Instance.new("TeleportOptions")
			options:SetTeleportData(data)
			TeleportService:TeleportAsync(placeId, { player }, options)
		end
	end)
	if not ok then
		warn(`[Teleporte] {player.UserId} -> {target} falhou: {err}`)
		DataService.reopenAfterFailedTeleport(player)
		return false
	end
	return true
end

-- Jogador novo: vai para o tutorial, sozinho.
function PlaceTeleport.sendToTutorial(player: Player): boolean
	return send(player, "Tutorial", true, "FirstTime")
end

-- Terminou o tutorial (ou já tinha terminado): vai para o lobby.
function PlaceTeleport.sendToLobby(player: Player, reason: string): boolean
	return send(player, "Lobby", false, reason)
end

function PlaceTeleport.Start()
	-- Teleporte que falhou depois de liberar o perfil: abre de novo (o DataService ignora repetição).
	TeleportService.TeleportInitFailed:Connect(function(player: Player)
		DataService.reopenAfterFailedTeleport(player)
	end)
end

return PlaceTeleport
