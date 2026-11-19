--!strict
-- Peças básicas para montar o mundo e os kits dos mapas (KIT-MODULAR seção 1): material liso, sem
-- textura, ancoradas. Usado pelo servidor (partida), pelo cliente (lobby) e pela prévia no Studio.

local Build = {}

export type PartOptions = {
	transparency: number?,
	collide: boolean?,
	query: boolean?, -- false = raios (tiros, câmera) atravessam
	shadow: boolean?,
	-- Peça de acabamento (junta de tijolo, tábua, ferrugem, moldura): não colide, não bloqueia tiro,
	-- não faz sombra e não entra no minimapa. Sempre encostada numa peça que colide.
	detail: boolean?,
	-- Acabamento que AJUDA A JOGAR (setas da esteira, faixas de aviso de queda, vagas): nunca some na
	-- versão leve dos mapas (MapDetailLevel).
	signal: boolean?,
}

Build.DetailAttribute = "MapDetail"
Build.SignalAttribute = "MapSignal"
-- Atalho para as peças de acabamento.
Build.Detail = { detail = true } :: PartOptions
-- Atalho para as peças de acabamento que sinalizam algo (nunca somem).
Build.Signal = { detail = true, signal = true } :: PartOptions

local function apply(part: BasePart, name: string, color: Color3, parent: Instance, options: PartOptions?)
	part.Name = name
	part.Anchored = true
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if options then
		part.Transparency = options.transparency or 0
		if options.collide == false then
			part.CanCollide = false
		end
		if options.query == false then
			part.CanQuery = false
			part.CanTouch = false
		end
		if options.shadow == false then
			part.CastShadow = false
		end
		if options.detail then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part:SetAttribute(Build.DetailAttribute, true)
		end
		if options.signal then
			part:SetAttribute(Build.SignalAttribute, true)
		end
	end
	part.Parent = parent
end

-- Modelo vazio para agrupar as peças de um componente do kit (aparece com nome no Explorer).
function Build.model(name: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- Quadro de um componente: no ponto (x, z) do quadro da ilha, na altura `y` (0 = chão), girado
-- `yawDegrees` em volta de Y. As peças do componente usam `origem * CFrame.new(...)`.
function Build.pivot(frame: CFrame, at: Vector2, yawDegrees: number?, y: number?): CFrame
	return frame * CFrame.new(at.X, y or 0, at.Y) * CFrame.Angles(0, math.rad(yawDegrees or 0), 0)
end

-- Bloco com tamanho e posição (centro).
function Build.block(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	parent: Instance,
	options: PartOptions?
): Part
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	apply(part, name, color, parent, options)
	return part
end

-- Triângulo retângulo deitado (uma WedgePart), com a espessura para baixo a partir de `topY`.
-- `corner` é o vértice do ângulo reto; `a` e `b` são as pontas dos dois catetos (no plano XZ).
--
-- A WedgePart tem a seção em triângulo no plano YZ local, com o ângulo reto em (-Y, +Z): andar +Y
-- a partir dele chega numa ponta e andar -Z chega na outra. A espessura fica no eixo X local, que
-- aqui aponta para cima ou para baixo (a peça é simétrica nesse eixo).
function Build.flatTriangle(
	name: string,
	corner: Vector3,
	a: Vector3,
	b: Vector3,
	topY: number,
	thickness: number,
	color: Color3,
	parent: Instance,
	options: PartOptions?
): WedgePart
	local flatCorner = Vector3.new(corner.X, 0, corner.Z)
	local toA = Vector3.new(a.X, 0, a.Z) - flatCorner
	local toB = Vector3.new(b.X, 0, b.Z) - flatCorner
	local yAxis = toA.Unit
	local zAxis = -toB.Unit
	local xAxis = yAxis:Cross(zAxis)
	local mid = (Vector3.new(a.X, 0, a.Z) + Vector3.new(b.X, 0, b.Z)) / 2
	local position = Vector3.new(mid.X, topY - thickness / 2, mid.Z)
	local wedge = Instance.new("WedgePart")
	wedge.Size = Vector3.new(thickness, toA.Magnitude, toB.Magnitude)
	wedge.CFrame = CFrame.fromMatrix(position, xAxis, yAxis, zAxis)
	apply(wedge, name, color, parent, options)
	return wedge
end

-- Peça apoiada no chão de um quadro (CFrame no topo do chão), em coordenadas locais (x, z).
function Build.onFloor(
	name: string,
	size: Vector3,
	frame: CFrame,
	x: number,
	z: number,
	color: Color3,
	parent: Instance,
	options: PartOptions?
): Part
	return Build.block(name, size, frame * CFrame.new(x, size.Y / 2, z), color, parent, options)
end

-- Igual a onFloor, e também a cópia espelhada no eixo X local (o outro lado da ilha), se x ≠ 0.
function Build.mirrored(
	name: string,
	size: Vector3,
	frame: CFrame,
	x: number,
	z: number,
	color: Color3,
	parent: Instance,
	options: PartOptions?
)
	Build.onFloor(name, size, frame, x, z, color, parent, options)
	if x ~= 0 then
		Build.onFloor(name, size, frame, -x, z, color, parent, options)
	end
end

-- Coordenadas (x, z) do quadro no plano do chão, em Vector2.
local function at(frame: CFrame, p: Vector2, y: number?): Vector3
	return frame * Vector3.new(p.X, y or 0, p.Y)
end

-- Parede (ou mureta, ou viga) reta de `a` até `b` (x, z do quadro), apoiada em `baseY` (altura local).
-- O comprimento ganha a espessura, para os cantos fecharem.
function Build.wall(
	name: string,
	frame: CFrame,
	a: Vector2,
	b: Vector2,
	height: number,
	thickness: number,
	color: Color3,
	parent: Instance,
	baseY: number?,
	options: PartOptions?
): Part
	local mid = (a + b) / 2
	local dir = b - a
	local yaw = math.atan2(-dir.Y, dir.X) -- eixo X local da peça ao longo de a → b
	local y = (baseY or 0) + height / 2
	return Build.block(
		name,
		Vector3.new(dir.Magnitude + thickness, height, thickness),
		frame * CFrame.new(mid.X, y, mid.Y) * CFrame.Angles(0, yaw, 0),
		color,
		parent,
		options
	)
end

-- Triângulo retângulo de chão em coordenadas do quadro (topo em `topY` local).
function Build.floorTriangle(
	name: string,
	frame: CFrame,
	corner: Vector2,
	a: Vector2,
	b: Vector2,
	thickness: number,
	color: Color3,
	parent: Instance,
	topY: number?,
	options: PartOptions?
): WedgePart
	local y = topY or 0
	return Build.flatTriangle(
		name,
		at(frame, corner, y),
		at(frame, a, y),
		at(frame, b, y),
		frame.Position.Y + y,
		thickness,
		color,
		parent,
		options
	)
end

-- Retângulo de chão entre dois cantos (x, z do quadro), com o topo em `topY` local.
function Build.floorRect(
	name: string,
	frame: CFrame,
	min: Vector2,
	max: Vector2,
	thickness: number,
	color: Color3,
	parent: Instance,
	topY: number?,
	options: PartOptions?
): Part
	local size = max - min
	local mid = (min + max) / 2
	return Build.block(
		name,
		Vector3.new(size.X, thickness, size.Y),
		frame * CFrame.new(mid.X, (topY or 0) - thickness / 2, mid.Y),
		color,
		parent,
		options
	)
end

-- Rampa reta: sobe de `foot` até `head` (x, z do quadro), da altura `fromY` até `toY` (locais).
function Build.ramp(
	name: string,
	frame: CFrame,
	foot: Vector2,
	head: Vector2,
	fromY: number,
	toY: number,
	width: number,
	color: Color3,
	parent: Instance,
	options: PartOptions?
): WedgePart
	local rise = toY - fromY
	local dir = head - foot
	local mid = (foot + head) / 2
	-- A WedgePart sobe para o +Z local; aqui o +Z local aponta de `foot` para `head`.
	local look = CFrame.lookAt(Vector3.zero, Vector3.new(-dir.X, 0, -dir.Y))
	local wedge = Instance.new("WedgePart")
	wedge.Size = Vector3.new(width, rise, dir.Magnitude)
	wedge.CFrame = frame * CFrame.new(mid.X, fromY + rise / 2, mid.Y) * look
	apply(wedge, name, color, parent, options)
	return wedge
end

-- Cunha solta (telhado de duas águas, chanfro), com tamanho e posição (centro). A WedgePart tem a
-- face alta no +Z local e a rampa descendo para o -Z.
function Build.wedge(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	parent: Instance,
	options: PartOptions?
): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Size = size
	wedge.CFrame = cframe
	apply(wedge, name, color, parent, options)
	return wedge
end

-- Prisma low poly de 6 ou 8 lados (KIT-MODULAR 1: cilindro = prisma), em pé no eixo Y de `cframe`
-- (centro da peça). `diameter` é a medida de face a face. É feito de blocos cruzados (3 no de 6
-- lados, 4 no de 8), todos da mesma cor.
function Build.prism(
	name: string,
	sides: number,
	diameter: number,
	height: number,
	cframe: CFrame,
	color: Color3,
	parent: Instance,
	options: PartOptions?
): { Part }
	assert(sides == 6 or sides == 8, "prisma de 6 ou 8 lados")
	local face = diameter * math.tan(math.pi / sides) -- largura de cada face
	local parts = {}
	for k = 0, sides / 2 - 1 do
		local turn = CFrame.Angles(0, k * 2 * math.pi / sides, 0)
		local size = Vector3.new(diameter, height, face)
		table.insert(parts, Build.block(name, size, cframe * turn, color, parent, options))
	end
	return parts
end

return Build
