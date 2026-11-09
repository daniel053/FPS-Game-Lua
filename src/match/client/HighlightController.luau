--!strict
-- Contornos (GDD 7.6) [DECIDIDO]:
--   * inimigo: contorno vermelho (ou a cor de acessibilidade do perfil) só no que está VISÍVEL;
--     não aparece através de paredes;
--   * parceiro: contorno na cor da equipe SÓ quando o corpo inteiro está escondido. A cada 0,1 s,
--     raios da câmera até cabeça, tronco, mãos e pés: todos bloqueados = mostra; algum livre = esconde;
--   * parceiro visível: sem contorno, com o nome sobre a cabeça.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local TeamColors = require(Shared.Config.TeamColors)
local Theme = require(Shared.Config.Theme)
local Types = require(Shared.Types)

local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local CombatEffects = require(script.Parent.CombatEffects)

local ATTR = CombatNames.Attr

-- Pontos do corpo checados para o contorno do parceiro (R15 e R6)
local BODY_POINTS = {
	{ "Head" },
	{ "UpperTorso", "Torso" },
	{ "LeftHand", "Left Arm" },
	{ "RightHand", "Right Arm" },
	{ "LeftFoot", "Left Leg" },
	{ "RightFoot", "Right Leg" },
}

type Tracked = {
	model: Model,
	highlight: Highlight,
	nameTag: BillboardGui?,
	connections: { RBXScriptConnection },
}

local HighlightController = {}

local player = Players.LocalPlayer
local tracked: { [Model]: Tracked } = {}

local sightParams = RaycastParams.new()
sightParams.CollisionGroup = CombatNames.Groups.SightRay
sightParams.FilterType = Enum.RaycastFilterType.Exclude

local function myTeam(): string?
	local teamId = player:GetAttribute(ATTR.TeamId)
	return if typeof(teamId) == "string" then teamId else nil
end

local function enemyColor(): Color3
	local profile = PlayerDataClient.get()
	local choice = if profile then profile.settings.enemyOutlineColor else "red"
	return Theme.EnemyOutline[choice] or Theme.EnemyOutline.red
end

local function teamColor(teamId: string): Color3
	if Theme.Team[teamId :: Types.TeamColorId] then
		return TeamColors.getColor(teamId :: Types.TeamColorId)
	end
	return Theme.Color.TextPrimary
end

local function isPartner(model: Model): boolean
	return model ~= player.Character and model:GetAttribute(ATTR.TeamId) == myTeam()
end

local function makeNameTag(model: Model): BillboardGui?
	local head = model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PartnerName"
	gui.Size = UDim2.fromOffset(200, 24)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.FontFace = Theme.Font.BodyStrong
	text.TextSize = Theme.TextSize.Body
	text.TextColor3 = Theme.Color.TextPrimary
	text.TextStrokeTransparency = 0.3
	local name = model:GetAttribute(ATTR.DisplayName)
	text.Text = if typeof(name) == "string" then name else model.Name
	text.Parent = gui
	gui.Adornee = head
	gui.Parent = CombatEffects.getFolder()
	return gui
end

-- Atualiza o tipo de contorno de um modelo (inimigo, parceiro, eu).
local function refresh(entry: Tracked)
	local model = entry.model
	local highlight = entry.highlight
	local alive = model:GetAttribute(ATTR.Alive) == true
	if model == player.Character or not alive then
		highlight.Enabled = false
		if entry.nameTag then
			entry.nameTag.Enabled = false
		end
		return
	end
	if isPartner(model) then
		local teamId = model:GetAttribute(ATTR.TeamId)
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.OutlineColor = teamColor(if typeof(teamId) == "string" then teamId else "")
		-- Liga/desliga na checagem de visibilidade
		if entry.nameTag == nil then
			entry.nameTag = makeNameTag(model)
		end
		if entry.nameTag then
			entry.nameTag.Enabled = true
		end
	else
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded -- só desenha o que está visível
		highlight.OutlineColor = enemyColor()
		highlight.Enabled = true
		if entry.nameTag then
			entry.nameTag.Enabled = false
		end
	end
end

local function track(instance: Instance)
	if not instance:IsA("Model") or tracked[instance] then
		return
	end
	local model = instance
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0
	highlight.Enabled = false
	highlight.Adornee = model
	highlight.Parent = CombatEffects.getFolder()
	local entry: Tracked = { model = model, highlight = highlight, nameTag = nil, connections = {} }
	tracked[model] = entry
	table.insert(
		entry.connections,
		model:GetAttributeChangedSignal(ATTR.TeamId):Connect(function()
			refresh(entry)
		end)
	)
	table.insert(
		entry.connections,
		model:GetAttributeChangedSignal(ATTR.Alive):Connect(function()
			refresh(entry)
		end)
	)
	refresh(entry)
end

local function untrack(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local entry = tracked[instance]
	if entry == nil then
		return
	end
	tracked[instance] = nil
	for _, connection in entry.connections do
		connection:Disconnect()
	end
	entry.highlight:Destroy()
	if entry.nameTag then
		entry.nameTag:Destroy()
	end
end

-- Todos os pontos do corpo bloqueados por parede/obstáculo?
local function fullyHidden(model: Model, origin: Vector3): boolean
	local filter: { Instance } = { model, CombatEffects.getFolder() }
	if player.Character then
		table.insert(filter, player.Character)
	end
	local camera = workspace.CurrentCamera
	if camera then
		table.insert(filter, camera)
	end
	sightParams.FilterDescendantsInstances = filter
	for _, names in BODY_POINTS do
		for _, name in names do
			local part = model:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				if workspace:Raycast(origin, part.Position - origin, sightParams) == nil then
					return false -- esta parte está à vista
				end
				break
			end
		end
	end
	return true
end

local function checkPartners()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local origin = camera.CFrame.Position
	for model, entry in tracked do
		if model ~= player.Character and model:GetAttribute(ATTR.Alive) == true and isPartner(model) then
			entry.highlight.Enabled = fullyHidden(model, origin)
		end
	end
end

local function refreshAll()
	for _, entry in tracked do
		refresh(entry)
	end
end

function HighlightController.Start()
	CollectionService:GetInstanceAddedSignal(CombatNames.CombatantTag):Connect(track)
	CollectionService:GetInstanceRemovedSignal(CombatNames.CombatantTag):Connect(untrack)
	for _, instance in CollectionService:GetTagged(CombatNames.CombatantTag) do
		track(instance)
	end
	player:GetAttributeChangedSignal(ATTR.TeamId):Connect(refreshAll)
	player.CharacterAdded:Connect(function()
		task.defer(refreshAll)
	end)
	PlayerDataClient.onChanged(refreshAll)

	task.spawn(function()
		while true do
			checkPartners()
			task.wait(CombatConfig.Outline.PartnerCheckSeconds)
		end
	end)
end

return HighlightController
