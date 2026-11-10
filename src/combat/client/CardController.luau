--!strict
-- Cartas no cliente (FASES F4, GDD 8). Só pede e mostra; o servidor decide (CardService).
--   * Guarda as cartas da rodada que o servidor mandou e prevê as cargas na hora (mesma CardState),
--     para o botão responder sem esperar a rede. Se o servidor recusar, ele manda o estado certo.
--   * Controles (GDD 7.2.6):
--       PC: C, Q, E, X (a tecla fixa de cada carta);
--       controle: LB = a carta básica escolhida, RB = a ult (só dá para levar 1 básica + a ult);
--       celular: botões fixos (CardHUD chama press/release).
--   * Nuvem: segurar mostra o arco; soltar arremessa (GDD 8.4). As outras saem ao apertar.
--   * Impulso: o salto é aplicado aqui (o Roblox deixa o corpo do jogador com o próprio cliente).
--   * Tremor recebido: mira tremida enquanto durar (o servidor deixa mais lento).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local CardConfig = require(Shared.Config.CardConfig)
local CardRules = require(Shared.Cards.CardRules)
local CardState = require(Shared.Cards.CardState)
local CardTypes = require(Shared.Cards.CardTypes)
local CombatNames = require(Shared.Combat.CombatNames)
local Remotes = require(Shared.Remotes)
local Theme = require(Shared.Config.Theme)

local AimCamera = require(script.Parent.Parent.Common.AimCamera)
local CombatEffects = require(script.Parent.CombatEffects)

type CardKey = string -- "C", "Q", "E" ou "X" (Types.CardKey); string por causa do verificador de tipos
type CardView = CardTypes.CardView

local NAMES = CardTypes.Names
local ARC_DOTS = 18
local ARC_STEP = 1 / 20

local KEY_BY_CODE: { [Enum.KeyCode]: CardKey } = {
	[Enum.KeyCode.C] = "C",
	[Enum.KeyCode.Q] = "Q",
	[Enum.KeyCode.E] = "E",
	[Enum.KeyCode.X] = "X",
}

local CardController = {}

local player = Players.LocalPlayer
local actionEvent: RemoteEvent

local views: { CardView } = {}
local states: { [string]: CardState.State } = {}
local active = false
local holding: { key: CardKey, since: number }? = nil
local heldGamepad: { [Enum.KeyCode]: CardKey } = {}
local renascerEndsAt: number? = nil
local lastSentT = -math.huge
local changedCallbacks: { () -> () } = {}
local eventCallbacks: { (kind: string, data: any) -> () } = {}

-- Mira tremida (Tremor)
local shakePitch, shakeYaw = 0, 0

local arcDots: { BasePart } = {}

local sightParams = RaycastParams.new()
sightParams.CollisionGroup = CombatNames.Groups.SightRay
sightParams.FilterType = Enum.RaycastFilterType.Exclude

local function now(): number
	return workspace:GetServerTimeNow()
end

local function notifyChanged()
	for _, callback in changedCallbacks do
		task.spawn(callback)
	end
end

local function aliveCharacter(): Model?
	local character = player.Character
	if character == nil or character:GetAttribute(CombatNames.Attr.Alive) ~= true then
		return nil
	end
	return character
end

local function viewFor(key: CardKey): CardView?
	for _, view in views do
		if view.key == key then
			return view
		end
	end
	return nil
end

local function lookDirection(): Vector3
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.LookVector else Vector3.new(0, 0, -1)
end

-- Arco da Nuvem ------------------------------------------------------------------------------------

local function hideArc()
	for _, dot in arcDots do
		dot.Transparency = 1
	end
end

local function ensureArc()
	if #arcDots > 0 then
		return
	end
	for i = 1, ARC_DOTS do
		local dot = Instance.new("Part")
		dot.Name = "ArcoNuvem"
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.one * 0.35
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CanTouch = false
		dot.CastShadow = false
		dot.Material = Enum.Material.Neon -- brilho permitido só em efeito de carta
		dot.Color = Theme.Cards.card_nuvem
		dot.Transparency = 1
		dot.Parent = CombatEffects.getFolder()
		arcDots[i] = dot
	end
end

local function showArc(def: CardConfig.CardDef)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		hideArc()
		return
	end
	ensureArc()
	local p = def.params
	local velocity = lookDirection() * p.ThrowSpeed + Vector3.new(0, p.ThrowLift, 0)
	local path = CardRules.throwPath(head.Position, velocity, workspace.Gravity, p.MaxFlightSeconds, ARC_STEP)
	sightParams.FilterDescendantsInstances = { character :: Model, CombatEffects.getFolder() }
	local stopped = false
	for i = 1, ARC_DOTS do
		local dot = arcDots[i]
		local nextPoint: Vector3? = path[i + 1]
		if stopped or nextPoint == nil then
			dot.Transparency = 1
			continue
		end
		local point: Vector3 = nextPoint
		local from = path[i]
		local hit = workspace:Raycast(from, point - from, sightParams)
		if hit then
			point = hit.Position
			stopped = true
		end
		dot.Position = point
		dot.Transparency = Theme.CardFxTransparency
	end
end

-- Uso ----------------------------------------------------------------------------------------------

local function launch(def: CardConfig.CardDef)
	local character = aliveCharacter()
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid) then
		return
	end
	local speed = CardRules.launchSpeed(def.params.LaunchHeight, workspace.Gravity)
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, speed, v.Z)
end

local function use(key: CardKey)
	local view = viewFor(key)
	if not active or view == nil or view.locked or aliveCharacter() == nil then
		return
	end
	local state = states[key]
	local def = CardConfig.get(view.id)
	if state == nil or def == nil then
		return
	end
	local t = math.max(now(), lastSentT)
	if not CardState.use(state, t) then
		return
	end
	lastSentT = t
	actionEvent:FireServer("Use", key, t, lookDirection())
	if def.id == "card_impulso" then
		launch(def)
	end
	notifyChanged()
end

-- Apertou a carta (tecla, botão do controle ou botão de toque).
function CardController.press(key: CardKey)
	local view = viewFor(key)
	if not active or view == nil or view.locked then
		return
	end
	if view.id == "card_nuvem" then
		holding = { key = key, since = os.clock() }
		return
	end
	use(key)
end

-- Soltou: a Nuvem é arremessada agora.
function CardController.release(key: CardKey)
	local current = holding
	if current and current.key == key then
		holding = nil
		hideArc()
		use(key)
	end
end

-- Cancela a mira da Nuvem sem arremessar (ex.: abriu um painel).
function CardController.cancelHold()
	holding = nil
	hideArc()
end

-- Estado para o HUD ------------------------------------------------------------------------------

function CardController.getViews(): { CardView }
	return views
end

function CardController.isActive(): boolean
	return active
end

function CardController.getState(key: CardKey): CardState.State?
	return states[key]
end

function CardController.basicKey(): CardKey?
	for _, view in views do
		if view.key ~= CardConfig.UltKey then
			return view.key
		end
	end
	return nil
end

function CardController.renascerEndsAt(): number?
	return renascerEndsAt
end

function CardController.onChanged(callback: () -> ())
	table.insert(changedCallbacks, callback)
end

-- Eventos do servidor para o HUD (Renascer, Tremored)
function CardController.onEvent(callback: (kind: string, data: any) -> ())
	table.insert(eventCallbacks, callback)
end

-- Teste de exploit (só DEV_): manda `count` pedidos de uma vez, sem esperar a recarga.
function CardController.devSpam(key: CardKey, count: number)
	local t = math.max(now(), lastSentT)
	for i = 1, count do
		local stamp = t + (i - 1) * 0.001
		lastSentT = stamp
		actionEvent:FireServer("Use", key, stamp, lookDirection())
	end
end

-- Uma tecla de carta que o jogador NÃO tem nesta rodada (para o teste de exploit).
function CardController.devMissingKey(): CardKey?
	for _, key in { "C", "Q", "E", "X" } :: { CardKey } do
		local view = viewFor(key)
		if view == nil or view.locked then
			return key
		end
	end
	return nil
end

-- Servidor ---------------------------------------------------------------------------------------

local function onCards(data: CardTypes.CardsData)
	views = data.cards
	active = data.active
	local fresh: { [string]: CardState.State } = {}
	for _, view in views do
		local def = CardConfig.get(view.id)
		if def and not view.locked then
			local state = CardState.new(def)
			state.charges = view.charges
			state.rechargeAt = view.rechargeAt
			-- Mantém o intervalo mínimo do uso que acabou de sair daqui
			local old = states[view.key]
			if old and old.def.id == def.id then
				state.lastUseAt = old.lastUseAt
			end
			fresh[view.key] = state
		end
	end
	states = fresh
	if not active then
		holding = nil
		hideArc()
		renascerEndsAt = nil
	end
	notifyChanged()
end

-- Quadro a quadro ----------------------------------------------------------------------------------

local function stepShake(_dt: number)
	local tremor = CardConfig.get("card_tremor")
	local character = player.Character
	local untilT = character and character:GetAttribute(NAMES.TremorUntilAttr)
	local shaking = typeof(untilT) == "number" and now() < untilT and aliveCharacter() ~= nil
	local targetPitch, targetYaw = 0, 0
	if shaking and tremor then
		local amplitude = math.rad(tremor.params.AimShakeDegrees)
		local clock = os.clock() * tremor.params.AimShakeSpeed
		targetPitch = math.noise(clock, 0.3) * amplitude
		targetYaw = math.noise(0.7, clock) * amplitude
	end
	local dPitch, dYaw = targetPitch - shakePitch, targetYaw - shakeYaw
	if math.abs(dPitch) > 1e-5 or math.abs(dYaw) > 1e-5 then
		AimCamera.addRotation(dPitch, dYaw)
		shakePitch, shakeYaw = targetPitch, targetYaw
	end
end

local function step(dt: number)
	stepShake(dt)
	local current = holding
	if current == nil then
		return
	end
	if not active or aliveCharacter() == nil then
		CardController.cancelHold()
		return
	end
	local view = viewFor(current.key)
	local def = if view then CardConfig.get(view.id) else nil
	if def and os.clock() - current.since >= def.params.HoldArcSeconds then
		showArc(def)
	end
end

-- Entrada (PC e controle) ------------------------------------------------------------------------

local function keyForInput(input: InputObject): CardKey?
	local key = KEY_BY_CODE[input.KeyCode]
	if key then
		return key
	end
	if input.KeyCode == Enum.KeyCode.ButtonL1 then
		return CardController.basicKey()
	elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
		return CardConfig.UltKey
	end
	return nil
end

function CardController.Init()
	actionEvent = Remotes.event("CardAction")
end

function CardController.Start()
	Remotes.event("CardEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Cards" then
			onCards(data :: CardTypes.CardsData)
		elseif kind == "Renascer" then
			renascerEndsAt = (data :: CardTypes.RenascerData).endsAt
			notifyChanged()
		end
		for _, callback in eventCallbacks do
			task.spawn(callback, kind, data)
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local key = keyForInput(input)
		if key then
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				heldGamepad[input.KeyCode] = key -- solta a mesma carta, mesmo que a básica mude
			end
			CardController.press(key)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local key = heldGamepad[input.KeyCode] or KEY_BY_CODE[input.KeyCode]
		heldGamepad[input.KeyCode] = nil
		if key then
			CardController.release(key)
		end
	end)

	player.CharacterRemoving:Connect(function()
		CardController.cancelHold()
		shakePitch, shakeYaw = 0, 0
	end)

	RunService:BindToRenderStep("CardController", Enum.RenderPriority.Camera.Value + 3, step)
end

return CardController
