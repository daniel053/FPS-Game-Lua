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
		TouchLookRadiansPerPixel = 0.006, -- arrastar o dedo no botão ATIRAR também gira a câmera
	},

	-- Botões de toque (GDD 13.1): centro de cada botão em pixels a partir do canto inferior direito.
	-- Ficam em volta do botão de pulo do Roblox. Tela pequena = menor lado da tela abaixo de 500 px.
	-- O editor de posição dos botões (settings.mobileLayout) é da F7.
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
		},
		Large = {
			FireSize = 110,
			ButtonSize = 80,
			Fire = Vector2.new(-110, -290),
			Aim = Vector2.new(-110, -405),
			Switch = Vector2.new(-240, -260),
			Reload = Vector2.new(-240, -140),
			AmmoRightMargin = 300,
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

	-- Contornos (GDD 7.6) [DECIDIDO]
	Outline = {
		PartnerCheckSeconds = 0.1, -- frequência da checagem "corpo inteiro escondido"
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
		Offsets = {
			Pistol = Vector3.new(0.7, -0.7, -1.3),
			SMG = Vector3.new(0.85, -0.8, -1.45),
			Shotgun = Vector3.new(0.9, -0.85, -1.55),
			LightRifle = Vector3.new(0.9, -0.85, -1.6),
			Rifle = Vector3.new(0.9, -0.85, -1.6),
			MachineGun = Vector3.new(1.0, -0.95, -1.6),
			Sniper = Vector3.new(0.85, -0.9, -1.7),
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
	},

	-- Arena de teste cinza da F2 (substituída pelas ilhas na F3)
	TestArena = {
		Enabled = true,
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
