--!strict
-- Mapas e mundo do servidor de partida (GDD seção 15 e KIT-MODULAR).
-- Nomes exibidos em Strings.Maps. Plantas baixas das ilhas: aprovadas uma a uma na F10 (GDD 15.8).

local Types = require(script.Parent.Parent.Types)

-- Lado do mirante em que a ilha fica (norte = -Z, como no minimapa).
export type IslandPosition = "North" | "East" | "South" | "West"

export type MapDef = {
	id: Types.MapId,
	position: IslandPosition, -- [DECIDIDO] (F10, plantas do dono do projeto)
}

local MapConfig = {
	-- Regras gerais de todo mapa (GDD 15.1) [PROPOSTA]
	General = {
		PlayableWidth = 140,
		PlayableDepth = 105,
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

	-- Ilhas de duelo em volta do Mirante (GDD 15.3) [DECIDIDO] (F10): uma de cada lado do octógono.
	Maps = {
		{ id = "map_porto", position = "North" },
		{ id = "map_fabrica", position = "East" },
		{ id = "map_praca", position = "South" },
		{ id = "map_torre", position = "West" },
	} :: { MapDef },

	-- Mirante (GDD 6.5)
	Mirante = {
		FlatGround = true, -- sem torre e sem prédio no meio [DECIDIDO]
		InvisibleEdgeBarrier = true, -- [DECIDIDO]
		RoofsTransparentForSpectators = true, -- [PROPOSTA]
		ArenaPlayersSeeSpectators = false, -- [PROPOSTA]
		RoofTransparencyForSpectators = 0.85, -- 1 = invisível
		-- Octógono com piso levemente transparente [DECIDIDO] (F10): dá para ver as ilhas olhando para
		-- baixo sem precisar ir até a borda. Moldura opaca (grade e aro) para o piso
		-- continuar parecendo chão. Valores [PROPOSTA].
		GlassTransparency = 0.65,
		FrameWidth = 1.2, -- vigas da grade e do aro
		FrameHeight = 0.35,
		RimHeight = 0.6, -- aro visível na borda (a barreira invisível é mais alta)
	},

	-- Mundo da partida: posições e tamanhos [PROPOSTA] (F10, proporções das plantas do dono).
	-- Cada ilha fica "de lado" para o mirante: as duas bases ficam à esquerda e à direita de quem olha
	-- da borda (eixo X local da ilha = tangente ao mirante), então quem assiste vê os dois times por igual.
	World = {
		IslandFloorY = 0, -- topo do chão das ilhas
		IslandDistance = 180, -- do centro do mirante ao centro de cada ilha
		BodySize = Vector2.new(140, 105), -- área de duelo: comprimento (base a base) × largura
		BaseSize = Vector2.new(36, 42), -- cada base, fora da área de duelo, numa ponta (planta da Praça)
		BaseDoorWidth = 14, -- passagem da base para a área de duelo (planta da Praça)
		BaseSpawnSpread = 4, -- distância entre os dois pontos de nascer da base
		IslandThickness = 4,
		IslandEdgeRail = 3, -- mureta em volta (meia altura)
		MiranteFloorY = 70, -- topo do chão do mirante
		MiranteWidth = 110, -- octógono, de um lado ao lado oposto
		MiranteThickness = 1,
		MiranteBarrierHeight = 14, -- barreira invisível nas bordas
	},

	-- Céu e luz (ESTILO T4: céu claro e nuvens baixas; GDD 14: dia) [PROPOSTA]
	Sky = {
		ClockTime = 14,
		AtmosphereDensity = 0.12,
		AtmosphereHaze = 0.3,
		CloudSeed = 7,
		-- Mar de nuvens bem abaixo: o fundo olhando para baixo fica claro, nunca o azul-escuro do céu.
		-- Fundo o bastante para as sombras das ilhas e do mirante não chegarem nele (a -170 apareciam
		-- como buracos escuros).
		CloudSeaY = -500,
		CloudSeaSize = 2048, -- cada ladrilho (maior peça que o Roblox aceita)
		CloudSeaTiles = 5, -- ladrilhos por lado (ímpar, centrado no mirante)
		SeaClouds = 60, -- nuvens grandes em cima do mar
		SeaCloudRadius = NumberRange.new(0, 1600),
		LowClouds = 10, -- entre as ilhas e o mar (aparecem pelo vidro do mirante)
		LowCloudY = NumberRange.new(-110, -45),
		LowCloudRadius = NumberRange.new(0, 320),
		FarClouds = 14, -- no horizonte
		FarCloudY = NumberRange.new(-40, 30),
		FarCloudRadius = NumberRange.new(420, 600),
		CloudPuffs = NumberRange.new(3, 6), -- bolas por nuvem
		CloudPuffSize = NumberRange.new(16, 30),
	},
}

-- Giro (graus, em torno de Y) de cada lado: o eixo X local da ilha fica tangente ao mirante.
MapConfig.PositionYaw = {
	North = 0,
	South = 0,
	East = 90,
	West = 90,
} :: { [string]: number }

-- Direção (X, Z) do centro do mirante até cada lado.
MapConfig.PositionDirection = {
	North = Vector2.new(0, -1),
	East = Vector2.new(1, 0),
	South = Vector2.new(0, 1),
	West = Vector2.new(-1, 0),
} :: { [string]: Vector2 }

function MapConfig.islandCount(): number
	return #MapConfig.Maps
end

return MapConfig
