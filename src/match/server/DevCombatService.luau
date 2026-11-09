--!strict
-- Comandos de teste do combate (FASES F2). Só existem no ambiente DEV_.
--   SetWeapon (id)     -> equipa a arma (primária ou pistola, pelo espaço dela)
--   SwitchTeam         -> passa para a outra dupla de teste
--   Heal               -> vida e escudo cheios
--   ToggleDummies      -> alvos andando / parados
--   ExploitStart (n)   -> começa a contar os tiros aceitos; o cliente manda n tiros de uma vez
--   ExploitEnd         -> responde quantos o servidor aceitou

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Env = require(Shared.Env)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Config.Strings)
local WeaponConfig = require(Shared.Config.WeaponConfig)

local CombatService = require(script.Parent.CombatService)
local Combatants = require(script.Parent.Combatants)
local TeamService = require(script.Parent.TeamService)
local TestArenaService = require(script.Parent.TestArenaService)

local COOLDOWN_SECONDS = 0.2
local MAX_EXPLOIT_SHOTS = 50

local DevCombatService = {}

local commandEvent: RemoteEvent
local resultEvent: RemoteEvent
local lastCommandAt: { [Player]: number } = {}

local function reply(player: Player, ok: boolean, messageKey: string, detail: string?)
	resultEvent:FireClient(player, ok, messageKey, detail)
end

local function onCommand(player: Player, command: unknown, arg: unknown)
	local now = os.clock()
	local last = lastCommandAt[player]
	-- O fim do teste de exploit vem logo depois do começo: não entra no limite.
	if command ~= "ExploitEnd" and last and now - last < COOLDOWN_SECONDS then
		return
	end
	lastCommandAt[player] = now

	if command == "SetWeapon" then
		if typeof(arg) ~= "string" or WeaponConfig.get(arg) == nil then
			reply(player, false, "Invalid")
			return
		end
		local ok = CombatService.devSetWeapon(player, arg)
		reply(player, ok, if ok then "WeaponSet" else "NotAlive", Strings.Weapons[arg])
	elseif command == "SwitchTeam" then
		local teamId = TeamService.cycle(player)
		reply(player, true, "TeamSet", Strings.Teams[teamId])
	elseif command == "Heal" then
		local combatant = Combatants.getByPlayer(player)
		if combatant == nil or not combatant.alive then
			reply(player, false, "NotAlive")
			return
		end
		Combatants.revive(combatant)
		reply(player, true, "Healed")
	elseif command == "ToggleDummies" then
		local moving = TestArenaService.toggleDummyMovement()
		reply(player, true, "DummiesToggled", if moving then Strings.Dev.DummiesMoving else Strings.Dev.DummiesStill)
	elseif command == "ExploitStart" then
		if typeof(arg) ~= "number" or arg < 1 or arg > MAX_EXPLOIT_SHOTS then
			reply(player, false, "Invalid")
			return
		end
		CombatService.devWatchExploit(player, math.floor(arg))
	elseif command == "ExploitEnd" then
		local accepted, sent, allowed = CombatService.devFinishExploit(player)
		reply(
			player,
			accepted <= allowed,
			"ExploitResult",
			string.format(Strings.Dev.CombatResults.ExploitDone, accepted, sent, allowed)
		)
	else
		reply(player, false, "Invalid")
	end
end

function DevCombatService.Init()
	if not Env.IsDev then
		return
	end
	commandEvent = Remotes.event("DevCombatCommand")
	resultEvent = Remotes.event("DevCombatResult")
end

function DevCombatService.Start()
	if not Env.IsDev then
		return
	end
	commandEvent.OnServerEvent:Connect(onCommand)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCommandAt[player] = nil
	end)
end

return DevCombatService
