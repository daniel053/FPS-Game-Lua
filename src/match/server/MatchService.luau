--!strict
-- Partida completa dentro de um servidor (FASES F3, GDD seção 4). O servidor é a autoridade de
-- duplas, vidas, rodadas, armas por rodada, zona e resultado. Máquina de estados (GDD 4.1):
--
--   Receiving -> Forming -> [ Draw -> Prep -> Combat -> RoundEnd ] ... -> Champion -> EndScreen
--
-- As regras puras (duplas, folga, confrontos, ilhas, vidas, Virada, final) ficam em
-- Shared/Match/MatchRules; aqui ficam o tempo, os personagens, a rede e os casos especiais.
-- Vindo da fila (F5), a composição chega pelo MatchHandoff (MemoryStore): quem vai jogar e as duplas
-- fixas. Sem composição (Studio, teleporte de teste), entram os jogadores que estão no servidor (e,
-- só em DEV_, os jogadores de teste do painel), como na F3.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local CardConfig = require(Shared.Config.CardConfig)
local CardRules = require(Shared.Cards.CardRules)
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local Env = require(Shared.Env)
local HealthMath = require(Shared.Combat.HealthMath)
local LoadoutRules = require(Shared.Match.LoadoutRules)
local MapConfig = require(Shared.Config.MapConfig)
local MatchConfig = require(Shared.Config.MatchConfig)
local MatchRules = require(Shared.Match.MatchRules)
local MatchTypes = require(Shared.Match.MatchTypes)
local RankRules = require(Shared.Progression.RankRules)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Config.Strings)
local TeamColors = require(Shared.Config.TeamColors)
local WorldLayout = require(Shared.Match.WorldLayout)

local DataService = require(ServerScriptService.Common.DataService)
local Handoff = require(ServerScriptService.Common.Matchmaking.Handoff)
local ActivityService = require(script.Parent.Parent.Combat.ActivityService)
local CardService = require(script.Parent.Parent.Combat.CardService)
local CharacterService = require(script.Parent.Parent.Combat.CharacterService)
local CombatService = require(script.Parent.Parent.Combat.CombatService)
local Combatants = require(script.Parent.Parent.Combat.Combatants)
local LobbyReturn = require(script.Parent.LobbyReturn)
local MatchRewards = require(script.Parent.MatchRewards)
local MatchWorld = require(script.Parent.MatchWorld)
local ShieldPoints = require(script.Parent.ShieldPoints)
local TeamService = require(script.Parent.Parent.Combat.TeamService)

type Phase = MatchTypes.Phase

type Member = {
	key: string,
	player: Player?,
	name: string,
	userId: number,
	isBot: boolean,
	connected: boolean,
	teamId: string?,
	-- Rodada atual
	inDuel: boolean,
	island: number?,
	side: number,
	slot: number,
	alive: boolean,
	bot: Combatants.Combatant?,
	choice: LoadoutRules.Choice,
	confirmed: boolean,
	previous: LoadoutRules.Choice?,
	afkWarned: boolean,
	-- Cartas (GDD 8.2): a básica vale a partida toda; escolhida na 1ª preparação do jogador
	card: string?,
	cardStepDone: boolean,
	-- Equipe eliminada / fim (GDD 4.8)
	exitChoice: ("Watch" | "NewMatch")?,
	partnerAnswer: boolean?,
	leaving: boolean,
}

type Team = { id: string, members: { Member }, forfeitPending: boolean }

type ActiveDuel = {
	duel: MatchRules.Duel,
	finished: boolean,
	winner: string?,
	finishedAt: number?,
	movedOut: boolean,
	botsOnly: boolean,
}

local MatchService = {}

local stateEvent: RemoteEvent
local matchEvent: RemoteEvent
local requestEvent: RemoteEvent

local rng = Random.new()
local phase: Phase = "Receiving"
local members: { [string]: Member } = {}
local memberByPlayer: { [Player]: Member } = {}
local teams: { [string]: Team } = {}
local rules: MatchRules.State? = nil
local plan: MatchRules.RoundPlan? = nil
local duels: { ActiveDuel } = {}
local endsAt: number? = nil
local combatStartedAt: number? = nil
local firstJoinAt: number? = nil
local botCounter = 0
local forceStart = false
local skipRequested = false
local abortRequested = false -- painel de teste: recomeçar a partida
local pendingLifeRemovals: { string } = {}
local requestWindow: { [Player]: { start: number, count: number } } = {}
-- Composição vinda da fila (F5). Vale para a primeira partida deste servidor.
local handoff: Handoff.MatchHandoff? = nil
local expected: { [number]: boolean } = {}
-- Partida privada (servidores privados, F11): vem do MatchHandoff e vale para o servidor inteiro.
local privateServer = false

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function humans(): { Member }
	local list = {}
	for _, m in members do
		if not m.isBot and m.connected and m.player then
			table.insert(list, m)
		end
	end
	return list
end

local function connectedHumanCount(): number
	return #humans()
end

local function memberCount(): number
	local count = 0
	for _, m in members do
		if m.connected then
			count += 1
		end
	end
	return count
end

local function minPlayers(): number
	return if Env.IsDev then MatchConfig.Start.DevMinPlayers else MatchConfig.Start.MinPlayers
end

local function partnerOf(member: Member): Member?
	local team = member.teamId and teams[member.teamId]
	if team == nil then
		return nil
	end
	for _, other in team.members do
		if other ~= member then
			return other
		end
	end
	return nil
end

local function setLocation(member: Member, location: string?)
	if member.player then
		member.player:SetAttribute(MatchTypes.Attr.Location, location)
	end
end

-- Rede -------------------------------------------------------------------------------------------

local function snapshot(): MatchTypes.Snapshot
	local teamViews: { MatchTypes.TeamView } = {}
	local order: { string } = if rules then rules.order else {}
	for _, id in order do
		local team = teams[id]
		local ts = rules and rules.teams[id]
		if team == nil or ts == nil then
			continue
		end
		local memberViews: { MatchTypes.MemberView } = {}
		for _, m in team.members do
			table.insert(
				memberViews,
				{ key = m.key, name = m.name, userId = m.userId, isBot = m.isBot, connected = m.connected }
			)
		end
		table.insert(teamViews, {
			id = id,
			lives = ts.lives,
			roundWins = ts.roundWins,
			eliminated = ts.eliminated,
			placement = ts.placement,
			members = memberViews,
		})
	end
	local duelViews: { MatchTypes.DuelView } = {}
	for _, d in duels do
		table.insert(duelViews, {
			a = d.duel.a,
			b = d.duel.b,
			island = d.duel.island,
			finished = d.finished,
			winner = d.winner,
		})
	end
	return {
		phase = phase,
		round = if rules then rules.round else 0,
		endsAt = endsAt,
		combatStartedAt = combatStartedAt,
		isVirada = plan ~= nil and plan.isVirada,
		isFinal = if plan then plan.isFinal else (rules ~= nil and rules.finalMode),
		viradaDone = rules ~= nil and rules.viradaDone,
		teams = teamViews,
		duels = duelViews,
		bye = if plan then plan.bye else nil,
		championId = if rules then rules.championId else nil,
		waiting = memberCount(),
		minPlayers = if handoff then #(handoff :: Handoff.MatchHandoff).userIds else minPlayers(),
	}
end

local function publish()
	stateEvent:FireAllClients(snapshot())
end

local function sendTo(member: Member, kind: MatchTypes.EventName, data: any)
	if member.player and member.connected then
		matchEvent:FireClient(member.player, kind, data)
	end
end

local function announceAll(data: MatchTypes.AnnounceData)
	matchEvent:FireAllClients("Announce", data)
end

local function setPhase(newPhase: Phase, seconds: number?)
	phase = newPhase
	endsAt = if seconds then serverNow() + seconds else nil
	publish()
end

-- Espera até o fim da etapa (ou um pedido de pular, ou a partida acabar por falta de gente).
local function waitPhase(extraCheck: (() -> boolean)?)
	while true do
		if skipRequested or abortRequested or connectedHumanCount() == 0 then
			break
		end
		if endsAt and serverNow() >= endsAt then
			break
		end
		if extraCheck and extraCheck() then
			break
		end
		task.wait(0.1)
	end
	skipRequested = false
end

-- Personagens ------------------------------------------------------------------------------------

local function toMirante(member: Member)
	member.inDuel = false
	member.island = nil
	member.alive = false
	if member.bot then
		member.bot.model:Destroy()
		member.bot = nil
	end
	local player = member.player
	if player == nil or not member.connected or member.leaving then
		return
	end
	setLocation(member, MatchTypes.MiranteLocation)
	CombatService.disarm(player)
	CardService.disarm(player)
	task.spawn(CharacterService.place, player, MatchWorld.miranteSpawn(), nil)
end

local function toBase(member: Member, island: number, side: number, slot: number)
	member.inDuel = true
	member.island = island
	member.side = side
	member.slot = slot
	member.alive = true
	local spawn = WorldLayout.baseSpawn(island, side, slot)
	local teamId = member.teamId :: string
	if member.isBot then
		member.bot = CharacterService.spawnBot(member.name, teamId, island, spawn)
		member.alive = member.bot ~= nil
		return
	end
	local player = member.player
	if player == nil or not member.connected then
		member.alive = false
		return
	end
	setLocation(member, `Island{island}`)
	CombatService.disarm(player)
	local character = CharacterService.place(player, spawn, { teamId = teamId, island = island, protectSeconds = 0 })
	if character == nil then
		member.alive = false
	elseif phase == "Draw" or phase == "Prep" then
		CharacterService.setFrozen(character, true) -- solta no começo do combate
	end
end

-- Duplas -----------------------------------------------------------------------------------------

local function eloOf(member: Member): number
	if member.player then
		local profile = DataService.getProfile(member.player)
		if profile then
			return profile.rank.points
		end
	end
	return 0
end

local function friendPairs(list: { Member }): { [string]: boolean }
	local result: { [string]: boolean } = {}
	local pending = 0
	for i, a in list do
		for j = i + 1, #list do
			local b = list[j]
			local pa, pb = a.player, b.player
			if pa and pb and pa.UserId > 0 and pb.UserId > 0 then
				pending += 1
				task.spawn(function()
					local ok, friends = pcall(function()
						return pa:IsFriendsWithAsync(pb.UserId)
					end)
					if ok and friends then
						result[a.key .. "|" .. b.key] = true
						result[b.key .. "|" .. a.key] = true
					end
					pending -= 1
				end)
			end
		end
	end
	local deadline = os.clock() + 5
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	return result
end

local function formTeams()
	local list: { Member } = {}
	for _, m in members do
		if m.connected and not m.leaving then -- quem está voltando ao lobby não joga
			table.insert(list, m)
		end
	end
	local infos: { MatchRules.MemberInfo } = {}
	for _, m in list do
		table.insert(infos, { key = m.key, elo = eloOf(m) })
	end
	local friends = friendPairs(list)
	-- Duplas fixas vindas da fila (MatchHandoff). Se um dos dois não chegou, o outro é pareado
	-- normalmente (MatchRules ignora a dupla incompleta).
	local fixedPairs: { { string } } = {}
	local current = handoff
	if current then
		for _, duo in current.duos do
			table.insert(fixedPairs, { `p{duo[1]}`, `p{duo[2]}` })
		end
	end
	local groups = MatchRules.formTeams(infos, fixedPairs, function(a: string, b: string): boolean
		return friends[a .. "|" .. b] == true
	end)

	teams = {}
	local ids: { string } = {}
	for i, group in groups do
		local id = TeamColors.Order[i]
		assert(id, "mais duplas do que cores")
		local team: Team = { id = id, members = {}, forfeitPending = false }
		for _, key in group do
			local m = members[key]
			m.teamId = id
			table.insert(team.members, m)
			if m.player then
				TeamService.set(m.player, id)
			end
		end
		teams[id] = team
		table.insert(ids, id)
	end
	rules = MatchRules.newState(ids, WorldLayout.islandCount())
end

-- Recompensas (F9) ---------------------------------------------------------------------------------

-- Ainda com o parceiro do começo da partida? (o parceiro não saiu do jogo)
local function keptPartner(member: Member): boolean
	local partner = partnerOf(member)
	return partner ~= nil and partner.connected
end

-- Credita moedas, elo e estatísticas da dupla com a colocação que ela tem agora (MatchRewards).
local function settleTeam(teamId: string)
	local state = rules
	local team = teams[teamId]
	local ts = state and state.teams[teamId]
	if team == nil or ts == nil or ts.placement == nil then
		return
	end
	for _, m in team.members do
		if m.player and m.connected and not m.isBot then
			MatchRewards.settle(m.player, ts.placement, keptPartner(m))
		end
	end
end

-- Começo da partida: quem é dupla de quem (para o bônus do mesmo parceiro).
local function beginRewards()
	local state = rules
	if state == nil then
		return
	end
	local entries = {}
	for _, m in members do
		if m.player and m.teamId and not m.isBot and m.connected then
			local partner = partnerOf(m)
			table.insert(entries, {
				player = m.player,
				teamId = m.teamId,
				partnerUserId = if partner then partner.userId else nil,
			})
		end
	end
	MatchRewards.begin(entries, #state.order, privateServer)
end

-- Quem sai no meio conta como se a dupla caísse agora (RankConfig.LeaverCountsAsEliminatedNow).
-- Usa a lista de membros pela chave (não memberByPlayer), porque a saída pode já ter sido tratada.
local function leaverContext(player: Player): MatchRewards.LeaverContext?
	local state = rules
	local member = members[`p{player.UserId}`]
	if state == nil or member == nil or member.teamId == nil then
		return nil
	end
	local ts = state.teams[member.teamId]
	if ts == nil then
		return nil
	end
	local placement = ts.placement or RankRules.leaverPlacement(#MatchRules.aliveTeams(state))
	return { placement = placement, samePartner = false }
end

-- Resultados -------------------------------------------------------------------------------------

local function sendEliminatedPrompt(teamId: string)
	local team = teams[teamId]
	if team == nil then
		return
	end
	for _, m in team.members do
		sendTo(m, "Eliminated", nil)
	end
end

local function handleReport(report: MatchRules.RoundReport)
	for _, id in report.eliminated do
		announceAll({ kind = "TeamEliminated", teamId = id })
		-- A colocação de quem caiu já está definida: credita agora (F9; quem fica para assistir recebe o
		-- mesmo que receberia no fim, GDD 4.8)
		settleTeam(id)
		local state = rules
		if state and state.championId == nil then
			sendEliminatedPrompt(id)
		end
	end
	if report.viradaNext then
		announceAll({ kind = "Virada" })
	end
	if report.finalStarted then
		announceAll({ kind = "FinalStart" })
	end
	publish()
end

local function applyPending()
	local state = rules
	if state == nil then
		return
	end
	for _, id in pendingLifeRemovals do
		handleReport(MatchRules.devRemoveLife(state, id))
	end
	table.clear(pendingLifeRemovals)
	for id, team in teams do
		if team.forfeitPending then
			team.forfeitPending = false
			handleReport(MatchRules.forfeit(state, id))
		end
	end
end

local function teamTotal(teamId: string): (number, number)
	-- (vivos, HP + escudo dos vivos)
	local team = teams[teamId]
	local alive, total = 0, 0
	if team == nil then
		return 0, 0
	end
	for _, m in team.members do
		if m.inDuel and m.alive then
			local combatant = if m.bot then m.bot elseif m.player then Combatants.getByPlayer(m.player) else nil
			if combatant and combatant.alive then
				alive += 1
				total += HealthMath.total(combatant.health)
			end
		end
	end
	return alive, total
end

local function finishDuel(d: ActiveDuel, winner: string?)
	if d.finished then
		return
	end
	d.finished = true
	d.winner = winner
	d.finishedAt = os.clock()
	local a, b = teams[d.duel.a], teams[d.duel.b]
	for _, team in { a, b } do
		local kind: MatchTypes.AnnounceKind = if winner == nil
			then "DuelTie"
			elseif winner == team.id then "DuelWon"
			else "DuelLost"
		for _, m in team.members do
			sendTo(m, "Announce", { kind = kind, teamId = winner, island = d.duel.island })
		end
	end
	publish()
end

local function checkDuels()
	for _, d in duels do
		if d.finished then
			continue
		end
		local aliveA = teamTotal(d.duel.a)
		local aliveB = teamTotal(d.duel.b)
		if aliveA == 0 and aliveB == 0 then
			finishDuel(d, nil)
		elseif aliveA == 0 then
			finishDuel(d, d.duel.b)
		elseif aliveB == 0 then
			finishDuel(d, d.duel.a)
		end
	end
end

local function allDuelsFinished(): boolean
	for _, d in duels do
		if not d.finished then
			return false
		end
	end
	return true
end

local function moveFinishedDuels()
	for _, d in duels do
		if
			d.finished
			and not d.movedOut
			and d.finishedAt
			and os.clock() - d.finishedAt >= MatchConfig.DuelEndToMiranteDelay
		then
			d.movedOut = true
			for _, id in { d.duel.a, d.duel.b } do
				for _, m in teams[id].members do
					if m.inDuel then
						toMirante(m)
					end
				end
			end
		end
	end
end

-- Combate: zona, queda, ausência e duelos só de jogadores de teste -----------------------------

local function combatantOf(member: Member): Combatants.Combatant?
	if member.bot then
		return member.bot
	end
	if member.player then
		return Combatants.getByPlayer(member.player)
	end
	return nil
end

local function tickCombat(dt: number)
	local started = combatStartedAt or serverNow()
	local elapsed = serverNow() - started
	local radius = WorldLayout.zoneRadius(elapsed)
	local zoneDamage = MatchConfig.Zone.DamagePerSecond * dt
	local fallY = MapConfig.World.IslandFloorY - MatchConfig.FallOutDepth

	for _, m in members do
		if not (m.inDuel and m.alive and m.island) then
			continue
		end
		local combatant = combatantOf(m)
		if combatant == nil or not combatant.alive then
			continue
		end
		local root = combatant.model:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then
			continue
		end
		local position = root.Position
		-- Zona (GDD 4.4)
		local center = WorldLayout.islandCenter(m.island)
		local flat = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
		if flat.Magnitude > radius then
			Combatants.applyZoneDamage(combatant, zoneDamage)
		end
		-- Caiu da ilha: volta para a base e perde o escudo
		if m.player and position.Y < fallY and combatant.alive then
			combatant.model:PivotTo(WorldLayout.baseSpawn(m.island, m.side, m.slot))
			root.AssemblyLinearVelocity = Vector3.zero
			if MapConfig.General.FallOutLosesShield then
				Combatants.clearShield(combatant)
			end
		end
	end
end

local function sendAfkToLobby(member: Member)
	local player = member.player
	if player == nil then
		return
	end
	member.leaving = true
	task.spawn(function()
		if not LobbyReturn.send({ player }, "Afk", nil) then
			player:Kick(Strings.Match.AfkKick)
		end
	end)
end

local function tickAfk()
	for _, m in humans() do
		if not (m.inDuel and m.alive) or m.player == nil then
			continue
		end
		local idle = ActivityService.inactiveSeconds(m.player)
		if idle >= MatchConfig.Afk.SendToLobbyAfter then
			sendAfkToLobby(m)
		elseif idle >= MatchConfig.Afk.WarnAfter then
			m.afkWarned = true
			sendTo(m, "AfkWarning", { seconds = math.ceil(MatchConfig.Afk.SendToLobbyAfter - idle) })
		elseif m.afkWarned then
			m.afkWarned = false
			sendTo(m, "AfkWarning", { seconds = 0 })
		end
	end
end

local function tickBotDuels()
	if combatStartedAt == nil or serverNow() - combatStartedAt < MatchConfig.Dev.BotDuelSeconds then
		return
	end
	for _, d in duels do
		if d.finished or not d.botsOnly then
			continue
		end
		local loserId = if rng:NextNumber() < 0.5 then d.duel.a else d.duel.b
		for _, m in teams[loserId].members do
			if m.bot and m.bot.alive then
				Combatants.knockWithoutSource(m.bot)
			end
		end
	end
end

-- Preparação (GDD 4.10) --------------------------------------------------------------------------

local function memoryOf(member: Member): LoadoutRules.Memory?
	if member.player == nil then
		return nil
	end
	local profile = DataService.getProfile(member.player)
	if profile == nil then
		return nil
	end
	return {
		lastPrimaryByPhase = profile.loadout.lastPrimaryByPhase,
		lastSecondary = profile.loadout.lastSecondary,
	}
end

local function ownedCards(member: Member): { [string]: any }
	if member.player == nil then
		return {}
	end
	local profile = DataService.getProfile(member.player)
	return if profile then profile.cards.owned else {}
end

-- Etapa da carta: na 1ª rodada; quem estava de folga escolhe na sua primeira preparação.
local function hasCardStep(member: Member, round: number): boolean
	if member.cardStepDone or member.isBot then
		return false
	end
	return round == CardConfig.ChoiceRound or CardConfig.ByeTeamChoosesOnFirstPrep
end

local function sendPartnerChoice(member: Member)
	local partner = partnerOf(member)
	if partner == nil then
		return
	end
	local data: MatchTypes.PartnerChoiceData = {
		name = member.name,
		primary = member.choice.primary,
		secondary = member.choice.secondary,
		card = member.card,
		confirmed = member.confirmed,
	}
	sendTo(partner, "PrepPartner", data)
end

local function openPrep(round: number, seconds: number)
	local options = LoadoutRules.options(round)
	for _, m in members do
		if not m.inDuel then
			continue
		end
		local primary, secondary = LoadoutRules.resolve(options, nil, m.previous, memoryOf(m))
		m.choice = { primary = primary, secondary = secondary }
		m.confirmed = m.isBot
	end
	for _, m in members do
		if not m.inDuel or m.isBot then
			continue
		end
		local owned = ownedCards(m)
		local cardStep = hasCardStep(m, round)
		local data: MatchTypes.PrepData = {
			round = round,
			phaseId = options.phaseId,
			primaries = options.primaries,
			secondaries = options.secondaries,
			endsAt = serverNow() + seconds,
			cardStep = cardStep,
			cardOptions = if cardStep then CardRules.basicOptions(owned) else {},
			card = m.card,
			ult = CardRules.ultOf(owned),
			ultUnlocked = CardRules.ultUnlocked(round),
			primary = m.choice.primary,
			secondary = m.choice.secondary :: string,
		}
		sendTo(m, "PrepOpen", data)
	end
	for _, m in members do
		if m.inDuel then
			sendPartnerChoice(m)
		end
	end
end

local function closePrepAndArm(round: number)
	local options = LoadoutRules.options(round)
	for _, m in members do
		if not m.inDuel then
			continue
		end
		local primary, secondary = LoadoutRules.resolve(options, m.choice, m.previous, memoryOf(m))
		m.previous = { primary = primary, secondary = secondary }
		local choseCardNow = false
		if hasCardStep(m, round) then
			-- Fim da etapa da carta: sem escolha = partida inteira sem carta básica (GDD 8.2)
			m.cardStepDone = true
			choseCardNow = m.card ~= nil
		end
		local player = m.player
		if player == nil or not m.alive then
			continue
		end
		sendTo(m, "PrepClose", nil)
		CombatService.setLoadout(player, primary, secondary)
		CardService.arm(player, m.card, CardRules.ultOf(ownedCards(m)), round)
		if player.Character then
			CharacterService.setFrozen(player.Character, false)
		end
		ActivityService.reset(player)
		m.afkWarned = false
		-- Memória do perfil para "Repetir última" e para a próxima partida (DADOS 3.1)
		DataService.update(player, function(profile)
			if primary then
				profile.loadout.lastPrimaryByPhase[options.phaseId] = primary
			end
			profile.loadout.lastSecondary = secondary
			if choseCardNow then
				profile.loadout.lastCard = m.card
			end
			return true, nil
		end)
	end
end

local function onPrepChoose(member: Member, arg: unknown)
	if phase ~= "Prep" or not member.inDuel or plan == nil or typeof(arg) ~= "table" then
		return
	end
	local options = LoadoutRules.options(plan.round)
	local raw = arg :: { [any]: any }
	if raw.primary ~= nil then
		if not LoadoutRules.isPrimaryAllowed(options, raw.primary) then
			return
		end
		member.choice.primary = raw.primary
	end
	if raw.secondary ~= nil then
		if not LoadoutRules.isSecondaryAllowed(options, raw.secondary) then
			return
		end
		member.choice.secondary = raw.secondary
	end
	sendPartnerChoice(member)
end

local function onPrepCard(member: Member, arg: unknown)
	if phase ~= "Prep" or not member.inDuel or plan == nil or not hasCardStep(member, plan.round) then
		return
	end
	if not CardRules.isBasicChoiceAllowed(ownedCards(member), arg) then
		return
	end
	member.card = arg :: string
	sendPartnerChoice(member)
end

-- Rodada -----------------------------------------------------------------------------------------

-- Rodada interrompida (recomeçar pelo painel, todos saíram): todos para o mirante, sem resultado.
local function abortRound()
	for _, m in members do
		sendTo(m, "PrepClose", nil)
		sendTo(m, "AfkWarning", { seconds = 0 })
		if m.inDuel then
			toMirante(m)
		end
	end
	CardService.clearWorld()
	duels = {}
	plan = nil
	combatStartedAt = nil
end

local function playRound()
	local state = rules :: MatchRules.State
	applyPending()
	if state.championId then
		return
	end
	local roundPlan = MatchRules.planRound(state, rng)
	plan = roundPlan
	duels = {}
	for _, duel in roundPlan.duels do
		local botsOnly = true
		for _, id in { duel.a, duel.b } do
			for _, m in teams[id].members do
				if not m.isBot and m.connected then
					botsOnly = false
				end
			end
		end
		table.insert(duels, {
			duel = duel,
			finished = false,
			winner = nil,
			finishedAt = nil,
			movedOut = false,
			botsOnly = botsOnly,
		})
	end
	combatStartedAt = nil

	-- SORTEIO_CONFRONTOS + TELEPORTE: confrontos na tela, todos ainda no mirante
	setPhase("Draw", MatchConfig.ArenaTeleportTime)
	if roundPlan.isVirada then
		announceAll({ kind = "Virada" })
	elseif roundPlan.isFinal and state.round == 1 then
		announceAll({ kind = "FinalStart" })
	end
	for _, duel in roundPlan.duels do
		announceAll({ kind = "Matchups", teamId = duel.a, otherId = duel.b, island = duel.island })
	end
	if roundPlan.bye then
		announceAll({ kind = "Bye", teamId = roundPlan.bye })
	end
	waitPhase()
	if abortRequested then
		abortRound()
		return
	end

	-- Cada dupla na base da sua ilha; folga e eliminados no mirante
	for _, m in members do
		m.inDuel = false
	end
	for _, d in duels do
		for side, id in { d.duel.a, d.duel.b } do
			local slot = 0
			for _, m in teams[id].members do
				if m.connected and not m.leaving then
					slot += 1
					task.spawn(toBase, m, d.duel.island, side, slot)
				end
			end
		end
	end
	task.wait(0.5) -- personagens novos sendo criados

	-- PREPARACAO: congelado na base, modal de armas (e da carta, na 1ª preparação de cada um)
	local anyCardStep = false
	for _, m in members do
		if m.inDuel and hasCardStep(m, roundPlan.round) then
			anyCardStep = true
		end
	end
	local prepSeconds = if state.round == 1 or anyCardStep
		then MatchConfig.PrepTimeFirstRound
		else MatchConfig.PrepTimeOtherRounds
	setPhase("Prep", prepSeconds)
	openPrep(roundPlan.round, prepSeconds)
	waitPhase()
	if abortRequested then
		abortRound()
		return
	end
	closePrepAndArm(roundPlan.round)

	-- Quem jogou esta rodada (para as moedas e estatísticas, F9). "Sozinho" = 1 contra 2.
	local participants: { { member: Member, teamId: string, duel: number, solo: boolean } } = {}
	for i, d in duels do
		local counts: { [string]: number } = {}
		for _, id in { d.duel.a, d.duel.b } do
			counts[id] = 0
			for _, m in teams[id].members do
				if m.inDuel then
					counts[id] += 1
				end
			end
		end
		for _, id in { d.duel.a, d.duel.b } do
			local other = if id == d.duel.a then d.duel.b else d.duel.a
			for _, m in teams[id].members do
				if m.inDuel and m.player and not m.isBot then
					table.insert(participants, {
						member = m,
						teamId = id,
						duel = i,
						solo = counts[id] == 1 and counts[other] >= 2,
					})
				end
			end
		end
	end

	-- COMBATE
	combatStartedAt = serverNow()
	ShieldPoints.reset() -- pontos de escudo acesos no começo de cada rodada
	setPhase("Combat", MatchConfig.CombatMaxTime)
	announceAll({ kind = "RoundStart" })
	checkDuels()
	local last = os.clock()
	local lastAfk = 0
	local timedOut = false
	while true do
		task.wait(0.1)
		local nowClock = os.clock()
		local dt = nowClock - last
		last = nowClock
		tickCombat(dt)
		if Env.IsDev then
			tickBotDuels()
		end
		if nowClock - lastAfk >= 1 then
			lastAfk = nowClock
			tickAfk()
		end
		checkDuels()
		moveFinishedDuels()
		if allDuelsFinished() or connectedHumanCount() == 0 or abortRequested then
			break
		end
		if skipRequested or (endsAt and serverNow() >= endsAt) then
			skipRequested = false
			timedOut = true
			break
		end
	end
	if abortRequested then
		abortRound()
		return
	end
	-- Tempo esgotado (ou rodada pulada): vence quem tiver mais HP + escudo (GDD 4.4)
	if timedOut then
		for _, d in duels do
			if not d.finished then
				local _, totalA = teamTotal(d.duel.a)
				local _, totalB = teamTotal(d.duel.b)
				finishDuel(d, MatchRules.timeoutWinner(d.duel.a, totalA, d.duel.b, totalB))
			end
		end
	end

	-- FIM_RODADA: todos voltam ao mirante, placar; nuvens e marcas somem
	CardService.clearWorld()
	for _, m in members do
		if m.inDuel then
			toMirante(m)
		end
		sendTo(m, "AfkWarning", { seconds = 0 })
	end
	local outcomes: { MatchRules.DuelOutcome } = {}
	for i, d in duels do
		outcomes[i] = { winner = d.winner }
	end
	for _, p in participants do
		local player = p.member.player
		if player and p.member.connected then
			MatchRewards.recordRound(player, {
				won = duels[p.duel].winner == p.teamId,
				virada = roundPlan.isVirada,
				solo = p.solo,
			})
		end
	end
	local report = MatchRules.finishRound(state, roundPlan, outcomes)
	setPhase("RoundEnd", MatchConfig.RoundEndTime)
	handleReport(report)
	applyPending()
	waitPhase()
end

-- Começo e fim -----------------------------------------------------------------------------------

local function makeMember(key: string, player: Player?, name: string, userId: number, isBot: boolean): Member
	return {
		key = key,
		player = player,
		name = name,
		userId = userId,
		isBot = isBot,
		connected = true,
		teamId = nil,
		inDuel = false,
		island = nil,
		side = 1,
		slot = 1,
		alive = false,
		bot = nil,
		choice = {},
		confirmed = false,
		previous = nil,
		afkWarned = false,
		card = nil,
		cardStepDone = false,
		exitChoice = nil,
		partnerAnswer = nil,
		leaving = false,
	}
end

local function newMember(player: Player): Member
	return makeMember(`p{player.UserId}`, player, player.DisplayName, player.UserId, false)
end

local function newBot(): Member
	botCounter += 1
	return makeMember(`bot{botCounter}`, nil, string.format(Strings.Dev.BotName, botCounter), 0, true)
end

local function resetMatch()
	-- Mantém os jogadores e os jogadores de teste; zera duplas, vidas e rodadas.
	for key, m in members do
		if not m.connected then
			members[key] = nil
			continue
		end
		m.teamId = nil
		m.inDuel = false
		m.alive = false
		m.previous = nil
		m.card = nil
		m.cardStepDone = false
		m.exitChoice = nil
		m.partnerAnswer = nil
		m.leaving = false
		if m.bot then
			m.bot.model:Destroy()
			m.bot = nil
		end
		if m.player then
			TeamService.set(m.player, nil)
			m.player:SetAttribute(CombatNames.Attr.Kills, 0)
		end
	end
	-- Quem chegou durante a partida anterior entra nesta
	for _, player in Players:GetPlayers() do
		if memberByPlayer[player] == nil and memberCount() < MatchConfig.Start.MaxPlayers then
			local m = newMember(player)
			members[m.key] = m
			memberByPlayer[player] = m
		end
	end
	teams = {}
	rules = nil
	plan = nil
	duels = {}
	combatStartedAt = nil
	forceStart = false
	skipRequested = false
	abortRequested = false
	table.clear(pendingLifeRemovals)
	MatchRewards.cancel() -- partida anterior interrompida: quem não recebeu não recebe mais
	firstJoinAt = if connectedHumanCount() > 0 then os.clock() else nil
end

-- Composição vinda da fila --------------------------------------------------------------------------

local function arrivedExpected(): (number, number)
	local current = handoff
	if current == nil then
		return 0, 0
	end
	local arrived = 0
	for _, m in humans() do
		if expected[m.userId] then
			arrived += 1
		end
	end
	return arrived, #current.userIds
end

-- Volta para o lobby sem jogar. Na partida que não aconteceu, entra direto na fila, na frente.
local function sendBack(member: Member, reason: LobbyReturn.ReturnReason, options: LobbyReturn.ReturnOptions?)
	local player = member.player
	if player == nil or member.leaving then
		return
	end
	member.leaving = true
	task.spawn(function()
		if not LobbyReturn.send({ player }, reason, options) then
			if reason == "NotExpected" then
				player:Kick(Strings.Match.NotExpectedKick)
				return
			end
			member.leaving = false
			sendTo(member, "Notice", { key = if Env.IsStudio then "TeleportStudio" else "TeleportFailed" })
		end
	end)
end

-- Quem não está na composição não joga esta partida (só fora do ambiente de teste).
local function isUnexpected(player: Player): boolean
	return handoff ~= nil and not expected[player.UserId] and not Env.IsDev
end

local function loadHandoff()
	if Env.IsStudio or game.PrivateServerId == "" then
		return
	end
	local data = Handoff.readMatchAsync(game.PrivateServerId, MatchConfig.Start.HandoffReadSeconds)
	if data == nil then
		warn("[Partida] Sem MatchHandoff: começando com quem estiver no servidor (como na F3)")
		return
	end
	handoff = data
	privateServer = data.isPrivate == true
	for _, userId in data.userIds do
		expected[userId] = true
	end
	print(`[Partida] Partida {data.matchId}: esperando {#data.userIds} jogador(es), {#data.duos} dupla(s) fixa(s)`)
	for _, m in humans() do
		if m.player and isUnexpected(m.player) then
			sendBack(m, "NotExpected", nil)
		end
	end
	publish()
end

local function receivingFromQueue(): boolean
	-- Começa quando todos chegam, ou ReceivingPlayersTimeout depois do primeiro (GDD 4.1).
	-- Devolve true para começar; false = a partida não vai acontecer (todos voltaram para a fila).
	while true do
		local arrived, total = arrivedExpected()
		if firstJoinAt then
			local startAt = firstJoinAt + MatchConfig.ReceivingPlayersTimeout
			local newEndsAt = serverNow() + math.max(0, startAt - os.clock())
			if endsAt == nil or math.abs(newEndsAt - endsAt) > 0.5 then
				endsAt = newEndsAt
				publish()
			end
			if forceStart or arrived >= total or os.clock() >= startAt then
				local present = 0
				for _, m in members do
					if m.connected and not m.leaving then
						present += 1
					end
				end
				if present >= MatchConfig.Start.MinArrived and connectedHumanCount() > 0 then
					return true
				end
				-- Chegou gente de menos: quem chegou volta para a fila, na frente (decisão da F5).
				warn(`[Partida] Só {present} de {total} jogador(es) chegaram: de volta para a fila`)
				handoff = nil
				table.clear(expected)
				for _, m in humans() do
					sendTo(m, "Notice", { key = "NotEnoughPlayers" })
					sendBack(m, "NotEnoughPlayers", { autoQueue = true, priority = true })
				end
				publish()
				return false
			end
		end
		task.wait(0.25)
	end
end

local function receiving()
	setPhase("Receiving", nil)
	for _, m in humans() do
		toMirante(m)
	end
	if handoff and receivingFromQueue() then
		forceStart = false
		return
	end
	while true do
		local count = memberCount()
		local enough = count >= minPlayers() and connectedHumanCount() > 0
		if enough and firstJoinAt then
			local startAt = firstJoinAt + MatchConfig.ReceivingPlayersTimeout
			local newEndsAt = serverNow() + math.max(0, startAt - os.clock())
			if endsAt == nil or math.abs(newEndsAt - endsAt) > 0.5 then
				endsAt = newEndsAt
				publish()
			end
			if forceStart or os.clock() >= startAt or count >= MatchConfig.Start.MaxPlayers then
				break
			end
		elseif endsAt ~= nil then
			endsAt = nil
			publish()
		end
		task.wait(0.25)
	end
	forceStart = false
end

-- Equipe eliminada ou fim: "Nova partida" e "seguir com o parceiro?" (GDD 4.8).
-- `list` com 2 membros e options.together = dupla fixa: viajam juntos e caem no mesmo lobby.
local function goToLobby(list: { Member }, reason: LobbyReturn.ReturnReason, options: LobbyReturn.ReturnOptions)
	local going: { Member } = {}
	local players: { Player } = {}
	for _, m in list do
		local player = m.player
		if player and m.connected and not m.leaving then
			m.leaving = true
			table.insert(going, m)
			table.insert(players, player)
			sendTo(m, "Notice", { key = "GoingToLobby" })
		end
	end
	if #players == 0 then
		return
	end
	local opts: LobbyReturn.ReturnOptions = {
		autoQueue = options.autoQueue,
		priority = options.priority,
		together = options.together == true and #players == 2,
	}
	task.spawn(function()
		if not LobbyReturn.send(players, reason, opts) then
			for _, m in going do
				local player = m.player
				if player and player.Parent == Players then
					m.leaving = false
					m.exitChoice = nil
					m.partnerAnswer = nil
					sendTo(m, "Notice", { key = if Env.IsStudio then "TeleportStudio" else "TeleportFailed" })
				end
			end
		end
	end)
end

local function resolveExit(member: Member)
	if member.exitChoice ~= "NewMatch" then
		return
	end
	local partner = partnerOf(member)
	if partner == nil or partner.isBot or not partner.connected or partner.exitChoice == "Watch" then
		goToLobby({ member }, "NewMatch", { autoQueue = true })
		return
	end
	if partner.exitChoice ~= "NewMatch" then
		return -- espera o parceiro decidir (ou o fim da partida)
	end
	-- Os dois querem nova partida: pergunta se seguem juntos
	if member.partnerAnswer == nil and partner.partnerAnswer == nil then
		sendTo(member, "PartnerQuestion", { partnerName = partner.name })
		sendTo(partner, "PartnerQuestion", { partnerName = member.name })
		return
	end
	if member.partnerAnswer == nil or partner.partnerAnswer == nil then
		return
	end
	if member.partnerAnswer == true and partner.partnerAnswer == true then
		-- Os dois aceitaram: entram na fila como dupla fixa (GDD 4.8)
		goToLobby({ member, partner }, "NewMatch", { autoQueue = true, together = true })
	else
		goToLobby({ member }, "NewMatch", { autoQueue = true })
		goToLobby({ partner }, "NewMatch", { autoQueue = true })
	end
end

local function champion()
	local state = rules :: MatchRules.State
	local championId = state.championId
	setPhase("Champion", MatchConfig.ChampionCeremonyTime)
	announceAll({ kind = "Champion", teamId = championId })
	if championId then
		settleTeam(championId) -- moedas e elo da campeã (as outras já receberam ao cair)
	end
	local slot = 0
	for _, m in humans() do
		if m.teamId == championId then
			slot += 1
			local player = m.player :: Player
			setLocation(m, MatchTypes.MiranteLocation)
			CombatService.disarm(player)
			CardService.disarm(player)
			task.spawn(CharacterService.place, player, MatchWorld.podiumSpawn(slot), nil)
		end
	end
	waitPhase()
end

local function endScreen()
	local state = rules :: MatchRules.State
	-- Quem ainda não recebeu (não deveria sobrar ninguém: cada dupla recebe ao cair) recebe agora
	for id in teams do
		settleTeam(id)
	end
	setPhase("EndScreen", MatchConfig.EndScreenTime)
	for _, m in humans() do
		m.exitChoice = nil
		m.partnerAnswer = nil
		local ts = m.teamId and state.teams[m.teamId]
		local partner = partnerOf(m)
		local data: MatchTypes.EndScreenData = {
			placement = if ts then ts.placement else nil,
			championId = state.championId,
			endsAt = endsAt :: number,
			partnerName = if partner and not partner.isBot and partner.connected then partner.name else nil,
		}
		sendTo(m, "EndScreen", data)
		if partner and not partner.isBot and partner.connected then
			sendTo(m, "PartnerQuestion", { partnerName = partner.name })
		end
		if m.player then
			DataService.saveNow(m.player)
		end
	end
	waitPhase()

	-- Todos de volta ao lobby. Quem respondeu "sim" dos dois lados vai junto, como dupla fixa, e entra
	-- direto na fila (GDD 4.8); os outros só voltam ao lobby.
	local handled: { [Member]: boolean } = {}
	for _, m in humans() do
		if m.leaving or m.player == nil or handled[m] then
			continue
		end
		handled[m] = true
		local partner = partnerOf(m)
		local together = partner ~= nil
			and not partner.isBot
			and partner.connected
			and not partner.leaving
			and m.partnerAnswer == true
			and partner.partnerAnswer == true
		if together and partner then
			handled[partner] = true
			goToLobby({ m, partner }, "MatchEnded", { autoQueue = true, together = true })
		else
			goToLobby({ m }, "MatchEnded", {})
		end
	end
	task.wait(2)
end

local function runMatch()
	loadHandoff()
	while true do
		resetMatch()
		receiving()
		setPhase("Forming", nil)
		formTeams()
		beginRewards()
		-- A composição da fila vale só para a primeira partida deste servidor.
		handoff = nil
		table.clear(expected)
		publish()
		task.wait(1)
		local state = rules :: MatchRules.State
		while state.championId == nil and connectedHumanCount() > 0 and not abortRequested do
			playRound()
		end
		if connectedHumanCount() > 0 and state.championId and not abortRequested then
			champion()
			endScreen()
		end
	end
end

-- Pedidos dos clientes ---------------------------------------------------------------------------

local function rateLimited(player: Player): boolean
	local now = os.clock()
	local window = requestWindow[player]
	if window == nil or now - window.start >= 1 then
		requestWindow[player] = { start = now, count = 1 }
		return false
	end
	window.count += 1
	return window.count > 20
end

local function onRequest(player: Player, kind: unknown, arg: unknown)
	local member = memberByPlayer[player]
	if member == nil or rateLimited(player) then
		return
	end
	if kind == "PrepChoose" then
		onPrepChoose(member, arg)
	elseif kind == "PrepCard" then
		onPrepCard(member, arg)
	elseif kind == "PrepConfirm" then
		if phase == "Prep" and member.inDuel and not member.confirmed then
			member.confirmed = true
			sendPartnerChoice(member)
		end
	elseif kind == "Watch" then
		local ts = rules and member.teamId and rules.teams[member.teamId]
		if ts and ts.eliminated then
			member.exitChoice = "Watch"
			sendTo(member, "Notice", { key = "Watching" })
			local partner = partnerOf(member)
			if partner then
				resolveExit(partner)
			end
		end
	elseif kind == "NewMatch" then
		local ts = rules and member.teamId and rules.teams[member.teamId]
		local allowed = phase == "EndScreen" or (ts ~= nil and ts.eliminated)
		if allowed then
			member.exitChoice = "NewMatch"
			if phase == "EndScreen" then
				-- No fim: vai agora. Se os dois já disseram "sim" a seguir juntos, o parceiro vai junto
				-- (ele aceitou ir para a próxima partida com este jogador).
				local partner = partnerOf(member)
				if partner and member.partnerAnswer == true and partner.partnerAnswer == true then
					goToLobby({ member, partner }, "NewMatch", { autoQueue = true, together = true })
				else
					goToLobby({ member }, "NewMatch", { autoQueue = true })
				end
			else
				resolveExit(member)
			end
		end
	elseif kind == "PartnerAnswer" then
		if typeof(arg) ~= "boolean" or member.partnerAnswer ~= nil then
			return
		end
		member.partnerAnswer = arg
		if phase ~= "EndScreen" then
			resolveExit(member)
		end
	end
end

local function onPlayerAdded(player: Player)
	player:SetAttribute(CombatNames.Attr.Kills, 0)
	if isUnexpected(player) then
		-- Servidor de outra partida (não estava na composição da fila): volta ao lobby.
		local m = newMember(player)
		memberByPlayer[player] = m
		sendBack(m, "NotExpected", nil)
		return
	end
	if phase == "Receiving" and memberCount() < MatchConfig.Start.MaxPlayers then
		local m = newMember(player)
		members[m.key] = m
		memberByPlayer[player] = m
		if firstJoinAt == nil then
			firstJoinAt = os.clock()
		end
	end
	-- Começa no mirante; quem chega no meio da partida assiste dali até a próxima.
	player:SetAttribute(MatchTypes.Attr.Location, MatchTypes.MiranteLocation)
	local member = memberByPlayer[player]
	if member == nil or not member.inDuel then
		task.spawn(CharacterService.place, player, MatchWorld.miranteSpawn(), nil)
	end
	stateEvent:FireClient(player, snapshot())
	publish()
end

local function onPlayerRemoving(player: Player)
	requestWindow[player] = nil
	local member = memberByPlayer[player]
	memberByPlayer[player] = nil
	if member == nil then
		return
	end
	member.connected = false
	member.alive = false
	if rules == nil then
		members[member.key] = nil -- ainda não começou: só sai da lista
		publish()
		return
	end
	local partner = partnerOf(member)
	if partner and partner.connected then
		sendTo(partner, "Announce", { kind = "PartnerLeft" })
		if partner.exitChoice == "NewMatch" then
			resolveExit(partner)
		end
	end
	local team = member.teamId and teams[member.teamId]
	if team then
		local anyone = false
		for _, m in team.members do
			if m.connected then
				anyone = true
			end
		end
		local ts = rules.teams[team.id]
		if not anyone and ts and not ts.eliminated then
			team.forfeitPending = true -- os dois saíram: dupla eliminada (GDD 4.9)
			if phase ~= "Prep" and phase ~= "Combat" and phase ~= "Draw" then
				applyPending()
			end
		end
	end
	publish()
end

-- Personagem perdido no mirante (caiu, botão de reiniciar): volta para o mirante.
local function onCharacterLost(player: Player)
	local member = memberByPlayer[player]
	if member and member.inDuel then
		return
	end
	task.wait(1)
	if player.Parent then
		CharacterService.place(player, MatchWorld.miranteSpawn(), nil)
	end
end

-- Mirante: quem cair abaixo do mirante volta para ele.
local function watchMiranteFalls()
	local fallY = MapConfig.World.MiranteFloorY - MatchConfig.FallOutDepth
	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			if player:GetAttribute(MatchTypes.Attr.Location) ~= MatchTypes.MiranteLocation then
				continue
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if character and root and root:IsA("BasePart") and root.Position.Y < fallY then
				character:PivotTo(MatchWorld.miranteSpawn())
				root.AssemblyLinearVelocity = Vector3.zero
			end
		end
	end)
end

-- Comandos de teste (DevMatchService) ------------------------------------------------------------

function MatchService.getPhase(): Phase
	return phase
end

function MatchService.getRound(): number
	return if rules then rules.round else 0
end

function MatchService.botCount(): number
	local count = 0
	for _, m in members do
		if m.isBot then
			count += 1
		end
	end
	return count
end

function MatchService.devStartNow(): boolean
	if phase ~= "Receiving" or memberCount() < 2 or connectedHumanCount() == 0 then
		return false
	end
	forceStart = true
	return true
end

function MatchService.devSkip(): boolean
	if phase == "Receiving" or phase == "Forming" then
		return false
	end
	skipRequested = true
	return true
end

-- Tira 1 vida da dupla. Entre rodadas vale na hora; no meio da rodada, no fim dela.
function MatchService.devRemoveLife(teamId: string): (boolean, boolean)
	local state = rules
	if state == nil or state.teams[teamId] == nil or state.teams[teamId].eliminated or state.finalMode then
		return false, false
	end
	if phase == "RoundEnd" then
		handleReport(MatchRules.devRemoveLife(state, teamId))
		return true, false
	end
	table.insert(pendingLifeRemovals, teamId)
	return true, true
end

function MatchService.devForceVirada(): boolean
	local state = rules
	if state == nil then
		return false
	end
	local ok = MatchRules.devForceVirada(state)
	publish()
	return ok
end

function MatchService.devAddBots(count: number): boolean
	if phase ~= "Receiving" then
		return false
	end
	local added = 0
	while
		added < count
		and memberCount() < MatchConfig.Start.MaxPlayers
		and MatchService.botCount() < MatchConfig.Dev.MaxBots
	do
		local bot = newBot()
		members[bot.key] = bot
		added += 1
	end
	publish()
	return added > 0
end

function MatchService.devClearBots(): boolean
	if phase ~= "Receiving" then
		return false
	end
	for key, m in members do
		if m.isBot then
			members[key] = nil
		end
	end
	publish()
	return true
end

function MatchService.devRestart(): boolean
	if phase == "Receiving" then
		return false
	end
	-- Encerra a partida atual sem resultado; o laço volta para RECEBENDO_JOGADORES.
	abortRequested = true
	MatchRewards.cancel()
	return true
end

function MatchService.getTeamIds(): { string }
	return if rules then MatchRules.aliveTeams(rules) else {}
end

-- Ciclo de vida ----------------------------------------------------------------------------------

function MatchService.isEnabled(): boolean
	return not CombatConfig.TestArena.Enabled
end

function MatchService.Init()
	if not MatchService.isEnabled() then
		return
	end
	stateEvent = Remotes.event("MatchState")
	matchEvent = Remotes.event("MatchEvent")
	requestEvent = Remotes.event("MatchRequest")
	MatchWorld.build()
end

function MatchService.Start()
	if not MatchService.isEnabled() then
		return
	end
	requestEvent.OnServerEvent:Connect(onRequest)
	MatchRewards.setLeaverContext(leaverContext)
	MatchRewards.onSettled(function(player: Player, data)
		local member = memberByPlayer[player]
		if member then
			sendTo(member, "Rewards", data)
		end
	end)
	CharacterService.onLost(onCharacterLost)
	Combatants.onKnocked(function()
		-- O laço do combate confere os duelos a cada 0,1 s; aqui só atualiza o placar.
		if phase == "Combat" then
			task.defer(checkDuels)
		end
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	watchMiranteFalls()
	task.spawn(runMatch)
end

return MatchService
