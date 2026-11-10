--!strict
-- Teleporte de teste entre os 3 places (FASES F0). Só existe no ambiente DEV_.
-- O cliente só PEDE ("quero ir para X"); o servidor valida tudo e faz o teleporte.
-- A Partida usa servidor reservado, como no jogo real (GDD 6.1).
-- "Levar todos" (F4, testes em grupo até a fila da F5): todos os jogadores deste servidor vão
-- juntos num teleporte só, para o MESMO servidor do destino (na Partida, o mesmo servidor reservado).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage.Shared
local Env = require(Shared.Env)
local Remotes = require(Shared.Remotes)
local DevConfig = require(Shared.Config.DevConfig)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)

local DevTeleportService = {}

local requestEvent: RemoteEvent
local resultEvent: RemoteEvent
local lastRequestAt: { [Player]: number } = {}
local lastGroupAt = -math.huge -- "levar todos": um pedido por vez no servidor inteiro
local groupInProgress = false

local function reply(player: Player, ok: boolean, messageKey: string)
	resultEvent:FireClient(player, ok, messageKey)
end

-- Antes de sair do servidor, o perfil é salvo e a trava liberada (DADOS-JOGADOR 5.3).
-- Se algo falhar, o perfil é reaberto aqui e o erro sobe para quem chamou.
local function teleport(player: Player, target: Types.PlaceName, placeId: number)
	local accessCode = if target == "Match" then TeleportService:ReserveServerAsync(placeId) else nil

	if not DataService.releaseForTeleportAsync(player) then
		DataService.reopenAfterFailedTeleport(player)
		error("não foi possível salvar o perfil antes do teleporte")
	end

	local ok, err = pcall(function()
		if accessCode then
			TeleportService:TeleportToPrivateServer(placeId, accessCode, { player })
		else
			TeleportService:TeleportAsync(placeId, { player })
		end
	end)
	if not ok then
		DataService.reopenAfterFailedTeleport(player)
		error(err)
	end
end

-- Todos juntos: salva e libera o perfil de cada um (em paralelo) e teleporta a lista de uma vez.
-- Quem não conseguiu salvar fica neste servidor (perfil reaberto) e é avisado.
local function teleportGroup(players: { Player }, target: Types.PlaceName, placeId: number)
	local accessCode = if target == "Match" then TeleportService:ReserveServerAsync(placeId) else nil

	local released: { Player } = {}
	local pending = #players
	for _, player in players do
		task.spawn(function()
			if DataService.releaseForTeleportAsync(player) then
				table.insert(released, player)
			else
				DataService.reopenAfterFailedTeleport(player)
				reply(player, false, "Failed")
			end
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait(0.1)
	end
	if #released == 0 then
		error("ninguém conseguiu salvar o perfil antes do teleporte")
	end

	local ok, err = pcall(function()
		if accessCode then
			TeleportService:TeleportToPrivateServer(placeId, accessCode, released)
		else
			TeleportService:TeleportAsync(placeId, released)
		end
	end)
	if not ok then
		for _, player in released do
			DataService.reopenAfterFailedTeleport(player)
		end
		error(err)
	end
end

local function onRequest(player: Player, rawTarget: unknown, rawEveryone: unknown)
	-- 1. Tipo e valor
	local maybeTarget: Types.PlaceName? = Env.toPlaceName(rawTarget)
	if not maybeTarget then
		reply(player, false, "Invalid")
		return
	end
	local target: Types.PlaceName = maybeTarget

	-- 2. Frequência
	local now = os.clock()
	local last = lastRequestAt[player]
	if last and now - last < DevConfig.TeleportCooldownSeconds then
		reply(player, false, "Cooldown")
		return
	end
	lastRequestAt[player] = now

	-- 3. Destino possível
	local placeId = Env.getPlaceId(target)
	if placeId ~= 0 and placeId == game.PlaceId then
		reply(player, false, "SamePlace")
		return
	end
	if placeId == 0 then
		reply(player, false, "NotConfigured")
		return
	end
	if Env.IsStudio then
		reply(player, false, "Studio")
		return
	end

	-- 4a. Levar todos deste servidor
	if rawEveryone == true then
		if groupInProgress or now - lastGroupAt < DevConfig.TeleportGroupCooldownSeconds then
			reply(player, false, "Cooldown")
			return
		end
		groupInProgress = true
		lastGroupAt = now
		local everyone = Players:GetPlayers()
		for _, other in everyone do
			reply(other, true, "GroupSent")
		end
		local ok, err = pcall(function()
			teleportGroup(everyone, target, placeId)
		end)
		groupInProgress = false
		if not ok then
			warn(`[DevTeleport] Falhou levar todos -> {target}: {err}`)
			for _, other in everyone do
				if other.Parent then
					reply(other, false, "Failed")
				end
			end
		end
		return
	end
	if rawEveryone ~= nil then
		reply(player, false, "Invalid")
		return
	end

	-- 4b. Teleporte só de quem pediu
	reply(player, true, "Sent")
	local ok, err = pcall(function()
		teleport(player, target, placeId)
	end)
	if not ok then
		warn(`[DevTeleport] Falhou para {player.UserId} -> {target}: {err}`)
		reply(player, false, "Failed")
	end
end

function DevTeleportService.Init()
	if not Env.IsDev then
		return
	end
	requestEvent = Remotes.event("DevTeleportRequest")
	resultEvent = Remotes.event("DevTeleportResult")
end

function DevTeleportService.Start()
	if not Env.IsDev then
		return
	end

	requestEvent.OnServerEvent:Connect(onRequest)

	TeleportService.TeleportInitFailed:Connect(function(player: Player, result: Enum.TeleportResult, message: string)
		warn(`[DevTeleport] TeleportInitFailed {player.UserId}: {result.Name} {message}`)
		DataService.reopenAfterFailedTeleport(player)
		reply(player, false, "Failed")
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastRequestAt[player] = nil
	end)
end

return DevTeleportService
