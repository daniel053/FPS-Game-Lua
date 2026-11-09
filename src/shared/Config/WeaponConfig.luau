--!strict
-- Armas (GDD seção 7.2). Os nomes exibidos ficam em Strings.Weapons (por ID).
-- Números da tabela 7.2.3 [PROPOSTA]: ajustar aqui depois dos testes, nunca no código.
--
-- Unidades: distâncias em studs, ângulos em GRAUS, tempos em segundos, cadência em tiros por segundo.
-- Escopetas: `pellets` = número de bagos, `damage` = dano de CADA bago.
-- `referenceShotsToKill` e `referenceTimeToKill` vêm da tabela do GDD e servem só para o teste
-- automático (tempo para derrubar com tolerância de ±10%). Não são usados no jogo.
--
-- Perda de dano, espalhamento e recuo (GDD 7.2.5) são [PROPOSTA] da F2, para ajustar em teste.

local Types = require(script.Parent.Parent.Types)

-- Perda de dano com a distância: dano cheio até `start`; cai em linha reta até `minMultiplier`
-- em `finish`; daí em diante fica em `minMultiplier`. Sem tabela = sem perda (Trovão e snipers).
export type Falloff = { start: number, finish: number, minMultiplier: number }

-- Espalhamento (graus, raio do cone em volta da retícula).
export type Spread = {
	hip: number, -- parado, sem mira
	moving: number, -- somado ao andar ou pular
	alt: number?, -- substitui `hip` com o modo alternativo ligado (mira aberta, rajada ou bagos concentrados)
	bloomPerShot: number, -- somado a cada tiro seguido
	bloomMax: number,
	bloomRecovery: number, -- graus por segundo de volta a zero
}

-- Recuo simples e previsível (GDD 7.2.6): sobe `kick` graus por tiro e balança `sway` graus para os
-- lados, sempre no mesmo padrão. Ao parar de atirar, volta à mira original a `recovery` graus por segundo.
export type Recoil = { kick: number, sway: number, recovery: number }

-- Rajada do modo alternativo: `count` tiros a `rate` por segundo, depois `cooldown` até a próxima rajada.
export type Burst = { count: number, rate: number, cooldown: number }

-- Atravessar coberturas finas (Moedor).
export type Penetration = { maxThickness: number, damageMultiplier: number }

export type TracerStyle = "Normal" | "Subtle"

export type WeaponDef = {
	id: string,
	category: Types.WeaponCategory,
	slot: Types.WeaponSlot,
	fireMode: Types.FireMode,
	altMode: Types.AltMode?,
	damage: number,
	pellets: number,
	fireRate: number, -- tiros por segundo
	magazine: number,
	reloadTime: number,
	burst: Burst?, -- modo alternativo "Burst" ou "ScopeBurst"
	spinUpTime: number?, -- metralhadoras: segurando o gatilho, o primeiro tiro sai depois deste tempo
	moveSpeedMultiplier: number?, -- com a arma na mão
	scopedMoveSpeedMultiplier: number?, -- com a mira aberta
	falloff: Falloff?,
	range: number, -- alcance máximo do tiro
	effectiveRange: number?, -- escopetas: tiro automático do celular só até aqui
	pelletSpread: number?, -- escopetas: cone dos bagos (graus)
	focusedPelletSpread: number?, -- escopetas com "FocusedPellets": cone com o modo alternativo
	spread: Spread,
	recoil: Recoil,
	scopeFieldOfView: number?, -- campo de visão com a mira aberta
	penetration: Penetration?,
	tracer: TracerStyle,
	autoFire: Types.AutoFireBehavior,
	referenceShotsToKill: number,
	referenceTimeToKill: number,
}

export type MeleeDef = {
	id: string,
	damage: number,
	swingsPerSecond: number,
	range: number, -- studs
	heavyDamage: number,
	heavyInterval: number, -- segundos entre golpes fortes
	moveSpeedMultiplier: number,
	touchHeavyHoldSeconds: number, -- celular: segurar ATIRAR por este tempo faz o golpe forte
}

export type WeaponPhase = {
	id: Types.WeaponPhaseId,
	fromRound: number,
	toRound: number?, -- nil = até o fim da partida
	primaries: { string },
}

local DEFAULT_RANGE = 300
local SHOTGUN_RANGE = 60

-- Ordem = ordem de exibição dentro de cada categoria.
local Weapons: { WeaponDef } = {
	-- Pistolas
	{
		id = "weapon_bolinha",
		category = "Pistol",
		slot = "secondary",
		fireMode = "Semi",
		altMode = "Burst",
		burst = { count = 3, rate = 12, cooldown = 0.55 },
		damage = 13,
		pellets = 1,
		fireRate = 4,
		magazine = 12,
		reloadTime = 1.75,
		falloff = { start = 20, finish = 50, minMultiplier = 0.7 },
		range = DEFAULT_RANGE,
		spread = { hip = 0.6, moving = 1.5, alt = 2.5, bloomPerShot = 0.4, bloomMax = 2.5, bloomRecovery = 6 },
		recoil = { kick = 0.6, sway = 0.15, recovery = 8 },
		tracer = "Normal",
		autoFire = "MaxRateOnTarget",
		referenceShotsToKill = 12,
		referenceTimeToKill = 2.8,
	},
	{
		id = "weapon_chumbinho",
		category = "Pistol",
		slot = "secondary",
		fireMode = "Semi",
		damage = 6,
		pellets = 12,
		fireRate = 1.3,
		magazine = 3,
		reloadTime = 1.75,
		falloff = { start = 6, finish = 15, minMultiplier = 0.25 }, -- de longe o dano quase some
		range = SHOTGUN_RANGE,
		effectiveRange = 8,
		pelletSpread = 7,
		spread = { hip = 0, moving = 1, bloomPerShot = 0, bloomMax = 0, bloomRecovery = 10 },
		recoil = { kick = 3, sway = 0.3, recovery = 10 },
		tracer = "Normal",
		autoFire = "InEffectiveRange",
		referenceShotsToKill = 3,
		referenceTimeToKill = 1.5,
	},
	{
		id = "weapon_zumbido",
		category = "Pistol",
		slot = "secondary",
		fireMode = "Auto",
		damage = 9,
		pellets = 1,
		fireRate = 10,
		magazine = 20,
		reloadTime = 1.6,
		falloff = { start = 15, finish = 40, minMultiplier = 0.6 }, -- fraca de longe
		range = DEFAULT_RANGE,
		spread = { hip = 1.2, moving = 1.5, bloomPerShot = 0.3, bloomMax = 3, bloomRecovery = 8 },
		recoil = { kick = 0.5, sway = 0.2, recovery = 10 },
		tracer = "Normal",
		autoFire = "WhileOnTarget",
		referenceShotsToKill = 17,
		referenceTimeToKill = 1.6,
	},
	{
		id = "weapon_precisa",
		category = "Pistol",
		slot = "secondary",
		fireMode = "Semi",
		damage = 15,
		pellets = 1,
		fireRate = 4.5,
		magazine = 15,
		reloadTime = 1.5,
		falloff = { start = 30, finish = 60, minMultiplier = 0.85 }, -- pouca perda (GDD 7.2.4)
		range = DEFAULT_RANGE,
		spread = { hip = 0.4, moving = 1.2, bloomPerShot = 0.35, bloomMax = 2, bloomRecovery = 6 },
		recoil = { kick = 0.7, sway = 0.15, recovery = 8 },
		tracer = "Normal",
		autoFire = "MaxRateOnTarget",
		referenceShotsToKill = 10,
		referenceTimeToKill = 2.0,
	},
	{
		id = "weapon_tambor",
		category = "Pistol",
		slot = "secondary",
		fireMode = "Semi",
		damage = 40,
		pellets = 1,
		fireRate = 1.6,
		magazine = 6,
		reloadTime = 2.25,
		falloff = { start = 30, finish = 60, minMultiplier = 0.75 },
		range = DEFAULT_RANGE,
		spread = { hip = 0.3, moving = 1.5, bloomPerShot = 1.2, bloomMax = 3, bloomRecovery = 5 }, -- recompensa calma
		recoil = { kick = 3, sway = 0.3, recovery = 8 },
		tracer = "Normal",
		autoFire = "MaxRateOnTarget",
		referenceShotsToKill = 4,
		referenceTimeToKill = 1.9,
	},

	-- Submetralhadoras
	{
		id = "weapon_ferrao",
		category = "SMG",
		slot = "primary",
		fireMode = "Auto",
		altMode = "Burst",
		burst = { count = 4, rate = 16, cooldown = 0.4 },
		damage = 8,
		pellets = 1,
		fireRate = 13,
		magazine = 25,
		reloadTime = 2.25,
		falloff = { start = 15, finish = 40, minMultiplier = 0.65 },
		range = DEFAULT_RANGE,
		-- espalha muito em movimento contínuo (GDD 7.2.4)
		spread = { hip = 0.9, moving = 1.0, alt = 0.8, bloomPerShot = 0.35, bloomMax = 5, bloomRecovery = 8 },
		recoil = { kick = 0.45, sway = 0.25, recovery = 10 },
		tracer = "Normal",
		autoFire = "WhileOnTarget",
		referenceShotsToKill = 19,
		referenceTimeToKill = 1.4,
	},
	{
		id = "weapon_vespa",
		category = "SMG",
		slot = "primary",
		fireMode = "Auto",
		damage = 9,
		pellets = 1,
		fireRate = 11,
		magazine = 30,
		reloadTime = 2.25,
		falloff = { start = 20, finish = 50, minMultiplier = 0.75 },
		range = DEFAULT_RANGE,
		-- atirar andando é preciso (GDD 7.2.4)
		spread = { hip = 0.7, moving = 0.3, bloomPerShot = 0.2, bloomMax = 2.5, bloomRecovery = 8 },
		recoil = { kick = 0.4, sway = 0.15, recovery = 10 },
		tracer = "Normal",
		autoFire = "WhileOnTarget",
		referenceShotsToKill = 17,
		referenceTimeToKill = 1.45,
	},

	-- Escopetas
	{
		id = "weapon_balde",
		category = "Shotgun",
		slot = "primary",
		fireMode = "Semi",
		altMode = "FocusedPellets",
		damage = 4,
		pellets = 15,
		fireRate = 1.1,
		magazine = 5,
		reloadTime = 2.5,
		falloff = { start = 8, finish = 20, minMultiplier = 0.3 },
		range = SHOTGUN_RANGE,
		effectiveRange = 12,
		pelletSpread = 5,
		focusedPelletSpread = 2.2, -- alcança um pouco mais longe
		spread = { hip = 0, moving = 1, bloomPerShot = 0, bloomMax = 0, bloomRecovery = 10 },
		recoil = { kick = 3.5, sway = 0.4, recovery = 9 },
		tracer = "Normal",
		autoFire = "InEffectiveRange",
		referenceShotsToKill = 3,
		referenceTimeToKill = 1.8,
	},
	{
		id = "weapon_varredor",
		category = "Shotgun",
		slot = "primary",
		fireMode = "Auto",
		damage = 3.5,
		pellets = 10,
		fireRate = 3,
		magazine = 7,
		reloadTime = 2.2,
		falloff = { start = 8, finish = 18, minMultiplier = 0.3 },
		range = SHOTGUN_RANGE,
		effectiveRange = 10,
		pelletSpread = 5.5,
		spread = { hip = 0, moving = 1, bloomPerShot = 0, bloomMax = 0, bloomRecovery = 10 },
		recoil = { kick = 1.8, sway = 0.3, recovery = 10 },
		tracer = "Normal",
		autoFire = "InEffectiveRange",
		referenceShotsToKill = 5,
		referenceTimeToKill = 1.35,
	},

	-- Fuzis leves
	{
		id = "weapon_tatico",
		category = "LightRifle",
		slot = "primary",
		fireMode = "Auto",
		altMode = "ScopeBurst",
		burst = { count = 3, rate = 15, cooldown = 0.35 },
		damage = 10,
		pellets = 1,
		fireRate = 9,
		magazine = 24,
		reloadTime = 2.5,
		falloff = { start = 40, finish = 80, minMultiplier = 0.85 },
		range = DEFAULT_RANGE,
		spread = { hip = 0.5, moving = 1.2, alt = 0.15, bloomPerShot = 0.25, bloomMax = 2.5, bloomRecovery = 8 },
		recoil = { kick = 0.45, sway = 0.15, recovery = 10 },
		scopeFieldOfView = 60,
		tracer = "Normal",
		autoFire = "WhileOnTarget",
		referenceShotsToKill = 15,
		referenceTimeToKill = 1.6,
	},
	{
		id = "weapon_atirador",
		category = "LightRifle",
		slot = "primary",
		fireMode = "Semi",
		altMode = "Scope",
		damage = 30,
		pellets = 1,
		fireRate = 2.8,
		magazine = 12,
		reloadTime = 2.5,
		falloff = { start = 50, finish = 100, minMultiplier = 0.9 },
		range = DEFAULT_RANGE,
		spread = { hip = 0.8, moving = 2, alt = 0.05, bloomPerShot = 0.5, bloomMax = 2, bloomRecovery = 6 },
		recoil = { kick = 1.4, sway = 0.15, recovery = 8 },
		scopeFieldOfView = 55,
		tracer = "Normal",
		autoFire = "MaxRateOnTarget",
		referenceShotsToKill = 5,
		referenceTimeToKill = 1.45,
	},

	-- Metralhadoras
	{
		id = "weapon_martelo",
		category = "MachineGun",
		slot = "primary",
		fireMode = "Auto",
		damage = 9,
		pellets = 1,
		fireRate = 11,
		magazine = 50,
		reloadTime = 3.25,
		spinUpTime = 0.5,
		moveSpeedMultiplier = 0.85, -- 15% mais lento
		falloff = { start = 30, finish = 60, minMultiplier = 0.8 },
		range = DEFAULT_RANGE,
		spread = { hip = 1.2, moving = 1.5, bloomPerShot = 0.1, bloomMax = 2, bloomRecovery = 6 },
		recoil = { kick = 0.35, sway = 0.25, recovery = 8 },
		tracer = "Normal",
		autoFire = "SpinUpNearTarget",
		referenceShotsToKill = 17,
		referenceTimeToKill = 2.0,
	},
	{
		id = "weapon_moedor",
		category = "MachineGun",
		slot = "primary",
		fireMode = "Auto",
		damage = 9,
		pellets = 1,
		fireRate = 12,
		magazine = 100,
		reloadTime = 5.0,
		spinUpTime = 1.0,
		moveSpeedMultiplier = 0.8, -- 20% mais lento
		falloff = { start = 30, finish = 60, minMultiplier = 0.8 },
		range = DEFAULT_RANGE,
		spread = { hip = 1.4, moving = 1.5, bloomPerShot = 0.08, bloomMax = 2.2, bloomRecovery = 6 },
		recoil = { kick = 0.3, sway = 0.25, recovery = 8 },
		penetration = { maxThickness = 1.5, damageMultiplier = 0.5 }, -- coberturas finas, dano reduzido
		tracer = "Normal",
		autoFire = "SpinUpNearTarget",
		referenceShotsToKill = 17,
		referenceTimeToKill = 2.4,
	},

	-- Fuzis
	{
		id = "weapon_rajada",
		category = "Rifle",
		slot = "primary",
		fireMode = "Auto",
		damage = 11,
		pellets = 1,
		fireRate = 9,
		magazine = 30,
		reloadTime = 2.5,
		falloff = { start = 30, finish = 60, minMultiplier = 0.85 }, -- perde um pouco de longe
		range = DEFAULT_RANGE,
		spread = { hip = 0.25, moving = 1.2, bloomPerShot = 0.15, bloomMax = 1.8, bloomRecovery = 8 },
		recoil = { kick = 0.35, sway = 0.1, recovery = 10 }, -- pouco recuo
		tracer = "Subtle", -- difícil saber de onde vem
		autoFire = "WhileOnTarget",
		referenceShotsToKill = 14,
		referenceTimeToKill = 1.45,
	},
	{
		id = "weapon_trovao",
		category = "Rifle",
		slot = "primary",
		fireMode = "Auto",
		damage = 16,
		pellets = 1,
		fireRate = 6.5,
		magazine = 25,
		reloadTime = 2.5,
		falloff = nil, -- sem perda de dano com a distância
		range = DEFAULT_RANGE,
		spread = { hip = 0.25, moving = 1.4, bloomPerShot = 0.3, bloomMax = 3, bloomRecovery = 8 },
		recoil = { kick = 0.75, sway = 0.25, recovery = 8 }, -- recuo forte
		tracer = "Normal",
		autoFire = "WhileOnTarget",
		referenceShotsToKill = 10,
		referenceTimeToKill = 1.4,
	},

	-- Snipers (sem mira, o tiro espalha muito)
	{
		id = "weapon_matapato",
		category = "Sniper",
		slot = "primary",
		fireMode = "Bolt",
		altMode = "Scope",
		damage = 55,
		pellets = 1,
		fireRate = 1 / 1.1, -- 1 tiro a cada 1,1 s
		magazine = 5,
		reloadTime = 2.5,
		range = DEFAULT_RANGE,
		spread = { hip = 4, moving = 3, alt = 0.05, bloomPerShot = 0, bloomMax = 0, bloomRecovery = 10 },
		recoil = { kick = 3, sway = 0.2, recovery = 8 },
		scopeFieldOfView = 35,
		tracer = "Normal",
		autoFire = "ScopedOnTarget",
		referenceShotsToKill = 3,
		referenceTimeToKill = 2.2,
	},
	{
		id = "weapon_gemea",
		category = "Sniper",
		slot = "primary",
		fireMode = "Double",
		altMode = "Scope",
		damage = 70,
		pellets = 1,
		fireRate = 1 / 0.4, -- os 2 tiros saem em 0,4 s; depois precisa recarregar
		magazine = 2,
		reloadTime = 2.8,
		range = DEFAULT_RANGE,
		spread = { hip = 5, moving = 3, alt = 0.1, bloomPerShot = 0, bloomMax = 0, bloomRecovery = 10 },
		recoil = { kick = 3.5, sway = 0.3, recovery = 8 },
		scopeFieldOfView = 35,
		tracer = "Normal",
		autoFire = "ScopedOnTarget",
		referenceShotsToKill = 3,
		referenceTimeToKill = 3.2,
	},
	{
		id = "weapon_luneta",
		category = "Sniper",
		slot = "primary",
		fireMode = "Bolt",
		altMode = "Scope",
		damage = 135, -- maior dano possível de um tiro; nunca derruba vida cheia (150)
		pellets = 1,
		fireRate = 1 / 1.6, -- 1 tiro a cada 1,6 s
		magazine = 5,
		reloadTime = 3.7,
		scopedMoveSpeedMultiplier = 0.7, -- mirando, 30% mais lento [DECIDIDO]
		range = DEFAULT_RANGE,
		spread = { hip = 7, moving = 4, alt = 0, bloomPerShot = 0, bloomMax = 0, bloomRecovery = 10 },
		recoil = { kick = 4, sway = 0.2, recovery = 7 },
		scopeFieldOfView = 20,
		tracer = "Normal",
		autoFire = "ScopedOnTarget",
		referenceShotsToKill = 2,
		referenceTimeToKill = 1.6,
	},
}

-- Corpo a corpo (GDD 7.2.7) [PROPOSTA]
local Melee: MeleeDef = {
	id = "weapon_bastao",
	damage = 50,
	swingsPerSecond = 2,
	range = 4,
	heavyDamage = 75,
	heavyInterval = 1.2,
	moveSpeedMultiplier = 1.1, -- +10%
	touchHeavyHoldSeconds = 0.35,
}

-- Pistolas liberadas desde a 1ª rodada (GDD 7.2.2)
local BASE_PISTOLS = { "weapon_bolinha", "weapon_chumbinho", "weapon_zumbido", "weapon_precisa" }

local WeaponConfig = {
	Weapons = Weapons,
	Melee = Melee,

	-- Regra de segurança (GDD 7.2.1) [DECIDIDO]: nenhum tiro único pode passar disto.
	MaxSingleShotDamage = 135,

	-- Moedor e Gêmea entram na fase Pesadas [DECIDIDO] (GDD 7.2.2).
	-- false = só Rajada, Trovão e Luneta.
	HeavyIncludesMoedorAndGemea = true,

	-- O Tambor só fica disponível a partir desta rodada [PROPOSTA]
	TamborFromRound = 3,

	BasePistols = BASE_PISTOLS,

	-- Fases por rodada (GDD 7.2.2)
	Phases = {
		{ id = "pistolas", fromRound = 1, toRound = 2, primaries = {} },
		{
			id = "medias",
			fromRound = 3,
			toRound = 3,
			primaries = {
				"weapon_ferrao",
				"weapon_vespa",
				"weapon_balde",
				"weapon_varredor",
				"weapon_tatico",
				"weapon_atirador",
				"weapon_martelo",
				"weapon_matapato",
			},
		},
		{
			id = "pesadas",
			fromRound = 4,
			toRound = nil,
			primaries = { "weapon_rajada", "weapon_trovao", "weapon_moedor", "weapon_gemea", "weapon_luneta" },
		},
	} :: { WeaponPhase },

	-- Munição reserva infinita (GDD 7.2.5)
	InfiniteReserveAmmo = true,

	-- Tempo para sacar uma arma ao trocar [PROPOSTA]
	EquipTime = 0.35,
}

local byId: { [string]: WeaponDef } = {}
for _, weapon in Weapons do
	byId[weapon.id] = weapon
end

function WeaponConfig.get(id: string): WeaponDef?
	return byId[id]
end

function WeaponConfig.isValidId(id: string): boolean
	return byId[id] ~= nil or id == Melee.id
end

-- A arma tem mira (zoom)?
function WeaponConfig.hasScope(def: WeaponDef): boolean
	return def.altMode == "Scope" or def.altMode == "ScopeBurst"
end

-- A arma usa rajada no modo alternativo?
function WeaponConfig.hasBurst(def: WeaponDef): boolean
	return def.altMode == "Burst" or def.altMode == "ScopeBurst"
end

function WeaponConfig.getPhaseForRound(round: number): WeaponPhase
	for _, phase in WeaponConfig.Phases do
		if round >= phase.fromRound and (phase.toRound == nil or round <= phase.toRound) then
			return phase
		end
	end
	return WeaponConfig.Phases[#WeaponConfig.Phases]
end

-- Primárias que podem ser escolhidas nesta rodada (aplica a chave HeavyIncludesMoedorAndGemea).
function WeaponConfig.getPrimariesForRound(round: number): { string }
	local phase = WeaponConfig.getPhaseForRound(round)
	local result = {}
	for _, id in phase.primaries do
		local excluded = phase.id == "pesadas"
			and not WeaponConfig.HeavyIncludesMoedorAndGemea
			and (id == "weapon_moedor" or id == "weapon_gemea")
		if not excluded then
			table.insert(result, id)
		end
	end
	return result
end

-- Secundárias (pistolas) que podem ser escolhidas nesta rodada.
function WeaponConfig.getSecondariesForRound(round: number): { string }
	local result = table.clone(BASE_PISTOLS)
	if round >= WeaponConfig.TamborFromRound then
		table.insert(result, "weapon_tambor")
	end
	return result
end

return WeaponConfig
