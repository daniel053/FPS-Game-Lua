--!strict
-- Formas das armas para a arma em primeira pessoa (ViewModel, Partida e Tutorial) e para as vitrines
-- 3D da interface (Arsenal T5, modal T2). Só cliente.
-- Cada arma usa o seu modelo detalhado (WeaponModels) com as cores do Theme.WeaponLook; a forma simples
-- por categoria só aparece para uma arma que ainda não tenha modelo. Com as mãos (primeira pessoa),
-- a mão direita fica na empunhadura do modelo e a esquerda no guarda-mão.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
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

local function arm(hand: Vector3, elbow: Vector3, parts: { PartSpec })
	table.insert(parts, box(Vector3.new(0.3, 0.3, 0.34), hand, COLORS.Glove))
	local wrist = hand + (elbow - hand).Unit * 0.2
	table.insert(parts, segment(wrist, elbow, 0.34, COLORS.Sleeve))
end

local function lookOf(id: string?): WeaponModels.Look
	local look = if id then Theme.WeaponLook[id] else nil
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
	table.insert(parts, box(Vector3.new(0.2, 0.42, 0.22), grip, c.dark, tilt))
	return { parts = parts, muzzle = Vector3.new(0, 0.2, -2.0), leftHand = Vector3.new(0, -0.05, -1.0), grip = grip }
end

local function withHands(built: WeaponModels.Built, withArms: boolean): Shape
	local parts = built.parts
	if withArms then
		arm(built.grip + Vector3.new(0, -0.05, 0.05), Vector3.new(0.3, -1.3, 0.8), parts)
		local left = built.leftHand
		if left then
			arm(left, Vector3.new(-0.7, -1.3, 0.1), parts)
		end
	end
	return { parts = parts, muzzle = built.muzzle, leftHand = built.leftHand }
end

-- Arma de fogo. `id` escolhe o modelo e as cores; sem id (ou sem modelo), a forma da categoria.
function WeaponShapes.gun(category: Types.WeaponCategory, withArms: boolean, id: string?): Shape
	local look = lookOf(id)
	local built = (if id then WeaponModels.build(id, look) else nil) or fallback(category, look)
	return withHands(built, withArms)
end

-- Bastão (corpo a corpo).
function WeaponShapes.melee(withArms: boolean): Shape
	local id = WeaponConfig.Melee.id
	local built = WeaponModels.build(id, lookOf(id)) or fallback("Rifle", lookOf(id))
	if not withArms then
		return withHands(built, false)
	end
	-- Na mão: o taco inteiro inclinado em volta da empunhadura
	for _, spec in built.parts do
		spec.cframe = MELEE_TILT * spec.cframe
	end
	return withHands({
		parts = built.parts,
		muzzle = MELEE_TILT * built.muzzle,
		leftHand = nil,
		grip = Vector3.new(0, 0, 0.05),
	}, true)
end

-- Forma pelo ID da arma (WeaponConfig).
function WeaponShapes.forId(id: string, withArms: boolean): Shape
	if id == WeaponConfig.Melee.id then
		return WeaponShapes.melee(withArms)
	end
	local def = WeaponConfig.get(id)
	return WeaponShapes.gun(if def then def.category else "Rifle", withArms, id)
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
	return part
end

-- Modelo solto com as peças da forma, para vitrines em ViewportFrame.
function WeaponShapes.buildModel(shape: Shape): Model
	local model = Instance.new("Model")
	model.Name = "WeaponPreview"
	for _, spec in shape.parts do
		WeaponShapes.makePart(spec).Parent = model
	end
	-- Sem isto, a orientação da caixa envolvente (GetBoundingBox) vem da primeira peça, que pode estar
	-- girada (um cano cilíndrico), e a vitrine mostraria a arma de frente
	model.WorldPivot = CFrame.identity
	return model
end

return WeaponShapes
