--!strict
-- Vidro da parede invisível da base (MapConfig.BaseBarrier). A parede é do servidor
-- (match/server/BaseBarriers) e só fica de pé no sorteio e na preparação. Aqui, cada painel com vidro
-- ganha um desenho só na tela de quem joga: chegando perto, aparece um vidro azul-escuro com linhas
-- finas de neon subindo devagar e, de tempos em tempos, uma faixa clara. Longe, nada aparece.
-- Feito com SurfaceGui (sem material Neon nem imagem): leve no celular, e só os painéis perto de
-- quem joga são animados.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local MapConfig = require(Shared.Config.MapConfig)
local Theme = require(Shared.Config.Theme)

local CFG = MapConfig.BaseBarrier
local GLASS = Theme.Match.BaseBarrierGlass
local LINE = Theme.Match.BaseBarrierLine

-- Mesmos nomes do match/server/BaseBarriers
local FOLDER_NAME = "BaseBarriers"
local ACTIVE = "Active"
local GLASS_TAG = "BaseBarrierGlass"

local LINE_PIXELS = 2
local SWEEP_STUDS = 1.6 -- altura da faixa clara
local SWEEP_SPEED = 9 -- studs por segundo

type Face = {
	gui: SurfaceGui,
	back: Frame,
	stroke: UIStroke,
	lines: { Frame },
	sweep: Frame,
}

type Panel = {
	part: BasePart,
	faces: { Face },
	height: number,
	alpha: number,
}

local BaseBarrierFx = {}

local panels: { [BasePart]: Panel } = {}
local folder: Instance? = nil

local function makeFace(part: BasePart, face: Enum.NormalId, height: number): Face
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BarrierGlass"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = CFG.PixelsPerStud
	gui.LightInfluence = 0 -- não escurece com a sombra: brilho leve de neon
	gui.Brightness = 1.2
	gui.AlwaysOnTop = false
	gui.ClipsDescendants = true
	gui.Enabled = false
	gui.Adornee = part

	local back = Instance.new("Frame")
	back.Name = "Glass"
	back.BorderSizePixel = 0
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = GLASS
	back.BackgroundTransparency = 1
	back.ClipsDescendants = true
	back.Parent = gui

	-- Mais forte embaixo, sumindo para cima: a parede não parece um teto
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	fade.Parent = back

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = LINE
	stroke.Thickness = LINE_PIXELS
	stroke.Transparency = 1
	stroke.Parent = back

	local lines: { Frame } = {}
	local count = math.ceil(height / CFG.LineSpacing) + 1
	for i = 1, count do
		local line = Instance.new("Frame")
		line.Name = `Line{i}`
		line.BorderSizePixel = 0
		line.BackgroundColor3 = LINE
		line.BackgroundTransparency = 1
		line.Size = UDim2.new(1, 0, 0, LINE_PIXELS)
		line.Parent = back
		table.insert(lines, line)
	end

	local sweep = Instance.new("Frame")
	sweep.Name = "Sweep"
	sweep.BorderSizePixel = 0
	sweep.BackgroundColor3 = LINE
	sweep.BackgroundTransparency = 1
	sweep.Size = UDim2.new(1, 0, 0, math.floor(SWEEP_STUDS * CFG.PixelsPerStud))
	local sweepFade = Instance.new("UIGradient")
	sweepFade.Rotation = 90
	sweepFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	sweepFade.Parent = sweep
	sweep.Parent = back

	gui.Parent = part
	return { gui = gui, back = back, stroke = stroke, lines = lines, sweep = sweep }
end

local function addPanel(part: Instance)
	if not part:IsA("BasePart") or panels[part] then
		return
	end
	local height = part.Size.Y
	panels[part] = {
		part = part,
		-- As duas faces largas do painel (fino no eixo Z local)
		faces = { makeFace(part, Enum.NormalId.Front, height), makeFace(part, Enum.NormalId.Back, height) },
		height = height,
		alpha = 0,
	}
end

local function removePanel(part: Instance)
	local panel = panels[part :: BasePart]
	if panel then
		for _, face in panel.faces do
			face.gui:Destroy()
		end
		panels[part :: BasePart] = nil
	end
end

-- Distância do ponto até o retângulo do painel.
local function distanceTo(part: BasePart, position: Vector3): number
	local p = part.CFrame:PointToObjectSpace(position)
	local size = part.Size
	local dx = math.max(0, math.abs(p.X) - size.X / 2)
	local dy = math.max(0, math.abs(p.Y) - size.Y / 2)
	return Vector3.new(dx, dy, p.Z).Magnitude
end

local function alphaAt(distance: number): number
	if distance >= CFG.ShowDistance then
		return 0
	end
	local t = (CFG.ShowDistance - distance) / (CFG.ShowDistance - CFG.FullDistance)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t) -- entra suave
end

local function draw(panel: Panel, alpha: number, now: number)
	local visible = alpha > 0.01
	local spacing = CFG.LineSpacing * CFG.PixelsPerStud
	local heightPx = panel.height * CFG.PixelsPerStud
	-- Linhas subindo: o deslocamento dá a volta a cada espaçamento
	local offset = (now * CFG.LineSpeed * CFG.PixelsPerStud) % spacing
	-- Faixa clara: sobe a parede inteira e espera até a próxima
	local cycle = now % CFG.SweepEvery
	local sweepY = heightPx - cycle * SWEEP_SPEED * CFG.PixelsPerStud
	for _, face in panel.faces do
		face.gui.Enabled = visible
		if not visible then
			continue
		end
		face.back.BackgroundTransparency = 1 - CFG.GlassOpacity * alpha
		face.stroke.Transparency = 1 - CFG.EdgeOpacity * alpha
		for i, line in face.lines do
			local y = heightPx - ((i - 1) * spacing + offset)
			line.Position = UDim2.fromOffset(0, math.floor(y))
			line.BackgroundTransparency = 1 - CFG.LineOpacity * alpha
		end
		face.sweep.Position = UDim2.fromOffset(0, math.floor(sweepY))
		face.sweep.BackgroundTransparency = 1 - CFG.SweepOpacity * alpha
	end
end

local function hideAll()
	for _, panel in panels do
		if panel.alpha > 0 then
			panel.alpha = 0
			draw(panel, 0, 0)
		end
	end
end

local function step()
	local barriers = folder
	if barriers == nil or barriers:GetAttribute(ACTIVE) ~= true then
		hideAll()
		return
	end
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		hideAll()
		return
	end
	local position = root.Position
	local now = os.clock()
	for _, panel in panels do
		local alpha = alphaAt(distanceTo(panel.part, position))
		if alpha > 0 or panel.alpha > 0 then
			panel.alpha = alpha
			draw(panel, alpha, now)
		end
	end
end

function BaseBarrierFx.Start()
	CollectionService:GetInstanceAddedSignal(GLASS_TAG):Connect(addPanel)
	CollectionService:GetInstanceRemovedSignal(GLASS_TAG):Connect(removePanel)
	for _, part in CollectionService:GetTagged(GLASS_TAG) do
		addPanel(part)
	end
	task.spawn(function()
		folder = workspace:WaitForChild(FOLDER_NAME, 60)
	end)
	RunService.Heartbeat:Connect(step)
end

return BaseBarrierFx
