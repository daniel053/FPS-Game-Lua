--!strict
-- Mensagens da comunicação (F8) entre servidor e cliente (remotes SocialRequest e SocialEvent).
-- O servidor confere tudo o que chega: tipo, valores, onde o jogador está e a frequência.

-- Cliente -> servidor, remote "SocialRequest": (tipo, argumento)
export type RequestName =
	"Ping" -- PingRequest
	| "Phrase" -- ID da frase (SocialConfig.Phrases.Ids)
	| "Emote" -- ID do emote (SocialConfig.Emotes.List)
	| "Praise" -- nil: elogiar o parceiro

export type PingRequest = { kind: string, position: Vector3 }

-- Servidor -> cliente, remote "SocialEvent": (tipo, dados)
export type EventName =
	"Ping" -- PingData (para quem marcou e para o parceiro)
	| "Phrase" -- PhraseData (para quem falou e para o parceiro)
	| "Emote" -- { id: string } (para quem fez)
	| "Praised" -- { name: string } (o parceiro elogiou você)
	| "PraiseSent" -- { name: string } (seu elogio chegou)

export type PingData = {
	fromUserId: number,
	name: string,
	kind: string,
	position: Vector3,
	island: number,
	expiresAt: number, -- tempo do servidor
}

export type PhraseData = { fromUserId: number, name: string, id: string }

return {}
