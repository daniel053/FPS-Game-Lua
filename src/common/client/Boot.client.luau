--!strict
-- Ponto de entrada do cliente, igual nos 3 places.
-- Carrega os controladores comuns (PlayerScripts.Common), os de combate (PlayerScripts.Combat, só na
-- Partida e no Tutorial) e os do place (PlayerScripts.Place).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Loader)

local playerScripts = script.Parent and script.Parent.Parent
-- Os 3 places têm a pasta Place: espera ela chegar (o Roblox copia as pastas do StarterPlayerScripts
-- uma de cada vez, e este script pode rodar antes). Combat só existe na Partida e no Tutorial.
local placeFolder = if playerScripts then playerScripts:WaitForChild("Place", 10) else nil
local combatFolder = if playerScripts then playerScripts:FindFirstChild("Combat") else nil

Loader.run({ script.Parent, combatFolder, placeFolder })
