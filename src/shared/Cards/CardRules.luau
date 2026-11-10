--!strict
-- Regras puras das cartas (GDD 8.2 a 8.5). Sem rede, sem tempo real: o servidor usa para decidir,
-- o cliente para mostrar, e os testes automáticos para conferir.

local CardConfig = require(script.Parent.Parent.Config.CardConfig)

type CardKey = string -- "C", "Q", "E" ou "X" (Types.CardKey); string por causa do verificador de tipos
type CardDef = CardConfig.CardDef

export type GetCard = (id: string) -> CardDef?

-- Cartas que estão valendo numa rodada: tecla -> ID.
export type RoundCards = { [CardKey]: string }

local CardRules = {}

local function keyOrder(key: CardKey): number
	return table.find(CardConfig.BasicKeys, key) or (#CardConfig.BasicKeys + 1)
end

-- Cartas básicas (C, Q, E) que o jogador tem, na ordem das teclas. São as opções da escolha.
function CardRules.basicOptions(owned: { [string]: any }, getCard: GetCard?): { string }
	local get: GetCard = getCard or CardConfig.get
	local list: { string } = {}
	for id in owned do
		local def = get(id)
		if def and not def.isUlt then
			table.insert(list, id)
		end
	end
	table.sort(list, function(a: string, b: string): boolean
		local ka, kb = keyOrder((get(a) :: CardDef).key), keyOrder((get(b) :: CardDef).key)
		if ka ~= kb then
			return ka < kb
		end
		return a < b
	end)
	return list
end

-- A escolha da carta básica é válida? (o jogador tem a carta e ela não é ult)
function CardRules.isBasicChoiceAllowed(owned: { [string]: any }, cardId: unknown, getCard: GetCard?): boolean
	if typeof(cardId) ~= "string" or owned[cardId :: string] == nil then
		return false
	end
	local get: GetCard = getCard or CardConfig.get
	local def = get(cardId :: string)
	return def ~= nil and not def.isUlt
end

-- A ult (X) que o jogador tem, se tiver. Não é escolhida: vem sozinha (GDD 8.2).
function CardRules.ultOf(owned: { [string]: any }, getCard: GetCard?): string?
	local get: GetCard = getCard or CardConfig.get
	local found: string? = nil
	for id in owned do
		local def = get(id)
		if def and def.isUlt and (found == nil or id < (found :: string)) then
			found = id
		end
	end
	return found
end

-- Ult liberada para todos a partir da 4ª rodada (GDD 8.5) [DECIDIDO].
function CardRules.ultUnlocked(round: number): boolean
	return round >= CardConfig.UltUnlockRound
end

-- Cartas valendo nesta rodada: a básica escolhida (a partida toda) e a ult, se já liberou.
function CardRules.roundCards(basicId: string?, ultId: string?, round: number, getCard: GetCard?): RoundCards
	local get: GetCard = getCard or CardConfig.get
	local cards: RoundCards = {}
	if basicId then
		local def = get(basicId)
		if def and not def.isUlt then
			cards[def.key] = basicId
		end
	end
	if ultId and CardRules.ultUnlocked(round) then
		local def = get(ultId)
		if def and def.isUlt then
			cards[def.key] = ultId
		end
	end
	return cards
end

-- Geometria ---------------------------------------------------------------------------------------

-- Impulso: velocidade para cima que leva o jogador a `height` studs (sem resistência do ar).
function CardRules.launchSpeed(height: number, gravity: number): number
	return math.sqrt(2 * gravity * math.max(0, height))
end

-- Nuvem: pontos da trajetória da bola a cada `step` segundos, até `maxTime`.
function CardRules.throwPath(
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	maxTime: number,
	step: number
): { Vector3 }
	local points = { origin }
	local t = 0
	while t < maxTime - 1e-9 do
		t = math.min(maxTime, t + step)
		table.insert(points, origin + velocity * t + Vector3.new(0, -0.5 * gravity * t * t, 0))
	end
	return points
end

-- Tremor: `position` está dentro da onda (retângulo no chão à frente de `origin`, na direção `dir`)?
-- Devolve (dentro, distância ao longo da onda). `dir` é achatado no chão.
function CardRules.inWave(
	origin: Vector3,
	dir: Vector3,
	length: number,
	width: number,
	heightTolerance: number,
	position: Vector3
): (boolean, number)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 1e-6 then
		return false, 0
	end
	local forward = flat.Unit
	local rel = position - origin
	if math.abs(rel.Y) > heightTolerance then
		return false, 0
	end
	local relFlat = Vector3.new(rel.X, 0, rel.Z)
	local along = relFlat:Dot(forward)
	if along < 0 or along > length then
		return false, along
	end
	local lateral = (relFlat - forward * along).Magnitude
	return lateral <= width / 2, along
end

-- Nuvem: o segmento de `a` até `b` passa pela esfera? (visão bloqueada pela fumaça)
function CardRules.segmentHitsSphere(a: Vector3, b: Vector3, center: Vector3, radius: number): boolean
	local ab = b - a
	local lengthSq = ab:Dot(ab)
	local t = if lengthSq > 1e-9 then math.clamp((center - a):Dot(ab) / lengthSq, 0, 1) else 0
	local closest = a + ab * t
	return (center - closest).Magnitude <= radius
end

-- Direção enviada pelo cliente: vetor finito, com tamanho perto de 1. Devolve a direção normalizada.
function CardRules.readDirection(value: unknown): Vector3?
	if typeof(value) ~= "Vector3" then
		return nil
	end
	local v = value :: Vector3
	for _, n in { v.X, v.Y, v.Z } do
		if n ~= n or math.abs(n) == math.huge then
			return nil
		end
	end
	local magnitude = v.Magnitude
	if magnitude < 0.5 or magnitude > 1.5 then
		return nil
	end
	return v.Unit
end

return CardRules
