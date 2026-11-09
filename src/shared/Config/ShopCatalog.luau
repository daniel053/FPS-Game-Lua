--!strict
-- Catálogo de skins (GDD 11 e DADOS-JOGADOR 1.8). Vazio até a F9.
-- Cada item é salvo no perfil pelo ID (ex.: "skin_rajada_laranja"), nunca pelo nome exibido.

local Types = require(script.Parent.Parent.Types)

export type SkinSlot = "weapon" | "melee" | "body" | "head" | "victoryEffect" | "emote"

export type SkinDef = {
	id: string,
	slot: SkinSlot,
	weaponId: string?, -- para skins de arma
	rarity: Types.Rarity,
	priceCoins: number?, -- nil = não vende por moedas
	robuxProductId: number?, -- nil = não vende por Robux (F11)
}

local ShopCatalog = {
	Skins = {} :: { SkinDef },
}

return ShopCatalog
