--!strict
-- Vida e escudo (GDD 7.1). Funções puras, usadas pelo servidor e pelos testes.
-- O escudo absorve o dano primeiro; o que sobra vai para a vida. Sem multiplicador de cabeça.

local CharacterConfig = require(script.Parent.Parent.Config.CharacterConfig)

local HEALTH = CharacterConfig.Health

export type Health = { hp: number, shield: number }

export type DamageResult = {
	dealt: number, -- dano que realmente entrou (escudo + vida)
	toShield: number,
	toHp: number,
	shieldBroken: boolean, -- o escudo chegou a zero com este dano
	knocked: boolean, -- a vida chegou a zero
}

local HealthMath = {}

function HealthMath.full(): Health
	return { hp = HEALTH.MaxHp, shield = HEALTH.MaxShield }
end

function HealthMath.total(health: Health): number
	return health.hp + health.shield
end

-- Aplica o dano (altera `health`). Valores inválidos (negativo, NaN) não causam dano.
function HealthMath.applyDamage(health: Health, amount: number): DamageResult
	if amount ~= amount or amount <= 0 then
		return { dealt = 0, toShield = 0, toHp = 0, shieldBroken = false, knocked = health.hp <= 0 }
	end
	local hadShield = health.shield > 0
	local toShield = math.min(health.shield, amount)
	health.shield -= toShield
	local toHp = math.min(health.hp, amount - toShield)
	health.hp -= toHp
	return {
		dealt = toShield + toHp,
		toShield = toShield,
		toHp = toHp,
		shieldBroken = hadShield and health.shield <= 0,
		knocked = health.hp <= 0,
	}
end

-- Regenera o escudo depois de `ShieldRegenDelay` segundos sem levar dano. Devolve true se mudou.
function HealthMath.regenShield(health: Health, dt: number, secondsSinceDamage: number): boolean
	if health.hp <= 0 or health.shield >= HEALTH.MaxShield or secondsSinceDamage < HEALTH.ShieldRegenDelay then
		return false
	end
	health.shield = math.min(HEALTH.MaxShield, health.shield + HEALTH.ShieldRegenPerSecond * dt)
	return true
end

return HealthMath
