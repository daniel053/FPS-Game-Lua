--!strict
-- Formas de BLOCOS das armas (provisórias até a F10), usadas pela arma em primeira pessoa (ViewModel,
-- Partida e Tutorial) e pelas vitrines 3D da interface (Arsenal, T5). Só cliente.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Types = require(Shared.Types)

local COLORS = Theme.Combat

export type PartSpec = { size: Vector3, cframe: CFrame, color: Color3 }

export type Shape = {
	parts: { PartSpec },
	muzzle: Vector3,
	leftHand: Vector3?, -- nil = uma mão só
}

local WeaponShapes = {}

-- Formas -----------------------------------------------------------------------------------------

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

-- Arma de fogo de uma categoria. withArms = mãos e mangas (primeira pessoa); sem = só a arma (vitrine).
function WeaponShapes.gun(category: Types.WeaponCategory, withArms: boolean): Shape
	local body, dark, light = COLORS.WeaponBody, COLORS.WeaponDark, COLORS.WeaponLight
	local grip = Vector3.new(0, -0.18, 0.02)
	local tilt = CFrame.Angles(math.rad(-15), 0, 0)
	local parts: { PartSpec } = {}
	local muzzle: Vector3
	local leftHand: Vector3? = nil

	if category == "Pistol" then
		table.insert(parts, box(Vector3.new(0.22, 0.3, 0.75), Vector3.new(0, 0.12, -0.2), body))
		table.insert(parts, box(Vector3.new(0.12, 0.12, 0.25), Vector3.new(0, 0.17, -0.68), dark))
		table.insert(parts, box(Vector3.new(0.2, 0.45, 0.22), grip, dark, tilt))
		muzzle = Vector3.new(0, 0.17, -0.82)
	elseif category == "SMG" then
		table.insert(parts, box(Vector3.new(0.3, 0.4, 1.2), Vector3.new(0, 0.12, -0.35), body))
		table.insert(parts, box(Vector3.new(0.12, 0.12, 0.5), Vector3.new(0, 0.18, -1.2), dark))
		table.insert(parts, box(Vector3.new(0.2, 0.6, 0.22), Vector3.new(0, -0.3, -0.5), dark))
		table.insert(parts, box(Vector3.new(0.2, 0.4, 0.22), grip, dark, tilt))
		table.insert(parts, box(Vector3.new(0.18, 0.25, 0.5), Vector3.new(0, 0.1, 0.5), light))
		muzzle = Vector3.new(0, 0.18, -1.45)
		leftHand = Vector3.new(0, -0.05, -0.8)
	elseif category == "Shotgun" then
		table.insert(parts, box(Vector3.new(0.32, 0.4, 1.4), Vector3.new(0, 0.12, -0.4), body))
		table.insert(parts, box(Vector3.new(0.2, 0.2, 1.1), Vector3.new(0, 0.24, -1.55), dark))
		table.insert(parts, box(Vector3.new(0.27, 0.22, 0.6), Vector3.new(0, 0.02, -1.3), light))
		table.insert(parts, box(Vector3.new(0.26, 0.32, 0.45), Vector3.new(0, 0.05, 0.42), light))
		table.insert(parts, box(Vector3.new(0.2, 0.4, 0.22), grip, dark, tilt))
		muzzle = Vector3.new(0, 0.24, -2.1)
		leftHand = Vector3.new(0, -0.1, -1.3)
	elseif category == "MachineGun" then
		table.insert(parts, box(Vector3.new(0.42, 0.55, 1.8), Vector3.new(0, 0.15, -0.5), body))
		table.insert(parts, box(Vector3.new(0.18, 0.18, 1.0), Vector3.new(0, 0.2, -1.9), dark))
		table.insert(parts, box(Vector3.new(0.45, 0.5, 0.5), Vector3.new(0, -0.35, -0.6), dark))
		table.insert(parts, box(Vector3.new(0.22, 0.42, 0.24), grip, dark, tilt))
		table.insert(parts, box(Vector3.new(0.28, 0.36, 0.45), Vector3.new(0, 0.08, 0.45), light))
		muzzle = Vector3.new(0, 0.2, -2.4)
		leftHand = Vector3.new(0, -0.12, -1.25)
	elseif category == "Sniper" then
		table.insert(parts, box(Vector3.new(0.3, 0.4, 1.8), Vector3.new(0, 0.12, -0.5), body))
		table.insert(parts, box(Vector3.new(0.11, 0.11, 1.3), Vector3.new(0, 0.18, -2.0), dark))
		table.insert(parts, box(Vector3.new(0.2, 0.2, 0.9), Vector3.new(0, 0.48, -0.45), dark))
		table.insert(parts, box(Vector3.new(0.22, 0.35, 0.3), Vector3.new(0, -0.22, -0.55), dark))
		table.insert(parts, box(Vector3.new(0.26, 0.4, 0.5), Vector3.new(0, 0.05, 0.5), light))
		table.insert(parts, box(Vector3.new(0.2, 0.4, 0.22), grip, dark, tilt))
		muzzle = Vector3.new(0, 0.18, -2.65)
		leftHand = Vector3.new(0, -0.05, -1.2)
	else -- Fuzis e fuzis leves (referência do guia)
		table.insert(parts, box(Vector3.new(0.32, 0.45, 1.6), Vector3.new(0, 0.15, -0.45), body))
		table.insert(parts, box(Vector3.new(0.13, 0.13, 0.9), Vector3.new(0, 0.22, -1.7), dark))
		table.insert(parts, box(Vector3.new(0.24, 0.6, 0.3), Vector3.new(0, -0.3, -0.6), dark))
		table.insert(parts, box(Vector3.new(0.2, 0.42, 0.22), grip, dark, tilt))
		table.insert(parts, box(Vector3.new(0.26, 0.36, 0.45), Vector3.new(0, 0.1, 0.45), light))
		table.insert(parts, box(Vector3.new(0.12, 0.14, 0.35), Vector3.new(0, 0.45, -0.35), dark))
		muzzle = Vector3.new(0, 0.22, -2.15)
		leftHand = Vector3.new(0, -0.05, -1.05)
	end

	if withArms then
		arm(grip + Vector3.new(0, -0.05, 0.05), Vector3.new(0.3, -1.3, 0.8), parts)
		if leftHand then
			arm(leftHand, Vector3.new(-0.7, -1.3, 0.1), parts)
		end
	end
	return { parts = parts, muzzle = muzzle, leftHand = leftHand }
end

function WeaponShapes.melee(withArms: boolean): Shape
	local tilt = CFrame.Angles(math.rad(62), math.rad(-8), math.rad(-12))
	local parts: { PartSpec } = {
		{ size = Vector3.new(0.16, 0.16, 0.6), cframe = tilt, color = COLORS.MeleeHandle },
		{
			size = Vector3.new(0.2, 0.2, 1.2),
			cframe = tilt * CFrame.new(0, 0, -0.85),
			color = COLORS.WeaponLight,
		},
	}
	if withArms then
		arm(Vector3.new(0, -0.05, 0.1), Vector3.new(0.3, -1.3, 0.8), parts)
	end
	return { parts = parts, muzzle = (tilt * CFrame.new(0, 0, -1.45)).Position, leftHand = nil }
end

-- Modelo solto (sem física) com as peças da forma, para vitrines em ViewportFrame.
function WeaponShapes.buildModel(shape: Shape): Model
	local model = Instance.new("Model")
	model.Name = "WeaponPreview"
	for _, spec in shape.parts do
		local part = Instance.new("Part")
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
		part.Parent = model
	end
	return model
end

-- Forma da arma pelo ID (WeaponConfig), sem as mãos.
function WeaponShapes.forWeapon(category: string): Shape
	if category == "Melee" then
		return WeaponShapes.melee(false)
	end
	return WeaponShapes.gun(category :: Types.WeaponCategory, false)
end

return WeaponShapes
