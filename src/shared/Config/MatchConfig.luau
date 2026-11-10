--!strict
-- Loop da partida (GDD seção 4). Tempos em segundos.

local MatchConfig = {
	-- Vidas da dupla (GDD 2 e 4.3) [DECIDIDO]
	StartingLives = 5,
	MaxLives = 5,
	LivesLostPerRoundLoss = 1,

	-- Máquina de estados (GDD 4.1)
	ReceivingPlayersTimeout = 20, -- RECEBENDO_JOGADORES, até 20 s
	ArenaTeleportTime = 3, -- TELEPORTE (confrontos na tela, depois todos vão para as ilhas)
	PrepTimeFirstRound = 15, -- PREPARACAO na 1ª rodada (inclui escolha de carta) [PROPOSTA]
	PrepTimeOtherRounds = 10, -- PREPARACAO nas demais [PROPOSTA]
	CombatMaxTime = 90, -- COMBATE, até 90 s
	RoundEndTime = 5, -- FIM_RODADA (placar)
	ChampionCeremonyTime = 15, -- CAMPEAO
	EndScreenTime = 20, -- TELA_FINAL: escolhas da seção 4.8, depois todos voltam ao lobby
	-- Duelo que acabou antes dos outros: a dupla volta ao mirante depois deste tempo
	DuelEndToMiranteDelay = 3,

	-- Começo da partida.
	-- Vindo da fila (F5): o servidor reservado lê a composição (MatchHandoff) e começa quando todos
	-- chegam ou ReceivingPlayersTimeout segundos depois do primeiro. Quem não chegou fica de fora;
	-- com menos de MinArrived, quem chegou volta para a fila, na frente.
	-- Sem composição (teste no Studio ou teleporte de teste): como na F3, quem estiver no servidor,
	-- com o mínimo de MinPlayers.
	Start = {
		MinPlayers = 4, -- igual ao mínimo flexível da fila (QueueConfig.FlexibleMinPlayers)
		DevMinPlayers = 2, -- ambiente DEV_: dá para testar com 2 clientes (ou 1 + jogadores de teste)
		MaxPlayers = 16, -- QueueConfig.MaxPlayers
		MinArrived = 2, -- vindo da fila: segue com quem chegou, a partir de 2 [DECIDIDO na F5]
		HandoffReadSeconds = 10, -- quanto tempo tenta ler o MatchHandoff ao abrir o servidor
	},

	-- Jogador sem par (número ímpar) joga 1v2, sem bônus (GDD 4.2) [DECIDIDO].
	-- Quem fica sozinho: o de maior elo entre os que sobraram sem par [PROPOSTA].
	SoloPlayerBonus = false,
	OddPlayerSolo = "HighestElo",

	-- Zona e tempo esgotado (GDD 4.4) [PROPOSTA]
	Zone = {
		StartsAt = 60, -- segundos de combate até a zona começar a fechar
		CloseDuration = 30, -- fecha até o centro em 30 s
		DamagePerSecond = 10,
		IgnoresShield = true,
		FinalRadius = 8, -- raio no fim do fechamento (studs)
		StartMargin = 6, -- o círculo começa cobrindo a ilha inteira + esta folga
	},
	-- Aos 90 s com as duas duplas vivas: vence quem tiver mais HP + escudo somados; empate exato = ninguém perde vida.
	TimeoutTieBreak = "HpPlusShield",

	-- Rodada da Virada (GDD 4.5) [DECIDIDO]
	Virada = {
		TriggerLives = 1, -- primeira vez que qualquer dupla fica com 1 vida
		WinnerLifeBonus = 1, -- teto = MaxLives
		OncePerMatch = true,
	},

	-- Sorteio de confrontos (GDD 4.6) [PROPOSTA]
	Pairing = {
		AvoidRepeatOpponent = true,
		ByePriorityMoreLives = true, -- folga gira; prioridade para quem tem mais vidas
		AvoidSameMapTwiceInArena = true, -- a dupla não joga na mesma ilha duas rodadas seguidas (se der)
		Attempts = 60, -- sorteios testados para achar a combinação com menos repetições
	},

	-- Fim da partida (GDD 4.7) [PROPOSTA]. Com 2 duplas vivas começa a final: as vidas param de
	-- contar e vence quem ganhar WinsNeeded rodadas [DECIDIDO pelo dono do projeto na F3].
	Final = {
		Enabled = true,
		BestOf = 3,
		WinsNeeded = 2,
	},
	TargetDurationMinutes = { Min = 8, Max = 12 },

	-- Casos especiais (GDD 4.9)
	Afk = {
		WarnAfter = 30,
		SendToLobbyAfter = 60,
		MoveThreshold = 1, -- studs andados que contam como atividade
		LookThreshold = 0.02, -- mudança na direção do olhar que conta como atividade
	},

	-- Cair da ilha volta para a base e perde o escudo (MapConfig.General) [PROPOSTA]
	FallOutDepth = 25, -- studs abaixo do chão da ilha (ou do mirante)

	-- Espectar o parceiro: o cliente manda para onde olha (o servidor repassa num atributo)
	LookSyncPerSecond = 15,

	-- Ult liberada a partir desta rodada (GDD 8.5) [DECIDIDO] — repetida em CardConfig por clareza
	UltUnlockRound = 4,

	-- Ferramentas de teste (só DEV_)
	Dev = {
		MaxBots = 15, -- jogadores de teste (alvos parados) para montar partidas de 4 a 16
		BotDuelSeconds = 6, -- duelo só entre jogadores de teste: resultado sorteado depois deste tempo
	},
}

return MatchConfig
