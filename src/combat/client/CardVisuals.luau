--!strict
-- Efeitos visuais FINAIS das cartas (FASES F10). Brilho só aqui (ESTILO 2.6, GDD 14): curto, uma cor
-- por carta, nunca piscando e nunca cobrindo a tela. Com "reduzir efeitos", menos peças e mais curto.
--   * Nuvem (lilás): a bola brilhante voa em arco deixando um rastro curto; onde ela bate, a nuvem do
--     servidor (uma esfera, que é o que bloqueia a visão) ganha um contorno de nuvem de desenho
--     animado (bolas foscas em volta), cresce ao aparecer e se desfaz no fim. Dentro dela a tela fica
--     coberta de névoa; do mirante ela fica translúcida, para dar para assistir.
--   * Impulso (azul-céu): anel que se abre no chão e riscos curtos subindo de quem saltou.
--   * Tremor (âmbar): faixa brilhante que corre pelo chão e pedras que sobem e afundam quando a onda
--     passa (as pedras são foscas, cor de terra).
--   * Renascer (verde-menta): a marca vira um selo de 6 lados no chão; na volta, uma coluna de luz
--     curta e o anel.
-- Tudo só na tela de cada um (pasta CombatEffects, ignorada pelos raios).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local CardConfig = require(Shared.Config.CardConfig)
local CardTypes = require(Shared.Cards.CardTypes)
local MatchTypes = require(Shared.Match.MatchTypes)
local Remotes = require(Shared.Remotes)
local Theme = require(Shared.Config.Theme)

local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local CombatEffects = require(script.Parent.CombatEffects)
local MatchUi = require(Shared.Ui.Ui)
local Smoke = require(script.Parent.Smoke)

local NAMES = CardTypes.Names
local NUVEM = CardConfig.get("card_nuvem") :: CardConfig.CardDef
local COLORS = Theme.Cards
local FX = Theme.CardFx

local CardVisuals = {}

local player = Players.LocalPlayer
local overlay: Frame

-- Contorno de cada nuvem e selo de cada marca (as bolas e barras feitas aqui)
local cloudPuffs: { [BasePart]: { BasePart } } = {}
local markSigils: { [BasePart]: { BasePart } } = {}

local function onMirante(): boolean
	return player:GetAttribute(MatchTypes.Attr.Location) == MatchTypes.MiranteLocation
end

local function reduced(): boolean
	local profile = PlayerDataClient.get()
	return profile ~= nil and profile.settings.reduceEffects
end

-- Peça de efeito: brilho (neon) só quando `glow`; o resto é fosco.
local function fxPart(name: string, shape: Enum.PartType, color: Color3, glow: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Color = color
	part.Transparency = if glow then Theme.CardFxTransparency else 0
	part.Parent = CombatEffects.getFolder()
	return part
end

local function fadeAndDestroy(part: BasePart, seconds: number, goal: { [string]: any }?)
	local props: { [string]: any } = goal or {}
	props.Transparency = 1
	local tween =
		TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), props)
	tween.Completed:Connect(function()
		part:Destroy()
	end)
	tween:Play()
end

-- Anel deitado no chão que se abre e some.
local function groundRing(center: Vector3, color: Color3, from: number, to: number, seconds: number)
	local ring = fxPart("Anel", Enum.PartType.Cylinder, color, true)
	ring.Size = Vector3.new(0.12, from, from)
	ring.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2)
	fadeAndDestroy(ring, seconds, { Size = Vector3.new(0.12, to, to) })
end

-- Nuvem ------------------------------------------------------------------------------------------

local function onNuvemThrow(data: CardTypes.NuvemThrowData)
	local ball = fxPart("NuvemBola", Enum.PartType.Ball, COLORS.card_nuvem, true)
	ball.Size = Vector3.one * FX.NuvemBallSize
	ball.Position = data.origin
	local trail = not reduced()
	local started = os.clock()
	local lastDrop = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min(os.clock() - started, data.flight)
		ball.Position = data.origin + data.velocity * t + Vector3.new(0, -0.5 * data.gravity * t * t, 0)
		if trail and t - lastDrop >= FX.NuvemTrailEvery then
			lastDrop = t
			local dot = fxPart("NuvemRastro", Enum.PartType.Ball, COLORS.card_nuvem, true)
			dot.Size = Vector3.one * FX.NuvemBallSize * 0.6
			dot.Position = ball.Position
			fadeAndDestroy(dot, FX.NuvemTrailSeconds, { Size = Vector3.one * 0.1 })
		end
		if t >= data.flight then
			connection:Disconnect()
			ball:Destroy()
		end
	end)
end

local function styleCloud(smoke: BasePart)
	local modifier = if onMirante() then NUVEM.params.MiranteTransparency else 0
	smoke.LocalTransparencyModifier = modifier
	local puffs: { BasePart } = cloudPuffs[smoke] or {}
	for _, puff in puffs do
		puff.LocalTransparencyModifier = modifier
	end
end

-- Contorno de nuvem: bolas foscas em volta da esfera, saindo um pouco dela (só visual; quem bloqueia
-- a visão é a esfera do servidor). Posições fixas de um icosaedro achatado, para toda nuvem ser igual.
local PUFFS = {
	Vector3.new(0, 0.55, 0),
	Vector3.new(0.62, 0.2, 0),
	Vector3.new(-0.62, 0.2, 0),
	Vector3.new(0, 0.2, 0.62),
	Vector3.new(0, 0.2, -0.62),
	Vector3.new(0.45, -0.25, 0.45),
	Vector3.new(-0.45, -0.25, 0.45),
	Vector3.new(0.45, -0.25, -0.45),
	Vector3.new(-0.45, -0.25, -0.45),
}

local function onSmokeAdded(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local smoke = instance
	local radius = smoke.Size.X / 2
	local puffs: { BasePart } = {}
	for i, offset in PUFFS do
		local puff = fxPart("NuvemBola", Enum.PartType.Ball, if i <= 5 then COLORS.Smoke else COLORS.SmokeShade, false)
		local size = radius * (if i == 1 then 1.25 else 1.05)
		puff.Size = Vector3.one * size * 0.3
		puff.Position = smoke.Position + offset * radius
		TweenService
			:Create(puff, TweenInfo.new(FX.NuvemGrowSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = Vector3.one * size,
			})
			:Play()
		table.insert(puffs, puff)
	end
	cloudPuffs[smoke] = puffs
	styleCloud(smoke)
	-- Cresce ao aparecer (só nesta tela; a nuvem "de verdade" já está no tamanho certo)
	local full = smoke.Size
	smoke.Size = full * 0.3
	TweenService
		:Create(
			smoke,
			TweenInfo.new(FX.NuvemGrowSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = full }
		)
		:Play()
	-- Quando o servidor tira a nuvem, o contorno se desfaz
	smoke.AncestryChanged:Connect(function(_, parent)
		if parent == nil and cloudPuffs[smoke] then
			for _, puff in cloudPuffs[smoke] do
				fadeAndDestroy(puff, FX.NuvemFadeSeconds, { Size = puff.Size * 0.4 })
			end
			cloudPuffs[smoke] = nil
		end
	end)
end

-- Tremor -----------------------------------------------------------------------------------------

local function onTremorWave(data: CardTypes.TremorWaveData)
	if data.length <= 0.1 then
		return
	end
	local strip = fxPart("TremorOnda", Enum.PartType.Block, COLORS.card_tremor, true)
	local base =
		CFrame.lookAt(data.origin + Vector3.new(0, 0.1, 0), data.origin + data.direction + Vector3.new(0, 0.1, 0))
	local seconds = data.length / math.max(data.speed, 1)
	local step = if reduced() then FX.TremorRockStep * 2 else FX.TremorRockStep
	local nextRock = step / 2
	local random = Random.new(math.floor(data.origin.X * 7 + data.origin.Z * 13))
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local progress = math.min((os.clock() - started) / seconds, 1)
		local length = math.max(0.2, data.length * progress)
		strip.Size = Vector3.new(data.width * 0.5, 0.2, length)
		strip.CFrame = base * CFrame.new(0, 0, -length / 2)
		-- Pedras: sobem do chão quando a onda passa e afundam de novo
		while nextRock <= length do
			for _, side in { -1, 1 } do
				local rock = fxPart("TremorPedra", Enum.PartType.Block, COLORS.TremorRock, false)
				local size = random:NextNumber(0.7, 1.3)
				rock.Size = Vector3.new(size, size * 1.4, size)
				local at = base
					* CFrame.new(side * data.width * random:NextNumber(0.2, 0.42), -size, -nextRock)
					* CFrame.Angles(
						random:NextNumber(-0.4, 0.4),
						random:NextNumber(0, math.pi),
						random:NextNumber(-0.4, 0.4)
					)
				rock.CFrame = at
				local up = TweenService:Create(
					rock,
					TweenInfo.new(FX.TremorRockRise, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ CFrame = at + Vector3.new(0, size * 1.2, 0) }
				)
				up.Completed:Connect(function()
					fadeAndDestroy(rock, FX.TremorRockSink, { CFrame = at })
				end)
				up:Play()
			end
			nextRock += step
		end
		if progress >= 1 then
			connection:Disconnect()
			fadeAndDestroy(strip, 0.35)
		end
	end)
end

-- Impulso ----------------------------------------------------------------------------------------

local function onImpulsoLaunch(data: CardTypes.ImpulsoLaunchData)
	local color = COLORS.card_impulso
	groundRing(data.feet + Vector3.new(0, 0.1, 0), color, 1.5, FX.ImpulsoRingSize, FX.ImpulsoSeconds)
	local streaks = if reduced() then 3 else 6
	for i = 1, streaks do
		local angle = i / streaks * math.pi * 2
		local at = data.feet + Vector3.new(math.cos(angle) * 1.4, 0.5, math.sin(angle) * 1.4)
		local streak = fxPart("ImpulsoRisco", Enum.PartType.Block, color, true)
		streak.Size = Vector3.new(0.15, 1.6, 0.15)
		streak.CFrame = CFrame.new(at)
		fadeAndDestroy(streak, FX.ImpulsoSeconds, { CFrame = CFrame.new(at + Vector3.new(0, FX.ImpulsoStreakRise, 0)) })
	end
end

-- Renascer ---------------------------------------------------------------------------------------

-- Selo de 6 lados no chão (no lugar do disco do servidor, que fica invisível nesta tela).
local function onMarkAdded(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local mark = instance
	mark.LocalTransparencyModifier = 1
	local center = mark.Position
	local color = COLORS.card_renascer
	local bars: { BasePart } = {}
	for _, ring in { { radius = 2, width = 0.22 }, { radius = 1.15, width = 0.16 } } do
		local side = ring.radius -- hexágono regular: lado = raio
		local apothem = ring.radius * math.sqrt(3) / 2
		for k = 0, 5 do
			local angle = k * math.pi / 3 + (if ring.radius < 2 then math.pi / 6 else 0)
			local bar = fxPart("RenascerSelo", Enum.PartType.Block, color, true)
			bar.Size = Vector3.new(side + ring.width, 0.08, ring.width)
			bar.CFrame = CFrame.new(center) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.04, -apothem)
			table.insert(bars, bar)
		end
	end
	local gem = fxPart("RenascerSelo", Enum.PartType.Block, color, true)
	gem.Size = Vector3.new(0.5, 0.08, 0.5)
	gem.CFrame = CFrame.new(center + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, math.pi / 4, 0)
	table.insert(bars, gem)
	markSigils[mark] = bars
	mark.AncestryChanged:Connect(function(_, parent)
		if parent == nil and markSigils[mark] then
			for _, bar in markSigils[mark] do
				fadeAndDestroy(bar, 0.3)
			end
			markSigils[mark] = nil
		end
	end)
end

local function onRenascerReturn(data: CardTypes.RenascerReturnData)
	local color = COLORS.card_renascer
	local feet = data.to - Vector3.new(0, 2.8, 0)
	groundRing(feet + Vector3.new(0, 0.1, 0), color, 1, 9, 0.45)
	local column = fxPart("RenascerColuna", Enum.PartType.Cylinder, color, true)
	local height = FX.RenascerColumnHeight
	column.Size = Vector3.new(height, 2.2, 2.2)
	column.CFrame = CFrame.new(feet + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	fadeAndDestroy(column, if reduced() then 0.25 else 0.5, { Size = Vector3.new(height, 0.2, 0.2) })
end

-- Dentro da nuvem: névoa na tela (quem está no mirante não tem) ------------------------------------

local function stepOverlay()
	local camera = workspace.CurrentCamera
	local inside = camera ~= nil and not onMirante() and Smoke.containing(camera.CFrame.Position) ~= nil
	overlay.Visible = inside
end

local function restyleAll()
	for _, smoke in Smoke.all() do
		styleCloud(smoke)
	end
end

function CardVisuals.Start()
	local gui = MatchUi.screen("CardSmokeOverlay", 0, Enum.ScreenInsets.None)
	overlay = MatchUi.frame("Fog", gui)
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = COLORS.Smoke
	overlay.BackgroundTransparency = NUVEM.params.InsideOverlayTransparency
	overlay.Visible = false
	gui.Parent = player:WaitForChild("PlayerGui")

	Remotes.event("CardFx").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "NuvemThrow" then
			onNuvemThrow(data :: CardTypes.NuvemThrowData)
		elseif kind == "TremorWave" then
			onTremorWave(data :: CardTypes.TremorWaveData)
		elseif kind == "ImpulsoLaunch" then
			onImpulsoLaunch(data :: CardTypes.ImpulsoLaunchData)
		elseif kind == "RenascerReturn" then
			onRenascerReturn(data :: CardTypes.RenascerReturnData)
		end
	end)

	CollectionService:GetInstanceAddedSignal(NAMES.SmokeTag):Connect(onSmokeAdded)
	for _, smoke in Smoke.all() do
		onSmokeAdded(smoke)
	end
	CollectionService:GetInstanceAddedSignal(NAMES.MarkTag):Connect(onMarkAdded)
	for _, mark in CollectionService:GetTagged(NAMES.MarkTag) do
		onMarkAdded(mark)
	end
	player:GetAttributeChangedSignal(MatchTypes.Attr.Location):Connect(restyleAll)
	RunService.RenderStepped:Connect(stepOverlay)
end

return CardVisuals
