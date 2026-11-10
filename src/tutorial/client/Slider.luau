--!strict
-- Controle deslizante provisório (F6; componente final na F7): arrastar na barra (toque e mouse) e
-- botões − e + (controle e toque preciso). Alvos de toque de 44 px (ESTILO 3).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Ui = require(ReplicatedStorage.Shared.Ui.ProvisionalUi)

export type Slider = {
	frame: Frame,
	set: (value: number) -> (),
	get: () -> number,
}

local Slider = {}

local ROW_HEIGHT = 70
local BUTTON = Theme.Touch.MinTarget

function Slider.new(
	parent: Instance,
	title: string,
	minValue: number,
	maxValue: number,
	step: number,
	value: number,
	format: (number) -> string,
	onChange: (number) -> ()
): Slider
	local frame = Ui.frame("Slider", parent)
	frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)

	local label = Ui.label("Title", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, frame)
	label.Size = UDim2.new(1, -70, 0, 20)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = title

	local valueLabel = Ui.label("Value", Theme.Font.Number, Theme.TextSize.Body, Theme.Color.TextPrimary, frame)
	valueLabel.AnchorPoint = Vector2.new(1, 0)
	valueLabel.Position = UDim2.fromScale(1, 0)
	valueLabel.Size = UDim2.fromOffset(70, 20)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right

	local minus = Ui.button("Minus", "−", false, frame)
	minus.Position = UDim2.fromOffset(0, 24)
	minus.Size = UDim2.fromOffset(BUTTON, BUTTON)
	minus.Modal = true

	local plus = Ui.button("Plus", "+", false, frame)
	plus.AnchorPoint = Vector2.new(1, 0)
	plus.Position = UDim2.new(1, 0, 0, 24)
	plus.Size = UDim2.fromOffset(BUTTON, BUTTON)

	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.Text = ""
	track.AutoButtonColor = false
	track.Selectable = false
	track.BackgroundColor3 = Theme.Color.PanelRaised
	track.Position = UDim2.fromOffset(BUTTON + 10, 24 + BUTTON / 2 - 8)
	track.Size = UDim2.new(1, -2 * (BUTTON + 10), 0, 16)
	Ui.corner(track, 8)
	Ui.stroke(track)
	track.Parent = frame

	local fill = Ui.frame("Fill", track)
	fill.BackgroundColor3 = Theme.Color.Accent
	fill.BackgroundTransparency = 0
	fill.Size = UDim2.fromScale(0, 1)
	Ui.corner(fill, 8)

	local current = value

	local function render()
		local alpha = if maxValue > minValue then (current - minValue) / (maxValue - minValue) else 0
		fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
		valueLabel.Text = format(current)
	end

	local function set(v: number, notify: boolean)
		local snapped = math.floor((v - minValue) / step + 0.5) * step + minValue
		snapped = math.clamp(snapped, minValue, maxValue)
		snapped = math.floor(snapped * 1000 + 0.5) / 1000
		if snapped == current then
			render()
			return
		end
		current = snapped
		render()
		if notify then
			onChange(current)
		end
	end

	local function fromX(x: number)
		local alpha = (x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		set(minValue + math.clamp(alpha, 0, 1) * (maxValue - minValue), true)
	end

	minus.Activated:Connect(function()
		set(current - step, true)
	end)
	plus.Activated:Connect(function()
		set(current + step, true)
	end)

	local dragging = false
	track.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not dragging then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	render()
	return {
		frame = frame,
		set = function(v: number)
			set(v, false)
		end,
		get = function(): number
			return current
		end,
	}
end

return Slider
