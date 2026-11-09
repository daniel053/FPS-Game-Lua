--!strict
-- Pedidos do cliente para salvar configurações (retícula, sensibilidade, áudio, layout do celular...).
-- O cliente manda só os campos que mudaram; o servidor valida tudo (SettingsValidation) e aplica.
-- Qualquer valor inválido recusa o pedido inteiro (docs/DADOS-JOGADOR.md seções 4 e 10).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local DataConfig = require(Shared.Config.DataConfig)
local Remotes = require(Shared.Remotes)
local SettingsValidation = require(Shared.SettingsValidation)

local DataService = require(script.Parent.DataService)

local SettingsService = {}

local requestEvent: RemoteEvent
local resultEvent: RemoteEvent

-- Limite de frequência: no máximo N pedidos por janela de tempo, por jogador.
local recentRequests: { [Player]: { number } } = {}

local function allowRequest(player: Player): boolean
	local now = os.clock()
	local list = recentRequests[player]
	if list == nil then
		list = {}
		recentRequests[player] = list
	end
	local windowStart = now - DataConfig.SettingsRequestWindowSeconds
	while #list > 0 and list[1] < windowStart do
		table.remove(list, 1)
	end
	if #list >= DataConfig.SettingsRequestMaxPerWindow then
		return false
	end
	table.insert(list, now)
	return true
end

local function onRequest(player: Player, patch: unknown)
	if not allowRequest(player) then
		resultEvent:FireClient(player, false, "RateLimited")
		return
	end

	local validationError: string? = nil
	local ok, err = DataService.update(player, function(profile): (boolean, string?)
		local newSettings, errorKey = SettingsValidation.applyPatch(profile.settings, patch)
		if newSettings == nil then
			validationError = errorKey
			return false, "Invalid"
		end
		profile.settings = newSettings
		return true, nil
	end)

	if ok then
		resultEvent:FireClient(player, true, "Ok")
	elseif err == "Invalid" then
		resultEvent:FireClient(player, false, "Invalid", validationError)
	else
		resultEvent:FireClient(player, false, "NotLoaded")
	end
end

function SettingsService.Init()
	requestEvent = Remotes.event("SettingsUpdateRequest")
	resultEvent = Remotes.event("SettingsUpdateResult")
end

function SettingsService.Start()
	requestEvent.OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player: Player)
		recentRequests[player] = nil
	end)
end

return SettingsService
