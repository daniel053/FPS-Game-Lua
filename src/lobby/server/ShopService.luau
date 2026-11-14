--!strict
-- Skins no Arsenal (F9, GDD 10.2 e 11, DADOS-JOGADOR 4). O cliente só PEDE; o servidor confere tudo:
--   * "Buy" (id da skin): à venda, ainda não tem, saldo suficiente -> EconomyService.buySkin (salva na hora);
--   * "Equip" (id da skin): só skin que o jogador tem e do slot certo (ProfileRules.equipSkin);
--   * "Unequip" (id da arma ou do Bastão): volta para a skin padrão.
-- Limite de frequência por jogador (EconomyConfig). A resposta vai pelo ShopResult.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Remotes = require(Shared.Remotes)

local Common = ServerScriptService.Common
local DataService = require(Common.DataService)
local EconomyService = require(Common.EconomyService)
local ProfileRules = require(Common.Data.ProfileRules)

local MAX_ID_LENGTH = 64

local ShopService = {}

local requestEvent: RemoteEvent
local resultEvent: RemoteEvent
local windows: { [Player]: { start: number, count: number } } = {}

local function rateLimited(player: Player): boolean
	local now = os.clock()
	local window = windows[player]
	if window == nil or now - window.start >= EconomyConfig.ShopRequestWindowSeconds then
		windows[player] = { start = now, count = 1 }
		return false
	end
	window.count += 1
	return window.count > EconomyConfig.ShopRequestMaxPerWindow
end

local function reply(player: Player, ok: boolean, key: string, id: string?)
	resultEvent:FireClient(player, ok, key, id)
end

-- Aplica um pedido já validado no formato. Devolve (sucesso, chave da mensagem).
local function handle(player: Player, kind: string, id: string): (boolean, string)
	if kind == "Buy" then
		local ok, err = EconomyService.buySkin(player, id)
		if ok then
			return true, "Bought"
		end
		return false, err or "Failed"
	elseif kind == "Equip" then
		local ok, err = DataService.update(player, function(profile)
			return ProfileRules.equipSkin(profile, id)
		end)
		return ok, if ok then "Equipped" else (err or "Failed")
	elseif kind == "Unequip" then
		local ok, err = DataService.update(player, function(profile)
			return ProfileRules.unequipWeaponSkin(profile, id)
		end)
		return ok, if ok then "Equipped" else (err or "Failed")
	end
	return false, "Failed"
end

local function onRequest(player: Player, kind: unknown, id: unknown)
	if rateLimited(player) then
		reply(player, false, "TooFast", nil)
		return
	end
	if
		(kind ~= "Buy" and kind ~= "Equip" and kind ~= "Unequip")
		or typeof(id) ~= "string"
		or #(id :: string) == 0
		or #(id :: string) > MAX_ID_LENGTH
	then
		return -- pedido malformado: ignora
	end
	local ok, key = handle(player, kind :: string, id :: string)
	reply(player, ok, key, id :: string)
end

function ShopService.Init()
	requestEvent = Remotes.event("ShopRequest")
	resultEvent = Remotes.event("ShopResult")
end

function ShopService.Start()
	requestEvent.OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player: Player)
		windows[player] = nil
	end)
end

return ShopService
