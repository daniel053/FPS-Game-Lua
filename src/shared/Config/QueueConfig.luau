--!strict
-- Fila e matchmaking (GDD 6.2 e 6.3).

local QueueConfig = {
	-- Montagem da partida (GDD 6.2)
	MinPlayersToStart = 7, -- [DECIDIDO]
	FillWaitSeconds = 15, -- ao chegar a 7, espera até 16 [PROPOSTA]
	MaxPlayers = 16, -- [PROPOSTA]
	FlexibleAfterSeconds = 60, -- sem 7 em 60 s, começa com quem houver... [PROPOSTA]
	FlexibleMinPlayers = 4, -- ...a partir de 4 [PROPOSTA]
	SharedAcrossLobbyServers = true,

	-- Separação por nível (GDD 6.3) [PROPOSTA]
	Tiers = {
		Aprendizes = {
			MaxMatchesPlayed = 9, -- contas com menos de 10 partidas
			RankTiers = { "Bronze", "Prata" },
		},
		Experientes = {
			RankTiers = { "Ouro", "Platina", "Mestre", "Deus" },
		},
	},
	TierMergeAfterSeconds = 45, -- faixa sem 7 jogadores em 45 s junta com a outra
	FixedDuoUsesHigherRank = true, -- dupla fixa entra na faixa do maior elo
}

return QueueConfig
