--!strict
-- Atributos das armas em escala de 0 a 1, para as barras da interface (modal de preparação T2 e
-- Arsenal T5). Só exibição: calculados a partir do WeaponConfig, sem números novos de jogo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)

export type Stats = { damage: number, fireRate: number, range: number, mobility: number }

-- Referências do topo de cada barra (só visual)
local MAX_FIRE_RATE = 13 -- tiros por segundo
local MAX_REACH = 120 -- studs
local MOBILITY_MIN, MOBILITY_MAX = 0.7, 1.1 -- multiplicador de velocidade com a arma na mão
local FLOOR = 0.05 -- toda barra mostra pelo menos um pedacinho

local WeaponStats = {}

local function clamp(v: number): number
	return math.clamp(v, FLOOR, 1)
end

function WeaponStats.get(id: string): Stats?
	local melee = WeaponConfig.Melee
	if id == melee.id then
		return {
			damage = clamp(melee.damage / WeaponConfig.MaxSingleShotDamage),
			fireRate = clamp(melee.swingsPerSecond / MAX_FIRE_RATE),
			range = clamp(melee.range / MAX_REACH),
			mobility = clamp((melee.moveSpeedMultiplier - MOBILITY_MIN) / (MOBILITY_MAX - MOBILITY_MIN)),
		}
	end
	local def = WeaponConfig.get(id)
	if def == nil then
		return nil
	end
	local reach = if def.effectiveRange then def.effectiveRange elseif def.falloff then def.falloff.finish else def.range
	local speed = def.moveSpeedMultiplier or 1
	return {
		damage = clamp(def.damage * def.pellets / WeaponConfig.MaxSingleShotDamage),
		fireRate = clamp(def.fireRate / MAX_FIRE_RATE),
		range = clamp(reach / MAX_REACH),
		mobility = clamp((speed - MOBILITY_MIN) / (MOBILITY_MAX - MOBILITY_MIN)),
	}
end

return WeaponStats
