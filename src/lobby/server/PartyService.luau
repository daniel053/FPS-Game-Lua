--!strict
-- Grupo de 2 no lobby (GDD 6.4 e 4.8; decisões da F5):
--   * Todo jogador tem um grupo (sozinho = grupo de 1).
--   * Convite dentro do jogo para qualquer jogador do mesmo servidor de lobby; ele aceita ou recusa.
--     Amigos de fora chegam pelo convite nativo do Roblox (no cliente) e caem neste servidor.
--   * JOGAR deixa o jogador "pronto"; com os 2 prontos, o grupo entra na fila como dupla fixa.
--     Cancelar (qualquer um) tira o grupo da fila.
--   * Se um dos dois sai do jogo ou do grupo, o outro sai da fila com um aviso.
--   * Volta da partida (LobbyHandoff): refaz a dupla fixa quando os dois chegam e, em "Nova
--     partida", entra direto na fila. Quem voltou porque a partida não aconteceu passa na frente.
-- O servidor decide tudo; o cliente só pede (LobbyRequest) e mostra a foto (LobbyState).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local LobbyTypes = require(Shared.Queue.LobbyTypes)
local QueueConfig = require(Shared.Config.QueueConfig)
local RankRules = require(Shared.Progression.RankRules)
local Remotes = require(Shared.Remotes)

local DataService = require(ServerScriptService.Common.DataService)
local Handoff = require(ServerScriptService.Common.Matchmaking.Handoff)
local QueueService = require(script.Parent.QueueService)

type Party = {
	members: { Player },
	ready: { [Player]: boolean },
	state: LobbyTypes.PartyState,
	ticketId: string?,
	priority: boolean, -- próxima entrada na fila passa na frente
}

local PartyService = {}

local stateEvent: RemoteEvent
local requestEvent: RemoteEvent
local lobbyEvent: RemoteEvent

local partyOf: { [Player]: Party } = {}
local invites: { [Player]: { [Player]: number } } = {} -- invites[convidado][quem convidou] = expira em
local arrivals: { [Player]: Handoff.LobbyHandoff } = {}
local requestWindow: { [Player]: { start: number, count: number } } = {}
local pushScheduled = false

local function notice(player: Player, key: string, name: string?)
	if player.Parent == Players then
		lobbyEvent:FireClient(player, "Notice", { key = key, name = name })
	end
end

local function noticeParty(party: Party, key: string, except: Player?, name: string?)
	for _, member in party.members do
		if member ~= except then
			notice(member, key, name)
		end
	end
end

-- Foto -------------------------------------------------------------------------------------------

local function memberView(player: Player, party: Party): LobbyTypes.MemberView
	local profile = DataService.getProfile(player)
	return {
		userId = player.UserId,
		name = player.DisplayName,
		rankTier = RankRules.displayTier(player.UserId, if profile then profile.rank.points else 0),
		ready = party.ready[player] == true,
	}
end

local function canBeInvited(player: Player): boolean
	local party = partyOf[player]
	return party ~= nil and #party.members == 1 and party.state == "Idle"
end

local function snapshotFor(player: Player): LobbyTypes.Snapshot?
	local party = partyOf[player]
	if party == nil then
		return nil
	end
	local members: { LobbyTypes.MemberView } = { memberView(player, party) }
	for _, member in party.members do
		if member ~= player then
			table.insert(members, memberView(member, party))
		end
	end

	local queue: LobbyTypes.QueueView? = nil
	if party.state == "Queued" and party.ticketId then
		local pool = QueueService.statusFor(party.ticketId)
		if pool then
			queue = { count = pool.count, target = pool.target, startsAt = pool.startsAt }
		else
			queue = { count = #party.members, target = QueueConfig.MinPlayersToStart, startsAt = nil }
		end
	end

	local now = os.clock()
	local invitesIn: { LobbyTypes.PlayerRef } = {}
	local mine = invites[player]
	if mine then
		for from, expiresAt in mine do
			if expiresAt > now and from.Parent == Players then
				table.insert(invitesIn, { userId = from.UserId, name = from.DisplayName })
			end
		end
	end
	local invitedOut: { number } = {}
	for target, list in invites do
		local expiresAt = list[player]
		if expiresAt and expiresAt > now then
			table.insert(invitedOut, target.UserId)
		end
	end

	local available: { LobbyTypes.PlayerRef } = {}
	if #party.members < QueueConfig.PartySize and party.state == "Idle" then
		for _, other in Players:GetPlayers() do
			if other ~= player and canBeInvited(other) then
				table.insert(available, { userId = other.UserId, name = other.DisplayName })
			end
		end
	end

	return {
		members = members,
		state = party.state,
		queue = queue,
		invitesIn = invitesIn,
		invitedOut = invitedOut,
		available = available,
	}
end

-- Qualquer mudança muda a lista "dá para convidar" de todo mundo: manda a foto para todos,
-- uma vez por quadro.
local function pushAll()
	if pushScheduled then
		return
	end
	pushScheduled = true
	task.defer(function()
		pushScheduled = false
		for player in partyOf do
			local snap = snapshotFor(player)
			if snap and player.Parent == Players then
				stateEvent:FireClient(player, snap)
			end
		end
	end)
end

-- Fila -------------------------------------------------------------------------------------------

local function partyOfTicket(ticketId: string): Party?
	for _, party in partyOf do
		if party.ticketId == ticketId then
			return party
		end
	end
	return nil
end

local function tryQueue(party: Party)
	if party.state ~= "Idle" or #party.members == 0 then
		return
	end
	for _, member in party.members do
		if not party.ready[member] then
			return
		end
	end
	party.ticketId = QueueService.enqueue(party.members, party.priority)
	party.priority = false
	party.state = "Queued"
	pushAll()
end

local function leaveQueue(party: Party)
	if party.state == "Queued" and party.ticketId then
		if not QueueService.dequeue(party.ticketId) then
			return -- já está teleportando
		end
	end
	if party.state ~= "Teleporting" then
		party.state = "Idle"
		party.ticketId = nil
		table.clear(party.ready)
	end
end

-- Grupo ------------------------------------------------------------------------------------------

local function newSolo(player: Player): Party
	local party: Party = { members = { player }, ready = {}, state = "Idle", ticketId = nil, priority = false }
	partyOf[player] = party
	return party
end

local function clearInvitesOf(player: Player)
	invites[player] = nil
	for _, list in invites do
		list[player] = nil
	end
end

-- Tira o jogador do grupo (sair do grupo ou do jogo). O outro sai da fila e é avisado.
local function removeFromParty(player: Player, leftGame: boolean)
	local party = partyOf[player]
	if party == nil then
		return
	end
	partyOf[player] = nil
	local index = table.find(party.members, player)
	if index then
		table.remove(party.members, index)
	end
	party.ready[player] = nil
	if #party.members > 0 and party.state ~= "Teleporting" then
		local wasQueued = party.state == "Queued"
		leaveQueue(party)
		noticeParty(
			party,
			if leftGame then "PartnerLeftGame" elseif wasQueued then "PartnerLeftQueue" else "PartnerLeftParty",
			nil,
			player.DisplayName
		)
	end
	if not leftGame then
		newSolo(player)
	end
	pushAll()
end

local function join(player: Player, host: Party)
	local own = partyOf[player]
	if own and own ~= host then
		leaveQueue(own)
	end
	partyOf[player] = host
	table.insert(host.members, player)
	table.clear(host.ready)
	clearInvitesOf(player)
	for _, member in host.members do
		clearInvitesOf(member)
	end
end

-- Volta da partida -------------------------------------------------------------------------------

local function resolveArrival(player: Player)
	local data = arrivals[player]
	if data == nil or player.Parent ~= Players then
		return
	end
	local party = partyOf[player]
	if party == nil then
		return
	end

	if data.partyWith then
		local partner = Players:GetPlayerByUserId(data.partyWith)
		local partnerData = if partner then arrivals[partner] else nil
		if partner and partnerData and partnerData.partyWith == player.UserId then
			arrivals[player] = nil
			arrivals[partner] = nil
			local partnerParty = partyOf[partner]
			if partnerParty and canBeInvited(player) and canBeInvited(partner) then
				join(player, partnerParty)
				if data.autoQueue and partnerData.autoQueue then
					partnerParty.ready[player] = true
					partnerParty.ready[partner] = true
					partnerParty.priority = data.priority or partnerData.priority
					tryQueue(partnerParty)
				end
				pushAll()
			end
			return
		end
		-- O parceiro ainda não chegou: espera um pouco e depois segue sozinho.
		task.delay(QueueConfig.PartnerArrivalWaitSeconds, function()
			if arrivals[player] == data then
				data.partyWith = nil
				resolveArrival(player)
			end
		end)
		return
	end

	arrivals[player] = nil
	if data.autoQueue and canBeInvited(player) then
		party.ready[player] = true
		party.priority = data.priority
		tryQueue(party)
	end
	pushAll()
end

-- Pedidos ----------------------------------------------------------------------------------------

local function rateLimited(player: Player): boolean
	local now = os.clock()
	local window = requestWindow[player]
	if window == nil or now - window.start >= 1 then
		requestWindow[player] = { start = now, count = 1 }
		return false
	end
	window.count += 1
	return window.count > QueueConfig.RequestsPerSecond
end

local function playerFromId(value: unknown): Player?
	if typeof(value) ~= "number" or value ~= math.floor(value) then
		return nil
	end
	local other = Players:GetPlayerByUserId(value)
	return if other and partyOf[other] then other else nil
end

local function onRequest(player: Player, kind: unknown, arg: unknown)
	local party = partyOf[player]
	if party == nil or rateLimited(player) then
		return
	end

	if kind == "Invite" then
		local target = playerFromId(arg)
		if target == nil or target == player then
			return
		end
		if #party.members >= QueueConfig.PartySize or party.state ~= "Idle" or not canBeInvited(target) then
			notice(player, "CannotInvite")
			pushAll()
			return
		end
		local list = invites[target]
		if list == nil then
			list = {}
			invites[target] = list
		end
		list[player] = os.clock() + QueueConfig.InviteExpireSeconds
		notice(target, "InviteReceived", player.DisplayName)
		task.delay(QueueConfig.InviteExpireSeconds + 0.1, pushAll) -- some da tela quando expira
		pushAll()
	elseif kind == "AcceptInvite" then
		local from = playerFromId(arg)
		local list = invites[player]
		local expiresAt = if from and list then list[from] else nil
		if from == nil or expiresAt == nil or expiresAt < os.clock() then
			notice(player, "InviteExpired")
			pushAll()
			return
		end
		local host = partyOf[from]
		if host == nil or #host.members >= QueueConfig.PartySize or host.state ~= "Idle" or #party.members > 1 then
			if list then
				list[from] = nil
			end
			notice(player, "InviteExpired")
			pushAll()
			return
		end
		join(player, host)
		noticeParty(host, "PartnerJoined", player, player.DisplayName)
		pushAll()
	elseif kind == "DeclineInvite" then
		local from = playerFromId(arg)
		local list = invites[player]
		if from and list and list[from] then
			list[from] = nil
			notice(from, "InviteDeclined", player.DisplayName)
			pushAll()
		end
	elseif kind == "LeaveParty" then
		if #party.members > 1 and party.state ~= "Teleporting" then
			removeFromParty(player, false)
			notice(player, "YouLeftParty")
		end
	elseif kind == "Play" then
		if party.state == "Idle" and not party.ready[player] then
			party.ready[player] = true
			if #party.members > 1 then
				noticeParty(party, "PartnerReady", player, player.DisplayName)
			end
			tryQueue(party)
			pushAll()
		end
	elseif kind == "Cancel" then
		if party.state == "Queued" then
			leaveQueue(party)
			noticeParty(party, "QueueCanceledBy", player, player.DisplayName)
			pushAll()
		elseif party.state == "Idle" and party.ready[player] then
			party.ready[player] = nil
			pushAll()
		end
	end
end

-- Eventos da fila --------------------------------------------------------------------------------

local function onQueueEvent(ticketId: string?, kind: QueueService.EventKind, detail: any?)
	if kind == "Status" then
		pushAll()
		return
	end
	local party = if ticketId then partyOfTicket(ticketId) else nil
	if party == nil then
		return
	end
	if kind == "Teleporting" then
		party.state = "Teleporting"
		noticeParty(party, "MatchFound")
	elseif kind == "Failed" then
		party.state = "Idle"
		party.ticketId = nil
		if detail == "TeleportFailed" then
			-- Volta para a fila, na frente, sem precisar apertar JOGAR de novo.
			noticeParty(party, "TeleportFailed")
			local here: { Player } = {}
			for _, member in party.members do
				if member.Parent == Players then
					table.insert(here, member)
				end
			end
			party.members = here
			party.priority = true
			tryQueue(party)
		else
			table.clear(party.ready)
			noticeParty(party, "QueueError")
		end
	elseif kind == "Studio" then
		party.state = "Idle"
		party.ticketId = nil
		table.clear(party.ready)
		noticeParty(party, "StudioMatchFound")
	end
	pushAll()
end

-- Ciclo de vida ----------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	if partyOf[player] then
		return
	end
	newSolo(player)
	pushAll()
	task.spawn(function()
		local data = Handoff.takeLobby(player.UserId)
		if data and player.Parent == Players then
			arrivals[player] = data
			-- O perfil precisa estar carregado para entrar na fila (faixa de elo).
			DataService.waitForProfile(player, 20)
			resolveArrival(player)
		end
	end)
end

function PartyService.Init()
	stateEvent = Remotes.event("LobbyState")
	requestEvent = Remotes.event("LobbyRequest")
	lobbyEvent = Remotes.event("LobbyEvent")
end

function PartyService.Start()
	QueueService.onEvent(onQueueEvent)
	requestEvent.OnServerEvent:Connect(onRequest)
	DataService.ProfileLoaded:Connect(function()
		pushAll() -- elo dos membros aparece quando o perfil carrega
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		requestWindow[player] = nil
		arrivals[player] = nil
		clearInvitesOf(player)
		removeFromParty(player, true)
		pushAll()
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PartyService
