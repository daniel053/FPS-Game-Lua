--!strict
-- Lista única de RemoteEvents do jogo.
-- O servidor cria; o cliente espera. Nenhum remote é criado à mão no Studio.
-- Regra: o servidor valida TUDO o que chega por aqui (tipo, valores, frequência).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type EventName =
	"DevTeleportRequest" -- cliente -> servidor: (destino: PlaceName) — só em DEV_
	| "DevTeleportResult" -- servidor -> cliente: (sucesso: boolean, chaveDaMensagem: string) — só em DEV_
	| "ProfileSnapshot" -- servidor -> cliente: (perfil: PlayerData.Profile) — cópia somente leitura, a cada mudança
	| "SettingsUpdateRequest" -- cliente -> servidor: (pedido: campos de Settings que mudaram)
	| "SettingsUpdateResult" -- servidor -> cliente: (sucesso: boolean, chaveDaMensagem: string, erroDeValidação: string?)
	| "DevDataCommand" -- cliente -> servidor: (comando: string) — só em DEV_
	| "DevDataResult" -- servidor -> cliente: (sucesso: boolean, chaveDaMensagem: string, detalhe: string?) — só em DEV_
	| "WeaponAction" -- cliente -> servidor: (ação, horário, argumento) — ver Combat/CombatTypes
	| "CombatEvent" -- servidor -> cliente: (tipo, dados) — ver Combat/CombatTypes
	| "DevCombatCommand" -- cliente -> servidor: (comando: string, argumento: any) — só em DEV_
	| "DevCombatResult" -- servidor -> cliente: (sucesso: boolean, chaveDaMensagem: string, detalhe: string?) — só em DEV_
	| "MatchState" -- servidor -> clientes: (foto: Match/MatchTypes.Snapshot)
	| "MatchEvent" -- servidor -> cliente: (tipo, dados) — ver Match/MatchTypes
	| "MatchRequest" -- cliente -> servidor: (tipo, argumento) — ver Match/MatchTypes
	| "DevMatchCommand" -- cliente -> servidor: (comando: string, argumento: any) — só em DEV_
	| "DevMatchResult" -- servidor -> cliente: (sucesso: boolean, chaveDaMensagem: string, detalhe: string?) — só em DEV_

-- Eventos sem garantia de entrega (efeitos visuais frequentes; perder um não muda o jogo).
export type UnreliableEventName =
	"ShotFx" -- servidor -> clientes: (atirador: Model, arma: string, origem: Vector3, fins: {Vector3})
	| "LookSync" -- cliente -> servidor: (direção do olhar: Vector3), para o parceiro espectar

local FOLDER_NAME = "Remotes"
local CLIENT_WAIT_TIMEOUT = 15

local Remotes = {}

local function getFolder(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end

	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, CLIENT_WAIT_TIMEOUT)
	assert(folder, "Pasta de remotes não apareceu no ReplicatedStorage")
	return folder
end

local function getOrCreate(name: string, className: string): Instance
	local folder = getFolder()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA(className) then
			return existing
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	local remote = folder:WaitForChild(name, CLIENT_WAIT_TIMEOUT)
	assert(remote and remote:IsA(className), `Remote "{name}" não encontrado`)
	return remote
end

function Remotes.event(name: EventName): RemoteEvent
	return getOrCreate(name, "RemoteEvent") :: RemoteEvent
end

function Remotes.unreliable(name: UnreliableEventName): UnreliableRemoteEvent
	return getOrCreate(name, "UnreliableRemoteEvent") :: UnreliableRemoteEvent
end

return Remotes
