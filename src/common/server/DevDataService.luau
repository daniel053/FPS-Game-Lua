--!strict
-- Comandos de teste dos dados (FASES F1). Só existem no ambiente DEV_.
--   AddCoins     -> +DataConfig.DevAddCoinsAmount moedas (pelo EconomyService, como no jogo real)
--   ResetProfile -> perfil volta ao padrão (o cliente pede confirmação antes)
--   ShowProfile  -> perfil completo no Output do servidor + resumo na tela
--   GrantStarterCards -> as 4 cartas iniciais (F4; o tutorial da F6 entrega de verdade)
--   TutorialReset    -> tutorial pendente desde a etapa 1 (no lobby publicado, leva ao tutorial)
--   TutorialComplete -> tutorial feito, com as 4 cartas (pular o tutorial nos testes)
--   ClearCards   -> tira todas as cartas (testar a partida sem carta)
--   RankUp / RankDown -> ± DataConfig.DevRankStep PE (F9), gravado no ranking
--   RankReset    -> PE e partidas ranqueadas a zero (testar a proteção das primeiras partidas)
--   SimulateMatch -> uma partida de 8 duplas com colocação sorteada: moedas e elo pelo caminho real
--   ResetFirstWin -> a "primeira vitória do dia" volta a valer hoje
--   ClearSkins   -> tira todas as skins (testar comprar de novo)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CardConfig = require(Shared.Config.CardConfig)
local DataConfig = require(Shared.Config.DataConfig)
local EconomyRules = require(Shared.Progression.EconomyRules)
local Env = require(Shared.Env)
local Remotes = require(Shared.Remotes)
local TutorialConfig = require(Shared.Config.TutorialConfig)

local Common = script.Parent
local DataService = require(Common.DataService)
local EconomyService = require(Common.EconomyService)
local ProfileRules = require(Common.Data.ProfileRules)
local RankService = require(Common.RankService)

local COOLDOWN_SECONDS = 0.5

local DevDataService = {}

local commandEvent: RemoteEvent
local resultEvent: RemoteEvent
local lastCommandAt: { [Player]: number } = {}

local function reply(player: Player, ok: boolean, messageKey: string, detail: string?)
	resultEvent:FireClient(player, ok, messageKey, detail)
end

local function onCommand(player: Player, command: unknown)
	local now = os.clock()
	local last = lastCommandAt[player]
	if last and now - last < COOLDOWN_SECONDS then
		return
	end
	lastCommandAt[player] = now

	if command == "AddCoins" then
		local ok = EconomyService.addCoins(player, DataConfig.DevAddCoinsAmount, "dev")
		reply(player, ok, if ok then "CoinsAdded" else "NotLoaded")
	elseif command == "GrantStarterCards" then
		-- Até o tutorial existir (F6): as 4 cartas iniciais pela regra real (uma por tecla)
		local _, reason = DataService.update(player, function(profile)
			local changed = false
			for _, id in CardConfig.StarterCards do
				if ProfileRules.grantCard(profile, id, "admin", os.time()) then
					changed = true
				end
			end
			return changed, nil
		end)
		local loaded = reason ~= "NotLoaded"
		reply(player, loaded, if loaded then "CardsGranted" else "NotLoaded")
	elseif command == "TutorialReset" then
		local ok = DataService.update(player, function(profile)
			profile.tutorialDone = false
			profile.tutorialStep = 0
			return true, nil
		end)
		reply(player, ok, if ok then "TutorialReset" else "NotLoaded")
	elseif command == "TutorialComplete" then
		local ok = DataService.update(player, function(profile)
			for _, id in CardConfig.StarterCards do
				ProfileRules.grantCard(profile, id, "admin", os.time())
			end
			profile.tutorialDone = true
			profile.tutorialStep = #TutorialConfig.Steps
			return true, nil
		end)
		reply(player, ok, if ok then "TutorialCompleted" else "NotLoaded")
	elseif command == "ClearCards" then
		local ok = DataService.update(player, function(profile)
			profile.cards.owned = {}
			profile.loadout.lastCard = nil
			return true, nil
		end)
		reply(player, ok, if ok then "CardsCleared" else "NotLoaded")
	elseif command == "RankUp" or command == "RankDown" then
		local amount = if command == "RankUp" then DataConfig.DevRankStep else -DataConfig.DevRankStep
		local ok = RankService.devAddPoints(player, amount)
		reply(player, ok, if ok then "RankChanged" else "NotLoaded")
	elseif command == "RankReset" then
		local ok = RankService.devReset(player)
		reply(player, ok, if ok then "RankReset" else "NotLoaded")
	elseif command == "SimulateMatch" then
		-- Uma partida de 8 duplas com colocação sorteada, pelo caminho real (EconomyRules, RankService)
		local profile = DataService.getProfile(player)
		if profile == nil then
			reply(player, false, "NotLoaded")
			return
		end
		local rng = Random.new()
		local placement = rng:NextInteger(1, 8)
		local roundsPlayed = 9 - placement
		local tally = {
			roundsPlayed = roundsPlayed,
			roundsWon = math.max(0, roundsPlayed - 2),
			kills = rng:NextInteger(0, 6),
		}
		local today = os.time()
		local coins = EconomyRules.matchCoins(tally, {
			placement = placement,
			samePartner = true,
			isPrivate = false,
			firstWinAvailable = EconomyService.firstWinAvailable(player, today) == true,
		})
		EconomyService.creditMatch(player, coins, today)
		local rank = RankService.applyMatch(player, { placement = placement, teamCount = 8 }, false)
		DataService.saveNow(player)
		reply(
			player,
			true,
			"MatchSimulated",
			string.format(
				"%dº de 8 · +%d moedas · %+d PE (%s)%s",
				placement,
				coins.total,
				if rank then rank.delta else 0,
				if rank then rank.tier else "?",
				if rank and rank.protected then " · sem perda (primeiras partidas)" else ""
			)
		)
	elseif command == "ResetFirstWin" then
		local ok = DataService.update(player, function(profile)
			profile.daily.lastFirstWinDay = nil
			return true, nil
		end)
		reply(player, ok, if ok then "FirstWinReset" else "NotLoaded")
	elseif command == "ClearSkins" then
		local ok = DataService.update(player, function(profile)
			profile.cosmetics.owned = {}
			profile.cosmetics.equipped.weapons = {}
			profile.cosmetics.equipped.melee = nil
			return true, nil
		end)
		reply(player, ok, if ok then "SkinsCleared" else "NotLoaded")
	elseif command == "ResetProfile" then
		local ok = DataService.devResetProfile(player)
		reply(player, ok, if ok then "ProfileReset" else "NotLoaded")
	elseif command == "ShowProfile" then
		local profile = DataService.getProfile(player)
		if profile == nil then
			reply(player, false, "NotLoaded")
			return
		end
		local json = HttpService:JSONEncode(profile)
		print(`[Dados] Perfil de {player.Name} ({player.UserId}), {#json} bytes:\n{json}`)
		local cardCount = 0
		for _ in profile.cards.owned do
			cardCount += 1
		end
		local detail = string.format(
			"moedas %d · PE %d (%d ranqueadas) · cartas %d · tutorial %s (etapa %d) · %d bytes · armazenamento: %s",
			profile.coins,
			profile.rank.points,
			profile.rank.matchesPlayed,
			cardCount,
			if profile.tutorialDone then "feito" else "pendente",
			profile.tutorialStep,
			#json,
			DataService.getStorageMode()
		)
		reply(player, true, "ProfileShown", detail)
	else
		reply(player, false, "Invalid")
	end
end

function DevDataService.Init()
	if not Env.IsDev then
		return
	end
	commandEvent = Remotes.event("DevDataCommand")
	resultEvent = Remotes.event("DevDataResult")
end

function DevDataService.Start()
	if not Env.IsDev then
		return
	end
	commandEvent.OnServerEvent:Connect(onCommand)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCommandAt[player] = nil
	end)
end

return DevDataService
