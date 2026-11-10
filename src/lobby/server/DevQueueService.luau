--!strict
-- Comandos de teste da fila (FASES F5). Só existem no ambiente DEV_.
--   Info       -> estado da fila neste lobby (líder, fichas, contagem por faixa)
--   ForceStart -> o líder monta já uma partida com quem está na fila (respeita o mínimo de teste)
--   Print      -> lista todas as fichas no Output do servidor

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Env = require(Shared.Env)
local Remotes = require(Shared.Remotes)

local QueueService = require(script.Parent.QueueService)

local COOLDOWN_SECONDS = 1

local DevQueueService = {}

local commandEvent: RemoteEvent
local resultEvent: RemoteEvent
local lastCommandAt: { [Player]: number } = {}

local function reply(player: Player, ok: boolean, key: string, detail: string?)
	resultEvent:FireClient(player, ok, key, detail)
end

local function onCommand(player: Player, command: unknown)
	local now = os.clock()
	local last = lastCommandAt[player]
	if last and now - last < COOLDOWN_SECONDS then
		return
	end
	lastCommandAt[player] = now

	if command == "Info" then
		reply(player, true, "Info", QueueService.devDescribe())
	elseif command == "ForceStart" then
		local ok = QueueService.devForceStart()
		reply(player, ok, if ok then "Forced" else "Failed")
	elseif command == "Print" then
		task.spawn(QueueService.devPrintQueue)
		reply(player, true, "Printed")
	else
		reply(player, false, "Invalid")
	end
end

function DevQueueService.Init()
	if not Env.IsDev then
		return
	end
	commandEvent = Remotes.event("DevQueueCommand")
	resultEvent = Remotes.event("DevQueueResult")
end

function DevQueueService.Start()
	if not Env.IsDev then
		return
	end
	commandEvent.OnServerEvent:Connect(onCommand)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCommandAt[player] = nil
	end)
end

return DevQueueService
