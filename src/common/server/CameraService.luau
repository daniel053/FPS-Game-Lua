--!strict
-- Trava a câmera em primeira pessoa para todos os jogadores, em todos os places (GDD 3.1) [DECIDIDO].
-- Camada do servidor; o cliente reforça em FirstPersonCamera.

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterConfig = require(ReplicatedStorage.Shared.Config.CharacterConfig)

local ZOOM = CharacterConfig.Camera.FirstPersonZoomDistance

local CameraService = {}

local function lockPlayer(player: Player)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = ZOOM
	player.CameraMaxZoomDistance = ZOOM
end

local function onPlayerAdded(player: Player)
	lockPlayer(player)
	player:GetPropertyChangedSignal("CameraMode"):Connect(function()
		if player.CameraMode ~= Enum.CameraMode.LockFirstPerson then
			lockPlayer(player)
		end
	end)
end

function CameraService.Init()
	-- Garante o padrão mesmo se o place não tiver sido sincronizado pelo Rojo.
	StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	StarterPlayer.CameraMinZoomDistance = ZOOM
	StarterPlayer.CameraMaxZoomDistance = ZOOM
end

function CameraService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return CameraService
