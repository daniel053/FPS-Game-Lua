--!strict
-- Fila, grupo e matchmaking (GDD 6.2, 6.3 e 6.4; FASES F5).

local QueueConfig = {
	-- Montagem da partida (GDD 6.2)
	MinPlayersToStart = 7, -- [DECIDIDO]
	FillWaitSeconds = 15, -- ao chegar a 7, espera até 16 [PROPOSTA]
	MaxPlayers = 16, -- [PROPOSTA]
	FlexibleAfterSeconds = 20, -- sem 7 em 20 s, começa com quem houver... [DECIDIDO na F5; era 60 s]
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

	-- Ambiente DEV_ (Studio e jogo de teste): só o que muda em teste [DECIDIDO na F5].
	-- Com 2 ou mais na fila, a partida sai em 5 s (as faixas também se juntam em 5 s).
	Dev = {
		FlexibleMinPlayers = 2,
		FlexibleAfterSeconds = 5,
		TierMergeAfterSeconds = 5,
	},

	-- Grupo no lobby (GDD 6.4, decisões da F5)
	PartySize = 2,
	InviteExpireSeconds = 30, -- convite sem resposta some
	-- Ao voltar da partida como dupla fixa, espera o parceiro chegar ao lobby por até este tempo
	PartnerArrivalWaitSeconds = 20,
	RequestsPerSecond = 10, -- limite de pedidos do cliente (LobbyRequest)

	-- Fila compartilhada no MemoryStore (detalhes técnicos; ver GDD 20, F5)
	Store = {
		TicketTtlSeconds = 30, -- ficha que ninguém renova some sozinha (servidor que caiu)
		TicketRefreshSeconds = 3, -- o lobby dono da ficha renova e confere se ela foi chamada
		LeaderLockSeconds = 10, -- trava do lobby "líder", que monta as partidas
		LeaderTickSeconds = 1,
		StatusTtlSeconds = 15,
		StatusPollSeconds = 2, -- cada lobby lê o estado da fila (contagem "5/7")
		MaxTicketsRead = 400,
		MatchHandoffTtlSeconds = 300, -- MatchHandoff expira em 5 min (DADOS-JOGADOR 2)
		LobbyHandoffTtlSeconds = 120, -- volta da partida para o lobby (nova partida, dupla fixa)
		Retries = 3,
		DevForceTtlSeconds = 10, -- painel TESTE: "começar já"
	},

	-- Teleporte para a partida: se o jogador continuar no lobby depois disto, o teleporte travou
	-- e ele volta para a fila (FASES F5: ninguém fica preso em teleporte).
	TeleportStuckSeconds = 30,
}

return QueueConfig
