--!strict
-- Seção DESEMPENHO do painel TESTE (só DEV_, F10, GDD 13.2): quadros por segundo, modo do mapa
-- (completo ou leve) e quantas peças estão escondidas, mais um botão para alternar a versão leve e
-- comparar no aparelho. É o medidor do teste de 30 fps no celular.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Env = require(Shared.Env)
local Strings = require(Shared.Config.Strings)

local DevPanelController = require(script.Parent.DevPanelController)
local MapDetailLevel = require(script.Parent.MapDetailLevel)

local S = Strings.Dev

local DevPerformancePanel = {}

local function line(stats: MapDetailLevel.Stats): string
	return string.format(
		S.PerformanceLine,
		math.floor(stats.fps + 0.5),
		S.DetailModes[stats.reason] or stats.reason,
		stats.hidden
	)
end

function DevPerformancePanel.Start()
	if not Env.IsDev then
		return
	end
	DevPanelController.addSection(function(ui: DevPanelController.SectionUi)
		ui.addTitle(S.PerformanceTitle)
		local label = ui.addLabel(line(MapDetailLevel.stats()))
		ui.addButton(S.PerformanceForce, false, function()
			MapDetailLevel.toggleForced()
			label.Text = line(MapDetailLevel.stats())
		end)
		MapDetailLevel.onStats(function(stats)
			label.Text = line(stats)
		end)
	end)
end

return DevPerformancePanel
