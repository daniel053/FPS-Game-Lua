--!strict
-- Estado do tutorial vindo do servidor (TutorialState) e pedidos (TutorialRequest).
-- O cliente só mostra e pede; quem decide é o TutorialService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local TutorialTypes = require(Shared.Tutorial.TutorialTypes)

type Snapshot = TutorialTypes.Snapshot

local TutorialClient = {}

local current: Snapshot? = nil
local listeners: { (Snapshot) -> () } = {}
local requestEvent: RemoteEvent

function TutorialClient.get(): Snapshot?
	return current
end

function TutorialClient.onChanged(callback: (Snapshot) -> ())
	table.insert(listeners, callback)
	if current then
		task.spawn(callback, current)
	end
end

function TutorialClient.request(name: TutorialTypes.RequestName)
	requestEvent:FireServer(name)
end

function TutorialClient.Init()
	requestEvent = Remotes.event("TutorialRequest")
end

function TutorialClient.Start()
	Remotes.event("TutorialState").OnClientEvent:Connect(function(snapshot: Snapshot)
		current = snapshot
		for _, callback in listeners do
			task.spawn(callback, snapshot)
		end
	end)
end

return TutorialClient
