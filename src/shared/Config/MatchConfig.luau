--!strict
-- Loop da partida (GDD seção 4). Tempos em segundos.

local MatchConfig = {
	-- Vidas da dupla (GDD 2 e 4.3) [DECIDIDO]
	StartingLives = 5,
	MaxLives = 5,
	LivesLostPerRoundLoss = 1,

	-- Máquina de estados (GDD 4.1)
	ReceivingPlayersTimeout = 20, -- RECEBENDO_JOGADORES, até 20 s
	ArenaTeleportTime = 3, -- TELEPORTE
	PrepTimeFirstRound = 15, -- PREPARACAO na 1ª rodada (inclui escolha de carta) [PROPOSTA]
	PrepTimeOtherRounds = 10, -- PREPARACAO nas demais [PROPOSTA]
	CombatMaxTime = 90, -- COMBATE, até 90 s
	RoundEndTime = 5, -- FIM_RODADA (placar)
	ChampionCeremonyTime = 15, -- CAMPEAO

	-- Zona e tempo esgotado (GDD 4.4) [PROPOSTA]
	Zone = {
		StartsAt = 60, -- segundos de combate até a zona começar a fechar
		CloseDuration = 30, -- fecha até o centro em 30 s
		DamagePerSecond = 10,
		IgnoresShield = true,
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
		AvoidSameMapTwiceInArena = true,
	},

	-- Fim da partida (GDD 4.7) [PROPOSTA] — final melhor de 3 ainda em aberto (GDD 18, item 11)
	Final = {
		Enabled = true,
		BestOf = 3,
	},
	TargetDurationMinutes = { Min = 8, Max = 12 },

	-- Jogador sem par joga 1v2, sem bônus (GDD 4.2) [DECIDIDO]
	SoloPlayerBonus = false,

	-- Casos especiais (GDD 4.9)
	Afk = {
		WarnAfter = 30,
		SendToLobbyAfter = 60,
	},

	-- Ult liberada a partir desta rodada (GDD 8.5) [DECIDIDO] — repetida em CardConfig por clareza
	UltUnlockRound = 4,
}

return MatchConfig
