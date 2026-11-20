--!strict
-- Iluminação e cor por mapa, só no cliente (LightingConfig e Theme.MapGrade) [PROPOSTA].
-- Um ColorCorrectionEffect próprio ("MapGrade") na Lighting, criado uma vez e reaproveitado: trocar de
-- ilha, de rodada ou de partida só muda os valores (nada se acumula). No mirante e sem ilha volta ao
-- neutro e ao ExposureCompensation da base. Não mexe em Atmosphere, céu nem nas luzes dos mapas
-- (WorldBuilder.applyLighting e os kits cuidam disso).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local LightingConfig = require(Shared.Config.LightingConfig)
local Theme = require(Shared.Config.Theme)
local WorldLayout = require(Shared.Match.WorldLayout)

local MatchClient = require(script.Parent.MatchClient)

local EFFECT_NAME = "MapGrade"
local NEUTRAL_TINT = Color3.new(1, 1, 1)

local MapLighting = {}

local effect: ColorCorrectionEffect
local baseExposure = 0
local currentMap: string? = nil
local applied = false
local tweens: { Tween } = {}

-- Reaproveita o efeito se já existir (script recarregado); apaga duplicatas.
local function getEffect(): ColorCorrectionEffect
	local found: ColorCorrectionEffect? = nil
	for _, child in Lighting:GetChildren() do
		if child.Name == EFFECT_NAME and child:IsA("ColorCorrectionEffect") then
			if found then
				child:Destroy()
			else
				found = child
			end
		end
	end
	if found then
		return found
	end
	local created = Instance.new("ColorCorrectionEffect")
	created.Name = EFFECT_NAME
	created.Parent = Lighting
	return created
end

local function apply(mapId: string?)
	for _, tween in tweens do
		tween:Cancel()
	end
	table.clear(tweens)
	local preset = if mapId then LightingConfig.Maps[mapId] else nil
	local tint = if mapId and preset then Theme.MapGrade[mapId] or NEUTRAL_TINT else NEUTRAL_TINT
	local info = TweenInfo.new(LightingConfig.TransitionSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	table.insert(
		tweens,
		TweenService:Create(effect, info, {
			Saturation = if preset then preset.Saturation else 0,
			Contrast = if preset then preset.Contrast else 0,
			Brightness = if preset then preset.Brightness else 0,
			TintColor = tint,
		})
	)
	table.insert(
		tweens,
		TweenService:Create(Lighting, info, {
			ExposureCompensation = baseExposure + (if preset then preset.Exposure else 0),
		})
	)
	for _, tween in tweens do
		tween:Play()
	end
end

local function check()
	local island = MatchClient.myIsland()
	local mapId = if island then WorldLayout.mapId(island) else nil
	if applied and mapId == currentMap then
		return
	end
	applied = true
	currentMap = mapId
	apply(mapId)
end

function MapLighting.Start()
	if not MatchClient.isEnabled() then
		return
	end
	baseExposure = Lighting.ExposureCompensation
	effect = getEffect()
	effect.Enabled = true
	while true do
		check()
		task.wait(LightingConfig.CheckSeconds)
	end
end

return MapLighting
