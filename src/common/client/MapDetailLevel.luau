--!strict
-- Versão leve dos mapas no cliente (GDD 13.2, F10). Esconde, só nesta tela, as peças de acabamento
-- pequenas (MapDetail.isOptional) do mundo da partida e do lobby, quando:
--   * o jogador escolheu um gráfico baixo no menu do Roblox (nível 1 a LightQualityMax); ou
--   * o gráfico está no automático e a média de quadros fica abaixo de LowFps por LowFpsSeconds
--     seguidos (aí fica leve até o fim da sessão, para não ficar trocando).
-- Nada que colide ou que sinaliza (setas, faixas de aviso) some. Funciona com o streaming: as peças
-- que chegam depois também são conferidas. O painel TESTE mostra os quadros e o modo (só DEV_).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Build = require(Shared.Maps.Build)
local MapConfig = require(Shared.Config.MapConfig)
local MapDetail = require(Shared.Maps.MapDetail)

local PERF = MapConfig.Performance
local WORLD_NAMES = { "MatchWorld", "LobbyWorld", "LobbyBackdrop" }

local MapDetailLevel = {}

-- reason: chave de Strings.Dev.DetailModes
export type Stats = { fps: number, light: boolean, reason: string, hidden: number }

local light = false
local reason = "Full" -- chave de Strings.Dev.DetailModes
local forcedByFps = false
local forcedByPanel = false
local hidden: { [BasePart]: boolean } = {}
local fps = 60
local listeners: { (Stats) -> () } = {}

local function savedQuality(): number?
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok or level == Enum.SavedQualitySetting.Automatic then
		return nil
	end
	return (level :: Enum.SavedQualitySetting).Value
end

local function apply(part: Instance)
	if part:IsA("Light") and part:GetAttribute(Build.LightAttribute) == true then
		-- Luzes de cenário (Porto) apagam na versão leve, só nesta tela
		part.Enabled = not light
	elseif part:IsA("BasePart") and MapDetail.isOptional(part) then
		if light then
			part.LocalTransparencyModifier = 1
			hidden[part] = true
		elseif hidden[part] then
			part.LocalTransparencyModifier = 0
			hidden[part] = nil
		end
	end
end

local function applyAll()
	for _, name in WORLD_NAMES do
		local world = workspace:FindFirstChild(name)
		if world then
			for _, part in world:GetDescendants() do
				apply(part)
			end
		end
	end
end

local function count(): number
	local n = 0
	for part in hidden do
		if part.Parent then
			n += 1
		else
			hidden[part] = nil
		end
	end
	return n
end

local function setLight(on: boolean, why: string)
	reason = why
	if on == light then
		return
	end
	light = on
	applyAll()
end

local function decide()
	local quality = savedQuality()
	if forcedByPanel then
		setLight(true, "Forced")
	elseif quality then
		forcedByFps = false
		setLight(quality <= PERF.LightQualityMax, if quality <= PERF.LightQualityMax then "LowQuality" else "Full")
	elseif forcedByFps then
		setLight(true, "LowFps")
	else
		setLight(false, "FullAuto")
	end
end

local function watchWorld(world: Instance)
	world.DescendantAdded:Connect(apply)
	for _, part in world:GetDescendants() do
		apply(part)
	end
end

function MapDetailLevel.stats(): Stats
	return { fps = fps, light = light, reason = reason, hidden = count() }
end

-- Painel TESTE (só DEV_): liga e desliga a versão leve para comparar no aparelho.
function MapDetailLevel.toggleForced()
	forcedByPanel = not forcedByPanel
	decide()
end

function MapDetailLevel.onStats(callback: (Stats) -> ())
	table.insert(listeners, callback)
end

function MapDetailLevel.Start()
	decide()
	for _, name in WORLD_NAMES do
		local world = workspace:FindFirstChild(name)
		if world then
			watchWorld(world)
		end
	end
	workspace.ChildAdded:Connect(function(child)
		if table.find(WORLD_NAMES, child.Name) then
			watchWorld(child)
		end
	end)
	pcall(function()
		UserSettings():GetService("UserGameSettings").Changed:Connect(function(property)
			if property == "SavedQualityLevel" then
				decide()
			end
		end)
	end)

	-- Média de quadros por segundo (janela de 1 s) e queda sustentada
	local frames, elapsed, lowFor = 0, 0, 0
	RunService.RenderStepped:Connect(function(dt: number)
		frames += 1
		elapsed += dt
		if elapsed < 1 then
			return
		end
		fps = frames / elapsed
		frames, elapsed = 0, 0
		if fps < PERF.LowFps then
			lowFor += 1
		else
			lowFor = 0
		end
		if lowFor >= PERF.LowFpsSeconds and not forcedByFps and savedQuality() == nil then
			forcedByFps = true
			decide()
		end
		local stats = MapDetailLevel.stats()
		for _, callback in listeners do
			task.spawn(callback, stats)
		end
	end)
end

return MapDetailLevel
