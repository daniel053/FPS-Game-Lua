--!strict
-- Etapa 7 do tutorial (GDD 5.2): editor da retícula com prévia ao vivo. Formato, cor (cores prontas
-- do Theme), tamanho, espessura, espaço no meio e contorno. Salvar manda o pedido normal de
-- configuração (validado no servidor).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Crosshair = require(Shared.Ui.Crosshair)
local DataConfig = require(Shared.Config.DataConfig)
local PlayerData = require(Shared.Types.PlayerData)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.ProvisionalUi)

local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local Slider = require(script.Parent.Slider)

local C = Strings.Tutorial.Crosshair
local LIMITS = DataConfig.Limits
local SHAPES = { "dot", "cross", "circle", "cross_dot" }
local PREVIEW_SIZE = 110

export type Panel = { commit: () -> (), close: () -> () }

local CrosshairEditor = {}

local function row(container: GuiObject, order: number, height: number): Frame
	local f = Ui.frame("Row", container)
	f.Size = UDim2.new(1, 0, 0, height)
	f.LayoutOrder = order
	return f
end

local function caption(parent: Instance, text: string)
	local l = Ui.label("Caption", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, parent)
	l.Size = UDim2.new(1, 0, 0, 20)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
end

function CrosshairEditor.open(container: GuiObject): Panel
	local profile = PlayerDataClient.get()
	local working: PlayerData.CrosshairSettings = if profile
		then table.clone(profile.settings.crosshair)
		else {
			shape = "cross",
			color = "#FFFFFF",
			size = 4,
			thickness = 2,
			gap = 3,
			outline = true,
			outlineOpacity = 0.6,
		}

	local body = Ui.label("Body", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary, container)
	body.Size = UDim2.new(1, 0, 0, 22)
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.Text = C.Body
	body.LayoutOrder = 0

	-- Prévia
	local previewRow = row(container, 1, PREVIEW_SIZE)
	local preview = Ui.frame("Preview", previewRow)
	preview.AnchorPoint = Vector2.new(0.5, 0)
	preview.Position = UDim2.fromScale(0.5, 0)
	preview.Size = UDim2.fromOffset(PREVIEW_SIZE * 1.6, PREVIEW_SIZE)
	preview.BackgroundColor3 = Theme.Combat.ArenaWall
	preview.BackgroundTransparency = 0
	Ui.corner(preview)
	local drawn = Ui.frame("Crosshair", preview)
	drawn.Size = UDim2.fromScale(1, 1)

	local refreshButtons: { () -> () } = {}
	local function render()
		Crosshair.build(drawn, working)
		for _, refresh in refreshButtons do
			refresh()
		end
	end

	-- Formato
	local shapeRow = row(container, 2, 20 + 8 + Theme.Touch.MinTarget)
	caption(shapeRow, C.Shape)
	local shapeList = Ui.frame("Shapes", shapeRow)
	shapeList.Position = UDim2.fromOffset(0, 28)
	shapeList.Size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget)
	Ui.list(shapeList, Enum.FillDirection.Horizontal, 6)
	for i, shape in SHAPES do
		local b = Ui.button("Shape", C.Shapes[shape] or shape, false, shapeList)
		b.Size = UDim2.new(0.25, -5, 1, 0)
		b.TextSize = Theme.TextSize.Label
		b.TextWrapped = true
		b.LayoutOrder = i
		b.Modal = true
		b.Activated:Connect(function()
			working.shape = shape :: any
			render()
		end)
		table.insert(refreshButtons, function()
			b.BackgroundColor3 = if working.shape == shape then Theme.Color.Accent else Theme.Color.PanelRaised
		end)
	end

	-- Cor
	local colorRow = row(container, 3, 20 + 8 + Theme.Touch.MinTarget)
	caption(colorRow, C.Color)
	local swatches = Ui.frame("Colors", colorRow)
	swatches.Position = UDim2.fromOffset(0, 28)
	swatches.Size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget)
	Ui.list(swatches, Enum.FillDirection.Horizontal, 8)
	for i, hex in Theme.CrosshairPalette do
		local b = Instance.new("TextButton")
		b.Name = "Swatch"
		b.Text = ""
		b.LayoutOrder = i
		b.Size = UDim2.fromOffset(Theme.Touch.MinTarget, Theme.Touch.MinTarget)
		b.BackgroundColor3 = Color3.fromHex(hex)
		Ui.corner(b)
		local stroke = Ui.stroke(b, Theme.Color.PanelBorder, 2)
		b.Parent = swatches
		b.Activated:Connect(function()
			working.color = hex
			render()
		end)
		table.insert(refreshButtons, function()
			local selected = string.upper(working.color) == string.upper(hex)
			stroke.Color = if selected then Theme.Color.Accent else Theme.Color.PanelBorder
			stroke.Thickness = if selected then 3 else 2
		end)
	end

	-- Números (inteiros)
	local function intSlider(order: number, title: string, range: { Min: number, Max: number }, key: string)
		local s = Slider.new(
			container,
			title,
			range.Min,
			range.Max,
			1,
			(working :: any)[key],
			function(v: number): string
				return tostring(math.floor(v + 0.5))
			end,
			function(v: number)
				(working :: any)[key] = math.floor(v + 0.5)
				render()
			end
		)
		s.frame.LayoutOrder = order
	end
	intSlider(4, C.Size, LIMITS.CrosshairSize, "size")
	intSlider(5, C.Thickness, LIMITS.CrosshairThickness, "thickness")
	intSlider(6, C.Gap, LIMITS.CrosshairGap, "gap")

	-- Contorno
	local outlineRow = row(container, 7, Theme.Touch.MinTarget)
	local outlineLabel =
		Ui.label("Caption", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, outlineRow)
	outlineLabel.Size = UDim2.new(1, -150, 1, 0)
	outlineLabel.TextXAlignment = Enum.TextXAlignment.Left
	outlineLabel.Text = C.Outline
	local outlineButton = Ui.button("Outline", "", false, outlineRow)
	outlineButton.AnchorPoint = Vector2.new(1, 0)
	outlineButton.Position = UDim2.fromScale(1, 0)
	outlineButton.Size = UDim2.new(0, 140, 1, 0)
	outlineButton.TextSize = Theme.TextSize.Body
	outlineButton.Activated:Connect(function()
		working.outline = not working.outline
		render()
	end)
	table.insert(refreshButtons, function()
		outlineButton.Text = if working.outline then C.On else C.Off
		outlineButton.BackgroundColor3 = if working.outline then Theme.Color.Accent else Theme.Color.PanelRaised
	end)

	render()
	return {
		commit = function()
			PlayerDataClient.requestSettings({ crosshair = table.clone(working) })
		end,
		close = function() end,
	}
end

return CrosshairEditor
