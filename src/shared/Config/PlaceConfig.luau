--!strict
-- IDs da experiência e dos 3 places.
-- Dev = experiência de teste (a atual, privada). Production = experiência real, criada antes do lançamento (F11).
-- Um ID 0 significa "ainda não configurado".

export type PlaceIds = {
	Lobby: number,
	Tutorial: number,
	Match: number,
}

export type Universe = {
	GameId: number,
	Places: PlaceIds,
}

local PlaceConfig = {
	Dev = {
		GameId = 10775571935,
		Places = {
			Lobby = 90852897401461, -- place inicial da experiência
			Tutorial = 0, -- preencher depois de criar o place no Studio
			Match = 0, -- preencher depois de criar o place no Studio
		},
	} :: Universe,

	Production = {
		GameId = 0,
		Places = {
			Lobby = 0,
			Tutorial = 0,
			Match = 0,
		},
	} :: Universe,
}

return PlaceConfig
