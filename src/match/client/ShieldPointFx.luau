--!strict
-- Som do ponto de escudo (F10): quando um ponto apaga (alguém pegou o escudo), toca o brilho no
-- lugar dele. O servidor é quem decide (match/server/ShieldPoints); aqui só se ouve.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local AudioConfig = require(Shared.Config.AudioConfig)
local IslandCommon = require(Shared.Maps.IslandCommon)

local CombatEffects = require(script.Parent.Parent.Combat.CombatEffects)

local ACTIVE = "ShieldPointActive" -- mesmo nome do match/server/ShieldPoints

local ShieldPointFx = {}

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	model:GetAttributeChangedSignal(ACTIVE):Connect(function()
		if model:GetAttribute(ACTIVE) == false then
			CombatEffects.playSoundAt(AudioConfig.ShieldPickup, model:GetPivot().Position)
		end
	end)
end

function ShieldPointFx.Start()
	CollectionService:GetInstanceAddedSignal(IslandCommon.ShieldPointTag):Connect(watch)
	for _, model in CollectionService:GetTagged(IslandCommon.ShieldPointTag) do
		watch(model)
	end
end

return ShieldPointFx
