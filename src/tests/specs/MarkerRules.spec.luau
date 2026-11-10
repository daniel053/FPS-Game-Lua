--!strict
-- GDD 7.6: marcação de aliado e inimigo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarkerRules = require(ReplicatedStorage.Shared.Combat.MarkerRules)

local function input(overrides: { [string]: any }): MarkerRules.Input
	local base: { [string]: any } = {
		isSelf = false,
		alive = true,
		isPartner = false,
		sameIsland = true,
		anyPartVisible = true,
		behindSmoke = false,
		viewerOnMirante = false,
		targetOnIsland = true,
	}
	for k, v in overrides do
		base[k] = v
	end
	return (base :: any) :: MarkerRules.Input
end

return function(t: any)
	t.test("inimigo à vista: contorno e barra vermelhos, sem nome", function()
		local s = MarkerRules.decide(input({}))
		t.eq(s.outline, "Enemy")
		t.eq(s.bar, "Enemy")
		t.eq(s.name, "None")
	end)

	t.test("inimigo atrás da parede: nada", function()
		local s = MarkerRules.decide(input({ anyPartVisible = false }))
		t.deepEq(s, { outline = "None", bar = "None", name = "None" })
	end)

	t.test("inimigo atrás da Nuvem: nada", function()
		local s = MarkerRules.decide(input({ behindSmoke = true }))
		t.deepEq(s, { outline = "None", bar = "None", name = "None" })
	end)

	t.test("aliado à vista: barra verde e nome, sem contorno", function()
		local s = MarkerRules.decide(input({ isPartner = true }))
		t.deepEq(s, { outline = "None", bar = "Ally", name = "Ally" })
	end)

	t.test("aliado com o corpo todo escondido: só a silhueta verde", function()
		local s = MarkerRules.decide(input({ isPartner = true, anyPartVisible = false }))
		t.deepEq(s, { outline = "AllySilhouette", bar = "None", name = "None" })
	end)

	t.test("outra ilha, derrubado ou eu mesmo: nada", function()
		t.eq(MarkerRules.decide(input({ sameIsland = false })).outline, "None")
		t.eq(MarkerRules.decide(input({ isPartner = true, sameIsland = false })).bar, "None")
		t.eq(MarkerRules.decide(input({ alive = false })).bar, "None")
		t.eq(MarkerRules.decide(input({ isSelf = true })).outline, "None")
	end)

	t.test("do mirante: só o nome na cor da equipe de quem duela", function()
		local s = MarkerRules.decide(input({ viewerOnMirante = true, sameIsland = false }))
		t.deepEq(s, { outline = "None", bar = "None", name = "Team" })
		local other = MarkerRules.decide(input({ viewerOnMirante = true, targetOnIsland = false }))
		t.eq(other.name, "None")
	end)

	t.test("pulso fica entre os limites e para com 'reduzir efeitos'", function()
		for i = 0, 20 do
			local v = MarkerRules.pulse(i * 0.1, 1.2, 0, 0.45, false)
			t.ok(v >= 0 and v <= 0.45, `pulso {v}`)
		end
		t.eq(MarkerRules.pulse(0.3, 1.2, 0, 0.45, true), 0)
	end)

	t.test("frações da barra limitadas a 0..1", function()
		local hp, shield = MarkerRules.barFractions(50, 25, 100, 50)
		t.eq(hp, 0.5)
		t.eq(shield, 0.5)
		local hp2, shield2 = MarkerRules.barFractions(150, -5, 100, 50)
		t.eq(hp2, 1)
		t.eq(shield2, 0)
	end)
end
