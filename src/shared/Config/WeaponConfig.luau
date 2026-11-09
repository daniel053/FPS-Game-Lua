--!strict
-- Armas (GDD seção 7.2). Os nomes exibidos ficam em Strings.Weapons (por ID).
-- Números da tabela 7.2.3 [PROPOSTA]: ajustar aqui depois dos testes, nunca no código.
--
-- Escopetas: `pellets` = número de bagos, `damage` = dano de CADA bago.
-- `referenceShotsToKill` e `referenceTimeToKill` vêm da tabela do GDD e servem para o teste
-- automático da F2 (tempo para derrubar com tolerância de ±10%). Não são usados no jogo.

local Types = require(script.Parent.Parent.Types)

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
	burstCount: number?, -- rajada do modo alternativo
	spinUpTime: number?, -- metralhadoras: tempo até a cadência máxima
	moveSpeedMultiplier: number?, -- com a arma na mão
	scopedMoveSpeedMultiplier: number?, -- com a mira aberta
	hasDamageFalloff: boolean, -- perda de dano com a distância (curvas definidas na F2)
	penetratesThinCover: boolean?,
	subtleTracer: boolean?,
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
}

export type WeaponPhase = {
	id: Types.WeaponPhaseId,
	fromRound: number,
	toRound: number?, -- nil = até o fim da partida
	primaries: { string },
}

-- Ordem = ordem de exibição dentro de cada categoria.
local Weapons: { WeaponDef } = {
	-- Pistolas
	{
		id = "weapon_bolinha",
		category = "Pistol",
		slot = "secondary",
		fireMode = "Semi",
		altMode = "Burst",
		burstCount = 3,
		damage = 13,
		pellets = 1,
		fireRate = 4,
		magazine = 12,
		reloadTime = 1.75,
		hasDamageFalloff = true,
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
		hasDamageFalloff = true,
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
		hasDamageFalloff = true,
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
		hasDamageFalloff = true, -- pouca perda (GDD 7.2.4)
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
		hasDamageFalloff = true,
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
		burstCount = 4,
		damage = 8,
		pellets = 1,
		fireRate = 13,
		magazine = 25,
		reloadTime = 2.25,
		hasDamageFalloff = true,
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
		hasDamageFalloff = true,
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
		hasDamageFalloff = true,
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
		hasDamageFalloff = true,
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
		burstCount = 3,
		damage = 10,
		pellets = 1,
		fireRate = 9,
		magazine = 24,
		reloadTime = 2.5,
		hasDamageFalloff = true,
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
		hasDamageFalloff = true,
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
		hasDamageFalloff = true,
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
		penetratesThinCover = true, -- com dano reduzido (valor na F2)
		hasDamageFalloff = true,
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
		subtleTracer = true,
		hasDamageFalloff = true, -- perde um pouco de longe
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
		hasDamageFalloff = false, -- sem perda de dano com a distância
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
		hasDamageFalloff = true,
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
		hasDamageFalloff = true,
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
		scopedMoveSpeedMultiplier = 0.7, -- mirando, 30% mais lento
		hasDamageFalloff = true,
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
}

-- Pistolas liberadas desde a 1ª rodada (GDD 7.2.2)
local BASE_PISTOLS = { "weapon_bolinha", "weapon_chumbinho", "weapon_zumbido", "weapon_precisa" }

local WeaponConfig = {
	Weapons = Weapons,
	Melee = Melee,

	-- Regra de segurança (GDD 7.2.1) [DECIDIDO]: nenhum tiro único pode passar disto.
	MaxSingleShotDamage = 135,

	-- Moedor e Gêmea entram na fase Pesadas? [PROPOSTA] (GDD 7.2.2 e pergunta 2 da seção 18)
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
