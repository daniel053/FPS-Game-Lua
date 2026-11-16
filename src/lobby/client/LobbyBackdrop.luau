--!strict
-- Cenário do lobby (ESTILO T3, só ambientação): ao fundo, o mirante plano e as 4 ilhas de duelo de
-- verdade, montados pelo mesmo código da partida numa versão leve (`LobbyBuilder.backdrop`).
-- Montado só no cliente, aos poucos, sem colisão e sem nada salvo no place. A ilha onde o jogador
-- fica vem do servidor (`LobbyWorld`).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local LobbyBuilder = require(Shared.Maps.LobbyBuilder)
local MapConfig = require(Shared.Config.MapConfig)

local LobbyBackdrop = {}

function LobbyBackdrop.Start()
	local model = LobbyBuilder.backdrop(CFrame.new(MapConfig.Lobby.Center), task.wait)
	model.Parent = workspace
end

return LobbyBackdrop
