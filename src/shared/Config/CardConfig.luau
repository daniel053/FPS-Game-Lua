--!strict
-- Cartas de habilidade (GDD seção 8). Nomes e descrições ficam em Strings.Cards (por ID).
-- Na primeira versão só existem estas 4 cartas, iguais para todos (GDD 8.8) [DECIDIDO].
-- O sistema já nasce pronto para crescer: cada carta tem tecla fixa e a regra é uma carta por tecla.
-- Números do GDD 8.4 marcados [PROPOSTA]; os outros (velocidades, folgas) são técnicos, também
-- ajustáveis em teste.

local Types = require(script.Parent.Parent.Types)

export type CardDef = {
	id: string,
	key: Types.CardKey,
	isUlt: boolean,
	rarity: Types.Rarity?, -- raridade das 4 cartas iniciais: [ABERTO] (GDD 8.9)
	charges: number, -- cargas no começo de cada rodada
	cooldown: number?, -- segundos para uma carga voltar depois de usada (nil = não volta na rodada)
	minInterval: number, -- intervalo mínimo entre dois usos seguidos (segundos)
	params: { [string]: number },
}

local Cards: { CardDef } = {
	-- Nuvem (C): fumaça arremessável. Raio 8, duração 7 s, 2 cargas por rodada [PROPOSTA]
	{
		id = "card_nuvem",
		key = "C",
		isUlt = false,
		rarity = nil,
		charges = 2,
		cooldown = nil,
		minInterval = 0.6,
		params = {
			Radius = 8,
			Duration = 7,
			ThrowSpeed = 48, -- velocidade da bola ao sair da mão (studs/s)
			ThrowLift = 16, -- empurrão extra para cima, para fazer arco
			MaxFlightSeconds = 1.3, -- sem bater em nada, a bola vira nuvem no ar depois disto (~60 studs)
			HoldArcSeconds = 0.15, -- segurando a tecla/botão por mais que isto, mostra o arco
			MiranteTransparency = 0.6, -- de cima, a nuvem fica translúcida (ver os duelos)
			InsideOverlayTransparency = 0.25, -- câmera dentro da nuvem: tela coberta de névoa
		},
	},
	-- Impulso (Q): salto para cima. ~18 studs, 1 carga, recarga 20 s [PROPOSTA]
	{
		id = "card_impulso",
		key = "Q",
		isUlt = false,
		rarity = nil,
		charges = 1,
		cooldown = 20,
		minInterval = 0.3,
		params = {
			LaunchHeight = 18,
		},
	},
	-- Tremor (E): onda no chão. 20 × 6 studs, 50% de lentidão e mira tremida por 2 s, sem dano,
	-- 1 carga, recarga 25 s [PROPOSTA]
	{
		id = "card_tremor",
		key = "E",
		isUlt = false,
		rarity = nil,
		charges = 1,
		cooldown = 25,
		minInterval = 0.3,
		params = {
			Length = 20,
			Width = 6,
			SlowPercent = 0.5,
			DebuffDuration = 2,
			Damage = 0,
			WaveSpeed = 40, -- a onda anda à frente (studs/s); o efeito chega quando ela passa
			GroundTolerance = 3, -- diferença de altura máxima entre a onda e os pés do atingido
			GroundedCheck = 4.5, -- "no chão": algo até esta distância abaixo do centro do corpo
			AimShakeDegrees = 2.5, -- tremor da mira de quem foi atingido
			AimShakeSpeed = 9,
		},
	},
	-- Renascer (X, ult): segunda chance. Janela de 8 s, 1 uso por rodada [PROPOSTA]
	{
		id = "card_renascer",
		key = "X",
		isUlt = true,
		rarity = nil,
		charges = 1,
		cooldown = nil,
		minInterval = 0.3,
		params = {
			Window = 8, -- segundos em que cair faz voltar à marca com HP e escudo cheios
			ReturnProtection = 0.5, -- proteção curta ao voltar (evita ser derrubado no mesmo instante)
		},
	},
}

local CardConfig = {
	Cards = Cards,

	-- Cartas entregues pelo tutorial (GDD 8.8)
	StarterCards = { "card_nuvem", "card_impulso", "card_tremor", "card_renascer" },

	-- Escolha de carta (GDD 8.2) [DECIDIDO]
	ChoiceRound = 1, -- só na 1ª rodada
	ChoiceTime = 15, -- segundos; sem escolha = partida sem carta básica
	BasicKeys = { "C", "Q", "E" } :: { Types.CardKey },
	-- Dupla de folga na 1ª rodada escolhe na sua primeira preparação [PROPOSTA] (GDD 8.2, F4)
	ByeTeamChoosesOnFirstPrep = true,

	-- Ult (GDD 8.5) [DECIDIDO]
	UltKey = "X" :: Types.CardKey,
	UltUnlockRound = 4,
	UltUsesPerRound = 1, -- [PROPOSTA]
	-- Renascer: se os 8 s passarem sem cair, volta à marca mantendo a vida atual [PROPOSTA] (GDD 8.4)
	RenascerReturnOnExpire = true,

	-- Coleção (GDD 8.3) [DECIDIDO]: no máximo uma carta por tecla.
	MaxCardsPerKey = 1,

	-- Pedidos de carta do cliente: limite por segundo (o resto é ignorado)
	ActionsPerSecond = 10,
}

local byId: { [string]: CardDef } = {}
for _, card in Cards do
	byId[card.id] = card
end

function CardConfig.get(id: string): CardDef?
	return byId[id]
end

return CardConfig
