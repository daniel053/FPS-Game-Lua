--!strict
-- Botões de toque do combate (GDD 7.2.6 e 13.1). Só aparecem no celular; no PC somem (ESTILO 3).
--   ATIRAR: segura para atirar; arrastar o dedo nele também gira a câmera.
--           Com o corpo a corpo: tocar = golpe leve, segurar = golpe forte.
--   MIRA / MODO: aparece em toda arma de fogo (MODO nas de modo alternativo, MIRA nas outras); toque
--   liga e desliga.
--   1⇄2: toque alterna primária e pistola; segurar abre as 3 opções (1, 2, 3).
--   RECARREGAR.
-- Posição e tamanho: padrão do CombatConfig ou o que o jogador montou no editor de botões
-- (settings.mobileLayout, F7), resolvido por Shared/Ui/TouchLayout.
-- Movimento e pulo usam os controles de toque do Roblox (joystick à esquerda, pulo à direita).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatTypes = require(Shared.Combat.CombatTypes)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local TouchLayout = require(Shared.Ui.TouchLayout)
local WeaponConfig = require(Shared.Config.WeaponConfig)

local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local WeaponController = require(script.Parent.WeaponController)

local LAYOUT = CombatConfig.TouchLayout
local INPUT = CombatConfig.Input

type Slot = CombatTypes.Slot

local TouchControls = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local fireButton: TextButton
local aimButton: TextButton
local reloadButton: TextButton
local switchButton: TextButton
local slotPicker: Frame

local function makeRound(name: string, text: string, size: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Size = UDim2.fromOffset(size, size)
	button.BackgroundColor3 = Theme.Color.PanelBase
	button.BackgroundTransparency = LAYOUT.ButtonTransparency
	button.AutoButtonColor = false
	button.FontFace = Theme.Font.Title
	button.TextSize = Theme.TextSize.Label
	button.TextColor3 = Theme.Color.TextPrimary
	button.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.PanelBorder
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	button.Parent = gui
	return button
end

local function setPressed(button: GuiButton, pressed: boolean)
	button.BackgroundColor3 = if pressed then Theme.Color.AccentPressed else Theme.Color.PanelBase
end

local function applyLayout()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 400)
	local profile = PlayerDataClient.get()
	local saved = profile and profile.settings.mobileLayout
	local function place(button: GuiObject, id: string): TouchLayout.Placement
		local p = TouchLayout.resolve(id, viewport, saved)
		button.Position = p.position
		button.Size = UDim2.fromOffset(p.size, p.size)
		return p
	end
	place(fireButton, "Fire")
	place(aimButton, "Aim")
	place(reloadButton, "Reload")
	local switch = place(switchButton, "Switch")
	slotPicker.Position = switch.position - UDim2.fromOffset(0, switch.size)
end

local function refresh()
	-- Sem armas (mirante, preparação) os botões de combate somem.
	gui.Enabled = InputDevice.get() == "Touch" and player.Character ~= nil and WeaponController.getLoadout() ~= nil
	local state = WeaponController.getCurrentGun()
	-- Toda arma de fogo usa o botão: MIRA (luneta ou ADS) ou MODO (rajada, bagos concentrados).
	aimButton.Visible = state ~= nil
	if state then
		local altMode = state.def.altMode
		local isMode = altMode ~= nil and not WeaponConfig.hasScope(state.def)
		aimButton.Text = if isMode then Strings.Combat.AltButton else Strings.Combat.AimButton
		setPressed(aimButton, if isMode then state.alt else WeaponController.isAiming())
	end
	reloadButton.Visible = state ~= nil
end

-- Botão ATIRAR: segurar + arrastar para olhar
local function bindFire()
	local activeInput: InputObject? = nil
	local lastPosition = Vector3.zero

	fireButton.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch or activeInput then
			return
		end
		activeInput = input
		lastPosition = input.Position
		setPressed(fireButton, true)
		WeaponController.setTrigger(true, true)
	end)

	UserInputService.TouchMoved:Connect(function(input: InputObject)
		if input ~= activeInput then
			return
		end
		local delta = input.Position - lastPosition
		lastPosition = input.Position
		WeaponController.touchLook(Vector2.new(delta.X, delta.Y))
	end)

	UserInputService.TouchEnded:Connect(function(input: InputObject)
		if input ~= activeInput then
			return
		end
		activeInput = nil
		setPressed(fireButton, false)
		WeaponController.setTrigger(false, true)
	end)
end

-- Botão de troca: toque = 1⇄2; segurar = escolher entre 1, 2 e 3.
local function bindSwitch()
	local downAt: number? = nil
	local opened = false

	switchButton.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		downAt = os.clock()
		opened = false
		local myDown = downAt
		task.delay(INPUT.TouchSwitchHoldSeconds, function()
			if downAt == myDown then
				opened = true
				slotPicker.Visible = true
			end
		end)
	end)

	switchButton.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch or downAt == nil then
			return
		end
		downAt = nil
		if not opened then
			WeaponController.quickSwitch()
		end
	end)

	for i, slot: Slot in { "primary", "secondary", "melee" } :: { Slot } do
		local label = ({ Strings.Combat.SlotPrimary, Strings.Combat.SlotSecondary, Strings.Combat.SlotMelee })[i]
		local option = Instance.new("TextButton")
		option.Name = slot
		option.LayoutOrder = i
		option.Size = UDim2.fromOffset(Theme.Touch.MinTarget, Theme.Touch.MinTarget)
		option.BackgroundColor3 = Theme.Color.PanelRaised
		option.FontFace = Theme.Font.Title
		option.TextSize = Theme.TextSize.Body
		option.TextColor3 = Theme.Color.TextPrimary
		option.Text = label
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, Theme.SmallCardCornerRadius)
		corner.Parent = option
		option.Parent = slotPicker
		option.Activated:Connect(function()
			slotPicker.Visible = false
			WeaponController.equip(slot)
		end)
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "CombatTouchControls"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- mesma área do editor de botões e das cartas (TouchLayout)
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5

	fireButton = makeRound("Fire", Strings.Combat.FireButton, LAYOUT.Small.FireSize)
	fireButton.TextSize = Theme.TextSize.Body
	aimButton = makeRound("Aim", Strings.Combat.AimButton, LAYOUT.Small.ButtonSize)
	switchButton = makeRound("Switch", Strings.Combat.SwitchButton, LAYOUT.Small.ButtonSize)
	switchButton.TextSize = Theme.TextSize.Body
	reloadButton = makeRound("Reload", Strings.Combat.ReloadButton, LAYOUT.Small.ButtonSize)
	reloadButton.TextScaled = true
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = reloadButton

	slotPicker = Instance.new("Frame")
	slotPicker.Name = "SlotPicker"
	slotPicker.Visible = false
	slotPicker.AnchorPoint = Vector2.new(0.5, 1)
	slotPicker.AutomaticSize = Enum.AutomaticSize.XY
	slotPicker.BackgroundColor3 = Theme.Color.PanelBase
	slotPicker.BackgroundTransparency = Theme.Transparency.PanelBase
	slotPicker.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, Theme.Touch.ButtonGap)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = slotPicker
	local pickerPadding = Instance.new("UIPadding")
	pickerPadding.PaddingTop = UDim.new(0, 8)
	pickerPadding.PaddingBottom = UDim.new(0, 8)
	pickerPadding.PaddingLeft = UDim.new(0, 8)
	pickerPadding.PaddingRight = UDim.new(0, 8)
	pickerPadding.Parent = slotPicker

	aimButton.Activated:Connect(WeaponController.toggleAlt)
	reloadButton.Activated:Connect(WeaponController.reload)
	bindFire()
	bindSwitch()

	gui.Parent = player:WaitForChild("PlayerGui")
end

function TouchControls.Start()
	build()
	applyLayout()
	refresh()
	WeaponController.onChanged(refresh)
	PlayerDataClient.onChanged(applyLayout)
	InputDevice.onChanged(function()
		slotPicker.Visible = false
		refresh()
	end)
	player.CharacterAdded:Connect(refresh)
	player.CharacterRemoving:Connect(function()
		task.defer(refresh)
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)
	end
	-- O menu do Roblox aberto: solta o gatilho.
	GuiService.MenuOpened:Connect(function()
		WeaponController.setTrigger(false, true)
	end)
end

return TouchControls
