--!strict
-- Como a voz toca neste cliente (GDD 12.2, F8). Quem pode ouvir quem é decidido pelo servidor
-- (VoiceService, lista de acesso no microfone de cada jogador); aqui só se escolhe o caminho do som:
--   * Direto: parceiro de dupla, sem depender da distância (rodada, derrubado espectando);
--   * Pela distância: todos no mirante (AudioEmitter no personagem de quem fala, AudioListener na câmera);
--   * Nada: qualquer outro caso.
-- Tudo passa por um AudioFader com o volume de voz das configurações (master × voz).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage.Shared
local CombatNames = require(Shared.Combat.CombatNames)
local MatchTypes = require(Shared.Match.MatchTypes)
local SocialConfig = require(Shared.Config.SocialConfig)
local SocialRules = require(Shared.Social.SocialRules)

local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)

type Route = {
	mode: SocialRules.VoiceMode,
	input: AudioDeviceInput?,
	wire: Wire?,
	emitter: AudioEmitter?,
}

local VoiceRouter = {}

local player = Players.LocalPlayer
local folder: Folder
local fader: AudioFader
local listener: AudioListener?
local routes: { [Player]: Route } = {}
local queued = false

local function wire(source: Instance, target: Instance, parent: Instance): Wire
	local w = Instance.new("Wire")
	w.SourceInstance = source
	w.TargetInstance = target
	w.Parent = parent
	return w
end

local function presenceOf(p: Player): SocialRules.Presence
	local team = p:GetAttribute(CombatNames.Attr.TeamId)
	local location = p:GetAttribute(MatchTypes.Attr.Location)
	return {
		userId = p.UserId,
		teamId = if typeof(team) == "string" then team else nil,
		location = if typeof(location) == "string" then location else nil,
	}
end

local function clear(route: Route)
	if route.wire then
		route.wire:Destroy()
		route.wire = nil
	end
	if route.emitter then
		route.emitter:Destroy()
		route.emitter = nil
	end
	route.mode = "None"
	route.input = nil
end

local function ensureListener()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	if listener and listener.Parent == camera then
		return
	end
	if listener then
		listener:Destroy()
	end
	local l = Instance.new("AudioListener")
	l.Name = "TeamVoiceListener"
	l.Parent = camera
	wire(l, fader, l)
	listener = l
end

local function applyVolume()
	local profile = PlayerDataClient.get()
	local audio = profile and profile.settings.audio
	fader.Volume = if audio then audio.master * audio.voice else 1
end

local function route(speaker: Player, me: SocialRules.Presence)
	local r = routes[speaker]
	if r == nil then
		r = { mode = "None" }
		routes[speaker] = r
	end
	local found = speaker:FindFirstChild(SocialConfig.Voice.InputName)
	local input = if found and found:IsA("AudioDeviceInput") then found else nil
	local mode: SocialRules.VoiceMode = if input then SocialRules.voiceMode(me, presenceOf(speaker)) else "None"
	local character = speaker.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if mode == "Spatial" and root == nil then
		mode = "None"
	end
	-- Nada mudou?
	if r.mode == mode and r.input == input then
		if mode ~= "Spatial" or (r.emitter and r.emitter.Parent == root) then
			return
		end
	end
	clear(r)
	if input == nil or mode == "None" then
		return
	end
	r.mode = mode
	r.input = input
	if mode == "Direct" then
		r.wire = wire(input, fader, folder)
	else
		local emitter = Instance.new("AudioEmitter")
		emitter.Name = "TeamVoiceEmitter"
		emitter:SetDistanceAttenuation({
			[0] = 1,
			[SocialConfig.Voice.NearDistance] = 1,
			[SocialConfig.Voice.FarDistance] = 0,
		})
		emitter.Parent = root
		r.emitter = emitter
		r.wire = wire(input, emitter, emitter)
	end
end

local function refresh()
	queued = false
	ensureListener()
	local me = presenceOf(player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			route(other, me)
		end
	end
end

local function queue()
	if not queued then
		queued = true
		task.defer(refresh)
	end
end

local function watch(p: Player)
	p:GetAttributeChangedSignal(CombatNames.Attr.TeamId):Connect(queue)
	p:GetAttributeChangedSignal(MatchTypes.Attr.Location):Connect(queue)
	p.CharacterAdded:Connect(queue)
	p.ChildAdded:Connect(function(child: Instance)
		if child:IsA("AudioDeviceInput") then
			queue()
		end
	end)
	queue()
end

function VoiceRouter.Start()
	folder = Instance.new("Folder")
	folder.Name = "TeamVoice"
	folder.Parent = SoundService
	fader = Instance.new("AudioFader")
	fader.Name = "VoiceVolume"
	fader.Parent = folder
	local output = Instance.new("AudioDeviceOutput")
	output.Name = "VoiceOut"
	output.Parent = folder
	wire(fader, output, folder)
	applyVolume()
	PlayerDataClient.onChanged(applyVolume)

	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(p: Player)
		local r = routes[p]
		if r then
			clear(r)
			routes[p] = nil
		end
	end)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(queue)
	task.spawn(function()
		while true do
			task.wait(SocialConfig.Voice.RefreshSeconds)
			refresh()
		end
	end)
end

return VoiceRouter
