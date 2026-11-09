--!strict
-- HUD de combate PROVISÓRIO da F2 (o visual final da tela T6 é da F7), seguindo Theme e ESTILO T6:
--   * baixo esquerdo: escudo e vida em barras com o número;
--   * baixo direito: munição "25 | ∞", nome da arma, "RECARREGANDO";
--   * PC: armas 1/2/3 com chips de tecla e dica de recarga (no celular, os botões já mostram);
--   * centro: retícula do perfil (formato, cor, tamanho, espessura, espaço, contorno);
--   * marcador de acerto e som diferente quando o escudo quebra (GDD 7.3);
--   * aviso "N KILL" embaixo, no centro (GDD 7.7), contando os abates da partida;
--   * luneta redonda com fundo escuro nas snipers com a mira aberta (guia, quadro 3).
-- Sem neon e sem vermelho fora de perigo/inimigo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local AudioConfig = require(Shared.Config.AudioConfig)
local CharacterConfig = require(Shared.Config.CharacterConfig)
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local CombatTypes = require(Shared.Combat.CombatTypes)
local Env = require(Shared.Env)
local PlayerData = require(Shared.Types.PlayerData)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Config.Strings)
local TextUtil = require(Shared.TextUtil)
local Theme = require(Shared.Config.Theme)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponState = require(Shared.Combat.WeaponState)

local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local CombatEffects = require(script.Parent.CombatEffects)
local WeaponController = require(script.Parent.WeaponController)

local ATTR = CombatNames.Attr
local HEALTH = CharacterConfig.Health
local FX = CombatConfig.Effects
local MARGIN = Theme.ScreenMargin
local BAR_WIDTH = 220
local BAR_HEIGHT = 12

local CombatHUD = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local shieldFill: Frame
local shieldText: TextLabel
local hpFill: Frame
local hpText: TextLabel
local ammoText: TextLabel
local weaponText: TextLabel
local ammoBlock: Frame
local slotHints: Frame
local slotLabels: { [string]: TextLabel } = {}
local slotRows: { [string]: Frame } = {}
local crosshair: Frame
local hitMarker: Frame
local killText: TextLabel
local devReport: TextLabel
local knockedText: TextLabel
local scopeOverlay: Frame
local hitMarkerUntil = 0
local killUntil = 0

local function label(name: string, font: Font, size: number, color: Color3, parent: Instance): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.FontFace = font
	text.TextSize = size
	text.TextColor3 = color
	text.TextStrokeTransparency = 0.6
	text.Text = ""
	text.Parent = parent
	return text
end

local function frame(name: string, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 1
	f.Parent = parent
	return f
end

-- Barras de escudo e vida ----------------------------------------------------------------------------

local function makeBar(name: string, color: Color3, y: number, parent: Instance): (Frame, TextLabel)
	local back = frame(name, parent)
	back.Position = UDim2.fromOffset(0, y)
	back.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT)
	back.BackgroundColor3 = Theme.Color.PanelBase
	back.BackgroundTransparency = Theme.Transparency.PanelBase
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = back
	local fill = frame("Fill", back)
	fill.BackgroundTransparency = 0
	fill.BackgroundColor3 = color
	fill.Size = UDim2.fromScale(1, 1)
	local fillCorner = corner:Clone()
	fillCorner.Parent = fill
	local value = label("Value", Theme.Font.Number, Theme.TextSize.PrimaryButton, Theme.Color.TextPrimary, parent)
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Position = UDim2.fromOffset(BAR_WIDTH + 8, y - 5)
	value.Size = UDim2.fromOffset(60, BAR_HEIGHT + 10)
	return fill, value
end

local function buildHealth()
	local block = frame("Health", gui)
	block.AnchorPoint = Vector2.new(0, 1)
	block.Position = UDim2.new(0, MARGIN, 1, -MARGIN)
	block.Size = UDim2.fromOffset(BAR_WIDTH + 70, 2 * BAR_HEIGHT + 30)
	local shieldCaption =
		label("ShieldCaption", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, block)
	shieldCaption.Text = Strings.Combat.Shield
	shieldCaption.TextXAlignment = Enum.TextXAlignment.Left
	shieldCaption.Size = UDim2.fromOffset(BAR_WIDTH, 14)
	shieldFill, shieldText = makeBar("Shield", Theme.Color.Shield, 16, block)
	hpFill, hpText = makeBar("Hp", Theme.Color.Hp, 16 + BAR_HEIGHT + 10, block)
end

-- Munição e armas -----------------------------------------------------------------------------------

local function keyChip(text: string, parent: Instance): TextLabel
	local chip = label("Key", Theme.Font.Title, Theme.TextSize.Label, Theme.Color.TextSecondary, parent)
	chip.BackgroundTransparency = 0
	chip.BackgroundColor3 = Theme.Color.PanelRaised
	chip.TextStrokeTransparency = 1
	chip.Size = UDim2.fromOffset(22, 22)
	chip.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = chip
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.TextSecondary
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = chip
	return chip
end

local function buildAmmo()
	ammoBlock = frame("Ammo", gui)
	ammoBlock.AnchorPoint = Vector2.new(1, 1)
	ammoBlock.Size = UDim2.fromOffset(240, 70)
	ammoText = label("Count", Theme.Font.Number, 34, Theme.Color.TextPrimary, ammoBlock)
	ammoText.TextXAlignment = Enum.TextXAlignment.Right
	ammoText.AnchorPoint = Vector2.new(1, 1)
	ammoText.Position = UDim2.fromScale(1, 1)
	ammoText.Size = UDim2.new(1, 0, 0, 40)
	weaponText = label("Weapon", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextSecondary, ammoBlock)
	weaponText.TextXAlignment = Enum.TextXAlignment.Right
	weaponText.AnchorPoint = Vector2.new(1, 1)
	weaponText.Position = UDim2.new(1, 0, 1, -42)
	weaponText.Size = UDim2.new(1, 0, 0, 20)

	-- PC: armas com chips de tecla (1, 2, 3) e R para recarregar
	slotHints = frame("SlotHints", gui)
	slotHints.AnchorPoint = Vector2.new(1, 1)
	slotHints.Position = UDim2.new(1, -MARGIN, 1, -MARGIN - 80)
	slotHints.Size = UDim2.fromOffset(240, 4 * 26)
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = slotHints
	local rows = {
		{ key = Strings.Combat.SlotPrimary, slot = "primary" },
		{ key = Strings.Combat.SlotSecondary, slot = "secondary" },
		{ key = Strings.Combat.SlotMelee, slot = "melee" },
		{ key = Strings.Combat.ReloadKey, slot = "reload" },
	}
	for i, row in rows do
		local line = frame(row.slot, slotHints)
		line.LayoutOrder = i
		line.Size = UDim2.fromOffset(240, 22)
		local rowList = Instance.new("UIListLayout")
		rowList.FillDirection = Enum.FillDirection.Horizontal
		rowList.HorizontalAlignment = Enum.HorizontalAlignment.Right
		rowList.VerticalAlignment = Enum.VerticalAlignment.Center
		rowList.Padding = UDim.new(0, 6)
		rowList.SortOrder = Enum.SortOrder.LayoutOrder
		rowList.Parent = line
		local name = label("Name", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, line)
		name.AutomaticSize = Enum.AutomaticSize.X
		name.Size = UDim2.fromOffset(0, 22)
		name.LayoutOrder = 1
		if row.slot == "reload" then
			name.Text = TextUtil.upper(Strings.Combat.ReloadButton)
		end
		local chip = keyChip(row.key, line)
		chip.LayoutOrder = 2
		slotLabels[row.slot] = name
		slotRows[row.slot] = line
	end
end

local function layoutForDevice()
	local touch = InputDevice.get() == "Touch"
	slotHints.Visible = not touch
	local rightMargin = MARGIN
	if touch then
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 400)
		local layout = CombatConfig.TouchLayout
		local size = if math.min(viewport.X, viewport.Y) >= layout.LargeScreenMinSide
			then layout.Large
			else layout.Small
		rightMargin = size.AmmoRightMargin
	end
	ammoBlock.Position = UDim2.new(1, -rightMargin, 1, -MARGIN)
end

local function refreshWeapons()
	local loadout = WeaponController.getLoadout()
	local equipped = WeaponController.getEquippedSlot()
	for _, slot in { "primary", "secondary", "melee" } do
		local name = slotLabels[slot]
		local id: string? = nil
		if loadout then
			id = if slot == "primary"
				then loadout.primary
				elseif slot == "secondary" then loadout.secondary
				else loadout.melee
		end
		slotRows[slot].Visible = id ~= nil
		name.Text = if id then TextUtil.upper(Strings.Weapons[id] or id) else ""
		name.TextColor3 = if slot == equipped then Theme.Color.TextPrimary else Theme.Color.TextSecondary
		name.FontFace = if slot == equipped then Theme.Font.Title else Theme.Font.BodyStrong
	end
	slotRows.reload.Visible = equipped ~= "melee"
end

-- Retícula -------------------------------------------------------------------------------------------

local function crosshairPiece(
	size: UDim2,
	position: UDim2,
	color: Color3,
	outline: boolean,
	outlineOpacity: number
): Frame
	local piece = frame("Piece", crosshair)
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.Size = size
	piece.Position = position
	piece.BackgroundColor3 = color
	piece.BackgroundTransparency = 0
	if outline then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Transparency = 1 - outlineOpacity
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = piece
	end
	return piece
end

local function buildCrosshair(settings: PlayerData.CrosshairSettings)
	crosshair:ClearAllChildren()
	local ok, color = pcall(Color3.fromHex, settings.color)
	local c = if ok then color else Color3.new(1, 1, 1)
	local length = 2 + settings.size * 2
	local thick = settings.thickness
	local gap = settings.gap
	local shape = settings.shape
	local center = UDim2.fromScale(0.5, 0.5)

	if shape == "cross" or shape == "cross_dot" then
		local offset = gap + length / 2
		crosshairPiece(
			UDim2.fromOffset(length, thick),
			center + UDim2.fromOffset(-offset, 0),
			c,
			settings.outline,
			settings.outlineOpacity
		)
		crosshairPiece(
			UDim2.fromOffset(length, thick),
			center + UDim2.fromOffset(offset, 0),
			c,
			settings.outline,
			settings.outlineOpacity
		)
		crosshairPiece(
			UDim2.fromOffset(thick, length),
			center + UDim2.fromOffset(0, -offset),
			c,
			settings.outline,
			settings.outlineOpacity
		)
		crosshairPiece(
			UDim2.fromOffset(thick, length),
			center + UDim2.fromOffset(0, offset),
			c,
			settings.outline,
			settings.outlineOpacity
		)
	end
	if shape == "dot" or shape == "cross_dot" then
		local dot = math.max(2, thick + 1)
		crosshairPiece(UDim2.fromOffset(dot, dot), center, c, settings.outline, settings.outlineOpacity)
	end
	if shape == "circle" then
		local diameter = gap * 2 + length * 2
		local ring = frame("Ring", crosshair)
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
		crosshairPiece(UDim2.fromOffset(2, 2), center, c, settings.outline, settings.outlineOpacity)
	end
end

local function buildHitMarker()
	hitMarker = frame("HitMarker", gui)
	hitMarker.AnchorPoint = Vector2.new(0.5, 0.5)
	hitMarker.Position = UDim2.fromScale(0.5, 0.5)
	hitMarker.Size = UDim2.fromOffset(40, 40)
	hitMarker.Visible = false
	for i = 0, 3 do
		local angle = 45 + i * 90
		local piece = frame("Line", hitMarker)
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.BackgroundTransparency = 0
		piece.BackgroundColor3 = Theme.Combat.HitMarker
		piece.Size = UDim2.fromOffset(9, 2)
		local radius = 12
		piece.Position = UDim2.new(0.5, math.cos(math.rad(angle)) * radius, 0.5, math.sin(math.rad(angle)) * radius)
		piece.Rotation = angle
	end
end

-- Luneta: círculo transparente com o resto da tela escuro (o traço gigante do círculo cobre as bordas).
local function buildScope()
	scopeOverlay = frame("Scope", gui)
	scopeOverlay.Size = UDim2.fromScale(1, 1)
	scopeOverlay.Visible = false
	scopeOverlay.ZIndex = 0
	local lens = frame("Lens", scopeOverlay)
	lens.AnchorPoint = Vector2.new(0.5, 0.5)
	lens.Position = UDim2.fromScale(0.5, 0.5)
	lens.Size = UDim2.fromScale(0.9, 0.9)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = lens
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = lens
	local dark = Instance.new("UIStroke")
	dark.Color = Theme.Combat.ScopeDark
	dark.Transparency = Theme.ScopeDarkTransparency
	dark.Thickness = 4000
	dark.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	dark.Parent = lens
	for _, horizontal in { true, false } do
		local line = frame("Reticle", lens)
		line.BackgroundTransparency = 0
		line.BackgroundColor3 = Theme.Combat.ScopeReticle
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = if horizontal then UDim2.new(1, 0, 0, 2) else UDim2.new(0, 2, 1, 0)
	end
end

-- Eventos -------------------------------------------------------------------------------------------

local function onCombatEvent(kind: string, data: any)
	if kind == "Hit" then
		local hit = data :: CombatTypes.HitData
		hitMarkerUntil = os.clock() + FX.HitMarkerSeconds
		CombatEffects.damageNumber(hit.position, hit.damage, hit.toShield >= hit.damage)
		CombatEffects.playSound(if hit.shieldBroken then AudioConfig.ShieldBreak else AudioConfig.HitMarker)
	elseif kind == "Kill" then
		local kill = data :: CombatTypes.KillData
		local format = if kill.kills == 1 then Strings.Combat.KillSingular else Strings.Combat.KillPlural
		killText.Text = string.format(format, kill.kills)
		killUntil = os.clock() + CombatConfig.KillNotice.Seconds
		CombatEffects.playSound(AudioConfig.KillCrack)
		if Env.IsDev then
			devReport.Text = string.format(
				Strings.Dev.KnockReport,
				kill.victimName,
				kill.seconds,
				kill.shots,
				Strings.Weapons[kill.weaponId] or kill.weaponId
			)
		end
	end
end

local function update()
	local character = player.Character
	local alive = character ~= nil and character:GetAttribute(ATTR.Alive) == true
	knockedText.Visible = character == nil
	crosshair.Visible = alive and not WeaponController.isScopedSniper()
	scopeOverlay.Visible = alive and WeaponController.isScopedSniper()

	if character then
		local hp = (character:GetAttribute(ATTR.Hp) :: number?) or HEALTH.MaxHp
		local shield = (character:GetAttribute(ATTR.Shield) :: number?) or HEALTH.MaxShield
		hpFill.Size = UDim2.fromScale(math.clamp(hp / HEALTH.MaxHp, 0, 1), 1)
		shieldFill.Size = UDim2.fromScale(math.clamp(shield / HEALTH.MaxShield, 0, 1), 1)
		hpText.Text = tostring(hp)
		shieldText.Text = tostring(shield)
	end

	local state = WeaponController.getCurrentGun()
	if state then
		local reloading = WeaponState.isReloading(state, workspace:GetServerTimeNow())
		ammoText.Text = if reloading then Strings.Combat.Reloading else `{state.ammo} | {Strings.Combat.Infinite}`
		ammoText.TextSize = if reloading then Theme.TextSize.Title else 34
		weaponText.Text = TextUtil.upper(Strings.Weapons[state.def.id] or state.def.id)
	else
		ammoText.Text = ""
		weaponText.Text = TextUtil.upper(Strings.Weapons[WeaponConfig.Melee.id] or "")
	end

	local clock = os.clock()
	hitMarker.Visible = clock < hitMarkerUntil
	killText.Visible = clock < killUntil
	devReport.Visible = clock < killUntil + 4
end

function CombatHUD.Start()
	gui = Instance.new("ScreenGui")
	gui.Name = "CombatHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 1

	buildScope()
	buildHealth()
	buildAmmo()
	crosshair = frame("Crosshair", gui)
	crosshair.Size = UDim2.fromScale(1, 1)
	buildHitMarker()

	killText = label("KillNotice", Theme.Font.Title, 36, Theme.Color.TextPrimary, gui)
	killText.AnchorPoint = Vector2.new(0.5, 1)
	killText.Position = UDim2.new(0.5, 0, 1, -120)
	killText.Size = UDim2.fromOffset(300, 44)
	killText.Visible = false

	devReport = label("DevKnockReport", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary, gui)
	devReport.AnchorPoint = Vector2.new(0.5, 1)
	devReport.Position = UDim2.new(0.5, 0, 1, -96)
	devReport.Size = UDim2.fromOffset(500, 20)
	devReport.Visible = false

	knockedText = label("Knocked", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, gui)
	knockedText.AnchorPoint = Vector2.new(0.5, 0.5)
	knockedText.Position = UDim2.fromScale(0.5, 0.4)
	knockedText.Size = UDim2.fromOffset(400, 40)
	knockedText.Text = TextUtil.upper(Strings.Combat.KnockedOut)
	knockedText.Visible = false

	local defaultCrosshair = PlayerDataClient.get()
	if defaultCrosshair then
		buildCrosshair(defaultCrosshair.settings.crosshair)
	end
	PlayerDataClient.onChanged(function(profile: PlayerData.Profile)
		buildCrosshair(profile.settings.crosshair)
	end)

	layoutForDevice()
	refreshWeapons()
	InputDevice.onChanged(layoutForDevice)
	WeaponController.onChanged(refreshWeapons)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutForDevice)
	end
	Remotes.event("CombatEvent").OnClientEvent:Connect(onCombatEvent)
	RunService.RenderStepped:Connect(update)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return CombatHUD
