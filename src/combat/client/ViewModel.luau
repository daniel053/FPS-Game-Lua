--!strict
-- Arma e mãos em primeira pessoa (GDD 3.1 e docs/referencias/visuais/guia-arma-primeira-pessoa.png).
-- Modelo de BLOCOS provisório (arte final na F10), só no cliente, preso à câmera:
--   * sempre no canto inferior direito; o centro da tela fica livre;
--   * luvas escuras e manga neutra (sem cor de equipe: aliado e inimigo pela marcação, GDD 7.6);
--   * pistola com uma mão; as outras armas com duas;
--   * balanço ao andar, recuo ao atirar, abaixa perto de parede, some com a mira de sniper aberta;
--   * no celular, 10% menor e mais baixa;
--   * cada arma se encaixa no quadro do guia (cano fora do centro, nada no centro livre nem fora da
--     zona da arma): a que não cabe fica menor (ViewModelFit, F10). O Bastão fica de fora (é erguido).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local Types = require(Shared.Types)
local ViewModelFit = require(Shared.Combat.ViewModelFit)
local WeaponShapes = require(Shared.Combat.WeaponShapes)

local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)

local VM = CombatConfig.ViewModel

type Shape = WeaponShapes.Shape

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

-- Construção -------------------------------------------------------------------------------------

-- Posição da arma em relação à câmera (por categoria; no celular, menor e mais baixa).
local function offsetFor(kind: string, touch: boolean): Vector3
	local offset = VM.Offsets[kind] or VM.Offsets.Rifle
	if touch then
		offset = offset * VM.TouchScale + Vector3.new(0, VM.TouchExtraDown, 0)
	end
	return offset
end

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
		WeaponShapes.makePart(spec).Parent = newModel
	end
	local touch = InputDevice.get() == "Touch"
	local scale = if touch then VM.TouchScale else 1
	if kind ~= "Melee" then
		scale *= ViewModelFit.scale(shape.parts, shape.muzzle, offsetFor(kind, touch), scale)
	end
	if scale ~= 1 then
		newModel:ScaleTo(scale)
	end
	model = newModel
	currentKind = kind
	currentShape = shape
end

-- API --------------------------------------------------------------------------------------------

-- Troca a arma mostrada. `category` = categoria da arma de fogo, ou "Melee" (posição na tela);
-- `weaponId` = a arma (cores e peças próprias, WeaponShapes).
-- Skin equipada no perfil (F9): só muda as cores do modelo.
local function equippedSkin(weaponId: string?): string?
	local profile = PlayerDataClient.get()
	if profile == nil then
		return nil
	end
	local equipped = profile.cosmetics.equipped
	if weaponId == nil then
		return equipped.melee
	end
	return equipped.weapons[weaponId]
end

function ViewModel.setWeapon(category: string, weaponId: string?)
	local shape = if category == "Melee"
		then WeaponShapes.melee(true, equippedSkin(nil))
		else WeaponShapes.gun(category :: Types.WeaponCategory, true, weaponId, equippedSkin(weaponId))
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

	local offset = offsetFor(currentKind or "Rifle", InputDevice.get() == "Touch")

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
