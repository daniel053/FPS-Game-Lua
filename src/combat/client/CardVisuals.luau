--!strict
-- Efeitos visuais PROVISÓRIOS das cartas (FASES F4; arte final na F10). Brilho só aqui (ESTILO 2.6):
-- curto, uma cor por carta, nunca piscando.
--   * Nuvem: a bola voando em arco (o servidor cria a nuvem onde ela bate); a nuvem cresce ao
--     aparecer; dentro dela a tela fica coberta de névoa; do mirante ela fica translúcida, para dar
--     para assistir o duelo de cima (FASES F4: "efeitos legíveis de cima").
--   * Tremor: faixa âmbar que corre pelo chão até o fim da onda.
--   * Renascer: anel que se abre na marca quando o jogador volta.

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

local CombatEffects = require(script.Parent.CombatEffects)
local MatchUi = require(Shared.Ui.ProvisionalUi)
local Smoke = require(script.Parent.Smoke)

local NAMES = CardTypes.Names
local NUVEM = CardConfig.get("card_nuvem") :: CardConfig.CardDef

local CardVisuals = {}

local player = Players.LocalPlayer
local overlay: Frame

local function onMirante(): boolean
	return player:GetAttribute(MatchTypes.Attr.Location) == MatchTypes.MiranteLocation
end

local function fxPart(name: string, shape: Enum.PartType, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = Theme.CardFxTransparency
	part.Parent = CombatEffects.getFolder()
	return part
end

local function fadeAndDestroy(part: BasePart, seconds: number)
	local tween = TweenService:Create(part, TweenInfo.new(seconds), { Transparency = 1 })
	tween.Completed:Connect(function()
		part:Destroy()
	end)
	tween:Play()
end

-- Nuvem ------------------------------------------------------------------------------------------

local function onNuvemThrow(data: CardTypes.NuvemThrowData)
	local ball = fxPart("NuvemBola", Enum.PartType.Ball, Theme.Cards.card_nuvem)
	ball.Size = Vector3.one * 0.9
	ball.Position = data.origin
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min(os.clock() - started, data.flight)
		ball.Position = data.origin + data.velocity * t + Vector3.new(0, -0.5 * data.gravity * t * t, 0)
		if t >= data.flight then
			connection:Disconnect()
			ball:Destroy()
		end
	end)
end

local function styleSmoke(part: BasePart)
	-- Do mirante: translúcida (LocalTransparencyModifier só muda nesta tela)
	part.LocalTransparencyModifier = if onMirante() then NUVEM.params.MiranteTransparency else 0
end

local function onSmokeAdded(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	styleSmoke(instance)
	-- Cresce ao aparecer (só nesta tela; a nuvem "de verdade" já está no tamanho certo)
	local full = instance.Size
	instance.Size = full * 0.3
	TweenService:Create(instance, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = full })
		:Play()
end

local function restyleAll()
	for _, smoke in Smoke.all() do
		styleSmoke(smoke)
	end
end

-- Tremor -----------------------------------------------------------------------------------------

local function onTremorWave(data: CardTypes.TremorWaveData)
	if data.length <= 0.1 then
		return
	end
	local strip = fxPart("TremorOnda", Enum.PartType.Block, Theme.Cards.card_tremor)
	local base =
		CFrame.lookAt(data.origin + Vector3.new(0, 0.15, 0), data.origin + data.direction + Vector3.new(0, 0.15, 0))
	local seconds = data.length / math.max(data.speed, 1)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local progress = math.min((os.clock() - started) / seconds, 1)
		local length = math.max(0.2, data.length * progress)
		strip.Size = Vector3.new(data.width, 0.3, length)
		strip.CFrame = base * CFrame.new(0, 0, -length / 2)
		if progress >= 1 then
			connection:Disconnect()
			fadeAndDestroy(strip, 0.35)
		end
	end)
end

-- Renascer ---------------------------------------------------------------------------------------

local function onRenascerReturn(data: CardTypes.RenascerReturnData)
	local ring = fxPart("RenascerVolta", Enum.PartType.Cylinder, Theme.Cards.card_renascer)
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.CFrame = CFrame.new(data.to - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	TweenService:Create(ring, TweenInfo.new(0.45), { Size = Vector3.new(0.2, 9, 9), Transparency = 1 }):Play()
	task.delay(0.5, function()
		ring:Destroy()
	end)
end

-- Dentro da nuvem: névoa na tela (quem está no mirante não tem) ------------------------------------

local function stepOverlay()
	local camera = workspace.CurrentCamera
	local inside = camera ~= nil and not onMirante() and Smoke.containing(camera.CFrame.Position) ~= nil
	overlay.Visible = inside
end

function CardVisuals.Start()
	local gui = MatchUi.screen("CardSmokeOverlay", 0, Enum.ScreenInsets.None)
	overlay = MatchUi.frame("Fog", gui)
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Cards.Smoke
	overlay.BackgroundTransparency = NUVEM.params.InsideOverlayTransparency
	overlay.Visible = false
	gui.Parent = player:WaitForChild("PlayerGui")

	Remotes.event("CardFx").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "NuvemThrow" then
			onNuvemThrow(data :: CardTypes.NuvemThrowData)
		elseif kind == "TremorWave" then
			onTremorWave(data :: CardTypes.TremorWaveData)
		elseif kind == "RenascerReturn" then
			onRenascerReturn(data :: CardTypes.RenascerReturnData)
		end
	end)

	CollectionService:GetInstanceAddedSignal(NAMES.SmokeTag):Connect(onSmokeAdded)
	for _, smoke in Smoke.all() do
		styleSmoke(smoke)
	end
	player:GetAttributeChangedSignal(MatchTypes.Attr.Location):Connect(restyleAll)
	RunService.RenderStepped:Connect(stepOverlay)
end

return CardVisuals
