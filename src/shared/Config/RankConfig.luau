--!strict
-- Elo (GDD seção 9). Os nomes exibidos ficam em Strings.Ranks; ícones e cores em Theme.Rank.

local Types = require(script.Parent.Parent.Types)

export type RankTier = {
	id: Types.RankTierId,
	minPoints: number,
}

export type PlacementPoints = {
	fromPlace: number,
	toPlace: number,
	points: number,
}

local RankConfig = {
	-- Faixas (GDD 9.1), em ordem crescente [DECIDIDO] com valores [PROPOSTA]
	Tiers = {
		{ id = "Bronze", minPoints = 0 },
		{ id = "Prata", minPoints = 1000 },
		{ id = "Ouro", minPoints = 2000 },
		{ id = "Platina", minPoints = 3000 },
		{ id = "Mestre", minPoints = 4000 },
		{ id = "Deus", minPoints = 5000 },
	} :: { RankTier },

	-- Ganho e perda por colocação da dupla (GDD 9.2) [PROPOSTA], escrita para uma partida de 8 duplas.
	-- Em partidas com menos duplas, a tabela é proporcional (F9): a colocação é levada para a escala de
	-- 8 (1º continua 1º, último vira 8º) e arredondada. Ex.: 4 duplas -> 1º, 3º, 6º e 8º.
	PlacementPoints = {
		{ fromPlace = 1, toPlace = 1, points = 40 },
		{ fromPlace = 2, toPlace = 2, points = 25 },
		{ fromPlace = 3, toPlace = 4, points = 10 },
		{ fromPlace = 5, toPlace = 6, points = -5 },
		{ fromPlace = 7, toPlace = 8, points = -15 },
	} :: { PlacementPoints },
	ReferenceTeams = 8, -- a tabela acima vale para esta quantidade de duplas

	MinPoints = 0, -- Bronze não perde abaixo de 0
	ProtectedMatches = 10, -- nas 10 primeiras partidas não perde PE
	DoubleLossFromTier = "Mestre" :: Types.RankTierId, -- a partir de Mestre, perdas dobram
	DoubleLossMultiplier = 2,
	PrivateMatchesAffectRank = false, -- (GDD 6.6) [PROPOSTA]
	-- Quem sai no meio (ou volta ao lobby por ausência) conta como se a dupla tivesse caído naquele
	-- momento, sem perda menor para quem desiste [DECIDIDO] (F9)
	LeaverCountsAsEliminatedNow = true,

	-- Elo ADM (GDD 9.4) [DECIDIDO]: só pelo UserId, nunca pelo nome. Só cosmético.
	AdminUserIds = {
		4865569761, -- dono do projeto
	} :: { number },

	-- Ranking global (DADOS-JOGADOR seção 8)
	LeaderboardStoreName = "RankLeaderboard_v1", -- OrderedDataStore; prefixo DEV_ pelo Env
	LeaderboardTopCount = 100,
	LeaderboardRefreshSeconds = 300, -- o lobby lê os 100 primeiros a cada 5 min (não a cada tela aberta)
	DevLeaderboardRefreshSeconds = 30, -- em teste (DEV_), para ver o ranking mudar sem esperar
	LeaderboardWriteRetries = 5, -- espera crescente: 1, 2, 4, 8 e 16 s
	-- O elo ADM fica fixo no topo do ranking, com o selo ADM, fora da contagem dos 100 [DECIDIDO] (F9)
	AdminPinnedOnLeaderboard = true,
}

return RankConfig
