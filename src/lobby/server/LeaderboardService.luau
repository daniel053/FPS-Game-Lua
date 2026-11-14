--!strict
-- Ranking global no lobby (F9, GDD 9.3 e DADOS-JOGADOR 8).
--   * Lê os 100 primeiros do RankLeaderboard_v1 a cada 5 minutos (RankConfig), não a cada tela aberta,
--     para não estourar os limites de pedidos do DataStore. Quem grava é o RankService (fim de partida).
--   * Nomes pelo UserService, em lote, guardados em memória.
--   * O elo ADM fica fixo no topo, com o selo, fora da contagem (RankConfig.AdminPinnedOnLeaderboard).
--   * Manda a lista para todos a cada leitura e para quem pedir (abrir a tela), sem ler de novo.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Shared = ReplicatedStorage.Shared
local Env = require(Shared.Env)
local RankConfig = require(Shared.Config.RankConfig)
local RankRules = require(Shared.Progression.RankRules)
local RankingTypes = require(Shared.Progression.RankingTypes)
local Remotes = require(Shared.Remotes)

local REQUEST_COOLDOWN = 2 -- segundos entre pedidos do mesmo jogador

local LeaderboardService = {}

local boardEvent: RemoteEvent
local requestEvent: RemoteEvent
local board: RankingTypes.Board = { available = false, updatedAt = 0, entries = {}, admins = {} }
local names: { [number]: string } = {}
local lastRequest: { [Player]: number } = {}

-- Nomes de exibição em lote (os que ainda não estão em memória).
local function fillNames(userIds: { number })
	local missing: { number } = {}
	for _, id in userIds do
		if names[id] == nil and id > 0 then
			table.insert(missing, id)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and typeof(infos) == "table" then
		for _, info in infos :: { any } do
			if typeof(info) == "table" and typeof(info.Id) == "number" then
				local display = if typeof(info.DisplayName) == "string" and info.DisplayName ~= ""
					then info.DisplayName
					else info.Username
				if typeof(display) == "string" then
					names[info.Id] = display
				end
			end
		end
	end
	for _, id in missing do
		if names[id] == nil then
			local player = Players:GetPlayerByUserId(id)
			names[id] = if player then player.DisplayName else `#{id}`
		end
	end
end

local function readTop(): { { userId: number, points: number } }?
	local ok, result = pcall(function()
		local store = DataStoreService:GetOrderedDataStore(Env.dataStoreName(RankConfig.LeaderboardStoreName))
		local pages = store:GetSortedAsync(false, RankConfig.LeaderboardTopCount)
		return pages:GetCurrentPage()
	end)
	if not ok then
		warn(`[Ranking] Não foi possível ler o ranking: {result}`)
		return nil
	end
	local list = {}
	for _, item in result :: { any } do
		local userId = tonumber(item.key)
		local points = item.value
		if userId and typeof(points) == "number" and not RankRules.isAdmin(userId) then
			table.insert(list, { userId = userId, points = points })
		end
	end
	return list
end

local function refresh()
	local top = readTop()
	local ids: { number } = {}
	if top then
		for _, row in top do
			table.insert(ids, row.userId)
		end
	end
	if RankConfig.AdminPinnedOnLeaderboard then
		for _, id in RankConfig.AdminUserIds do
			table.insert(ids, id)
		end
	end
	fillNames(ids)

	local admins: { RankingTypes.Entry } = {}
	if RankConfig.AdminPinnedOnLeaderboard then
		for _, id in RankConfig.AdminUserIds do
			table.insert(admins, { userId = id, name = names[id] or `#{id}`, points = 0, tier = "Adm" })
		end
	end
	if top == nil then
		-- Sem resposta: mantém a lista anterior (se houver) e avisa que não está disponível
		board = { available = false, updatedAt = board.updatedAt, entries = board.entries, admins = admins }
	else
		local entries: { RankingTypes.Entry } = {}
		for _, row in top do
			table.insert(entries, {
				userId = row.userId,
				name = names[row.userId] or `#{row.userId}`,
				points = row.points,
				tier = RankRules.tierOf(row.points) :: string,
			})
		end
		board = { available = true, updatedAt = os.time(), entries = entries, admins = admins }
	end
	boardEvent:FireAllClients(board)
end

function LeaderboardService.Init()
	boardEvent = Remotes.event("RankingBoard")
	requestEvent = Remotes.event("RankingRequest")
end

function LeaderboardService.Start()
	requestEvent.OnServerEvent:Connect(function(player: Player)
		local now = os.clock()
		if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
			return
		end
		lastRequest[player] = now
		boardEvent:FireClient(player, board)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastRequest[player] = nil
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(
				if Env.IsDev then RankConfig.DevLeaderboardRefreshSeconds else RankConfig.LeaderboardRefreshSeconds
			)
		end
	end)
end

return LeaderboardService
