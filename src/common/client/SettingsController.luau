--!strict
-- Painel de configurações (ESTILO T6 "Painel P", GDD 13.3), igual no Lobby, na Partida e no Tutorial.
--   * PC: tecla P abre e fecha; controle: direcional para a direita; celular: engrenagem.
--   * Abas: Retícula, Sensibilidade, Áudio, Voz, Acessibilidade e, no toque, Botões (editor de layout).
--   * O jogo NÃO pausa. As mudanças de cada aba são salvas ao trocar de aba ou fechar o painel
--     (pedido normal de configuração, validado no servidor); as escolhas de botão valem na hora.
-- Também aplica o tamanho do texto da interface (settings.uiScale) em todas as telas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local DataConfig = require(Shared.Config.DataConfig)
local PlayerData = require(Shared.Types.PlayerData)
local Strings = require(Shared.Config.Strings)
local TextScale = require(Shared.Ui.TextScale)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.Ui)
local UiConfig = require(Shared.Config.UiConfig)

local InputDevice = require(script.Parent.InputDevice)
local PlayerDataClient = require(script.Parent.PlayerDataClient)
local CrosshairEditor = require(script.Parent.Settings.CrosshairEditor)
local LayoutEditor = require(script.Parent.Settings.LayoutEditor)
local SensitivityPanel = require(script.Parent.Settings.SensitivityPanel)
local VoicePanel = require(script.Parent.Settings.VoicePanel)
local Widgets = require(script.Parent.Ui.Widgets)

local S = Strings.Settings
local KEYS = UiConfig.Keys

type Panel = { commit: () -> (), close: () -> () }

local SettingsController = {}

local player = Players.LocalPlayer
local modal: Widgets.Modal
local tabs: Widgets.Tabs
local content: ScrollingFrame
local gearGui: ScreenGui
local gear: TextButton
local current: Panel? = nil
local listeners: { (boolean) -> () } = {}

local function settings(): PlayerData.Settings?
	local profile = PlayerDataClient.get()
	return if profile then profile.settings else nil
end

local function percent(v: number): string
	return string.format(S.Percent, math.floor(v * 100 + 0.5))
end

local function note(text: string, order: number)
	local l = Ui.paragraph("Note", Theme.Font.Body, Theme.TextSize.Label, Theme.Color.TextSecondary, content)
	l.Text = text
	l.LayoutOrder = order
end

-- Abas -------------------------------------------------------------------------------------------

local function sensitivityTab(): Panel
	local panel = SensitivityPanel.open(content)
	local s = settings()
	if s then
		local device = InputDevice.get()
		if device == "Touch" then
			local autoFire = Widgets.toggle(content, S.AutoFire, s.autoFire, function(on: boolean)
				PlayerDataClient.requestSettings({ autoFire = on })
			end)
			autoFire.frame.LayoutOrder = 10
		end
		if device ~= "KeyboardMouse" then
			local assist = Widgets.toggle(content, S.AimAssist, s.aimAssist, function(on: boolean)
				PlayerDataClient.requestSettings({ aimAssist = on })
			end)
			assist.frame.LayoutOrder = 11
		end
	end
	return panel
end

local function audioTab(): Panel
	local s = settings()
	local working = if s then table.clone(s.audio) else { master = 1, sfx = 1, music = 1, voice = 1 }
	local dirty = false
	local fields =
		{ { "master", S.Audio.Master }, { "sfx", S.Audio.Sfx }, { "music", S.Audio.Music }, { "voice", S.Audio.Voice } }
	for i, field in fields do
		local key, title = field[1], field[2]
		local slider = Widgets.slider(
			content,
			title,
			0,
			1,
			UiConfig.Settings.AudioStep,
			(working :: any)[key],
			percent,
			function(v: number)
				(working :: any)[key] = v
				dirty = true
			end
		)
		slider.frame.LayoutOrder = i
	end
	local function commit()
		if dirty then
			dirty = false
			PlayerDataClient.requestSettings({ audio = table.clone(working) })
		end
	end
	return { commit = commit, close = commit }
end

local function accessibilityTab(): Panel
	local s = settings()
	if s == nil then
		return { commit = function() end, close = function() end }
	end
	local colors = {}
	for _, id in { "red", "yellow", "magenta" } do
		table.insert(colors, { id = id, label = S.EnemyColors[id] })
	end
	Widgets.choice(content, S.EnemyColor, colors, s.enemyOutlineColor, function(id: string)
		PlayerDataClient.requestSettings({ enemyOutlineColor = id })
	end).frame.LayoutOrder =
		1

	local sizes = {}
	for _, value in DataConfig.Limits.UiScaleOptions do
		table.insert(sizes, { id = tostring(value), label = S.TextSizes[tostring(value)] or tostring(value) })
	end
	Widgets.choice(content, S.TextSize, sizes, tostring(s.uiScale), function(id: string)
		local value = tonumber(id)
		if value then
			TextScale.setScale(value) -- prévia na hora; o perfil confirma
			PlayerDataClient.requestSettings({ uiScale = value })
		end
	end).frame.LayoutOrder =
		2

	-- Tamanho do minimapa: o minimapa acompanha o perfil (muda na hora em que o servidor confirma).
	local minimapSizes = {}
	for _, id in UiConfig.Minimap.SizeOrder do
		table.insert(minimapSizes, { id = id, label = S.MinimapSizes[id] or id })
	end
	Widgets.choice(content, S.MinimapSize, minimapSizes, s.minimapSize, function(id: string)
		PlayerDataClient.requestSettings({ minimapSize = id })
	end).frame.LayoutOrder =
		3

	Widgets.toggle(content, S.ReduceEffects, s.reduceEffects, function(on: boolean)
		PlayerDataClient.requestSettings({ reduceEffects = on })
	end).frame.LayoutOrder =
		4

	note(S.Graphics, 5)
	return { commit = function() end, close = function() end }
end

local function buttonsTab(): Panel
	note(S.Buttons.Body, 1)
	local row = Ui.frame("Row", content)
	row.LayoutOrder = 2
	row.Size = UDim2.new(1, 0, 0, Theme.PrimaryButtonMinHeight)
	Ui.list(row, Enum.FillDirection.Horizontal, Theme.Space.Medium)
	local edit =
		Widgets.button(row, S.Buttons.Edit, "primary", { size = UDim2.fromOffset(220, Theme.PrimaryButtonMinHeight) })
	edit.root.Modal = true
	edit.onClick(function()
		SettingsController.close()
		LayoutEditor.open()
	end)
	local reset = Widgets.button(
		row,
		S.Buttons.Reset,
		"secondary",
		{ size = UDim2.fromOffset(220, Theme.PrimaryButtonMinHeight), order = 2 }
	)
	reset.onClick(function()
		PlayerDataClient.requestSettings({ mobileLayout = false })
	end)
	return { commit = function() end, close = function() end }
end

local TAB_BUILDERS: { [string]: () -> Panel } = {
	Crosshair = function()
		return CrosshairEditor.open(content)
	end,
	Sensitivity = sensitivityTab,
	Audio = audioTab,
	Voice = function()
		return VoicePanel.open(content)
	end,
	Accessibility = accessibilityTab,
	Buttons = buttonsTab,
}

local function leaveTab()
	local panel = current
	current = nil
	if panel then
		panel.commit()
	end
	Ui.clear(content)
end

local function showTab(id: string)
	leaveTab()
	local builder = TAB_BUILDERS[id]
	if builder then
		current = builder()
	end
	content.CanvasPosition = Vector2.zero
end

-- Abrir e fechar ----------------------------------------------------------------------------------

function SettingsController.isOpen(): boolean
	return modal ~= nil and modal.isOpen()
end

function SettingsController.open()
	if modal == nil or modal.isOpen() then
		return
	end
	tabs.setVisible("Buttons", InputDevice.get() == "Touch")
	modal.open()
	local selected = tabs.selected()
	if selected == nil then
		tabs.select("Crosshair")
	else
		showTab(selected)
	end
	for _, callback in listeners do
		task.spawn(callback, true)
	end
end

function SettingsController.close()
	if modal then
		modal.close()
	end
end

function SettingsController.toggle()
	if SettingsController.isOpen() then
		SettingsController.close()
	else
		SettingsController.open()
	end
end

-- callback(aberto) a cada abrir/fechar (ex.: soltar o gatilho, esconder o placar).
function SettingsController.onToggled(callback: (boolean) -> ())
	table.insert(listeners, callback)
end

-- No lobby a engrenagem fica na barra do topo (LobbyScreen); nos outros places, no canto superior
-- esquerdo, só no toque (ESTILO T6).
function SettingsController.setOwnGear(enabled: boolean)
	gearGui.Enabled = enabled
end

local function build()
	modal = Widgets.modal("SettingsPanel", 60, {
		title = S.Title,
		maxSize = Vector2.new(760, 620),
	})
	local body = modal.body
	local items = {}
	for _, id in { "Crosshair", "Sensitivity", "Audio", "Voice", "Accessibility", "Buttons" } do
		table.insert(items, { id = id, label = (S.Tabs :: any)[id] })
	end
	tabs = Widgets.tabs(body, items, showTab)
	content = Ui.scroll("Content", Enum.ScrollingDirection.Y, body)
	content.Position = UDim2.fromOffset(0, Theme.Touch.MinTarget + 16)
	content.Size = UDim2.new(1, 0, 1, -(Theme.Touch.MinTarget + 16) - 22)
	local layout = Ui.list(content, Enum.FillDirection.Vertical, Theme.Space.Large)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = content
	local footer = Ui.label("Footer", Theme.Font.Body, Theme.TextSize.Label, Theme.Color.TextSecondary, body)
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Size = UDim2.new(1, 0, 0, 18)
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.Text = S.SavedOnLeave
	modal.onClosed(function()
		leaveTab()
		for _, callback in listeners do
			task.spawn(callback, false)
		end
	end)
	modal.gui.Parent = player:WaitForChild("PlayerGui")

	-- Engrenagem (celular): canto superior esquerdo, abaixo da barra do Roblox
	gearGui = Ui.screen("SettingsGear", 6, Enum.ScreenInsets.CoreUISafeInsets)
	gear = Widgets.iconButton(gearGui, Strings.Ui.Gear, SettingsController.toggle)
	gear.Position = UDim2.fromOffset(Theme.ScreenMargin, Theme.ScreenMargin / 2)
	gear.BackgroundColor3 = Theme.Color.PanelBase
	gear.BackgroundTransparency = Theme.Transparency.PanelBase
	gearGui.Parent = player:WaitForChild("PlayerGui")
end

local function refreshGear()
	gear.Visible = InputDevice.get() == "Touch"
end

function SettingsController.Start()
	build()
	-- No lobby a engrenagem é da barra do topo
	local place = script.Parent.Parent:FindFirstChild("Place")
	SettingsController.setOwnGear(not (place and place:FindFirstChild("LobbyScreen")))
	refreshGear()
	InputDevice.onChanged(function()
		refreshGear()
		if SettingsController.isOpen() then
			tabs.setVisible("Buttons", InputDevice.get() == "Touch")
		end
	end)

	local function applyScale(profile: PlayerData.Profile)
		TextScale.setScale(profile.settings.uiScale)
	end
	local profile = PlayerDataClient.get()
	if profile then
		applyScale(profile)
	end
	PlayerDataClient.onChanged(applyScale)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or LayoutEditor.isOpen() then
			return
		end
		if input.KeyCode == KEYS.Settings or input.KeyCode == KEYS.SettingsPad then
			SettingsController.toggle()
		end
	end)
end

return SettingsController
