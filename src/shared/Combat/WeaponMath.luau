--!strict
-- Contas das armas: dano com a distância, espalhamento, direção dos bagos e tempo para derrubar.
-- Funções puras, usadas pelo cliente, pelo servidor e pelos testes.

local CharacterConfig = require(script.Parent.Parent.Config.CharacterConfig)
local WeaponConfig = require(script.Parent.Parent.Config.WeaponConfig)
local WeaponState = require(script.Parent.WeaponState)

type WeaponDef = WeaponConfig.WeaponDef

local WeaponMath = {}

-- Multiplicador de dano pela distância (1 = dano cheio).
function WeaponMath.falloffMultiplier(def: WeaponDef, distance: number): number
	local falloff = def.falloff
	if falloff == nil or distance <= falloff.start then
		return 1
	end
	if distance >= falloff.finish then
		return falloff.minMultiplier
	end
	local alpha = (distance - falloff.start) / (falloff.finish - falloff.start)
	return 1 + (falloff.minMultiplier - 1) * alpha
end

-- Dano de UM bago/bala a esta distância.
function WeaponMath.pelletDamage(def: WeaponDef, distance: number): number
	return def.damage * WeaponMath.falloffMultiplier(def, distance)
end

-- Dano de um tiro inteiro (todos os bagos acertando) a esta distância.
function WeaponMath.shotDamage(def: WeaponDef, distance: number): number
	return WeaponMath.pelletDamage(def, distance) * def.pellets
end

-- Maior dano possível de um tiro (colado, todos os bagos).
function WeaponMath.maxShotDamage(def: WeaponDef): number
	return def.damage * def.pellets
end

-- Raio do cone de espalhamento (graus) para a situação atual.
function WeaponMath.spreadDegrees(def: WeaponDef, alt: boolean, moving: boolean, bloom: number): number
	local spread = def.spread
	local base = if alt and spread.alt ~= nil then spread.alt else spread.hip
	if moving then
		base += spread.moving
	end
	return base + bloom
end

-- Direção aleatória dentro de um cone de `angleDegrees` em volta de `direction` (distribuição uniforme no disco).
function WeaponMath.randomInCone(direction: Vector3, angleDegrees: number, rng: Random): Vector3
	if angleDegrees <= 0 then
		return direction.Unit
	end
	local maxTan = math.tan(math.rad(angleDegrees))
	local radius = math.sqrt(rng:NextNumber()) * maxTan
	local theta = rng:NextNumber() * 2 * math.pi
	local frame = CFrame.lookAt(Vector3.zero, direction)
	local offset = frame.RightVector * (math.cos(theta) * radius) + frame.UpVector * (math.sin(theta) * radius)
	return (direction.Unit + offset).Unit
end

-- Direções de cada bago/bala do tiro. `spreadDegrees` é o espalhamento da arma (mira); escopetas somam o
-- cone dos bagos em volta dessa direção.
function WeaponMath.shotDirections(
	def: WeaponDef,
	alt: boolean,
	aimDirection: Vector3,
	spreadDegrees: number,
	rng: Random
): { Vector3 }
	local center = WeaponMath.randomInCone(aimDirection, spreadDegrees, rng)
	if def.pellets <= 1 then
		return { center }
	end
	local cone = def.pelletSpread or 0
	if alt and def.altMode == "FocusedPellets" and def.focusedPelletSpread then
		cone = def.focusedPelletSpread
	end
	local result = table.create(def.pellets)
	for i = 1, def.pellets do
		result[i] = WeaponMath.randomInCone(center, cone, rng)
	end
	return result
end

-- Velocidade de andar com esta arma na mão (GDD 7.2.4 e 7.4).
function WeaponMath.walkSpeed(def: WeaponDef?, scoped: boolean, isMelee: boolean): number
	local speed = CharacterConfig.Movement.WalkSpeed
	if isMelee then
		return speed * WeaponConfig.Melee.moveSpeedMultiplier
	end
	if def then
		speed *= def.moveSpeedMultiplier or 1
		if scoped then
			speed *= def.scopedMoveSpeedMultiplier or 1
		end
	end
	return speed
end

export type TimeToKill = { seconds: number, shots: number }

-- Simula alguém segurando o gatilho colado no alvo, com todos os bagos acertando, usando a MESMA
-- máquina de estados do jogo (WeaponState): cadência, pente, recarga e aquecimento.
-- `totalHealth` = vida + escudo do alvo (150 com tudo cheio).
function WeaponMath.simulateTimeToKill(def: WeaponDef, totalHealth: number): TimeToKill
	local state = WeaponState.new(def)
	WeaponState.setSpin(state, true, 0)
	local t = 0
	local dealt = 0
	local shots = 0
	for _ = 1, 10000 do
		local ok, reason = WeaponState.fire(state, t, 0)
		if ok then
			shots += 1
			dealt += WeaponMath.shotDamage(def, 0)
			if dealt >= totalHealth then
				return { seconds = t, shots = shots }
			end
			if state.ammo <= 0 then
				WeaponState.startReload(state, t) -- como no jogo: recarrega assim que o pente esvazia
			end
		elseif reason == "empty" then
			WeaponState.startReload(state, t)
		end
		t = WeaponState.nextEventTime(state, t)
	end
	return { seconds = math.huge, shots = shots }
end

-- Mesmo cálculo para o corpo a corpo (golpes leves seguidos).
function WeaponMath.simulateMeleeTimeToKill(totalHealth: number, heavy: boolean): TimeToKill
	local melee = WeaponConfig.Melee
	local damage = if heavy then melee.heavyDamage else melee.damage
	local interval = if heavy then melee.heavyInterval else 1 / melee.swingsPerSecond
	local swings = math.ceil(totalHealth / damage)
	return { seconds = (swings - 1) * interval, shots = swings }
end

return WeaponMath
