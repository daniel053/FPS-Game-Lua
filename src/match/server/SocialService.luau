--!strict
-- Comunicação sem voz e sem texto (GDD 12.3 e 12.4, F8): pings, frases prontas, emotes e elogio.
-- O cliente só pede (SocialRequest); o servidor confere tudo e manda só para quem deve ver:
--   * ping: de quem está numa ilha de duelo, ao alcance, para ele e o parceiro;
--   * frase: para ele e o parceiro, em qualquer momento da partida;
--   * emote: no mirante e no fim da rodada; o servidor toca a animação (todos veem);
--   * elogio: 1 no fim de cada rodada e 1 no fim da partida; soma social.praisesReceived do parceiro.
-- Também guarda os parceiros recentes (social.recentPartners) quando a dupla se forma.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local MatchTypes = require(Shared.Match.MatchTypes)
local Remotes = require(Shared.Remotes)
local SocialConfig = require(Shared.Config.SocialConfig)
local SocialRules = require(Shared.Social.SocialRules)
local SocialTypes = require(Shared.Social.SocialTypes)
local Zones = require(Shared.Maps.Zones)

local DataService = require(ServerScriptService.Common.DataService)
local ProfileRules = require(ServerScriptService.Common.Data.ProfileRules)
local TeamService = require(script.Parent.Parent.Combat.TeamService)
local MatchService = require(script.Parent.MatchService)

type Emoting = { track: AnimationTrack, startedAt: number, looped: boolean, location: string? }
type State = {
	window: SocialRules.Window,
	lastPing: number?,
	lastPhrase: number?,
	lastEmote: number?,
	praised: { [string]: boolean },
	emote: Emoting?,
}

local SocialService = {}

local eventRemote: RemoteEvent
local states: { [Player]: State } = {}
local animations: { [string]: Animation } = {}

local function stateOf(player: Player): State
	local s = states[player]
	if s == nil then
		s = { window = { start = 0, count = 0 }, praised = {} }
		states[player] = s
	end
	return s
end

local function location(player: Player): string?
	local value = player:GetAttribute(MatchTypes.Attr.Location)
	return if typeof(value) == "string" then value else nil
end

local function partnerOf(player: Player): Player?
	local team = TeamService.get(player)
	if team == nil then
		return nil
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and TeamService.get(other) == team then
			return other
		end
	end
	return nil
end

local function send(targets: { Player? }, kind: SocialTypes.EventName, data: any)
	local sent: { [Player]: boolean } = {}
	for _, target in targets do
		if target and not sent[target] and target.Parent == Players then
			sent[target] = true
			eventRemote:FireClient(target, kind, data)
		end
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Pings ------------------------------------------------------------------------------------------

local function onPing(player: Player, s: State, arg: unknown, now: number)
	if typeof(arg) ~= "table" then
		return
	end
	local req = arg :: { [string]: unknown }
	local kind, position = req.kind, req.position
	local where = location(player)
	local root = rootOf(player)
	if not SocialRules.isPingKind(kind) or not SocialRules.canPing(where) or root == nil then
		return
	end
	if not SocialRules.pingInReach(root.Position, position) then
		return
	end
	if not SocialRules.intervalOk(s.lastPing, now, SocialConfig.Ping.MinInterval) then
		return
	end
	s.lastPing = now
	local island = tonumber(string.match(where :: string, "%d+")) or 0
	local data: SocialTypes.PingData = {
		fromUserId = player.UserId,
		name = player.DisplayName,
		kind = kind :: string,
		position = position :: Vector3,
		island = island,
		zone = Zones.name(Zones.at(position :: Vector3)),
		expiresAt = workspace:GetServerTimeNow() + SocialConfig.Ping.Seconds,
	}
	send({ player, partnerOf(player) }, "Ping", data)
end

-- Frases -----------------------------------------------------------------------------------------

local function onPhrase(player: Player, s: State, arg: unknown, now: number)
	if not SocialRules.isPhrase(arg) or TeamService.get(player) == nil then
		return
	end
	if not SocialRules.intervalOk(s.lastPhrase, now, SocialConfig.Phrases.MinInterval) then
		return
	end
	s.lastPhrase = now
	local data: SocialTypes.PhraseData = { fromUserId = player.UserId, name = player.DisplayName, id = arg :: string }
	send({ player, partnerOf(player) }, "Phrase", data)
end

-- Emotes -----------------------------------------------------------------------------------------

local function stopEmote(s: State)
	local emote = s.emote
	if emote then
		s.emote = nil
		emote.track:Stop(0.2)
		emote.track:Destroy()
	end
end

local function animationOf(def: SocialConfig.EmoteDef): Animation
	local existing = animations[def.id]
	if existing then
		return existing
	end
	local created = Instance.new("Animation")
	created.Name = def.id
	created.AnimationId = def.animationId
	animations[def.id] = created
	return created
end

local function onEmote(player: Player, s: State, arg: unknown, now: number)
	local def = SocialRules.emoteDef(arg)
	local where = location(player)
	if def == nil or not SocialRules.canEmote(where, MatchService.getPhase()) then
		return
	end
	if not SocialRules.intervalOk(s.lastEmote, now, SocialConfig.Emotes.MinInterval) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if humanoid == nil or animator == nil or humanoid.Health <= 0 then
		return
	end
	s.lastEmote = now
	stopEmote(s)
	local ok, track = pcall(function()
		return animator:LoadAnimation(animationOf(def))
	end)
	if not ok then
		warn(`[Social] Emote {def.id} não carregou: {track}`)
		return
	end
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = def.looped
	track:Play(0.2)
	s.emote = { track = track, startedAt = now, looped = def.looped, location = where }
	send({ player }, "Emote", { id = def.id })
end

-- Para o emote quando o jogador anda, troca de lugar (vai para a ilha) ou passa do tempo.
local function tickEmotes()
	local now = os.clock()
	for player, s in states do
		local emote = s.emote
		if emote == nil then
			continue
		end
		local root = rootOf(player)
		local speed = if root
			then Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
			else 0
		local ended = not emote.looped and not emote.track.IsPlaying
		if
			root == nil
			or ended
			or speed > SocialConfig.Emotes.CancelSpeed
			or location(player) ~= emote.location
			or now - emote.startedAt > SocialConfig.Emotes.MaxSeconds
		then
			stopEmote(s)
		end
	end
end

-- Elogio -----------------------------------------------------------------------------------------

local function onPraise(player: Player, s: State)
	local key = SocialRules.praiseKey(MatchService.getPhase(), MatchService.getRound())
	local partner = partnerOf(player)
	if key == nil or partner == nil or partner.UserId == player.UserId or s.praised[key] then
		return
	end
	s.praised[key] = true
	DataService.update(partner, function(profile)
		return ProfileRules.addPraise(profile)
	end)
	send({ partner }, "Praised", { name = player.DisplayName })
	send({ player }, "PraiseSent", { name = partner.DisplayName })
end

-- Parceiros recentes -----------------------------------------------------------------------------

local function onTeamChanged(player: Player, teamId: string?)
	local s = states[player]
	if s then
		s.praised = {} -- dupla nova (partida nova): elogios de novo
	end
	if teamId == nil or not MatchService.isEnabled() then
		return
	end
	local partner = partnerOf(player)
	if partner == nil or player.UserId <= 0 or partner.UserId <= 0 then
		return
	end
	local now = os.time()
	DataService.update(player, function(profile)
		return ProfileRules.addRecentPartner(profile, partner.UserId, now)
	end)
	DataService.update(partner, function(profile)
		return ProfileRules.addRecentPartner(profile, player.UserId, now)
	end)
end

-- Pedidos ----------------------------------------------------------------------------------------

local function onRequest(player: Player, kind: unknown, arg: unknown)
	if not MatchService.isEnabled() then
		return
	end
	local s = stateOf(player)
	local now = os.clock()
	if not SocialRules.windowAllows(s.window, now) then
		return
	end
	if kind == "Ping" then
		onPing(player, s, arg, now)
	elseif kind == "Phrase" then
		onPhrase(player, s, arg, now)
	elseif kind == "Emote" then
		onEmote(player, s, arg, now)
	elseif kind == "Praise" then
		onPraise(player, s)
	end
end

function SocialService.Init()
	eventRemote = Remotes.event("SocialEvent")
	Remotes.event("SocialRequest").OnServerEvent:Connect(onRequest)
end

function SocialService.Start()
	TeamService.onChanged(onTeamChanged)
	Players.PlayerRemoving:Connect(function(player: Player)
		local s = states[player]
		if s then
			stopEmote(s)
		end
		states[player] = nil
	end)
	RunService.Heartbeat:Connect(tickEmotes)
end

return SocialService
