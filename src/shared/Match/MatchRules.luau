--!strict
-- Regras da partida (GDD 4.2 a 4.9) em funções puras: formar duplas, sortear confrontos, folga e
-- ilhas, aplicar o resultado da rodada (vidas, Virada, eliminação, final e campeão).
-- Sem tempo, sem instâncias e sem rede: o MatchService chama estas funções e os testes simulam
-- partidas inteiras com elas.

local MatchConfig = require(script.Parent.Parent.Config.MatchConfig)

export type TeamState = {
	id: string,
	lives: number,
	roundWins: number, -- só conta na final
	eliminated: boolean,
	placement: number?, -- 1 = campeã
	hadBye: boolean, -- já teve folga neste ciclo
	byes: number,
	lastOpponent: string?,
	lastIsland: number?,
}

export type State = {
	teams: { [string]: TeamState },
	order: { string }, -- ordem fixa (a das cores)
	islandCount: number,
	round: number,
	viradaDone: boolean, -- a Virada já foi jogada
	viradaPending: boolean, -- a próxima rodada é a Virada
	finalMode: boolean,
	lastBye: string?,
	championId: string?,
}

export type Duel = { a: string, b: string, island: number }

export type RoundPlan = {
	round: number,
	isVirada: boolean,
	isFinal: boolean,
	bye: string?,
	duels: { Duel },
}

-- Resultado de cada duelo, na ordem de `plan.duels`: o ID da dupla vencedora, ou nil = empate.
export type DuelOutcome = { winner: string? }

export type RoundReport = {
	livesBefore: { [string]: number },
	eliminated: { string },
	viradaNext: boolean, -- a Virada foi disparada agora (vale para a próxima rodada)
	finalStarted: boolean,
	championId: string?,
}

export type MemberInfo = { key: string, elo: number }

local MatchRules = {}

-- Duplas ----------------------------------------------------------------------------------------

-- Forma as duplas (GDD 4.2), na ordem de prioridade:
--   1. duplas fixas vindas do lobby; 2. amigos no Roblox; 3. solo com solo por elo parecido;
--   4. número ímpar: um joga sozinho (1v2), sem bônus.
-- Se só sairia UMA dupla (2 jogadores, só em teste), cada um vira uma dupla de uma pessoa.
function MatchRules.formTeams(
	members: { MemberInfo },
	fixedPairs: { { string } },
	areFriends: (a: string, b: string) -> boolean
): { { string } }
	local present: { [string]: MemberInfo } = {}
	for _, m in members do
		present[m.key] = m
	end
	local used: { [string]: boolean } = {}
	local teams: { { string } } = {}

	for _, pair in fixedPairs do
		local a, b = pair[1], pair[2]
		if a and b and a ~= b and present[a] and present[b] and not used[a] and not used[b] then
			used[a], used[b] = true, true
			table.insert(teams, { a, b })
		end
	end

	local remaining: { MemberInfo } = {}
	for _, m in members do
		if not used[m.key] then
			table.insert(remaining, m)
		end
	end
	-- Maior elo primeiro; empate pela chave (resultado estável)
	table.sort(remaining, function(x, y)
		if x.elo ~= y.elo then
			return x.elo > y.elo
		end
		return x.key < y.key
	end)

	for i, a in remaining do
		if used[a.key] then
			continue
		end
		for j = i + 1, #remaining do
			local b = remaining[j]
			if not used[b.key] and areFriends(a.key, b.key) then
				used[a.key], used[b.key] = true, true
				table.insert(teams, { a.key, b.key })
				break
			end
		end
	end

	local solos: { string } = {}
	for _, m in remaining do
		if not used[m.key] then
			table.insert(solos, m.key)
		end
	end
	-- Ímpar: o de maior elo entre os sem par joga sozinho
	if #solos % 2 == 1 then
		table.insert(teams, { table.remove(solos, 1) :: string })
	end
	for i = 1, #solos, 2 do
		table.insert(teams, { solos[i], solos[i + 1] })
	end

	if #teams == 1 and #members >= 2 then
		local only = teams[1]
		teams = {}
		for _, key in only do
			table.insert(teams, { key })
		end
	end
	return teams
end

-- Estado -----------------------------------------------------------------------------------------

function MatchRules.newState(teamIds: { string }, islandCount: number): State
	local teams: { [string]: TeamState } = {}
	for _, id in teamIds do
		teams[id] = {
			id = id,
			lives = MatchConfig.StartingLives,
			roundWins = 0,
			eliminated = false,
			placement = nil,
			hadBye = false,
			byes = 0,
			lastOpponent = nil,
			lastIsland = nil,
		}
	end
	local state: State = {
		teams = teams,
		order = table.clone(teamIds),
		islandCount = islandCount,
		round = 0,
		viradaDone = false,
		viradaPending = false,
		finalMode = false,
		lastBye = nil,
		championId = nil,
	}
	-- Só 2 duplas desde o começo: a partida inteira é a final.
	if MatchConfig.Final.Enabled and #teamIds == 2 then
		state.finalMode = true
	end
	return state
end

function MatchRules.aliveTeams(state: State): { string }
	local result = {}
	for _, id in state.order do
		if not state.teams[id].eliminated then
			table.insert(result, id)
		end
	end
	return result
end

local function shuffle<T>(list: { T }, rng: Random)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

-- Folga (GDD 4.6): gira entre todas as duplas vivas antes de repetir; entre as que ainda não
-- tiveram, prioridade para quem tem mais vidas. Ao recomeçar o ciclo, evita repetir a última.
local function pickBye(state: State, alive: { string }, rng: Random): string
	local candidates = {}
	for _, id in alive do
		if not state.teams[id].hadBye then
			table.insert(candidates, id)
		end
	end
	if #candidates == 0 then
		for _, id in alive do
			state.teams[id].hadBye = false
			if id ~= state.lastBye or #alive == 1 then
				table.insert(candidates, id)
			end
		end
	end
	if MatchConfig.Pairing.ByePriorityMoreLives then
		local best = -math.huge
		for _, id in candidates do
			best = math.max(best, state.teams[id].lives)
		end
		local top = {}
		for _, id in candidates do
			if state.teams[id].lives == best then
				table.insert(top, id)
			end
		end
		candidates = top
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

-- Pareia as duplas evitando repetir o confronto anterior quando possível.
local function pairTeams(state: State, ids: { string }, rng: Random): { { string } }
	local best: { { string } } = {}
	local bestRepeats = math.huge
	local attempts = if MatchConfig.Pairing.AvoidRepeatOpponent then MatchConfig.Pairing.Attempts else 1
	for _ = 1, attempts do
		local list = table.clone(ids)
		shuffle(list, rng)
		local pairs = {}
		local repeats = 0
		for i = 1, #list - 1, 2 do
			local a, b = list[i], list[i + 1]
			if state.teams[a].lastOpponent == b or state.teams[b].lastOpponent == a then
				repeats += 1
			end
			table.insert(pairs, { a, b })
		end
		if repeats < bestRepeats then
			best, bestRepeats = pairs, repeats
			if repeats == 0 then
				break
			end
		end
	end
	return best
end

-- Ilhas: cada duelo numa ilha diferente; a dupla não repete a ilha da rodada anterior (se der).
local function assignIslands(state: State, pairs: { { string } }, rng: Random): { number }
	local islands = {}
	for i = 1, state.islandCount do
		table.insert(islands, i)
	end
	local best: { number } = {}
	local bestConflicts = math.huge
	local attempts = if MatchConfig.Pairing.AvoidSameMapTwiceInArena then MatchConfig.Pairing.Attempts else 1
	for _ = 1, attempts do
		local list = table.clone(islands)
		shuffle(list, rng)
		local conflicts = 0
		for i, pair in pairs do
			local island = list[i]
			for _, id in pair do
				if state.teams[id].lastIsland == island then
					conflicts += 1
				end
			end
		end
		if conflicts < bestConflicts then
			best, bestConflicts = list, conflicts
			if conflicts == 0 then
				break
			end
		end
	end
	local result = {}
	for i = 1, #pairs do
		result[i] = best[i]
	end
	return result
end

-- Monta a próxima rodada: folga, confrontos e ilhas.
function MatchRules.planRound(state: State, rng: Random): RoundPlan
	state.round += 1
	local isFinal = state.finalMode
	local isVirada = state.viradaPending and not isFinal
	if isVirada then
		state.viradaPending = false
		state.viradaDone = true
	end

	local alive = MatchRules.aliveTeams(state)
	local bye: string? = nil
	local playing = alive
	if #alive % 2 == 1 then
		local chosen = pickBye(state, alive, rng)
		bye = chosen
		state.teams[chosen].hadBye = true
		state.teams[chosen].byes += 1
		state.lastBye = chosen
		playing = {}
		for _, id in alive do
			if id ~= chosen then
				table.insert(playing, id)
			end
		end
	end

	local pairs = pairTeams(state, playing, rng)
	assert(#pairs <= state.islandCount, "mais duelos do que ilhas")
	local islands = assignIslands(state, pairs, rng)
	local duels: { Duel } = {}
	for i, pair in pairs do
		table.insert(duels, { a = pair[1], b = pair[2], island = islands[i] })
	end
	return { round = state.round, isVirada = isVirada, isFinal = isFinal, bye = bye, duels = duels }
end

-- Resultado ---------------------------------------------------------------------------------------

-- Elimina quem zerou as vidas, dispara a Virada, começa a final e define a campeã.
local function settle(state: State, report: RoundReport)
	local newlyOut = {}
	for _, id in state.order do
		local team = state.teams[id]
		if not team.eliminated and team.lives <= 0 then
			table.insert(newlyOut, id)
		end
	end
	if #newlyOut > 0 then
		local stillAlive = #MatchRules.aliveTeams(state) - #newlyOut
		for _, id in newlyOut do
			local team = state.teams[id]
			team.eliminated = true
			team.placement = stillAlive + 1 -- quem cai na mesma rodada divide a colocação
			table.insert(report.eliminated, id)
		end
	end

	local alive = MatchRules.aliveTeams(state)
	if #alive == 1 and state.championId == nil then
		state.championId = alive[1]
		state.teams[alive[1]].placement = 1
		report.championId = alive[1]
		return
	end

	if not state.finalMode and MatchConfig.Final.Enabled and #alive == 2 then
		state.finalMode = true
		state.viradaPending = false -- na final as vidas não contam: não há Virada
		for _, id in alive do
			state.teams[id].roundWins = 0
		end
		report.finalStarted = true
		return
	end

	if not state.finalMode and not state.viradaDone and not state.viradaPending then
		for _, id in alive do
			if state.teams[id].lives == MatchConfig.Virada.TriggerLives then
				state.viradaPending = true
				report.viradaNext = true
				break
			end
		end
	end
end

local function newReport(state: State): RoundReport
	local livesBefore = {}
	for id, team in state.teams do
		livesBefore[id] = team.lives
	end
	return { livesBefore = livesBefore, eliminated = {}, viradaNext = false, finalStarted = false, championId = nil }
end

function MatchRules.finishRound(state: State, plan: RoundPlan, outcomes: { DuelOutcome }): RoundReport
	local report = newReport(state)
	for i, duel in plan.duels do
		local a, b = state.teams[duel.a], state.teams[duel.b]
		a.lastOpponent, b.lastOpponent = duel.b, duel.a
		a.lastIsland, b.lastIsland = duel.island, duel.island
		local outcome = outcomes[i]
		local winnerId = outcome and outcome.winner
		if winnerId ~= duel.a and winnerId ~= duel.b then
			continue -- empate: ninguém perde vida
		end
		local winner = state.teams[winnerId :: string]
		local loser = if winner == a then b else a
		if plan.isFinal then
			winner.roundWins += 1
			if winner.roundWins >= MatchConfig.Final.WinsNeeded then
				loser.eliminated = true
				loser.placement = 2
				table.insert(report.eliminated, loser.id)
			end
		else
			loser.lives = math.max(0, loser.lives - MatchConfig.LivesLostPerRoundLoss)
			if plan.isVirada then
				winner.lives = math.min(MatchConfig.MaxLives, winner.lives + MatchConfig.Virada.WinnerLifeBonus)
			end
		end
	end
	settle(state, report)
	return report
end

-- A dupla inteira saiu do jogo (GDD 4.9): eliminada na hora.
function MatchRules.forfeit(state: State, teamId: string): RoundReport
	local report = newReport(state)
	local team = state.teams[teamId]
	if team == nil or team.eliminated then
		return report
	end
	if state.finalMode then
		team.eliminated = true
		team.placement = 2
		table.insert(report.eliminated, teamId)
	else
		team.lives = 0
	end
	settle(state, report)
	return report
end

-- Tempo esgotado (GDD 4.4): vence quem tiver mais HP + escudo somados; empate exato = nil.
function MatchRules.timeoutWinner(a: string, totalA: number, b: string, totalB: number): string?
	if totalA > totalB then
		return a
	elseif totalB > totalA then
		return b
	end
	return nil
end

-- Comandos de teste ------------------------------------------------------------------------------

function MatchRules.devRemoveLife(state: State, teamId: string): RoundReport
	local report = newReport(state)
	local team = state.teams[teamId]
	if team and not team.eliminated and not state.finalMode then
		team.lives = math.max(0, team.lives - 1)
		settle(state, report)
	end
	return report
end

function MatchRules.devForceVirada(state: State): boolean
	if state.finalMode or state.viradaDone then
		return false
	end
	state.viradaPending = true
	return true
end

return MatchRules
