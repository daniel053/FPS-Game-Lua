--!strict
-- Nuvens da carta Nuvem no mundo (criadas pelo servidor, tag CardSmoke). A nuvem quase opaca já
-- esconde o corpo; aqui fica a conta "a linha de A até B passa por alguma nuvem?", usada para:
--   * não mostrar o contorno do inimigo através da nuvem (HighlightController);
--   * tiro automático e assistência de mira não "enxergarem" através dela (WeaponController).
-- Atirar através da nuvem continua valendo: ela bloqueia a visão, não as balas.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CardRules = require(Shared.Cards.CardRules)
local CardTypes = require(Shared.Cards.CardTypes)

local NAMES = CardTypes.Names

local Smoke = {}

local function radiusOf(part: BasePart): number
	local radius = part:GetAttribute(NAMES.SmokeRadiusAttr)
	return if typeof(radius) == "number" then radius else part.Size.X / 2
end

function Smoke.blocks(from: Vector3, to: Vector3): boolean
	for _, instance in CollectionService:GetTagged(NAMES.SmokeTag) do
		if
			instance:IsA("BasePart") and CardRules.segmentHitsSphere(from, to, instance.Position, radiusOf(instance))
		then
			return true
		end
	end
	return false
end

-- A nuvem em que este ponto está, se estiver dentro de uma.
function Smoke.containing(point: Vector3): BasePart?
	for _, instance in CollectionService:GetTagged(NAMES.SmokeTag) do
		if instance:IsA("BasePart") and (point - instance.Position).Magnitude < radiusOf(instance) then
			return instance
		end
	end
	return nil
end

function Smoke.all(): { BasePart }
	local list: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(NAMES.SmokeTag) do
		if instance:IsA("BasePart") then
			table.insert(list, instance)
		end
	end
	return list
end

return Smoke
