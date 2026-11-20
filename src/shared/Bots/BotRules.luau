--!strict
-- Contas dos bots de preenchimento (docs/BOTS.md), em funções puras: fila, mira, escolhas e nomes.
-- Usadas pela fila (lobby), pelo servidor da partida e pelos testes.

local BotConfig = require(script.Parent.Parent.Config.BotConfig)
local CardConfig = require(script.Parent.Parent.Config.CardConfig)

export type RampPoint = { seconds: number, fill: number }

-- Parâmetros da fila com bots (QueueRules.Params.bots).
export type QueueParams = {
	startAfter: number,
	fillTo: number,
	ramp: { RampPoint },
}

export type Skill = typeof(BotConfig.Skill)

export type AimInput = {
	distance: number,
	moving: boolean,
	targetMoving: boolean,
	vsBot: boolean,
	shotsAtTarget: number, -- tiros já dados neste alvo
}

local BotRules = {}

function BotRules.queueParams(): QueueParams
	return {
		startAfter = BotConfig.Queue.StartAfterSeconds,
		fillTo = BotConfig.Queue.FillTo,
		ramp = BotConfig.Queue.Ramp,
	}
end

-- Vagas mostradas na contagem da fila (jogadores + bots) depois de `waitSeconds` de espera de quem
-- chegou primeiro. 0 antes do primeiro ponto; entre dois pontos, sobe em linha reta; arredonda para baixo.
function BotRules.seatsShown(waitSeconds: number, q: QueueParams): number
	local ramp = q.ramp
	if #ramp == 0 or waitSeconds < ramp[1].seconds then
		return 0
	end
	local fill = ramp[#ramp].fill
	for i = 1, #ramp - 1 do
		local a, b = ramp[i], ramp[i + 1]
		if waitSeconds < b.seconds then
			local alpha = (waitSeconds - a.seconds) / math.max(b.seconds - a.seconds, 1e-6)
			fill = a.fill + (b.fill - a.fill) * alpha
			break
		end
	end
	return math.clamp(math.floor(fill * q.fillTo + 1e-6), 0, q.fillTo)
end

-- Quantos bots completam a sala com `present` pessoas (nunca negativo).
function BotRules.botsToFill(present: number, fillTo: number): number
	return math.max(0, fillTo - present)
end

-- Erro de mira (graus) de um tiro do bot. Bots ruins de propósito: erram mais de longe, andando, com o
-- alvo andando e nos primeiros tiros num alvo novo.
function BotRules.aimErrorDegrees(skill: Skill, input: AimInput): number
	local degrees = skill.AimErrorDegrees + skill.AimErrorPerStud * input.distance
	if input.moving then
		degrees += skill.AimErrorMoving
	end
	if input.targetMoving then
		degrees += skill.AimErrorTargetMoving
	end
	local warmupLeft = math.max(0, skill.WarmupShots - input.shotsAtTarget)
	if skill.WarmupShots > 0 then
		degrees += skill.AimErrorWarmup * warmupLeft / skill.WarmupShots
	end
	if input.vsBot then
		degrees *= skill.VsBotErrorMultiplier
	end
	return degrees
end

-- Multiplicador do dano do bot contra este alvo.
function BotRules.damageMultiplier(skill: Skill, vsBot: boolean): number
	return skill.DamageMultiplier * (if vsBot then skill.VsBotDamageMultiplier else 1)
end

-- Sorteio entre `min` e `max`.
function BotRules.between(range: { Min: number, Max: number }, rng: Random): number
	return range.Min + (range.Max - range.Min) * rng:NextNumber()
end

-- Armas da rodada para um bot: uma primária e uma pistola quaisquer das liberadas.
function BotRules.pickLoadout(primaries: { string }, secondaries: { string }, rng: Random): (string?, string?)
	local primary = if #primaries > 0 then primaries[rng:NextInteger(1, #primaries)] else nil
	local secondary = if #secondaries > 0 then secondaries[rng:NextInteger(1, #secondaries)] else nil
	return primary, secondary
end

-- Cartas do bot na partida: uma básica sorteada (C, Q ou E) e a ult das cartas iniciais.
function BotRules.pickCards(rng: Random): (string?, string?)
	local basics: { string } = {}
	local ult: string? = nil
	for _, id in CardConfig.StarterCards do
		local def = CardConfig.get(id)
		if def and def.isUlt then
			ult = ult or id
		elseif def then
			table.insert(basics, id)
		end
	end
	local basic = if #basics > 0 then basics[rng:NextInteger(1, #basics)] else nil
	return basic, ult
end

-- Nome de jogador para o bot, com as partes de `parts` (Strings.Bots). Não repete nomes de `used`.
export type NameParts = { First: { string }, Second: { string }, Patterns: { string } }

function BotRules.makeName(parts: NameParts, rng: Random, used: { [string]: boolean }): string
	local name = ""
	for _ = 1, 20 do
		local first = parts.First[rng:NextInteger(1, #parts.First)]
		local second = parts.Second[rng:NextInteger(1, #parts.Second)]
		local pattern = parts.Patterns[rng:NextInteger(1, #parts.Patterns)]
		name = string.format(pattern, first, second, rng:NextInteger(1, 99))
		if not used[name] then
			break
		end
	end
	used[name] = true
	return name
end

return BotRules
