--!strict
-- Trava a câmera em primeira pessoa no cliente (GDD 3.1) [DECIDIDO].
-- Reaplica a trava se qualquer coisa tentar mudar o modo ou o zoom. Não existe opção de terceira pessoa.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterConfig = require(ReplicatedStorage.Shared.Config.CharacterConfig)

local ZOOM = CharacterConfig.Camera.FirstPersonZoomDistance

local FirstPersonCamera = {}

local player = Players.LocalPlayer

local function enforce()
	if player.CameraMode ~= Enum.CameraMode.LockFirstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end
	if player.CameraMinZoomDistance ~= ZOOM then
		player.CameraMinZoomDistance = ZOOM
	end
	if player.CameraMaxZoomDistance ~= ZOOM then
		player.CameraMaxZoomDistance = ZOOM
	end
end

local function onCharacterAdded(_character: Model)
	task.defer(function()
		local camera = workspace.CurrentCamera
		if camera and camera.CameraType ~= Enum.CameraType.Custom then
			camera.CameraType = Enum.CameraType.Custom
		end
		enforce()
	end)
end

function FirstPersonCamera.Start()
	enforce()
	player:GetPropertyChangedSignal("CameraMode"):Connect(enforce)
	player:GetPropertyChangedSignal("CameraMinZoomDistance"):Connect(enforce)
	player:GetPropertyChangedSignal("CameraMaxZoomDistance"):Connect(enforce)

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

return FirstPersonCamera
