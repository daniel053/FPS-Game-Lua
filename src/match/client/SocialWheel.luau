--!strict
-- Roda de opções da comunicação (F8): pings, frases prontas e emotes.
--   PC: segurar a tecla abre; o mouse fica livre; soltar a tecla escolhe a opção sob o mouse
--       (ou clicar nela). Soltar fora de qualquer opção só fecha.
--   Celular: segurar o botão abre; tocar numa opção escolhe; tocar fora fecha.
--   Controle: segurar o botão abre com a primeira opção selecionada; A escolhe, B fecha.
-- Uma roda aberta por vez. O jogo não pausa.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local SocialConfig = require(Shared.Config.SocialConfig)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.Ui)

local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local Widgets = require(script.Parent.Parent.Common.Ui.Widgets)

export type Option = { id: string, text: string, color: Color3? }

local OPTION_WIDTH = 170

local SocialWheel = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local backdrop: TextButton
local center: Frame
local titleLabel: TextLabel
local buttons: { Widgets.Button } = {}
local hoveredId: string? = nil
local onPick: ((id: string) -> ())? = nil
local opened = false

local function clearButtons()
	for _, b in buttons do
		b.root:Destroy()
	end
	table.clear(buttons)
	hoveredId = nil
end

function SocialWheel.close()
	if not opened then
		return
	end
	opened = false
	gui.Enabled = false
	onPick = nil
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	clearButtons()
end

function SocialWheel.isOpen(): boolean
	return opened
end

local function pick(id: string)
	local callback = onPick
	SocialWheel.close()
	if callback then
		callback(id)
	end
end

-- Soltar a tecla (PC): escolhe a opção sob o mouse, se houver.
function SocialWheel.release()
	if not opened then
		return
	end
	if hoveredId then
		pick(hoveredId)
	else
		SocialWheel.close()
	end
end

function SocialWheel.open(title: string, options: { Option }, callback: (id: string) -> ())
	SocialWheel.close()
	opened = true
	onPick = callback
	titleLabel.Text = title
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 400)
	local small = math.min(viewport.X, viewport.Y) < CombatConfig.TouchLayout.LargeScreenMinSide
	local radius = if small then SocialConfig.Wheel.RadiusSmall else SocialConfig.Wheel.Radius
	local count = #options
	for i, option in options do
		local angle = math.rad(-90 + (i - 1) * 360 / count)
		local button = Widgets.button(center, option.text, "secondary", {
			size = UDim2.fromOffset(OPTION_WIDTH, Theme.Touch.MinTarget),
			textSize = Theme.TextSize.Label,
			arrow = false,
			modal = true, -- libera o mouse da primeira pessoa (PC)
		})
		button.root.AnchorPoint = Vector2.new(0.5, 0.5)
		button.root.Position = UDim2.new(0.5, math.cos(angle) * radius * 1.35, 0.5, math.sin(angle) * radius)
		if option.color then
			button.label.TextColor3 = option.color
		end
		local id = option.id
		button.root.MouseEnter:Connect(function()
			hoveredId = id
			button.setKind("primary")
		end)
		button.root.MouseLeave:Connect(function()
			if hoveredId == id then
				hoveredId = nil
			end
			button.setKind("secondary")
		end)
		button.onClick(function()
			pick(id)
		end)
		table.insert(buttons, button)
	end
	gui.Enabled = true
	Widgets.popIn(center)
	if InputDevice.get() == "Gamepad" and buttons[1] then
		GuiService.SelectedObject = buttons[1].root
	end
end

function SocialWheel.Start()
	gui = Ui.screen("SocialWheel", 40, Enum.ScreenInsets.CoreUISafeInsets)
	gui.Enabled = false

	-- Toque fora das opções fecha (e não deixa o toque virar tiro ou câmera)
	backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Theme.Color.Overlay
	backdrop.BackgroundTransparency = 0.8
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Parent = gui
	backdrop.Activated:Connect(function()
		SocialWheel.close()
	end)

	center = Ui.frame("Center", gui)
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.5)
	center.Size = UDim2.fromOffset(120, 44)
	titleLabel = Ui.label("Title", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, center)
	titleLabel.Size = UDim2.fromScale(1, 1)
	Ui.outlineText(titleLabel)

	UserInputService.InputBegan:Connect(function(input: InputObject)
		if opened and input.KeyCode == Enum.KeyCode.ButtonB then
			SocialWheel.close()
		end
	end)
	InputDevice.onChanged(function()
		SocialWheel.close()
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
end

return SocialWheel
