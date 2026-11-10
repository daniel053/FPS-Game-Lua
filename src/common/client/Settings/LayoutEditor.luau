--!strict
-- Editor de posição e tamanho dos botões de toque (GDD 13.1 [PROPOSTA], FASES F7).
-- Tela cheia sobre o jogo, só no celular: cada botão de combate (ATIRAR, MIRA, 1⇄2, RECARREGAR e as
-- cartas Q, E, C, X) aparece no lugar atual; arrastar move, tocar seleciona e − / + mudam o tamanho.
-- SALVAR manda settings.mobileLayout (posição relativa do centro + escala), validado no servidor.
-- PADRÃO volta todos ao layout padrão; CANCELAR descarta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local DataConfig = require(Shared.Config.DataConfig)
local PlayerData = require(Shared.Types.PlayerData)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local TouchLayout = require(Shared.Ui.TouchLayout)
local Ui = require(Shared.Ui.Ui)
local UiConfig = require(Shared.Config.UiConfig)

local PlayerDataClient = require(script.Parent.Parent.PlayerDataClient)
local Widgets = require(script.Parent.Parent.Ui.Widgets)

local L = Strings.LayoutEditor
local SCALE = DataConfig.Limits.MobileButtonScale

type Entry = { x: number, y: number, scale: number }

local LayoutEditor = {}

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local area: Frame
local ghosts: { [string]: TextButton } = {}
local working: { [string]: Entry } = {}
local selected: string? = nil
local sizeLabel: TextLabel
local opened = false

local function viewport(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(800, 400)
end

-- Posição e tamanho atuais de um botão (o que está no working, ou o padrão).
local function placementOf(id: string): TouchLayout.Placement
	local entry = working[id]
	local base = TouchLayout.default(id, viewport())
	if entry then
		return { position = UDim2.fromScale(entry.x, entry.y), size = math.floor(base.size * entry.scale + 0.5) }
	end
	return base
end

local function ensureEntry(id: string): Entry
	local entry = working[id]
	if entry == nil then
		local rel = TouchLayout.toRelative(TouchLayout.default(id, viewport()).position, area.AbsoluteSize)
		entry = { x = rel.X, y = rel.Y, scale = 1 }
		working[id] = entry
	end
	return entry
end

local function render()
	for id, ghost in ghosts do
		local p = placementOf(id)
		ghost.Position = p.position
		ghost.Size = UDim2.fromOffset(p.size, p.size)
		local stroke = ghost:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if id == selected then Theme.LayoutEditor.GhostSelected else Theme.Color.PanelBorder
			stroke.Thickness = if id == selected then 3 else 2
		end
	end
	local entry = selected and working[selected]
	sizeLabel.Text = string.format(L.Size, math.floor((if entry then entry.scale else 1) * 100 + 0.5))
end

local function changeScale(delta: number)
	if selected == nil then
		return
	end
	local entry = ensureEntry(selected)
	entry.scale = math.clamp(math.floor((entry.scale + delta) * 100 + 0.5) / 100, SCALE.Min, SCALE.Max)
	render()
end

local function close()
	opened = false
	if gui then
		gui.Enabled = false
	end
end

local function save()
	local layout: PlayerData.MobileButtonLayout = {}
	local count = 0
	for id, entry in working do
		layout[id] = { x = entry.x, y = entry.y, scale = entry.scale }
		count += 1
	end
	PlayerDataClient.requestSettings({ mobileLayout = if count > 0 then layout else false })
	close()
end

local function makeGhost(id: string)
	local ghost = Instance.new("TextButton")
	ghost.Name = id
	ghost.AnchorPoint = Vector2.new(0.5, 0.5)
	ghost.AutoButtonColor = false
	ghost.BackgroundColor3 = Theme.LayoutEditor.Ghost
	ghost.BackgroundTransparency = Theme.LayoutEditorGhostTransparency
	ghost.FontFace = Theme.Font.Title
	ghost.TextSize = Theme.TextSize.Label
	ghost.TextColor3 = Theme.Color.TextPrimary
	ghost.TextWrapped = true
	ghost.Text = L.Names[id] or id
	Ui.corner(ghost, 999)
	Ui.stroke(ghost, Theme.Color.PanelBorder, 2)
	ghost.Parent = area
	ghosts[id] = ghost

	local dragging: InputObject? = nil
	ghost.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			dragging = input
			selected = id
			render()
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging == nil or not opened then
			return
		end
		local t = input.UserInputType
		local isTouch = t == Enum.UserInputType.Touch and input == dragging
		if not (isTouch or t == Enum.UserInputType.MouseMovement) then
			return
		end
		local size = area.AbsoluteSize
		local rel = (Vector2.new(input.Position.X, input.Position.Y) - area.AbsolutePosition)
			/ Vector2.new(math.max(size.X, 1), math.max(size.Y, 1))
		local entry = ensureEntry(id)
		entry.x = math.clamp(rel.X, 0, 1)
		entry.y = math.clamp(rel.Y, 0, 1)
		render()
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = nil
		end
	end)
end

local function build()
	local g = Ui.screen("LayoutEditor", 80, Enum.ScreenInsets.DeviceSafeInsets)
	g.IgnoreGuiInset = false -- mesma área dos botões de toque do combate
	g.Enabled = false
	gui = g

	local dim = Ui.frame("Dim", g)
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Theme.Color.Overlay
	dim.BackgroundTransparency = Theme.Transparency.Overlay
	dim.Active = true

	area = Ui.frame("Area", g)
	area.Size = UDim2.fromScale(1, 1)
	for _, id in TouchLayout.ButtonIds do
		makeGhost(id)
	end

	-- Barra de cima: dica, tamanho do selecionado e botões
	local bar, barContent = Ui.panel("Bar", g, Theme.Space.Medium)
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, Theme.ScreenMargin)
	local barHeight = 20 + 2 * Theme.Touch.MinTarget + 3 * Theme.Space.Small + 2 * Theme.Space.Medium + 4
	bar.Size = UDim2.new(0.6, 0, 0, barHeight)
	Ui.sizeLimit(bar, Vector2.new(380, barHeight), Vector2.new(560, barHeight))
	local hint = Ui.label("Hint", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, barContent)
	hint.Size = UDim2.new(1, 0, 0, 20)
	hint.Text = L.Hint
	hint.TextWrapped = true

	local function makeRow(y: number): Frame
		local r = Ui.frame("Row", barContent)
		r.Position = UDim2.fromOffset(0, y)
		r.Size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget)
		local layout = Ui.list(r, Enum.FillDirection.Horizontal, Theme.Space.Small)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		return r
	end
	local row = makeRow(20 + Theme.Space.Small)
	local actions = makeRow(20 + 2 * Theme.Space.Small + Theme.Touch.MinTarget)
	local minus = Widgets.iconButton(row, L.Smaller, function()
		changeScale(-UiConfig.LayoutEditor.ScaleStep)
	end)
	minus.LayoutOrder = 1
	minus.Modal = true
	sizeLabel = Ui.label("Size", Theme.Font.Number, Theme.TextSize.Body, Theme.Color.TextPrimary, row)
	sizeLabel.Size = UDim2.fromOffset(110, Theme.Touch.MinTarget)
	sizeLabel.LayoutOrder = 2
	local plus = Widgets.iconButton(row, L.Bigger, function()
		changeScale(UiConfig.LayoutEditor.ScaleStep)
	end)
	plus.LayoutOrder = 3
	local small = UDim2.fromOffset(110, Theme.Touch.MinTarget)
	local reset =
		Widgets.button(actions, L.Reset, "secondary", { size = small, textSize = Theme.TextSize.Body, order = 4 })
	reset.onClick(function()
		table.clear(working)
		render()
	end)
	local cancel =
		Widgets.button(actions, L.Cancel, "secondary", { size = small, textSize = Theme.TextSize.Body, order = 5 })
	cancel.onClick(close)
	local saveButton =
		Widgets.button(actions, L.Save, "primary", { size = small, textSize = Theme.TextSize.Body, order = 6 })
	saveButton.onClick(save)

	g.Parent = player:WaitForChild("PlayerGui")
end

function LayoutEditor.isOpen(): boolean
	return opened
end

function LayoutEditor.open()
	if gui == nil then
		build()
	end
	table.clear(working)
	local profile = PlayerDataClient.get()
	local saved = profile and profile.settings.mobileLayout
	if saved then
		for id, entry in saved do
			working[id] = { x = entry.x, y = entry.y, scale = entry.scale }
		end
	end
	selected = TouchLayout.ButtonIds[1]
	opened = true
	if gui then
		gui.Enabled = true
	end
	render()
end

return LayoutEditor
