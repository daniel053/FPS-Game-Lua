--!strict
-- Regras puras do tutorial (F6): ordem das etapas, retomada, pular, tarefas. Sem servidor, testável.

local TutorialConfig = require(script.Parent.Parent.Config.TutorialConfig)
local TutorialTypes = require(script.Parent.TutorialTypes)

type StepId = TutorialTypes.StepId
type Task = TutorialTypes.Task
type TaskView = TutorialTypes.TaskView
type Phase = TutorialTypes.Phase

local TutorialRules = {}

TutorialRules.StepCount = #TutorialConfig.Steps

function TutorialRules.stepId(index: number): StepId
	return TutorialConfig.Steps[math.clamp(index, 1, TutorialRules.StepCount)]
end

function TutorialRules.stepIndex(id: StepId): number
	return table.find(TutorialConfig.Steps, id) or 1
end

-- Etapa para retomar a partir do que está salvo (0 = nunca começou). Sempre 1..8.
function TutorialRules.resumeStep(saved: number): number
	if saved ~= saved then -- NaN
		return 1
	end
	return math.clamp(math.floor(saved), 1, TutorialRules.StepCount)
end

function TutorialRules.canSkip(id: StepId): boolean
	return TutorialConfig.SkippableSteps[id] == true
end

-- Próxima etapa, ou nil depois da última.
function TutorialRules.nextStep(index: number): number?
	if index >= TutorialRules.StepCount then
		return nil
	end
	return index + 1
end

-- Cartas que ainda faltam ensinar (as que o jogador já ganhou são puladas ao retomar).
function TutorialRules.pendingCards(order: { string }, owned: { [string]: any }): { string }
	local list = {}
	for _, id in order do
		if owned[id] == nil then
			table.insert(list, id)
		end
	end
	return list
end

-- Tarefas das lições de armas (do config) no formato comum.
function TutorialRules.weaponTasks(lesson: TutorialConfig.WeaponLesson): { Task }
	local tasks: { Task } = {}
	for _, t in lesson.tasks do
		table.insert(tasks, { kind = t.kind :: any, count = t.count or 1, slot = t.slot })
	end
	return tasks
end

-- Tarefas do desafio de cada carta.
function TutorialRules.cardTasks(cardId: string): { Task }
	if cardId == "card_impulso" then
		return { { kind = "Reach", count = 1 } }
	elseif cardId == "card_nuvem" then
		return { { kind = "Smoke", count = 1 } }
	elseif cardId == "card_tremor" then
		return { { kind = "Tremor", count = TutorialConfig.Cards.TremorTargets } }
	elseif cardId == "card_renascer" then
		return { { kind = "Activate", count = 1 }, { kind = "Revive", count = 1 } }
	end
	return {}
end

function TutorialRules.movementTasks(): { Task }
	return {
		{ kind = "Look", count = 1 },
		{ kind = "Walk", count = 1 },
		{ kind = "Jump", count = 1 },
	}
end

-- O evento `kind` (com `data`) conta para a tarefa?
function TutorialRules.matches(task: Task, kind: TutorialTypes.TaskKind, data: any): boolean
	if task.kind ~= kind then
		return false
	end
	if kind == "Equip" then
		return data == task.slot
	elseif kind == "Alt" then
		return data == true
	end
	return true
end

-- Progresso: devolve (índice da tarefa atual, quanto dela já foi feito) depois do evento.
-- Só a tarefa atual conta (em ordem). Índice #tasks + 1 = tudo feito.
function TutorialRules.advance(
	tasks: { Task },
	index: number,
	done: number,
	kind: TutorialTypes.TaskKind,
	data: any
): (number, number)
	local task = tasks[index]
	if task == nil or not TutorialRules.matches(task, kind, data) then
		return index, done
	end
	done += 1
	if done >= task.count then
		return index + 1, 0
	end
	return index, done
end

function TutorialRules.allDone(tasks: { Task }, index: number): boolean
	return index > #tasks
end

-- Vista das tarefas para o cliente.
function TutorialRules.view(tasks: { Task }, index: number, done: number): { TaskView }
	local list: { TaskView } = {}
	for i, task in tasks do
		local progress = if i < index then task.count elseif i == index then done else 0
		table.insert(list, { kind = task.kind, count = task.count, done = progress, slot = task.slot })
	end
	return list
end

-- O pedido do cliente vale no momento atual?
function TutorialRules.accepts(request: string, stepId: StepId, phase: Phase, currentTask: Task?): boolean
	if request == "Continue" then
		return phase == "Intro" or phase == "Reward" or phase == "Info" or phase == "Panel"
	elseif request == "Skip" then
		return phase == "Panel" and TutorialRules.canSkip(stepId)
	elseif request == "Looked" then
		return stepId == "Movement" and phase == "Doing" and currentTask ~= nil and currentTask.kind == "Look"
	elseif request == "Finish" then
		return stepId == "Final" and phase == "Final"
	end
	return false
end

return TutorialRules
