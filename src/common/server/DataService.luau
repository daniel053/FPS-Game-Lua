--!strict
-- Perfil do jogador com trava de sessão (docs/DADOS-JOGADOR.md). Roda nos 3 places.
--
-- Só o servidor lê e escreve dados. Toda mudança passa por DataService.update(), que:
--   1. recusa se o perfil não estiver carregado (ou estiver sendo liberado para teleporte);
--   2. roda a função de mudança (as regras ficam em Data/ProfileRules);
--   3. se deu certo, envia ao cliente uma cópia nova (somente leitura).
--
-- Ciclo de vida (seção 5):
--   entrar  -> abre com trava -> migra -> completa e valida -> envia cópia ao cliente
--   jogando -> salvamento automático (DataConfig.AutoSaveSeconds) e saveNow() nos momentos importantes
--   sair    -> salva e libera a trava
--   teleporte -> releaseForTeleportAsync() antes; reopenAfterFailedTeleport() se falhar
--   servidor fechando -> o ProfileStore salva todos (BindToClose)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local DataConfig = require(Shared.Config.DataConfig)
local DefaultProfile = require(Shared.Config.DefaultProfile)
local Env = require(Shared.Env)
local PlayerData = require(Shared.Types.PlayerData)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Config.Strings)

local DataFolder = script.Parent.Data
local Adapter = require(DataFolder.ProfileStoreAdapter)
local Migrations = require(DataFolder.Migrations)
local ProfileSanitizer = require(DataFolder.ProfileSanitizer)

type Profile = PlayerData.Profile

type PlayerState = {
	session: Adapter.Session,
	profile: Profile,
	releasing: boolean, -- liberando para teleporte: não aceita mais mudanças
	endingByUs: boolean, -- nós encerramos a sessão (sair/teleporte), não outro servidor
}

-- Resultado de uma função de mudança: (true) aplicou; (false, motivo) recusou sem mudar nada.
export type Mutator = (profile: Profile) -> (boolean, string?)

local DataService = {}

local store: Adapter.Store
local snapshotEvent: RemoteEvent

local states: { [Player]: PlayerState } = {}
local loading: { [Player]: boolean } = {}
local left: { [Player]: boolean } = {}

local loadedEvent = Instance.new("BindableEvent")
-- Dispara (player) quando o perfil termina de carregar.
DataService.ProfileLoaded = loadedEvent.Event

-- Chamados logo antes de o perfil deixar este servidor (o jogador saiu ou vai ser teleportado), com o
-- perfil ainda aberto: a última chance de gravar algo (ex.: recompensas de quem sai no meio da partida,
-- F9). Não podem esperar (yield): só DataService.update.
local beforeRelease: { (player: Player) -> () } = {}

local function runBeforeRelease(player: Player)
	if states[player] == nil then
		return
	end
	for _, callback in beforeRelease do
		local ok, err = pcall(function(): string?
			callback(player)
			return nil
		end)
		if not ok then
			warn(`[Dados] Erro antes de liberar o perfil de {player.UserId}: {err}`)
		end
	end
end

-- ===== Cópia para o cliente =====

local dirty: { [Player]: boolean } = {}
local flushScheduled = false

local function flushSnapshots()
	flushScheduled = false
	for player in dirty do
		local state = states[player]
		if state and not state.releasing then
			snapshotEvent:FireClient(player, state.profile)
		end
	end
	table.clear(dirty)
end

-- Mudanças feitas no mesmo quadro saem num envio só.
local function markDirty(player: Player)
	dirty[player] = true
	if not flushScheduled then
		flushScheduled = true
		task.defer(flushSnapshots)
	end
end

-- ===== Carregar =====

local function profileKey(player: Player): string
	return DataConfig.ProfileKeyPrefix .. tostring(player.UserId)
end

local function isInGame(player: Player): boolean
	return not left[player] and player.Parent == Players
end

local function kick(player: Player, message: string)
	if isInGame(player) then
		player:Kick(message)
	end
end

local function checkSize(player: Player, profile: Profile)
	local ok, json = pcall(HttpService.JSONEncode, HttpService, profile)
	if ok and #json > DataConfig.MaxProfileBytes then
		warn(`[Dados] Perfil de {player.UserId} com {#json} bytes (limite de aviso: {DataConfig.MaxProfileBytes})`)
	end
end

-- Transforma os dados crus do DataStore no perfil pronto. Nil + erro = não dá para usar este perfil.
local function prepareProfile(raw: { [string]: any }, now: number): (Profile?, string?)
	if next(raw) == nil then
		return DefaultProfile.new(now), nil -- perfil novo
	end
	local ok, migrated = Migrations.run(raw)
	if not ok then
		return nil, `migração falhou: {migrated}`
	end
	local profile, fixes = ProfileSanitizer.sanitize(migrated, now)
	for _, fix in fixes do
		warn(`[Dados] Correção ao carregar: {fix}`)
	end
	return profile, nil
end

local function loadProfile(player: Player)
	if loading[player] or states[player] then
		return
	end
	loading[player] = true

	local started = os.clock()
	local function cancel(): boolean
		if not isInGame(player) then
			return true
		end
		if Env.IsDev and ServerStorage:GetAttribute(DataConfig.DevSimulateLoadFailureAttribute) == true then
			return true -- falha simulada (teste da seção 10)
		end
		return os.clock() - started > DataConfig.LoadTimeoutSeconds
	end

	local session = store.startSession(profileKey(player), cancel)
	loading[player] = nil

	-- Falhou de vez: avisa e manda de volta, SEM criar perfil vazio por cima (seção 5.1.6).
	if session == nil then
		warn(`[Dados] Não foi possível abrir o perfil de {player.UserId}`)
		kick(player, Strings.Data.LoadFailed)
		return
	end

	-- Saiu enquanto carregava.
	if not isInGame(player) then
		session:EndSession()
		return
	end

	local now = os.time()
	local profile, err = prepareProfile(session.Data, now)
	if profile == nil then
		-- Os dados salvos não foram tocados (a migração trabalha numa cópia): liberar sem perder nada.
		warn(`[Dados] Perfil de {player.UserId} não pôde ser preparado: {err}`)
		session:EndSession()
		kick(player, Strings.Data.LoadFailed)
		return
	end

	profile.lastLoginAt = now
	session.Data = profile :: any
	session:AddUserId(player.UserId) -- vínculo do UserId para pedidos de exclusão (seção 9)

	local state: PlayerState = {
		session = session,
		profile = profile,
		releasing = false,
		endingByUs = false,
	}
	states[player] = state

	session.OnSave:Connect(function()
		state.profile.lastSaveAt = os.time()
		checkSize(player, state.profile)
	end)

	-- Outro servidor assumiu a trava (ou o DataStore encerrou a sessão): este servidor para de salvar.
	session.OnSessionEnd:Connect(function()
		if states[player] == state then
			states[player] = nil
		end
		if not state.endingByUs then
			warn(`[Dados] Sessão do perfil de {player.UserId} encerrada por outro servidor`)
			kick(player, Strings.Data.SessionEnded)
		end
	end)

	markDirty(player)
	loadedEvent:Fire(player)
end

local function endSession(player: Player)
	local state = states[player]
	if state then
		runBeforeRelease(player)
		state.endingByUs = true
		states[player] = nil
		state.session:EndSession() -- salva e libera a trava
	end
end

-- ===== API para os outros serviços =====

-- Perfil carregado (nil enquanto carrega ou se está sendo liberado). NÃO alterar direto: use update().
function DataService.getProfile(player: Player): Profile?
	local state = states[player]
	if state == nil or state.releasing then
		return nil
	end
	return state.profile
end

-- Espera o perfil carregar (ou o jogador sair, ou o tempo acabar).
function DataService.waitForProfile(player: Player, timeoutSeconds: number?): Profile?
	local deadline = os.clock() + (timeoutSeconds or DataConfig.LoadTimeoutSeconds + 5)
	while isInGame(player) and os.clock() < deadline do
		local profile = DataService.getProfile(player)
		if profile then
			return profile
		end
		task.wait(0.1)
	end
	return DataService.getProfile(player)
end

-- Única porta de entrada para mudar o perfil. `mutator` não pode esperar (yield).
function DataService.update(player: Player, mutator: Mutator): (boolean, string?)
	local state = states[player]
	if state == nil or state.releasing then
		return false, "NotLoaded"
	end
	local ok, reason = mutator(state.profile)
	if ok then
		markDirty(player)
	end
	return ok, reason
end

-- Registra uma função para rodar antes de o perfil deixar este servidor (ver beforeRelease).
function DataService.onBeforeRelease(callback: (player: Player) -> ())
	table.insert(beforeRelease, callback)
end

-- Salvar já (compra, fim de partida, fim do tutorial — seção 5.2).
function DataService.saveNow(player: Player)
	local state = states[player]
	if state then
		state.session:Save()
	end
end

-- Antes de teleportar (seção 5.3): salva e libera a trava, esperando o DataStore confirmar.
-- Devolve true se liberou a tempo. Em caso de false, não teleportar: chamar reopenAfterFailedTeleport.
function DataService.releaseForTeleportAsync(player: Player): boolean
	local state = states[player]
	if state == nil or state.releasing then
		return false
	end
	runBeforeRelease(player)
	state.releasing = true
	state.endingByUs = true

	local saved = false
	local connection = state.session.OnAfterSave:Connect(function()
		saved = true
	end)
	state.session:EndSession()

	local deadline = os.clock() + DataConfig.TeleportReleaseTimeoutSeconds
	while not saved and os.clock() < deadline do
		task.wait()
	end
	connection:Disconnect()
	if states[player] == state then
		states[player] = nil
	end
	return saved
end

-- O teleporte falhou depois de liberar: abre o perfil de novo neste servidor.
function DataService.reopenAfterFailedTeleport(player: Player)
	if isInGame(player) and states[player] == nil then
		task.spawn(loadProfile, player)
	end
end

-- ===== Só para teste (DEV_) =====

function DataService.devResetProfile(player: Player): boolean
	if not Env.IsDev then
		return false
	end
	local state = states[player]
	if state == nil or state.releasing then
		return false
	end
	local fresh = DefaultProfile.new(os.time())
	state.profile = fresh
	state.session.Data = fresh :: any
	markDirty(player)
	state.session:Save()
	return true
end

-- "Access" = salvando de verdade; outro valor = armazenamento falso do Studio (nada é salvo).
function DataService.getStorageMode(): string
	return Adapter.getDataStoreState()
end

-- ===== Inicialização =====

function DataService.Init()
	store = Adapter.newStore(Env.dataStoreName(DataConfig.ProfileStoreName))
	snapshotEvent = Remotes.event("ProfileSnapshot")
end

function DataService.Start()
	Adapter.OnOverwrite:Connect(function(storeName: string, key: string)
		warn(`[Dados] ATENÇÃO: dado inválido sobrescrito em {storeName}/{key}`)
	end)
	Adapter.OnCriticalToggle:Connect(function(isCritical: boolean)
		if isCritical then
			warn("[Dados] Muitas falhas seguidas do DataStore. Salvamentos serão repetidos.")
		end
	end)

	task.spawn(function()
		while Adapter.getDataStoreState() == "NotReady" do
			task.wait(0.5)
		end
		local mode = Adapter.getDataStoreState()
		if mode == "Access" then
			print(`[Dados] Salvando em {Env.dataStoreName(DataConfig.ProfileStoreName)}`)
		else
			warn(
				`[Dados] Sem acesso ao DataStore ({mode}): NADA será salvo nesta sessão. `
					.. "No Studio: Configurações do jogo › Segurança › Permitir acesso do Studio aos serviços de API."
			)
		end
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		left[player] = nil
		loadProfile(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		left[player] = true
		endSession(player)
		dirty[player] = nil
		-- Libera a referência depois que o carregamento em andamento (se houver) perceber a saída.
		task.delay(DataConfig.LoadTimeoutSeconds + 5, function()
			if player.Parent ~= Players then
				left[player] = nil
			end
		end)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
end

return DataService
