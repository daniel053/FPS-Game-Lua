--!strict
-- Chat de texto da partida (GDD 12.3, F8): para onde vai o que o jogador digita no chat do Roblox
-- (canal da dupla na ilha; canal do mirante lá em cima) e o prefixo de cada canal nas mensagens.
-- Quem está em cada canal é decidido pelo servidor (ChatChannels).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local CombatNames = require(Shared.Combat.CombatNames)
local MatchTypes = require(Shared.Match.MatchTypes)
local SocialConfig = require(Shared.Config.SocialConfig)
local SocialRules = require(Shared.Social.SocialRules)
local Strings = require(Shared.Config.Strings)

local ChatTarget = {}

local player = Players.LocalPlayer

local function presence(): SocialRules.Presence
	local team = player:GetAttribute(CombatNames.Attr.TeamId)
	local location = player:GetAttribute(MatchTypes.Attr.Location)
	return {
		userId = player.UserId,
		teamId = if typeof(team) == "string" then team else nil,
		location = if typeof(location) == "string" then location else nil,
	}
end

local function update()
	local config = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	if config == nil then
		return
	end
	local name = SocialRules.chatTarget(presence())
	local channel = TextChatService:FindFirstChild(name)
	if channel and channel:IsA("TextChannel") then
		config.TargetTextChannel = channel
	end
end

local function prefixOf(channel: TextChannel?): string?
	if channel == nil then
		return nil
	end
	if channel.Name == SocialConfig.Chat.MiranteChannel then
		return Strings.Social.ChatMirante
	end
	local prefix = SocialConfig.Chat.DuoChannelPrefix
	if string.sub(channel.Name, 1, #prefix) == prefix then
		return Strings.Social.ChatDuo
	end
	return nil
end

function ChatTarget.Start()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	player:GetAttributeChangedSignal(CombatNames.Attr.TeamId):Connect(update)
	player:GetAttributeChangedSignal(MatchTypes.Attr.Location):Connect(update)
	-- O canal pode chegar depois do atributo (o servidor cria e põe o jogador)
	TextChatService.DescendantAdded:Connect(function(child: Instance)
		if child:IsA("TextChannel") or child:IsA("TextSource") then
			task.defer(update)
		end
	end)
	update()

	TextChatService.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
		local tag = prefixOf(message.TextChannel)
		if tag == nil then
			return nil
		end
		local props = Instance.new("TextChatMessageProperties")
		props.PrefixText = tag .. " " .. message.PrefixText
		return props
	end
end

return ChatTarget
