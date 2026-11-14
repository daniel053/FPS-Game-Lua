--!strict
-- Moedas de uma partida (GDD 10.1) em funções puras. Quem credita no perfil é o EconomyService.

local EconomyConfig = require(script.Parent.Parent.Config.EconomyConfig)

local R = EconomyConfig.Rewards
local SECONDS_PER_DAY = 86400

-- O que o jogador fez na partida (contado pelo servidor da partida).
export type Tally = {
	roundsPlayed: number,
	roundsWon: number,
	kills: number,
}

export type Context = {
	placement: number?, -- nil = sem colocação (não ganha moedas de colocação)
	samePartner: boolean, -- jogou a partida inteira com o mesmo parceiro
	isPrivate: boolean,
	firstWinAvailable: boolean, -- ainda não ganhou a "primeira vitória do dia" hoje
}

export type Breakdown = {
	rounds: number,
	wins: number,
	kills: number,
	placement: number,
	partnerBonus: number,
	firstWin: number,
	privateCut: number, -- moedas a menos por ser partida privada (número positivo)
	total: number,
	gotFirstWin: boolean,
}

local EconomyRules = {}

-- Dia (UTC) de um horário os.time(), para a "primeira vitória do dia".
function EconomyRules.dayOf(time: number): number
	return math.floor(time / SECONDS_PER_DAY)
end

function EconomyRules.firstWinAvailable(lastFirstWinDay: number?, now: number): boolean
	return lastFirstWinDay == nil or lastFirstWinDay ~= EconomyRules.dayOf(now)
end

function EconomyRules.placementCoins(placement: number?): number
	if placement == nil then
		return 0
	end
	return R.PlacementByPlace[placement] or 0
end

-- Moedas da partida, peça por peça.
function EconomyRules.matchCoins(tally: Tally, context: Context): Breakdown
	local rounds = math.max(0, tally.roundsPlayed) * R.RoundParticipation
	local wins = math.max(0, tally.roundsWon) * R.RoundWin
	local kills = math.max(0, tally.kills) * R.Kill
	local placement = EconomyRules.placementCoins(context.placement)
	local base = rounds + wins + kills + placement
	local partnerBonus = if context.samePartner then math.floor(base * R.SamePartnerWholeMatchBonus) else 0
	local gotFirstWin = context.firstWinAvailable and tally.roundsWon > 0
	local firstWin = if gotFirstWin then R.FirstWinOfDay else 0
	local total = base + partnerBonus + firstWin
	local privateCut = 0
	if context.isPrivate then
		local kept = math.floor(total * EconomyConfig.PrivateMatchRewardMultiplier)
		privateCut = total - kept
		total = kept
	end
	return {
		rounds = rounds,
		wins = wins,
		kills = kills,
		placement = placement,
		partnerBonus = partnerBonus,
		firstWin = firstWin,
		privateCut = privateCut,
		total = total,
		gotFirstWin = gotFirstWin,
	}
end

return EconomyRules
