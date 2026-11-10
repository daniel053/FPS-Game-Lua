--!strict
-- Cargas e recarga de UMA carta durante a rodada (GDD 8.4 e 8.5). Lógica pura, sem Roblox:
-- roda no servidor (autoridade) e no cliente (resposta na hora), igual à WeaponState das armas.
-- Horários em tempo do servidor (workspace:GetServerTimeNow()).
--
--   * Cada rodada começa com as cargas cheias (`resetRound`).
--   * Usar gasta 1 carga. Com `cooldown`, a carga volta depois desse tempo (uma por vez).
--   * Entre dois usos seguidos há um intervalo mínimo (`minInterval`).
--   * A ult tem `CardConfig.UltUsesPerRound` usos por rodada e não recarrega.

local CardConfig = require(script.Parent.Parent.Config.CardConfig)

type CardDef = CardConfig.CardDef

export type State = {
	def: CardDef,
	maxCharges: number,
	charges: number,
	rechargeAt: number?, -- quando a próxima carga volta (nil = nada recarregando)
	lastUseAt: number,
}

-- Motivo da recusa: "noCharges" (sem carga / recarregando) ou "tooSoon" (intervalo mínimo)
export type RefuseReason = string

local CardState = {}

local function maxChargesOf(def: CardDef): number
	return if def.isUlt then CardConfig.UltUsesPerRound else def.charges
end

function CardState.new(def: CardDef): State
	local max = maxChargesOf(def)
	return { def = def, maxCharges = max, charges = max, rechargeAt = nil, lastUseAt = -math.huge }
end

-- Começo de rodada: cargas cheias, nada recarregando.
function CardState.resetRound(state: State)
	state.charges = state.maxCharges
	state.rechargeAt = nil
	state.lastUseAt = -math.huge
end

-- Devolve as cargas que já recarregaram até `now`.
function CardState.update(state: State, now: number)
	local cooldown = state.def.cooldown
	while state.rechargeAt and now >= state.rechargeAt and state.charges < state.maxCharges do
		state.charges += 1
		if state.charges < state.maxCharges and cooldown then
			state.rechargeAt = (state.rechargeAt :: number) + cooldown
		else
			state.rechargeAt = nil
		end
	end
end

function CardState.canUse(state: State, now: number): (boolean, RefuseReason?)
	CardState.update(state, now)
	if state.charges <= 0 then
		return false, "noCharges"
	end
	if now - state.lastUseAt < state.def.minInterval then
		return false, "tooSoon"
	end
	return true, nil
end

-- Gasta uma carga. Devolve false (sem mudar nada) se não pode.
function CardState.use(state: State, now: number): (boolean, RefuseReason?)
	local ok, reason = CardState.canUse(state, now)
	if not ok then
		return false, reason
	end
	state.charges -= 1
	state.lastUseAt = now
	local cooldown = state.def.cooldown
	if cooldown and state.rechargeAt == nil then
		state.rechargeAt = now + cooldown
	end
	return true, nil
end

-- Segundos até a próxima carga (0 = pronta ou não recarrega).
function CardState.secondsToRecharge(state: State, now: number): number
	if state.rechargeAt == nil then
		return 0
	end
	return math.max(0, state.rechargeAt - now)
end

return CardState
