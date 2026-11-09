--!strict
-- Cartas de habilidade (GDD seção 8). Nomes e descrições ficam em Strings.Cards (por ID).
-- Na primeira versão só existem estas 4 cartas, iguais para todos (GDD 8.8) [DECIDIDO].
-- O sistema já nasce pronto para crescer: cada carta tem tecla fixa e a regra é uma carta por tecla.

local Types = require(script.Parent.Parent.Types)

export type CardDef = {
	id: string,
	key: Types.CardKey,
	isUlt: boolean,
	rarity: Types.Rarity?, -- raridade das 4 cartas iniciais: [ABERTO] (GDD 8.9)
	charges: number, -- cargas por rodada
	cooldown: number?, -- segundos de recarga entre cargas (nil = sem recarga dentro da rodada)
	params: { [string]: number },
}

local Cards: { CardDef } = {
	-- Nuvem (C): fumaça arremessável [PROPOSTA]
	{
		id = "card_nuvem",
		key = "C",
		isUlt = false,
		rarity = nil,
		charges = 2,
		cooldown = nil,
		params = {
			Radius = 8,
			Duration = 7,
		},
	},
	-- Impulso (Q): salto para cima [PROPOSTA]
	{
		id = "card_impulso",
		key = "Q",
		isUlt = false,
		rarity = nil,
		charges = 1,
		cooldown = 20,
		params = {
			LaunchHeight = 18,
		},
	},
	-- Tremor (E): onda no chão [PROPOSTA]
	{
		id = "card_tremor",
		key = "E",
		isUlt = false,
		rarity = nil,
		charges = 1,
		cooldown = 25,
		params = {
			Length = 20,
			Width = 6,
			SlowPercent = 0.5,
			DebuffDuration = 2,
			Damage = 0,
		},
	},
	-- Renascer (X, ult): segunda chance
	{
		id = "card_renascer",
		key = "X",
		isUlt = true,
		rarity = nil,
		charges = 1, -- 1 uso por rodada [PROPOSTA]
		cooldown = nil,
		params = {
			Window = 8, -- segundos em que cair faz voltar à marca
		},
	},
}

local CardConfig = {
	Cards = Cards,

	-- Cartas entregues pelo tutorial (GDD 8.8)
	StarterCards = { "card_nuvem", "card_impulso", "card_tremor", "card_renascer" },

	-- Escolha de carta (GDD 8.2) [DECIDIDO]
	ChoiceRound = 1, -- só na 1ª rodada
	ChoiceTime = 15, -- segundos; sem escolha = partida sem carta básica
	BasicKeys = { "C", "Q", "E" } :: { Types.CardKey },

	-- Ult (GDD 8.5) [DECIDIDO]
	UltKey = "X" :: Types.CardKey,
	UltUnlockRound = 4,
	UltUsesPerRound = 1, -- [PROPOSTA]

	-- Coleção (GDD 8.3) [DECIDIDO]: no máximo uma carta por tecla.
	MaxCardsPerKey = 1,
}

local byId: { [string]: CardDef } = {}
for _, card in Cards do
	byId[card.id] = card
end

function CardConfig.get(id: string): CardDef?
	return byId[id]
end

return CardConfig
