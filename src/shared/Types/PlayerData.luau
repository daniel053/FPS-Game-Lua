--!strict
-- Contrato do perfil salvo do jogador (docs/DADOS-JOGADOR.md seção 3.1).
-- Os nomes de campo são EXATAMENTE os do documento. Mudou o formato: nova migração (seção 7).
-- Valores padrão: src/shared/Config/DefaultProfile.luau.

local Types = require(script.Parent)

export type CardId = string -- ex.: "card_nuvem"
export type WeaponId = string -- ex.: "weapon_rajada"
export type SkinId = string -- ex.: "skin_rajada_laranja"
export type CardKey = Types.CardKey
export type Rarity = Types.Rarity

export type CardSource = "tutorial" | "spin" | "shop" | "event" | "admin"
export type SkinSource = "shop_coins" | "shop_robux" | "reward" | "event" | "admin"

export type OwnedCard = {
	acquiredAt: number, -- os.time() de quando ganhou
	source: CardSource,
}

export type OwnedSkin = {
	acquiredAt: number,
	source: SkinSource,
}

export type CrosshairShape = "dot" | "cross" | "circle" | "cross_dot"

export type CrosshairSettings = {
	shape: CrosshairShape,
	color: string, -- hex, ex.: "#FFFFFF"
	size: number, -- 1 a 10
	thickness: number, -- 1 a 5
	gap: number, -- 0 a 10
	outline: boolean,
	outlineOpacity: number, -- 0 a 1
}

export type SensitivitySettings = {
	touch: number, -- 0.1 a 5.0
	mouse: number,
	gamepad: number,
	scopedMultiplier: number, -- multiplicador quando a mira de sniper está aberta
}

export type MobileButtonPlacement = { x: number, y: number, scale: number }

export type MobileButtonLayout = {
	[string]: MobileButtonPlacement, -- posição relativa (0 a 1) e escala
}

export type EnemyOutlineColor = "red" | "yellow" | "magenta"

export type MinimapSize = "small" | "medium" | "large"

export type AudioSettings = { master: number, sfx: number, music: number, voice: number } -- 0 a 1

export type Settings = {
	sensitivity: SensitivitySettings,
	crosshair: CrosshairSettings,
	autoFire: boolean, -- só tem efeito no toque
	aimAssist: boolean, -- toque e controle
	enemyOutlineColor: EnemyOutlineColor,
	uiScale: number, -- 1.0, 1.15 ou 1.3
	minimapSize: MinimapSize, -- tamanho do minimapa da partida
	reduceEffects: boolean,
	audio: AudioSettings,
	mobileLayout: MobileButtonLayout?, -- nil = layout padrão
	voicePromptSeen: boolean, -- já viu a tela de voz do tutorial
}

export type RankData = {
	points: number, -- pontos de elo (PE)
	matchesPlayed: number, -- partidas ranqueadas jogadas
	peakPoints: number, -- maior PE já alcançado
	seasonId: number, -- temporada atual [ABERTO: existirá temporada?] — fica 1
}

export type Stats = {
	matchesPlayed: number,
	matchesWon: number,
	podiums: number, -- 1º, 2º ou 3º
	roundsPlayed: number,
	roundsWon: number,
	kills: number,
	deaths: number,
	damageDealt: number,
	viradasWon: number, -- Rodadas da Virada vencidas
	soloRoundsWon: number, -- rodadas vencidas jogando 1v2
	killsByWeapon: { [WeaponId]: number },
}

export type LoadoutMemory = {
	lastCard: CardId?, -- carta escolhida na última partida
	lastPrimaryByPhase: { [string]: WeaponId }, -- "medias" / "pesadas"
	lastSecondary: WeaponId?,
}

export type RecentPartner = { userId: number, at: number }

export type Social = {
	praisesReceived: number,
	equippedTitle: string?,
	recentPartners: { RecentPartner }, -- últimos 10, para sugerir "jogar de novo"
}

export type Daily = {
	lastFirstWinDay: number?, -- dia (UTC) da última "primeira vitória do dia"
	lastFreeSpinDay: number?, -- dia (UTC) do último giro grátis [depende de GDD 8.9]
	loginStreak: number,
	lastLoginDay: number?,
}

export type Moderation = {
	warnings: number,
	lastWarningAt: number?,
}

export type EquippedCosmetics = {
	weapons: { [WeaponId]: SkinId }, -- arma sem entrada = skin padrão
	melee: SkinId?,
	body: SkinId?,
	head: SkinId?,
	victoryEffect: SkinId?,
	emotes: { SkinId }, -- até 4
}

export type Profile = {
	schemaVersion: number,
	createdAt: number,
	lastLoginAt: number,
	lastSaveAt: number,

	tutorialDone: boolean,
	tutorialStep: number, -- etapa em que parou, para retomar se sair no meio

	coins: number,
	gems: number, -- [ABERTO] segunda moeda; fica 0 até ser decidida

	cards: {
		owned: { [CardId]: OwnedCard },
		-- regra: no máximo 1 carta por tecla; validado pelo servidor
	},

	cosmetics: {
		owned: { [SkinId]: OwnedSkin },
		equipped: EquippedCosmetics,
	},

	loadout: LoadoutMemory,
	settings: Settings,
	rank: RankData,
	stats: Stats,
	social: Social,
	daily: Daily,
	moderation: Moderation,

	flags: { [string]: boolean }, -- marcadores diversos (ex.: "seen_spin_intro")
}

return {}
