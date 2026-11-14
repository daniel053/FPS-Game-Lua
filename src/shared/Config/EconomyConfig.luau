--!strict
-- Economia (GDD seção 10). Valores [PROPOSTA].

local Types = require(script.Parent.Parent.Types)

local EconomyConfig = {
	-- Moedas ganhas (GDD 10.1)
	Rewards = {
		RoundParticipation = 5, -- por rodada jogada (a dupla de folga não ganha)
		RoundWin = 10,
		Kill = 3,
		PlacementByPlace = {
			[1] = 100,
			[2] = 60,
			[3] = 30,
			[4] = 30,
		} :: { [number]: number },
		-- "Primeira vitória do dia" = a primeira RODADA vencida no dia (UTC) [DECIDIDO] (F9)
		FirstWinOfDay = 150,
		-- Jogou a partida inteira com o mesmo parceiro: +10% sobre as moedas da partida (sem contar a
		-- primeira vitória do dia). Quem joga sozinho (1v2) não tem parceiro e não ganha o bônus.
		SamePartnerWholeMatchBonus = 0.10,
	},

	-- Preços em moedas (GDD 10.2). Na v1 as moedas compram só skins.
	Prices = {
		CardBasicCommon = 1500, -- futuro
		CardBasicRare = 3000, -- futuro
		CardUlt = 5000, -- futuro
		-- Skins por raridade [DECIDIDO] (F9): a tabela do GDD falava em "rara", que não existe na escala.
		-- Celestial não é vendida por moedas (só eventos).
		SkinByRarity = {
			Comum = 600,
			Epica = 2000,
			Lendaria = 5000,
		} :: { [Types.Rarity]: number },
	},

	-- Partidas privadas: elo não muda e as moedas valem metade [DECIDIDO] (F9; as partidas privadas
	-- em si chegam na F11)
	PrivateMatchRewardMultiplier = 0.5,

	-- Pedidos de compra/equipar vindos do cliente: limite de frequência
	ShopRequestWindowSeconds = 5,
	ShopRequestMaxPerWindow = 10,

	-- Regras fixas (GDD 8.9 e 10.3)
	CardsSoldForRobux = false,
	PaidRandomRewards = false, -- proibido (ECA Digital, Lei 15.211/2025)
	CoinsNeverNegative = true,
}

return EconomyConfig
