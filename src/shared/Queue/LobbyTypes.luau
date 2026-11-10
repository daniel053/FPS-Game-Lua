--!strict
-- Mensagens do lobby (F5): grupo de 2, convites e fila. O servidor manda a foto (LobbyState) para
-- cada jogador; o cliente só pede (LobbyRequest) e mostra.

export type PartyState = "Idle" | "Queued" | "Teleporting"

export type MemberView = {
	userId: number,
	name: string,
	rankTier: string, -- Bronze, Prata… (Strings.Ranks)
	ready: boolean,
}

export type PlayerRef = { userId: number, name: string }

export type QueueView = {
	count: number,
	target: number,
	startsAt: number?, -- horário do servidor (workspace:GetServerTimeNow) em que a partida sai
}

export type Snapshot = {
	members: { MemberView }, -- o próprio jogador primeiro
	state: PartyState,
	queue: QueueView?, -- só na fila
	invitesIn: { PlayerRef }, -- quem me convidou
	invitedOut: { number }, -- quem eu convidei (UserIds)
	available: { PlayerRef }, -- quem dá para convidar agora (mesmo servidor, sozinho, fora da fila)
}

export type RequestName =
	"Invite" -- UserId
	| "AcceptInvite" -- UserId de quem convidou
	| "DeclineInvite" -- UserId de quem convidou
	| "LeaveParty"
	| "Play" -- fico pronto; com todos prontos o grupo entra na fila
	| "Cancel" -- saio da fila (ou deixo de estar pronto)

export type EventName = "Notice" -- { key: string, name: string? }

return {}
