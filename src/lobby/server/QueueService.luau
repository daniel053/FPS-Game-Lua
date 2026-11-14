--!strict
-- Fila compartilhada entre os servidores de lobby (GDD 6.2, 6.3 e 16.5; FASES F5).
--
-- Como funciona:
--   * Cada grupo na fila é uma FICHA no MemoryStore (MatchQueue_v1), com validade curta. O lobby
--     dono da ficha a renova a cada TicketRefreshSeconds; se o servidor cair, a ficha some sozinha.
--   * Um lobby por vez é o LÍDER (trava no MatchQueueControl_v1). O líder lê todas as fichas, aplica
--     QueueRules e, quando uma partida fecha: reserva o servidor, grava o MatchHandoff (composição),
--     marca cada ficha com o código do servidor e avisa os outros lobbies (MessagingService).
--   * Cada lobby teleporta os SEUS jogadores (o Roblox só deixa teleportar quem está no servidor).
--     Se o aviso se perder, a renovação da ficha descobre a marca em poucos segundos.
--   * O líder grava o estado da fila (contagem "5/7"); os outros lobbies leem.
-- No Studio não há servidor reservado nem teleporte: a partida é "encontrada" e o grupo é avisado.
--
-- Este serviço não sabe de grupos; o PartyService chama enqueue/dequeue e ouve os eventos.

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage.Shared
local Env = require(Shared.Env)
local QueueConfig = require(Shared.Config.QueueConfig)
local QueueRules = require(Shared.Queue.QueueRules)

local DataService = require(ServerScriptService.Common.DataService)
local Handoff = require(ServerScriptService.Common.Matchmaking.Handoff)
local MemoryMaps = require(ServerScriptService.Common.Matchmaking.MemoryMaps)

local Store = QueueConfig.Store

type Ticket = QueueRules.Ticket

type Assigned = { matchId: string, code: string }

type LocalTicket = {
	id: string,
	players: { Player },
	ticket: Ticket?, -- nil enquanto grava
	removed: boolean,
	teleporting: boolean,
}

-- Eventos para o PartyService:
--   "Queued"      a ficha foi gravada
--   "Status"      a contagem da fila mudou (ticketId = nil)
--   "Teleporting" a partida fechou; teleportando
--   "Failed"      detail = "QueueError" (não entrou na fila) ou "TeleportFailed" (volta para a fila)
--   "Studio"      a partida fechou, mas no Studio não há teleporte (detail = nº de jogadores)
export type EventKind = "Queued" | "Status" | "Teleporting" | "Failed" | "Studio"
type Listener = (ticketId: string?, kind: EventKind, detail: any?) -> ()

local QueueService = {}

local params = QueueRules.params(Env.IsDev)
local jobId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
local topic = MemoryMaps.fullName("MatchFound")

local queueMap: MemoryStoreSortedMap
local controlMap: MemoryStoreSortedMap
local listeners: { Listener } = {}
local localTickets: { [string]: LocalTicket } = {}
local teleportingPlayers: { [Player]: LocalTicket } = {}
local status: QueueRules.Status? = nil
local isLeader = false
local lastLeaderAttempt = -math.huge

-- Avisos repetidos (ex.: Studio sem acesso à API) aparecem no máximo 1 vez por minuto.
local lastWarnAt: { [string]: number } = {}
local function warnThrottled(key: string, message: string)
	local now = os.clock()
	if now - (lastWarnAt[key] or -math.huge) >= 60 then
		lastWarnAt[key] = now
		warn(message)
	end
end

local function emit(ticketId: string?, kind: EventKind, detail: any?)
	for _, listener in listeners do
		task.spawn(listener, ticketId, kind, detail)
	end
end

local function newTicketId(): string
	local guid = string.gsub(HttpService:GenerateGUID(false), "-", "")
	return string.sub(guid, 1, 16)
end

local function inGame(player: Player): boolean
	return player.Parent == Players
end

-- Ficha lida do MemoryStore (validada: o MemoryStore é nosso, mas um formato antigo não pode travar a fila).
local function parseTicket(raw: any): (Ticket?, Assigned?)
	if typeof(raw) ~= "table" or typeof(raw.id) ~= "string" or typeof(raw.userIds) ~= "table" then
		return nil, nil
	end
	local userIds: { number } = {}
	for _, v in raw.userIds do
		if typeof(v) ~= "number" then
			return nil, nil
		end
		table.insert(userIds, v)
	end
	if #userIds == 0 or #userIds > QueueConfig.PartySize then
		return nil, nil
	end
	local tier: QueueRules.Tier = if raw.tier == "Experientes" then "Experientes" else "Aprendizes"
	local ticket: Ticket = {
		id = raw.id,
		userIds = userIds,
		tier = tier,
		enqueuedAt = if typeof(raw.enqueuedAt) == "number" then raw.enqueuedAt else 0,
		priority = raw.priority == true,
	}
	local assigned: Assigned? = nil
	local a = raw.assigned
	if typeof(a) == "table" and typeof(a.matchId) == "string" and typeof(a.code) == "string" then
		assigned = { matchId = a.matchId, code = a.code }
	end
	return ticket, assigned
end

-- Teleporte ---------------------------------------------------------------------------------------

local function failTeleport(rec: LocalTicket, players: { Player })
	for _, player in players do
		if teleportingPlayers[player] == rec then
			teleportingPlayers[player] = nil
		end
		DataService.reopenAfterFailedTeleport(player)
	end
	emit(rec.id, "Failed", "TeleportFailed")
end

local function startTeleport(rec: LocalTicket, assigned: Assigned)
	if rec.teleporting or rec.removed then
		return
	end
	rec.teleporting = true
	localTickets[rec.id] = nil -- para de renovar
	emit(rec.id, "Teleporting")
	task.spawn(function()
		MemoryMaps.retry("apagar ficha", function()
			queueMap:RemoveAsync(rec.id)
			return true
		end)
	end)

	local players: { Player } = {}
	for _, player in rec.players do
		if inGame(player) then
			table.insert(players, player)
		end
	end
	if #players == 0 then
		return
	end
	if assigned.code == "" then
		emit(rec.id, "Studio")
		return
	end

	-- Salva e libera o perfil de cada um (DADOS-JOGADOR 5.3), em paralelo.
	local pending = #players
	local allReleased = true
	for _, player in players do
		task.spawn(function()
			if not DataService.releaseForTeleportAsync(player) then
				allReleased = false
			end
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait(0.1)
	end
	if not allReleased then
		-- A dupla viaja junta ou não viaja: quem já liberou reabre o perfil aqui.
		failTeleport(rec, players)
		return
	end

	for _, player in players do
		teleportingPlayers[player] = rec
	end
	local ok, err = pcall(function()
		TeleportService:TeleportToPrivateServer(Env.getPlaceId("Match"), assigned.code, players)
	end)
	if not ok then
		warn(`[Fila] Teleporte para a partida falhou: {err}`)
		failTeleport(rec, players)
		return
	end
	-- Ninguém fica preso em teleporte: se alguém continuar aqui, volta para a fila.
	task.delay(QueueConfig.TeleportStuckSeconds, function()
		local stuck: { Player } = {}
		for _, player in players do
			if inGame(player) and teleportingPlayers[player] == rec then
				table.insert(stuck, player)
			end
		end
		if #stuck > 0 then
			warn(`[Fila] Teleporte travado para {#stuck} jogador(es); voltando para a fila`)
			failTeleport(rec, stuck)
		end
	end)
end

-- Ficha local --------------------------------------------------------------------------------------

-- Renova a validade e confere se o líder já chamou esta ficha para uma partida.
local function refreshTicket(rec: LocalTicket)
	local ticket = rec.ticket
	if ticket == nil or rec.removed or rec.teleporting then
		return
	end
	local assigned: Assigned? = nil
	local ok, err = pcall(function()
		queueMap:UpdateAsync(rec.id, function(old: any)
			if old == nil then
				return ticket -- expirou (ex.: falha passageira): grava de novo
			end
			local _, a = parseTicket(old)
			assigned = a
			return old -- mantém a marca do líder, se houver
		end, Store.TicketTtlSeconds)
	end)
	if not ok then
		warnThrottled("refresh", `[Fila] Renovar ficha falhou: {err}`)
		return
	end
	if assigned and not rec.removed then
		startTeleport(rec, assigned)
	end
end

function QueueService.enqueue(players: { Player }, priority: boolean): string
	local id = newTicketId()
	local rec: LocalTicket =
		{ id = id, players = table.clone(players), ticket = nil, removed = false, teleporting = false }
	localTickets[id] = rec
	task.spawn(function()
		local levels: { QueueRules.PlayerLevel } = {}
		local userIds: { number } = {}
		for _, player in players do
			local profile = DataService.waitForProfile(player, 15)
			if profile == nil then
				localTickets[id] = nil
				emit(id, "Failed", "QueueError")
				return
			end
			table.insert(levels, { points = profile.rank.points, matchesPlayed = profile.stats.matchesPlayed })
			table.insert(userIds, player.UserId)
		end
		local ticket: Ticket = {
			id = id,
			userIds = userIds,
			tier = QueueRules.groupTier(levels),
			enqueuedAt = MemoryMaps.now(),
			priority = priority,
		}
		if rec.removed then
			return
		end
		local ok = MemoryMaps.retry("gravar ficha", function()
			return queueMap:SetAsync(id, ticket, Store.TicketTtlSeconds)
		end)
		if not ok then
			localTickets[id] = nil
			emit(id, "Failed", "QueueError")
			return
		end
		rec.ticket = ticket
		if rec.removed then
			-- Cancelou enquanto gravava
			pcall(function()
				queueMap:RemoveAsync(id)
			end)
			return
		end
		emit(id, "Queued")
	end)
	return id
end

-- Sai da fila. Devolve false se já está teleportando (tarde demais para cancelar).
function QueueService.dequeue(ticketId: string): boolean
	local rec = localTickets[ticketId]
	if rec == nil then
		return true
	end
	if rec.teleporting then
		return false
	end
	rec.removed = true
	localTickets[ticketId] = nil
	task.spawn(function()
		MemoryMaps.retry("apagar ficha", function()
			queueMap:RemoveAsync(ticketId)
			return true
		end)
	end)
	return true
end

function QueueService.statusFor(ticketId: string): QueueRules.PoolStatus?
	local rec = localTickets[ticketId]
	local current = status
	if rec == nil or rec.ticket == nil or current == nil then
		return nil
	end
	return current.pools[rec.ticket.tier]
end

function QueueService.onEvent(listener: Listener)
	table.insert(listeners, listener)
end

-- Líder --------------------------------------------------------------------------------------------

local function tryLeadership(): boolean
	local now = MemoryMaps.now()
	-- O líder renova a trava a cada 1/3 da validade; os outros tentam a cada metade.
	local interval = if isLeader then Store.LeaderLockSeconds / 3 else Store.LeaderLockSeconds / 2
	if now - lastLeaderAttempt < interval then
		return isLeader
	end
	lastLeaderAttempt = now
	local became = false
	local ok, err = pcall(function()
		controlMap:UpdateAsync("leader", function(old: any)
			local t = MemoryMaps.now()
			if
				typeof(old) == "table"
				and old.jobId ~= jobId
				and typeof(old.untilAt) == "number"
				and old.untilAt > t
			then
				became = false
				return nil -- outro lobby é o líder
			end
			became = true
			return { jobId = jobId, untilAt = t + Store.LeaderLockSeconds }
		end, Store.LeaderLockSeconds)
	end)
	if not ok then
		warnThrottled("leader", `[Fila] Trava do líder falhou: {err}`)
		became = false
	end
	if became ~= isLeader then
		print(if became then "[Fila] Este lobby agora monta as partidas (líder)" else "[Fila] Deixou de ser o líder")
	end
	isLeader = became
	return became
end

local function readAllTickets(): { { ticket: Ticket, assigned: Assigned? } }
	local result: { { ticket: Ticket, assigned: Assigned? } } = {}
	local lower: string? = nil
	while #result < Store.MaxTicketsRead do
		local ok, items = pcall(function()
			return queueMap:GetRangeAsync(Enum.SortDirection.Ascending, 200, lower)
		end)
		if not ok or typeof(items) ~= "table" or #items == 0 then
			break
		end
		for _, item in items do
			local ticket, assigned = parseTicket(item.value)
			if ticket then
				table.insert(result, { ticket = ticket, assigned = assigned })
			end
			lower = item.key
		end
		if #items < 200 then
			break
		end
	end
	return result
end

local function releaseClaims(ids: { string }, matchId: string)
	for _, id in ids do
		pcall(function()
			queueMap:UpdateAsync(id, function(old: any)
				if typeof(old) == "table" and typeof(old.assigned) == "table" and old.assigned.matchId == matchId then
					old.assigned = nil
					return old
				end
				return nil
			end, Store.TicketTtlSeconds)
		end)
	end
end

-- Monta uma partida: reserva o servidor, grava a composição, marca as fichas e avisa os lobbies.
local function launch(plan: QueueRules.Plan)
	local matchId = newTicketId()
	local code = ""
	if not Env.IsStudio then
		local placeId = Env.getPlaceId("Match")
		if placeId == 0 then
			warn("[Fila] Place da Partida sem ID em PlaceConfig")
			return
		end
		local ok, accessCode, privateServerId = pcall(function(): (string, string)
			local a, b = (TeleportService :: any):ReserveServerAsync(placeId)
			return a, b
		end)
		if not ok then
			warn(`[Fila] Reservar servidor falhou: {accessCode}`)
			return
		end
		local handoff: Handoff.MatchHandoff = {
			matchId = matchId,
			userIds = plan.userIds,
			duos = plan.duos,
			pool = plan.pool,
			createdAt = MemoryMaps.now(),
			isPrivate = false, -- a fila só monta partidas normais; as privadas chegam na F11
		}
		if not Handoff.writeMatch(privateServerId, handoff) then
			return
		end
		code = accessCode
	end

	local claimed: { string } = {}
	for _, id in plan.ticketIds do
		local got = false
		pcall(function()
			queueMap:UpdateAsync(id, function(old: any)
				if typeof(old) ~= "table" or old.assigned ~= nil then
					got = false
					return nil -- saiu da fila ou já foi chamada
				end
				got = true
				old.assigned = { matchId = matchId, code = code }
				return old
			end, Store.TicketTtlSeconds)
		end)
		if not got then
			releaseClaims(claimed, matchId)
			return -- tenta de novo no próximo ciclo, com a fila atualizada
		end
		table.insert(claimed, id)
	end

	print(`[Fila] Partida {matchId}: {#plan.userIds} jogador(es), faixa {plan.pool}`)
	pcall(function()
		MessagingService:PublishAsync(topic, { m = matchId, c = code, t = plan.ticketIds })
	end)
	for _, id in plan.ticketIds do
		local rec = localTickets[id]
		if rec then
			startTeleport(rec, { matchId = matchId, code = code })
		end
	end
end

local function leaderTick()
	local entries = readAllTickets()
	local open: { Ticket } = {}
	for _, entry in entries do
		if entry.assigned == nil then
			table.insert(open, entry.ticket)
		end
	end
	local force = false
	if Env.IsDev then
		local ok, value = pcall(function()
			return controlMap:GetAsync("force")
		end)
		force = ok and value == true
	end
	local plans, newStatus = QueueRules.plan(open, MemoryMaps.now(), params, force)
	status = newStatus
	emit(nil, "Status")
	pcall(function()
		controlMap:SetAsync("status", newStatus, Store.StatusTtlSeconds)
	end)
	if force and #plans > 0 then
		pcall(function()
			controlMap:RemoveAsync("force")
		end)
	end
	for _, plan in plans do
		launch(plan)
	end
end

local function readStatus()
	local ok, value = pcall(function()
		return controlMap:GetAsync("status")
	end)
	if not ok or typeof(value) ~= "table" or typeof(value.pools) ~= "table" then
		return
	end
	local pools: { [string]: QueueRules.PoolStatus } = {}
	for tier, pool in value.pools do
		if typeof(tier) == "string" and typeof(pool) == "table" and typeof(pool.count) == "number" then
			pools[tier] = {
				count = pool.count,
				target = if typeof(pool.target) == "number" then pool.target else params.minPlayers,
				startsAt = if typeof(pool.startsAt) == "number" then pool.startsAt else nil,
			}
		end
	end
	status = { merged = value.merged == true, pools = pools }
	emit(nil, "Status")
end

-- Teste (DEV_) -------------------------------------------------------------------------------------

function QueueService.devForceStart(): boolean
	if not Env.IsDev then
		return false
	end
	local ok = pcall(function()
		controlMap:SetAsync("force", true, Store.DevForceTtlSeconds)
	end)
	return ok
end

function QueueService.devDescribe(): string
	local count = 0
	for _ in localTickets do
		count += 1
	end
	local parts = { `líder: {if isLeader then "este lobby" else "outro lobby"}`, `fichas daqui: {count}` }
	local current = status
	if current then
		for tier, pool in current.pools do
			table.insert(parts, `{tier}: {pool.count}/{pool.target}`)
		end
		if current.merged then
			table.insert(parts, "faixas juntas")
		end
	end
	return table.concat(parts, " · ")
end

function QueueService.devPrintQueue()
	local entries = readAllTickets()
	print(`[Fila] {#entries} ficha(s) em {MemoryMaps.fullName(MemoryMaps.Names.Queue)}:`)
	local now = MemoryMaps.now()
	for _, entry in entries do
		local t = entry.ticket
		print(
			`  {t.id} · {table.concat(t.userIds, ", ")} · {t.tier} · {string.format("%.0f", now - t.enqueuedAt)} s`
				.. (if t.priority then " · prioridade" else "")
				.. (if entry.assigned then ` · chamada (partida {entry.assigned.matchId})` else "")
		)
	end
end

-- Ciclo de vida ------------------------------------------------------------------------------------

function QueueService.Init()
	queueMap = MemoryMaps.get(MemoryMaps.Names.Queue)
	controlMap = MemoryMaps.get(MemoryMaps.Names.Control)
end

function QueueService.Start()
	-- Aviso do líder: "estas fichas foram chamadas" (pode se perder; a renovação cobre).
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(topic, function(message: any)
				local data = message.Data
				if typeof(data) ~= "table" or typeof(data.t) ~= "table" then
					return
				end
				if typeof(data.m) ~= "string" or typeof(data.c) ~= "string" then
					return
				end
				for _, id in data.t do
					local rec = if typeof(id) == "string" then localTickets[id] else nil
					if rec then
						startTeleport(rec, { matchId = data.m, code = data.c })
					end
				end
			end)
		end)
		if not ok then
			warn(`[Fila] MessagingService indisponível ({err}); a fila usa só a renovação das fichas`)
		end
	end)

	-- Renovação das fichas deste lobby
	task.spawn(function()
		while true do
			task.wait(Store.TicketRefreshSeconds)
			for _, rec in localTickets do
				task.spawn(refreshTicket, rec)
			end
		end
	end)

	-- Líder e estado da fila
	task.spawn(function()
		local lastStatusRead = -math.huge
		while true do
			if tryLeadership() then
				local ok, err = pcall(function()
					leaderTick()
				end)
				if not ok then
					warnThrottled("tick", `[Fila] Ciclo do líder falhou: {err}`)
				end
			elseif next(localTickets) ~= nil and os.clock() - lastStatusRead >= Store.StatusPollSeconds then
				lastStatusRead = os.clock()
				readStatus()
			end
			task.wait(Store.LeaderTickSeconds)
		end
	end)

	TeleportService.TeleportInitFailed:Connect(function(player: Player, result: Enum.TeleportResult, message: string)
		local rec = teleportingPlayers[player]
		if rec then
			warn(`[Fila] TeleportInitFailed {player.UserId}: {result.Name} {message}`)
			failTeleport(rec, { player })
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		teleportingPlayers[player] = nil
	end)
end

return QueueService
