--!strict
-- Valores padrão do perfil novo (docs/DADOS-JOGADOR.md seção 3.2).
-- Também servem para completar campos ausentes ao carregar (seção 5.1, passo 4).

local PlayerData = require(script.Parent.Parent.Types.PlayerData)

local DefaultProfile = {}

-- Versão atual do esquema. Mudou o formato do perfil: subir este número e criar a migração.
DefaultProfile.SchemaVersion = 1

-- Perfil novo completo. `now` = os.time() do momento da criação.
function DefaultProfile.new(now: number): PlayerData.Profile
	return {
		schemaVersion = DefaultProfile.SchemaVersion,
		createdAt = now,
		lastLoginAt = now,
		lastSaveAt = 0,

		tutorialDone = false,
		tutorialStep = 0,

		coins = 0,
		gems = 0,

		cards = { owned = {} }, -- as 4 cartas iniciais são dadas ao terminar o tutorial

		cosmetics = {
			owned = {},
			equipped = { weapons = {}, melee = nil, body = nil, head = nil, victoryEffect = nil, emotes = {} },
		},

		loadout = { lastCard = nil, lastPrimaryByPhase = {}, lastSecondary = nil },

		settings = DefaultProfile.settings(),

		rank = { points = 0, matchesPlayed = 0, peakPoints = 0, seasonId = 1 },

		stats = {
			matchesPlayed = 0,
			matchesWon = 0,
			podiums = 0,
			roundsPlayed = 0,
			roundsWon = 0,
			kills = 0,
			deaths = 0,
			damageDealt = 0,
			viradasWon = 0,
			soloRoundsWon = 0,
			killsByWeapon = {},
		},

		social = { praisesReceived = 0, equippedTitle = nil, recentPartners = {} },
		daily = { lastFirstWinDay = nil, lastFreeSpinDay = nil, loginStreak = 0, lastLoginDay = nil },
		moderation = { warnings = 0, lastWarningAt = nil },
		flags = {},
	}
end

-- Configurações padrão (usadas também quando um valor salvo é inválido).
function DefaultProfile.settings(): PlayerData.Settings
	return {
		sensitivity = { touch = 1.0, mouse = 1.0, gamepad = 1.0, scopedMultiplier = 0.8 },
		crosshair = {
			shape = "cross",
			color = "#FFFFFF",
			size = 4,
			thickness = 2,
			gap = 3,
			outline = true,
			outlineOpacity = 0.6,
		},
		autoFire = true,
		aimAssist = true,
		enemyOutlineColor = "red",
		uiScale = 1.0,
		reduceEffects = false,
		audio = { master = 1, sfx = 1, music = 0.6, voice = 1 },
		mobileLayout = nil,
		voicePromptSeen = false,
	}
end

return DefaultProfile
