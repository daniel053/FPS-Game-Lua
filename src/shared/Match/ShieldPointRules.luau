--!strict
-- Ponto de recarga de escudo (GDD 15.1): regras puras, usadas pelo servidor e pelos testes.
-- Quem passa em cima de um ponto aceso com o escudo incompleto fica com o escudo cheio; o ponto
-- apaga e reacende depois de `ShieldPickupRespawnSeconds`. Com o escudo cheio o ponto não é gasto.

local CharacterConfig = require(script.Parent.Parent.Config.CharacterConfig)
local MapConfig = require(script.Parent.Parent.Config.MapConfig)

local GENERAL = MapConfig.General

local ShieldPointRules = {}

-- O ponto está aceso em `now`? (`readyAt` = quando reacende; nil = nunca foi usado)
function ShieldPointRules.isActive(readyAt: number?, now: number): boolean
	return readyAt == nil or now >= readyAt
end

-- O corpo (centro em `body`) está em cima do ponto (topo da placa em `pad`)?
function ShieldPointRules.inReach(pad: Vector3, body: Vector3): boolean
	local flat = Vector3.new(body.X - pad.X, 0, body.Z - pad.Z)
	local above = body.Y - pad.Y
	return flat.Magnitude <= GENERAL.ShieldPickupRadius and above >= 0 and above <= GENERAL.ShieldPickupHeight
end

-- Pode pegar? Só vivo, com o escudo incompleto e o ponto aceso.
function ShieldPointRules.canPickup(alive: boolean, shield: number, active: boolean): boolean
	return alive and active and shield < CharacterConfig.Health.MaxShield
end

-- Quando o ponto reacende depois de usado em `now`.
function ShieldPointRules.readyAfter(now: number): number
	return now + GENERAL.ShieldPickupRespawnSeconds
end

return ShieldPointRules
