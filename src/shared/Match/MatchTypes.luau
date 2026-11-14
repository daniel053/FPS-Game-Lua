--!strict
-- Mensagens da partida entre servidor e cliente (remotes em Remotes.luau).
-- O servidor nunca confia no que chega do cliente: tudo é checado campo a campo.

-- Estados da máquina do servidor (GDD 4.1)
export type Phase =
	"Receiving" -- RECEBENDO_JOGADORES
	| "Forming" -- FORMANDO_DUPLAS
	| "Draw" -- SORTEIO_CONFRONTOS + TELEPORTE (confrontos na tela)
	| "Prep" -- PREPARACAO (congelado na base, modal de armas)
	| "Combat" -- COMBATE
	| "RoundEnd" -- FIM_RODADA (placar)
	| "Champion" -- CAMPEAO (cerimônia)
	| "EndScreen" -- RECOMPENSAS E ELO (F9) + TELA_FINAL

export type MemberView = { key: string, name: string, userId: number, isBot: boolean, connected: boolean }

export type TeamView = {
	id: string, -- cor da equipe (TeamColors)
	lives: number,
	roundWins: number,
	eliminated: boolean,
	placement: number?,
	members: { MemberView },
}

export type DuelView = {
	a: string,
	b: string,
	island: number, -- índice em MapConfig.Maps
	finished: boolean,
	winner: string?, -- nil com finished = empate
}

-- Servidor -> todos, remote "MatchState": foto completa a cada mudança.
export type Snapshot = {
	phase: Phase,
	round: number,
	endsAt: number?, -- fim da etapa atual (tempo do servidor)
	combatStartedAt: number?, -- começo do COMBATE (zona: MatchConfig.Zone)
	isVirada: boolean,
	isFinal: boolean,
	viradaDone: boolean,
	teams: { TeamView },
	duels: { DuelView },
	bye: string?,
	championId: string?,
	waiting: number, -- jogadores no servidor antes de começar
	minPlayers: number,
}

-- Servidor -> um jogador, remote "MatchEvent": (tipo, dados)
export type EventName =
	"PrepOpen" -- PrepData
	| "PrepPartner" -- PartnerChoiceData
	| "PrepClose" -- nil
	| "Announce" -- AnnounceData
	| "AfkWarning" -- { seconds: number } (0 = some)
	| "Eliminated" -- nil: escolher Assistir ou Nova partida
	| "PartnerQuestion" -- { partnerName: string }
	| "EndScreen" -- EndScreenData
	| "Notice" -- { key: string }
	| "Rewards" -- RewardsData: moedas e elo da partida (F9), quando são creditados

export type PrepData = {
	round: number,
	phaseId: string,
	primaries: { string },
	secondaries: { string },
	endsAt: number,
	cardStep: boolean, -- etapa da carta aberta: 1ª preparação do jogador na partida (GDD 8.2)
	cardOptions: { string }, -- cartas básicas que o jogador tem (vazio = ainda não tem cartas)
	card: string?, -- carta básica escolhida (travada depois da etapa da carta)
	ult: string?, -- ult do jogador (vem sozinha a partir da 4ª rodada)
	ultUnlocked: boolean,
	primary: string?, -- escolha atual (já resolvida: anterior / perfil / primeira)
	secondary: string,
}

export type PartnerChoiceData = {
	name: string,
	primary: string?,
	secondary: string?,
	card: string?,
	confirmed: boolean,
}

export type AnnounceKind =
	"Matchups"
	| "Bye"
	| "RoundStart"
	| "Virada"
	| "FinalStart"
	| "DuelWon"
	| "DuelLost"
	| "DuelTie"
	| "TeamEliminated"
	| "Champion"
	| "PartnerLeft"

export type AnnounceData = { kind: AnnounceKind, teamId: string?, otherId: string?, island: number? }

export type EndScreenData = {
	placement: number?,
	championId: string?,
	endsAt: number,
	partnerName: string?,
}

-- Recompensas da partida (F9, GDD 9 e 10), mandadas a quem recebeu, quando são creditadas: ao ser
-- eliminado, no fim da partida ou ao sair no meio.
export type RewardsData = {
	placement: number?,
	coins: number,
	coinsBreakdown: {
		rounds: number,
		wins: number,
		kills: number,
		placement: number,
		partnerBonus: number,
		firstWin: number,
		privateCut: number,
	},
	ranked: boolean,
	rankDelta: number,
	rankPoints: number,
	rankTier: string, -- faixa depois (RankRules.DisplayTier)
	rankTierBefore: string,
	rankProtected: boolean, -- perda anulada (primeiras partidas)
	rankDoubled: boolean, -- perda dobrada (Mestre ou acima)
}

-- Cliente -> servidor, remote "MatchRequest": (tipo, argumento)
export type RequestName =
	"PrepChoose" -- { primary: string?, secondary: string? }
	| "PrepCard" -- ID da carta básica (só na etapa da carta)
	| "PrepConfirm"
	| "Watch" -- equipe eliminada: assistir do mirante
	| "NewMatch" -- equipe eliminada ou fim: voltar ao lobby para outra partida
	| "PartnerAnswer" -- boolean: seguir com o parceiro?

-- Atributos no Player (replicam para todos)
local Attr = {
	Location = "MatchLocation", -- "Mirante" ou "Island1".."Island4" (nil = fora do mundo, ex.: derrubado)
	Island = "Island", -- no modelo do combatente: índice da ilha (só acerta quem está na mesma)
	Look = "LookDir", -- no modelo: para onde o jogador olha (espectar o parceiro)
}

return {
	Attr = Attr,
	MiranteLocation = "Mirante",
	RoofTag = "MiranteRoof", -- telhados que ficam transparentes para quem está no mirante
}
