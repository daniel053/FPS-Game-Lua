--!strict
-- Seção FILA do painel TESTE (só DEV_, só no Lobby, FASES F5): estado da fila, "começar já com quem
-- está na fila" (para testar com 2 contas sem esperar os 60 s) e a lista de fichas no Output.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Env = require(Shared.Env)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Config.Strings)

local DevPanelController = require(script.Parent.Parent.Common.DevPanelController)

local R = Strings.Dev.QueueResults

local DevQueuePanel = {}

function DevQueuePanel.Start()
	if not Env.IsDev then
		return
	end
	local command = Remotes.event("DevQueueCommand")
	local result = Remotes.event("DevQueueResult")

	DevPanelController.addSection(function(ui: DevPanelController.SectionUi)
		ui.addTitle(Strings.Dev.QueueTitle)
		local info = ui.addLabel("")
		ui.addButton(Strings.Dev.QueueRefresh, false, function()
			command:FireServer("Info")
		end)
		ui.addButton(Strings.Dev.QueueForceStart, true, function()
			command:FireServer("ForceStart")
		end)
		ui.addButton(Strings.Dev.QueuePrint, false, function()
			command:FireServer("Print")
		end)

		result.OnClientEvent:Connect(function(ok: boolean, key: string, detail: string?)
			if key == "Info" then
				info.Text = detail or ""
				return
			end
			ui.showStatus(ok, R[key] or R.Invalid)
		end)
		command:FireServer("Info")
	end)
end

return DevQueuePanel
