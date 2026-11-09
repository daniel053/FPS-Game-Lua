--!strict
-- FASES F3: regras da partida com partidas simuladas do começo ao campeão.
--   * partida completa com 4, 7, 8 e 16 jogadores;
--   * Virada uma vez só, na rodada seguinte à primeira dupla com 1 vida, +1 vida com teto 5;
--   * jogador ímpar joga sozinho, sem bônus;
--   * folga gira e nunca repete antes de todos;
--   * armas certas em cada rodada; primária só a partir da 3ª.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local LoadoutRules = require(Shared.Match.LoadoutRules)
local MatchConfig = require(Shared.Config.MatchConfig)
local MatchRules = require(Shared.Match.MatchRules)
local TeamColors = require(Shared.Config.TeamColors)

local ISLANDS = 4
local MAX_ROUNDS = 300

type SimResult = {
	rounds: number,
	champion: string?,
	viradaRounds: { number },
	errors: { string },
	teamSizes: { number },
}

local function makeMembers(count: number): { MatchRules.MemberInfo }
	local list = {}
	for i = 1, count do
		table.insert(list, { key = `m{i}`, elo = (i * 37) % 101 })
	end
	return list
end

local function noFriends(_a: string, _b: string): boolean
	return false
end

-- Simula uma partida inteira com resultados sorteados (inclui empates).
local function simulate(playerCount: number, seed: number): SimResult
	local rng = Random.new(seed)
	local groups = MatchRules.formTeams(makeMembers(playerCount), {}, noFriends)
	local ids = {}
	local sizes = {}
	for i, group in groups do
		table.insert(ids, TeamColors.Order[i])
		table.insert(sizes, #group)
	end
	local state = MatchRules.newState(ids, ISLANDS)
	local result: SimResult = { rounds = 0, champion = nil, viradaRounds = {}, errors = {}, teamSizes = sizes }
	local function fail(message: string)
		table.insert(result.errors, `[{playerCount} jogadores, semente {seed}, rodada {state.round}] {message}`)
	end

	local byeSeen: { [string]: boolean } = {}
	local viradaExpected = false
	while state.championId == nil and state.round < MAX_ROUNDS do
		local alive = MatchRules.aliveTeams(state)
		local plan = MatchRules.planRound(state, rng)

		-- Virada no momento certo
		if viradaExpected and not plan.isFinal and not plan.isVirada then
			fail("a Virada deveria ser esta rodada")
		end
		if plan.isVirada then
			table.insert(result.viradaRounds, plan.round)
		end
		viradaExpected = false

		-- Todo vivo joga exatamente uma vez, ou está de folga
		local seen: { [string]: number } = {}
		for _, duel in plan.duels do
			seen[duel.a] = (seen[duel.a] or 0) + 1
			seen[duel.b] = (seen[duel.b] or 0) + 1
		end
		if plan.bye then
			seen[plan.bye] = (seen[plan.bye] or 0) + 1
		end
		for _, id in alive do
			if seen[id] ~= 1 then
				fail(`dupla {id} aparece {seen[id] or 0} vezes`)
			end
		end
		if (#alive % 2 == 1) ~= (plan.bye ~= nil) then
			fail("folga errada para o número de duplas")
		end
		if #plan.duels > ISLANDS then
			fail("mais duelos que ilhas")
		end
		local islands: { [number]: boolean } = {}
		for _, duel in plan.duels do
			if islands[duel.island] then
				fail("duas duplas na mesma ilha")
			end
			islands[duel.island] = true
		end

		-- Folga gira e nunca repete antes de todos
		if plan.bye then
			if byeSeen[plan.bye] then
				for _, id in alive do
					if not byeSeen[id] then
						fail(`folga repetida para {plan.bye} antes de {id}`)
					end
				end
				byeSeen = {}
			end
			byeSeen[plan.bye] = true
		end

		local outcomes: { MatchRules.DuelOutcome } = {}
		for i, duel in plan.duels do
			local roll = rng:NextNumber()
			outcomes[i] = { winner = if roll < 0.45 then duel.a elseif roll < 0.9 then duel.b else nil }
		end
		local before: { [string]: number } = {}
		for id, team in state.teams do
			before[id] = team.lives
		end
		local report = MatchRules.finishRound(state, plan, outcomes)

		-- Vidas: perdeu = -1; Virada: venceu = +1 até 5; folga e empate não mudam; nunca passa de 5
		if not plan.isFinal then
			for i, duel in plan.duels do
				local winner = outcomes[i].winner
				for _, id in { duel.a, duel.b } do
					local expected = before[id]
					if winner ~= nil and winner ~= id then
						expected = math.max(0, expected - 1)
					elseif winner == id and plan.isVirada then
						expected = math.min(MatchConfig.MaxLives, expected + 1)
					end
					if state.teams[id].lives ~= expected then
						fail(`vidas de {id}: {state.teams[id].lives}, esperado {expected}`)
					end
				end
			end
			if plan.bye and state.teams[plan.bye].lives ~= before[plan.bye] then
				fail("a dupla de folga mudou de vida")
			end
		end
		for _, team in state.teams do
			if team.lives > MatchConfig.MaxLives then
				fail(`{team.id} passou de {MatchConfig.MaxLives} vidas`)
			end
		end
		if report.viradaNext then
			viradaExpected = true
		end
	end
	result.rounds = state.round
	result.champion = state.championId
	if #result.viradaRounds > 1 then
		fail("Virada aconteceu mais de uma vez")
	end
	return result
end

return function(t: any)
	for _, count in { 4, 7, 8, 16 } do
		t.test(`partida completa com {count} jogadores (50 partidas simuladas)`, function()
			for seed = 1, 50 do
				local result = simulate(count, seed)
				t.ok(result.champion ~= nil, `{count} jogadores, semente {seed}: sem campeã em {MAX_ROUNDS} rodadas`)
				t.eq(#result.errors, 0, result.errors[1])
			end
		end)
	end

	t.test("duplas: 4 → 2, 7 → 3 + 1 sozinho, 8 → 4, 16 → 8", function()
		local function sizes(count: number): (number, number)
			local groups = MatchRules.formTeams(makeMembers(count), {}, noFriends)
			local solos = 0
			for _, g in groups do
				if #g == 1 then
					solos += 1
				end
			end
			return #groups, solos
		end
		local teams4, solos4 = sizes(4)
		t.eq(teams4, 2)
		t.eq(solos4, 0)
		local teams7, solos7 = sizes(7)
		t.eq(teams7, 4)
		t.eq(solos7, 1)
		local teams8 = sizes(8)
		t.eq(teams8, 4)
		local teams16 = sizes(16)
		t.eq(teams16, 8)
	end)

	t.test("jogador ímpar joga sozinho, com as mesmas vidas e sem bônus", function()
		local groups = MatchRules.formTeams(makeMembers(7), {}, noFriends)
		local ids = {}
		for i in groups do
			table.insert(ids, TeamColors.Order[i])
		end
		local state = MatchRules.newState(ids, ISLANDS)
		for _, team in state.teams do
			t.eq(team.lives, MatchConfig.StartingLives)
		end
		t.eq(MatchConfig.SoloPlayerBonus, false)
	end)

	t.test("o sozinho é o de maior elo entre os sem par", function()
		local members = {
			{ key = "a", elo = 10 },
			{ key = "b", elo = 50 },
			{ key = "c", elo = 30 },
		}
		local groups = MatchRules.formTeams(members, {}, noFriends)
		t.eq(#groups, 2)
		t.deepEq(groups[1], { "b" })
		t.deepEq(groups[2], { "c", "a" })
	end)

	t.test("prioridade: dupla fixa, depois amigos, depois elo parecido", function()
		local members = {
			{ key = "a", elo = 100 },
			{ key = "b", elo = 90 },
			{ key = "c", elo = 80 },
			{ key = "d", elo = 70 },
			{ key = "e", elo = 60 },
			{ key = "f", elo = 50 },
		}
		local groups = MatchRules.formTeams(members, { { "a", "f" } }, function(x: string, y: string): boolean
			return (x == "b" and y == "e") or (x == "e" and y == "b")
		end)
		t.deepEq(groups[1], { "a", "f" }, "dupla fixa")
		t.deepEq(groups[2], { "b", "e" }, "amigos")
		t.deepEq(groups[3], { "c", "d" }, "elo parecido")
	end)

	t.test("2 jogadores (só em teste): cada um vira uma dupla", function()
		local groups = MatchRules.formTeams(makeMembers(2), {}, noFriends)
		t.eq(#groups, 2)
	end)

	t.test("Virada: na rodada seguinte à 1ª dupla com 1 vida; vencedor +1 até 5", function()
		local state = MatchRules.newState({ "Azul", "Laranja", "Verde", "Roxo" }, ISLANDS)
		local rng = Random.new(7)
		-- Azul perde até ficar com 1 vida
		while state.teams.Azul.lives > 1 do
			local plan = MatchRules.planRound(state, rng)
			t.ok(not plan.isVirada, "Virada antes da hora")
			local outcomes = {}
			for i, duel in plan.duels do
				local loser = if duel.a == "Azul" or duel.b == "Azul" then "Azul" else duel.b
				outcomes[i] = { winner = if loser == duel.a then duel.b else duel.a }
			end
			MatchRules.finishRound(state, plan, outcomes)
		end
		t.ok(state.viradaPending, "Virada não ficou marcada")
		local virada = MatchRules.planRound(state, rng)
		t.ok(virada.isVirada, "a rodada seguinte não é a Virada")
		local before = {}
		for id, team in state.teams do
			before[id] = team.lives
		end
		local outcomes = {}
		for i, duel in virada.duels do
			outcomes[i] = { winner = duel.a }
		end
		MatchRules.finishRound(state, virada, outcomes)
		for _, duel in virada.duels do
			t.eq(state.teams[duel.a].lives, math.min(5, before[duel.a] + 1), "vencedor da Virada")
			t.eq(state.teams[duel.b].lives, math.max(0, before[duel.b] - 1), "perdedor da Virada")
		end
		-- Nunca mais
		for _ = 1, 10 do
			if state.championId or state.finalMode then
				break
			end
			local plan = MatchRules.planRound(state, rng)
			t.ok(not plan.isVirada, "Virada repetida")
			local o = {}
			for i, duel in plan.duels do
				o[i] = { winner = duel.a }
			end
			MatchRules.finishRound(state, plan, o)
		end
	end)

	t.test("final: com 2 duplas vence quem fizer 2 rodadas; vidas não contam", function()
		local state = MatchRules.newState({ "Azul", "Laranja" }, ISLANDS)
		t.ok(state.finalMode, "2 duplas = final desde o começo")
		local rng = Random.new(3)
		local plan = MatchRules.planRound(state, rng)
		MatchRules.finishRound(state, plan, { { winner = "Azul" } })
		t.eq(state.championId, nil)
		t.eq(state.teams.Azul.lives, MatchConfig.StartingLives, "vidas não mudam na final")
		t.eq(state.teams.Laranja.lives, MatchConfig.StartingLives, "vidas não mudam na final")
		plan = MatchRules.planRound(state, rng)
		MatchRules.finishRound(state, plan, { { winner = nil } }) -- empate: ninguém pontua
		t.eq(state.championId, nil)
		plan = MatchRules.planRound(state, rng)
		MatchRules.finishRound(state, plan, { { winner = "Azul" } })
		t.eq(state.championId, "Azul")
		t.eq(state.teams.Laranja.placement, 2)
	end)

	t.test("tempo esgotado: mais HP + escudo vence; empate exato = ninguém", function()
		t.eq(MatchRules.timeoutWinner("a", 120, "b", 80), "a")
		t.eq(MatchRules.timeoutWinner("a", 10, "b", 80), "b")
		t.eq(MatchRules.timeoutWinner("a", 50, "b", 50), nil)
	end)

	t.test("os dois saíram: dupla eliminada", function()
		local state = MatchRules.newState({ "Azul", "Laranja", "Verde" }, ISLANDS)
		local report = MatchRules.forfeit(state, "Verde")
		t.ok(state.teams.Verde.eliminated)
		t.eq(report.eliminated[1], "Verde")
		t.ok(state.finalMode, "com 2 duplas vivas começa a final")
	end)

	t.test("armas por rodada (GDD 7.2.2): primária só a partir da 3ª", function()
		for round = 1, 2 do
			local options = LoadoutRules.options(round)
			t.eq(#options.primaries, 0, `rodada {round} tem primária`)
			t.eq(options.phaseId, "pistolas")
			t.ok(table.find(options.secondaries, "weapon_tambor") == nil, "Tambor antes da 3ª")
			local primary, secondary = LoadoutRules.resolve(options, { primary = "weapon_rajada" }, nil, nil)
			t.eq(primary, nil, "primária aceita na rodada de pistola")
			t.ok(table.find(options.secondaries, secondary) ~= nil)
		end
		local medias = LoadoutRules.options(3)
		t.eq(medias.phaseId, "medias")
		t.ok(table.find(medias.primaries, "weapon_vespa") ~= nil)
		t.ok(table.find(medias.primaries, "weapon_rajada") == nil, "pesada na 3ª")
		t.ok(table.find(medias.secondaries, "weapon_tambor") ~= nil, "Tambor na 3ª")
		for round = 4, 9 do
			local pesadas = LoadoutRules.options(round)
			t.eq(pesadas.phaseId, "pesadas")
			t.ok(table.find(pesadas.primaries, "weapon_vespa") == nil, "média na fase pesada")
			t.ok(table.find(pesadas.primaries, "weapon_luneta") ~= nil)
		end
	end)

	t.test("sem escolha: anterior, depois a do perfil, depois a primeira da lista", function()
		local options = LoadoutRules.options(4)
		local p1 = LoadoutRules.resolve(options, nil, { primary = "weapon_trovao", secondary = "weapon_precisa" }, nil)
		t.eq(p1, "weapon_trovao", "mantém a anterior")
		local p2 = LoadoutRules.resolve(
			options,
			nil,
			{ primary = "weapon_vespa" },
			{ lastPrimaryByPhase = { pesadas = "weapon_luneta" }, lastSecondary = nil }
		)
		t.eq(p2, "weapon_luneta", "anterior inválida: usa a do perfil")
		local p3, s3 = LoadoutRules.resolve(options, nil, nil, nil)
		t.eq(p3, options.primaries[1], "nada: primeira da lista")
		t.eq(s3, options.secondaries[1])
		local p4, s4 =
			LoadoutRules.resolve(options, { primary = "weapon_gemea", secondary = "weapon_tambor" }, nil, nil)
		t.eq(p4, "weapon_gemea")
		t.eq(s4, "weapon_tambor")
	end)
end
