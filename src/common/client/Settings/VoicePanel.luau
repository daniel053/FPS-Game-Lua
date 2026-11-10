--!strict
-- Etapa 5 do tutorial (GDD 5.2): voz. Explica por que falar com a dupla ajuda e:
--   * se o chat de voz está ligado na conta: medidor do microfone (se o Roblox der acesso ao áudio);
--   * se não está: como ativar nas configurações do Roblox (o jogo não liga nada sozinho).
-- "Agora não" é o botão de pular, sem culpa.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VoiceChatService = game:GetService("VoiceChatService")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.Ui)

local V = Strings.Tutorial.Voice
local METER_GAIN = 4 -- nível do microfone (0..~0,25 falando) para a barra (0..1)

export type Panel = { commit: () -> (), close: () -> () }

local VoicePanel = {}

local player = Players.LocalPlayer

-- Medidor do microfone com a API de áudio do Roblox. Devolve a função de limpar, ou nil se não deu.
local function startMeter(fill: Frame): (() -> ())?
	local input = player:FindFirstChildWhichIsA("AudioDeviceInput", true)
	if input == nil then
		return nil
	end
	local ok, analyzer = pcall(function(): Instance
		local a = Instance.new("AudioAnalyzer")
		local wire = Instance.new("Wire")
		wire.Parent = a;
		(wire :: any).SourceInstance = input;
		(wire :: any).TargetInstance = a
		a.Parent = player
		return a
	end)
	if not ok then
		return nil
	end
	local connection = RunService.RenderStepped:Connect(function()
		local level = (analyzer :: any).RmsLevel
		if typeof(level) == "number" then
			fill.Size = UDim2.fromScale(math.clamp(level * METER_GAIN, 0, 1), 1)
		end
	end)
	return function()
		connection:Disconnect()
		analyzer:Destroy()
	end
end

function VoicePanel.open(container: GuiObject): Panel
	local body = Ui.label("Body", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextPrimary, container)
	body.Size = UDim2.new(1, 0, 0, 60)
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Text = V.Body
	body.LayoutOrder = 1

	local status = Ui.label("Status", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextSecondary, container)
	status.Size = UDim2.new(1, 0, 0, 80)
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.Text = V.Checking
	status.LayoutOrder = 2

	local meter = Ui.frame("Meter", container)
	meter.Size = UDim2.new(1, 0, 0, 18)
	meter.BackgroundColor3 = Theme.Color.PanelRaised
	meter.BackgroundTransparency = 0
	meter.LayoutOrder = 3
	meter.Visible = false
	Ui.corner(meter, 9)
	local fill = Ui.frame("Fill", meter)
	fill.BackgroundColor3 = Theme.Color.Success
	fill.BackgroundTransparency = 0
	fill.Size = UDim2.fromScale(0, 1)
	Ui.corner(fill, 9)

	local closed = false
	local stopMeter: (() -> ())? = nil
	task.spawn(function()
		local ok, enabled = pcall(function(): boolean
			return VoiceChatService:IsVoiceEnabledForUserIdAsync(player.UserId)
		end)
		if closed then
			return
		end
		if ok and enabled then
			stopMeter = startMeter(fill)
			if stopMeter then
				status.Text = V.Enabled
				meter.Visible = true
			else
				status.Text = V.NoMeter
			end
		else
			status.Text = V.Disabled
		end
	end)

	local function close()
		closed = true
		if stopMeter then
			stopMeter()
			stopMeter = nil
		end
	end
	return { commit = close, close = close }
end

return VoicePanel
