--!strict
-- Tutorial (GDD 5, FASES F6): primeira entrada guiada, uma única vez.
-- O servidor conduz as 8 etapas e confere cada tarefa (derrubar alvos, recarregar, usar a carta,
-- chegar ao lugar). Ele também salva a etapa (`tutorialStep`), entrega as cartas e marca
-- `tutorialDone`. O cliente só mostra e pede (TutorialRequest).
--
--   1 Boas-vindas · 2 Movimento · 3 Armas · 4 Cartas · 5 Voz · 6 Sensibilidade · 7 Retícula · 8 Final
--
-- Retomar: ao voltar, começa da etapa salva; na etapa das cartas, as já ganhas são puladas.
-- Pular: só voz, sensibilidade e retícula (TutorialConfig.SkippableSteps) [DECIDIDO].
-- Exceção de confiança: "olhei os marcadores" (Movimento) vem do cliente, porque o servidor não sabe
-- para onde a câmera aponta. Não dá nada ao jogador além de passar dessa tarefa.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local CardConfig = require(Shared.Config.CardConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local Env = require(Shared.Env)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Config.Strings)
local TutorialConfig = require(Shared.Config.TutorialConfig)
local TutorialRules = require(Shared.Tutorial.TutorialRules)
local TutorialTypes = require(Shared.Tutorial.TutorialTypes)

local DataService = require(ServerScriptService.Common.DataService)
local PlaceTeleport = require(ServerScriptService.Common.PlaceTeleport)
local ProfileRules = require(ServerScriptService.Common.Data.ProfileRules)
local CardService = require(ServerScriptService.Combat.CardService)
local CharacterService = require(ServerScriptService.Combat.CharacterService)
local CombatService = require(ServerScriptService.Combat.CombatService)
local Combatants = require(ServerScriptService.Combat.Combatants)
local TeamService = require(ServerScriptService.Combat.TeamService)

local TutorialWorld = require(script.Parent.TutorialWorld)

type Task = TutorialTypes.Task
type Phase = TutorialTypes.Phase
type StationName = TutorialWorld.StationName

type State = {
	step: number,
	phase: Phase,
	tasks: { Task },
	taskIndex: number,
	taskDone: number,
	lesson: number,
	cards: { string }, -- cartas a ensinar (as que faltam)
	cardIndex: number,
	station: StationName?,
	finishing: boolean,
	noTeleport: boolean,
	token: number, -- muda a cada troca de lição/etapa: tarefas atrasadas antigas não contam
	rateStart: number,
	rateCount: number,
}

type Target = { model: Model, base: CFrame, moving: boolean, phase: number, spot: Vector3, kind: string }

local CARDS = TutorialConfig.Cards
local TARGETS = TutorialConfig.Targets
local CHECK_SECONDS = 0.1

local TutorialService = {}

local stateEvent: RemoteEvent
local requestEvent: RemoteEvent
local states: { [Player]: State } = {}
local targets: { [Model]: Target } = {}

-- Envio ------------------------------------------------------------------------------------------

local function currentLesson(s: State): TutorialConfig.WeaponLesson?
	return TutorialConfig.WeaponLessons[s.lesson]
end

local function send(player: Player)
	local s = states[player]
	if s == nil then
		return
	end
	local stepId = TutorialRules.stepId(s.step)
	local lesson = currentLesson(s)
	local snapshot: TutorialTypes.Snapshot = {
		step = s.step,
		stepId = stepId,
		totalSteps = TutorialRules.StepCount,
		phase = s.phase,
		canSkip = TutorialRules.canSkip(stepId),
		tasks = TutorialRules.view(s.tasks, s.taskIndex, s.taskDone),
		taskIndex = s.taskIndex,
		lesson = if stepId == "Weapons" then s.lesson else nil,
		lessonCount = if stepId == "Weapons" then #TutorialConfig.WeaponLessons else nil,
		tip = if stepId == "Weapons" and lesson then lesson.tip else nil,
		cardId = if stepId == "Cards" then s.cards[s.cardIndex] else nil,
		cardIndex = if stepId == "Cards" then s.cardIndex else nil,
		cardCount = if stepId == "Cards" then #s.cards else nil,
		finishing = s.finishing,
		noTeleport = s.noTeleport,
	}
	stateEvent:FireClient(player, snapshot)
end

-- Personagem -------------------------------------------------------------------------------------

local function place(player: Player, station: StationName)
	local s = states[player]
	if s then
		s.station = station
	end
	CharacterService.place(player, TutorialWorld.spawn(station), {
		teamId = TutorialConfig.PlayerTeam,
		island = nil,
		protectSeconds = 0,
	})
end

local function goTo(player: Player, station: StationName)
	local s = states[player]
	if s and s.station == station and player.Character and player.Character.Parent then
		return
	end
	place(player, station)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Altura dos pés (o centro do corpo menos a distância até os pés).
local function feetY(player: Player): number?
	local root = rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil then
		return nil
	end
	return root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
end

-- Alvos ------------------------------------------------------------------------------------------

local function spawnTarget(spot: Vector3, moving: boolean, kind: string)
	local cframe = CFrame.lookAt(spot + Vector3.new(0, 3, 0), spot + Vector3.new(0, 3, -1))
	local combatant = CharacterService.spawnBot(Strings.Combat.DummyName, CombatNames.DummyTeam, nil, cframe)
	if combatant == nil then
		return
	end
	local model = combatant.model
	-- Sai da lista quando é derrubado (onKnocked): o modelo some e um novo aparece no lugar.
	targets[model] = {
		model = model,
		base = model:GetPivot(),
		moving = moving,
		phase = math.random() * math.pi * 2,
		spot = spot,
		kind = kind,
	}
end

local function buildTargets()
	for _, spot in TutorialWorld.rangeTargets() do
		task.spawn(spawnTarget, spot, false, "Range")
	end
	for _, spot in TutorialWorld.sniperTargets() do
		task.spawn(spawnTarget, spot, false, "Range")
	end
	for _, spot in TutorialWorld.tremorTargets() do
		task.spawn(spawnTarget, spot, false, "Tremor")
	end
	for _, spot in TutorialWorld.settingsTargets() do
		task.spawn(spawnTarget, spot, true, "Settings")
	end
end

local function moveTargets()
	local t = os.clock()
	for _, target in targets do
		if target.moving then
			local x = math.sin(t * TARGETS.MoveSpeed * 2 * math.pi + target.phase) * TARGETS.MoveAmplitude
			target.model:PivotTo(target.base * CFrame.new(x, 0, 0))
		end
	end
end

-- Etapas -----------------------------------------------------------------------------------------

local enterStep: (player: Player, index: number) -> ()

local function setTasks(s: State, tasks: { Task })
	s.tasks = tasks
	s.taskIndex = 1
	s.taskDone = 0
	s.token += 1
end

local function saveStep(player: Player, index: number)
	DataService.update(player, function(profile): (boolean, string?)
		if profile.tutorialDone or profile.tutorialStep == index then
			return false, nil
		end
		profile.tutorialStep = index
		return true, nil
	end)
end

local function nextStep(player: Player)
	local s = states[player]
	if s == nil then
		return
	end
	local index = TutorialRules.nextStep(s.step)
	if index then
		enterStep(player, index)
	end
end

-- Armas ---------------------------------------------------------------------------------------------

-- Armas de cada etapa: (primária, secundária), ou nil = sem armas.
local function loadoutFor(s: State): (string?, string?)
	local stepId = TutorialRules.stepId(s.step)
	if stepId == "Welcome" or stepId == "Movement" then
		return nil, nil
	elseif stepId == "Weapons" then
		local lesson = currentLesson(s)
		if lesson then
			return lesson.primary, lesson.secondary
		end
	elseif stepId == "Sensitivity" then
		return TutorialConfig.Settings.Weapon, TutorialConfig.Settings.Secondary
	end
	return nil, TutorialConfig.Settings.Secondary
end

local function applyLoadout(player: Player, s: State)
	local primary, secondary = loadoutFor(s)
	if secondary then
		CombatService.setLoadout(player, primary, secondary)
	else
		CombatService.disarm(player)
	end
end

local function startLesson(player: Player, index: number)
	local s = states[player]
	local lesson = TutorialConfig.WeaponLessons[index]
	if s == nil or lesson == nil then
		return
	end
	s.lesson = index
	s.phase = "Doing"
	setTasks(s, TutorialRules.weaponTasks(lesson))
	applyLoadout(player, s)
	send(player)
end

-- Cartas ----------------------------------------------------------------------------------------

local CARD_STATION: { [string]: StationName } = {
	card_impulso = "Impulso",
	card_nuvem = "Nuvem",
	card_tremor = "Tremor",
	card_renascer = "Renascer",
}

local function currentCard(s: State): string?
	return s.cards[s.cardIndex]
end

local function cardIntro(player: Player)
	local s = states[player]
	if s == nil then
		return
	end
	local cardId = currentCard(s)
	if cardId == nil then
		nextStep(player)
		return
	end
	s.phase = "Intro"
	setTasks(s, {})
	CardService.disarm(player)
	goTo(player, CARD_STATION[cardId] or "Impulso")
	send(player)
end

local function armCard(player: Player, cardId: string)
	local def = CardConfig.get(cardId)
	if def == nil then
		return
	end
	-- A ult fica liberada no tutorial: rodada da liberação (GDD 8.5)
	if def.isUlt then
		CardService.arm(player, nil, cardId, CardConfig.UltUnlockRound)
	else
		CardService.arm(player, cardId, nil, CardConfig.UltUnlockRound)
	end
end

local function startCard(player: Player)
	local s = states[player]
	local cardId = s and currentCard(s)
	if s == nil or cardId == nil then
		return
	end
	s.phase = "Doing"
	setTasks(s, TutorialRules.cardTasks(cardId))
	place(player, CARD_STATION[cardId] or "Impulso") -- volta ao começo do desafio
	armCard(player, cardId)
	send(player)
end

local function grantCard(player: Player, cardId: string)
	DataService.update(player, function(profile)
		return ProfileRules.grantCard(profile, cardId, "tutorial", os.time())
	end)
	DataService.saveNow(player)
end

-- Tarefas ---------------------------------------------------------------------------------------

local function onTasksDone(player: Player)
	local s = states[player]
	if s == nil then
		return
	end
	local stepId = TutorialRules.stepId(s.step)
	if stepId == "Movement" then
		nextStep(player)
	elseif stepId == "Weapons" then
		if s.lesson < #TutorialConfig.WeaponLessons then
			startLesson(player, s.lesson + 1)
		else
			s.phase = "Info" -- como as armas mudam a cada fase da partida
			setTasks(s, {})
			send(player)
		end
	elseif stepId == "Cards" then
		local cardId = currentCard(s)
		if cardId then
			grantCard(player, cardId)
		end
		CardService.disarm(player)
		s.phase = "Reward"
		send(player)
	end
end

-- Um evento do jogo que pode contar para a tarefa atual.
local function progress(player: Player, kind: TutorialTypes.TaskKind, data: any)
	local s = states[player]
	if s == nil or s.phase ~= "Doing" or s.finishing then
		return
	end
	local index, done = TutorialRules.advance(s.tasks, s.taskIndex, s.taskDone, kind, data)
	if index == s.taskIndex and done == s.taskDone then
		return
	end
	s.taskIndex, s.taskDone = index, done
	if TutorialRules.allDone(s.tasks, s.taskIndex) then
		onTasksDone(player)
	else
		send(player)
	end
end

local function currentTask(s: State): Task?
	return s.tasks[s.taskIndex]
end

-- Errou o desafio da carta (nuvem fora, não subiu, Renascer acabou): cargas de volta logo.
local function retryCard(player: Player)
	local s = states[player]
	if s == nil then
		return
	end
	local token = s.token
	task.delay(CARDS.RetrySeconds, function()
		local now = states[player]
		if now and now.token == token and now.phase == "Doing" then
			CardService.refill(player)
		end
	end)
end

-- Conferência por posição (a cada 0,1 s): andar, pular, subir, área de perigo.
local function checkPositions(player: Player, s: State)
	local current = currentTask(s)
	if current == nil or s.phase ~= "Doing" then
		return
	end
	local root = rootOf(player)
	local feet = feetY(player)
	if root == nil or feet == nil then
		return
	end
	local p = root.Position
	if current.kind == "Walk" then
		local c = TutorialWorld.walkCenter()
		if Vector2.new(p.X - c.X, p.Z - c.Z).Magnitude <= TutorialConfig.Movement.WalkRadius then
			progress(player, "Walk", nil)
		end
	elseif current.kind == "Jump" or current.kind == "Reach" then
		local top, half
		if current.kind == "Jump" then
			top, half = TutorialWorld.jumpBox()
		else
			top, half = TutorialWorld.impulsoTop()
		end
		local onTop = math.abs(p.X - top.X) <= half and math.abs(p.Z - top.Z) <= half and feet >= top.Y - 0.6
		if onTop then
			progress(player, current.kind, nil)
		end
	elseif current.kind == "Revive" or current.kind == "Activate" then
		local center, half = TutorialWorld.dangerPad()
		local onPad = math.abs(p.X - center.X) <= half.X
			and math.abs(p.Z - center.Z) <= half.Y
			and feet <= center.Y + 1.5
		if not onPad then
			return
		end
		local combatant = Combatants.getByPlayer(player)
		if combatant and CardService.isRenascerActive(player) then
			-- Derruba de propósito: o Renascer leva de volta à marca (CardService, guarda de queda)
			Combatants.applyDamage(
				combatant,
				CARDS.RenascerPadDamage,
				{ player = nil, weaponId = "tutorial", at = nil }
			)
		else
			-- Sem o Renascer ativo, não derruba: volta ao começo para ativar primeiro
			place(player, "Renascer")
		end
	end
end

-- Etapas (entrada) --------------------------------------------------------------------------------

enterStep = function(player: Player, index: number)
	local s = states[player]
	if s == nil then
		return
	end
	s.step = index
	s.token += 1
	setTasks(s, {})
	saveStep(player, index)
	local stepId = TutorialRules.stepId(index)

	if stepId == "Weapons" then
		goTo(player, "Range")
		startLesson(player, 1)
		return
	end
	local station: StationName = if stepId == "Welcome" or stepId == "Movement"
		then "Start"
		elseif stepId == "Cards" then CARD_STATION[TutorialConfig.CardOrder[1]] or "Impulso"
		else "Settings"
	if stepId ~= "Cards" then
		goTo(player, station)
	end
	applyLoadout(player, s)

	if stepId == "Welcome" then
		s.phase = "Intro"
	elseif stepId == "Movement" then
		s.phase = "Doing"
		setTasks(s, TutorialRules.movementTasks())
	elseif stepId == "Cards" then
		local owned = {}
		local profile = DataService.getProfile(player)
		if profile then
			owned = profile.cards.owned
		end
		s.cards = TutorialRules.pendingCards(TutorialConfig.CardOrder, owned)
		s.cardIndex = 1
		cardIntro(player)
		return
	elseif stepId == "Voice" or stepId == "Sensitivity" or stepId == "Crosshair" then
		s.phase = "Panel"
		CardService.disarm(player)
	elseif stepId == "Final" then
		s.phase = "Final"
	end
	send(player)
end

-- Fim ---------------------------------------------------------------------------------------------

local function finish(player: Player)
	local s = states[player]
	if s == nil or s.finishing then
		return
	end
	s.finishing = true
	send(player)
	DataService.update(player, function(profile)
		-- Rede de segurança: quem chega ao final tem as 4 cartas iniciais (ganhas na etapa 4)
		for _, id in CardConfig.StarterCards do
			ProfileRules.grantCard(profile, id, "tutorial", os.time())
		end
		profile.tutorialDone = true
		profile.tutorialStep = TutorialRules.StepCount
		return true, nil
	end)
	DataService.saveNow(player) -- momento importante (DADOS 5.2)
	if not PlaceTeleport.sendToLobby(player, "TutorialDone") then
		-- Studio (sem teleporte) ou falha: avisa e deixa o botão de novo
		local now = states[player]
		if now then
			now.finishing = false
			now.noTeleport = true
			send(player)
		end
	end
end

-- Pedidos -----------------------------------------------------------------------------------------

local function rateLimited(s: State): boolean
	local now = os.clock()
	if now - s.rateStart >= 1 then
		s.rateStart = now
		s.rateCount = 0
	end
	s.rateCount += 1
	return s.rateCount > TutorialConfig.RequestsPerSecond
end

local function setVoiceSeen(player: Player)
	DataService.update(player, function(profile)
		if profile.settings.voicePromptSeen then
			return false, nil
		end
		profile.settings.voicePromptSeen = true
		return true, nil
	end)
end

local function devSkip(player: Player, s: State)
	local stepId = TutorialRules.stepId(s.step)
	if stepId == "Cards" then
		for i = s.cardIndex, #s.cards do
			grantCard(player, s.cards[i])
		end
		CardService.disarm(player)
	elseif stepId == "Voice" then
		setVoiceSeen(player)
	end
	nextStep(player)
end

local function onRequest(player: Player, request: unknown)
	local s = states[player]
	if s == nil or s.finishing or typeof(request) ~= "string" or rateLimited(s) then
		return
	end
	local stepId = TutorialRules.stepId(s.step)
	if request == "DevSkip" then
		if Env.IsDev then
			devSkip(player, s)
		end
		return
	end
	if not TutorialRules.accepts(request, stepId, s.phase, currentTask(s)) then
		send(player) -- corrige a tela do cliente
		return
	end

	if request == "Looked" then
		progress(player, "Look", nil)
	elseif request == "Finish" then
		finish(player)
	elseif request == "Continue" or request == "Skip" then
		if stepId == "Cards" then
			if s.phase == "Intro" then
				startCard(player)
			else -- Reward: próxima carta
				s.cardIndex += 1
				cardIntro(player)
			end
		else
			-- Boas-vindas, fases das armas, voz, sensibilidade, retícula. Na sensibilidade e na
			-- retícula o cliente já pediu para salvar (SettingsUpdateRequest).
			if stepId == "Voice" then
				setVoiceSeen(player) -- viu a tela, aceitando ou não ("Agora não")
			end
			nextStep(player)
		end
	end
end

-- Entrada e saída ---------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	local profile = DataService.waitForProfile(player)
	if profile == nil or player.Parent == nil then
		return
	end
	if profile.tutorialDone then
		-- Jogador antigo nunca fica no tutorial (GDD 5.1)
		if PlaceTeleport.sendToLobby(player, "AlreadyDone") then
			return
		end
		-- Studio: não há teleporte; deixa refazer para testar
		warn(`[Tutorial] {player.Name} já terminou o tutorial; no Studio dá para refazer (nada muda no perfil).`)
	end
	TeamService.set(player, TutorialConfig.PlayerTeam)
	states[player] = {
		step = 1,
		phase = "Intro",
		tasks = {},
		taskIndex = 1,
		taskDone = 0,
		lesson = 1,
		cards = {},
		cardIndex = 1,
		station = nil,
		finishing = false,
		noTeleport = false,
		token = 0,
		rateStart = 0,
		rateCount = 0,
	}
	local start = if profile.tutorialDone then 1 else TutorialRules.resumeStep(profile.tutorialStep)
	enterStep(player, start)
end

function TutorialService.Init()
	stateEvent = Remotes.event("TutorialState")
	requestEvent = Remotes.event("TutorialRequest")
end

function TutorialService.Start()
	requestEvent.OnServerEvent:Connect(onRequest)

	-- Armas: recarregar, trocar, abrir a mira
	CombatService.onWeaponEvent(function(player: Player, kind: CombatService.WeaponEventKind, data: any)
		progress(player, kind :: TutorialTypes.TaskKind, data)
	end)

	-- Alvo derrubado por um jogador: conta; o alvo volta logo. Jogador derrubado: volta à estação.
	Combatants.onKnocked(function(target: Combatants.Combatant, source: Combatants.DamageSource?)
		local info = targets[target.model]
		if info then
			targets[target.model] = nil
			if source and source.player then
				progress(source.player, "Knock", nil)
			end
			task.delay(TARGETS.RespawnSeconds, spawnTarget, info.spot, info.moving, info.kind)
			return
		end
		local player = target.player
		if player and states[player] then
			task.delay(TutorialConfig.RespawnSeconds, function()
				local s = states[player]
				if s and s.station and player.Parent then
					place(player, s.station)
					applyLoadout(player, s)
					local cardId = currentCard(s)
					if TutorialRules.stepId(s.step) == "Cards" and s.phase == "Doing" and cardId then
						armCard(player, cardId)
					end
				end
			end)
		end
	end)
	CharacterService.onLost(function(player: Player)
		local s = states[player]
		if s and s.station then
			task.delay(TutorialConfig.RespawnSeconds, function()
				if states[player] == s and s.station and player.Parent then
					place(player, s.station)
					applyLoadout(player, s)
				end
			end)
		end
	end)

	-- Cartas
	CardService.onEvent(function(player: Player, kind: CardService.CardEventKind, data: any)
		local s = states[player]
		if s == nil or s.phase ~= "Doing" then
			return
		end
		if kind == "Used" then
			if data == "card_renascer" then
				progress(player, "Activate", nil)
			end
			-- Errou? Cargas de volta para tentar de novo (só se a tarefa não terminou). O Renascer
			-- espera a janela acabar.
			local def = CardConfig.get(data)
			local wait = if def and def.id == "card_renascer" then def.params.Window else CARDS.RetryAfterUseSeconds
			task.delay(wait, function()
				local now = states[player]
				if now == s and now.phase == "Doing" and currentCard(now) == data then
					retryCard(player)
				end
			end)
		elseif kind == "SmokeLanded" and typeof(data) == "Vector3" then
			local c = TutorialWorld.nuvemCircle()
			if Vector2.new(data.X - c.X, data.Z - c.Z).Magnitude <= CARDS.NuvemCircleRadius + 1 then
				progress(player, "Smoke", nil)
			end
		elseif kind == "TremorHit" then
			local target = data :: Combatants.Combatant
			local info = targets[target.model]
			if info and info.kind == "Tremor" then
				progress(player, "Tremor", nil)
			end
		elseif kind == "Revived" then
			progress(player, "Revive", nil)
		end
	end)

	buildTargets()
	RunService.Heartbeat:Connect(moveTargets)
	task.spawn(function()
		while true do
			for player, s in states do
				local ok, err = pcall(function()
					checkPositions(player, s)
				end)
				if not ok then
					warn(`[Tutorial] Erro ao conferir posição: {err}`)
				end
			end
			task.wait(CHECK_SECONDS)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
end

return TutorialService
