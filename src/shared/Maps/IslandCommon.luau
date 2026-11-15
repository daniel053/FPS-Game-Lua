--!strict
-- Peças que toda ilha tem (GDD 15.1): as duas bases nas pontas (fora da área de duelo), com chão,
-- mureta, parede da frente com a passagem e rocha embaixo; a âncora do nome da ilha; as zonas com
-- nome (pings) e os pontos de escudo.
-- O quadro da ilha (`frame`) tem o eixo X local de base a base; a base +X é montada com `frame` e a
-- base -X com o quadro girado 180°.

local CollectionService = game:GetService("CollectionService")

local Build = require(script.Parent.Build)
local MapConfig = require(script.Parent.Parent.Config.MapConfig)
local MatchTypes = require(script.Parent.Parent.Match.MatchTypes)
local Theme = require(script.Parent.Parent.Config.Theme)

local WORLD = MapConfig.World
local COLORS = Theme.Match

local IslandCommon = {}

-- Cores das peças comuns (bases), para cada ilha usar a sua paleta.
export type Style = {
	floor: Color3,
	rail: Color3,
	wall: Color3,
	underside: Color3,
}

-- O que cada módulo em Maps/Islands devolve.
export type Island = {
	style: Style?, -- cores das bases; sem isso, o cinza da F3
	build: (frame: CFrame, folder: Instance) -> (), -- monta a área de duelo (as bases vêm daqui)
}

IslandCommon.GroundAttribute = "MapGround" -- chão desenhado no minimapa
IslandCommon.ZoneAttribute = "MapZone" -- id da zona (nome em Strings.Zones)
IslandCommon.ZoneSideAttribute = "MapZoneSide" -- "east" (metade +X), "west" (metade -X) ou nada
IslandCommon.ZoneTag = "MapZone"
IslandCommon.ShieldPointTag = "ShieldPoint"
IslandCommon.NoShadow = { shadow = false } :: Build.PartOptions
IslandCommon.Invisible = { transparency = 1, collide = false, query = false, shadow = false } :: Build.PartOptions

IslandCommon.GrayStyle = {
	floor = COLORS.IslandFloor,
	rail = COLORS.IslandRail,
	wall = COLORS.IslandWall,
	underside = COLORS.IslandUnderside,
} :: Style

-- Altura da parede da frente da base (cobertura cheia: protege quem acabou de nascer).
local BASE_WALL_HEIGHT = 7
-- Altura das zonas (peças invisíveis): cobre do chão até acima do nível mais alto.
local ZONE_HEIGHT = 40

-- Marca uma peça como chão (minimapa).
function IslandCommon.ground(part: BasePart): BasePart
	part:SetAttribute(IslandCommon.GroundAttribute, true)
	return part
end

-- Marca um telhado: fica transparente só para quem está no mirante (GDD 6.5).
function IslandCommon.roof(part: BasePart): BasePart
	CollectionService:AddTag(part, MatchTypes.RoofTag)
	return part
end

-- Quadro girado 180° em volta do centro da ilha (a outra metade, nas ilhas com simetria de giro).
function IslandCommon.rotated(frame: CFrame): CFrame
	return frame * CFrame.Angles(0, math.pi, 0)
end

-- Zona com nome (GDD 15.1): caixa invisível entre dois cantos (x, z do quadro). `zoneId` é uma chave
-- de Strings.Zones; `side` diferencia as metades ("east" = +X, "west" = -X).
function IslandCommon.zone(
	frame: CFrame,
	folder: Instance,
	zoneId: string,
	min: Vector2,
	max: Vector2,
	side: ("east" | "west")?
): Part
	local size = max - min
	local mid = (min + max) / 2
	local part = Build.block(
		"Zone",
		Vector3.new(math.abs(size.X), ZONE_HEIGHT, math.abs(size.Y)),
		frame * CFrame.new(mid.X, ZONE_HEIGHT / 2 - 2, mid.Y),
		COLORS.IslandFloor,
		folder,
		IslandCommon.Invisible
	)
	part:SetAttribute(IslandCommon.ZoneAttribute, zoneId)
	if side then
		part:SetAttribute(IslandCommon.ZoneSideAttribute, side)
	end
	CollectionService:AddTag(part, IslandCommon.ZoneTag)
	return part
end

-- Ponto de recarga de escudo (GDD 15.1: 2 por mapa, simétricos): placa baixa de 6 lados no chão.
-- Só a marca no mapa; a regra de recarga é do servidor.
function IslandCommon.shieldPoint(frame: CFrame, folder: Instance, x: number, z: number, y: number?): Model
	local model = Build.model("ShieldPoint", folder)
	local origin = Build.pivot(frame, Vector2.new(x, z), 0, y)
	local base = Build.prism("Pad", 6, 6, 0.4, origin * CFrame.new(0, 0.2, 0), COLORS.ShieldPadRim, model)
	Build.prism("PadTop", 6, 4.6, 0.2, origin * CFrame.new(0, 0.5, 0), COLORS.ShieldPad, model, Build.Detail)
	model.PrimaryPart = base[1]
	CollectionService:AddTag(model, IslandCommon.ShieldPointTag)
	return model
end

-- Uma base, na ponta +X local do quadro.
local function base(frame: CFrame, folder: Instance, style: Style)
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
			style.floor,
			folder,
			0,
			IslandCommon.NoShadow
		)
	)
	Build.block(
		"Underside",
		Vector3.new(size.X - 6, 8, size.Y - 6),
		frame * CFrame.new((x0 + x1) / 2, -t - 4, 0),
		style.underside,
		folder,
		IslandCommon.NoShadow
	)
	-- Mureta no fundo e nos lados
	local rail = WORLD.IslandEdgeRail
	Build.wall("Rail", frame, Vector2.new(x1, -hz), Vector2.new(x1, hz), rail, 1, style.rail, folder)
	for _, z in { -hz, hz } do
		Build.wall("Rail", frame, Vector2.new(x0, z), Vector2.new(x1, z), rail, 1, style.rail, folder)
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
			style.wall,
			folder
		)
	end
end

-- As duas bases da ilha.
function IslandCommon.bases(frame: CFrame, folder: Instance, style: Style?)
	local colors = style or IslandCommon.GrayStyle
	base(frame, folder, colors)
	base(IslandCommon.rotated(frame), folder, colors)
	local x0, x1 = WORLD.BodySize.X / 2, WORLD.BodySize.X / 2 + WORLD.BaseSize.X
	local hz = WORLD.BaseSize.Y / 2
	IslandCommon.zone(frame, folder, "base", Vector2.new(x0, -hz), Vector2.new(x1, hz), "east")
	IslandCommon.zone(frame, folder, "base", Vector2.new(-x1, -hz), Vector2.new(-x0, hz), "west")
end

-- Peça invisível no centro da ilha, onde fica o nome visto do mirante.
function IslandCommon.labelAnchor(frame: CFrame, folder: Instance): Part
	return Build.block("LabelAnchor", Vector3.one, frame, COLORS.IslandFloor, folder, IslandCommon.Invisible)
end

return IslandCommon
