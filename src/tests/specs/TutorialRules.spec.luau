--!strict
-- GDD 5 e FASES F6: ordem das etapas, retomada, pular só as configurações, tarefas em ordem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardConfig = require(ReplicatedStorage.Shared.Config.CardConfig)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local TutorialRules = require(ReplicatedStorage.Shared.Tutorial.TutorialRules)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)

return function(t: any)
	t.test("8 etapas na ordem do GDD 5.2", function()
		t.eq(TutorialRules.StepCount, 8)
		t.eq(TutorialRules.stepId(1), "Welcome")
		t.eq(TutorialRules.stepId(4), "Cards")
		t.eq(TutorialRules.stepId(8), "Final")
		t.eq(TutorialRules.stepIndex("Crosshair"), 7)
		t.eq(TutorialRules.nextStep(7), 8)
		t.eq(TutorialRules.nextStep(8), nil)
	end)

	t.test("retomar: perfil novo começa na 1; etapa salva é respeitada e limitada", function()
		t.eq(TutorialRules.resumeStep(0), 1)
		t.eq(TutorialRules.resumeStep(5), 5)
		t.eq(TutorialRules.resumeStep(99), 8)
		t.eq(TutorialRules.resumeStep(-3), 1)
		t.eq(TutorialRules.resumeStep(0 / 0), 1)
	end)

	t.test("só voz, sensibilidade e retícula podem ser puladas", function()
		for _, id in TutorialConfig.Steps do
			local expected = id == "Voice" or id == "Sensitivity" or id == "Crosshair"
			t.eq(TutorialRules.canSkip(id), expected, id)
		end
	end)

	t.test("pedidos só valem no momento certo", function()
		t.ok(TutorialRules.accepts("Skip", "Voice", "Panel", nil), "pular voz")
		t.ok(not TutorialRules.accepts("Skip", "Weapons", "Doing", nil), "não pula armas")
		t.ok(not TutorialRules.accepts("Skip", "Cards", "Intro", nil), "não pula cartas")
		t.ok(not TutorialRules.accepts("Continue", "Weapons", "Doing", nil), "não avança jogando")
		t.ok(TutorialRules.accepts("Continue", "Cards", "Reward", nil), "continuar depois da carta")
		t.ok(not TutorialRules.accepts("Finish", "Crosshair", "Panel", nil), "terminar só no final")
		t.ok(TutorialRules.accepts("Finish", "Final", "Final", nil), "terminar")
		local look = { kind = "Look", count = 1 } :: any
		local walk = { kind = "Walk", count = 1 } :: any
		t.ok(TutorialRules.accepts("Looked", "Movement", "Doing", look), "olhou")
		t.ok(not TutorialRules.accepts("Looked", "Movement", "Doing", walk), "olhar fora de hora")
		t.ok(not TutorialRules.accepts("Qualquer", "Final", "Final", nil), "pedido desconhecido")
	end)

	t.test("tarefas contam em ordem e só o evento certo", function()
		local tasks = TutorialRules.weaponTasks(TutorialConfig.WeaponLessons[3]) -- trocar de arma
		local i, done = 1, 0
		i, done = TutorialRules.advance(tasks, i, done, "Knock", nil)
		t.eq(i, 1, "derrubar antes de trocar não conta")
		i, done = TutorialRules.advance(tasks, i, done, "Equip", "primary")
		t.eq(i, 1, "sacar a primária antes da secundária não conta")
		i, done = TutorialRules.advance(tasks, i, done, "Equip", "secondary")
		t.eq(i, 2)
		i, done = TutorialRules.advance(tasks, i, done, "Equip", "primary")
		t.eq(i, 3)
		i, done = TutorialRules.advance(tasks, i, done, "Knock", nil)
		t.ok(TutorialRules.allDone(tasks, i), "lição completa")
	end)

	t.test("contagem dentro da tarefa e vista para o cliente", function()
		local tasks = TutorialRules.weaponTasks(TutorialConfig.WeaponLessons[1]) -- 2 alvos
		local i, done = TutorialRules.advance(tasks, 1, 0, "Knock", nil)
		t.eq(i, 1)
		t.eq(done, 1)
		local view = TutorialRules.view(tasks, i, done)
		t.eq(view[1].done, 1)
		t.eq(view[1].count, 2)
		i, done = TutorialRules.advance(tasks, i, done, "Knock", nil)
		t.ok(TutorialRules.allDone(tasks, i))
	end)

	t.test("modo alternativo só conta ao ligar", function()
		local task = { kind = "Alt", count = 1 } :: any
		t.ok(not TutorialRules.matches(task, "Alt", false), "desligar não conta")
		t.ok(TutorialRules.matches(task, "Alt", true), "ligar conta")
	end)

	t.test("cartas já ganhas são puladas ao retomar", function()
		local pending = TutorialRules.pendingCards(TutorialConfig.CardOrder, { card_impulso = true, card_nuvem = true })
		t.deepEq(pending, { "card_tremor", "card_renascer" })
		t.eq(#TutorialRules.pendingCards(TutorialConfig.CardOrder, {}), 4)
	end)

	t.test("o tutorial ensina as 4 cartas iniciais, cada uma com desafio", function()
		t.eq(#TutorialConfig.CardOrder, #CardConfig.StarterCards)
		for _, id in CardConfig.StarterCards do
			t.ok(table.find(TutorialConfig.CardOrder, id) ~= nil, id)
			t.ok(#TutorialRules.cardTasks(id) > 0, `desafio de {id}`)
		end
	end)

	t.test("lições de armas: uma de cada categoria do GDD 5.2, armas que existem", function()
		local categories: { [string]: boolean } = {}
		for _, lesson in TutorialConfig.WeaponLessons do
			local secondary = WeaponConfig.get(lesson.secondary)
			t.ok(secondary ~= nil and secondary.slot == "secondary", lesson.secondary)
			local id = lesson.primary or lesson.secondary
			local def = WeaponConfig.get(id)
			t.ok(def ~= nil, id)
			if def then
				categories[def.category] = true
				if lesson.primary then
					t.eq(def.slot, "primary", id)
				end
			end
			for _, task in lesson.tasks do
				if task.kind == "Alt" and def then
					t.ok(def.altMode ~= nil, `{id} tem modo alternativo`)
				end
			end
		end
		for _, category in { "Pistol", "SMG", "Shotgun", "Sniper", "MachineGun" } do
			t.ok(categories[category], category)
		end
		t.ok(categories.Rifle or categories.LightRifle, "fuzil")
	end)
end
