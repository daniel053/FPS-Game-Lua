--!strict
-- Formas das armas para a arma em primeira pessoa (ViewModel, Partida e Tutorial) e para as vitrines
-- 3D da interface (Arsenal T5, modal T2). Só cliente.
-- Cada arma usa o seu modelo detalhado (WeaponModels) com as cores do Theme.WeaponLook; a forma simples
-- por categoria só aparece para uma arma que ainda não tenha modelo. Com as mãos (primeira pessoa),
-- a mão direita fica na empunhadura do modelo e a esquerda no guarda-mão.
--
-- Mãos e braços (F10): luva escura de blocos (dorso, dedos que dão a volta, polegar, indicador
-- esticado ao lado do guarda-mato), punho da luva e manga neutra que engrossa até o cotovelo, com o
-- punho dobrado. A manga não tem cor de equipe (GDD 3.3). A câmera vê o lado esquerdo da arma, então
-- os dedos e o polegar ficam desse lado; o dorso da mão direita fica do lado de fora.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ShopCatalog = require(Shared.Config.ShopCatalog)
local Theme = require(Shared.Config.Theme)
local Types = require(Shared.Types)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponModels = require(Shared.Combat.WeaponModels)

local COLORS = Theme.Combat

export type PartSpec = WeaponModels.PartSpec

export type Shape = {
	parts: { PartSpec },
	muzzle: Vector3,
	leftHand: Vector3?, -- nil = uma mão só
}

local WeaponShapes = {}

-- Atributo das peças do pente no modelo montado (o ViewModel anima na recarga).
WeaponShapes.MagAttribute = "Mag"

-- Bastão na mão: inclinado (como quem segura um taco); na vitrine, deitado como as outras armas.
local MELEE_TILT = CFrame.Angles(math.rad(62), math.rad(-8), math.rad(-12))

local function box(size: Vector3, position: Vector3, color: Color3, rotation: CFrame?): PartSpec
	return { size = size, cframe = CFrame.new(position) * (rotation or CFrame.identity), color = color }
end

-- Segmento (braço) entre dois pontos.
local function segment(from: Vector3, to: Vector3, thickness: number, color: Color3): PartSpec
	local length = (to - from).Magnitude
	return {
		size = Vector3.new(thickness, thickness, length),
		cframe = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2),
		color = color,
	}
end

-- Peça no quadro da mão: `at` e o giro são locais ao quadro `frame`.
local function piece(parts: { PartSpec }, frame: CFrame, size: Vector3, at: Vector3, color: Color3, turn: CFrame?)
	table.insert(parts, { size = size, cframe = frame * CFrame.new(at) * (turn or CFrame.identity), color = color })
end

-- Antebraço do pulso ao cotovelo: punho da luva, punho dobrado da manga e a manga, engrossando.
local function forearm(parts: { PartSpec }, wrist: Vector3, elbow: Vector3)
	local dir = (elbow - wrist).Unit
	local cuffEnd = wrist + dir * 0.16
	table.insert(parts, segment(wrist, cuffEnd, 0.27, COLORS.Glove))
	table.insert(parts, segment(cuffEnd - dir * 0.02, cuffEnd + dir * 0.03, 0.29, COLORS.GloveShade))
	local foldEnd = cuffEnd + dir * 0.14
	table.insert(parts, segment(cuffEnd, foldEnd, 0.37, COLORS.SleeveShade))
	local mid = foldEnd + (elbow - foldEnd) * 0.5
	table.insert(parts, segment(foldEnd, mid, 0.34, COLORS.Sleeve))
	table.insert(parts, segment(mid, elbow, 0.4, COLORS.Sleeve))
	-- costura ao comprido, virada para a câmera (lado de cima)
	table.insert(
		parts,
		segment(foldEnd + Vector3.new(0, 0.17, 0), elbow + Vector3.new(0, 0.2, 0), 0.03, COLORS.SleeveShade)
	)
end

-- Mão direita na empunhadura. `frame`: origem no meio da empunhadura, Y ao longo dela (para cima),
-- -Z para a frente (cano). Devolve o pulso (embaixo e atrás da empunhadura).
local function rightHand(parts: { PartSpec }, frame: CFrame, indexFinger: boolean): Vector3
	local g, shade, pad = COLORS.Glove, COLORS.GloveShade, COLORS.GlovePad
	-- dorso (lado de fora, +X) e a dobra entre polegar e indicador, atrás e em cima
	piece(parts, frame, Vector3.new(0.08, 0.32, 0.3), Vector3.new(0.12, -0.01, 0.03), g)
	piece(parts, frame, Vector3.new(0.02, 0.2, 0.18), Vector3.new(0.165, 0, 0.03), pad)
	piece(parts, frame, Vector3.new(0.26, 0.09, 0.1), Vector3.new(0.02, 0.12, 0.15), g)
	-- 3 dedos dando a volta na frente e terminando do lado esquerdo (o que a câmera vê)
	for i, y in { 0.05, -0.05, -0.15 } do
		piece(parts, frame, Vector3.new(0.27, 0.085, 0.09), Vector3.new(0.005, y, -0.15), g)
		piece(parts, frame, Vector3.new(0.08, 0.085, 0.2), Vector3.new(-0.115, y, -0.07), g)
		piece(parts, frame, Vector3.new(0.085, 0.03, 0.06), Vector3.new(-0.115, y, -0.13), pad)
		if i < 3 then
			piece(parts, frame, Vector3.new(0.285, 0.012, 0.1), Vector3.new(0.005, y - 0.05, -0.15), shade)
			piece(parts, frame, Vector3.new(0.09, 0.012, 0.21), Vector3.new(-0.115, y - 0.05, -0.07), shade)
		end
	end
	-- polegar do lado esquerdo, deitado para a frente
	piece(
		parts,
		frame,
		Vector3.new(0.075, 0.08, 0.24),
		Vector3.new(-0.11, 0.15, 0.0),
		g,
		CFrame.Angles(math.rad(-12), 0, 0)
	)
	piece(parts, frame, Vector3.new(0.08, 0.04, 0.06), Vector3.new(-0.11, 0.17, -0.1), pad)
	-- indicador esticado ao lado do guarda-mato (fora do gatilho até atirar)
	if indexFinger then
		piece(
			parts,
			frame,
			Vector3.new(0.07, 0.07, 0.22),
			Vector3.new(-0.1, 0.13, -0.24),
			g,
			CFrame.Angles(math.rad(12), 0, 0)
		)
	end
	return (frame * CFrame.new(0.04, -0.2, 0.12)).Position
end

-- Mão esquerda embaixo do guarda-mão. `at` = o ponto de apoio do modelo. Os dedos sobem pelo lado
-- esquerdo (o que a câmera vê); o polegar sobe pelo outro. Devolve o pulso.
local function leftHand(parts: { PartSpec }, at: Vector3): Vector3
	local frame = CFrame.new(at)
	local g, shade, pad = COLORS.Glove, COLORS.GloveShade, COLORS.GlovePad
	piece(parts, frame, Vector3.new(0.3, 0.09, 0.32), Vector3.new(0, -0.03, 0), g) -- palma
	piece(parts, frame, Vector3.new(0.22, 0.03, 0.2), Vector3.new(0, -0.08, 0.02), pad)
	piece(parts, frame, Vector3.new(0.08, 0.2, 0.3), Vector3.new(-0.15, 0.07, -0.01), g) -- dedos
	for _, z in { -0.075, 0, 0.075 } do
		piece(parts, frame, Vector3.new(0.085, 0.2, 0.012), Vector3.new(-0.15, 0.07, z), shade)
	end
	piece(parts, frame, Vector3.new(0.085, 0.035, 0.3), Vector3.new(-0.15, 0.16, -0.01), pad) -- pontas
	piece(parts, frame, Vector3.new(0.07, 0.16, 0.22), Vector3.new(0.15, 0.05, 0.04), g) -- polegar
	return at + Vector3.new(-0.02, -0.08, 0.2)
end

-- Inclinação da empunhadura dos modelos (WeaponModels: -15° a -18°, base para trás).
local GRIP_TILT = CFrame.Angles(math.rad(-16), 0, 0)
local RIGHT_ELBOW = Vector3.new(0.3, -1.3, 0.8)
local LEFT_ELBOW = Vector3.new(-0.7, -1.3, 0.1)

-- Cores da arma: as da skin (tema do ShopCatalog, Theme.SkinLook) por cima das da arma. Skin
-- desconhecida ou de outra arma = cores padrão.
local function lookOf(id: string?, skinId: string?): WeaponModels.Look
	local base = if id then Theme.WeaponLook[id] else nil
	local skin = if skinId then ShopCatalog.getSkin(skinId) else nil
	local theme = if skin and skin.weaponId == id and skin.theme then Theme.SkinLook[skin.theme] else nil
	local look = theme or base
	if theme and base then
		look = {
			body = theme.body,
			dark = theme.dark,
			accent = theme.accent,
			metal = theme.metal or base.metal,
			lens = theme.lens or base.lens,
		}
	end
	local body = if look then look.body else COLORS.WeaponBody
	local accent = if look then look.accent else COLORS.WeaponLight
	return {
		body = body,
		dark = if look then look.dark else COLORS.WeaponDark,
		light = body:Lerp(Color3.new(1, 1, 1), 0.25),
		accent = accent,
		metal = (if look then look.metal else nil) or COLORS.WeaponLight,
		lens = (if look then look.lens else nil) or accent,
	}
end

-- Forma simples por categoria (reserva para arma sem modelo detalhado).
local function fallback(category: Types.WeaponCategory, c: WeaponModels.Look): WeaponModels.Built
	local grip = Vector3.new(0, -0.18, 0.02)
	local tilt = CFrame.Angles(math.rad(-15), 0, 0)
	local parts: { PartSpec } = {}
	if category == "Pistol" then
		table.insert(parts, box(Vector3.new(0.22, 0.3, 0.75), Vector3.new(0, 0.12, -0.2), c.body))
		table.insert(parts, box(Vector3.new(0.2, 0.45, 0.22), grip, c.dark, tilt))
		return { parts = parts, muzzle = Vector3.new(0, 0.17, -0.6), leftHand = nil, grip = grip }
	end
	table.insert(parts, box(Vector3.new(0.3, 0.4, 1.6), Vector3.new(0, 0.12, -0.45), c.body))
	table.insert(parts, box(Vector3.new(0.12, 0.12, 0.8), Vector3.new(0, 0.2, -1.6), c.dark))
	table.insert(parts, box(Vector3.new(0.2, 0.5, 0.24), Vector3.new(0, -0.3, -0.5), c.dark))
	parts[#parts].mag = true -- pente
	parts[#parts].mag = true -- pente
	table.insert(parts, box(Vector3.new(0.2, 0.42, 0.22), grip, c.dark, tilt))
	return { parts = parts, muzzle = Vector3.new(0, 0.2, -2.0), leftHand = Vector3.new(0, -0.05, -1.0), grip = grip }
end

-- `gripFrame` (opcional): quadro da mão direita, quando a empunhadura não é a de pistola (Bastão).
local function withHands(built: WeaponModels.Built, withArms: boolean, gripFrame: CFrame?): Shape
	local parts = built.parts
	if withArms then
		local frame = gripFrame or (CFrame.new(built.grip) * GRIP_TILT)
		local wrist = rightHand(parts, frame, gripFrame == nil)
		forearm(parts, wrist, RIGHT_ELBOW)
		local left = built.leftHand
		if left then
			forearm(parts, leftHand(parts, left), LEFT_ELBOW)
		end
	end
	return { parts = parts, muzzle = built.muzzle, leftHand = built.leftHand }
end

-- Arma de fogo. `id` escolhe o modelo e as cores; sem id (ou sem modelo), a forma da categoria.
-- `skinId` = skin equipada (F9): só troca as cores.
function WeaponShapes.gun(category: Types.WeaponCategory, withArms: boolean, id: string?, skinId: string?): Shape
	local look = lookOf(id, skinId)
	local built = (if id then WeaponModels.build(id, look) else nil) or fallback(category, look)
	return withHands(built, withArms)
end

-- Bastão (corpo a corpo).
function WeaponShapes.melee(withArms: boolean, skinId: string?): Shape
	local id = WeaponConfig.Melee.id
	local look = lookOf(id, skinId)
	local built = WeaponModels.build(id, look) or fallback("Rifle", look)
	if not withArms then
		return withHands(built, false)
	end
	-- Na mão: o taco inteiro inclinado em volta da empunhadura
	for _, spec in built.parts do
		spec.cframe = MELEE_TILT * spec.cframe
	end
	-- A mão fecha em volta do cabo (que fica no eixo Z do taco): o Y da mão vai para a ponta
	local handle = MELEE_TILT * CFrame.new(0, 0, 0.05) * CFrame.Angles(math.rad(-90), 0, 0)
	return withHands({
		parts = built.parts,
		muzzle = MELEE_TILT * built.muzzle,
		leftHand = nil,
		grip = Vector3.new(0, 0, 0.05),
	}, true, handle)
end

-- Forma pelo ID da arma (WeaponConfig).
function WeaponShapes.forId(id: string, withArms: boolean, skinId: string?): Shape
	if id == WeaponConfig.Melee.id then
		return WeaponShapes.melee(withArms, skinId)
	end
	local def = WeaponConfig.get(id)
	return WeaponShapes.gun(if def then def.category else "Rifle", withArms, id, skinId)
end

-- Uma peça solta (sem física) a partir da descrição.
function WeaponShapes.makePart(spec: PartSpec): BasePart
	local part: BasePart
	if spec.wedge then
		part = Instance.new("WedgePart")
	else
		local p = Instance.new("Part")
		if spec.cylinder then
			p.Shape = Enum.PartType.Cylinder
		end
		part = p
	end
	part.Name = "Piece"
	part.Size = spec.size
	part.CFrame = spec.cframe
	part.Color = spec.color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	if spec.mag then
		part:SetAttribute(WeaponShapes.MagAttribute, true)
	end
	return part
end

-- Cantos arredondados (pedido do dono do projeto: armas menos quadradas). Cada caixa grande vira uma
-- "caixa de quinas redondas": duas caixas cruzadas, um pouco mais finas, e um cilindro em cada uma das
-- 4 quinas ao longo do lado mais comprido. Detalhes pequenos (serrilhado, dentes do trilho, frisos)
-- ficam retos: arredondar o que mal aparece só gastaria peças.
local ROUND_MIN_CROSS = 0.08 -- espessura mínima (studs) para arredondar
local ROUND_MIN_LENGTH = 0.16 -- comprimento mínimo
local ROUND_RATIO = 0.32 -- raio = 32% da menor espessura
local TURN_TO: { [string]: CFrame } = { -- o cilindro do Roblox fica deitado no eixo X
	X = CFrame.identity,
	Y = CFrame.Angles(0, 0, math.rad(90)),
	Z = CFrame.Angles(0, math.rad(90), 0),
}

-- Monta um Vector3 a partir de (comprimento, espessura U, espessura V) no eixo `axis`.
local function along(axis: string, l: number, u: number, v: number): Vector3
	if axis == "X" then
		return Vector3.new(l, u, v)
	elseif axis == "Y" then
		return Vector3.new(u, l, v)
	end
	return Vector3.new(u, v, l)
end

function WeaponShapes.smooth(parts: { PartSpec }): { PartSpec }
	local out: { PartSpec } = {}
	for _, spec in parts do
		if spec.cylinder or spec.wedge then
			table.insert(out, spec)
			continue
		end
		local s = spec.size
		local axis, length, a, b
		if s.Z >= s.X and s.Z >= s.Y then
			axis, length, a, b = "Z", s.Z, s.X, s.Y
		elseif s.X >= s.Y then
			axis, length, a, b = "X", s.X, s.Y, s.Z
		else
			axis, length, a, b = "Y", s.Y, s.X, s.Z
		end
		if math.min(a, b) < ROUND_MIN_CROSS or length < ROUND_MIN_LENGTH then
			table.insert(out, spec)
			continue
		end
		local r = math.min(a, b) * ROUND_RATIO
		-- As caixas vêm primeiro e mantêm o giro da peça (o pente usa o giro da 1ª peça na recarga)
		local function add(size: Vector3, offset: Vector3, turn: CFrame?, cylinder: boolean?)
			table.insert(out, {
				size = size,
				cframe = spec.cframe * CFrame.new(offset) * (turn or CFrame.identity),
				color = spec.color,
				cylinder = cylinder,
				mag = spec.mag,
			})
		end
		add(along(axis, length, a, b - 2 * r), Vector3.zero)
		add(along(axis, length, a - 2 * r, b), Vector3.zero)
		for _, su in { -1, 1 } do
			for _, sv in { -1, 1 } do
				-- o cilindro tem o comprimento em X; TURN_TO o deita no eixo da peça
				add(
					Vector3.new(length, 2 * r, 2 * r),
					along(axis, 0, su * (a / 2 - r), sv * (b / 2 - r)),
					TURN_TO[axis],
					true
				)
			end
		end
	end
	return out
end

-- Modelo solto com as peças da forma, para vitrines em ViewportFrame. `smooth` = quinas redondas
-- (vitrine grande; as miniaturas da grade ficam retas para economizar peças).
function WeaponShapes.buildModel(shape: Shape, smooth: boolean?): Model
	local model = Instance.new("Model")
	model.Name = "WeaponPreview"
	for _, spec in if smooth then WeaponShapes.smooth(shape.parts) else shape.parts do
		WeaponShapes.makePart(spec).Parent = model
	end
	-- Sem isto, a orientação da caixa envolvente (GetBoundingBox) vem da primeira peça, que pode estar
	-- girada (um cano cilíndrico), e a vitrine mostraria a arma de frente
	model.WorldPivot = CFrame.identity
	return model
end

return WeaponShapes
