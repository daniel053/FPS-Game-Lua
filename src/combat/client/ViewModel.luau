--!strict
-- Arma e mãos em primeira pessoa (GDD 3.1 e docs/referencias/visuais/guia-arma-primeira-pessoa.png).
-- Modelo de BLOCOS provisório (arte final na F10), só no cliente, preso à câmera:
--   * sempre no canto inferior direito; o centro da tela fica livre;
--   * luvas escuras e manga neutra (sem cor de equipe: aliado e inimigo pela marcação, GDD 7.6);
--   * pistola com uma mão; as outras armas com duas;
--   * balanço ao andar, recuo ao atirar, abaixa perto de parede, some com a mira de sniper aberta;
--   * no celular, 10% menor e mais baixa.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local Theme = require(Shared.Config.Theme)
local Types = require(Shared.Types)

local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)

local VM = CombatConfig.ViewModel
local COLORS = Theme.Combat

type PartSpec = { size: Vector3, cframe: CFrame, color: Color3 }

type Shape = {
	parts: { PartSpec },
	muzzle: Vector3,
	leftHand: Vector3?, -- nil = uma mão só
}

local ViewModel = {}

local player = Players.LocalPlayer

local model: Model? = nil
local currentKind: string? = nil
local currentShape: Shape? = nil
local visible = true
local kick = 0
local swingStartedAt = -math.huge
local swingHeavy = false
local reloadUntil = 0
local reloadDuration = 1
local equipStartedAt = -math.huge
local lowerAlpha = 0

local wallParams = RaycastParams.new()
wallParams.CollisionGroup = CombatNames.Groups.SightRay
wallParams.FilterType = Enum.RaycastFilterType.Exclude

-- Formas -----------------------------------------------------------------------------------------

local function box(size: Vector3, position: Vector3, color: Color3, rotation: CFrame?): PartSpec
	return { size = size, cframe = CFrame.new(position) * (rotation or CFrame.identity), color = color }
end

-- Segmento (braço) entre dois pontos.
local function segment(from: Vector3, to: Vector3, thickness: number, color: Color3): PartSpec
	local length = (to - from).Magnitude
	return {
		size = Vector3.new(thickness, thickness, length),
		cframe = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2),
		color = color,
	}
end

local function arm(hand: Vector3, elbow: Vector3, parts: { PartSpec })
	table.insert(parts, box(Vector3.new(0.3, 0.3, 0.34), hand, COLORS.Glove))
	local wrist = hand + (elbow - hand).Unit * 0.2
	table.insert(parts, segment(wrist, elbow, 0.34, COLORS.Sleeve))
end

local function gunShape(category: Types.WeaponCategory): Shape
	local body, dark, light = COLORS.WeaponBody, COLORS.WeaponDark, COLORS.WeaponLight
	local grip = Vector3.new(0, -0.18, 0.02)
	local tilt = CFrame.Angles(math.rad(-15), 0, 0)
	local parts: { PartSpec } = {}
	local muzzle: Vector3
	local leftHand: Vector3? = nil

	if category == "Pistol" then
		table.insert(parts, box(Vector3.new(0.22, 0.3, 0.75), Vector3.new(0, 0.12, -0.2), body))
		table.insert(parts, box(Vector3.new(0.12, 0.12, 0.25), Vector3.new(0, 0.17, -0.68), dark))
		table.insert(parts, box(Vector3.new(0.2, 0.45, 0.22), grip, dark, tilt))
		muzzle = Vector3.new(0, 0.17, -0.82)
	elseif category == "SMG" then
		table.insert(parts, box(Vector3.new(0.3, 0.4, 1.2), Vector3.new(0, 0.12, -0.35), body))
		table.insert(parts, box(Vector3.new(0.12, 0.12, 0.5), Vector3.new(0, 0.18, -1.2), dark))
		table.insert(parts, box(Vector3.new(0.2, 0.6, 0.22), Vector3.new(0, -0.3, -0.5), dark))
		table.insert(parts, box(Vector3.new(0.2, 0.4, 0.22), grip, dark, tilt))
		table.insert(parts, box(Vector3.new(0.18, 0.25, 0.5), Vector3.new(0, 0.1, 0.5), light))
		muzzle = Vector3.new(0, 0.18, -1.45)
		leftHand = Vector3.new(0, -0.05, -0.8)
	elseif category == "Shotgun" then
		table.insert(parts, box(Vector3.new(0.32, 0.4, 1.4), Vector3.new(0, 0.12, -0.4), body))
		table.insert(parts, box(Vector3.new(0.2, 0.2, 1.1), Vector3.new(0, 0.24, -1.55), dark))
		table.insert(parts, box(Vector3.new(0.27, 0.22, 0.6), Vector3.new(0, 0.02, -1.3), light))
		table.insert(parts, box(Vector3.new(0.26, 0.32, 0.45), Vector3.new(0, 0.05, 0.42), light))
		table.insert(parts, box(Vector3.new(0.2, 0.4, 0.22), grip, dark, tilt))
		muzzle = Vector3.new(0, 0.24, -2.1)
		leftHand = Vector3.new(0, -0.1, -1.3)
	elseif category == "MachineGun" then
		table.insert(parts, box(Vector3.new(0.42, 0.55, 1.8), Vector3.new(0, 0.15, -0.5), body))
		table.insert(parts, box(Vector3.new(0.18, 0.18, 1.0), Vector3.new(0, 0.2, -1.9), dark))
		table.insert(parts, box(Vector3.new(0.45, 0.5, 0.5), Vector3.new(0, -0.35, -0.6), dark))
		table.insert(parts, box(Vector3.new(0.22, 0.42, 0.24), grip, dark, tilt))
		table.insert(parts, box(Vector3.new(0.28, 0.36, 0.45), Vector3.new(0, 0.08, 0.45), light))
		muzzle = Vector3.new(0, 0.2, -2.4)
		leftHand = Vector3.new(0, -0.12, -1.25)
	elseif category == "Sniper" then
		table.insert(parts, box(Vector3.new(0.3, 0.4, 1.8), Vector3.new(0, 0.12, -0.5), body))
		table.insert(parts, box(Vector3.new(0.11, 0.11, 1.3), Vector3.new(0, 0.18, -2.0), dark))
		table.insert(parts, box(Vector3.new(0.2, 0.2, 0.9), Vector3.new(0, 0.48, -0.45), dark))
		table.insert(parts, box(Vector3.new(0.22, 0.35, 0.3), Vector3.new(0, -0.22, -0.55), dark))
		table.insert(parts, box(Vector3.new(0.26, 0.4, 0.5), Vector3.new(0, 0.05, 0.5), light))
		table.insert(parts, box(Vector3.new(0.2, 0.4, 0.22), grip, dark, tilt))
		muzzle = Vector3.new(0, 0.18, -2.65)
		leftHand = Vector3.new(0, -0.05, -1.2)
	else -- Fuzis e fuzis leves (referência do guia)
		table.insert(parts, box(Vector3.new(0.32, 0.45, 1.6), Vector3.new(0, 0.15, -0.45), body))
		table.insert(parts, box(Vector3.new(0.13, 0.13, 0.9), Vector3.new(0, 0.22, -1.7), dark))
		table.insert(parts, box(Vector3.new(0.24, 0.6, 0.3), Vector3.new(0, -0.3, -0.6), dark))
		table.insert(parts, box(Vector3.new(0.2, 0.42, 0.22), grip, dark, tilt))
		table.insert(parts, box(Vector3.new(0.26, 0.36, 0.45), Vector3.new(0, 0.1, 0.45), light))
		table.insert(parts, box(Vector3.new(0.12, 0.14, 0.35), Vector3.new(0, 0.45, -0.35), dark))
		muzzle = Vector3.new(0, 0.22, -2.15)
		leftHand = Vector3.new(0, -0.05, -1.05)
	end

	arm(grip + Vector3.new(0, -0.05, 0.05), Vector3.new(0.3, -1.3, 0.8), parts)
	if leftHand then
		arm(leftHand, Vector3.new(-0.7, -1.3, 0.1), parts)
	end
	return { parts = parts, muzzle = muzzle, leftHand = leftHand }
end

local function meleeShape(): Shape
	local tilt = CFrame.Angles(math.rad(62), math.rad(-8), math.rad(-12))
	local parts: { PartSpec } = {
		{ size = Vector3.new(0.16, 0.16, 0.6), cframe = tilt, color = COLORS.MeleeHandle },
		{
			size = Vector3.new(0.2, 0.2, 1.2),
			cframe = tilt * CFrame.new(0, 0, -0.85),
			color = COLORS.WeaponLight,
		},
	}
	arm(Vector3.new(0, -0.05, 0.1), Vector3.new(0.3, -1.3, 0.8), parts)
	return { parts = parts, muzzle = (tilt * CFrame.new(0, 0, -1.45)).Position, leftHand = nil }
end

-- Construção -------------------------------------------------------------------------------------

local function destroyModel()
	if model then
		model:Destroy()
		model = nil
	end
end

local function build(kind: string, shape: Shape)
	destroyModel()
	local newModel = Instance.new("Model")
	newModel.Name = "ViewModel"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Transparency = 1
	root.Size = Vector3.one * 0.1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.identity
	root.Parent = newModel
	newModel.PrimaryPart = root

	for _, spec in shape.parts do
		local part = Instance.new("Part")
		part.Name = "Piece"
		part.Size = spec.size
		part.CFrame = spec.cframe
		part.Color = spec.color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Parent = newModel
	end
	if InputDevice.get() == "Touch" then
		newModel:ScaleTo(VM.TouchScale)
	end
	model = newModel
	currentKind = kind
	currentShape = shape
end

-- API --------------------------------------------------------------------------------------------

-- Troca a arma mostrada. `category` = categoria da arma de fogo, ou "Melee".
function ViewModel.setWeapon(category: string)
	local shape = if category == "Melee" then meleeShape() else gunShape(category :: Types.WeaponCategory)
	build(category, shape)
	equipStartedAt = os.clock()
	reloadUntil = 0
end

function ViewModel.clear()
	destroyModel()
	currentKind = nil
	currentShape = nil
end

function ViewModel.setVisible(on: boolean)
	visible = on
end

function ViewModel.kick(amount: number?)
	kick = math.min(kick + VM.KickBack * (amount or 1), VM.KickBack * 3)
end

function ViewModel.swing(heavy: boolean)
	swingStartedAt = os.clock()
	swingHeavy = heavy
end

function ViewModel.setReloading(seconds: number)
	reloadDuration = math.max(seconds, 0.1)
	reloadUntil = os.clock() + seconds
end

-- Ponta do cano no mundo (origem do rastro e do clarão).
function ViewModel.getMuzzlePosition(): Vector3?
	local m, shape = model, currentShape
	if m == nil or shape == nil or m.Parent == nil then
		return nil
	end
	local scale = m:GetScale()
	return (m:GetPivot() * CFrame.new(shape.muzzle * scale)).Position
end

local function update(dt: number)
	local m = model
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if m == nil or camera == nil or humanoid == nil or not visible then
		if m and m.Parent then
			m.Parent = nil
		end
		return
	end
	if m.Parent ~= camera then
		m.Parent = camera
	end

	local now = os.clock()
	local reduce = 1
	local profile = PlayerDataClient.get()
	if profile and profile.settings.reduceEffects then
		reduce = CombatConfig.Effects.ReducedEffectsScale
	end

	local offset = VM.Offsets[currentKind or "Rifle"] or VM.Offsets.Rifle
	if InputDevice.get() == "Touch" then
		offset = offset * VM.TouchScale + Vector3.new(0, VM.TouchExtraDown, 0)
	end

	-- Balanço ao andar
	local speed = humanoid.MoveDirection.Magnitude
	local bobPhase = now * VM.BobSpeed
	local bobAmount = VM.BobAmount * speed * reduce
	local bob = CFrame.new(math.cos(bobPhase / 2) * bobAmount, math.abs(math.sin(bobPhase)) * bobAmount, 0)

	-- Recuo visual
	kick = math.max(0, kick - VM.KickRecovery * kick * dt - 0.01 * dt)
	local kickCf = CFrame.new(0, 0, kick * reduce) * CFrame.Angles(math.rad(kick * 25 * reduce), 0, 0)

	-- Perto de parede: abaixa e gira para baixo
	local filter: { Instance } = { m }
	if character then
		table.insert(filter, character)
	end
	wallParams.FilterDescendantsInstances = filter
	local blocked =
		workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * VM.WallCheckDistance, wallParams)
	local targetLower = if blocked then 1 else 0
	lowerAlpha += (targetLower - lowerAlpha) * math.min(1, dt * 10)
	local lower = CFrame.new(0, -0.3 * lowerAlpha, 0) * CFrame.Angles(-math.rad(VM.WallLowerAngle * lowerAlpha), 0, 0)

	-- Recarga: arma desce e gira um pouco
	local reloadAlpha = 0
	if now < reloadUntil then
		local progress = 1 - (reloadUntil - now) / reloadDuration
		reloadAlpha = math.sin(progress * math.pi)
	end
	local reload = CFrame.Angles(-math.rad(VM.ReloadDipAngle * reloadAlpha), 0, math.rad(12 * reloadAlpha))

	-- Golpe do corpo a corpo
	local swingTime = if swingHeavy then 0.35 else 0.2
	local swingAlpha = 0
	if now - swingStartedAt < swingTime then
		swingAlpha = math.sin((now - swingStartedAt) / swingTime * math.pi)
	end
	local swingAngle = if swingHeavy then 80 else 55
	local swing = CFrame.Angles(-math.rad(swingAngle * swingAlpha), math.rad(35 * swingAlpha), 0)

	-- Sacar: sobe de baixo
	local equipAlpha = math.clamp((now - equipStartedAt) / 0.25, 0, 1)
	local equip = CFrame.new(0, -0.8 * (1 - equipAlpha), 0)

	m:PivotTo(camera.CFrame * CFrame.new(offset) * bob * equip * lower * reload * swing * kickCf)
end

function ViewModel.Start()
	RunService:BindToRenderStep("ViewModel", Enum.RenderPriority.Camera.Value + 3, update)

	-- Trocou entre celular e PC: refaz no tamanho certo.
	InputDevice.onChanged(function()
		local kind, shape = currentKind, currentShape
		if kind and shape then
			build(kind, shape)
		end
	end)
end

return ViewModel
