--!strict
-- Seção COMBATE do painel TESTE (só DEV_, só no place Partida): escolher qualquer uma das 18 armas,
-- trocar de dupla, vida cheia, alvos andando/parados e o teste de exploit de cadência.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local Env = require(Shared.Env)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Config.Strings)
local TextUtil = require(Shared.TextUtil)
local Theme = require(Shared.Config.Theme)
local WeaponConfig = require(Shared.Config.WeaponConfig)

local DevPanelController = require(script.Parent.Parent.Common.DevPanelController)
local WeaponController = require(script.Parent.WeaponController)

local EXPLOIT_SHOTS = 20

local DevCombatPanel = {}

function DevCombatPanel.Start()
	if not Env.IsDev then
		return
	end
	local command = Remotes.event("DevCombatCommand")
	local result = Remotes.event("DevCombatResult")
	local player = Players.LocalPlayer

	DevPanelController.addSection(function(ui: DevPanelController.SectionUi)
		ui.addTitle(Strings.Dev.CombatTitle)
		local info = ui.addLabel("")
		local function refreshInfo()
			local teamId = player:GetAttribute(CombatNames.Attr.TeamId)
			local kills = player:GetAttribute(CombatNames.Attr.Kills)
			info.Text = string.format(
				Strings.Dev.CombatInfo,
				if typeof(teamId) == "string" then (Strings.Teams :: any)[teamId] or teamId else "-",
				if typeof(kills) == "number" then kills else 0
			)
		end
		refreshInfo()
		player:GetAttributeChangedSignal(CombatNames.Attr.TeamId):Connect(refreshInfo)
		player:GetAttributeChangedSignal(CombatNames.Attr.Kills):Connect(refreshInfo)

		local testArena = CombatConfig.TestArena.Enabled
		if testArena then
			ui.addButton(Strings.Dev.SwitchTeam, false, function()
				command:FireServer("SwitchTeam")
			end)
		end
		ui.addButton(Strings.Dev.Heal, false, function()
			command:FireServer("Heal")
		end)
		if testArena then
			ui.addButton(Strings.Dev.DummiesMoving .. " / " .. Strings.Dev.DummiesStill, false, function()
				command:FireServer("ToggleDummies")
			end)
		end
		ui.addButton(Strings.Dev.ExploitTest, false, function()
			command:FireServer("ExploitStart", EXPLOIT_SHOTS)
			WeaponController.devRapidFire(EXPLOIT_SHOTS)
			task.wait(0.5)
			command:FireServer("ExploitEnd")
		end)

		ui.addTitle(Strings.Dev.WeaponsTitle)
		local grid = Instance.new("Frame")
		grid.Name = "WeaponGrid"
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.fromScale(1, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(0.5, -Theme.Touch.ButtonGap / 2, 0, Theme.Touch.MinTarget)
		layout.CellPadding = UDim2.fromOffset(Theme.Touch.ButtonGap, Theme.Touch.ButtonGap / 2)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		for i, def in WeaponConfig.Weapons do
			local button = ui.makeButton(TextUtil.upper(Strings.Weapons[def.id] or def.id), false)
			button.LayoutOrder = i
			button.TextSize = Theme.TextSize.Body
			button.Parent = grid
			button.Activated:Connect(function()
				command:FireServer("SetWeapon", def.id)
			end)
		end
		ui.addCustom(grid)

		result.OnClientEvent:Connect(function(ok: boolean, key: string, detail: string?)
			local message = Strings.Dev.CombatResults[key] or Strings.Dev.CombatResults.Invalid
			if detail then
				message = `{message} {detail}`
			end
			ui.showStatus(ok, message)
		end)
	end)
end

return DevCombatPanel
