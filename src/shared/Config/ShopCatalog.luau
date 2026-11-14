--!strict
-- Catálogo de skins (GDD 11 e DADOS-JOGADOR 3.3). Cada item é salvo no perfil pelo ID
-- (ex.: "skin_rajada_areia"), nunca pelo nome exibido. Nomes em Strings.Skins; cores em Theme.SkinLook.
--
-- Catálogo inicial (F9, proposta aprovada pelo dono do projeto): só skins de ARMA e do Bastão (o
-- personagem é o avatar do jogador, GDD 3.2). Cada tema existe para as 18 armas e o Bastão, e só muda
-- as cores do modelo (nenhum vermelho, nenhum neon, GDD 11). O ID é "skin_<arma>_<tema>", com a arma
-- sem o prefixo "weapon_".
-- Novos temas: uma linha em Themes, as cores em Theme.SkinLook e o nome em Strings.Skins.Themes.

local EconomyConfig = require(script.Parent.EconomyConfig)
local Types = require(script.Parent.Parent.Types)
local WeaponConfig = require(script.Parent.WeaponConfig)

export type SkinSlot = "weapon" | "melee" | "body" | "head" | "victoryEffect" | "emote"

export type SkinDef = {
	id: string,
	slot: SkinSlot,
	weaponId: string?, -- arma (ou o Bastão) que a skin veste
	theme: string?, -- tema de cores (Theme.SkinLook)
	rarity: Types.Rarity,
	priceCoins: number?, -- nil = não vende por moedas
	robuxProductId: number?, -- nil = não vende por Robux (F11)
}

export type SkinTheme = { id: string, rarity: Types.Rarity, forSale: boolean }

local ShopCatalog = {
	-- Temas na ordem em que aparecem na fila de skins do Arsenal (depois da Padrão)
	Themes = {
		{ id = "areia", rarity = "Comum", forSale = true },
		{ id = "floresta", rarity = "Comum", forSale = true },
		{ id = "oceano", rarity = "Epica", forSale = true },
		{ id = "ouro", rarity = "Lendaria", forSale = true },
	} :: { SkinTheme },

	Skins = {} :: { SkinDef },
}

local function shortName(weaponId: string): string
	return (string.gsub(weaponId, "^weapon_", ""))
end

function ShopCatalog.skinId(weaponId: string, themeId: string): string
	return `skin_{shortName(weaponId)}_{themeId}`
end

-- Monta as skins de tema × arma (o catálogo não muda durante o jogo).
local function build()
	local weaponIds: { string } = {}
	for _, def in WeaponConfig.Weapons do
		table.insert(weaponIds, def.id)
	end
	table.insert(weaponIds, WeaponConfig.Melee.id)
	for _, weaponId in weaponIds do
		local isMelee = weaponId == WeaponConfig.Melee.id
		for _, theme in ShopCatalog.Themes do
			table.insert(ShopCatalog.Skins, {
				id = ShopCatalog.skinId(weaponId, theme.id),
				slot = if isMelee then "melee" else "weapon",
				weaponId = weaponId,
				theme = theme.id,
				rarity = theme.rarity,
				priceCoins = if theme.forSale then EconomyConfig.Prices.SkinByRarity[theme.rarity] else nil,
				robuxProductId = nil,
			})
		end
	end
end
build()

local byId: { [string]: SkinDef } = {}
local byWeapon: { [string]: { SkinDef } } = {}
for _, skin in ShopCatalog.Skins do
	byId[skin.id] = skin
	local weaponId = skin.weaponId
	if weaponId then
		local list = byWeapon[weaponId]
		if list == nil then
			list = {}
			byWeapon[weaponId] = list
		end
		table.insert(list, skin)
	end
end

-- Busca por ID.
function ShopCatalog.getSkin(id: string): SkinDef?
	return byId[id]
end

-- Skins de uma arma (ou do Bastão), na ordem dos temas.
function ShopCatalog.skinsFor(weaponId: string): { SkinDef }
	return byWeapon[weaponId] or {}
end

return ShopCatalog
