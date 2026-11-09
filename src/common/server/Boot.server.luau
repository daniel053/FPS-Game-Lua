--!strict
-- Ponto de entrada do servidor, igual nos 3 places.
-- Carrega os serviços comuns (ServerScriptService.Common) e os do place (ServerScriptService.Place).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Loader = require(ReplicatedStorage.Shared.Loader)

Loader.run({ script.Parent, ServerScriptService:FindFirstChild("Place") })
