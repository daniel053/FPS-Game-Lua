--!strict
-- Cartas (FASES F4, GDD 8): números do GDD 8.4, cargas e recarga, escolha, ult na 4ª rodada,
-- geometria da Nuvem e do Tremor, e o bloqueio de uso em recarga ou de carta que não escolheu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CardConfig = require(Shared.Config.CardConfig)
local CardRules = require(Shared.Cards.CardRules)
local CardState = require(Shared.Cards.CardState)
local Strings = require(Shared.Config.Strings)

local function def(id: string): CardConfig.CardDef
	local found = CardConfig.get(id)
	assert(found, `carta {id} não existe`)
	return found
end

local function near(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) <= (tolerance or 1e-6)
end

local ALL_OWNED = {
	card_nuvem = true,
	card_impulso = true,
	card_tremor = true,
	card_renascer = true,
}

return function(t: any)
	t.test("as 4 cartas da v1 com tecla fixa e os números do GDD 8.4", function()
		t.eq(def("card_nuvem").key, "C")
		t.eq(def("card_impulso").key, "Q")
		t.eq(def("card_tremor").key, "E")
		t.eq(def("card_renascer").key, "X")
		t.ok(def("card_renascer").isUlt, "Renascer é ult")
		t.eq(def("card_nuvem").params.Radius, 8)
		t.eq(def("card_nuvem").params.Duration, 7)
		t.eq(def("card_nuvem").charges, 2)
		t.eq(def("card_impulso").params.LaunchHeight, 18)
		t.eq(def("card_impulso").cooldown, 20)
		t.eq(def("card_tremor").params.Length, 20)
		t.eq(def("card_tremor").params.Width, 6)
		t.eq(def("card_tremor").params.SlowPercent, 0.5)
		t.eq(def("card_tremor").params.DebuffDuration, 2)
		t.eq(def("card_tremor").params.Damage, 0)
		t.eq(def("card_tremor").cooldown, 25)
		t.eq(def("card_renascer").params.Window, 8)
		for _, id in CardConfig.StarterCards do
			t.ok(Strings.Cards[id] ~= nil, `nome de {id} em Strings`)
		end
	end)

	t.test("Nuvem: 2 cargas por rodada, sem recarga; volta cheia na rodada seguinte", function()
		local s = CardState.new(def("card_nuvem"))
		t.ok(CardState.use(s, 0), "1ª")
		t.ok(CardState.use(s, 1), "2ª")
		local ok, reason = CardState.use(s, 100)
		t.eq(ok, false)
		t.eq(reason, "noCharges")
		CardState.resetRound(s)
		t.eq(s.charges, 2)
	end)

	t.test("Impulso: 1 carga, volta depois de 20 s (nem um instante antes)", function()
		local s = CardState.new(def("card_impulso"))
		t.ok(CardState.use(s, 10))
		t.eq(CardState.use(s, 29.9), false, "ainda recarregando")
		t.ok(near(CardState.secondsToRecharge(s, 25), 5), "faltam 5 s")
		t.ok(CardState.use(s, 30), "recarregou")
	end)

	t.test("Tremor: recarga de 25 s", function()
		local s = CardState.new(def("card_tremor"))
		t.ok(CardState.use(s, 0))
		t.eq(CardState.use(s, 24.99), false)
		t.ok(CardState.use(s, 25))
	end)

	t.test("Renascer: 1 uso por rodada", function()
		local s = CardState.new(def("card_renascer"))
		t.eq(s.maxCharges, CardConfig.UltUsesPerRound)
		t.ok(CardState.use(s, 0))
		t.eq(CardState.use(s, 500), false)
	end)

	t.test("exploit: 10 pedidos de uma vez com 2 cargas = só 2 aceitos", function()
		local s = CardState.new(def("card_nuvem"))
		local accepted = 0
		for i = 1, 10 do
			if CardState.use(s, 5 + i * 0.001) then
				accepted += 1
			end
		end
		t.eq(accepted, 1, "o intervalo mínimo também segura (2ª fica para depois)")
		local accepted2 = 0
		for i = 1, 10 do
			if CardState.use(s, 10 + i) then
				accepted2 += 1
			end
		end
		t.eq(accepted2, 1, "só sobrava 1 carga")
	end)

	t.test("escolha: opções são as básicas que o jogador tem, na ordem C, Q, E", function()
		t.deepEq(CardRules.basicOptions(ALL_OWNED), { "card_nuvem", "card_impulso", "card_tremor" })
		t.deepEq(CardRules.basicOptions({ card_tremor = true, card_nuvem = true }), { "card_nuvem", "card_tremor" })
		t.deepEq(CardRules.basicOptions({}), {}, "sem cartas = sem opções")
		t.ok(CardRules.isBasicChoiceAllowed(ALL_OWNED, "card_impulso"))
		t.eq(CardRules.isBasicChoiceAllowed(ALL_OWNED, "card_renascer"), false, "ult não se escolhe")
		t.eq(CardRules.isBasicChoiceAllowed({ card_nuvem = true }, "card_tremor"), false, "carta que não tem")
		t.eq(CardRules.isBasicChoiceAllowed(ALL_OWNED, "card_inventada"), false)
		t.eq(CardRules.isBasicChoiceAllowed(ALL_OWNED, 42), false)
	end)

	t.test("ult travada até a 4ª rodada; só a carta escolhida vale", function()
		local ult = CardRules.ultOf(ALL_OWNED)
		t.eq(ult, "card_renascer")
		t.eq(CardRules.ultOf({ card_nuvem = true }), nil)
		for round = 1, 3 do
			t.eq(CardRules.ultUnlocked(round), false, `rodada {round}`)
			t.deepEq(CardRules.roundCards("card_tremor", ult, round), { E = "card_tremor" })
		end
		t.ok(CardRules.ultUnlocked(4))
		t.deepEq(CardRules.roundCards("card_tremor", ult, 4), { E = "card_tremor", X = "card_renascer" })
		t.deepEq(CardRules.roundCards(nil, ult, 7), { X = "card_renascer" }, "sem escolha: só a ult")
		t.deepEq(CardRules.roundCards(nil, nil, 7), {})
	end)

	t.test("Impulso: velocidade que leva a 18 studs de altura", function()
		local gravity = 196.2
		local v = CardRules.launchSpeed(18, gravity)
		t.ok(near(v * v / (2 * gravity), 18, 1e-6), "altura máxima")
	end)

	t.test("Nuvem: trajetória em arco, caindo com a gravidade", function()
		local path = CardRules.throwPath(Vector3.zero, Vector3.new(0, 20, -70), 196.2, 1, 0.1)
		t.eq(#path, 11)
		t.ok(path[#path].Z < -69, "andou para a frente")
		t.ok(path[#path].Y < path[3].Y, "desce no fim")
	end)

	t.test("Tremor: 20 × 6 à frente, nada atrás, dos lados ou em outra altura", function()
		local origin = Vector3.new(0, 0, 0)
		local dir = Vector3.new(0, 0.3, -1) -- olhando um pouco para cima: a onda segue no chão
		local L, W, H = 20, 6, 3
		t.ok((CardRules.inWave(origin, dir, L, W, H, Vector3.new(0, 0, -10))), "na frente")
		t.ok((CardRules.inWave(origin, dir, L, W, H, Vector3.new(2.9, 1, -19.9))), "na borda")
		t.eq((CardRules.inWave(origin, dir, L, W, H, Vector3.new(0, 0, 5))), false, "atrás")
		t.eq((CardRules.inWave(origin, dir, L, W, H, Vector3.new(3.2, 0, -10))), false, "fora da largura")
		t.eq((CardRules.inWave(origin, dir, L, W, H, Vector3.new(0, 0, -20.5))), false, "além do comprimento")
		t.eq((CardRules.inWave(origin, dir, L, W, H, Vector3.new(0, 8, -10))), false, "em cima de plataforma")
		local _, along = CardRules.inWave(origin, dir, L, W, H, Vector3.new(0, 0, -12))
		t.ok(near(along, 12), "distância ao longo da onda")
	end)

	t.test("Nuvem bloqueia a visão: segmento × esfera", function()
		local center, radius = Vector3.new(0, 0, -20), 8
		t.ok(CardRules.segmentHitsSphere(Vector3.zero, Vector3.new(0, 0, -40), center, radius), "atravessa")
		t.ok(CardRules.segmentHitsSphere(Vector3.zero, Vector3.new(0, 0, -15), center, radius), "termina dentro")
		t.eq(CardRules.segmentHitsSphere(Vector3.zero, Vector3.new(20, 0, -40), center, radius), false, "passa do lado")
		t.eq(CardRules.segmentHitsSphere(Vector3.zero, Vector3.new(0, 0, -5), center, radius), false, "para antes")
	end)

	t.test("direção do cliente: só vetor finito com tamanho perto de 1", function()
		t.ok(CardRules.readDirection(Vector3.new(0, 0, -1)) ~= nil)
		t.eq(CardRules.readDirection(Vector3.new(0, 0, -50)), nil, "comprida demais")
		t.eq(CardRules.readDirection(Vector3.zero), nil)
		t.eq(CardRules.readDirection(Vector3.new(0 / 0, 0, 1)), nil, "NaN")
		t.eq(CardRules.readDirection("frente"), nil)
	end)
end
