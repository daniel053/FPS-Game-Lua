--!strict
-- Mensagens das cartas entre servidor e cliente (remotes em Remotes.luau).
-- O servidor nunca confia no que chega: tecla, horário e direção são conferidos campo a campo.

type CardKey = string -- "C", "Q", "E" ou "X" (Types.CardKey); string por causa do verificador de tipos

-- Cliente -> servidor, remote "CardAction": ("Use", tecla, horário em tempo do servidor, direção?)
-- A direção (para onde a câmera olha) só é usada pela Nuvem e pelo Tremor.
export type ActionName = "Use"

-- Uma carta no HUD do jogador.
export type CardView = {
	key: CardKey,
	id: string,
	charges: number,
	maxCharges: number,
	rechargeAt: number?, -- tempo do servidor
	locked: boolean, -- ult antes da 4ª rodada (cadeado)
}

-- Servidor -> um jogador, remote "CardEvent": (tipo, dados)
export type EventName =
	"Cards" -- CardsData: cartas desta rodada (ou da partida, fora do combate); manda de novo a cada mudança
	| "Launch" -- LaunchData: Impulso aceito; o cliente aplica a velocidade (ele controla o próprio corpo)
	| "Renascer" -- RenascerData: marca ativa (endsAt) ou terminou (endsAt = nil)
	| "Tremored" -- TremoredData: você foi atingido pelo Tremor

export type CardsData = {
	cards: { CardView },
	active: boolean, -- false = fora do combate (mirante, preparação): só mostra
}

export type LaunchData = { speed: number }

export type RenascerData = { endsAt: number?, revived: boolean? }

export type TremoredData = { untilT: number }

-- Servidor -> todos, remote "CardFx": (tipo, dados). Só efeito visual.
export type FxName =
	"NuvemThrow" -- NuvemThrowData
	| "TremorWave" -- TremorWaveData
	| "ImpulsoLaunch" -- ImpulsoLaunchData
	| "RenascerReturn" -- RenascerReturnData

-- caster: quem usou (legendas "Inimigo usou …", ESTILO 5)
export type NuvemThrowData = { origin: Vector3, velocity: Vector3, flight: number, gravity: number, caster: Player? }

export type TremorWaveData = {
	origin: Vector3,
	direction: Vector3,
	length: number,
	width: number,
	speed: number,
	caster: Player?,
}

export type ImpulsoLaunchData = { feet: Vector3, caster: Player? }

export type RenascerReturnData = { from: Vector3, to: Vector3, caster: Player? }

-- Nomes no mundo (servidor cria, cliente lê)
local Names = {
	WorldFolder = "CardWorldEffects", -- nuvens e marcas do Renascer (workspace)
	SmokeTag = "CardSmoke", -- cada nuvem; atributo Radius
	SmokeRadiusAttr = "Radius",
	MarkTag = "RenascerMark",
	-- No modelo do combatente: até quando está lento e com a mira tremida (tempo do servidor)
	TremorUntilAttr = "TremorUntil",
}

return {
	Names = Names,
}
