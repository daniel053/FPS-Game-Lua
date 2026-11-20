--!strict
-- Parede invisível das bases (MapConfig.BaseBarrier): no sorteio e na preparação o jogador anda livre
-- dentro da base, mas não sai dela; no combate a parede some. Só bloqueia o corpo: tiros, câmera e
-- toques atravessam. O vidro que aparece ao chegar perto é desenhado em cada cliente
-- (match/client/BaseBarrierFx), a partir dos painéis com a tag `GlassTag`.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local WorldLayout = require(Shared.Match.WorldLayout)

local BaseBarriers = {}

BaseBarriers.FolderName = "BaseBarriers"
BaseBarriers.ActiveAttribute = "Active" -- na pasta: a parede está de pé?
BaseBarriers.GlassTag = "BaseBarrierGlass"
BaseBarriers.IslandAttribute = "Island"

local parts: { BasePart } = {}
local folder: Folder? = nil
local active = false

function BaseBarriers.build()
	if folder then
		return
	end
	local root = Instance.new("Folder")
	root.Name = BaseBarriers.FolderName
	for island = 1, WorldLayout.islandCount() do
		for side = 1, 2 do
			for i, panel in WorldLayout.basePanels(island, side) do
				local part = Instance.new("Part")
				part.Name = if panel.glass then `Glass{i}` else `Wall{i}`
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
				part.Transparency = 1
				part.Size = panel.size
				part.CFrame = panel.cframe
				part:SetAttribute(BaseBarriers.IslandAttribute, island)
				if panel.glass then
					CollectionService:AddTag(part, BaseBarriers.GlassTag)
				end
				part.Parent = root
				table.insert(parts, part)
			end
		end
	end
	root:SetAttribute(BaseBarriers.ActiveAttribute, false)
	root.Parent = workspace
	folder = root
end

function BaseBarriers.setActive(on: boolean)
	if on == active or folder == nil then
		return
	end
	active = on
	for _, part in parts do
		part.CanCollide = on
	end
	folder:SetAttribute(BaseBarriers.ActiveAttribute, on)
end

function BaseBarriers.isActive(): boolean
	return active
end

return BaseBarriers
