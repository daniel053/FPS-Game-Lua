--!strict
-- Camada em cima da câmera de primeira pessoa do Roblox (FirstPersonCamera continua travando o modo).
-- Roda logo depois da câmera do Roblox, a cada quadro, e:
--   * aplica a sensibilidade do perfil (toque, mouse ou controle) e o multiplicador da mira aberta
--     (GDD 7.2.6 e 7.5), escalando o quanto a câmera girou por causa do jogador neste quadro;
--   * soma rotações pedidas pelo jogo (recuo, assistência de mira, arrastar o dedo no botão ATIRAR);
--   * controla o campo de visão (padrão e zoom da mira).
-- A câmera do Roblox lê a direção atual da própria câmera a cada quadro, então as mudanças ficam.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CharacterConfig = require(ReplicatedStorage.Shared.Config.CharacterConfig)

local InputDevice = require(script.Parent.InputDevice)
local PlayerDataClient = require(script.Parent.PlayerDataClient)

local MAX_PITCH = math.rad(CharacterConfig.Camera.MaxPitchDegrees)
local JUMP_RESET = math.rad(100) -- giro maior que isto num quadro = teleporte/troca de câmera, não do jogador
local ZOOM_SECONDS = 0.12

local AimCamera = {}

local hasBaseline = false
local lastYaw, lastPitch = 0, 0
local pendingYaw, pendingPitch = 0, 0
local lastInputRotation = 0 -- radianos girados pelo jogador no último quadro
local scoped = false
local frictionProvider: (() -> number)? = nil
local zoomFov: number? = nil
local fovTween: Tween? = nil

local function wrapAngle(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

-- Sensibilidade do perfil para o controle em uso (1 = padrão do Roblox).
function AimCamera.getSensitivity(): number
	local profile = PlayerDataClient.get()
	if profile == nil then
		return 1
	end
	local s = profile.settings.sensitivity
	local device = InputDevice.get()
	local value = if device == "Touch" then s.touch elseif device == "Gamepad" then s.gamepad else s.mouse
	if scoped then
		value *= s.scopedMultiplier
	end
	return value
end

-- Gira a câmera (radianos; positivo = para cima / para a esquerda). Aplicado no próximo quadro.
function AimCamera.addRotation(pitch: number, yaw: number)
	pendingPitch += pitch
	pendingYaw += yaw
end

-- Mira aberta: usa o multiplicador de sensibilidade da mira.
function AimCamera.setScoped(on: boolean)
	scoped = on
end

-- Campo de visão da mira (nil = padrão).
function AimCamera.setZoom(fov: number?)
	if zoomFov == fov then
		return
	end
	zoomFov = fov
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	if fovTween then
		fovTween:Cancel()
	end
	local target = fov or CharacterConfig.Camera.FieldOfView
	local tween = TweenService:Create(camera, TweenInfo.new(ZOOM_SECONDS), { FieldOfView = target })
	fovTween = tween
	tween:Play()
end

-- Assistência de mira: função que devolve um multiplicador (1 = nada) aplicado ao giro do jogador.
function AimCamera.setFrictionProvider(provider: (() -> number)?)
	frictionProvider = provider
end

-- Quanto o jogador girou a câmera no último quadro (radianos). Usado pela assistência de mira.
function AimCamera.getLastInputRotation(): number
	return lastInputRotation
end

local function step()
	local camera = workspace.CurrentCamera
	if camera == nil or camera.CameraType ~= Enum.CameraType.Custom then
		hasBaseline = false
		return
	end

	if zoomFov == nil and fovTween == nil and camera.FieldOfView ~= CharacterConfig.Camera.FieldOfView then
		camera.FieldOfView = CharacterConfig.Camera.FieldOfView
	end
	if fovTween and fovTween.PlaybackState ~= Enum.PlaybackState.Playing then
		fovTween = nil
	end

	local cframe = camera.CFrame
	local look = cframe.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local pitch = math.asin(math.clamp(look.Y, -1, 1))

	if not hasBaseline then
		hasBaseline = true
		lastYaw, lastPitch = yaw, pitch
		pendingYaw, pendingPitch = 0, 0
		return
	end

	local dYaw = wrapAngle(yaw - lastYaw)
	local dPitch = pitch - lastPitch
	if math.abs(dYaw) > JUMP_RESET or math.abs(dPitch) > JUMP_RESET then
		-- Teleporte ou câmera reposicionada: recomeça daqui.
		lastYaw, lastPitch = yaw, pitch
		pendingYaw, pendingPitch = 0, 0
		return
	end

	local scale = AimCamera.getSensitivity()
	if frictionProvider then
		scale *= frictionProvider()
	end
	lastInputRotation = math.sqrt(dYaw * dYaw + dPitch * dPitch)

	local newYaw = lastYaw + dYaw * scale + pendingYaw
	local newPitch = math.clamp(lastPitch + dPitch * scale + pendingPitch, -MAX_PITCH, MAX_PITCH)
	pendingYaw, pendingPitch = 0, 0

	if newYaw ~= yaw or newPitch ~= pitch then
		camera.CFrame = CFrame.new(cframe.Position) * CFrame.fromEulerAnglesYXZ(newPitch, newYaw, 0)
	end
	lastYaw, lastPitch = newYaw, newPitch
end

function AimCamera.Start()
	RunService:BindToRenderStep("AimCamera", Enum.RenderPriority.Camera.Value + 1, step)
end

return AimCamera
