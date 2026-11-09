--!strict
-- Estado de uma arma (munição, recarga, cadência, rajada, aquecimento, saque). Funções puras.
--
-- O MESMO código roda no cliente (para responder na hora) e no servidor (que decide). Os horários `t`
-- são em tempo do servidor (workspace:GetServerTimeNow). No servidor, `slack` dá uma folga de
-- arredondamento; no cliente, `slack` = 0.
--
-- Motivos de recusa: "equipping", "reloading", "empty", "spinning", "cadence".

local WeaponConfig = require(script.Parent.Parent.Config.WeaponConfig)

type WeaponDef = WeaponConfig.WeaponDef
type MeleeDef = WeaponConfig.MeleeDef

export type FireRejectReason = "equipping" | "reloading" | "empty" | "spinning" | "cadence"

export type State = {
	def: WeaponDef,
	ammo: number,
	reloadEndsAt: number?, -- recarregando até este horário
	nextShotAt: number, -- próximo tiro permitido
	burstLeft: number, -- tiros que faltam na rajada em andamento
	alt: boolean, -- modo alternativo / mira ligado
	spinStartedAt: number?, -- metralhadoras: quando começou a aquecer
	readyAt: number, -- arma sacada a partir deste horário
}

export type MeleeState = {
	def: MeleeDef,
	nextSwingAt: number,
	readyAt: number,
}

local WeaponState = {}

function WeaponState.new(def: WeaponDef): State
	return {
		def = def,
		ammo = def.magazine,
		reloadEndsAt = nil,
		nextShotAt = -math.huge,
		burstLeft = 0,
		alt = false,
		spinStartedAt = nil,
		readyAt = -math.huge,
	}
end

-- Termina a recarga se o horário dela já passou.
function WeaponState.update(state: State, t: number)
	local endsAt = state.reloadEndsAt
	if endsAt and t >= endsAt then
		state.reloadEndsAt = nil
		state.ammo = state.def.magazine
	end
end

function WeaponState.isReloading(state: State, t: number): boolean
	WeaponState.update(state, t)
	return state.reloadEndsAt ~= nil
end

function WeaponState.inBurstMode(state: State): boolean
	return state.alt and state.def.burst ~= nil and WeaponConfig.hasBurst(state.def)
end

function WeaponState.canFire(state: State, t: number, slack: number): (boolean, FireRejectReason?)
	WeaponState.update(state, t + slack)
	if t + slack < state.readyAt then
		return false, "equipping"
	end
	if state.reloadEndsAt ~= nil then
		return false, "reloading"
	end
	if state.ammo <= 0 then
		return false, "empty"
	end
	local spinUp = state.def.spinUpTime
	if spinUp then
		local started = state.spinStartedAt
		if started == nil or t + slack < started + spinUp then
			return false, "spinning"
		end
	end
	if t + slack < state.nextShotAt then
		return false, "cadence"
	end
	return true, nil
end

-- Dispara um tiro no horário `t` (gasta 1 de munição e marca a cadência). Devolve se foi aceito.
function WeaponState.fire(state: State, t: number, slack: number): (boolean, FireRejectReason?)
	local ok, reason = WeaponState.canFire(state, t, slack)
	if not ok then
		return false, reason :: FireRejectReason?
	end
	state.ammo -= 1

	local burst = state.def.burst
	if burst and WeaponState.inBurstMode(state) then
		if state.burstLeft <= 0 then
			state.burstLeft = burst.count
		end
		state.burstLeft -= 1
		if state.burstLeft > 0 and state.ammo > 0 then
			state.nextShotAt = t + 1 / burst.rate
		else
			state.burstLeft = 0
			state.nextShotAt = t + burst.cooldown
		end
	else
		state.nextShotAt = t + 1 / state.def.fireRate
	end
	return true, nil
end

-- Uma rajada começou e ainda não terminou (o cliente continua atirando mesmo sem segurar o gatilho).
function WeaponState.burstInProgress(state: State): boolean
	return state.burstLeft > 0
end

function WeaponState.startReload(state: State, t: number): boolean
	WeaponState.update(state, t)
	if state.reloadEndsAt ~= nil or state.ammo >= state.def.magazine then
		return false
	end
	state.reloadEndsAt = math.max(t, state.readyAt) + state.def.reloadTime
	state.burstLeft = 0
	return true
end

-- Sacar a arma: cancela a recarga, desliga a mira e o aquecimento.
function WeaponState.equip(state: State, t: number)
	WeaponState.update(state, t)
	state.reloadEndsAt = nil
	state.readyAt = t + WeaponConfig.EquipTime
	state.burstLeft = 0
	state.alt = false
	state.spinStartedAt = nil
end

function WeaponState.setAlt(state: State, on: boolean)
	state.alt = on and state.def.altMode ~= nil
	state.burstLeft = 0
end

function WeaponState.setSpin(state: State, on: boolean, t: number)
	if state.def.spinUpTime == nil then
		return
	end
	if on then
		if state.spinStartedAt == nil then
			state.spinStartedAt = t
		end
	else
		state.spinStartedAt = nil
	end
end

-- Primeiro horário a partir de `t` em que algo pode mudar (usado na simulação dos testes).
function WeaponState.nextEventTime(state: State, t: number): number
	local nextT = math.max(t, state.nextShotAt, state.readyAt)
	local endsAt = state.reloadEndsAt
	if endsAt then
		nextT = math.max(nextT, endsAt)
	end
	local spinUp = state.def.spinUpTime
	local started = state.spinStartedAt
	if spinUp and started then
		nextT = math.max(nextT, started + spinUp)
	end
	return nextT
end

-- Corpo a corpo -------------------------------------------------------------------------------

function WeaponState.newMelee(def: MeleeDef): MeleeState
	return { def = def, nextSwingAt = -math.huge, readyAt = -math.huge }
end

function WeaponState.equipMelee(state: MeleeState, t: number)
	state.readyAt = t + WeaponConfig.EquipTime
end

-- Golpe leve ou forte no horário `t`. Devolve se foi aceito.
function WeaponState.swing(state: MeleeState, heavy: boolean, t: number, slack: number): boolean
	if t + slack < state.readyAt or t + slack < state.nextSwingAt then
		return false
	end
	local interval = if heavy then state.def.heavyInterval else 1 / state.def.swingsPerSecond
	state.nextSwingAt = t + interval
	return true
end

return WeaponState
