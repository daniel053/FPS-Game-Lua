--!strict
-- Comandos de teste da partida (FASES F3). Só existem no ambiente DEV_.
--   StartNow           -> começa já (mínimo de 2 entre jogadores e jogadores de teste)
--   SkipRound          -> encerra a etapa atual; no combate, decide pelo tempo esgotado (HP + escudo)
--   RemoveLife (dupla) -> tira 1 vida da dupla (entre rodadas na hora; no meio, no fim da rodada)
--   ForceVirada        -> a próxima rodada é a Virada (se ainda não aconteceu)
--   AddBots (n)        -> jogadores de teste (alvos parados) antes de começar
--   ClearBots          -> tira os jogadores de teste
--   Restart            -> encerra a partida sem resultado e volta a esperar jogadores
--   RefillCards        -> cargas cheias e recargas zeradas (F4)
--   HurtSelf           -> leva DevConfig.HurtSelfDamage de dano (testar o Renascer sem outro jogador)
--   CardWatchStart/End -> conta pedidos de carta aceitos e recusados (teste de exploit da F4)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local DevConfig = require(Shared.Config.DevConfig)
local Env = require(Shared.Env)
local MatchConfig = require(Shared.Config.MatchConfig)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Config.Strings)

local CardService = require(script.Parent.CardService)
local Combatants = require(script.Parent.Combatants)
local MatchService = require(script.Parent.MatchService)

local COOLDOWN_SECONDS = 0.3

local DevMatchService = {}

local commandEvent: RemoteEvent
local resultEvent: RemoteEvent
local lastCommandAt: { [Player]: number } = {}

local function reply(player: Player, ok: boolean, key: string, detail: string?)
	resultEvent:FireClient(player, ok, key, detail)
end

local function onCommand(player: Player, command: unknown, arg: unknown)
	local now = os.clock()
	local last = lastCommandAt[player]
	if last and now - last < COOLDOWN_SECONDS then
		return
	end
	lastCommandAt[player] = now

	if command == "StartNow" then
		local ok = MatchService.devStartNow()
		reply(player, ok, if ok then "Started" else "NotEnough")
	elseif command == "SkipRound" then
		local ok = MatchService.devSkip()
		reply(player, ok, if ok then "Skipped" else "WrongPhase")
	elseif command == "RemoveLife" then
		if typeof(arg) ~= "string" then
			reply(player, false, "Invalid")
			return
		end
		local ok, queued = MatchService.devRemoveLife(arg)
		local teamName = string.format(Strings.Match.TeamName, Strings.Teams[arg] or arg)
		reply(player, ok, if ok then (if queued then "LifeQueued" else "LifeRemoved") else "WrongPhase", teamName)
	elseif command == "ForceVirada" then
		local ok = MatchService.devForceVirada()
		reply(player, ok, if ok then "ViradaForced" else "ViradaRefused")
	elseif command == "AddBots" then
		if typeof(arg) ~= "number" or arg < 1 or arg > MatchConfig.Dev.MaxBots then
			reply(player, false, "Invalid")
			return
		end
		local ok = MatchService.devAddBots(math.floor(arg))
		reply(player, ok, if ok then "BotsAdded" else "WrongPhase")
	elseif command == "ClearBots" then
		local ok = MatchService.devClearBots()
		reply(player, ok, if ok then "BotsCleared" else "WrongPhase")
	elseif command == "Restart" then
		local ok = MatchService.devRestart()
		reply(player, ok, if ok then "Restarted" else "WrongPhase")
	elseif command == "RefillCards" then
		local ok = CardService.devRefill(player)
		reply(player, ok, if ok then "CardsRefilled" else "NoCards")
	elseif command == "HurtSelf" then
		-- Leva dano como se fosse um tiro (passa pelo guarda do Renascer); serve para testar sozinho
		local combatant = Combatants.getByPlayer(player)
		if combatant == nil or not combatant.alive then
			reply(player, false, "NotInCombat")
			return
		end
		Combatants.applyDamage(combatant, DevConfig.HurtSelfDamage, { player = nil, weaponId = "dev", at = nil })
		reply(player, true, "SelfHurt")
	elseif command == "CardWatchStart" then
		-- Teste de exploit (F4): o cliente manda pedidos de carta pelo remote real; o servidor conta
		if not CardService.isArmed(player) then
			reply(player, false, "NoCards")
			return
		end
		CardService.devWatchStart(player)
	elseif command == "CardWatchEnd" then
		local accepted, refused = CardService.devWatchEnd(player)
		local sent = if typeof(arg) == "number" then arg else accepted + refused
		reply(player, true, "CardExploitDone", string.format(Strings.Dev.CardExploitDetail, accepted, sent, refused))
	else
		reply(player, false, "Invalid")
	end
end

function DevMatchService.Init()
	if not Env.IsDev or not MatchService.isEnabled() then
		return
	end
	commandEvent = Remotes.event("DevMatchCommand")
	resultEvent = Remotes.event("DevMatchResult")
end

function DevMatchService.Start()
	if not Env.IsDev or not MatchService.isEnabled() then
		return
	end
	commandEvent.OnServerEvent:Connect(onCommand)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCommandAt[player] = nil
	end)
end

return DevMatchService
