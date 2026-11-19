--!strict
-- Combate: validação no servidor, hitbox, controles, assistência de mira, efeitos e arena de teste (F2).
-- Números das armas ficam em WeaponConfig; saúde e movimento em CharacterConfig.
-- Tudo aqui é [PROPOSTA] (ajustar em teste), salvo onde estiver marcado.

local CombatConfig = {
	-- Fogo amigo [DECIDIDO]: o tiro do parceiro não causa dano.
	FriendlyFire = false,

	-- Aviso de abate "N KILL" [DECIDIDO]: conta os abates do jogador na PARTIDA inteira (GDD 7.7).
	-- Na arena de teste da F2 (sem partida), conta desde que o jogador entrou no servidor.
	KillNotice = {
		Seconds = 2.5,
	},

	-- Hitbox única em forma de cápsula, igual para todos, sem região de cabeça (GDD 3.2) [DECIDIDO].
	Hitbox = {
		Radius = 1.1,
		Height = 5.2,
	},

	-- Validação dos pedidos do cliente (GDD 16.6). O cliente manda o horário do tiro em tempo do servidor
	-- (workspace:GetServerTimeNow); o servidor só aceita horários dentro desta janela e em ordem.
	Validation = {
		MaxPastSeconds = 0.5, -- tiro com horário mais antigo que isto é recusado
		MaxFutureSeconds = 0.1, -- horário no futuro (relógio adiantado) é recusado
		TimingSlackSeconds = 0.01, -- folga de arredondamento na cadência
		MaxOriginDistance = 8, -- origem do tiro até a cabeça do personagem no servidor
		HitPositionTolerance = 6, -- ponto de acerto até a hitbox no servidor (atraso de rede)
		MeleeRangeTolerance = 2,
		ActionsPerSecond = 40, -- limite de pedidos por segundo (tiros, trocas, recargas)
	},

	-- Proteção ao aparecer (MapConfig.General.BaseSpawnProtectionSeconds vale para a base dos mapas)
	SpawnProtectionSeconds = 3,

	-- Controles (GDD 7.2.6 e 13.1)
	Input = {
		GamepadSwitchHoldSeconds = 0.35, -- controle: tocar Y alterna 1/2; segurar Y pega o corpo a corpo
		TouchSwitchHoldSeconds = 0.4, -- celular: segurar o botão de troca abre as 3 opções
		TouchCardDetailsHoldSeconds = 0.5, -- celular: segurar uma carta (menos a Nuvem) abre os detalhes
		TouchLookRadiansPerPixel = 0.006, -- arrastar o dedo no botão ATIRAR também gira a câmera
	},

	-- Botões de toque (GDD 13.1): centro de cada botão em pixels a partir do canto inferior direito.
	-- Ficam em volta do botão de pulo do Roblox. Tela pequena = menor lado da tela abaixo de 500 px.
	-- Posição e tamanho editáveis pelo jogador (settings.mobileLayout, F7): ver Shared/Ui/TouchLayout.
	TouchLayout = {
		LargeScreenMinSide = 500,
		Small = {
			FireSize = 88,
			ButtonSize = 64,
			Fire = Vector2.new(-75, -165),
			Aim = Vector2.new(-75, -255),
			Switch = Vector2.new(-175, -150),
			Reload = Vector2.new(-175, -60),
			AmmoRightMargin = 220, -- munição à esquerda dos botões
			-- Cartas (GDD 13.1): [Q] [E] [C] em linha ao lado da MIRA e [X] ao lado da recarga.
			-- Cada tecla sempre no mesmo lugar (GDD 8.3), mesmo que só apareçam as cartas da partida.
			CardSize = 64,
			Cards = {
				Q = Vector2.new(-307, -255),
				E = Vector2.new(-231, -255),
				C = Vector2.new(-155, -255),
				X = Vector2.new(-275, -60),
			} :: { [string]: Vector2 },
		},
		Large = {
			FireSize = 110,
			ButtonSize = 80,
			Fire = Vector2.new(-110, -290),
			Aim = Vector2.new(-110, -405),
			Switch = Vector2.new(-240, -260),
			Reload = Vector2.new(-240, -140),
			AmmoRightMargin = 300,
			CardSize = 80,
			Cards = {
				Q = Vector2.new(-389, -405),
				E = Vector2.new(-297, -405),
				C = Vector2.new(-205, -405),
				X = Vector2.new(-370, -140),
			} :: { [string]: Vector2 },
		},
		ButtonTransparency = 0.35, -- semitransparentes (guia, quadro 4)
	},

	-- Tiro automático no celular (GDD 7.2.6)
	AutoFire = {
		SniperDwellSeconds = 0.2, -- snipers: mira aberta e retícula sobre o inimigo por este tempo
		SpinUpConeDegrees = 12, -- metralhadoras começam a aquecer com o inimigo dentro deste cone
	},

	-- Assistência de mira leve para toque e controle; desligada no mouse (GDD 7.2.6)
	AimAssist = {
		ConeDegrees = 5, -- inimigo dentro deste cone em volta da retícula
		MaxDistance = 150,
		Friction = 0.6, -- multiplica a sensibilidade com a retícula perto do inimigo
		PullDegreesPerSecond = 4, -- puxa a mira devagar para o inimigo, só enquanto o jogador se mexe
	},

	-- Marcação de aliado e inimigo (GDD 7.6) [DECIDIDO]; números [PROPOSTA]. Cores no Theme.Marker.
	Markers = {
		CheckSeconds = 0.1, -- frequência da checagem de visibilidade (raios até 6 pontos do corpo)
		EnemyPulseSeconds = 1.2, -- ciclo do pulso do contorno do inimigo (devagar; sem pulso com "reduzir efeitos")
		EnemyOutlineTransparencyMin = 0, -- contorno do inimigo: varia entre estes dois valores
		EnemyOutlineTransparencyMax = 0.45,
		EnemyFillTransparency = 0.82, -- leve brilho vermelho por cima do corpo
		AllySilhouetteFillTransparency = 0.35, -- silhueta verde do aliado atrás da parede
		BarWidth = 64, -- barra sobre a cabeça, em pixels (tamanho fixo na tela)
		BarHeight = 7,
		ShieldLineHeight = 3, -- linha fina do escudo, em cima da barra
		BarGap = 2, -- espaço entre a linha do escudo e a barra
		BarOffsetStuds = 1.4, -- acima do topo da cabeça
		BarMaxDistance = 300, -- além disso, a barra some (studs)
	},

	-- Movimento ao andar (para espalhamento): velocidade acima disto conta como "andando"
	MovingSpeedThreshold = 2,

	-- Efeitos (GDD 7.7). Sem sangue; faíscas neutras.
	Effects = {
		TracerSeconds = 0.06,
		TracerWidth = 0.08,
		SubtleTracerTransparency = 0.85,
		TracerTransparency = 0.35,
		MuzzleFlashSeconds = 0.05,
		HitSparkCount = 4,
		HitSparkSeconds = 0.25,
		DamageNumberSeconds = 0.8,
		DamageNumberRise = 2.5,
		HitMarkerSeconds = 0.15,
		KnockdownParticles = 24,
		KnockdownSeconds = 1.2,
		ReducedEffectsScale = 0.4, -- "Reduzir efeitos" multiplica partículas e balanço da arma
	},

	-- Arma em primeira pessoa (guia-arma-primeira-pessoa.png) [PROPOSTA]
	-- Deslocamento do modelo em studs (direita, cima, frente) em relação à câmera.
	ViewModel = {
		-- Posição de cada categoria em relação à câmera (direita, cima, frente). Partiu da tabela do guia
		-- e foi ajustada na F10 para os modelos detalhados (mais compridos que os do guia) caberem no
		-- quadro sem encolher: mais para a direita e, nos fuzis e snipers, mais baixo e mais perto.
		Offsets = {
			Pistol = Vector3.new(0.85, -0.7, -1.3),
			SMG = Vector3.new(0.85, -0.8, -1.45),
			Shotgun = Vector3.new(0.95, -0.85, -1.55),
			LightRifle = Vector3.new(1.2, -1.0, -1.4),
			Rifle = Vector3.new(1.1, -0.85, -1.55),
			MachineGun = Vector3.new(1.1, -0.95, -1.6),
			Sniper = Vector3.new(1.15, -1.0, -1.5),
			Melee = Vector3.new(0.8, -0.8, -1.2),
		} :: { [string]: Vector3 },
		TouchScale = 0.9, -- celular: arma 10% menor...
		TouchExtraDown = -0.1, -- ...e mais baixa
		BobAmount = 0.04, -- balanço ao andar (studs)
		BobSpeed = 9,
		KickBack = 0.12, -- recuo visual do modelo por tiro (studs)
		KickRecovery = 12,
		WallCheckDistance = 3, -- perto de parede, a arma abaixa
		WallLowerAngle = 35, -- graus
		ReloadDipAngle = 25,
		-- Regras de enquadramento do guia (F10), numa tela de referência 16:9; posições de 0 a 1, da
		-- esquerda e de cima. A arma que não cabe fica menor (ViewModelFit). [PROPOSTA]
		Frame = {
			RefAspect = 16 / 9,
			MuzzleMinX = 0.6, -- ponta do cano: até 60% da largura (o guia pede ~61-62%; o centro livre manda)...
			MuzzleMinY = 0.6, -- ...e nunca acima de 60% da altura
			ZoneMinX = 0.58, -- ZONA DA ARMA: de 58% a 100% da largura...
			ZoneMinY = 0.52, -- ...e de 52% a 100% da altura
			CenterRadius = 0.2, -- CENTRO LIVRE: raio de 20% da altura em volta da retícula
			MinScale = 0.8,
			ScaleStep = 0.02,
		},
	},

	-- Arena de teste cinza da F2. Desligada na F3: o servidor monta o mirante e as 4 ilhas e roda a
	-- partida (MatchService). true = volta a arena de teste, sem partida (para testar só o combate).
	TestArena = {
		Enabled = false,
		RespawnSeconds = 3,
		DummyRespawnSeconds = 2,
		DummyStrafeDistance = 8, -- alvos que andam de um lado para o outro
		DummyStrafeSpeed = 10,
		-- Arma inicial de quem entra (o painel TESTE troca)
		DefaultPrimary = "weapon_rajada",
		DefaultSecondary = "weapon_bolinha",
	},
}

return CombatConfig
