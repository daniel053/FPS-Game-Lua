--!strict
-- [BOTS] Bots de preenchimento (docs/BOTS.md), sem servidor:
--   * na fila, ninguém espera mais que BotConfig.Queue.StartAfterSeconds; a contagem sobe com os bots e
--     gente de verdade ocupa a vaga antes do bot; sem bots, a fila é a mesma de antes;
--   * a sala é completada até FillTo; os bots erram mais de longe, andando e nos primeiros tiros;
--   * nomes sem repetir, armas e cartas sempre válidas para a rodada.
-- Para remover os bots, apague este arquivo junto (docs/BOTS.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local BotConfig = require(Shared.Config.BotConfig)
local BotRules = require(Shared.Bots.BotRules)
local CardConfig = require(Shared.Config.CardConfig)
local LoadoutRules = require(Shared.Match.LoadoutRules)
local QueueRules = require(Shared.Queue.QueueRules)
local Strings = require(Shared.Config.Strings)

type Ticket = QueueRules.Ticket

local BOTS = QueueRules.params(false, true)
local DEV_BOTS = QueueRules.params(true, true)
local START = BotConfig.Queue.StartAfterSeconds
local FILL = BotConfig.Queue.FillTo

local nextUser = 5000

local function solo(at: number): Ticket
	nextUser += 1
	return { id = `b{nextUser}`, userIds = { nextUser }, tier = "Aprendizes", enqueuedAt = at, priority = false }
end

local function solos(count: number, at: number): { Ticket }
	local list = {}
	for _ = 1, count do
		table.insert(list, solo(at))
	end
	return list
end

return function(t: any)
	t.test("sem bots, a fila não muda (params sem bots)", function()
		t.eq(QueueRules.params(false).bots, nil)
		t.eq(QueueRules.params(true).bots, nil)
		local plans, status = QueueRules.plan(solos(1, 0), 600, QueueRules.params(false))
		t.eq(#plans, 0, "1 jogador sozinho continua esperando gente de verdade")
		t.eq(status.pools.Aprendizes.count, 1)
	end)

	t.test("1 jogador: o primeiro bot aparece aos 10 s e a partida sai no tempo máximo", function()
		local queue = solos(1, 0)
		local _, status = QueueRules.plan(queue, 9.9, BOTS)
		t.eq(status.pools.Aprendizes.count, 1, "antes de 10 s, só gente")
		_, status = QueueRules.plan(queue, 10, BOTS)
		t.eq(status.pools.Aprendizes.count, 2, "aos 10 s entra o primeiro bot")
		t.eq(status.pools.Aprendizes.startsAt, START, "a tela já sabe quando sai")
		local plans = QueueRules.plan(queue, START - 0.1, BOTS)
		t.eq(#plans, 0)
		plans = QueueRules.plan(queue, START, BOTS)
		t.eq(#plans, 1)
		t.eq(#plans[1].userIds, 1)
		t.eq(plans[1].fillBots, true, "a partida completa com bots")
	end)

	t.test("a contagem sobe com o tempo e não chega na sala cheia antes de sair", function()
		local queue = solos(1, 0)
		local last = 0
		for second = 0, START - 1 do
			local _, status = QueueRules.plan(queue, second, BOTS)
			local count = status.pools.Aprendizes.count
			t.ok(count >= last, `contagem não desce (aos {second} s)`)
			t.ok(count < FILL, `sala cheia só quando a partida sai (aos {second} s)`)
			last = count
		end
		t.ok(last >= FILL / 2, "perto do fim, a sala já parece quase cheia")
	end)

	t.test("gente de verdade ocupa a vaga do bot", function()
		local queue = solos(5, 0)
		local _, status = QueueRules.plan(queue, 10, BOTS)
		t.eq(status.pools.Aprendizes.count, 5, "5 pessoas: os 2 lugares dos 10 s já estão ocupados")
		local plans = QueueRules.plan(queue, START, BOTS)
		t.eq(#plans, 1)
		t.eq(#plans[1].userIds, 5)
	end)

	t.test("as regras normais continuam valendo e também completam com bots", function()
		local queue = solos(4, 0)
		local plans = QueueRules.plan(queue, 20, BOTS) -- flexível: 4 pessoas aos 20 s
		t.eq(#plans, 1)
		t.eq(plans[1].fillBots, true)
		local full = QueueRules.plan(solos(16, 0), 0, BOTS)
		t.eq(#full, 1)
		t.eq(#full[1].userIds, 16)
	end)

	t.test("ninguém espera mais que o tempo máximo, mesmo com 7 esperando completar", function()
		local queue = solos(6, 0)
		table.insert(queue, solo(30)) -- o 7º chega aos 30 s: sem bots sairia aos 45 s
		t.eq(#QueueRules.plan(queue, START - 0.1, BOTS), 0)
		local plans = QueueRules.plan(queue, START, BOTS)
		t.eq(#plans, 1)
		t.eq(#plans[1].userIds, 7)
	end)

	t.test("o tempo conta de quem chegou primeiro", function()
		local queue = solos(1, 0)
		table.insert(queue, solo(20))
		local plans = QueueRules.plan(queue, START, BOTS)
		t.eq(#plans, 1)
		t.eq(#plans[1].userIds, 2, "quem chegou depois vai junto")
	end)

	t.test("teste: COMEÇAR JÁ funciona com 1 pessoa quando há bots", function()
		local plans = QueueRules.plan(solos(1, 0), 0, DEV_BOTS, true)
		t.eq(#plans, 1)
		t.eq(plans[1].fillBots, true)
	end)

	t.test("vagas da rampa e bots para completar", function()
		local q = BotRules.queueParams()
		t.eq(BotRules.seatsShown(0, q), 0)
		t.eq(BotRules.seatsShown(START, q), FILL)
		t.eq(BotRules.seatsShown(1000, q), FILL, "nunca passa da sala cheia")
		t.eq(BotRules.botsToFill(1, 16), 15)
		t.eq(BotRules.botsToFill(16, 16), 0)
		t.eq(BotRules.botsToFill(20, 16), 0, "nunca negativo")
	end)

	t.test("mira: erra mais de longe, andando, com o alvo andando e nos primeiros tiros", function()
		local skill = BotConfig.Skill
		local base = { distance = 20, moving = false, targetMoving = false, vsBot = false, shotsAtTarget = 99 }
		local function err(changes: { [string]: any }): number
			local input = table.clone(base)
			for k, v in changes do
				(input :: any)[k] = v
			end
			return BotRules.aimErrorDegrees(skill, input :: any)
		end
		local normal = err({})
		t.ok(err({ distance = 60 }) > normal, "mais longe, mais erro")
		t.ok(err({ moving = true }) > normal, "andando, mais erro")
		t.ok(err({ targetMoving = true }) > normal, "alvo andando, mais erro")
		t.ok(err({ shotsAtTarget = 0 }) > normal, "primeiros tiros erram mais")
		t.ok(err({ vsBot = true }) < normal, "bot contra bot acaba mais rápido")
		t.ok(normal >= 4, "bot ruim: nunca mira perfeito")
		t.ok(BotRules.damageMultiplier(skill, false) < 1, "dano menor contra jogadores")
	end)

	t.test("nomes de jogador sem repetir", function()
		local rng = Random.new(7)
		local used = {}
		local seen = {}
		for _ = 1, 16 do
			local name = BotRules.makeName(Strings.Bots, rng, used)
			t.ok(#name >= 3, "nome com pelo menos 3 letras")
			t.ok(not seen[name], `nome repetido: {name}`)
			seen[name] = true
		end
	end)

	t.test("armas e cartas do bot sempre valem para a rodada", function()
		local rng = Random.new(3)
		for round = 1, 8 do
			local options = LoadoutRules.options(round)
			for _ = 1, 20 do
				local primary, secondary = BotRules.pickLoadout(options.primaries, options.secondaries, rng)
				if #options.primaries > 0 then
					t.ok(LoadoutRules.isPrimaryAllowed(options, primary), `primária da rodada {round}`)
				else
					t.eq(primary, nil, `sem primária na rodada {round}`)
				end
				t.ok(LoadoutRules.isSecondaryAllowed(options, secondary), `pistola da rodada {round}`)
			end
		end
		for _ = 1, 20 do
			local basic, ult = BotRules.pickCards(rng)
			local basicDef = basic and CardConfig.get(basic)
			local ultDef = ult and CardConfig.get(ult)
			t.ok(basicDef ~= nil and not basicDef.isUlt, "carta básica")
			t.ok(ultDef ~= nil and ultDef.isUlt, "ult")
		end
	end)
end
