--!strict
-- Mensagens do tutorial (F6) entre servidor e cliente (remotes TutorialState e TutorialRequest).

local TutorialConfig = require(script.Parent.Parent.Config.TutorialConfig)

export type StepId = TutorialConfig.StepId

-- Momento dentro da etapa:
--   Intro  = tela de apresentação com botão (boas-vindas, carta grande)
--   Doing  = jogando: tarefas com progresso na tela
--   Reward = "Você ganhou a carta …!"
--   Info   = painel de informação com botão (fases das armas)
--   Panel  = tela de configuração (voz, sensibilidade, retícula) com Salvar/Pular
--   Final  = "Você está pronto!"
export type Phase = "Intro" | "Doing" | "Reward" | "Info" | "Panel" | "Final"

-- Tipos de tarefa: Movimento (Look, Walk, Jump), Armas (Knock, Reload, Equip, Alt) e Cartas
-- (Impulso: Reach; Nuvem: Smoke; Tremor: Tremor; Renascer: Activate, Revive).
export type TaskKind =
	"Look"
	| "Walk"
	| "Jump"
	| "Knock"
	| "Reload"
	| "Equip"
	| "Alt"
	| "Reach"
	| "Smoke"
	| "Tremor"
	| "Activate"
	| "Revive"

export type Task = { kind: TaskKind, count: number, slot: string? }

export type TaskView = { kind: TaskKind, count: number, done: number, slot: string? }

export type Snapshot = {
	step: number, -- 1 a 8
	stepId: StepId,
	totalSteps: number,
	phase: Phase,
	canSkip: boolean,
	tasks: { TaskView }, -- tarefas da lição/desafio atual (vazio fora de "Doing")
	taskIndex: number, -- tarefa atual (1..#tasks; #tasks + 1 = todas feitas)
	-- Armas
	lesson: number?,
	lessonCount: number?,
	tip: string?, -- chave em Strings.Tutorial.WeaponTips
	-- Cartas
	cardId: string?,
	cardIndex: number?,
	cardCount: number?,
	-- Final
	finishing: boolean?, -- salvando e teleportando
	noTeleport: boolean?, -- no Studio não há teleporte: avisar
}

-- Cliente -> servidor, remote TutorialRequest: (pedido)
export type RequestName =
	"Continue" -- botão principal da tela (Intro, Reward, Info, Panel)
	| "Skip" -- pular (só voz, sensibilidade e retícula)
	| "Looked" -- olhou os marcadores (tarefa Look do movimento)
	| "Finish" -- "Ir para o lobby"
	| "DevSkip" -- só DEV_: pula a etapa atual

return {
	Attr = {
		LookMarker = "TutorialLookMarker", -- tag dos marcadores para olhar (Movimento)
	},
}
