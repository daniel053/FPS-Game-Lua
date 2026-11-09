--!strict
-- Todos os textos visíveis ao jogador, em português do Brasil (ESTILO-E-TELAS seção 0).
-- Nenhum texto visível é escrito direto no código. Facilita tradução futura.
-- Nomes próprios do jogo; nunca usar nomes de outros jogos.

local Strings = {
	GameName = "[NOME DO JOGO]", -- [ABERTO] (GDD 18, item 1)

	Places = {
		Lobby = "Lobby",
		Tutorial = "Tutorial",
		Match = "Partida",
	},

	WeaponCategories = {
		Pistol = "Pistolas",
		SMG = "Submetralhadoras",
		Shotgun = "Escopetas",
		LightRifle = "Fuzis leves",
		Rifle = "Fuzis",
		Sniper = "Snipers",
		MachineGun = "Metralhadoras",
	},

	WeaponPhases = {
		pistolas = "Pistolas",
		medias = "Armas médias",
		pesadas = "Armas pesadas",
	},

	-- Nomes das armas, por ID (GDD 7.2.3)
	Weapons = {
		weapon_bolinha = "Bolinha",
		weapon_chumbinho = "Chumbinho",
		weapon_zumbido = "Zumbido",
		weapon_precisa = "Precisa",
		weapon_tambor = "Tambor",
		weapon_ferrao = "Ferrão",
		weapon_vespa = "Vespa",
		weapon_balde = "Balde",
		weapon_varredor = "Varredor",
		weapon_tatico = "Tático",
		weapon_atirador = "Atirador",
		weapon_martelo = "Martelo",
		weapon_moedor = "Moedor",
		weapon_rajada = "Rajada",
		weapon_trovao = "Trovão",
		weapon_matapato = "Mata-Pato",
		weapon_gemea = "Gêmea",
		weapon_luneta = "Luneta",
		weapon_bastao = "Bastão",
	} :: { [string]: string },

	-- Cartas, por ID (GDD 8.4)
	Cards = {
		card_nuvem = { name = "Nuvem", description = "Arremessa uma nuvem que bloqueia a visão." },
		card_impulso = { name = "Impulso", description = "Lança você bem alto para cima." },
		card_tremor = {
			name = "Tremor",
			description = "Onda no chão que deixa os inimigos lentos e com a mira tremida.",
		},
		card_renascer = {
			name = "Renascer",
			description = "Deixa uma marca: se cair em 8 s, volta a ela com vida cheia.",
		},
	} :: { [string]: { name: string, description: string } },

	Rarities = {
		Comum = "Comum",
		Epica = "Épica",
		Lendaria = "Lendária",
		Celestial = "Celestial",
	},

	Ranks = {
		Bronze = "Bronze",
		Prata = "Prata",
		Ouro = "Ouro",
		Platina = "Platina",
		Mestre = "Mestre",
		Deus = "Deus",
		Adm = "ADM",
	},

	Maps = {
		map_praca = "Praça",
		map_fabrica = "Fábrica",
		map_porto = "Porto",
		map_torre = "Torre",
		mirante = "Mirante",
	},

	Teams = {
		Azul = "Azul",
		Laranja = "Laranja",
		Verde = "Verde",
		Roxo = "Roxo",
		Amarelo = "Amarelo",
		Branco = "Branco",
		Rosa = "Rosa",
		Ciano = "Ciano",
	},

	-- Dados do jogador (DADOS-JOGADOR seção 5)
	Data = {
		-- Mensagens de expulsão (o Roblox mostra numa janela)
		LoadFailed = "Não foi possível carregar seu progresso agora. Seu progresso está seguro: entre de novo em alguns instantes.",
		SessionEnded = "Seu progresso foi aberto em outro servidor. Entre de novo para continuar.",
		-- Resposta a pedidos de configuração
		SettingsResults = {
			Ok = "Configurações salvas.",
			NotLoaded = "Seu perfil ainda está carregando.",
			RateLimited = "Muitas mudanças seguidas. Espere um pouco.",
			Invalid = "Valor inválido. Nada foi alterado.",
		} :: { [string]: string },
	},

	-- Combate e HUD provisório (F2; visual final na F7)
	Combat = {
		KillSingular = "%d KILL",
		KillPlural = "%d KILLS",
		Infinite = "∞",
		Reloading = "RECARREGANDO",
		Shield = "ESCUDO",
		Hp = "VIDA",
		-- Botões de toque (GDD 13.1)
		FireButton = "ATIRAR",
		AimButton = "MIRA",
		AltButton = "MODO",
		ReloadButton = "RECARREGAR",
		SwitchButton = "1⇄2",
		SlotPrimary = "1",
		SlotSecondary = "2",
		SlotMelee = "3",
		-- Dicas de tecla no PC
		ReloadKey = "R",
		AimKey = "BOTÃO DIREITO",
		DummyName = "ALVO",
		DummyDistance = "%s · %d studs",
		DummyMoving = "%s · andando",
		DummyThinCover = "%s · atrás de cobertura fina",
		KnockedOut = "Você foi derrubado",
	},

	-- Loop da partida (F3; visual final na F7)
	Match = {
		TeamName = "Dupla %s",
		Vs = "%s × %s",
		Life = "♥",
		LifeLost = "♡",
		-- Antes de começar
		Waiting = "Esperando jogadores · %d de %d",
		StartsIn = "A partida começa em %d s",
		Forming = "Formando as duplas…",
		YourTeam = "Você está na %s",
		SoloTeam = "Você joga sozinho nesta partida (1 contra 2)",
		YourPartner = "Parceiro: %s",
		-- Rodada
		Round = "RODADA %d",
		RoundPhase = "RODADA %d · %s",
		FinalRound = "FINAL · RODADA %d",
		FinalScore = "Vitórias na final: %d × %d (vence quem fizer %d)",
		ViradaBadge = "VIRADA",
		ViradaTitle = "RODADA DA VIRADA",
		ViradaSubtitle = "Quem vencer ganha +1 vida",
		FinalTitle = "FINAL",
		FinalSubtitle = "Melhor de 3 · as vidas não contam mais",
		Matchup = "%s × %s · %s",
		ByeYou = "Sua dupla está de folga: assista do mirante",
		ByeOther = "Folga: %s",
		Fight = "VALENDO!",
		DuelWon = "VOCÊS VENCERAM O DUELO",
		DuelLost = "VOCÊS PERDERAM O DUELO",
		DuelTie = "EMPATE · ninguém perde vida",
		TeamEliminated = "%s eliminada",
		ChampionTitle = "CAMPEÃ: %s",
		YouAreChampion = "VOCÊS SÃO OS CAMPEÕES!",
		PartnerLeft = "Seu parceiro saiu. Você segue sozinho.",
		Spectating = "Assistindo: %s",
		OnMirante = "Mirante",
		WaitingStart = "Aguardando início · %d s",
		ZoneClosing = "A zona está fechando",
		OutsideZone = "FORA DA ZONA",
		Scoreboard = "PLACAR",
		Placement = "%dº lugar",
		Wins = "%d vitória(s)",
		AfkWarning = "Você está parado. Mexa-se, senão volta ao lobby em %d s.",
		AfkKick = "Você ficou parado por muito tempo na partida.",
		-- Modal de preparação (T2, versão simples)
		StepCard = "CARTA",
		StepPrimary = "PRIMÁRIA",
		StepSecondary = "SECUNDÁRIA",
		CardPlaceholder = "As cartas chegam em breve.",
		UltLocked = "Libera na %dª rodada",
		YourCard = "Sua carta: —",
		PartnerChoosing = "Parceiro (%s): escolhendo…",
		PartnerChoice = "Parceiro (%s): %s",
		PartnerConfirmed = "%s ✓",
		NoPartner = "Sem parceiro nesta partida",
		RepeatLast = "REPETIR ÚLTIMA",
		Confirm = "CONFIRMAR",
		StatDamage = "Dano",
		StatFireRate = "Cadência",
		StatRange = "Alcance",
		-- Equipe eliminada e fim (GDD 4.8)
		EliminatedTitle = "SUA DUPLA FOI ELIMINADA",
		Watch = "ASSISTIR",
		NewMatch = "NOVA PARTIDA",
		PartnerQuestion = "Ir para a próxima partida com %s?",
		Yes = "SIM",
		No = "NÃO",
		WaitingPartner = "Esperando a resposta de %s…",
		GoingToLobby = "Voltando ao lobby…",
		EndTitle = "FIM DA PARTIDA",
		EndPlacement = "Sua dupla ficou em %dº lugar",
		BackToLobbyIn = "Voltando ao lobby em %d s",
		Notices = {
			TeleportStudio = "O teleporte não funciona no Studio. A partida recomeça aqui.",
			TeleportFailed = "Não foi possível voltar ao lobby agora. Tente de novo.",
			Watching = "Você está assistindo do mirante.",
		} :: { [string]: string },
	},

	-- Painel de teste (só aparece no ambiente DEV_)
	Dev = {
		ToggleButton = "TESTE",
		PanelTitle = "TELEPORTE DE TESTE",
		CurrentPlace = "Você está em: %s",
		UnknownPlace = "place não configurado",
		GoTo = "IR PARA %s",
		Close = "FECHAR",
		GamepadHint = "↑",
		Results = {
			Sent = "Teleportando…",
			NotDev = "Teleporte de teste desligado neste ambiente.",
			Studio = "Teleporte não funciona dentro do Studio. Teste no jogo publicado.",
			NotConfigured = "Esse place ainda não tem ID em PlaceConfig.",
			SamePlace = "Você já está nesse place.",
			Cooldown = "Espere alguns segundos e tente de novo.",
			Invalid = "Pedido inválido.",
			Failed = "O teleporte falhou. Tente de novo.",
		} :: { [string]: string },

		-- Seção de dados do painel (F1)
		DataTitle = "DADOS DO JOGADOR",
		DataLoading = "Perfil carregando…",
		DataSummary = "Moedas: %d · Tutorial: %s\nSensibilidade: toque %.1f · mouse %.1f · controle %.1f",
		TutorialDone = "feito",
		TutorialPending = "pendente",
		AddCoins = "+%d MOEDAS",
		SensitivityUp = "SENSIBILIDADE +%.1f",
		SendInvalid = "ENVIAR CONFIG INVÁLIDA",
		ShowProfile = "VER PERFIL",
		ResetProfile = "RESETAR PERFIL",
		ResetConfirm = "TOQUE DE NOVO PARA CONFIRMAR",
		InvalidDetail = "%s (motivo: %s)",
		-- Seção de combate do painel (F2, só no place Partida)
		CombatTitle = "COMBATE",
		CombatInfo = "Dupla: %s · Abates: %d",
		WeaponsTitle = "ESCOLHER ARMA",
		SwitchTeam = "TROCAR DE DUPLA",
		Heal = "VIDA E ESCUDO CHEIOS",
		DummiesMoving = "ALVOS: ANDANDO",
		DummiesStill = "ALVOS: PARADOS",
		ExploitTest = "TESTE: ATIRAR RÁPIDO DEMAIS",
		KnockReport = "%s derrubado em %.2f s com %d tiros (%s)",
		CombatResults = {
			WeaponSet = "Arma equipada.",
			TeamSet = "Dupla trocada.",
			Healed = "Vida e escudo cheios.",
			DummiesToggled = "Alvos atualizados.",
			ExploitResult = "Teste de cadência:",
			ExploitDone = "Servidor aceitou %d de %d tiros enviados de uma vez (a cadência permite %d).",
			NotAlive = "Espere aparecer de novo.",
			TestArenaOnly = "Só na arena de teste (desligada durante a partida).",
			Invalid = "Comando inválido.",
		} :: { [string]: string },

		-- Seção da partida (F3, só no place Partida)
		MatchTitle = "PARTIDA (TESTE)",
		MatchInfo = "Etapa: %s · Rodada %d · Jogadores de teste: %d",
		StartNow = "COMEÇAR AGORA",
		SkipRound = "PULAR RODADA",
		RemoveLife = "TIRAR 1 VIDA DE…",
		ForceVirada = "FORÇAR VIRADA",
		AddBot = "+1 JOGADOR DE TESTE",
		AddBots = "+%d JOGADORES DE TESTE",
		ClearBots = "TIRAR JOGADORES DE TESTE",
		RestartMatch = "RECOMEÇAR PARTIDA",
		BotName = "Teste %d",
		MatchPhases = {
			Receiving = "Recebendo jogadores",
			Forming = "Formando duplas",
			Draw = "Sorteio",
			Prep = "Preparação",
			Combat = "Combate",
			RoundEnd = "Fim da rodada",
			Champion = "Campeã",
			EndScreen = "Tela final",
		} :: { [string]: string },
		MatchResults = {
			Started = "Partida começando.",
			NotEnough = "Jogadores insuficientes.",
			Skipped = "Rodada encerrada.",
			LifeRemoved = "Vida removida:",
			LifeQueued = "A vida sai no fim desta rodada:",
			ViradaForced = "A próxima rodada será a Virada.",
			ViradaRefused = "A Virada já aconteceu (ou é a final).",
			BotsAdded = "Jogadores de teste adicionados.",
			BotsCleared = "Jogadores de teste removidos.",
			Restarted = "Partida recomeçando.",
			WrongPhase = "Não dá nesta etapa da partida.",
			Invalid = "Comando inválido.",
		} :: { [string]: string },

		DataResults = {
			CoinsAdded = "Moedas adicionadas.",
			ProfileReset = "Perfil resetado.",
			ProfileShown = "Perfil completo no Output do servidor.",
			NotLoaded = "O perfil ainda não carregou.",
			Invalid = "Comando inválido.",
		} :: { [string]: string },
	},
}

return Strings
