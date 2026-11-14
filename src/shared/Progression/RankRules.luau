--!strict
-- Regras do elo (GDD seção 9) em funções puras: faixa pelos pontos, elo ADM pelo UserId, pontos por
-- colocação (proporcional ao número de duplas), proteção das primeiras partidas e perdas dobradas a
-- partir de Mestre. Quem aplica no perfil é o RankService (servidor); a tela só mostra.

local RankConfig = require(script.Parent.Parent.Config.RankConfig)
local Types = require(script.Parent.Parent.Types)

-- Faixa exibida: as 6 do GDD 9.1 ou "Adm" (GDD 9.4).
export type DisplayTier = Types.RankTierId | "Adm"

-- Resultado de uma partida para o elo.
export type Outcome = {
	placement: number, -- colocação da dupla (1 = campeã)
	teamCount: number, -- duplas que começaram a partida
}

export type Delta = {
	delta: number, -- já com proteção e perda dobrada; o piso 0 é do ProfileRules
	base: number, -- da tabela, antes das regras
	scaledPlace: number, -- colocação na escala de 8 duplas
	protected: boolean, -- perda anulada (primeiras partidas)
	doubled: boolean, -- perda dobrada (Mestre ou acima)
}

local RankRules = {}

-- Atributo no Player com a faixa exibida (RankService, todos os places).
RankRules.Attr = { Tier = "RankTier" }

local adminSet: { [number]: boolean } = {}
for _, id in RankConfig.AdminUserIds do
	adminSet[id] = true
end

-- Faixa pelos pontos (RankConfig.Tiers em ordem crescente).
function RankRules.tierOf(points: number): Types.RankTierId
	local result: Types.RankTierId = RankConfig.Tiers[1].id :: Types.RankTierId
	for _, tier in RankConfig.Tiers do
		if points >= tier.minPoints then
			result = tier.id :: Types.RankTierId
		end
	end
	return result
end

local function tierIndex(id: Types.RankTierId): number
	for i, tier in RankConfig.Tiers do
		if tier.id == id then
			return i
		end
	end
	return 1
end

-- Elo ADM: só pelo UserId em config, nunca pelo nome (GDD 9.4).
function RankRules.isAdmin(userId: number): boolean
	return adminSet[userId] == true
end

-- Faixa para mostrar (o ADM aparece como ADM, seja qual for o PE).
function RankRules.displayTier(userId: number, points: number): DisplayTier
	if RankRules.isAdmin(userId) then
		return "Adm"
	end
	return RankRules.tierOf(points)
end

-- Colocação levada para a escala da tabela (8 duplas): 1º continua 1º, o último vira 8º.
function RankRules.scaledPlace(placement: number, teamCount: number): number
	local reference = RankConfig.ReferenceTeams
	local place = math.clamp(math.floor(placement), 1, math.max(1, teamCount))
	if teamCount <= 1 then
		return 1
	end
	local scaled = 1 + (place - 1) * (reference - 1) / (teamCount - 1)
	return math.clamp(math.floor(scaled + 0.5), 1, reference)
end

-- Pontos da tabela para a colocação já na escala de 8.
function RankRules.tablePoints(scaledPlace: number): number
	for _, row in RankConfig.PlacementPoints do
		if scaledPlace >= row.fromPlace and scaledPlace <= row.toPlace then
			return row.points
		end
	end
	return 0
end

-- Quanto o PE muda depois de uma partida (GDD 9.2).
--   `points` = PE antes da partida; `rankedMatches` = partidas ranqueadas já jogadas (antes desta).
function RankRules.delta(points: number, rankedMatches: number, outcome: Outcome): Delta
	local scaled = RankRules.scaledPlace(outcome.placement, outcome.teamCount)
	local base = RankRules.tablePoints(scaled)
	local result: Delta = { delta = base, base = base, scaledPlace = scaled, protected = false, doubled = false }
	if base >= 0 then
		return result
	end
	if rankedMatches < RankConfig.ProtectedMatches then
		result.delta = 0
		result.protected = true
		return result
	end
	if tierIndex(RankRules.tierOf(points)) >= tierIndex(RankConfig.DoubleLossFromTier) then
		result.delta = base * RankConfig.DoubleLossMultiplier
		result.doubled = true
	end
	return result
end

-- Colocação de quem sai no meio (RankConfig.LeaverCountsAsEliminatedNow): como se a dupla caísse
-- agora, ou seja, atrás de todas as duplas que ainda estão vivas. `aliveTeams` conta a dele.
function RankRules.leaverPlacement(aliveTeams: number): number
	return math.max(1, aliveTeams)
end

return RankRules
