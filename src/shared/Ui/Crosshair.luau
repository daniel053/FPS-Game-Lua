--!strict
-- Desenho da retícula do jogador (GDD 7.5), usado pelo HUD do combate e pela prévia do editor do
-- tutorial (F6). `container` é um Frame transparente; a retícula fica no centro dele.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(ReplicatedStorage.Shared.Types.PlayerData)

local Crosshair = {}

local function piece(
	container: Frame,
	size: UDim2,
	position: UDim2,
	color: Color3,
	outline: boolean,
	opacity: number
): Frame
	local f = Instance.new("Frame")
	f.Name = "Piece"
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 0
	if outline then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Transparency = 1 - opacity
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = f
	end
	f.Parent = container
	return f
end

function Crosshair.build(container: Frame, settings: PlayerData.CrosshairSettings)
	container:ClearAllChildren()
	local ok, color = pcall(Color3.fromHex, settings.color)
	local c = if ok then color else Color3.new(1, 1, 1)
	local length = 2 + settings.size * 2
	local thick = settings.thickness
	local gap = settings.gap
	local shape = settings.shape
	local outline, opacity = settings.outline, settings.outlineOpacity
	local center = UDim2.fromScale(0.5, 0.5)

	if shape == "cross" or shape == "cross_dot" then
		local offset = gap + length / 2
		piece(container, UDim2.fromOffset(length, thick), center + UDim2.fromOffset(-offset, 0), c, outline, opacity)
		piece(container, UDim2.fromOffset(length, thick), center + UDim2.fromOffset(offset, 0), c, outline, opacity)
		piece(container, UDim2.fromOffset(thick, length), center + UDim2.fromOffset(0, -offset), c, outline, opacity)
		piece(container, UDim2.fromOffset(thick, length), center + UDim2.fromOffset(0, offset), c, outline, opacity)
	end
	if shape == "dot" or shape == "cross_dot" then
		local dot = math.max(2, thick + 1)
		piece(container, UDim2.fromOffset(dot, dot), center, c, outline, opacity)
	end
	if shape == "circle" then
		local diameter = gap * 2 + length * 2
		local ring = Instance.new("Frame")
		ring.Name = "Ring"
		ring.BackgroundTransparency = 1
		ring.BorderSizePixel = 0
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = center
		ring.Size = UDim2.fromOffset(diameter, diameter)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = ring
		local stroke = Instance.new("UIStroke")
		stroke.Color = c
		stroke.Thickness = thick
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = ring
		ring.Parent = container
		piece(container, UDim2.fromOffset(2, 2), center, c, outline, opacity)
	end
end

return Crosshair
