--!strict
-- Atividade dos jogadores na partida:
--   * para onde cada um olha (remote LookSync -> atributo no personagem), para o parceiro espectar
--     em primeira pessoa depois de cair (GDD 4.3);
--   * há quanto tempo o jogador não faz nada (andar, olhar, atirar), para o aviso de ausência (GDD 4.9).
-- O MatchService decide quando contar (só no combate) e o que fazer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local MatchConfig = require(Shared.Config.MatchConfig)
local MatchTypes = require(Shared.Match.MatchTypes)
local Remotes = require(Shared.Remotes)
local ShotValidation = require(Shared.Combat.ShotValidation)

local CombatService = require(script.Parent.CombatService)

local AFK = MatchConfig.Afk
local MAX_LOOK_PER_SECOND = MatchConfig.LookSyncPerSecond * 2

type Tracker = {
	lastActive: number,
	lastPosition: Vector3?,
	lastLook: Vector3?,
	windowStart: number,
	windowCount: number,
}

local ActivityService = {}

local trackers: { [Player]: Tracker } = {}

local function tracker(player: Player): Tracker
	local t = trackers[player]
	if t == nil then
		t = { lastActive = os.clock(), lastPosition = nil, lastLook = nil, windowStart = 0, windowCount = 0 }
		trackers[player] = t
	end
	return t
end

function ActivityService.markActive(player: Player)
	tracker(player).lastActive = os.clock()
end

-- Zera a contagem (começo do combate, voltou a se mexer).
function ActivityService.reset(player: Player)
	local t = tracker(player)
	t.lastActive = os.clock()
	t.lastPosition = nil
end

-- Segundos sem atividade. Também confere se o personagem andou desde a última chamada.
function ActivityService.inactiveSeconds(player: Player): number
	local t = tracker(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local position = root.Position
		if t.lastPosition and (position - t.lastPosition).Magnitude >= AFK.MoveThreshold then
			t.lastActive = os.clock()
		end
		t.lastPosition = position
	end
	return os.clock() - t.lastActive
end

local function onLook(player: Player, raw: unknown)
	if not ShotValidation.isFiniteVector(raw) then
		return
	end
	local look = raw :: Vector3
	if look.Magnitude < 0.5 or look.Magnitude > 1.5 then
		return
	end
	local t = tracker(player)
	local now = os.clock()
	if now - t.windowStart >= 1 then
		t.windowStart = now
		t.windowCount = 0
	end
	t.windowCount += 1
	if t.windowCount > MAX_LOOK_PER_SECOND then
		return
	end
	look = look.Unit
	if t.lastLook == nil or (look - t.lastLook).Magnitude >= AFK.LookThreshold then
		t.lastActive = now
	end
	t.lastLook = look
	local character = player.Character
	if character then
		character:SetAttribute(MatchTypes.Attr.Look, look)
	end
end

local lookEvent: UnreliableRemoteEvent

function ActivityService.Init()
	lookEvent = Remotes.unreliable("LookSync")
end

function ActivityService.Start()
	lookEvent.OnServerEvent:Connect(onLook)
	CombatService.onActivity(ActivityService.markActive)
	Players.PlayerRemoving:Connect(function(player: Player)
		trackers[player] = nil
	end)
end

return ActivityService
