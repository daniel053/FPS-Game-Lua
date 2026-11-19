--!strict
-- Telas do tutorial (F6; visual final da F7), sempre sobre o jogo (nunca fundo opaco):
--   * faixa no topo: etapa, lição/carta, tarefas com progresso e a dica do controle em uso;
--   * janela no centro: boas-vindas, carta grande, "Você ganhou a carta", fases das armas, final;
--   * painel à esquerda: voz, sensibilidade e retícula (Salvar/Pular), com o jogo visível ao lado.
-- PC: Enter = botão principal (chip visível); mouse livre com janela/painel aberto. Na sensibilidade,
-- TESTAR esconde o painel para mirar; F (ou B no controle) volta. Controle: botão principal já
-- selecionado. Celular: botões grandes; o painel deixa a metade direita livre para mirar e atirar.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local CardConfig = require(Shared.Config.CardConfig)
local Strings = require(Shared.Config.Strings)
local TextUtil = require(Shared.TextUtil)
local Theme = require(Shared.Config.Theme)
local TutorialConfig = require(Shared.Config.TutorialConfig)
local TutorialTypes = require(Shared.Tutorial.TutorialTypes)
local CardArt = require(Shared.Ui.CardArt)
local Ui = require(Shared.Ui.Ui)
local WeaponConfig = require(Shared.Config.WeaponConfig)

local DevPanelController = require(script.Parent.Parent.Common.DevPanelController)
local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local Widgets = require(script.Parent.Parent.Common.Ui.Widgets)
local CrosshairEditor = require(script.Parent.Parent.Common.Settings.CrosshairEditor)
local SensitivityPanel = require(script.Parent.Parent.Common.Settings.SensitivityPanel)
local TutorialClient = require(script.Parent.TutorialClient)
local VoicePanel = require(script.Parent.Parent.Common.Settings.VoicePanel)

type Snapshot = TutorialTypes.Snapshot
type Panel = { commit: () -> (), close: () -> () }

local T = Strings.Tutorial
local MODAL_WIDTH = 560
local PANEL_WIDTH = 420
local BANNER_WIDTH = 560

local TutorialScreen = {}

local gui: ScreenGui
local banner: Frame
local bannerTitle: TextLabel
local bannerSub: TextLabel
local taskList: Frame
local hintLabel: TextLabel

local overlay: Frame -- janela do centro
local modal: Frame
local modalContent: Frame

local side: Frame -- painel da esquerda
local sideTitle: TextLabel
local sideContent: ScrollingFrame
local sideFooter: Frame
local backHint: Frame -- "F voltar ao ajuste" (modo TESTAR)

local primaryAction: (() -> ())? = nil
local primaryButton: TextButton? = nil
local openPanel: Panel? = nil
local viewKey = ""
local testing = false

-- Peças ------------------------------------------------------------------------------------------

local function text(name: string, font: Font, size: number, color: Color3, parent: Instance, height: number): TextLabel
	local l = Ui.label(name, font, size, color, parent)
	l.Size = UDim2.new(1, 0, 0, height)
	l.TextWrapped = true
	return l
end

local function selectForGamepad(button: TextButton?)
	if InputDevice.get() == "Gamepad" and button then
		GuiService.SelectedObject = button
	end
end

local function clearSelection()
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
end

-- Botão principal com o chip "Enter" no PC.
local function primary(parent: Instance, label: string, onClick: () -> ()): TextButton
	local button = Widgets.button(parent, label, "primary", {
		size = UDim2.fromOffset(260, Theme.PrimaryButtonMinHeight),
		modal = true, -- libera o mouse da primeira pessoa (PC)
		pc = T.ContinueKey,
	})
	button.root.Name = "Primary"
	button.onClick(onClick)
	primaryAction = onClick
	primaryButton = button.root
	return button.root
end

local function secondary(parent: Instance, label: string, onClick: () -> ()): TextButton
	local button = Widgets.button(parent, label, "secondary", {
		size = UDim2.fromOffset(180, Theme.PrimaryButtonMinHeight),
		modal = true,
	})
	button.root.Name = "Secondary"
	button.onClick(onClick)
	return button.root
end

-- Animação de abrir (ESTILO 2.7): sobe 24 px e aparece em 0,2 s (guarda a posição final, então
-- abrir duas vezes seguidas não desloca a janela).
local popIn = Widgets.popIn

-- Faixa do topo -----------------------------------------------------------------------------------

local function hintFor(kind: string): string?
	local key = if kind == "Look" or kind == "Walk"
		then "Move"
		elseif kind == "Jump" then "Jump"
		elseif kind == "Knock" then "Shoot"
		elseif kind == "Reload" then "Reload"
		elseif kind == "Equip" then "Swap"
		elseif kind == "Alt" then "Alt"
		elseif kind == "Reach" or kind == "Smoke" or kind == "Tremor" or kind == "Activate" then "Card"
		else nil
	if key == nil then
		return nil
	end
	local set = T.Hints[key]
	return set and set[InputDevice.get()]
end

local function taskText(task: TutorialTypes.TaskView): string
	local base: string
	if task.kind == "Equip" then
		base = if task.slot == "secondary" then T.Tasks.EquipSecondary else T.Tasks.EquipPrimary
	else
		base = T.Tasks[task.kind] or task.kind
	end
	if task.count > 1 then
		base ..= string.format(T.Count, task.done, task.count)
	end
	return base
end

local function subtitle(s: Snapshot): string
	if s.stepId == "Weapons" and s.lesson and s.lessonCount then
		local lesson = TutorialConfig.WeaponLessons[s.lesson]
		local id = lesson and (lesson.primary or lesson.secondary)
		local def = id and WeaponConfig.get(id)
		local category = if def then Strings.WeaponCategories[def.category] else ""
		local line = string.format(T.LessonLabel, s.lesson, s.lessonCount, TextUtil.upper(category))
		local tip = s.tip and T.WeaponTips[s.tip]
		return if tip then `{line}\n{tip}` else line
	elseif s.stepId == "Cards" and s.cardId and s.cardIndex and s.cardCount then
		local card = Strings.Cards[s.cardId]
		return string.format(T.Card.Label, s.cardIndex, s.cardCount)
			.. " · "
			.. TextUtil.upper(card and card.name or "")
	end
	return ""
end

local function renderBanner(s: Snapshot)
	local show = s.phase == "Doing" and not testing
	banner.Visible = show
	if not show then
		return
	end
	bannerTitle.Text = string.format(T.StepLabel, s.step, s.totalSteps) .. " · " .. (T.Steps[s.stepId] or "")
	local sub = subtitle(s)
	bannerSub.Text = sub
	bannerSub.Visible = sub ~= ""
	bannerSub.Size = UDim2.new(1, 0, 0, if string.find(sub, "\n") then 38 else 20)

	taskList:ClearAllChildren()
	Ui.list(taskList, Enum.FillDirection.Vertical, 2)
	for i, task in s.tasks do
		local done = i < s.taskIndex
		local current = i == s.taskIndex
		local line = text(
			"Task",
			if current then Theme.Font.BodyStrong else Theme.Font.Body,
			Theme.TextSize.Body,
			if done then Theme.Color.Success elseif current then Theme.Color.TextPrimary else Theme.Color.TextSecondary,
			taskList,
			22
		)
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.LayoutOrder = i
		line.Text = (if done then T.Done else T.Todo) .. "  " .. taskText(task)
	end
	taskList.Size = UDim2.new(1, 0, 0, #s.tasks * 24)

	local current = s.tasks[s.taskIndex]
	local hint = current and hintFor(current.kind)
	hintLabel.Text = hint or ""
	hintLabel.Visible = hint ~= nil
end

-- Janela do centro ----------------------------------------------------------------------------------

local function closeModal()
	overlay.Visible = false
	modalContent:ClearAllChildren()
	primaryAction = nil
	primaryButton = nil
	clearSelection()
end

local function openModal(
	title: string,
	body: string?,
	build: ((content: Frame) -> ())?,
	buttonLabel: string?,
	onClick: (() -> ())?
)
	modalContent:ClearAllChildren()
	primaryAction = nil
	primaryButton = nil
	Ui.list(modalContent, Enum.FillDirection.Vertical, 12).HorizontalAlignment = Enum.HorizontalAlignment.Center

	local titleLabel =
		text("Title", Theme.Font.Title, Theme.TextSize.Title + 6, Theme.Color.TextPrimary, modalContent, 36)
	titleLabel.Text = TextUtil.upper(title)
	titleLabel.LayoutOrder = 1
	if body then
		local bodyLabel =
			text("Body", Theme.Font.Body, Theme.TextSize.Body + 2, Theme.Color.TextSecondary, modalContent, 0)
		bodyLabel.AutomaticSize = Enum.AutomaticSize.Y
		bodyLabel.Text = body
		bodyLabel.LayoutOrder = 2
	end
	if build then
		local holder = Ui.frame("Extra", modalContent)
		holder.Size = UDim2.fromScale(1, 0)
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.LayoutOrder = 3
		build(holder)
	end
	if buttonLabel and onClick then
		local row = Ui.frame("Buttons", modalContent)
		row.Size = UDim2.new(1, 0, 0, Theme.PrimaryButtonMinHeight)
		row.LayoutOrder = 4
		local button = primary(row, buttonLabel, onClick)
		button.AnchorPoint = Vector2.new(0.5, 0)
		button.Position = UDim2.fromScale(0.5, 0)
	end
	overlay.Visible = true
	popIn(modal)
	selectForGamepad(primaryButton)
end

-- Carta grande (borda na cor da carta), com a arte (F10) em cima do nome
local function bigCard(parent: Frame, cardId: string, animate: boolean)
	local def = CardConfig.get(cardId)
	local names = Strings.Cards[cardId]
	local color = Theme.Cards[cardId] or Theme.Color.Accent
	local card = Ui.raised("Card", parent)
	card.Size = UDim2.fromOffset(240, 250)
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.fromScale(0.5, 0)
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
		stroke.Thickness = 3
	end
	Ui.corner(card, 10)
	Ui.padding(card, 12)
	Ui.list(card, Enum.FillDirection.Vertical, 6).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local art = Ui.frame("Art", card)
	art.Size = UDim2.fromOffset(60, 56)
	art.LayoutOrder = 0
	CardArt.draw(art, cardId, color)
	local name = text("Name", Theme.Font.Title, Theme.TextSize.Title + 4, color, card, 32)
	name.Text = TextUtil.upper(names and names.name or cardId)
	name.LayoutOrder = 1
	if def then
		local key = text("Key", Theme.Font.Title, Theme.TextSize.Body, Theme.Color.TextPrimary, card, 20)
		key.Text = string.format(T.Card.Key, def.key)
		key.LayoutOrder = 2
	end
	local desc = text("Description", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary, card, 90)
	desc.Text = names and names.description or ""
	desc.LayoutOrder = 3
	parent.Size = UDim2.new(1, 0, 0, 250)
	if animate then
		local scale = Instance.new("UIScale")
		scale.Scale = 0.6
		scale.Parent = card
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

local function phasesList(parent: Frame)
	Ui.list(parent, Enum.FillDirection.Vertical, 4)
	for i, phase in WeaponConfig.Phases do
		local rounds = if phase.toRound
			then string.format(T.Phases.Range, phase.fromRound, phase.toRound)
			else string.format(T.Phases.From, phase.fromRound)
		local line = text("Phase", Theme.Font.BodyStrong, Theme.TextSize.Body + 2, Theme.Color.TextPrimary, parent, 24)
		line.Text = string.format(T.Phases.Line, rounds, Strings.WeaponPhases[phase.id] or phase.id)
		line.LayoutOrder = i
	end
end

-- Painel da esquerda --------------------------------------------------------------------------------

local function closeSide()
	if openPanel then
		openPanel.close()
		openPanel = nil
	end
	testing = false
	side.Visible = false
	backHint.Visible = false
	for _, child in sideContent:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	sideFooter:ClearAllChildren()
	primaryAction = nil
	primaryButton = nil
	clearSelection()
end

local function setTesting(on: boolean)
	testing = on
	side.Visible = not on
	backHint.Visible = on
	local s = TutorialClient.get()
	if s then
		renderBanner(s)
	end
	if on then
		clearSelection()
	else
		selectForGamepad(primaryButton)
	end
end

local function openSide(s: Snapshot)
	closeSide()
	sideTitle.Text = TextUtil.upper(
		if s.stepId == "Voice"
			then T.Voice.Title
			elseif s.stepId == "Sensitivity" then T.Sensitivity.Title
			else T.Crosshair.Title
	)
	local panel: Panel = if s.stepId == "Voice"
		then VoicePanel.open(sideContent)
		elseif s.stepId == "Sensitivity" then SensitivityPanel.open(sideContent)
		else CrosshairEditor.open(sideContent)
	openPanel = panel

	Ui.list(sideFooter, Enum.FillDirection.Horizontal, 8)
	local primaryLabel = if s.stepId == "Voice" then T.Voice.Ok else T.Save
	local button = primary(sideFooter, primaryLabel, function()
		panel.commit()
		TutorialClient.request("Continue")
	end)
	button.Size = UDim2.new(0.6, -4, 1, 0)
	button.LayoutOrder = 1
	if s.canSkip then
		local skipLabel = if s.stepId == "Voice" then T.Voice.NotNow else T.Skip
		local skip = secondary(sideFooter, skipLabel, function()
			panel.close()
			TutorialClient.request("Skip")
		end)
		skip.Size = UDim2.new(0.4, -4, 1, 0)
		skip.LayoutOrder = 2
	end
	-- Sensibilidade no PC/controle: esconder o painel para mirar
	if s.stepId == "Sensitivity" and InputDevice.get() ~= "Touch" then
		local test = secondary(sideContent, T.Sensitivity.Test, function()
			setTesting(true)
		end)
		test.Size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget)
		test.LayoutOrder = 10
	end
	side.Visible = true
	popIn(side)
	selectForGamepad(primaryButton)
end

-- Render ------------------------------------------------------------------------------------------

local function render(s: Snapshot)
	local key = `{s.step}:{s.phase}:{s.lesson or 0}:{s.cardIndex or 0}:{s.cardId or ""}:{s.finishing}:{s.noTeleport}`
	renderBanner(s)
	if key == viewKey then
		return
	end
	viewKey = key

	if s.phase ~= "Panel" then
		closeSide()
	end
	if s.phase == "Doing" then
		closeModal()
	elseif s.phase == "Intro" and s.stepId == "Welcome" then
		openModal(T.Welcome.Title, T.Welcome.Body, nil, T.Welcome.Button, function()
			TutorialClient.request("Continue")
		end)
	elseif s.phase == "Intro" and s.cardId then
		local cardId = s.cardId
		openModal(
			string.format(T.Card.Label, s.cardIndex or 1, s.cardCount or 1),
			nil,
			function(holder: Frame)
				bigCard(holder, cardId, false)
			end,
			T.Card.TryIt,
			function()
				TutorialClient.request("Continue")
			end
		)
	elseif s.phase == "Reward" and s.cardId then
		local names = Strings.Cards[s.cardId]
		local cardId = s.cardId
		openModal(
			string.format(T.Card.Won, TextUtil.upper(names and names.name or "")),
			T.Card.WonBody,
			function(holder: Frame)
				bigCard(holder, cardId, true)
			end,
			T.Card.Next,
			function()
				TutorialClient.request("Continue")
			end
		)
	elseif s.phase == "Info" then
		openModal(T.Phases.Title, T.Phases.Body, phasesList, T.Phases.Button, function()
			TutorialClient.request("Continue")
		end)
	elseif s.phase == "Panel" then
		closeModal()
		openSide(s)
	elseif s.phase == "Final" then
		local body = if s.noTeleport then T.Final.Studio else T.Final.Body
		local label = if s.finishing then T.Final.Going else T.Final.Button
		openModal(T.Final.Title, body, nil, label, function()
			local now = TutorialClient.get()
			if now and not now.finishing then
				TutorialClient.request("Finish")
			end
		end)
	end
end

-- Montagem ------------------------------------------------------------------------------------------

local function build()
	gui = Ui.screen("Tutorial", 25, Enum.ScreenInsets.DeviceSafeInsets)

	-- Faixa do topo
	local bannerContent: Frame
	banner, bannerContent = Ui.autoPanel("Banner", gui, 10)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, Theme.ScreenMargin)
	banner.Size = UDim2.fromOffset(BANNER_WIDTH, 0)
	banner.Visible = false
	Ui.list(bannerContent, Enum.FillDirection.Vertical, 4)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(BANNER_WIDTH, math.huge)
	limit.Parent = banner
	bannerTitle = text("Title", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, bannerContent, 26)
	bannerTitle.TextXAlignment = Enum.TextXAlignment.Left
	bannerTitle.LayoutOrder = 1
	bannerSub = text("Sub", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextSecondary, bannerContent, 20)
	bannerSub.TextXAlignment = Enum.TextXAlignment.Left
	bannerSub.LayoutOrder = 2
	taskList = Ui.frame("Tasks", bannerContent)
	taskList.LayoutOrder = 3
	hintLabel = text("Hint", Theme.Font.Body, Theme.TextSize.Label + 1, Theme.Color.TextSecondary, bannerContent, 0)
	hintLabel.AutomaticSize = Enum.AutomaticSize.Y
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.LayoutOrder = 4

	-- Janela do centro sobre o jogo (escurecimento parcial, nunca opaco)
	overlay = Ui.frame("Overlay", gui)
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Color.Overlay
	overlay.BackgroundTransparency = Theme.Transparency.Overlay
	overlay.Visible = false
	overlay.Active = true
	local modalInner: Frame
	modal, modalInner = Ui.autoPanel("Modal", overlay, 20)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = UDim2.fromScale(0.9, 0)
	local modalLimit = Instance.new("UISizeConstraint")
	modalLimit.MaxSize = Vector2.new(MODAL_WIDTH, math.huge)
	modalLimit.Parent = modal
	modalContent = Ui.frame("Content", modalInner)
	modalContent.Size = UDim2.fromScale(1, 0)
	modalContent.AutomaticSize = Enum.AutomaticSize.Y

	-- Painel da esquerda (o lado direito fica livre para mirar e atirar)
	local sideInner: Frame
	side, sideInner = Ui.panel("Side", gui, 14)
	side.Position = UDim2.fromOffset(Theme.ScreenMargin, Theme.ScreenMargin)
	side.Size = UDim2.new(0.46, 0, 1, -2 * Theme.ScreenMargin)
	side.Visible = false
	local sideLimit = Instance.new("UISizeConstraint")
	sideLimit.MaxSize = Vector2.new(PANEL_WIDTH, math.huge)
	sideLimit.Parent = side
	sideTitle = text("Title", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, sideInner, 30)
	sideTitle.TextXAlignment = Enum.TextXAlignment.Left
	sideContent = Instance.new("ScrollingFrame")
	sideContent.Name = "Content"
	sideContent.BackgroundTransparency = 1
	sideContent.BorderSizePixel = 0
	sideContent.Position = UDim2.fromOffset(0, 38)
	sideContent.Size = UDim2.new(1, 0, 1, -38 - Theme.PrimaryButtonMinHeight - 10)
	sideContent.CanvasSize = UDim2.new()
	sideContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sideContent.ScrollBarThickness = 4
	sideContent.ScrollingDirection = Enum.ScrollingDirection.Y
	sideContent.Parent = sideInner
	Ui.list(sideContent, Enum.FillDirection.Vertical, 12)
	sideFooter = Ui.frame("Footer", sideInner)
	sideFooter.AnchorPoint = Vector2.new(0, 1)
	sideFooter.Position = UDim2.fromScale(0, 1)
	sideFooter.Size = UDim2.new(1, 0, 0, Theme.PrimaryButtonMinHeight)

	-- Modo TESTAR (sensibilidade): dica para voltar
	local backInner: Frame
	backHint, backInner = Ui.panel("BackHint", gui, nil, Theme.Chamfer.Tab)
	backHint.AnchorPoint = Vector2.new(0, 0)
	backHint.Position = UDim2.fromOffset(Theme.ScreenMargin, Theme.ScreenMargin)
	backHint.Size = UDim2.fromOffset(260, 40)
	backHint.Visible = false
	local chip = Ui.keyChip(T.Sensitivity.BackKey, backInner)
	chip.Name = "Chip"
	chip.AnchorPoint = Vector2.new(0, 0.5)
	chip.Position = UDim2.new(0, 10, 0.5, 0)
	local backText = Ui.label("Text", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, backInner)
	backText.Position = UDim2.fromOffset(42, 0)
	backText.Size = UDim2.new(1, -50, 1, 0)
	backText.TextXAlignment = Enum.TextXAlignment.Left
	backText.Text = TextUtil.upper(T.Sensitivity.Back)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function TutorialScreen.Start()
	build()
	TutorialClient.onChanged(render)
	InputDevice.onChanged(function(device: InputDevice.Device)
		local chip = backHint:FindFirstChild("Chip", true)
		if chip and chip:IsA("TextLabel") then
			chip.Text = if device == "Gamepad" then "B" else T.Sensitivity.BackKey
		end
		local s = TutorialClient.get()
		if s then
			viewKey = "" -- refaz janela/painel (botões e chips do aparelho novo)
			render(s)
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if UserInputService:GetFocusedTextBox() then
			return
		end
		local key = input.KeyCode
		if testing then
			if key == Enum.KeyCode.F or key == Enum.KeyCode.ButtonB then
				setTesting(false)
			end
			return
		end
		if processed then
			return
		end
		if (key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter) and primaryAction then
			primaryAction()
		end
	end)

	DevPanelController.addSection(function(ui)
		ui.addTitle(T.DevTitle)
		ui.addButton(Strings.Dev.TutorialSkipStep, false, function()
			TutorialClient.request("DevSkip")
		end)
	end)
end

return TutorialScreen
