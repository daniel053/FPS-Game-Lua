--!strict
-- Painel de teleporte de teste (FASES F0). Só aparece no ambiente DEV_.
--   Celular: botão "TESTE" na tela.
--   PC: tecla T (o atalho fica escrito no botão). Com o painel aberto o mouse fica livre.
--   Controle: direcional para cima; o painel abre com o primeiro botão selecionado.
-- Visual simples de ferramenta de teste; a interface final é da F7.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Env = require(Shared.Env)
local Remotes = require(Shared.Remotes)
local DevConfig = require(Shared.Config.DevConfig)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local Types = require(Shared.Types)

local DevPanelController = {}

local player = Players.LocalPlayer

local panel: Frame
local statusLabel: TextLabel
local toggleButton: TextButton
local keyHint: TextLabel
local firstPlaceButton: TextButton?

local function addCorner(parent: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.SmallCardCornerRadius)
	corner.Parent = parent
end

local function addStroke(parent: GuiObject)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.PanelBorder
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

local function makeButton(text: string, isPrimary: boolean): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.Size = UDim2.new(1, 0, 0, Theme.PrimaryButtonMinHeight)
	button.BackgroundColor3 = if isPrimary then Theme.Color.Accent else Theme.Color.PanelRaised
	button.FontFace = Theme.Font.Title
	button.TextSize = Theme.TextSize.PrimaryButton
	button.TextColor3 = Theme.Color.TextPrimary
	button.Text = text
	addCorner(button)
	if not isPrimary then
		addStroke(button)
	end
	return button
end

local function makeLabel(text: string, font: Font, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, size + 8)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	label.FontFace = font
	label.TextSize = size
	label.TextColor3 = color
	label.Text = text
	return label
end

local function setOpen(open: boolean)
	panel.Visible = open
	if open then
		statusLabel.Text = ""
		if UserInputService.GamepadEnabled and firstPlaceButton then
			GuiService.SelectedObject = firstPlaceButton
		end
	elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then
		GuiService.SelectedObject = nil
	end
end

local function toggle()
	setOpen(not panel.Visible)
end

-- Mostra o atalho só para quem usa teclado ou controle (no toque, o próprio botão basta).
local function refreshKeyHint()
	local lastInput = UserInputService:GetLastInputType()
	if lastInput == Enum.UserInputType.Touch then
		keyHint.Visible = false
	elseif lastInput.Name:find("Gamepad") then
		keyHint.Visible = true
		keyHint.Text = Strings.Dev.GamepadHint
	else
		keyHint.Visible = true
		keyHint.Text = DevConfig.PanelToggleKey.Name
	end
end

local function build(requestEvent: RemoteEvent)
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "DevPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Botão de abrir (canto superior esquerdo, abaixo da barra do Roblox)
	toggleButton = makeButton(Strings.Dev.ToggleButton, false)
	toggleButton.Name = "Toggle"
	toggleButton.AnchorPoint = Vector2.new(0, 0)
	toggleButton.Position = UDim2.fromOffset(Theme.ScreenMargin, Theme.ScreenMargin)
	toggleButton.Size = UDim2.fromOffset(120, Theme.Touch.MinTarget)
	toggleButton.TextSize = Theme.TextSize.Body
	toggleButton.BackgroundTransparency = Theme.Transparency.PanelBase
	toggleButton.Parent = gui
	toggleButton.Activated:Connect(toggle)

	-- Chip de tecla (ESTILO 2.5)
	keyHint = Instance.new("TextLabel")
	keyHint.Name = "KeyHint"
	keyHint.AnchorPoint = Vector2.new(1, 0.5)
	keyHint.Position = UDim2.new(1, -8, 0.5, 0)
	keyHint.Size = UDim2.fromOffset(24, 24)
	keyHint.BackgroundColor3 = Theme.Color.PanelRaised
	keyHint.FontFace = Theme.Font.Title
	keyHint.TextSize = Theme.TextSize.Label
	keyHint.TextColor3 = Theme.Color.TextSecondary
	keyHint.Parent = toggleButton
	addCorner(keyHint)
	local chipStroke = Instance.new("UIStroke")
	chipStroke.Color = Theme.Color.TextSecondary
	chipStroke.Thickness = 1
	chipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	chipStroke.Parent = keyHint

	-- Painel (modal leve; o jogo continua visível atrás)
	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Visible = false
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Theme.Color.PanelBase
	panel.BackgroundTransparency = Theme.Transparency.PanelBase
	panel.Parent = gui
	addCorner(panel)
	addStroke(panel)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(360, math.huge)
	sizeLimit.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, Theme.ScreenMargin)
	padding.PaddingBottom = UDim.new(0, Theme.ScreenMargin)
	padding.PaddingLeft = UDim.new(0, Theme.ScreenMargin)
	padding.PaddingRight = UDim.new(0, Theme.ScreenMargin)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, Theme.Touch.ButtonGap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local title = makeLabel(Strings.Dev.PanelTitle, Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary)
	title.LayoutOrder = nextOrder()
	title.Parent = panel

	local current = Env.getCurrentPlace()
	local currentName = if current then Strings.Places[current] else Strings.Dev.UnknownPlace
	local subtitle = makeLabel(
		string.format(Strings.Dev.CurrentPlace, currentName),
		Theme.Font.Body,
		Theme.TextSize.Body,
		Theme.Color.TextSecondary
	)
	subtitle.LayoutOrder = nextOrder()
	subtitle.Parent = panel

	for _, placeName: Types.PlaceName in Env.PlaceNames do
		if placeName == current then
			continue
		end
		local label = string.format(Strings.Dev.GoTo, string.upper(Strings.Places[placeName]))
		local button = makeButton(label, true)
		button.Name = `GoTo{placeName}`
		button.LayoutOrder = nextOrder()
		button.Parent = panel
		button.Activated:Connect(function()
			statusLabel.Text = ""
			requestEvent:FireServer(placeName)
		end)
		if firstPlaceButton == nil then
			firstPlaceButton = button
		end
	end

	statusLabel = makeLabel("", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary)
	statusLabel.Name = "Status"
	statusLabel.LayoutOrder = nextOrder()
	statusLabel.Parent = panel

	local closeButton = makeButton(Strings.Dev.Close, false)
	closeButton.Name = "Close"
	-- Modal = true libera o mouse da primeira pessoa enquanto o painel está aberto (PC).
	closeButton.Modal = true
	closeButton.LayoutOrder = nextOrder()
	closeButton.Parent = panel
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)

	gui.Parent = playerGui
end

function DevPanelController.Start()
	if not Env.IsDev then
		return
	end

	local requestEvent = Remotes.event("DevTeleportRequest")
	local resultEvent = Remotes.event("DevTeleportResult")

	build(requestEvent)
	refreshKeyHint()
	UserInputService.LastInputTypeChanged:Connect(refreshKeyHint)

	resultEvent.OnClientEvent:Connect(function(ok: boolean, messageKey: string)
		local message = Strings.Dev.Results[messageKey] or Strings.Dev.Results.Failed
		statusLabel.Text = message
		-- Vermelho é só para perigo/inimigo (ESTILO 2.1); falha usa texto normal.
		statusLabel.TextColor3 = if ok then Theme.Color.Success else Theme.Color.TextPrimary
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == DevConfig.PanelToggleKey or input.KeyCode == DevConfig.PanelToggleGamepadButton then
			toggle()
		end
	end)
end

return DevPanelController
