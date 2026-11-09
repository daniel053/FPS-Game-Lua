--!strict
-- Ponto de entrada do cliente, igual nos 3 places.
-- Carrega os controladores comuns (PlayerScripts.Common) e os do place (PlayerScripts.Place).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Loader)

local playerScripts = script.Parent and script.Parent.Parent
local placeFolder = if playerScripts then playerScripts:FindFirstChild("Place") else nil

Loader.run({ script.Parent, placeFolder })
