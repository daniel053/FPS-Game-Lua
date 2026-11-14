--!strict
-- Painel de teste (FASES F0 e F1). Só aparece no ambiente DEV_.
--   Celular: botão "TESTE" na tela.
--   PC: tecla T (o atalho fica escrito no botão). Com o painel aberto o mouse fica livre.
--   Controle: direcional para cima; o painel abre com o primeiro botão selecionado.
-- Seções: teleporte entre places (F0) e dados do jogador (F1).
-- O painel rola quando não cabe na tela (celular deitado).
-- Visual simples de ferramenta de teste; a interface final é da F7.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local DataConfig = require(Shared.Config.DataConfig)
local DevConfig = require(Shared.Config.DevConfig)
local Env = require(Shared.Env)
local PlayerData = require(Shared.Types.PlayerData)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local Types = require(Shared.Types)

local PlayerDataClient = require(script.Parent.PlayerDataClient)

local DevPanelController = {}

-- Ferramentas entregues a quem adiciona uma seção ao painel (DevPanelController.addSection).
export type SectionUi = {
	addTitle: (text: string) -> TextLabel,
	addLabel: (text: string) -> TextLabel,
	addButton: (text: string, isPrimary: boolean, onClick: () -> ()) -> TextButton,
	addCustom: (instance: GuiObject) -> GuiObject,
	makeButton: (text: string, isPrimary: boolean) -> TextButton,
	showStatus: (ok: boolean, message: string) -> (),
}
export type SectionBuilder = (ui: SectionUi) -> ()

local CLOSE_BUTTON_ORDER = 1e6 -- o botão FECHAR fica sempre por último

local player = Players.LocalPlayer
local sectionUi: SectionUi? = nil
local pendingSections: { SectionBuilder } = {}

local panel: Frame
local statusLabel: TextLabel
local dataLabel: TextLabel
local toggleButton: TextButton
local keyHint: TextLabel
local firstButton: TextButton?

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

local function showStatus(ok: boolean, message: string)
	statusLabel.Text = message
	-- Vermelho é só para perigo/inimigo (ESTILO 2.1); falha usa texto normal.
	statusLabel.TextColor3 = if ok then Theme.Color.Success else Theme.Color.TextPrimary
end

local function setOpen(open: boolean)
	panel.Visible = open
	if open then
		statusLabel.Text = ""
		if UserInputService.GamepadEnabled and firstButton then
			GuiService.SelectedObject = firstButton
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

local function refreshData(profile: PlayerData.Profile?)
	if profile == nil then
		dataLabel.Text = Strings.Dev.DataLoading
		return
	end
	local s = profile.settings.sensitivity
	local cardCount = 0
	for _ in profile.cards.owned do
		cardCount += 1
	end
	dataLabel.Text = string.format(
		Strings.Dev.DataSummary,
		profile.coins,
		if profile.tutorialDone then Strings.Dev.TutorialDone else Strings.Dev.TutorialPending,
		cardCount,
		s.touch,
		s.mouse,
		s.gamepad
	)
end

-- Próximo valor de sensibilidade para o teste (soma o passo; volta ao mínimo depois do máximo).
local function nextSensitivity(value: number): number
	local limits = DataConfig.Limits.Sensitivity
	local nextValue = value + DevConfig.SensitivityStep
	if nextValue > limits.Max + 1e-6 then
		nextValue = limits.Min
	end
	return math.round(nextValue * 100) / 100
end

local function build(teleportEvent: RemoteEvent, dataEvent: RemoteEvent)
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "DevPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Botão de abrir (canto superior esquerdo, ABAIXO da barra do Roblox).
	-- Fica numa ScreenGui própria com CoreUISafeInsets: a área começa depois dos botões do Roblox
	-- (menu, chat) e do entalhe da câmera, em qualquer aparelho.
	local toggleGui = Instance.new("ScreenGui")
	toggleGui.Name = "DevPanelToggle"
	toggleGui.ResetOnSpawn = false
	toggleGui.DisplayOrder = gui.DisplayOrder
	toggleGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	toggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	toggleButton = makeButton(Strings.Dev.ToggleButton, false)
	toggleButton.Name = "Toggle"
	toggleButton.AnchorPoint = Vector2.new(0, 0)
	toggleButton.Position = UDim2.fromOffset(Theme.ScreenMargin, Theme.ScreenMargin)
	toggleButton.Size = UDim2.fromOffset(120, Theme.Touch.MinTarget)
	toggleButton.TextSize = Theme.TextSize.Body
	toggleButton.BackgroundTransparency = Theme.Transparency.PanelBase
	toggleButton.Parent = toggleGui
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
	panel.Size = UDim2.fromScale(0.9, DevConfig.PanelHeightScale)
	panel.BackgroundColor3 = Theme.Color.PanelBase
	panel.BackgroundTransparency = Theme.Transparency.PanelBase
	panel.Parent = gui
	addCorner(panel)
	addStroke(panel)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = DevConfig.PanelMaxSize
	sizeLimit.Parent = panel

	-- Conteúdo rolável
	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Size = UDim2.fromScale(1, 1)
	content.CanvasSize = UDim2.new()
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.ScrollBarThickness = 6
	content.ScrollBarImageColor3 = Theme.Color.TextSecondary
	content.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, Theme.ScreenMargin)
	padding.PaddingBottom = UDim.new(0, Theme.ScreenMargin)
	padding.PaddingLeft = UDim.new(0, Theme.ScreenMargin)
	padding.PaddingRight = UDim.new(0, Theme.ScreenMargin)
	padding.Parent = content

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, Theme.Touch.ButtonGap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content

	local order = 0
	local function add<T>(instance: T & GuiObject): T
		order += 1
		instance.LayoutOrder = order
		instance.Parent = content
		if firstButton == nil and instance:IsA("TextButton") then
			firstButton = instance
		end
		return instance
	end

	-- Ferramentas para seções extras (ex.: combate, só no place Partida)
	sectionUi = {
		addTitle = function(text: string): TextLabel
			return add(makeLabel(text, Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary))
		end,
		addLabel = function(text: string): TextLabel
			return add(makeLabel(text, Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary))
		end,
		addButton = function(text: string, isPrimary: boolean, onClick: () -> ()): TextButton
			local button = add(makeButton(text, isPrimary))
			button.Activated:Connect(onClick)
			return button
		end,
		addCustom = function(instance: GuiObject): GuiObject
			return add(instance)
		end,
		makeButton = makeButton,
		showStatus = function(ok: boolean, message: string)
			showStatus(ok, message)
		end,
	}

	-- Status no topo: aparece sem precisar rolar
	statusLabel = makeLabel("", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary)
	statusLabel.Name = "Status"

	-- ===== Teleporte (F0) =====
	add(makeLabel(Strings.Dev.PanelTitle, Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary))

	local current = Env.getCurrentPlace()
	local currentName = if current then Strings.Places[current] else Strings.Dev.UnknownPlace
	add(
		makeLabel(
			string.format(Strings.Dev.CurrentPlace, currentName),
			Theme.Font.Body,
			Theme.TextSize.Body,
			Theme.Color.TextSecondary
		)
	)
	add(statusLabel)

	for _, placeName: Types.PlaceName in Env.PlaceNames do
		if placeName == current then
			continue
		end
		local label = string.format(Strings.Dev.GoTo, string.upper(Strings.Places[placeName]))
		local button = add(makeButton(label, true))
		button.Name = `GoTo{placeName}`
		button.Activated:Connect(function()
			statusLabel.Text = ""
			teleportEvent:FireServer(placeName)
		end)
		-- Testes em grupo (até a fila da F5): todos deste servidor juntos no mesmo servidor do destino.
		-- Pede um segundo toque, porque leva também quem não apertou.
		local groupLabel = string.format(Strings.Dev.GoToEveryone, string.upper(Strings.Places[placeName]))
		local group = add(makeButton(groupLabel, false))
		group.Name = `GoToEveryone{placeName}`
		local armedUntil = 0
		group.Activated:Connect(function()
			local now = os.clock()
			if now < armedUntil then
				armedUntil = 0
				group.Text = groupLabel
				statusLabel.Text = ""
				teleportEvent:FireServer(placeName, true)
				return
			end
			armedUntil = now + DataConfig.DevResetConfirmSeconds
			group.Text = string.format(Strings.Dev.GoToEveryoneConfirm, #Players:GetPlayers())
			task.delay(DataConfig.DevResetConfirmSeconds, function()
				if os.clock() >= armedUntil then
					group.Text = groupLabel
				end
			end)
		end)
	end

	-- ===== Dados do jogador (F1) =====
	add(makeLabel(Strings.Dev.DataTitle, Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary))

	dataLabel = add(makeLabel("", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary))
	dataLabel.Name = "DataSummary"
	refreshData(PlayerDataClient.get())
	PlayerDataClient.onChanged(refreshData)

	local addCoins = add(makeButton(string.format(Strings.Dev.AddCoins, DataConfig.DevAddCoinsAmount), false))
	addCoins.Name = "AddCoins"
	addCoins.Activated:Connect(function()
		dataEvent:FireServer("AddCoins")
	end)

	-- Tutorial (F6): refazer (volta ao começo; no lobby publicado, leva ao tutorial) e concluir
	local tutorialReset = add(makeButton(Strings.Dev.TutorialReset, false))
	tutorialReset.Name = "TutorialReset"
	tutorialReset.Activated:Connect(function()
		dataEvent:FireServer("TutorialReset")
	end)
	local tutorialComplete = add(makeButton(Strings.Dev.TutorialComplete, false))
	tutorialComplete.Name = "TutorialComplete"
	tutorialComplete.Activated:Connect(function()
		dataEvent:FireServer("TutorialComplete")
	end)

	-- Cartas (F4): comando de teste (o tutorial da F6 entrega de verdade)
	local grantCards = add(makeButton(Strings.Dev.GrantCards, true))
	grantCards.Name = "GrantCards"
	grantCards.Activated:Connect(function()
		dataEvent:FireServer("GrantStarterCards")
	end)
	local clearCards = add(makeButton(Strings.Dev.ClearCards, false))
	clearCards.Name = "ClearCards"
	clearCards.Activated:Connect(function()
		dataEvent:FireServer("ClearCards")
	end)

	-- Elo, moedas e skins (F9)
	for _, entry in
		{
			{ "RankUp", string.format(Strings.Dev.RankUp, DataConfig.DevRankStep) },
			{ "RankDown", string.format(Strings.Dev.RankDown, DataConfig.DevRankStep) },
			{ "RankReset", Strings.Dev.RankReset },
			{ "SimulateMatch", Strings.Dev.SimulateMatch },
			{ "ResetFirstWin", Strings.Dev.ResetFirstWin },
			{ "ClearSkins", Strings.Dev.ClearSkins },
		}
	do
		local command = entry[1]
		local button = add(makeButton(entry[2], false))
		button.Name = command
		button.Activated:Connect(function()
			dataEvent:FireServer(command)
		end)
	end

	-- Pedido de configuração VÁLIDO pelo caminho real (SettingsUpdateRequest): testa salvar e voltar.
	local sensitivity = add(makeButton(string.format(Strings.Dev.SensitivityUp, DevConfig.SensitivityStep), false))
	sensitivity.Name = "SensitivityUp"
	sensitivity.Activated:Connect(function()
		local profile = PlayerDataClient.get()
		if profile == nil then
			showStatus(false, Strings.Data.SettingsResults.NotLoaded)
			return
		end
		local s = profile.settings.sensitivity
		PlayerDataClient.requestSettings({
			sensitivity = {
				touch = nextSensitivity(s.touch),
				mouse = nextSensitivity(s.mouse),
				gamepad = nextSensitivity(s.gamepad),
			},
		})
	end)

	-- Pedido INVÁLIDO (fora do intervalo): o servidor tem que recusar sem mudar nada.
	local invalid = add(makeButton(Strings.Dev.SendInvalid, false))
	invalid.Name = "SendInvalid"
	invalid.Activated:Connect(function()
		PlayerDataClient.requestSettings({ sensitivity = { mouse = DevConfig.InvalidSensitivity } })
	end)

	local show = add(makeButton(Strings.Dev.ShowProfile, false))
	show.Name = "ShowProfile"
	show.Activated:Connect(function()
		dataEvent:FireServer("ShowProfile")
	end)

	-- Resetar pede um segundo toque para confirmar.
	local reset = add(makeButton(Strings.Dev.ResetProfile, false))
	reset.Name = "ResetProfile"
	local armedUntil = 0
	reset.Activated:Connect(function()
		local now = os.clock()
		if now < armedUntil then
			armedUntil = 0
			reset.Text = Strings.Dev.ResetProfile
			dataEvent:FireServer("ResetProfile")
			return
		end
		armedUntil = now + DataConfig.DevResetConfirmSeconds
		reset.Text = Strings.Dev.ResetConfirm
		task.delay(DataConfig.DevResetConfirmSeconds, function()
			if os.clock() >= armedUntil then
				reset.Text = Strings.Dev.ResetProfile
			end
		end)
	end)

	-- Seções extras pedidas antes do painel existir
	for _, builder in pendingSections do
		builder(sectionUi :: SectionUi)
	end
	table.clear(pendingSections)

	local closeButton = add(makeButton(Strings.Dev.Close, false))
	closeButton.Name = "Close"
	closeButton.LayoutOrder = CLOSE_BUTTON_ORDER
	-- Modal = true libera o mouse da primeira pessoa enquanto o painel está aberto (PC).
	closeButton.Modal = true
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)

	gui.Parent = playerGui
	toggleGui.Parent = playerGui
end

-- Adiciona uma seção ao painel (antes do botão FECHAR). Só tem efeito em DEV_.
function DevPanelController.addSection(builder: SectionBuilder)
	if not Env.IsDev then
		return
	end
	local ui = sectionUi
	if ui then
		builder(ui)
	else
		table.insert(pendingSections, builder)
	end
end

function DevPanelController.Start()
	if not Env.IsDev then
		return
	end

	local teleportRequest = Remotes.event("DevTeleportRequest")
	local teleportResult = Remotes.event("DevTeleportResult")
	local dataCommand = Remotes.event("DevDataCommand")
	local dataResult = Remotes.event("DevDataResult")

	build(teleportRequest, dataCommand)
	refreshKeyHint()
	UserInputService.LastInputTypeChanged:Connect(refreshKeyHint)

	teleportResult.OnClientEvent:Connect(function(ok: boolean, messageKey: string)
		showStatus(ok, Strings.Dev.Results[messageKey] or Strings.Dev.Results.Failed)
	end)

	dataResult.OnClientEvent:Connect(function(ok: boolean, messageKey: string, detail: string?)
		local message = Strings.Dev.DataResults[messageKey] or Strings.Dev.DataResults.Invalid
		if detail then
			message = `{message}\n{detail}`
		end
		showStatus(ok, message)
	end)

	PlayerDataClient.onSettingsResult(function(ok: boolean, messageKey: string, detail: string?)
		local message = Strings.Data.SettingsResults[messageKey] or Strings.Data.SettingsResults.Invalid
		if detail then
			message = string.format(Strings.Dev.InvalidDetail, message, detail)
		end
		showStatus(ok, message)
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
