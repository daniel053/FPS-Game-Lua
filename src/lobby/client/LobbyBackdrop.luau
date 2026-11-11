--!strict
-- Cenário do lobby (ESTILO T3, só ambientação): ao fundo, o mirante plano e as 4 ilhas de duelo
-- flutuando, em blocos cinza (o lobby 3D final é da F10). Montado só no cliente, sem colisão e sem
-- nada salvo no place. Fica na frente de quem nasce, além do chão do lobby.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)

local COLORS = Theme.Match
local CENTER = Vector3.new(0, 45, -300) -- longe do chão do lobby (200 × 200)
local MIRANTE_SIZE = 70
local ISLAND_SIZE = Vector3.new(70, 8, 50)
local ISLAND_OFFSETS = {
	Vector3.new(-110, -28, -70),
	Vector3.new(110, -28, -70),
	Vector3.new(-110, -28, 70),
	Vector3.new(110, -28, 70),
}

local LobbyBackdrop = {}

local function block(parent: Instance, size: Vector3, cframe: CFrame, color: Color3)
	local part = Instance.new("Part")
	part.Name = "Block"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
end

-- Ilha flutuante: chão, base mais escura e afunilada, e algumas construções simples em cima.
local function island(parent: Instance, center: Vector3, size: Vector3, seed: number)
	block(parent, size, CFrame.new(center), COLORS.IslandFloor)
	block(
		parent,
		Vector3.new(size.X * 0.8, size.Y * 2, size.Z * 0.8),
		CFrame.new(center - Vector3.new(0, size.Y * 1.4, 0)),
		COLORS.IslandUnderside
	)
	block(
		parent,
		Vector3.new(size.X * 0.45, size.Y * 2, size.Z * 0.45),
		CFrame.new(center - Vector3.new(0, size.Y * 3.2, 0)),
		COLORS.IslandUnderside
	)
	local random = Random.new(seed)
	for _ = 1, 5 do
		local w = random:NextNumber(6, 14)
		local h = random:NextNumber(5, 16)
		local x = random:NextNumber(-size.X / 2 + w, size.X / 2 - w)
		local z = random:NextNumber(-size.Z / 2 + w, size.Z / 2 - w)
		block(
			parent,
			Vector3.new(w, h, w),
			CFrame.new(center + Vector3.new(x, size.Y / 2 + h / 2, z)),
			COLORS.IslandCover
		)
	end
end

function LobbyBackdrop.Start()
	local folder = Instance.new("Folder")
	folder.Name = "LobbyBackdrop"

	-- Mirante: losango plano, sem nada no meio (GDD 6.5)
	block(
		folder,
		Vector3.new(MIRANTE_SIZE, 6, MIRANTE_SIZE),
		CFrame.new(CENTER) * CFrame.Angles(0, math.rad(45), 0),
		COLORS.MiranteFloor
	)
	block(
		folder,
		Vector3.new(MIRANTE_SIZE * 0.7, 14, MIRANTE_SIZE * 0.7),
		CFrame.new(CENTER - Vector3.new(0, 10, 0)) * CFrame.Angles(0, math.rad(45), 0),
		COLORS.IslandUnderside
	)
	for i, offset in ISLAND_OFFSETS do
		island(folder, CENTER + offset, ISLAND_SIZE, i)
	end
	folder.Parent = workspace
end

return LobbyBackdrop
