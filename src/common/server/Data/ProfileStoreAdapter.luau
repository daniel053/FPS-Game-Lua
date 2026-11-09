--!strict
-- Fachada tipada sobre o ProfileStore oficial (vendor/ProfileStore, copiado sem alterações).
-- O resto do jogo NUNCA usa o ProfileStore diretamente: só este módulo, pelo DataService.
--
-- O ProfileStore cuida de:
--   * trava de sessão (o mesmo perfil nunca aberto em dois servidores);
--   * salvamento automático, ao encerrar a sessão e ao fechar o servidor (BindToClose);
--   * repetição com espera crescente quando o DataStore falha.
-- No Studio sem "acesso aos serviços de API" ele usa um armazenamento falso em memória (nada é salvo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DataConfig = require(ReplicatedStorage.Shared.Config.DataConfig)

export type Connection = { Disconnect: (self: Connection) -> () }
export type Signal<T...> = { Connect: (self: Signal<T...>, listener: (T...) -> ()) -> Connection }

export type Session = {
	Data: { [string]: any },
	Key: string,
	IsActive: (self: Session) -> boolean,
	EndSession: (self: Session) -> (),
	Save: (self: Session) -> (),
	AddUserId: (self: Session, userId: number) -> (),
	OnSave: Signal<>,
	OnAfterSave: Signal<any>,
	OnSessionEnd: Signal<>,
}

type RawStore = {
	StartSessionAsync: (self: RawStore, key: string, params: { Cancel: (() -> boolean)? }?) -> Session?,
}

type RawModule = {
	DataStoreState: string,
	IsClosing: boolean,
	New: (name: string, template: { [string]: any }?) -> RawStore,
	SetConstant: (name: string, value: number) -> (),
	OnError: Signal<string, string, string>,
	OnOverwrite: Signal<string, string>,
	OnCriticalToggle: Signal<boolean>,
}

local ProfileStore = (require(ServerStorage.Vendor.ProfileStore) :: any) :: RawModule

-- Números da seção 5 (DataConfig), aplicados uma vez.
ProfileStore.SetConstant("AUTO_SAVE_PERIOD", DataConfig.AutoSaveSeconds)
ProfileStore.SetConstant("FIRST_LOAD_REPEAT", DataConfig.LockFirstRetrySeconds)
ProfileStore.SetConstant("LOAD_REPEAT_PERIOD", DataConfig.LockRetrySeconds)
ProfileStore.SetConstant("SESSION_STEAL", DataConfig.LockTakeoverSeconds)
ProfileStore.SetConstant("ASSUME_DEAD", DataConfig.StaleLockSeconds)

local Adapter = {}

export type Store = {
	-- Abre o perfil com trava. Devolve nil se falhar de vez ou se `cancel()` devolver true.
	startSession: (key: string, cancel: () -> boolean) -> Session?,
}

-- Cria a "loja" de perfis. O template fica vazio: o DataService monta o perfil novo
-- (assim ele sabe quando o perfil é novo e aplica migrações antes de completar campos).
function Adapter.newStore(name: string): Store
	local store = ProfileStore.New(name, {})
	return {
		startSession = function(key: string, cancel: () -> boolean): Session?
			return store:StartSessionAsync(key, { Cancel = cancel })
		end,
	}
end

-- "Access" = salvando de verdade. "NotReady" = ainda verificando. Outros = armazenamento falso (Studio).
function Adapter.getDataStoreState(): string
	return ProfileStore.DataStoreState
end

function Adapter.isClosing(): boolean
	return ProfileStore.IsClosing
end

Adapter.OnError = ProfileStore.OnError
Adapter.OnOverwrite = ProfileStore.OnOverwrite
Adapter.OnCriticalToggle = ProfileStore.OnCriticalToggle

return Adapter
