--!strict
-- Bots de preenchimento (pedido do dono do projeto depois da F10). TEMPORÁRIO: existe porque, no
-- começo, quase não há jogadores na fila. Como desligar e como remover: docs/BOTS.md.
--
--   * Na fila, cada bot é uma vaga vazia: aparece na contagem para o jogador ("Procurando partida…"),
--     mas um jogador de verdade que chega fica com a vaga. Ninguém espera mais que StartAfterSeconds.
--   * Na partida, o servidor completa a sala com bots até FillTo. Eles andam pelo mapa, atiram, usam
--     as armas da rodada e as cartas, como um jogador ruim (fáceis de derrubar, pensando no celular).
--   * Partida com bot: moedas normais, elo parado [DECIDIDO pelo dono do projeto].
--
-- Os números são [PROPOSTA]: ajuste aqui, sem mexer no código.

local BotConfig = {
	-- Chave geral. false = fila e partida voltam a funcionar como antes dos bots (docs/BOTS.md).
	Enabled = true,

	-- Fila (lobby) ------------------------------------------------------------------------------------
	Queue = {
		-- A partida sai no máximo este tempo depois da chegada de quem espera há mais tempo, completada
		-- com bots até FillTo. As regras normais da fila (7 → espera até 16; flexível) continuam valendo
		-- e podem fazer a partida sair antes.
		StartAfterSeconds = 35,
		FillTo = 16, -- sala cheia: 8 duplas, duelo nas 4 ilhas
		-- Vagas mostradas na contagem (jogadores + bots), pelo tempo de espera de quem chegou primeiro,
		-- como fração de FillTo. Entre dois pontos a conta sobe aos poucos; antes do primeiro, só gente.
		-- Com FillTo 16: 10 s → 2 vagas (o primeiro bot), 20 s → 6, 30 s → 12, 35 s → sala cheia.
		Ramp = {
			{ seconds = 10, fill = 0.125 },
			{ seconds = 20, fill = 0.4 },
			{ seconds = 30, fill = 0.75 },
			{ seconds = 35, fill = 1 },
		},
	},

	-- Partida -----------------------------------------------------------------------------------------
	Match = {
		FillTo = 16, -- igual a Queue.FillTo
		-- Sem composição da fila (Studio, teleporte de teste): completa a sala com bots também.
		-- A partida começa 20 s depois do primeiro jogador (MatchConfig.ReceivingPlayersTimeout) ou
		-- no "COMEÇAR AGORA" do painel TESTE.
		FillWithoutHandoff = true,
		-- Partida com bot não mexe no elo; moedas e estatísticas normais [DECIDIDO].
		AffectsRank = false,
	},

	-- Placar e tela: o bot aparece como um jogador (nome, elo e abates), sem a marca "BOT".
	Disguise = true,
	-- Elo mostrado no placar para cada bot (sorteado).
	DisplayTiers = { "Bronze", "Bronze", "Bronze", "Prata" },
	UserIdBase = -1000, -- UserIds de mentira dos bots: -1001, -1002… (nunca colide com o Studio)

	-- Habilidade: bots ruins de propósito ------------------------------------------------------------
	Skill = {
		ReactionSeconds = { Min = 0.75, Max = 1.25 }, -- do momento em que vê até o primeiro tiro
		-- Erro de mira em graus (cone). Cresce com a distância e quando ele ou o alvo se mexem.
		AimErrorDegrees = 5.5,
		AimErrorPerStud = 0.05, -- graus a mais por stud de distância
		AimErrorMoving = 2.5, -- o bot andando
		AimErrorTargetMoving = 3, -- o alvo andando (ele acompanha atrasado)
		-- Os primeiros tiros num alvo novo erram mais (o erro cai até o normal em WarmupShots tiros)
		AimErrorWarmup = 6,
		WarmupShots = 4,
		-- A mira segue o alvo atrasada: quanto maior, mais rápido ela alcança (por segundo)
		TrackSpeed = 3.5,
		FireRateMultiplier = 0.6, -- atira a 60% da cadência da arma
		DamageMultiplier = 0.6, -- 60% do dano da arma contra jogadores
		-- Rajadas: atira um tempo, para um tempo
		BurstSeconds = { Min = 0.6, Max = 1.4 },
		PauseSeconds = { Min = 0.5, Max = 1.1 },
		-- Bot contra bot (ninguém sofre): acaba mais rápido, para quem está no mirante não esperar
		VsBotErrorMultiplier = 0.45,
		VsBotDamageMultiplier = 2,
		-- Percepção
		SightRange = 90, -- studs
		FieldOfViewDegrees = 120,
		CloseAwareness = 14, -- percebe quem chega perto, mesmo de costas
		MemorySeconds = 5, -- vai até onde viu o inimigo por último
		-- Troca para a pistola quando a primária está recarregando e o inimigo está perto
		SwitchToPistolChance = 0.35,
		MeleeRange = 5, -- usa o corpo a corpo colado no inimigo
		MeleeHitChance = 0.55, -- golpes que acertam
		TremorAimError = 4, -- graus a mais com a mira tremida pelo Tremor
		AttackedAwarenessSeconds = 3, -- levou tiro: percebe quem atirou (mesmo de costas) por este tempo
	},

	Movement = {
		ThinkSeconds = 0.2, -- cada bot decide 5 vezes por segundo (espalhados entre os quadros)
		SpeedMultiplier = 0.85, -- anda um pouco mais devagar que um jogador
		RepathSeconds = 2.5,
		WaypointReach = 2.5,
		StuckSeconds = 1.2,
		-- Sem achar ninguém depois deste tempo de combate, vai atrás de um inimigo (como quem ouve os
		-- tiros). Antes disso, anda pelo mapa puxando para o lado do inimigo.
		HuntAfterSeconds = 12,
		-- Combate: fica de lado (strafe), às vezes para de se mexer (alvo fácil)
		StrafeStuds = 6,
		StrafeSeconds = { Min = 0.8, Max = 2 },
		StandStillChance = 0.35,
		-- Distância que tenta manter do inimigo, por categoria da arma
		PreferredRange = {
			Pistol = 18,
			SMG = 16,
			Shotgun = 8,
			LightRifle = 26,
			Rifle = 30,
			Sniper = 45,
			MachineGun = 26,
			Melee = 3,
		} :: { [string]: number },
		ZoneMargin = 6, -- volta para dentro da zona com esta folga
		-- Preparação: passeia dentro da base
		PrepWanderSeconds = { Min = 1.5, Max = 4 },
		-- Agente do Roblox para o caminho (PathfindingService)
		AgentRadius = 1.5,
		AgentHeight = 5,
		WaypointSpacing = 6,
	},

	-- Chance por segundo de usar cada carta quando a situação pede (e ela tem carga)
	Cards = {
		card_nuvem = 0.35, -- inimigo à vista e vida abaixo de LowHealth
		card_impulso = 0.08, -- inimigo à vista (ou preso)
		card_tremor = 0.5, -- inimigo à vista, no chão, ao alcance da onda
		card_renascer = 0.6, -- inimigo à vista e vida abaixo de LowHealth
		LowHealth = 0.55, -- fração de vida + escudo
	} :: { [string]: number },

	-- Preparação: tempo para "confirmar" a escolha (o parceiro de verdade vê o bot decidindo)
	ConfirmSeconds = { Min = 2, Max = 6 },

	-- Animações padrão R15 do Roblox (as mesmas do personagem dos jogadores), tocadas pelo servidor.
	-- O corpo criado já traz as dele (script Animate); estes números são só a reserva.
	Animations = {
		idle = "rbxassetid://507766666",
		walk = "rbxassetid://507777826",
		jump = "rbxassetid://507765000",
		fall = "rbxassetid://507767968",
	} :: { [string]: string },
	WalkAnimationSpeed = 16, -- velocidade (studs/s) em que a animação de andar toca em 1×
}

return BotConfig
