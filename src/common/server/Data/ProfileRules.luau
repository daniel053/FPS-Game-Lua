--!strict
-- Regras de integridade do perfil (docs/DADOS-JOGADOR.md seção 4).
-- Funções puras sobre o perfil: não salvam nem avisam o cliente (isso é do DataService.update).
-- Todas devolvem (true, nil) quando aplicam a mudança, ou (false, motivo) quando recusam — sem mudar nada.
--
-- Quem chama:
--   moedas  -> só o EconomyService
--   elo     -> só o RankService (F9)
--   cartas, skins, emotes, parceiros, estatísticas -> serviços de cada fase

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CardConfig = require(Shared.Config.CardConfig)
local DataConfig = require(Shared.Config.DataConfig)
local ShopCatalog = require(Shared.Config.ShopCatalog)
local SocialConfig = require(Shared.Config.SocialConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local PlayerData = require(Shared.Types.PlayerData)

type Profile = PlayerData.Profile

-- Dependências trocáveis nos testes (catálogos de exemplo).
export type Catalogs = {
	getCard: (id: string) -> CardConfig.CardDef?,
	getSkin: (id: string) -> ShopCatalog.SkinDef?,
	isValidWeapon: (id: string) -> boolean,
}

local DEFAULT_CATALOGS: Catalogs = {
	getCard = CardConfig.get,
	getSkin = ShopCatalog.getSkin,
	isValidWeapon = WeaponConfig.isValidId,
}

local ProfileRules = {}

ProfileRules.DefaultCatalogs = DEFAULT_CATALOGS

local function isFiniteInteger(value: unknown): boolean
	if typeof(value) ~= "number" then
		return false
	end
	local n = value :: number
	return n == n and n ~= math.huge and n ~= -math.huge and n % 1 == 0
end

-- Moedas: nunca negativas. `amount` positivo ganha, negativo gasta.
function ProfileRules.addCoins(profile: Profile, amount: number): (boolean, string?)
	if not isFiniteInteger(amount) then
		return false, "InvalidAmount"
	end
	local newValue = profile.coins + amount
	if newValue < 0 then
		return false, "InsufficientCoins"
	end
	profile.coins = newValue
	return true, nil
end

-- Pontos de elo: nunca negativos (perda maior que o saldo para em 0). Atualiza o pico.
function ProfileRules.applyRankDelta(profile: Profile, delta: number): (boolean, string?)
	if not isFiniteInteger(delta) then
		return false, "InvalidAmount"
	end
	local rank = profile.rank
	rank.points = math.max(0, rank.points + delta)
	rank.peakPoints = math.max(rank.peakPoints, rank.points)
	return true, nil
end

-- Cartas: só IDs do CardConfig, e no máximo uma carta por tecla (GDD 8.3).
function ProfileRules.grantCard(
	profile: Profile,
	cardId: string,
	source: PlayerData.CardSource,
	now: number,
	catalogs: Catalogs?
): (boolean, string?)
	local c = catalogs or DEFAULT_CATALOGS
	local card = c.getCard(cardId)
	if card == nil then
		return false, "UnknownCard"
	end
	local owned = profile.cards.owned
	if owned[cardId] ~= nil then
		return false, "AlreadyOwned"
	end
	local sameKey = 0
	for ownedId in owned do
		local ownedCard = c.getCard(ownedId)
		if ownedCard and ownedCard.key == card.key then
			sameKey += 1
		end
	end
	if sameKey >= CardConfig.MaxCardsPerKey then
		return false, "KeyTaken"
	end
	owned[cardId] = { acquiredAt = now, source = source }
	return true, nil
end

-- Skins: dar uma skin do catálogo.
function ProfileRules.grantSkin(
	profile: Profile,
	skinId: string,
	source: PlayerData.SkinSource,
	now: number,
	catalogs: Catalogs?
): (boolean, string?)
	local c = catalogs or DEFAULT_CATALOGS
	if c.getSkin(skinId) == nil then
		return false, "UnknownSkin"
	end
	if profile.cosmetics.owned[skinId] ~= nil then
		return false, "AlreadyOwned"
	end
	profile.cosmetics.owned[skinId] = { acquiredAt = now, source = source }
	return true, nil
end

-- Equipar: só skin que o jogador tem e que pertence àquele slot/arma. Emotes usam setEmotes.
function ProfileRules.equipSkin(profile: Profile, skinId: string, catalogs: Catalogs?): (boolean, string?)
	local c = catalogs or DEFAULT_CATALOGS
	local skin = c.getSkin(skinId)
	if skin == nil then
		return false, "UnknownSkin"
	end
	if profile.cosmetics.owned[skinId] == nil then
		return false, "NotOwned"
	end
	local equipped = profile.cosmetics.equipped
	if skin.slot == "weapon" then
		local weaponId = skin.weaponId
		if weaponId == nil or not c.isValidWeapon(weaponId) then
			return false, "WrongSlot"
		end
		equipped.weapons[weaponId] = skinId
	elseif skin.slot == "melee" then
		equipped.melee = skinId
	elseif skin.slot == "body" then
		equipped.body = skinId
	elseif skin.slot == "head" then
		equipped.head = skinId
	elseif skin.slot == "victoryEffect" then
		equipped.victoryEffect = skinId
	else
		return false, "WrongSlot"
	end
	return true, nil
end

-- Volta uma arma (ou o Bastão) para a skin padrão.
function ProfileRules.unequipWeaponSkin(profile: Profile, weaponId: string, catalogs: Catalogs?): (boolean, string?)
	local c = catalogs or DEFAULT_CATALOGS
	if weaponId == WeaponConfig.Melee.id then
		profile.cosmetics.equipped.melee = nil
		return true, nil
	end
	if not c.isValidWeapon(weaponId) then
		return false, "UnknownWeapon"
	end
	profile.cosmetics.equipped.weapons[weaponId] = nil
	return true, nil
end

-- Comprar uma skin com moedas (F9): precisa estar à venda, o jogador não pode já ter e precisa ter
-- saldo. Tudo ou nada: se algo falha, nem as moedas nem a coleção mudam. Quem chama é o EconomyService.
function ProfileRules.buySkinWithCoins(
	profile: Profile,
	skinId: string,
	now: number,
	catalogs: Catalogs?
): (boolean, string?)
	local c = catalogs or DEFAULT_CATALOGS
	local skin = c.getSkin(skinId)
	if skin == nil then
		return false, "UnknownSkin"
	end
	local price = skin.priceCoins
	if price == nil or not isFiniteInteger(price) or price <= 0 then
		return false, "NotForSale"
	end
	if profile.cosmetics.owned[skinId] ~= nil then
		return false, "AlreadyOwned"
	end
	if profile.coins < price then
		return false, "InsufficientCoins"
	end
	local ok, err = ProfileRules.addCoins(profile, -price)
	if not ok then
		return false, err
	end
	profile.cosmetics.owned[skinId] = { acquiredAt = now, source = "shop_coins" }
	return true, nil
end

-- Estatísticas de uma partida (DADOS 3.1 Stats). Números inteiros e não negativos; abates por arma só
-- com IDs do WeaponConfig (os outros são ignorados, sem recusar o resto).
export type MatchStats = {
	placement: number?,
	roundsPlayed: number,
	roundsWon: number,
	kills: number,
	deaths: number,
	damageDealt: number,
	viradasWon: number,
	soloRoundsWon: number,
	killsByWeapon: { [string]: number },
}

function ProfileRules.addMatchStats(profile: Profile, match: MatchStats, catalogs: Catalogs?): (boolean, string?)
	local c = catalogs or DEFAULT_CATALOGS
	for _, value in
		{
			match.roundsPlayed,
			match.roundsWon,
			match.kills,
			match.deaths,
			match.viradasWon,
			match.soloRoundsWon,
		}
	do
		if not isFiniteInteger(value) or value < 0 then
			return false, "InvalidAmount"
		end
	end
	local damage = match.damageDealt
	if typeof(damage) ~= "number" or damage ~= damage or damage < 0 or damage == math.huge then
		return false, "InvalidAmount"
	end
	local stats = profile.stats
	stats.matchesPlayed += 1
	if match.placement == 1 then
		stats.matchesWon += 1
	end
	if match.placement and match.placement <= 3 then
		stats.podiums += 1
	end
	stats.roundsPlayed += match.roundsPlayed
	stats.roundsWon += match.roundsWon
	stats.kills += match.kills
	stats.deaths += match.deaths
	stats.damageDealt += math.floor(damage)
	stats.viradasWon += match.viradasWon
	stats.soloRoundsWon += match.soloRoundsWon
	for weaponId, count in match.killsByWeapon do
		if c.isValidWeapon(weaponId) and isFiniteInteger(count) and count > 0 then
			stats.killsByWeapon[weaponId] = (stats.killsByWeapon[weaponId] or 0) + count
		end
	end
	return true, nil
end

-- Uma partida ranqueada a mais (para a proteção das primeiras partidas, GDD 9.2).
function ProfileRules.countRankedMatch(profile: Profile): (boolean, string?)
	profile.rank.matchesPlayed += 1
	return true, nil
end

-- Emotes: até 4, todos do jogador, todos do tipo emote, sem repetir.
function ProfileRules.setEmotes(profile: Profile, emoteIds: { string }, catalogs: Catalogs?): (boolean, string?)
	local c = catalogs or DEFAULT_CATALOGS
	if #emoteIds > DataConfig.MaxEquippedEmotes then
		return false, "TooMany"
	end
	local seen: { [string]: boolean } = {}
	for _, id in emoteIds do
		local skin = c.getSkin(id)
		if skin == nil then
			return false, "UnknownSkin"
		end
		if skin.slot ~= "emote" then
			return false, "WrongSlot"
		end
		if profile.cosmetics.owned[id] == nil then
			return false, "NotOwned"
		end
		if seen[id] then
			return false, "Duplicate"
		end
		seen[id] = true
	end
	profile.cosmetics.equipped.emotes = table.clone(emoteIds)
	return true, nil
end

-- Parceiros recentes: no máximo 10, mais recente primeiro, sem repetir o mesmo jogador.
function ProfileRules.addRecentPartner(profile: Profile, userId: number, now: number): (boolean, string?)
	if not isFiniteInteger(userId) or userId <= 0 then
		return false, "InvalidUser"
	end
	local list = profile.social.recentPartners
	for i = #list, 1, -1 do
		if list[i].userId == userId then
			table.remove(list, i)
		end
	end
	table.insert(list, 1, { userId = userId, at = now })
	while #list > DataConfig.MaxRecentPartners do
		table.remove(list)
	end
	return true, nil
end

-- Elogio recebido do parceiro (GDD 12.4): só soma, com teto.
function ProfileRules.addPraise(profile: Profile): (boolean, string?)
	local social = profile.social
	social.praisesReceived = math.min(social.praisesReceived + 1, SocialConfig.Praise.MaxReceived)
	return true, nil
end

-- Abates por arma: só IDs do WeaponConfig.
function ProfileRules.addWeaponKills(
	profile: Profile,
	weaponId: string,
	count: number,
	catalogs: Catalogs?
): (boolean, string?)
	local c = catalogs or DEFAULT_CATALOGS
	if not c.isValidWeapon(weaponId) then
		return false, "UnknownWeapon"
	end
	if not isFiniteInteger(count) or count < 0 then
		return false, "InvalidAmount"
	end
	local byWeapon = profile.stats.killsByWeapon
	byWeapon[weaponId] = (byWeapon[weaponId] or 0) + count
	return true, nil
end

return ProfileRules
