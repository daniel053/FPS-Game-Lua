--!strict
-- Elo do jogador (GDD seção 9, DADOS-JOGADOR 4 e 8). Único lugar do jogo que muda `rank`.
--   * applyMatch: PE de uma partida pela colocação (regras em Shared/Progression/RankRules), conta a
--     partida ranqueada e grava o novo PE no ranking global (RankLeaderboard_v1).
--   * Atributo `RankTier` no Player (Bronze… Deus ou Adm) em todos os places, para o placar e o lobby
--     mostrarem o elo de cada um sem pedir o perfil dos outros.
-- O ranking global é um OrderedDataStore (chave = UserId, valor = PE). As gravações vão para uma fila
-- com novas tentativas e espera crescente; o ADM não é gravado (fica fixo no topo, RankConfig).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Env = require(Shared.Env)
local RankConfig = require(Shared.Config.RankConfig)
local RankRules = require(Shared.Progression.RankRules)

local Common = script.Parent
local DataService = require(Common.DataService)
local ProfileRules = require(Common.Data.ProfileRules)

export type MatchResult = {
	ranked: boolean, -- false = partida privada (não mexe no elo)
	delta: number, -- PE que mudou de verdade (depois do piso 0)
	points: number, -- PE depois
	tier: string, -- faixa depois (RankRules.DisplayTier)
	tierBefore: string,
	protected: boolean,
	doubled: boolean,
}

local RankService = {}

local store: OrderedDataStore? = nil
local pendingWrites: { [number]: number } = {} -- UserId -> PE mais recente ainda não gravado
local writerRunning = false

local function setTierAttribute(player: Player, points: number)
	player:SetAttribute(RankRules.Attr.Tier, RankRules.displayTier(player.UserId, points))
end

local function getStore(): OrderedDataStore?
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore(Env.dataStoreName(RankConfig.LeaderboardStoreName))
		end)
		if ok then
			store = result
		else
			warn(`[Elo] Ranking indisponível: {result}`)
		end
	end
	return store
end

-- Grava a fila no ranking, um por vez, respeitando o orçamento de pedidos do DataStore.
local function runWriter()
	if writerRunning then
		return
	end
	writerRunning = true
	task.spawn(function()
		while next(pendingWrites) ~= nil do
			local userId, points = next(pendingWrites)
			pendingWrites[userId :: number] = nil
			local board = getStore()
			if board == nil then
				break
			end
			local delay = 1
			for attempt = 1, RankConfig.LeaderboardWriteRetries do
				while
					DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementSortedAsync)
					< 1
				do
					task.wait(1)
				end
				local ok, err = pcall(function()
					board:SetAsync(tostring(userId), points)
				end)
				if ok then
					break
				end
				if attempt == RankConfig.LeaderboardWriteRetries then
					warn(`[Elo] Não foi possível gravar {userId} no ranking: {err}`)
				else
					task.wait(delay)
					delay *= 2
				end
				-- Chegou um valor mais novo enquanto esperava: ele substitui este
				if pendingWrites[userId :: number] ~= nil then
					break
				end
			end
		end
		writerRunning = false
	end)
end

local function queueLeaderboard(userId: number, points: number)
	if userId <= 0 or RankRules.isAdmin(userId) then
		return -- jogadores de teste do Studio e o ADM não entram na lista
	end
	pendingWrites[userId] = points
	runWriter()
end

-- `isPrivate` = partida privada: não mexe no elo (RankConfig.PrivateMatchesAffectRank).
function RankService.applyMatch(player: Player, outcome: RankRules.Outcome, isPrivate: boolean): MatchResult?
	local profile = DataService.getProfile(player)
	if profile == nil then
		return nil
	end
	local before = profile.rank.points
	local tierBefore: string = RankRules.displayTier(player.UserId, before)
	local ranked = not isPrivate or RankConfig.PrivateMatchesAffectRank
	if not ranked then
		return {
			ranked = false,
			delta = 0,
			points = before,
			tier = tierBefore,
			tierBefore = tierBefore,
			protected = false,
			doubled = false,
		}
	end
	local change = RankRules.delta(before, profile.rank.matchesPlayed, outcome)
	local ok, err = DataService.update(player, function(p)
		local applied, reason = ProfileRules.applyRankDelta(p, change.delta)
		if not applied then
			return false, reason
		end
		return ProfileRules.countRankedMatch(p)
	end)
	if not ok then
		warn(`[Elo] applyMatch({player.UserId}) recusado: {err}`)
		return nil
	end
	local after = (DataService.getProfile(player) or profile).rank.points
	setTierAttribute(player, after)
	queueLeaderboard(player.UserId, after)
	return {
		ranked = true,
		delta = after - before,
		points = after,
		tier = RankRules.displayTier(player.UserId, after) :: string,
		tierBefore = tierBefore,
		protected = change.protected,
		doubled = change.doubled,
	}
end

-- Só para teste (DEV_): muda o PE direto e grava no ranking.
function RankService.devAddPoints(player: Player, amount: number): boolean
	if not Env.IsDev then
		return false
	end
	local ok = DataService.update(player, function(p)
		return ProfileRules.applyRankDelta(p, amount)
	end)
	local profile = DataService.getProfile(player)
	if ok and profile then
		setTierAttribute(player, profile.rank.points)
		queueLeaderboard(player.UserId, profile.rank.points)
	end
	return ok
end

-- Só para teste (DEV_): PE e partidas ranqueadas de volta a zero.
function RankService.devReset(player: Player): boolean
	if not Env.IsDev then
		return false
	end
	local ok = DataService.update(player, function(p)
		p.rank.points = 0
		p.rank.peakPoints = 0
		p.rank.matchesPlayed = 0
		return true, nil
	end)
	if ok then
		setTierAttribute(player, 0)
		queueLeaderboard(player.UserId, 0)
	end
	return ok
end

function RankService.Start()
	DataService.ProfileLoaded:Connect(function(player: Player)
		local profile = DataService.getProfile(player)
		setTierAttribute(player, if profile then profile.rank.points else 0)
	end)
	for _, player in Players:GetPlayers() do
		local profile = DataService.getProfile(player)
		if profile then
			setTierAttribute(player, profile.rank.points)
		end
	end
	game:BindToClose(function()
		-- Dá tempo de gravar o que ficou na fila (o servidor de partida fecha logo depois do fim)
		local deadline = os.clock() + 20
		while (next(pendingWrites) ~= nil or writerRunning) and os.clock() < deadline do
			task.wait(0.5)
		end
	end)
end

return RankService
