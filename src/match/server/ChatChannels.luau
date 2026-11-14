--!strict
-- Chat de texto da partida (GDD 12.3, F8): o chat do Roblox, num canal só da dupla e num canal do
-- mirante (quem está lá). O canal geral do servidor não existe na Partida
-- (TextChatService.CreateDefaultTextChannels = false, no match.project.json).
-- Quem pode digitar e o filtro são do Roblox; o jogo só decide quem está em cada canal.
-- Regra: Shared/Social/SocialRules.chatChannels. O cliente (ChatTarget) escolhe para onde vai o que
-- o jogador digita.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local CombatNames = require(Shared.Combat.CombatNames)
local MatchTypes = require(Shared.Match.MatchTypes)
local SocialConfig = require(Shared.Config.SocialConfig)
local SocialRules = require(Shared.Social.SocialRules)

local ChatChannels = {}

local queued: { [Player]: boolean } = {}
local syncing: { [Player]: boolean } = {}
local rerun: { [Player]: boolean } = {}

local function presenceOf(player: Player): SocialRules.Presence
	local team = player:GetAttribute(CombatNames.Attr.TeamId)
	local location = player:GetAttribute(MatchTypes.Attr.Location)
	return {
		userId = player.UserId,
		teamId = if typeof(team) == "string" then team else nil,
		location = if typeof(location) == "string" then location else nil,
	}
end

local function isOurs(name: string): boolean
	return name == SocialConfig.Chat.MiranteChannel
		or string.sub(name, 1, #SocialConfig.Chat.DuoChannelPrefix) == SocialConfig.Chat.DuoChannelPrefix
end

local function channel(name: string): TextChannel
	local existing = TextChatService:FindFirstChild(name)
	if existing and existing:IsA("TextChannel") then
		return existing
	end
	local created = Instance.new("TextChannel")
	created.Name = name
	created.Parent = TextChatService
	return created
end

local function sourceOf(ch: TextChannel, userId: number): TextSource?
	for _, child in ch:GetChildren() do
		if child:IsA("TextSource") and child.UserId == userId then
			return child
		end
	end
	return nil
end

local queue: (player: Player) -> ()

local function syncNow(player: Player)
	if player.Parent ~= Players or player.UserId <= 0 then
		return -- jogadores de teste do Studio (UserId negativo) não entram em canais
	end
	local wanted = SocialRules.chatChannels(presenceOf(player))
	-- Sai dos canais que não valem mais
	for _, child in TextChatService:GetChildren() do
		if child:IsA("TextChannel") and isOurs(child.Name) and not wanted[child.Name] then
			local source = sourceOf(child, player.UserId)
			if source then
				source:Destroy()
			end
		end
	end
	-- Entra nos que faltam
	for name in wanted do
		local ch = channel(name)
		if sourceOf(ch, player.UserId) == nil then
			local ok, err = pcall(function()
				ch:AddUserAsync(player.UserId)
			end)
			if not ok then
				warn(`[Chat] Não deu para pôr {player.Name} no canal {name}: {err}`)
			end
		end
	end
end

-- Entrar num canal espera (AddUserAsync): uma conferência por jogador de cada vez; o que mudar no
-- meio é conferido de novo no fim.
local function sync(player: Player)
	queued[player] = nil
	if syncing[player] then
		rerun[player] = true
		return
	end
	syncing[player] = true
	syncNow(player)
	syncing[player] = nil
	if rerun[player] then
		rerun[player] = nil
		queue(player)
	end
end

function queue(player: Player)
	if not queued[player] then
		queued[player] = true
		task.defer(sync, player)
	end
end

-- Canais de dupla vazios (partida nova) somem.
local function cleanUp()
	for _, child in TextChatService:GetChildren() do
		if child:IsA("TextChannel") and isOurs(child.Name) and child.Name ~= SocialConfig.Chat.MiranteChannel then
			if child:FindFirstChildOfClass("TextSource") == nil then
				child:Destroy()
			end
		end
	end
end

local function watch(player: Player)
	player:GetAttributeChangedSignal(CombatNames.Attr.TeamId):Connect(function()
		queue(player)
	end)
	player:GetAttributeChangedSignal(MatchTypes.Attr.Location):Connect(function()
		queue(player)
	end)
	queue(player)
end

function ChatChannels.Start()
	channel(SocialConfig.Chat.MiranteChannel)
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		queued[player] = nil
		rerun[player] = nil
		task.defer(cleanUp)
	end)
	task.spawn(function()
		while true do
			task.wait(30)
			cleanUp()
		end
	end)
end

return ChatChannels
