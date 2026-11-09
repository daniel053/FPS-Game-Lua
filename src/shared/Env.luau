--!strict
-- Ambiente atual: teste (DEV_) ou real.
--
-- Regra (ver GDD, "Decisões técnicas"):
--   * É REAL só quando o jogo roda fora do Studio, na experiência de produção configurada em PlaceConfig.
--   * Todo o resto é TESTE: Studio, experiência de teste, cópias não publicadas.
-- Na dúvida, o padrão é teste, para nunca misturar dados de teste com dados reais.

local RunService = game:GetService("RunService")

local PlaceConfig = require(script.Parent.Config.PlaceConfig)
local Types = require(script.Parent.Types)

local Env = {}

Env.IsStudio = RunService:IsStudio()

local productionGameId = PlaceConfig.Production.GameId
Env.IsProduction = (not Env.IsStudio) and productionGameId ~= 0 and game.GameId == productionGameId

Env.IsDev = not Env.IsProduction

-- Prefixo dos DataStores (DADOS-JOGADOR seção 2).
Env.DataStorePrefix = if Env.IsDev then "DEV_" else ""

-- Nome final do DataStore. Ex.: dataStoreName("PlayerProfile_v1") -> "DEV_PlayerProfile_v1" em teste.
function Env.dataStoreName(baseName: string): string
	return Env.DataStorePrefix .. baseName
end

local function currentUniverse(): PlaceConfig.Universe
	if Env.IsProduction then
		return PlaceConfig.Production
	end
	return PlaceConfig.Dev
end

-- ID do place de destino no ambiente atual (0 = não configurado).
function Env.getPlaceId(place: Types.PlaceName): number
	return currentUniverse().Places[place]
end

local PLACE_NAMES: { Types.PlaceName } = { "Lobby", "Tutorial", "Match" }

-- Converte um valor qualquer (ex.: vindo do cliente) em PlaceName, ou nil se for inválido.
function Env.toPlaceName(value: unknown): Types.PlaceName?
	if value == "Lobby" then
		return "Lobby"
	elseif value == "Tutorial" then
		return "Tutorial"
	elseif value == "Match" then
		return "Match"
	end
	return nil
end

-- Qual dos 3 places está rodando agora (nil se o PlaceId não estiver em PlaceConfig).
function Env.getCurrentPlace(): Types.PlaceName?
	for _, name: Types.PlaceName in PLACE_NAMES do
		local id = Env.getPlaceId(name)
		if id ~= 0 and id == game.PlaceId then
			return name
		end
	end
	return nil
end

Env.PlaceNames = PLACE_NAMES

return Env
