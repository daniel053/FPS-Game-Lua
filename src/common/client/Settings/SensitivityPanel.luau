--!strict
-- Etapa 6 do tutorial (GDD 5.2): sensibilidade da mira, com prévia na hora (AimCamera.setPreview).
-- Um controle para o aparelho em uso (toque, mouse ou controle) e outro para a mira aberta.
-- Salvar manda o pedido normal de configuração (SettingsUpdateRequest, validado no servidor).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local DataConfig = require(Shared.Config.DataConfig)
local PlayerData = require(Shared.Types.PlayerData)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local UiConfig = require(Shared.Config.UiConfig)
local Ui = require(Shared.Ui.Ui)

local AimCamera = require(script.Parent.Parent.AimCamera)
local InputDevice = require(script.Parent.Parent.InputDevice)
local PlayerDataClient = require(script.Parent.Parent.PlayerDataClient)
local Widgets = require(script.Parent.Parent.Ui.Widgets)

local S = Strings.Tutorial.Sensitivity
local LIMITS = DataConfig.Limits

export type Panel = { commit: () -> (), close: () -> () }

local SensitivityPanel = {}

local DEVICE_FIELD = { Touch = "touch", KeyboardMouse = "mouse", Gamepad = "gamepad" }

local function format(v: number): string
	return string.format("%.2f", v)
end

function SensitivityPanel.open(container: GuiObject): Panel
	local profile = PlayerDataClient.get()
	local saved: PlayerData.SensitivitySettings = if profile
		then table.clone(profile.settings.sensitivity)
		else { touch = 1, mouse = 1, gamepad = 1, scopedMultiplier = 0.8 }
	local working = table.clone(saved)
	local device = InputDevice.get()
	local field = DEVICE_FIELD[device] or "mouse"

	local body = Ui.label("Body", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary, container)
	body.Size = UDim2.new(1, 0, 0, 60)
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Text = S.Body
	body.LayoutOrder = 1

	local function apply()
		AimCamera.setPreview(working)
	end

	local main = Widgets.slider(
		container,
		S.Device[device] or S.Device.KeyboardMouse,
		LIMITS.Sensitivity.Min,
		LIMITS.Sensitivity.Max,
		UiConfig.Settings.SliderStep,
		(working :: any)[field],
		format,
		function(v: number)
			(working :: any)[field] = v
			apply()
		end
	)
	main.frame.LayoutOrder = 2

	local scoped = Widgets.slider(
		container,
		S.Scoped,
		LIMITS.ScopedMultiplier.Min,
		LIMITS.ScopedMultiplier.Max,
		UiConfig.Settings.SliderStep,
		working.scopedMultiplier,
		format,
		function(v: number)
			working.scopedMultiplier = v
			apply()
		end
	)
	scoped.frame.LayoutOrder = 3

	apply()
	return {
		commit = function()
			local patch: { [string]: any } = { scopedMultiplier = working.scopedMultiplier }
			patch[field] = (working :: any)[field]
			if
				working.scopedMultiplier == saved.scopedMultiplier
				and (working :: any)[field] == (saved :: any)[field]
			then
				AimCamera.setPreview(nil) -- nada mudou
				return
			end
			PlayerDataClient.requestSettings({ sensitivity = patch })
			-- A prévia sai quando o perfil salvo chegar (com os mesmos valores)
			task.delay(3, function()
				AimCamera.setPreview(nil)
			end)
		end,
		close = function()
			AimCamera.setPreview(nil)
		end,
	}
end

return SensitivityPanel
