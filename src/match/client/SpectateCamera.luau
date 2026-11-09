--!strict
-- Espectar o parceiro em primeira pessoa depois de cair (GDD 4.3): a câmera vai para a cabeça do
-- parceiro e olha para onde ele olha (o servidor repassa a direção no atributo LookDir).
-- O corpo do parceiro some só para quem assiste, para a câmera não ficar dentro da cabeça.
-- Também manda para o servidor para onde ESTE jogador olha (LookSync), enquanto está numa ilha.
-- Continua sempre em primeira pessoa (GDD 3.1): nunca há câmera atrás do personagem.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CombatNames = require(Shared.Combat.CombatNames)
local MatchConfig = require(Shared.Config.MatchConfig)
local MatchTypes = require(Shared.Match.MatchTypes)
local Remotes = require(Shared.Remotes)

local MatchClient = require(script.Parent.MatchClient)

local ATTR = CombatNames.Attr
local SEND_INTERVAL = 1 / MatchConfig.LookSyncPerSecond
local SMOOTHING = 18

local SpectateCamera = {}

local player = Players.LocalPlayer
local target: Model? = nil
local hiddenParts: { BasePart } = {}
local lookEvent: UnreliableRemoteEvent? = nil
local lastSentAt = 0
local lastSentLook: Vector3? = nil
local currentLook: Vector3? = nil

function SpectateCamera.getTargetName(): string?
	if target == nil then
		return nil
	end
	local name = target:GetAttribute(ATTR.DisplayName)
	return if typeof(name) == "string" then name else target.Name
end

local function setHidden(model: Model?, hidden: boolean)
	if hidden and model then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
				table.insert(hiddenParts, d)
			end
		end
	else
		for _, part in hiddenParts do
			part.LocalTransparencyModifier = 0
		end
		table.clear(hiddenParts)
	end
end

-- Parceiro vivo na mesma ilha (jogador ou jogador de teste).
local function findPartner(): Model?
	local teamId = MatchClient.myTeamId()
	local island = MatchClient.myIsland()
	if teamId == nil or island == nil then
		return nil
	end
	for _, instance in CollectionService:GetTagged(CombatNames.CombatantTag) do
		if
			instance:IsA("Model")
			and instance ~= player.Character
			and instance:GetAttribute(ATTR.TeamId) == teamId
			and instance:GetAttribute(ATTR.Alive) == true
			and instance:GetAttribute(MatchTypes.Attr.Island) == island
			and instance.Parent ~= nil
		then
			return instance
		end
	end
	return nil
end

local function wantsSpectate(): boolean
	if MatchClient.myIsland() == nil then
		return false
	end
	local character = player.Character
	return character == nil or character:GetAttribute(ATTR.Alive) == false
end

local function stop()
	if target == nil then
		return
	end
	setHidden(nil, false)
	target = nil
	currentLook = nil
	local camera = workspace.CurrentCamera
	if camera and player.Character then
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end

	-- Enviar o meu olhar (só vivo numa ilha)
	local character = player.Character
	if lookEvent and character and character:GetAttribute(ATTR.Alive) == true then
		local now = os.clock()
		local look = camera.CFrame.LookVector
		if now - lastSentAt >= SEND_INTERVAL and (lastSentLook == nil or (look - lastSentLook).Magnitude > 0.005) then
			lastSentAt = now
			lastSentLook = look
			lookEvent:FireServer(look)
		end
	end

	if not wantsSpectate() then
		stop()
		return
	end
	if target == nil or target.Parent == nil or target:GetAttribute(ATTR.Alive) ~= true then
		setHidden(nil, false)
		target = findPartner()
		currentLook = nil
		if target then
			setHidden(target, true)
		end
	end
	local model = target
	if model == nil then
		return -- parceiro também caiu: a câmera fica parada até voltar ao mirante
	end
	local head = model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local wanted = model:GetAttribute(MatchTypes.Attr.Look)
	local look = if typeof(wanted) == "Vector3" then wanted else head.CFrame.LookVector
	currentLook = if currentLook then currentLook:Lerp(look, math.clamp(dt * SMOOTHING, 0, 1)) else look
	local eye = head.Position + Vector3.new(0, 0.2, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(eye, eye + (currentLook :: Vector3))
end

function SpectateCamera.Start()
	if not MatchClient.isEnabled() then
		return
	end
	lookEvent = Remotes.unreliable("LookSync")
	RunService:BindToRenderStep("SpectateCamera", Enum.RenderPriority.Camera.Value + 5, step)
	player.CharacterAdded:Connect(function()
		stop()
	end)
	-- Chegou na base ou no mirante: a câmera olha para a frente do personagem (a câmera do Roblox
	-- manteria a direção de antes do teleporte).
	player:GetAttributeChangedSignal(MatchTypes.Attr.Location):Connect(function()
		task.wait(0.3)
		local camera = workspace.CurrentCamera
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if camera and root and root:IsA("BasePart") and camera.CameraType == Enum.CameraType.Custom then
			local position = camera.CFrame.Position
			camera.CFrame = CFrame.lookAt(position, position + root.CFrame.LookVector)
		end
	end)
end

return SpectateCamera
