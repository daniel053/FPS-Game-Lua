--!strict
-- Armas no cliente (GDD 7.2, 7.3 e 13). O cliente responde na hora (tiro, rastro, recuo) usando a mesma
-- máquina de estados do servidor (WeaponState), e PEDE ao servidor, que decide o dano.
--
-- Controles (GDD 7.2.6):
--   PC: botão esquerdo atira; botão direito segura a mira / modo alternativo; R recarrega;
--       1 / 2 / 3 ou roda do mouse trocam de arma.
--   Controle: gatilho direito atira; gatilho esquerdo mira; X recarrega; Y alterna 1/2 (segurar = corpo a corpo).
--   Celular: botões na tela (TouchControls). Tiro automático e assistência de mira conforme o perfil.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local AudioConfig = require(Shared.Config.AudioConfig)
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local CombatTypes = require(Shared.Combat.CombatTypes)
local Remotes = require(Shared.Remotes)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponMath = require(Shared.Combat.WeaponMath)
local WeaponState = require(Shared.Combat.WeaponState)

local AimCamera = require(script.Parent.Parent.Common.AimCamera)
local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local CombatEffects = require(script.Parent.CombatEffects)
local ViewModel = require(script.Parent.ViewModel)

type Slot = CombatTypes.Slot
type WeaponDef = WeaponConfig.WeaponDef

local INPUT = CombatConfig.Input
local AUTO = CombatConfig.AutoFire
local ASSIST = CombatConfig.AimAssist
local ATTR = CombatNames.Attr

local WeaponController = {}

local player = Players.LocalPlayer
local actionEvent: RemoteEvent

local loadout: CombatTypes.LoadoutData? = nil
local guns: { [string]: WeaponState.State } = {}
local melee = WeaponState.newMelee(WeaponConfig.Melee)
local equipped: Slot = "secondary"

local triggerHeld = false
local triggerFromTouch = false
local triggerDownAt = 0
local semiLatched = false -- semiautomática: já atirou neste toque do gatilho
local meleeSwungThisPress = false
local altHeld = false -- PC/controle: segurando a mira
local spinSent = false
local bloom = 0
local lastShotAt = -math.huge
local lastStepT = -math.huge -- horário do quadro anterior
local lastSentT = -math.huge -- horário do último pedido enviado (o servidor exige ordem)
local MAX_SHOTS_PER_FRAME = 3
local recoilPitch, recoilYaw = 0, 0 -- recuo acumulado (graus), devolvido ao parar de atirar
local shotIndex = 0
local dwellStartedAt: number? = nil -- snipers no tiro automático
local gamepadYDownAt: number? = nil
local rng = Random.new()

local changedCallbacks: { () -> () } = {}

local shotParams = RaycastParams.new()
shotParams.CollisionGroup = CombatNames.Groups.ShotRay
shotParams.FilterType = Enum.RaycastFilterType.Exclude

local sightParams = RaycastParams.new()
sightParams.CollisionGroup = CombatNames.Groups.SightRay
sightParams.FilterType = Enum.RaycastFilterType.Exclude

-- Utilidades -------------------------------------------------------------------------------------

local function now(): number
	return workspace:GetServerTimeNow()
end

local function notifyChanged()
	for _, callback in changedCallbacks do
		task.spawn(callback)
	end
end

local function send(action: CombatTypes.WeaponActionName, t: number, arg: any)
	lastSentT = math.max(lastSentT, t)
	actionEvent:FireServer(action, t, arg)
end

local function myTeam(): string?
	local teamId = player:GetAttribute(ATTR.TeamId)
	return if typeof(teamId) == "string" then teamId else nil
end

local function aliveCharacter(): Model?
	local character = player.Character
	if character == nil or character:GetAttribute(ATTR.Alive) ~= true then
		return nil
	end
	return character
end

local function settings()
	local profile = PlayerDataClient.get()
	return if profile then profile.settings else nil
end

local function currentGun(): WeaponState.State?
	if equipped == "melee" then
		return nil
	end
	return guns[equipped]
end

local function isMoving(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or not (root and root:IsA("BasePart")) then
		return false
	end
	if humanoid.FloorMaterial == Enum.Material.Air then
		return true
	end
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude > CombatConfig.MovingSpeedThreshold
end

local function updateFilters(character: Model?)
	local filter: { Instance } = { CombatEffects.getFolder() }
	local camera = workspace.CurrentCamera
	if camera then
		table.insert(filter, camera)
	end
	if character then
		table.insert(filter, character)
	end
	shotParams.FilterDescendantsInstances = filter
	sightParams.FilterDescendantsInstances = filter
end

-- Hitbox de um inimigo vivo? Devolve o modelo.
local function enemyFromHitbox(part: Instance): Model?
	if part.Name ~= CombatNames.HitboxName then
		return nil
	end
	local target = part.Parent
	if target == nil or not target:IsA("Model") or not CollectionService:HasTag(target, CombatNames.CombatantTag) then
		return nil
	end
	if target:GetAttribute(ATTR.Alive) ~= true then
		return nil
	end
	if not CombatConfig.FriendlyFire and target:GetAttribute(ATTR.TeamId) == myTeam() then
		return nil
	end
	return target
end

-- Lança um tiro. Atravessa parceiros (sem fogo amigo) e, com arma que penetra, uma cobertura fina.
-- Devolve (hitbox inimiga atingida ou nil, ponto final).
local function castShot(origin: Vector3, direction: Vector3, def: WeaponDef?): (BasePart?, Vector3)
	local baseFilter = shotParams.FilterDescendantsInstances
	local function finish(part: BasePart?, position: Vector3): (BasePart?, Vector3)
		shotParams.FilterDescendantsInstances = baseFilter -- tira os ignorados temporários
		return part, position
	end

	local start = origin
	local remaining = direction.Magnitude
	local unit = direction.Unit
	local penetrated = false
	for _ = 1, 6 do
		local result = workspace:Raycast(start, unit * remaining, shotParams)
		if result == nil then
			break
		end
		local part = result.Instance
		if part.Name == CombatNames.HitboxName then
			if enemyFromHitbox(part) then
				return finish(part, result.Position)
			end
			shotParams:AddToFilter(part) -- parceiro ou alvo derrubado: o tiro passa
		elseif def and def.penetration and not penetrated then
			-- Mede a espessura olhando de trás para a frente.
			local probe = result.Position + unit * (def.penetration.maxThickness + 0.05)
			local back = workspace:Raycast(probe, -unit * (def.penetration.maxThickness + 0.05), sightParams)
			if back and back.Instance == part then
				penetrated = true
				shotParams:AddToFilter(part)
			else
				return finish(nil, result.Position)
			end
		else
			return finish(nil, result.Position)
		end
		remaining -= (result.Position - start).Magnitude
		start = result.Position
		if remaining <= 0 then
			break
		end
	end
	return finish(nil, start + unit * math.max(remaining, 0))
end

-- O que está bem no centro da retícula (sem espalhamento)?
local function targetUnderCrosshair(range: number): (Model?, number)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil, 0
	end
	local origin = camera.CFrame.Position
	local hit, position = castShot(origin, camera.CFrame.LookVector * range, nil)
	if hit then
		return enemyFromHitbox(hit), (position - origin).Magnitude
	end
	return nil, 0
end

-- Inimigo visível mais perto da retícula, dentro de um cone (graus).
local function nearestEnemyInCone(coneDegrees: number, maxDistance: number): (BasePart?, number)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil, math.huge
	end
	local origin = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local cosLimit = math.cos(math.rad(coneDegrees))
	local best: BasePart? = nil
	local bestAngle = math.huge
	for _, target in CollectionService:GetTagged(CombatNames.CombatantTag) do
		if target == player.Character or not target:IsA("Model") then
			continue
		end
		local hitbox = target:FindFirstChild(CombatNames.HitboxName)
		if not (hitbox and hitbox:IsA("BasePart")) or enemyFromHitbox(hitbox) == nil then
			continue
		end
		local toTarget = hitbox.Position - origin
		local distance = toTarget.Magnitude
		if distance > maxDistance or distance < 0.1 then
			continue
		end
		local dot = look:Dot(toTarget.Unit)
		if dot < cosLimit then
			continue
		end
		local angle = math.acos(math.clamp(dot, -1, 1))
		if angle < bestAngle and workspace:Raycast(origin, toTarget, sightParams) == nil then
			best = hitbox
			bestAngle = angle
		end
	end
	return best, bestAngle
end

-- Ações ------------------------------------------------------------------------------------------

local function applyScope(state: WeaponState.State?)
	local scoped = state ~= nil and state.alt and WeaponConfig.hasScope(state.def)
	AimCamera.setScoped(scoped)
	AimCamera.setZoom(if scoped and state then state.def.scopeFieldOfView else nil)
	-- Sniper com a mira aberta: arma e mãos somem (guia, quadro 3).
	ViewModel.setVisible(not (scoped and state ~= nil and state.def.category == "Sniper"))
end

local function setAlt(on: boolean)
	local state = currentGun()
	if state == nil or state.def.altMode == nil or state.alt == on then
		return
	end
	if on and WeaponState.isReloading(state, now()) then
		return
	end
	WeaponState.setAlt(state, on)
	send("Alt", now(), on)
	applyScope(state)
	notifyChanged()
end

function WeaponController.reload()
	local state = currentGun()
	if state == nil or aliveCharacter() == nil then
		return
	end
	local t = now()
	if WeaponState.startReload(state, t) then
		send("Reload", t, nil)
		setAlt(false)
		ViewModel.setReloading(state.def.reloadTime)
		CombatEffects.playSound(AudioConfig.Reload)
		notifyChanged()
	end
end

function WeaponController.equip(slot: Slot)
	if slot == equipped or aliveCharacter() == nil then
		return
	end
	if slot ~= "melee" and guns[slot] == nil then
		return
	end
	setAlt(false)
	local previous = currentGun()
	if previous and spinSent then
		WeaponState.setSpin(previous, false, now())
		spinSent = false
	end
	equipped = slot
	local t = now()
	if slot == "melee" then
		WeaponState.equipMelee(melee, t)
		ViewModel.setWeapon("Melee")
	else
		local state = guns[slot]
		WeaponState.equip(state, t)
		ViewModel.setWeapon(state.def.category)
	end
	send("Equip", t, slot)
	semiLatched = triggerHeld
	bloom = 0
	applyScope(currentGun())
	CombatEffects.playSound(AudioConfig.Equip)
	notifyChanged()
end

-- Alterna primária ↔ secundária (do corpo a corpo volta para a primária, ou para a pistola).
function WeaponController.quickSwitch()
	if equipped == "primary" then
		WeaponController.equip("secondary")
	elseif equipped == "secondary" and guns.primary then
		WeaponController.equip("primary")
	elseif equipped == "melee" then
		WeaponController.equip(if guns.primary then "primary" else "secondary")
	end
end

local function cycle(direction: number)
	local order: { Slot } = {}
	if guns.primary then
		table.insert(order, "primary")
	end
	table.insert(order, "secondary")
	table.insert(order, "melee")
	local index = table.find(order, equipped) or 1
	WeaponController.equip(order[(index - 1 + direction) % #order + 1])
end

function WeaponController.setTrigger(down: boolean, fromTouch: boolean?)
	if down == triggerHeld then
		return
	end
	local t = now()
	if equipped == "melee" and not down and triggerHeld and triggerFromTouch and not meleeSwungThisPress then
		-- Celular: soltou antes do tempo do golpe forte = golpe leve.
		WeaponController.swingMelee(false)
	end
	triggerHeld = down
	triggerFromTouch = fromTouch == true
	if down then
		triggerDownAt = t
		semiLatched = false
		meleeSwungThisPress = false
		if equipped == "melee" and not triggerFromTouch then
			WeaponController.swingMelee(false)
		end
	end
end

function WeaponController.toggleAlt()
	local state = currentGun()
	if state then
		setAlt(not state.alt)
	end
end

function WeaponController.setAltHeld(on: boolean)
	altHeld = on
	if equipped == "melee" then
		if on then
			WeaponController.swingMelee(true)
		end
		return
	end
	setAlt(on)
end

-- Arrastar o dedo no botão ATIRAR também gira a câmera (pixels da tela).
function WeaponController.touchLook(delta: Vector2)
	local scale = INPUT.TouchLookRadiansPerPixel * AimCamera.getSensitivity()
	AimCamera.addRotation(-delta.Y * scale, -delta.X * scale)
end

function WeaponController.swingMelee(heavy: boolean)
	local character = aliveCharacter()
	local camera = workspace.CurrentCamera
	if character == nil or camera == nil or equipped ~= "melee" then
		return
	end
	local t = now()
	if not WeaponState.swing(melee, heavy, t, 0) then
		return
	end
	meleeSwungThisPress = true
	local origin = camera.CFrame.Position
	local reach = WeaponConfig.Melee.range + CombatConfig.Hitbox.Radius
	local result = workspace:Spherecast(origin, 0.8, camera.CFrame.LookVector * reach, shotParams)
	local part: BasePart? = nil
	if result and enemyFromHitbox(result.Instance) then
		part = result.Instance :: BasePart
	end
	local payload: CombatTypes.MeleePayload = { heavy = heavy, part = part }
	send("Melee", t, payload)
	ViewModel.swing(heavy)
	CombatEffects.playSound(if heavy then AudioConfig.MeleeHeavy else AudioConfig.MeleeSwing)
	if result then
		CombatEffects.spark(result.Position)
	end
end

local function fireOnce(state: WeaponState.State, t: number, character: Model)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local ok, reason = WeaponState.fire(state, t, 0)
	if not ok then
		if reason == "empty" then
			WeaponController.reload()
		end
		return
	end

	local def = state.def
	local origin = camera.CFrame.Position
	local spread = WeaponMath.spreadDegrees(def, state.alt, isMoving(character), bloom)
	local directions = WeaponMath.shotDirections(def, state.alt, camera.CFrame.LookVector, spread, rng)
	local ends: { Vector3 } = {}
	local hits: { CombatTypes.FireHit } = {}
	for i, direction in directions do
		local hitPart, position = castShot(origin, direction * def.range, def)
		ends[i] = position
		if hitPart then
			table.insert(hits, { part = hitPart, position = position, pellet = i })
		elseif (position - origin).Magnitude < def.range - 0.5 then
			CombatEffects.spark(position)
		end
	end
	local payload: CombatTypes.FirePayload = { origin = origin, ends = ends, hits = hits }
	send("Fire", t, payload)

	-- Resposta na hora: rastro, clarão, som, recuo
	local muzzle = ViewModel.getMuzzlePosition() or origin
	for _, position in ends do
		CombatEffects.tracer(muzzle, position, def.tracer)
	end
	CombatEffects.muzzleFlash(muzzle)
	local sound = AudioConfig.WeaponFire[def.id]
	if sound then
		CombatEffects.playSound(sound)
	end
	ViewModel.kick(if def.pellets > 1 or def.category == "Sniper" then 2 else 1)

	shotIndex += 1
	lastShotAt = t
	bloom = math.min(def.spread.bloomMax, bloom + def.spread.bloomPerShot)
	local kick = def.recoil.kick
	local sway = def.recoil.sway * (if shotIndex % 2 == 0 then 1 else -1)
	recoilPitch += kick
	recoilYaw += sway
	AimCamera.addRotation(math.rad(kick), math.rad(sway))
	semiLatched = true
	notifyChanged()
end

-- Tiro automático no celular (GDD 7.2.6): devolve (quer atirar, quer aquecer).
local function autoFireWants(state: WeaponState.State, t: number): (boolean, boolean)
	local s = settings()
	if InputDevice.get() ~= "Touch" or s == nil or not s.autoFire then
		dwellStartedAt = nil
		return false, false
	end
	local def = state.def
	local target, distance = targetUnderCrosshair(def.range)
	local behavior = def.autoFire
	if behavior == "WhileOnTarget" or behavior == "MaxRateOnTarget" then
		return target ~= nil, false
	elseif behavior == "InEffectiveRange" then
		return target ~= nil and distance <= (def.effectiveRange or def.range), false
	elseif behavior == "ScopedOnTarget" then
		if target and state.alt then
			dwellStartedAt = dwellStartedAt or t
			return t - (dwellStartedAt :: number) >= AUTO.SniperDwellSeconds, false
		end
		dwellStartedAt = nil
		return false, false
	elseif behavior == "SpinUpNearTarget" then
		local near = nearestEnemyInCone(AUTO.SpinUpConeDegrees, def.range)
		return target ~= nil, near ~= nil
	end
	return false, false
end

-- Assistência de mira (toque e controle; desligada no mouse): freia perto do inimigo e puxa de leve
-- enquanto o jogador se mexe.
local assistTarget: BasePart? = nil

local function aimAssistActive(): boolean
	local s = settings()
	local device = InputDevice.get()
	return s ~= nil and s.aimAssist and (device == "Touch" or device == "Gamepad")
end

local function updateAimAssist(dt: number, character: Model)
	if not aimAssistActive() then
		assistTarget = nil
		return
	end
	local target = nearestEnemyInCone(ASSIST.ConeDegrees, ASSIST.MaxDistance)
	assistTarget = target
	local camera = workspace.CurrentCamera
	if target == nil or camera == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0
	if not moving and AimCamera.getLastInputRotation() <= 0 then
		return
	end
	local look = camera.CFrame.LookVector
	local desired = (target.Position - camera.CFrame.Position).Unit
	local yawNow, yawWant = math.atan2(-look.X, -look.Z), math.atan2(-desired.X, -desired.Z)
	local pitchNow, pitchWant = math.asin(math.clamp(look.Y, -1, 1)), math.asin(math.clamp(desired.Y, -1, 1))
	local dYaw = (yawWant - yawNow + math.pi) % (2 * math.pi) - math.pi
	local dPitch = pitchWant - pitchNow
	local maxStep = math.rad(ASSIST.PullDegreesPerSecond) * dt
	AimCamera.addRotation(math.clamp(dPitch, -maxStep, maxStep), math.clamp(dYaw, -maxStep, maxStep))
end

-- Quadro a quadro ---------------------------------------------------------------------------------

local function recoverRecoil(def: WeaponDef?, dt: number, t: number)
	if def == nil or t - lastShotAt < 0.12 then
		return
	end
	local step = def.recoil.recovery * dt
	local pitchBack = math.min(recoilPitch, step)
	local yawBack = math.clamp(recoilYaw, -step, step)
	if pitchBack > 0 or yawBack ~= 0 then
		recoilPitch -= pitchBack
		recoilYaw -= yawBack
		AimCamera.addRotation(-math.rad(pitchBack), -math.rad(yawBack))
	end
	bloom = math.max(0, bloom - def.spread.bloomRecovery * dt)
	if t - lastShotAt > 0.4 then
		shotIndex = 0
	end
end

local function step(dt: number)
	local character = aliveCharacter()
	if character == nil or loadout == nil then
		return
	end
	local t = now()
	local state = currentGun()
	recoverRecoil(if state then state.def else nil, dt, t)
	updateAimAssist(dt, character)

	if equipped == "melee" then
		-- Celular: segurar ATIRAR faz o golpe forte.
		if triggerHeld and triggerFromTouch and not meleeSwungThisPress then
			if t - triggerDownAt >= WeaponConfig.Melee.touchHeavyHoldSeconds then
				WeaponController.swingMelee(true)
			end
		end
		return
	end
	if state == nil then
		return
	end

	WeaponState.update(state, t)
	if state.ammo <= 0 and state.reloadEndsAt == nil then
		WeaponController.reload()
	end

	local autoFire, autoSpin = autoFireWants(state, t)

	-- Metralhadoras: aquecer enquanto segura o gatilho (ou com o inimigo perto, no tiro automático)
	if state.def.spinUpTime then
		local wantSpin = triggerHeld or autoSpin or autoFire
		if wantSpin ~= spinSent then
			spinSent = wantSpin
			WeaponState.setSpin(state, wantSpin, t)
			send("Spin", t, wantSpin)
		end
	end

	local manual = triggerHeld
	if manual and state.def.fireMode ~= "Auto" and semiLatched then
		manual = false -- semiautomática: um tiro por toque
	end
	local wants = manual or autoFire or WeaponState.burstInProgress(state)
	if wants then
		-- Cadência exata: o tiro sai no horário em que ficou liberado (entre o quadro anterior e agora),
		-- não no começo do próximo quadro. Sem isso, a 60 quadros por segundo, a cadência arredonda para baixo.
		for _ = 1, MAX_SHOTS_PER_FRAME do
			local shotT = math.clamp(state.nextShotAt, math.max(lastStepT, lastSentT), t)
			if not WeaponState.canFire(state, shotT, 0) then
				if WeaponState.canFire(state, t, 0) then
					shotT = t
				else
					local _, reason = WeaponState.canFire(state, t, 0)
					if reason == "empty" then
						WeaponController.reload()
					end
					break
				end
			end
			fireOnce(state, shotT, character)
			if state.def.fireMode ~= "Auto" and not WeaponState.burstInProgress(state) and not autoFire then
				break
			end
		end
	end
	lastStepT = t
end

-- Entrada (PC e controle) ------------------------------------------------------------------------

local function onInputBegan(input: InputObject, processed: boolean)
	if processed then
		return
	end
	local inputType, key = input.UserInputType, input.KeyCode
	if inputType == Enum.UserInputType.MouseButton1 or key == Enum.KeyCode.ButtonR2 then
		WeaponController.setTrigger(true, false)
	elseif inputType == Enum.UserInputType.MouseButton2 or key == Enum.KeyCode.ButtonL2 then
		WeaponController.setAltHeld(true)
	elseif key == Enum.KeyCode.R or key == Enum.KeyCode.ButtonX then
		WeaponController.reload()
	elseif key == Enum.KeyCode.One then
		WeaponController.equip("primary")
	elseif key == Enum.KeyCode.Two then
		WeaponController.equip("secondary")
	elseif key == Enum.KeyCode.Three then
		WeaponController.equip("melee")
	elseif key == Enum.KeyCode.ButtonY then
		gamepadYDownAt = os.clock()
	end
end

local function onInputEnded(input: InputObject, _processed: boolean)
	local inputType, key = input.UserInputType, input.KeyCode
	if inputType == Enum.UserInputType.MouseButton1 or key == Enum.KeyCode.ButtonR2 then
		WeaponController.setTrigger(false, false)
	elseif inputType == Enum.UserInputType.MouseButton2 or key == Enum.KeyCode.ButtonL2 then
		if altHeld then
			WeaponController.setAltHeld(false)
		end
	elseif key == Enum.KeyCode.ButtonY and gamepadYDownAt then
		local held = os.clock() - gamepadYDownAt
		gamepadYDownAt = nil
		if held >= INPUT.GamepadSwitchHoldSeconds then
			WeaponController.equip("melee")
		else
			WeaponController.quickSwitch()
		end
	end
end

local function onInputChanged(input: InputObject, processed: boolean)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseWheel then
		return
	end
	cycle(if input.Position.Z > 0 then -1 else 1)
end

-- Servidor ---------------------------------------------------------------------------------------

local function onLoadout(data: CombatTypes.LoadoutData)
	loadout = data
	guns = {}
	if data.primary then
		local def = WeaponConfig.get(data.primary)
		if def then
			guns.primary = WeaponState.new(def)
		end
	end
	local secondaryDef = WeaponConfig.get(data.secondary)
	if secondaryDef then
		guns.secondary = WeaponState.new(secondaryDef)
	end
	melee = WeaponState.newMelee(WeaponConfig.Melee)
	equipped = data.equipped
	spinSent = false
	bloom = 0
	recoilPitch, recoilYaw = 0, 0
	local state = currentGun()
	if state then
		ViewModel.setWeapon(state.def.category)
	else
		ViewModel.setWeapon("Melee")
	end
	applyScope(nil)
	notifyChanged()
end

local function onSync(data: CombatTypes.SyncData)
	local state = guns[data.slot]
	if state then
		state.ammo = data.ammo
		state.reloadEndsAt = data.reloadEndsAt
		notifyChanged()
	end
end

-- API para HUD, botões de toque e painel de teste ---------------------------------------------------

function WeaponController.onChanged(callback: () -> ())
	table.insert(changedCallbacks, callback)
end

function WeaponController.getLoadout(): CombatTypes.LoadoutData?
	return loadout
end

function WeaponController.getEquippedSlot(): Slot
	return equipped
end

function WeaponController.getGun(slot: Slot): WeaponState.State?
	return guns[slot]
end

function WeaponController.getCurrentGun(): WeaponState.State?
	return currentGun()
end

function WeaponController.isScopedSniper(): boolean
	local state = currentGun()
	return state ~= nil and state.alt and WeaponConfig.hasScope(state.def) and state.def.category == "Sniper"
end

-- Teste de exploit (só DEV_): manda `count` tiros com horários colados, sem esperar a cadência.
function WeaponController.devRapidFire(count: number)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local t = now()
	for i = 1, count do
		local payload: CombatTypes.FirePayload = { origin = camera.CFrame.Position, ends = {}, hits = {} }
		send("Fire", t + (i - 1) * 0.001, payload)
	end
end

function WeaponController.Init()
	actionEvent = Remotes.event("WeaponAction")
end

function WeaponController.Start()
	Remotes.event("CombatEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Loadout" then
			onLoadout(data :: CombatTypes.LoadoutData)
		elseif kind == "Sync" then
			onSync(data :: CombatTypes.SyncData)
		end
	end)

	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	UserInputService.InputChanged:Connect(onInputChanged)

	AimCamera.setFrictionProvider(function(): number
		return if assistTarget then ASSIST.Friction else 1
	end)

	player.CharacterAdded:Connect(function(character: Model)
		updateFilters(character)
		triggerHeld = false
		altHeld = false
		applyScope(nil)
	end)
	updateFilters(player.Character)
	player.CharacterRemoving:Connect(function()
		ViewModel.clear()
		AimCamera.setZoom(nil)
		AimCamera.setScoped(false)
	end)

	RunService:BindToRenderStep("WeaponController", Enum.RenderPriority.Camera.Value + 2, step)
end

return WeaponController
