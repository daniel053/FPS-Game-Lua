--!strict
-- Regras puras da fila (GDD 6.2 e 6.3). Sem serviços do Roblox: os testes simulam a fila inteira.
--
--   * A partida é montada quando a fila junta MinPlayersToStart (7). Daí espera FillWaitSeconds (15)
--     para completar até MaxPlayers (16), ou sai na hora se chegar a 16.
--   * Sem 7 em FlexibleAfterSeconds (20; 5 em teste), começa com quem houver, a partir de FlexibleMinPlayers (4).
--   * Duas faixas (Aprendizes e Experientes). Uma faixa que não junta 7 em TierMergeAfterSeconds (45)
--     se junta com a outra.
--   * Ficha = um grupo (sozinho ou dupla fixa). Uma ficha nunca é separada.
--   * Ordem: fichas com prioridade primeiro (voltaram porque a partida não aconteceu), depois por
--     ordem de chegada.
--
-- "Quando a fila chegou a 7" não precisa ser guardado: é o horário de chegada da ficha que fez a
-- conta passar de 7 (a conta é feita do zero a cada vez, com as fichas em ordem).

local QueueConfig = require(script.Parent.Parent.Config.QueueConfig)
local RankConfig = require(script.Parent.Parent.Config.RankConfig)

export type Tier = "Aprendizes" | "Experientes"
export type PoolId = Tier | "Mistura"

export type Ticket = {
	id: string,
	userIds: { number },
	tier: Tier,
	enqueuedAt: number, -- segundos (relógio comum entre servidores)
	priority: boolean,
}

export type Params = {
	minPlayers: number,
	fillWait: number,
	maxPlayers: number,
	flexibleAfter: number,
	flexibleMin: number,
	tierMergeAfter: number,
}

export type Plan = {
	pool: PoolId,
	ticketIds: { string },
	userIds: { number },
	duos: { { number } }, -- duplas fixas (fichas de 2)
}

-- Estado de uma faixa para a tela ("Procurando partida… 5/7").
export type PoolStatus = {
	count: number,
	target: number, -- 7 enquanto não chega; 16 durante a espera para completar
	startsAt: number?, -- quando sai a partida, se já tem horário
}

export type Status = {
	merged: boolean,
	pools: { [string]: PoolStatus }, -- por Tier
}

export type PlayerLevel = { points: number, matchesPlayed: number }

local QueueRules = {}

function QueueRules.params(isDev: boolean): Params
	local p: Params = {
		minPlayers = QueueConfig.MinPlayersToStart,
		fillWait = QueueConfig.FillWaitSeconds,
		maxPlayers = QueueConfig.MaxPlayers,
		flexibleAfter = QueueConfig.FlexibleAfterSeconds,
		flexibleMin = QueueConfig.FlexibleMinPlayers,
		tierMergeAfter = QueueConfig.TierMergeAfterSeconds,
	}
	if isDev then
		p.flexibleMin = QueueConfig.Dev.FlexibleMinPlayers
		p.flexibleAfter = QueueConfig.Dev.FlexibleAfterSeconds
		p.tierMergeAfter = QueueConfig.Dev.TierMergeAfterSeconds
	end
	return p
end

-- Faixa de elo exibida (Bronze, Prata…) a partir dos pontos (RankConfig.Tiers em ordem crescente).
function QueueRules.rankTierOf(points: number): string
	local result = RankConfig.Tiers[1].id
	for _, tier in RankConfig.Tiers do
		if points >= tier.minPoints then
			result = tier.id
		end
	end
	return result
end

-- Faixa de fila de um jogador: menos de 10 partidas, Bronze ou Prata = Aprendizes.
function QueueRules.tierOf(level: PlayerLevel): Tier
	if level.matchesPlayed <= QueueConfig.Tiers.Aprendizes.MaxMatchesPlayed then
		return "Aprendizes"
	end
	local rankTier = QueueRules.rankTierOf(level.points)
	if table.find(QueueConfig.Tiers.Aprendizes.RankTiers, rankTier) then
		return "Aprendizes"
	end
	return "Experientes"
end

-- Faixa de um grupo: a do MAIOR elo da dupla (GDD 6.3), para ninguém usar um amigo novato para
-- jogar na faixa fácil.
function QueueRules.groupTier(levels: { PlayerLevel }): Tier
	local result: Tier = "Aprendizes"
	for _, level in levels do
		if QueueConfig.FixedDuoUsesHigherRank and QueueRules.tierOf(level) == "Experientes" then
			result = "Experientes"
		end
	end
	if not QueueConfig.FixedDuoUsesHigherRank and #levels > 0 then
		result = QueueRules.tierOf(levels[1])
	end
	return result
end

local function size(ticket: Ticket): number
	return #ticket.userIds
end

function QueueRules.sorted(tickets: { Ticket }): { Ticket }
	local list = table.clone(tickets)
	table.sort(list, function(a, b)
		if a.priority ~= b.priority then
			return a.priority
		end
		if a.enqueuedAt ~= b.enqueuedAt then
			return a.enqueuedAt < b.enqueuedAt
		end
		return a.id < b.id
	end)
	return list
end

local function countOf(tickets: { Ticket }): number
	local n = 0
	for _, t in tickets do
		n += size(t)
	end
	return n
end

-- Fichas que cabem na partida, em ordem; uma dupla que não cabe é pulada (nunca separada).
local function take(sortedTickets: { Ticket }, maxPlayers: number): { Ticket }
	local chosen: { Ticket } = {}
	local total = 0
	for _, t in sortedTickets do
		if total + size(t) <= maxPlayers then
			table.insert(chosen, t)
			total += size(t)
		end
	end
	return chosen
end

local function makePlan(pool: PoolId, chosen: { Ticket }): Plan
	local plan: Plan = { pool = pool, ticketIds = {}, userIds = {}, duos = {} }
	for _, t in chosen do
		table.insert(plan.ticketIds, t.id)
		for _, userId in t.userIds do
			table.insert(plan.userIds, userId)
		end
		if size(t) == 2 then
			table.insert(plan.duos, { t.userIds[1], t.userIds[2] })
		end
	end
	return plan
end

-- Uma faixa (ou a mistura). Devolve a partida a montar agora (ou nil) e o estado para a tela.
function QueueRules.evaluatePool(
	pool: PoolId,
	tickets: { Ticket },
	now: number,
	p: Params,
	force: boolean?
): (Plan?, PoolStatus)
	local list = QueueRules.sorted(tickets)
	local count = countOf(list)
	if count == 0 then
		return nil, { count = 0, target = p.minPlayers, startsAt = nil }
	end

	if force and count >= p.flexibleMin then
		return makePlan(pool, take(list, p.maxPlayers)), { count = count, target = p.minPlayers, startsAt = now }
	end

	if count >= p.minPlayers then
		-- Horário em que a fila chegou a 7: a chegada mais recente entre as fichas que somam 7.
		local total, reachedAt = 0, -math.huge
		for _, t in list do
			total += size(t)
			reachedAt = math.max(reachedAt, t.enqueuedAt)
			if total >= p.minPlayers then
				break
			end
		end
		local startAt = reachedAt + p.fillWait
		if count >= p.maxPlayers or now >= startAt then
			return makePlan(pool, take(list, p.maxPlayers)), { count = count, target = p.maxPlayers, startsAt = now }
		end
		return nil, { count = count, target = p.maxPlayers, startsAt = startAt }
	end

	local oldest = math.huge
	for _, t in list do
		oldest = math.min(oldest, t.enqueuedAt)
	end
	local flexAt = oldest + p.flexibleAfter
	if count >= p.flexibleMin then
		if now >= flexAt then
			return makePlan(pool, list), { count = count, target = p.minPlayers, startsAt = now }
		end
		return nil, { count = count, target = p.minPlayers, startsAt = flexAt }
	end
	return nil, { count = count, target = p.minPlayers, startsAt = nil }
end

-- Faixa "passando fome": não junta 7 e a ficha mais antiga já esperou TierMergeAfterSeconds.
local function starving(tickets: { Ticket }, now: number, p: Params): boolean
	if #tickets == 0 or countOf(tickets) >= p.minPlayers then
		return false
	end
	local oldest = math.huge
	for _, t in tickets do
		oldest = math.min(oldest, t.enqueuedAt)
	end
	return now - oldest >= p.tierMergeAfter
end

-- A fila inteira: as partidas a montar agora e o estado de cada faixa.
function QueueRules.plan(tickets: { Ticket }, now: number, p: Params, force: boolean?): ({ Plan }, Status)
	local apprentices: { Ticket } = {}
	local experienced: { Ticket } = {}
	for _, t in tickets do
		table.insert(if t.tier == "Experientes" then experienced else apprentices, t)
	end
	local merged = #apprentices > 0
		and #experienced > 0
		and (starving(apprentices, now, p) or starving(experienced, now, p))

	local pools: { { id: PoolId, tickets: { Ticket }, tiers: { Tier } } } = {}
	if merged then
		local all = table.clone(apprentices)
		table.move(experienced, 1, #experienced, #all + 1, all)
		table.insert(pools, { id = "Mistura", tickets = all, tiers = { "Aprendizes", "Experientes" } })
	else
		table.insert(pools, { id = "Aprendizes", tickets = apprentices, tiers = { "Aprendizes" } })
		table.insert(pools, { id = "Experientes", tickets = experienced, tiers = { "Experientes" } })
	end

	local plans: { Plan } = {}
	local status: Status = { merged = merged, pools = {} }
	for _, pool in pools do
		local remaining = pool.tickets
		local poolStatus: PoolStatus = { count = 0, target = p.minPlayers, startsAt = nil }
		while true do
			local plan, st = QueueRules.evaluatePool(pool.id, remaining, now, p, force)
			poolStatus = st
			if plan == nil then
				break
			end
			table.insert(plans, plan)
			local used: { [string]: boolean } = {}
			for _, id in plan.ticketIds do
				used[id] = true
			end
			local rest: { Ticket } = {}
			for _, t in remaining do
				if not used[t.id] then
					table.insert(rest, t)
				end
			end
			remaining = rest
			force = false -- "começar já" monta uma partida só
		end
		for _, tier in pool.tiers do
			status.pools[tier] = poolStatus
		end
	end
	return plans, status
end

return QueueRules
