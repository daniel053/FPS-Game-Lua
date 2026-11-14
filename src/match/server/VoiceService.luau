--!strict
-- Voz da partida (GDD 12.2, F8), com a API de áudio do Roblox.
-- O place da Partida desliga a voz padrão (VoiceChatService.EnableDefaultVoice = false, no
-- match.project.json): o servidor cria o microfone de cada jogador (AudioDeviceInput no Player) e
-- decide QUEM PODE OUVIR cada um (lista de acesso). É isso que impede a voz da dupla de chegar à dupla
-- adversária, mesmo para um cliente modificado. Regra em Shared/Social/SocialRules.voiceMode.
-- O cliente (VoiceRouter) só escolhe COMO tocar: direto (dupla) ou pela distância (mirante).
-- Quem pode usar voz é decidido pelo Roblox (idade, verificação); o jogo não liga nada sozinho.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatNames = require(Shared.Combat.CombatNames)
local MatchTypes = require(Shared.Match.MatchTypes)
local SocialConfig = require(Shared.Config.SocialConfig)
local SocialRules = require(Shared.Social.SocialRules)

local VoiceService = {}

local inputs: { [Player]: AudioDeviceInput } = {} -- o microfone criado por este serviço
local lastLists: { [Player]: string } = {}
local refreshQueued = false

local function presenceOf(player: Player): SocialRules.Presence
	local team = player:GetAttribute(CombatNames.Attr.TeamId)
	local location = player:GetAttribute(MatchTypes.Attr.Location)
	return {
		userId = player.UserId,
		teamId = if typeof(team) == "string" then team else nil,
		location = if typeof(location) == "string" then location else nil,
	}
end

-- Microfone do jogador, criado pelo servidor. (Scripts do jogo não conseguem ler
-- VoiceChatService.EnableDefaultVoice; se a voz padrão continuar ligada no place por engano, o Roblox
-- cria outro microfone no Player, e a lista de acesso é aplicada nele também.)
local function ensureInput(player: Player)
	local existing = inputs[player]
	if existing and existing.Parent then
		return
	end
	local created = Instance.new("AudioDeviceInput")
	created.Name = SocialConfig.Voice.InputName
	created.Player = player
	created.AccessType = Enum.AccessModifierType.Allow -- só quem está na lista ouve
	created:SetUserIdAccessList({})
	created.Parent = player
	inputs[player] = created
end

local function allInputs(player: Player): { AudioDeviceInput }
	local list = {}
	for _, child in player:GetChildren() do
		if child:IsA("AudioDeviceInput") then
			table.insert(list, child)
		end
	end
	return list
end

local function refresh()
	refreshQueued = false
	local everyone: { SocialRules.Presence } = {}
	local list = Players:GetPlayers()
	for _, player in list do
		table.insert(everyone, presenceOf(player))
	end
	for _, player in list do
		ensureInput(player)
		local listeners = SocialRules.voiceListeners(presenceOf(player), everyone)
		local key = table.concat(listeners, ",")
		if lastLists[player] ~= key then
			lastLists[player] = key
			for _, input in allInputs(player) do
				input.AccessType = Enum.AccessModifierType.Allow
				input:SetUserIdAccessList(listeners)
			end
		end
	end
end

-- Agrupa várias mudanças do mesmo quadro numa conferência só.
function VoiceService.queueRefresh()
	if not refreshQueued then
		refreshQueued = true
		task.defer(refresh)
	end
end

local function watch(player: Player)
	player:GetAttributeChangedSignal(CombatNames.Attr.TeamId):Connect(VoiceService.queueRefresh)
	player:GetAttributeChangedSignal(MatchTypes.Attr.Location):Connect(VoiceService.queueRefresh)
	-- A voz padrão cria o microfone um pouco depois de o jogador entrar
	player.ChildAdded:Connect(function(child: Instance)
		if child:IsA("AudioDeviceInput") then
			lastLists[player] = nil
			VoiceService.queueRefresh()
		end
	end)
	VoiceService.queueRefresh()
end

function VoiceService.Start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		inputs[player] = nil
		lastLists[player] = nil
		VoiceService.queueRefresh()
	end)
	-- Conferência periódica (segurança contra alguma mudança perdida)
	task.spawn(function()
		while true do
			task.wait(SocialConfig.Voice.RefreshSeconds)
			refresh()
		end
	end)
end

return VoiceService
