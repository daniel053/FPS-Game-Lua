--!strict
-- Mapas e mundo do servidor de partida (GDD seção 15 e KIT-MODULAR).
-- Nomes exibidos em Strings.Maps. Plantas baixas, tamanhos e paletas: [ABERTO] (GDD 15.8).

local Types = require(script.Parent.Parent.Types)

export type IslandPosition = "NorthWest" | "NorthEast" | "SouthWest" | "SouthEast"

export type MapDef = {
	id: Types.MapId,
	position: IslandPosition, -- posição em volta do Mirante [PROPOSTA]
}

local MapConfig = {
	-- Regras gerais de todo mapa (GDD 15.1) [PROPOSTA]
	General = {
		PlayableWidth = 140,
		PlayableDepth = 100,
		Routes = 3,
		MinHeightLevels = 2,
		MaxHeightLevels = 3,
		BaseToCenterSeconds = 6,
		LongSightlinesPerMap = 1,
		CoverEveryStuds = 10,
		ShieldPickupsPerMap = 2,
		ShieldPickupRespawnSeconds = 20,
		BaseSpawnProtectionSeconds = 3,
		FallOutReturnsToBase = true,
		FallOutLosesShield = true,
		MinCorridorWidth = 8,
		MinDoorWidth = 4, -- mínimo do KIT-MODULAR
		IdealDoorWidth = 6,
	},

	-- Regras de construção do kit (KIT-MODULAR seção 1) [DECIDIDO]
	Kit = {
		GridStuds = 1,
		FullCoverMinHeight = 6,
		HalfCoverHeight = 3,
		MaxPartsPerIsland = 3000,
		CylinderSides = { 6, 8 },
	},

	-- Ilhas de duelo em volta do Mirante (GDD 15.3)
	Maps = {
		{ id = "map_praca", position = "NorthWest" },
		{ id = "map_torre", position = "NorthEast" },
		{ id = "map_fabrica", position = "SouthWest" },
		{ id = "map_porto", position = "SouthEast" },
	} :: { MapDef },

	-- Mirante (GDD 6.5)
	Mirante = {
		FlatGround = true, -- sem torre e sem prédio no meio [DECIDIDO]
		InvisibleEdgeBarrier = true, -- [DECIDIDO]
		RoofsTransparentForSpectators = true, -- [PROPOSTA]
		ArenaPlayersSeeSpectators = false, -- [PROPOSTA]
		RoofTransparencyForSpectators = 0.85, -- 1 = invisível
	},

	-- Mundo cinza da F3 (montado por código; os mapas finais da F10 são construídos no Studio).
	-- Mirante em forma de losango (um quadrado girado 45°): cada lado fica de frente para uma ilha
	-- (borda noroeste -> ilha noroeste, etc.). As ilhas ficam em volta e abaixo [PROPOSTA].
	Gray = {
		IslandFloorY = 0, -- topo do chão das ilhas
		IslandSize = Vector2.new(140, 100), -- largura (eixo X, base a base) × profundidade
		IslandThickness = 4,
		IslandEdgeRail = 3, -- mureta em volta da ilha (meia altura)
		-- Centro de cada ilha (X, Z) por posição
		IslandCenters = {
			NorthWest = Vector2.new(-130, -105),
			NorthEast = Vector2.new(130, -105),
			SouthWest = Vector2.new(-130, 105),
			SouthEast = Vector2.new(130, 105),
		} :: { [IslandPosition]: Vector2 },
		BaseInset = 10, -- distância da base até a borda da ilha (eixo X)
		BaseSpawnSpread = 4, -- distância entre os dois pontos de nascer da base
		MiranteFloorY = 70, -- topo do chão do mirante
		MiranteHalfDiagonal = 75, -- do centro até cada ponta do losango
		MiranteThickness = 4,
		MiranteBarrierHeight = 14, -- barreira invisível nas bordas
	},
}

function MapConfig.islandCount(): number
	return #MapConfig.Maps
end

return MapConfig
