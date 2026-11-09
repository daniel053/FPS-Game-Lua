--!strict
-- O que muda na tela de cada um conforme o lugar (GDD 6.5), tudo só no cliente:
--   * no mirante: telhados das ilhas quase transparentes e nomes das ilhas visíveis;
--   * numa ilha: telhados normais e os espectadores do mirante invisíveis (não revelam nada);
--   * zona (GDD 4.4): parede roxa bem transparente em volta de cada ilha com duelo, fechando
--     até o centro a partir dos 60 s de combate.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local MapConfig = require(Shared.Config.MapConfig)
local MatchTypes = require(Shared.Match.MatchTypes)
local Theme = require(Shared.Config.Theme)
local WorldLayout = require(Shared.Match.WorldLayout)

local MatchClient = require(script.Parent.MatchClient)

local ZONE_HEIGHT = 60
local REFRESH_SECONDS = 0.25

local MiranteView = {}

local player = Players.LocalPlayer
local zoneParts: { [number]: Part } = {}
local zoneFolder: Folder
local lastOnMirante: boolean? = nil
local hiddenByMe: { [Model]: boolean } = {}

local function applyRoofs(onMirante: boolean)
	local modifier = if onMirante then MapConfig.Mirante.RoofTransparencyForSpectators else 0
	for _, roof in CollectionService:GetTagged(MatchTypes.RoofTag) do
		if roof:IsA("BasePart") then
			roof.LocalTransparencyModifier = modifier
		end
	end
	for _, label in CollectionService:GetTagged("IslandLabel") do
		if label:IsA("BillboardGui") then
			label.Enabled = onMirante
		end
	end
end

local function setModifier(character: Model, value: number)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = value
		end
	end
end

-- Espectadores somem para quem está jogando numa ilha. Só desfaz o que esta tela escondeu
-- (o parceiro assistido é escondido pela SpectateCamera).
local function applySpectatorVisibility(onIsland: boolean)
	for character in hiddenByMe do
		if character.Parent == nil then
			hiddenByMe[character] = nil
		end
	end
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if other == player or character == nil then
			continue
		end
		local hide = onIsland and other:GetAttribute(MatchTypes.Attr.Location) == MatchTypes.MiranteLocation
		if hide then
			setModifier(character, 1) -- reaplica (peças novas, troca de personagem)
			hiddenByMe[character] = true
		elseif hiddenByMe[character] then
			setModifier(character, 0)
			hiddenByMe[character] = nil
		end
	end
end

local function zonePart(island: number): Part
	local existing = zoneParts[island]
	if existing then
		return existing
	end
	local part = Instance.new("Part")
	part.Name = `Zone{island}`
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Shape = Enum.PartType.Cylinder
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Theme.Match.Zone
	part.Transparency = Theme.ZoneTransparency
	part.Parent = zoneFolder
	zoneParts[island] = part
	return part
end

local function updateZones()
	local snapshot = MatchClient.get()
	local active: { [number]: boolean } = {}
	if snapshot and snapshot.phase == "Combat" and snapshot.combatStartedAt then
		local radius = WorldLayout.zoneRadius(workspace:GetServerTimeNow() - snapshot.combatStartedAt)
		for _, duel in snapshot.duels do
			if not duel.finished then
				active[duel.island] = true
				local part = zonePart(duel.island)
				local center = WorldLayout.islandCenter(duel.island)
				-- Cilindro do Roblox: o eixo é X; gira para ficar em pé
				part.Size = Vector3.new(ZONE_HEIGHT, radius * 2, radius * 2)
				part.CFrame = CFrame.new(center + Vector3.new(0, ZONE_HEIGHT / 2 - 10, 0))
					* CFrame.Angles(0, 0, math.pi / 2)
			end
		end
	end
	for island, part in zoneParts do
		if not active[island] then
			part:Destroy()
			zoneParts[island] = nil
		end
	end
end

function MiranteView.Start()
	if not MatchClient.isEnabled() then
		return
	end
	zoneFolder = Instance.new("Folder")
	zoneFolder.Name = "MatchZones"
	zoneFolder.Parent = workspace

	CollectionService:GetInstanceAddedSignal(MatchTypes.RoofTag):Connect(function()
		lastOnMirante = nil
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		updateZones()
		elapsed += dt
		if elapsed < REFRESH_SECONDS then
			return
		end
		elapsed = 0
		local onMirante = MatchClient.isOnMirante()
		if onMirante ~= lastOnMirante then
			lastOnMirante = onMirante
			applyRoofs(onMirante)
		end
		applySpectatorVisibility(MatchClient.myIsland() ~= nil)
	end)
end

return MiranteView
