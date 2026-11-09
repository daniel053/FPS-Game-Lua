--!strict
-- Cópia SOMENTE LEITURA do perfil no cliente (docs/DADOS-JOGADOR.md seção 1.1).
-- O servidor envia o perfil ao carregar e a cada mudança. O cliente nunca escreve no perfil:
-- para mudar configurações, ele PEDE com requestSettings() e o servidor valida.
--
-- Uso:
--   local profile = PlayerDataClient.get()            -- nil enquanto carrega
--   PlayerDataClient.onChanged(function(profile) ... end)
--   PlayerDataClient.requestSettings({ sensitivity = { mouse = 1.5 } })

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local PlayerData = require(Shared.Types.PlayerData)
local Remotes = require(Shared.Remotes)

type Profile = PlayerData.Profile

local PlayerDataClient = {}

local current: Profile? = nil
local changedEvent = Instance.new("BindableEvent")
local settingsResultEvent = Instance.new("BindableEvent")
local settingsRequest: RemoteEvent

-- Congela a tabela inteira: qualquer tentativa de alterar a cópia dá erro (ajuda a achar bugs).
local function deepFreeze(value: any): any
	if typeof(value) == "table" and not table.isfrozen(value) then
		for _, v in value do
			deepFreeze(v)
		end
		table.freeze(value)
	end
	return value
end

function PlayerDataClient.get(): Profile?
	return current
end

-- Chama `callback(perfil)` a cada atualização. Devolve a conexão (Disconnect para parar).
function PlayerDataClient.onChanged(callback: (Profile) -> ()): RBXScriptConnection
	return changedEvent.Event:Connect(callback)
end

-- Resposta aos pedidos de configuração: callback(sucesso, chaveDaMensagem, erroDetalhado?).
function PlayerDataClient.onSettingsResult(callback: (boolean, string, string?) -> ()): RBXScriptConnection
	return settingsResultEvent.Event:Connect(callback)
end

-- Pede ao servidor para mudar configurações. Mandar só os campos que mudaram.
function PlayerDataClient.requestSettings(patch: { [string]: any })
	settingsRequest:FireServer(patch)
end

function PlayerDataClient.Start()
	-- Remotes.event espera o remote existir; por isso fica no Start (Init não pode esperar).
	-- Eventos que chegam antes da conexão ficam na fila do Roblox e não se perdem.
	settingsRequest = Remotes.event("SettingsUpdateRequest")
	Remotes.event("ProfileSnapshot").OnClientEvent:Connect(function(snapshot: Profile)
		current = deepFreeze(snapshot)
		changedEvent:Fire(snapshot)
	end)
	Remotes.event("SettingsUpdateResult").OnClientEvent:Connect(function(ok: boolean, key: string, detail: string?)
		settingsResultEvent:Fire(ok, key, detail)
	end)
end

return PlayerDataClient
