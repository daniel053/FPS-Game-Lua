--!strict
-- Ilha do lobby (ESTILO T3, FASES F10): montada pelo servidor ao iniciar, com colisão, pelo código
-- de `Shared/Maps/LobbyBuilder`. O fundo (o mundo da partida ao longe) é montado em cada cliente
-- (`LobbyBackdrop`), porque é só ambientação.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyBuilder = require(ReplicatedStorage.Shared.Maps.LobbyBuilder)

local LobbyWorld = {}

function LobbyWorld.Init()
	LobbyBuilder.install(workspace)
end

return LobbyWorld
