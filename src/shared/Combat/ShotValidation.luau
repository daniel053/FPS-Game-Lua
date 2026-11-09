--!strict
-- Checagens puras usadas pelo servidor para validar tiros (GDD 16.6). Separadas para poder testar.

local CombatConfig = require(script.Parent.Parent.Config.CombatConfig)

local VALIDATION = CombatConfig.Validation

local ShotValidation = {}

export type TimeRejectReason = "invalid" | "past" | "future" | "order"

-- O horário informado pelo cliente (`t`, em tempo do servidor) precisa ser um número, estar perto do
-- horário atual do servidor (`now`) e não pode ser anterior à última ação aceita (`lastT`).
-- Assim o cliente não consegue "inventar" tempo para atirar mais rápido que a cadência.
function ShotValidation.checkTime(t: unknown, now: number, lastT: number): (boolean, TimeRejectReason?)
	if typeof(t) ~= "number" or t ~= t or math.abs(t) == math.huge then
		return false, "invalid"
	end
	if t < now - VALIDATION.MaxPastSeconds then
		return false, "past"
	end
	if t > now + VALIDATION.MaxFutureSeconds then
		return false, "future"
	end
	if t < lastT then
		return false, "order"
	end
	return true, nil
end

-- Distância de um ponto até a superfície de uma cápsula em pé (0 ou negativo = dentro).
function ShotValidation.distanceToCapsule(point: Vector3, center: Vector3, height: number, radius: number): number
	local halfSegment = math.max(0, height / 2 - radius)
	local y = math.clamp(point.Y - center.Y, -halfSegment, halfSegment)
	local closest = Vector3.new(center.X, center.Y + y, center.Z)
	return (point - closest).Magnitude - radius
end

-- Vector3 válido (sem NaN nem infinito)?
function ShotValidation.isFiniteVector(value: unknown): boolean
	if typeof(value) ~= "Vector3" then
		return false
	end
	local v = value :: Vector3
	for _, c in { v.X, v.Y, v.Z } do
		if c ~= c or math.abs(c) == math.huge then
			return false
		end
	end
	return true
end

return ShotValidation
