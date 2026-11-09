--!strict
-- Economia (GDD seção 10). Valores [PROPOSTA].

local EconomyConfig = {
	-- Moedas ganhas (GDD 10.1)
	Rewards = {
		RoundParticipation = 5,
		RoundWin = 10,
		Kill = 3,
		PlacementByPlace = {
			[1] = 100,
			[2] = 60,
			[3] = 30,
			[4] = 30,
		} :: { [number]: number },
		FirstWinOfDay = 150,
		SamePartnerWholeMatchBonus = 0.10, -- +10%
	},

	-- Preços em moedas (GDD 10.2). Na v1 as moedas compram só skins.
	Prices = {
		CardBasicCommon = 1500, -- futuro
		CardBasicRare = 3000, -- futuro
		CardUlt = 5000, -- futuro
		SkinCommon = 600,
		SkinRare = 2000,
		SkinEpic = 5000,
	},

	-- Partidas privadas dão recompensa reduzida (GDD 6.6) [PROPOSTA]; o valor ainda não foi definido.
	PrivateMatchRewardMultiplier = nil :: number?,

	-- Regras fixas (GDD 8.9 e 10.3)
	CardsSoldForRobux = false,
	PaidRandomRewards = false, -- proibido (ECA Digital, Lei 15.211/2025)
	CoinsNeverNegative = true,
}

return EconomyConfig
