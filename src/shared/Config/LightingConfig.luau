--!strict
-- Iluminação e cor por mapa (MapLighting, só no cliente) [PROPOSTA].
-- As 4 ilhas estão no mesmo servidor e a Lighting é uma só (WorldBuilder.applyLighting monta a base:
-- dia, névoa leve). Cada jogador vê o ajuste da ilha em que está; no mirante e fora da partida, a base.
-- Tudo SUTIL (GDD 13.2: sem pós-processamento pesado; ESTILO: leitura competitiva primeiro):
--   * Saturation, Contrast e Brightness do ColorCorrectionEffect perto de 0;
--   * Exposure = quanto soma ao ExposureCompensation da base.
-- Os limites abaixo são conferidos em teste (MapLighting.spec): nenhum mapa pode passar deles.
-- A tinta de cada mapa (cor) fica no Theme.MapGrade.

export type Preset = {
	Saturation: number,
	Contrast: number,
	Brightness: number,
	Exposure: number,
}

local LightingConfig = {
	TransitionSeconds = 1.2, -- troca suave ao chegar na ilha ou voltar ao mirante
	CheckSeconds = 0.25, -- de quanto em quanto tempo confere a ilha do jogador

	Limits = {
		Saturation = 0.15, -- ±
		Contrast = 0.1, -- ±
		Brightness = 0.05, -- ±
		Exposure = 0.15, -- ±
		TintMinChannel = 0.9, -- a tinta é quase branca: nenhum canal abaixo de 90%
	},

	Maps = {
		map_porto = { Saturation = 0.06, Contrast = 0.03, Brightness = 0, Exposure = 0.03 },
		map_fabrica = { Saturation = -0.08, Contrast = 0.06, Brightness = -0.01, Exposure = -0.05 },
		map_praca = { Saturation = 0.1, Contrast = 0.02, Brightness = 0.01, Exposure = 0.03 },
		map_torre = { Saturation = 0.02, Contrast = 0.05, Brightness = 0, Exposure = 0.05 },
	} :: { [string]: Preset },
}

return LightingConfig
