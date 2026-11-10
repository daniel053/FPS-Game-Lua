--!strict
-- Tarefa "olhe para os 3 marcadores" (Movimento, GDD 5.2). Só o cliente sabe para onde a câmera
-- aponta: cada marcador olhado fica verde (só nesta tela) e, com todos vistos, o cliente avisa o
-- servidor ("Looked"). Não dá nada ao jogador além de passar desta tarefa.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local TutorialConfig = require(Shared.Config.TutorialConfig)
local TutorialTypes = require(Shared.Tutorial.TutorialTypes)

local TutorialClient = require(script.Parent.TutorialClient)

local CONE = math.cos(math.rad(TutorialConfig.Movement.LookConeDegrees))

local LookTask = {}

local seen: { [BasePart]: boolean } = {}
local sent = false

local function active(): boolean
	local s = TutorialClient.get()
	if s == nil or s.stepId ~= "Movement" or s.phase ~= "Doing" then
		return false
	end
	local current = s.tasks[s.taskIndex]
	return current ~= nil and current.kind == "Look"
end

local function check()
	if not active() then
		return
	end
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local origin = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local markers = CollectionService:GetTagged(TutorialTypes.Attr.LookMarker)
	local count = 0
	for _, marker in markers do
		if not marker:IsA("BasePart") then
			continue
		end
		if not seen[marker] then
			local direction = (marker.Position - origin).Unit
			if direction:Dot(look) >= CONE then
				seen[marker] = true
				marker.Color = Theme.Color.Success -- só nesta tela
			end
		end
		if seen[marker] then
			count += 1
		end
	end
	if count >= math.min(TutorialConfig.Movement.LookMarkers, #markers) and count > 0 and not sent then
		sent = true
		TutorialClient.request("Looked")
	end
end

function LookTask.Start()
	local wasActive = false
	TutorialClient.onChanged(function()
		local now = active()
		if now and not wasActive then
			-- Entrou nesta tarefa (ou voltou a ela): começa do zero
			sent = false
			table.clear(seen)
		end
		wasActive = now
	end)
	RunService.RenderStepped:Connect(check)
end

return LookTask
