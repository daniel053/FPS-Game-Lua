--!strict
-- FASES F5: regras da fila (GDD 6.2 e 6.3), sem servidor.
--   * começa com 7, espera até 16 por 15 s, flexível a partir de 4 após 20 s (2 após 5 s em teste);
--   * faixas separadas, que se juntam quando uma não junta 7 em 45 s;
--   * dupla fixa nunca é separada e entra na faixa do maior elo;
--   * quem voltou porque a partida não aconteceu passa na frente.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local QueueConfig = require(Shared.Config.QueueConfig)
local QueueRules = require(Shared.Queue.QueueRules)

type Ticket = QueueRules.Ticket

local PROD = QueueRules.params(false)
local DEV = QueueRules.params(true)

local nextUser = 0

local function solo(at: number, tier: QueueRules.Tier?): Ticket
	nextUser += 1
	return { id = `s{nextUser}`, userIds = { nextUser }, tier = tier or "Aprendizes", enqueuedAt = at, priority = false }
end

local function duo(at: number, tier: QueueRules.Tier?): Ticket
	nextUser += 2
	return {
		id = `d{nextUser}`,
		userIds = { nextUser - 1, nextUser },
		tier = tier or "Aprendizes",
		enqueuedAt = at,
		priority = false,
	}
end

local function solos(count: number, at: number, tier: QueueRules.Tier?): { Ticket }
	local list = {}
	for _ = 1, count do
		table.insert(list, solo(at, tier))
	end
	return list
end

local function playersIn(plans: { QueueRules.Plan }): number
	local n = 0
	for _, plan in plans do
		n += #plan.userIds
	end
	return n
end

return function(t: any)
	t.test("valores do GDD 6.2 e 6.3 na config", function()
		t.eq(QueueConfig.MinPlayersToStart, 7)
		t.eq(QueueConfig.FillWaitSeconds, 15)
		t.eq(QueueConfig.MaxPlayers, 16)
		t.eq(QueueConfig.FlexibleAfterSeconds, 20)
		t.eq(QueueConfig.FlexibleMinPlayers, 4)
		t.eq(QueueConfig.TierMergeAfterSeconds, 45)
		t.eq(PROD.flexibleMin, 4)
		t.ok(DEV.flexibleMin < PROD.flexibleMin, "em teste o mínimo flexível é menor")
		t.eq(DEV.flexibleAfter, 5, "em teste a fila começa em 5 s")
		t.eq(PROD.flexibleAfter, 20)
	end)

	t.test("7 jogadores: espera 15 s para completar, depois sai com 7", function()
		local queue = solos(7, 0)
		local plans, status = QueueRules.plan(queue, 14.9, PROD)
		t.eq(#plans, 0)
		t.eq(status.pools.Aprendizes.count, 7)
		t.eq(status.pools.Aprendizes.target, 16)
		t.eq(status.pools.Aprendizes.startsAt, 15)
		plans = QueueRules.plan(queue, 15, PROD)
		t.eq(#plans, 1)
		t.eq(#plans[1].userIds, 7)
	end)

	t.test("os 15 s contam a partir do 7º jogador", function()
		local queue = solos(6, 0)
		table.insert(queue, solo(30))
		t.eq(#QueueRules.plan(queue, 44, PROD), 0)
		t.eq(#QueueRules.plan(queue, 45, PROD), 1)
	end)

	t.test("16 jogadores: sai na hora", function()
		local plans = QueueRules.plan(solos(16, 0), 0, PROD)
		t.eq(#plans, 1)
		t.eq(#plans[1].userIds, 16)
	end)

	t.test("20 na fila: sai uma partida de 16 e os 4 seguintes continuam esperando", function()
		local queue = solos(16, 0)
		local late = solos(4, 5)
		table.move(late, 1, 4, #queue + 1, queue)
		local plans, status = QueueRules.plan(queue, 5, PROD)
		t.eq(#plans, 1)
		t.eq(#plans[1].userIds, 16)
		for _, ticket in late do
			t.ok(table.find(plans[1].ticketIds, ticket.id) == nil, "quem chegou depois espera a próxima")
		end
		t.eq(status.pools.Aprendizes.count, 4)
	end)

	t.test("poucos jogadores: com 3, em teste sai aos 5 s (mínimo 2); em produção não sai (mínimo 4)", function()
		local queue = solos(3, 0)
		t.eq(#QueueRules.plan(queue, 4.9, DEV), 0)
		local devPlans = QueueRules.plan(queue, 5, DEV)
		t.eq(#devPlans, 1)
		t.eq(#devPlans[1].userIds, 3)
		t.eq(#QueueRules.plan(queue, 600, PROD), 0, "em produção o mínimo é 4")
	end)

	t.test("4 jogadores em produção: começa aos 20 s", function()
		local queue = solos(4, 0)
		t.eq(#QueueRules.plan(queue, 19.9, PROD), 0)
		local plans = QueueRules.plan(queue, 20, PROD)
		t.eq(#plans, 1)
		t.eq(#plans[1].userIds, 4)
	end)

	t.test("dupla fixa nunca é separada e vira dupla na partida", function()
		local queue = solos(15, 0)
		local pair = duo(1)
		table.insert(queue, pair)
		local plans = QueueRules.plan(queue, 1, PROD) -- 17 na fila: passa de 16, sai na hora
		t.eq(#plans, 1)
		t.ok(table.find(plans[1].ticketIds, pair.id) == nil, "a dupla não cabe inteira: fica para a próxima")
		t.eq(#plans[1].userIds, 15)

		local small = { duo(0), duo(0), solo(0), solo(0), solo(0) }
		local plans2 = QueueRules.plan(small, 15, PROD)
		t.eq(#plans2, 1)
		t.eq(#plans2[1].duos, 2)
		t.eq(#plans2[1].userIds, 7)
	end)

	t.test("faixas separadas quando cada uma junta 7", function()
		local queue = solos(7, 0, "Aprendizes")
		table.move(solos(7, 0, "Experientes"), 1, 7, 8, queue)
		local plans, status = QueueRules.plan(queue, 15, PROD)
		t.eq(#plans, 2)
		t.ok(not status.merged)
		for _, plan in plans do
			t.eq(#plan.userIds, 7)
			t.ok(plan.pool ~= "Mistura")
		end
	end)

	t.test("faixa sem 7 em 45 s junta com a outra", function()
		-- 3 + 3: nenhuma faixa chega ao mínimo flexível (4) sozinha
		local queue = solos(3, 0, "Experientes")
		table.move(solos(3, 10, "Aprendizes"), 1, 3, 4, queue)
		local plans, status = QueueRules.plan(queue, 44, PROD)
		t.ok(not status.merged)
		t.eq(#plans, 0)
		local _, statusBefore = QueueRules.plan(queue, 44, PROD)
		t.eq(statusBefore.pools.Experientes.count, 3)
		plans, status = QueueRules.plan(queue, 45, PROD)
		t.ok(status.merged, "juntou as faixas")
		-- Juntas são 6 (4 ou mais) e já passaram dos 20 s: sai na hora.
		t.eq(#plans, 1)
		t.eq(plans[1].pool, "Mistura")
		t.eq(#plans[1].userIds, 6)

		-- Juntas com menos de 4: não sai, e as duas faixas mostram a mesma contagem
		local few = solos(2, 0, "Experientes")
		table.insert(few, solo(0, "Aprendizes"))
		local fewPlans, st = QueueRules.plan(few, 50, PROD)
		t.eq(#fewPlans, 0)
		t.ok(st.merged)
		t.eq(st.pools.Aprendizes.count, 3)
		t.eq(st.pools.Experientes.count, 3)
	end)

	t.test("faixa da dupla: a do maior elo; conta nova é Aprendiz", function()
		local novato = { points = 0, matchesPlayed = 2 }
		local ouroNovo = { points = 2500, matchesPlayed = 3 }
		local ouro = { points = 2500, matchesPlayed = 30 }
		local prata = { points = 1500, matchesPlayed = 30 }
		t.eq(QueueRules.tierOf(novato), "Aprendizes")
		t.eq(QueueRules.tierOf(ouroNovo), "Aprendizes", "menos de 10 partidas")
		t.eq(QueueRules.tierOf(prata), "Aprendizes")
		t.eq(QueueRules.tierOf(ouro), "Experientes")
		t.eq(QueueRules.groupTier({ novato, ouro }), "Experientes")
		t.eq(QueueRules.groupTier({ novato, prata }), "Aprendizes")
		t.eq(QueueRules.rankTierOf(0), "Bronze")
		t.eq(QueueRules.rankTierOf(5000), "Deus")
	end)

	t.test("quem voltou porque a partida não aconteceu passa na frente", function()
		local queue = solos(16, 0)
		local back = solo(10)
		back.priority = true
		table.insert(queue, back)
		local plans = QueueRules.plan(queue, 10, PROD)
		t.eq(#plans, 1)
		t.ok(table.find(plans[1].ticketIds, back.id) ~= nil)
	end)

	t.test("começar já (painel TESTE): monta uma partida com quem houver, respeitando o mínimo", function()
		t.eq(#QueueRules.plan({ solo(0) }, 0, DEV, true), 0, "1 jogador não monta partida")
		local plans = QueueRules.plan(solos(2, 0), 0, DEV, true)
		t.eq(#plans, 1)
		t.eq(playersIn(plans), 2)
	end)

	t.test("simulação: ninguém aparece em duas partidas e nenhuma passa de 16", function()
		local rng = Random.new(7)
		for _ = 1, 30 do
			local queue: { Ticket } = {}
			for _ = 1, rng:NextInteger(1, 40) do
				local at = rng:NextNumber(0, 90)
				local tier: QueueRules.Tier = if rng:NextNumber() < 0.5 then "Aprendizes" else "Experientes"
				table.insert(queue, if rng:NextNumber() < 0.3 then duo(at, tier) else solo(at, tier))
			end
			local plans = QueueRules.plan(queue, 120, PROD)
			local seen: { [number]: boolean } = {}
			for _, plan in plans do
				t.ok(#plan.userIds <= 16 and #plan.userIds >= 4, `partida com {#plan.userIds}`)
				for _, userId in plan.userIds do
					t.ok(not seen[userId], "jogador em duas partidas")
					seen[userId] = true
				end
			end
		end
	end)
end
