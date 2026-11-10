--!strict
-- Tutorial (GDD 5) [DECIDIDO]; números [PROPOSTA]. Duração alvo: 3 a 5 minutos.
-- As 8 etapas, as tarefas de cada uma e o tamanho da arena cinza do tutorial.

-- "Welcome" | "Movement" | "Weapons" | "Cards" | "Voice" | "Sensitivity" | "Crosshair" | "Final".
-- Guardado como string: o verificador de tipos perde a união ao ler de tabelas (como CardKey, F4).
export type StepId = string

-- Uma tarefa que o servidor confere.
--   Knock    = derrubar `count` alvos com a arma da lição
--   Reload   = recarregar
--   Equip    = sacar a arma do espaço `slot`
--   Alt      = abrir a mira / ligar o modo alternativo
export type WeaponTask = {
	kind: "Knock" | "Reload" | "Equip" | "Alt",
	count: number?,
	slot: string?, -- "primary" | "secondary" (Equip)
}

export type WeaponLesson = {
	primary: string?, -- nil = só a pistola
	secondary: string,
	tip: string, -- chave em Strings.Tutorial.WeaponTips
	tasks: { WeaponTask },
	sniperRange: boolean?, -- alvos longe (sniper)
}

local TutorialConfig = {
	-- Ordem das etapas (GDD 5.2). O número da etapa (1 a 8) é o que vai em profile.tutorialStep.
	Steps = { "Welcome", "Movement", "Weapons", "Cards", "Voice", "Sensitivity", "Crosshair", "Final" } :: { StepId },

	-- Pular: só as configurações [DECIDIDO] (F6). Pular mantém os valores atuais (padrão).
	SkippableSteps = { Voice = true, Sensitivity = true, Crosshair = true } :: { [string]: boolean },

	-- Movimento: olhar para os marcadores, andar até o círculo, pular na caixa.
	Movement = {
		LookMarkers = 3,
		LookConeDegrees = 12, -- olhar "para" o marcador: centro da tela até este ângulo
		WalkRadius = 4, -- chegou ao círculo (studs, distância no chão)
		BoxHeight = 3, -- caixa para pular (o pulo do Roblox sobe ~7 studs)
	},

	-- Armas: uma de cada categoria (GDD 5.2), na ordem. Cada lição ensina uma coisa.
	WeaponLessons = {
		{ primary = nil, secondary = "weapon_bolinha", tip = "Shoot", tasks = { { kind = "Knock", count = 2 } } },
		{
			primary = "weapon_ferrao",
			secondary = "weapon_bolinha",
			tip = "Reload",
			tasks = { { kind = "Knock", count = 1 }, { kind = "Reload" } },
		},
		{
			primary = "weapon_balde",
			secondary = "weapon_bolinha",
			tip = "Swap",
			tasks = {
				{ kind = "Equip", slot = "secondary" },
				{ kind = "Equip", slot = "primary" },
				{ kind = "Knock", count = 1 },
			},
		},
		{
			primary = "weapon_tatico",
			secondary = "weapon_bolinha",
			tip = "Alt",
			tasks = { { kind = "Alt" }, { kind = "Knock", count = 1 } },
		},
		{
			primary = "weapon_luneta",
			secondary = "weapon_bolinha",
			tip = "Scope",
			sniperRange = true,
			tasks = { { kind = "Alt" }, { kind = "Knock", count = 1 } },
		},
		{
			primary = "weapon_martelo",
			secondary = "weapon_bolinha",
			tip = "MachineGun",
			tasks = { { kind = "Knock", count = 1 } },
		},
	} :: { WeaponLesson },

	-- Cartas: uma por vez, nesta ordem. Ao completar o desafio, a carta entra na coleção.
	CardOrder = { "card_impulso", "card_nuvem", "card_tremor", "card_renascer" },
	Cards = {
		ImpulsoPlatformHeight = 13, -- alta demais para o pulo normal; o Impulso sobe ~18
		ImpulsoPlatformSize = 10,
		NuvemCircleRadius = 7, -- a nuvem tem que cair dentro deste círculo
		NuvemCircleDistance = 18, -- à frente de onde o jogador começa (arremesso reto cai a ~15 studs)
		TremorTargets = 2, -- alvos para atingir com a onda
		TremorTargetDistance = 10,
		RenascerPadDamage = 999, -- a área de perigo derruba (só com o Renascer ativo)
		RenascerPadDistance = 14,
		RetryAfterUseSeconds = 4, -- usou a carta e o desafio não terminou: espera isto...
		RetrySeconds = 1.5, -- ...e mais isto para devolver as cargas (tentar de novo sem esperar a recarga)
	},

	-- Sensibilidade e retícula: alvos andando na frente do jogador; sniper para a mira aberta.
	Settings = {
		Weapon = "weapon_luneta",
		Secondary = "weapon_bolinha",
		MovingTargets = 3,
	},

	-- Alvos (bonecos parados, inimigos de todos, com contorno e barra vermelhos)
	Targets = {
		RespawnSeconds = 1.2,
		MoveSpeed = 0.7, -- alvos que andam (ciclos por segundo, em seno)
		MoveAmplitude = 8, -- studs para cada lado
		Distances = { 14, 22, 30 }, -- estande das armas (studs à frente)
		SniperDistances = { 55, 70 },
	},

	-- O jogador do tutorial é de uma dupla de mentira; os alvos são do time "Alvo".
	PlayerTeam = "Azul",

	-- Caiu no vazio ou foi derrubado: volta à estação depois disto.
	RespawnSeconds = 1,

	-- Pedidos do cliente (TutorialRequest): no máximo isto por segundo.
	RequestsPerSecond = 8,

	-- Arena cinza do tutorial, montada por código (nada salvo no place)
	World = {
		Origin = Vector3.new(0, 200, 0), -- longe do Baseplate padrão do place
		StationSpacing = 140, -- distância entre as estações
		StationSize = Vector3.new(90, 1, 90),
		WallHeight = 14,
	},
}

return TutorialConfig
