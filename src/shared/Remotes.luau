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

function Remotes.event(name: EventName): RemoteEvent
	local folder = getFolder()

	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end

	local remote = folder:WaitForChild(name, CLIENT_WAIT_TIMEOUT)
	assert(remote and remote:IsA("RemoteEvent"), `Remote "{name}" não encontrado`)
	return remote
end

return Remotes
