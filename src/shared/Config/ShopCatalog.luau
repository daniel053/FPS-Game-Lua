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

-- Busca por ID. O índice é montado na primeira busca (o catálogo não muda durante o jogo).
local byId: { [string]: SkinDef }? = nil

function ShopCatalog.getSkin(id: string): SkinDef?
	if byId == nil then
		local index: { [string]: SkinDef } = {}
		for _, skin in ShopCatalog.Skins do
			index[skin.id] = skin
		end
		byId = index
	end
	return (byId :: { [string]: SkinDef })[id]
end

return ShopCatalog
