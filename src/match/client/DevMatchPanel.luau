--!strict
-- Seção PARTIDA do painel TESTE (só DEV_, só no place Partida, FASES F3):
--   começar agora, pular rodada, tirar 1 vida de uma dupla, forçar Virada, jogadores de teste
--   (para montar partidas de 4 a 16 com poucos clientes) e recomeçar a partida.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Env = require(Shared.Env)
local MatchTypes = require(Shared.Match.MatchTypes)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Config.Strings)
local TeamColors = require(Shared.Config.TeamColors)
local TextUtil = require(Shared.TextUtil)
local Theme = require(Shared.Config.Theme)

local DevPanelController = require(script.Parent.Parent.Common.DevPanelController)
local MatchClient = require(script.Parent.MatchClient)

local PHASE_NAMES = Strings.Dev.MatchPhases

local DevMatchPanel = {}

function DevMatchPanel.Start()
	if not Env.IsDev or not MatchClient.isEnabled() then
		return
	end
	local command = Remotes.event("DevMatchCommand")
	local result = Remotes.event("DevMatchResult")

	DevPanelController.addSection(function(ui: DevPanelController.SectionUi)
		ui.addTitle(Strings.Dev.MatchTitle)
		local info = ui.addLabel("")

		ui.addButton(Strings.Dev.StartNow, true, function()
			command:FireServer("StartNow")
		end)
		ui.addButton(Strings.Dev.SkipRound, false, function()
			command:FireServer("SkipRound")
		end)
		ui.addButton(Strings.Dev.ForceVirada, false, function()
			command:FireServer("ForceVirada")
		end)

		ui.addLabel(Strings.Dev.RemoveLife)
		local teamGrid = Instance.new("Frame")
		teamGrid.Name = "TeamGrid"
		teamGrid.BackgroundTransparency = 1
		teamGrid.Size = UDim2.fromScale(1, 0)
		teamGrid.AutomaticSize = Enum.AutomaticSize.Y
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(0.5, -Theme.Touch.ButtonGap / 2, 0, Theme.Touch.MinTarget)
		layout.CellPadding = UDim2.fromOffset(Theme.Touch.ButtonGap, Theme.Touch.ButtonGap / 2)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = teamGrid
		ui.addCustom(teamGrid)

		ui.addButton(Strings.Dev.AddBot, false, function()
			command:FireServer("AddBots", 1)
		end)
		ui.addButton(string.format(Strings.Dev.AddBots, 3), false, function()
			command:FireServer("AddBots", 3)
		end)
		ui.addButton(string.format(Strings.Dev.AddBots, 7), false, function()
			command:FireServer("AddBots", 7)
		end)
		ui.addButton(Strings.Dev.ClearBots, false, function()
			command:FireServer("ClearBots")
		end)
		ui.addButton(Strings.Dev.RestartMatch, false, function()
			command:FireServer("Restart")
		end)

		local shownTeams = ""
		MatchClient.onChanged(function(snapshot: MatchTypes.Snapshot)
			local bots = 0
			for _, team in snapshot.teams do
				for _, m in team.members do
					if m.isBot then
						bots += 1
					end
				end
			end
			info.Text = string.format(
				Strings.Dev.MatchInfo,
				PHASE_NAMES[snapshot.phase] or snapshot.phase,
				snapshot.round,
				bots
			) .. `\n{snapshot.waiting} / {snapshot.minPlayers}`

			-- Um botão por dupla viva (recria só quando a lista muda)
			local ids = {}
			for _, team in snapshot.teams do
				if not team.eliminated then
					table.insert(ids, team.id)
				end
			end
			local key = table.concat(ids, ",")
			if key == shownTeams then
				return
			end
			shownTeams = key
			for _, child in teamGrid:GetChildren() do
				if child:IsA("TextButton") then
					child:Destroy()
				end
			end
			for i, id in ids do
				local button = ui.makeButton(TextUtil.upper(Strings.Teams[id] or id), false)
				button.LayoutOrder = i
				button.TextSize = Theme.TextSize.Body
				button.TextColor3 = TeamColors.getColor(id)
				button.Parent = teamGrid
				button.Activated:Connect(function()
					command:FireServer("RemoveLife", id)
				end)
			end
		end)

		result.OnClientEvent:Connect(function(ok: boolean, key: string, detail: string?)
			local message = Strings.Dev.MatchResults[key] or Strings.Dev.MatchResults.Invalid
			if detail then
				message = `{message} {detail}`
			end
			ui.showStatus(ok, message)
		end)
	end)
end

return DevMatchPanel
