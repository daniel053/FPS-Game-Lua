--!strict
-- Ponto de entrada do cliente, igual nos 3 places.
-- Carrega os controladores comuns (PlayerScripts.Common), os de combate (PlayerScripts.Combat, só na
-- Partida e no Tutorial) e os do place (PlayerScripts.Place).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Loader)

local playerScripts = script.Parent and script.Parent.Parent
local combatFolder = if playerScripts then playerScripts:FindFirstChild("Combat") else nil
local placeFolder = if playerScripts then playerScripts:FindFirstChild("Place") else nil

Loader.run({ script.Parent, combatFolder, placeFolder })
