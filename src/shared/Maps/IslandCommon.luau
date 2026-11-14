--!strict
-- Peças que toda ilha tem (GDD 15.1): as duas bases nas pontas (fora da área de duelo), com chão,
-- mureta, parede da frente com a passagem e rocha embaixo, e a âncora do nome da ilha.
-- O quadro da ilha (`frame`) tem o eixo X local de base a base; a base +X é montada com `frame` e a
-- base -X com o quadro girado 180°.

local Build = require(script.Parent.Build)
local MapConfig = require(script.Parent.Parent.Config.MapConfig)
local Theme = require(script.Parent.Parent.Config.Theme)

local WORLD = MapConfig.World
local COLORS = Theme.Match

local IslandCommon = {}

IslandCommon.GroundAttribute = "MapGround" -- chão desenhado no minimapa
IslandCommon.NoShadow = { shadow = false } :: Build.PartOptions
IslandCommon.Invisible = { transparency = 1, collide = false, query = false, shadow = false } :: Build.PartOptions

-- Altura da parede da frente da base (cobertura cheia: protege quem acabou de nascer).
local BASE_WALL_HEIGHT = 7

-- Marca uma peça como chão (minimapa).
function IslandCommon.ground(part: BasePart): BasePart
	part:SetAttribute(IslandCommon.GroundAttribute, true)
	return part
end

-- Quadro girado 180° em volta do centro da ilha (a outra metade, nas ilhas com simetria de giro).
function IslandCommon.rotated(frame: CFrame): CFrame
	return frame * CFrame.Angles(0, math.pi, 0)
end

-- Uma base, na ponta +X local do quadro.
local function base(frame: CFrame, folder: Instance)
	local body, size = WORLD.BodySize, WORLD.BaseSize
	local t = WORLD.IslandThickness
	local x0 = body.X / 2 -- frente da base (encosta na área de duelo)
	local x1 = x0 + size.X -- fundo
	local hz = size.Y / 2
	IslandCommon.ground(
		Build.floorRect(
			"BaseFloor",
			frame,
			Vector2.new(x0, -hz),
			Vector2.new(x1, hz),
			t,
			COLORS.IslandFloor,
			folder,
			0,
			IslandCommon.NoShadow
		)
	)
	Build.block(
		"Underside",
		Vector3.new(size.X - 6, 8, size.Y - 6),
		frame * CFrame.new((x0 + x1) / 2, -t - 4, 0),
		COLORS.IslandUnderside,
		folder,
		IslandCommon.NoShadow
	)
	-- Mureta no fundo e nos lados
	local rail = WORLD.IslandEdgeRail
	Build.wall("Rail", frame, Vector2.new(x1, -hz), Vector2.new(x1, hz), rail, 1, COLORS.IslandRail, folder)
	for _, z in { -hz, hz } do
		Build.wall("Rail", frame, Vector2.new(x0, z), Vector2.new(x1, z), rail, 1, COLORS.IslandRail, folder)
	end
	-- Parede da frente com a passagem no meio
	local door = WORLD.BaseDoorWidth / 2
	for _, sign in { -1, 1 } do
		Build.wall(
			"BaseWall",
			frame,
			Vector2.new(x0, sign * door),
			Vector2.new(x0, sign * hz),
			BASE_WALL_HEIGHT,
			1.5,
			COLORS.IslandWall,
			folder
		)
	end
end

-- As duas bases da ilha.
function IslandCommon.bases(frame: CFrame, folder: Instance)
	base(frame, folder)
	base(IslandCommon.rotated(frame), folder)
end

-- Peça invisível no centro da ilha, onde fica o nome visto do mirante.
function IslandCommon.labelAnchor(frame: CFrame, folder: Instance): Part
	return Build.block("LabelAnchor", Vector3.one, frame, COLORS.IslandFloor, folder, IslandCommon.Invisible)
end

return IslandCommon
