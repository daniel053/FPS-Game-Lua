--!strict
-- Modelos LOW POLY das armas (provisórios até a arte final da F10), usados pela arma em primeira pessoa
-- (ViewModel, Partida e Tutorial) e pelas vitrines 3D da interface (Arsenal T5, modal T2). Só cliente.
-- Cada categoria tem uma forma base; cada arma tem as suas cores (Theme.WeaponLook) e peças próprias
-- para dar para diferenciar uma da outra (referência docs/referencias/ref-menus-armas.webp).
-- O cano aponta para -Z; Y para cima.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Types = require(Shared.Types)
local WeaponConfig = require(Shared.Config.WeaponConfig)

local COLORS = Theme.Combat

export type PartSpec = { size: Vector3, cframe: CFrame, color: Color3, cylinder: boolean? }

export type Shape = {
	parts: { PartSpec },
	muzzle: Vector3,
	leftHand: Vector3?, -- nil = uma mão só
}

type Look = { body: Color3, dark: Color3, light: Color3, accent: Color3 }

local WeaponShapes = {}

-- Peças -------------------------------------------------------------------------------------------

local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- o cilindro do Roblox fica deitado no eixo X
local ALONG_Y = CFrame.Angles(0, 0, math.rad(90))

local function box(size: Vector3, position: Vector3, color: Color3, rotation: CFrame?): PartSpec
	return { size = size, cframe = CFrame.new(position) * (rotation or CFrame.identity), color = color }
end

-- Cilindro ao longo de Z (cano, luneta), X (tambor de lado) ou Y (cartucho em pé).
local function cyl(length: number, diameter: number, center: Vector3, color: Color3, axis: string?): PartSpec
	local rotation = if axis == "X" then CFrame.identity elseif axis == "Y" then ALONG_Y else ALONG_Z
	return {
		size = Vector3.new(length, diameter, diameter),
		cframe = CFrame.new(center) * rotation,
		color = color,
		cylinder = true,
	}
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

local function lookOf(id: string?): Look
	local look = if id then Theme.WeaponLook[id] else nil
	local body = if look then look.body else COLORS.WeaponBody
	return {
		body = body,
		dark = if look then look.dark else COLORS.WeaponDark,
		light = body:Lerp(Color3.new(1, 1, 1), 0.25),
		accent = if look then look.accent else COLORS.WeaponLight,
	}
end

-- Faixa de destaque que abraça a peça (um pouco mais larga), vista dos dois lados.
local function band(parts: { PartSpec }, width: number, height: number, z: number, y: number, color: Color3)
	table.insert(parts, box(Vector3.new(width + 0.02, height, 0.05), Vector3.new(0, y, z), color))
end

-- Forma base de cada categoria ---------------------------------------------------------------------

local GRIP = Vector3.new(0, -0.18, 0.02)
local TILT = CFrame.Angles(math.rad(-15), 0, 0)

local function base(category: Types.WeaponCategory, c: Look, parts: { PartSpec }): (Vector3, Vector3?)
	local body, dark, light = c.body, c.dark, c.light
	if category == "Pistol" then
		table.insert(parts, box(Vector3.new(0.22, 0.3, 0.75), Vector3.new(0, 0.12, -0.2), body))
		table.insert(parts, box(Vector3.new(0.12, 0.12, 0.25), Vector3.new(0, 0.17, -0.68), dark))
		table.insert(parts, box(Vector3.new(0.2, 0.45, 0.22), GRIP, dark, TILT))
		table.insert(parts, box(Vector3.new(0.06, 0.12, 0.16), Vector3.new(0, -0.08, -0.1), dark)) -- guarda
		return Vector3.new(0, 0.17, -0.82), nil
	elseif category == "SMG" then
		table.insert(parts, box(Vector3.new(0.3, 0.4, 1.2), Vector3.new(0, 0.12, -0.35), body))
		table.insert(parts, box(Vector3.new(0.12, 0.12, 0.5), Vector3.new(0, 0.18, -1.2), dark))
		table.insert(parts, box(Vector3.new(0.2, 0.6, 0.22), Vector3.new(0, -0.3, -0.5), dark))
		table.insert(parts, box(Vector3.new(0.2, 0.4, 0.22), GRIP, dark, TILT))
		table.insert(parts, box(Vector3.new(0.18, 0.25, 0.5), Vector3.new(0, 0.1, 0.5), light))
		table.insert(parts, box(Vector3.new(0.1, 0.08, 0.5), Vector3.new(0, 0.36, -0.3), dark)) -- trilho
		return Vector3.new(0, 0.18, -1.45), Vector3.new(0, -0.05, -0.8)
	elseif category == "Shotgun" then
		table.insert(parts, box(Vector3.new(0.32, 0.4, 1.4), Vector3.new(0, 0.12, -0.4), body))
		table.insert(parts, cyl(1.1, 0.2, Vector3.new(0, 0.24, -1.55), dark))
		table.insert(parts, box(Vector3.new(0.27, 0.22, 0.6), Vector3.new(0, 0.02, -1.3), light))
		table.insert(parts, box(Vector3.new(0.26, 0.32, 0.45), Vector3.new(0, 0.05, 0.42), light))
		table.insert(parts, box(Vector3.new(0.2, 0.4, 0.22), GRIP, dark, TILT))
		return Vector3.new(0, 0.24, -2.1), Vector3.new(0, -0.1, -1.3)
	elseif category == "MachineGun" then
		table.insert(parts, box(Vector3.new(0.42, 0.55, 1.8), Vector3.new(0, 0.15, -0.5), body))
		table.insert(parts, cyl(1.0, 0.18, Vector3.new(0, 0.2, -1.9), dark))
		table.insert(parts, box(Vector3.new(0.45, 0.5, 0.5), Vector3.new(0, -0.35, -0.6), dark))
		table.insert(parts, box(Vector3.new(0.22, 0.42, 0.24), GRIP, dark, TILT))
		table.insert(parts, box(Vector3.new(0.28, 0.36, 0.45), Vector3.new(0, 0.08, 0.45), light))
		return Vector3.new(0, 0.2, -2.4), Vector3.new(0, -0.12, -1.25)
	elseif category == "Sniper" then
		table.insert(parts, box(Vector3.new(0.3, 0.4, 1.8), Vector3.new(0, 0.12, -0.5), body))
		table.insert(parts, cyl(1.3, 0.11, Vector3.new(0, 0.18, -2.0), dark))
		table.insert(parts, box(Vector3.new(0.22, 0.35, 0.3), Vector3.new(0, -0.22, -0.55), dark))
		table.insert(parts, box(Vector3.new(0.26, 0.4, 0.5), Vector3.new(0, 0.05, 0.5), light))
		table.insert(parts, box(Vector3.new(0.2, 0.4, 0.22), GRIP, dark, TILT))
		return Vector3.new(0, 0.18, -2.65), Vector3.new(0, -0.05, -1.2)
	end
	-- Fuzis e fuzis leves (referência do guia)
	table.insert(parts, box(Vector3.new(0.32, 0.45, 1.6), Vector3.new(0, 0.15, -0.45), body))
	table.insert(parts, cyl(0.9, 0.13, Vector3.new(0, 0.22, -1.7), dark))
	table.insert(parts, box(Vector3.new(0.24, 0.6, 0.3), Vector3.new(0, -0.3, -0.6), dark))
	table.insert(parts, box(Vector3.new(0.2, 0.42, 0.22), GRIP, dark, TILT))
	table.insert(parts, box(Vector3.new(0.26, 0.36, 0.45), Vector3.new(0, 0.1, 0.45), light))
	table.insert(parts, box(Vector3.new(0.34, 0.3, 0.6), Vector3.new(0, 0.18, -1.0), light)) -- guarda-mão
	return Vector3.new(0, 0.22, -2.15), Vector3.new(0, -0.05, -1.05)
end

-- Peças próprias de cada arma (o que diferencia uma da outra) -----------------------------------------

local EXTRAS: { [string]: (c: Look, parts: { PartSpec }) -> () } = {
	weapon_bolinha = function(c, parts)
		table.insert(parts, box(Vector3.new(0.23, 0.04, 0.6), Vector3.new(0, 0.28, -0.2), c.accent))
		table.insert(parts, box(Vector3.new(0.08, 0.06, 0.06), Vector3.new(0, 0.3, 0.12), c.dark))
	end,
	weapon_chumbinho = function(c, parts)
		table.insert(parts, cyl(0.34, 0.22, Vector3.new(0, 0.17, -0.82), c.dark)) -- boca larga
		table.insert(parts, cyl(0.06, 0.24, Vector3.new(0, 0.17, -0.7), c.accent))
	end,
	weapon_zumbido = function(c, parts)
		table.insert(parts, box(Vector3.new(0.16, 0.42, 0.18), Vector3.new(0, -0.55, 0.08), c.dark)) -- pente longo
		band(parts, 0.22, 0.31, -0.42, 0.12, c.accent)
		band(parts, 0.22, 0.31, -0.28, 0.12, c.accent)
	end,
	weapon_precisa = function(c, parts)
		table.insert(parts, cyl(0.5, 0.15, Vector3.new(0, 0.17, -1.0), c.dark)) -- silenciador
		table.insert(parts, box(Vector3.new(0.235, 0.05, 0.55), Vector3.new(0, 0.05, -0.2), c.accent))
	end,
	weapon_tambor = function(c, parts)
		table.insert(parts, cyl(0.3, 0.34, Vector3.new(0, 0.12, -0.08), c.light)) -- tambor do revólver
		table.insert(parts, cyl(0.6, 0.12, Vector3.new(0, 0.2, -0.75), c.dark))
		table.insert(parts, cyl(0.05, 0.36, Vector3.new(0, 0.12, -0.24), c.accent))
	end,
	weapon_ferrao = function(c, parts)
		table.insert(parts, cyl(0.14, 0.17, Vector3.new(0, 0.18, -1.42), c.accent)) -- ponta do cano
		table.insert(parts, box(Vector3.new(0.14, 0.3, 0.14), Vector3.new(0, -0.18, -0.95), c.dark)) -- empunhadura
		table.insert(parts, box(Vector3.new(0.31, 0.05, 0.9), Vector3.new(0, 0.33, -0.35), c.accent))
	end,
	weapon_vespa = function(c, parts)
		band(parts, 0.3, 0.41, -0.65, 0.12, c.accent)
		band(parts, 0.3, 0.41, -0.15, 0.12, c.accent)
		band(parts, 0.2, 0.2, -0.5, -0.45, c.accent) -- pente listrado
	end,
	weapon_balde = function(c, parts)
		for i = 0, 3 do -- cartuchos na lateral
			table.insert(parts, cyl(0.2, 0.08, Vector3.new(0.18, 0.12, -0.05 - i * 0.1), c.accent, "X"))
		end
		table.insert(parts, box(Vector3.new(0.29, 0.24, 0.5), Vector3.new(0, 0.02, -1.3), c.dark)) -- bomba
	end,
	weapon_varredor = function(c, parts)
		table.insert(parts, cyl(0.24, 0.52, Vector3.new(0, -0.28, -0.55), c.dark, "X")) -- carregador de tambor
		table.insert(parts, cyl(0.26, 0.2, Vector3.new(0, -0.28, -0.55), c.accent, "X"))
	end,
	weapon_tatico = function(c, parts)
		table.insert(parts, box(Vector3.new(0.14, 0.14, 0.22), Vector3.new(0, 0.45, -0.35), c.dark)) -- mira
		table.insert(parts, box(Vector3.new(0.08, 0.06, 0.02), Vector3.new(0, 0.48, -0.47), c.accent))
		band(parts, 0.24, 0.12, -0.6, -0.4, c.accent)
	end,
	weapon_atirador = function(c, parts)
		table.insert(parts, cyl(0.7, 0.17, Vector3.new(0, 0.52, -0.4), c.dark)) -- luneta curta
		table.insert(parts, cyl(0.05, 0.2, Vector3.new(0, 0.52, -0.75), c.accent))
		table.insert(parts, cyl(0.45, 0.1, Vector3.new(0, 0.22, -2.35), c.dark)) -- cano mais longo
	end,
	weapon_rajada = function(c, parts)
		band(parts, 0.34, 0.31, -0.85, 0.18, c.accent)
		band(parts, 0.34, 0.31, -1.15, 0.18, c.accent)
		table.insert(parts, cyl(0.12, 0.17, Vector3.new(0, 0.22, -2.15), c.accent))
	end,
	weapon_trovao = function(c, parts)
		table.insert(parts, box(Vector3.new(0.2, 0.18, 0.3), Vector3.new(0, 0.22, -2.2), c.dark)) -- freio de boca
		table.insert(parts, box(Vector3.new(0.35, 0.06, 0.6), Vector3.new(0, 0.34, -1.0), c.accent))
		table.insert(parts, box(Vector3.new(0.16, 0.12, 0.4), Vector3.new(0, 0.44, -0.3), c.dark))
	end,
	weapon_matapato = function(c, parts)
		table.insert(parts, cyl(0.6, 0.16, Vector3.new(0, 0.48, -0.45), c.dark))
		table.insert(parts, box(Vector3.new(0.31, 0.05, 1.2), Vector3.new(0, 0.33, -0.5), c.accent))
	end,
	weapon_gemea = function(c, parts)
		table.insert(parts, cyl(1.3, 0.11, Vector3.new(0, 0.32, -2.0), c.dark)) -- segundo cano
		table.insert(parts, cyl(0.7, 0.18, Vector3.new(0, 0.55, -0.45), c.dark))
		table.insert(parts, cyl(0.06, 0.2, Vector3.new(0, 0.55, -0.82), c.accent))
	end,
	weapon_luneta = function(c, parts)
		table.insert(parts, cyl(1.05, 0.3, Vector3.new(0, 0.58, -0.5), c.dark)) -- luneta grande
		table.insert(parts, cyl(0.08, 0.34, Vector3.new(0, 0.58, -1.02), c.accent))
		table.insert(parts, cyl(0.08, 0.34, Vector3.new(0, 0.58, 0.02), c.accent))
		for _, x in { -0.14, 0.14 } do -- bipé
			table.insert(parts, box(Vector3.new(0.05, 0.5, 0.05), Vector3.new(x, -0.15, -1.3), c.dark))
		end
	end,
	weapon_martelo = function(c, parts)
		table.insert(parts, box(Vector3.new(0.12, 0.12, 0.6), Vector3.new(0, 0.55, -0.5), c.dark)) -- alça
		band(parts, 0.45, 0.51, -0.6, -0.35, c.accent)
		band(parts, 0.42, 0.56, -1.2, 0.15, c.accent)
	end,
	weapon_moedor = function(c, parts)
		table.insert(parts, cyl(0.5, 0.44, Vector3.new(0, 0.15, -1.55), c.body)) -- carcaça
		for i = 0, 5 do -- 6 canos girando em volta do eixo
			local angle = i * math.pi / 3
			local offset = Vector3.new(math.cos(angle) * 0.12, 0.15 + math.sin(angle) * 0.12, -2.0)
			table.insert(parts, cyl(0.9, 0.07, offset, c.dark))
		end
		table.insert(parts, cyl(0.07, 0.38, Vector3.new(0, 0.15, -2.35), c.accent))
	end,
}

-- API ------------------------------------------------------------------------------------------------

-- Arma de fogo de uma categoria. withArms = mãos e mangas (primeira pessoa); sem = só a arma (vitrine).
-- `id` (opcional) aplica as cores e as peças próprias daquela arma.
function WeaponShapes.gun(category: Types.WeaponCategory, withArms: boolean, id: string?): Shape
	local look = lookOf(id)
	local parts: { PartSpec } = {}
	local muzzle, leftHand = base(category, look, parts)
	local extras = if id then EXTRAS[id] else nil
	if extras then
		extras(look, parts)
	end
	if withArms then
		arm(GRIP + Vector3.new(0, -0.05, 0.05), Vector3.new(0.3, -1.3, 0.8), parts)
		if leftHand then
			arm(leftHand, Vector3.new(-0.7, -1.3, 0.1), parts)
		end
	end
	return { parts = parts, muzzle = muzzle, leftHand = leftHand }
end

-- Bastão: taco de madeira low poly (cabo com fita escura, corpo que engrossa, ponta mais clara).
function WeaponShapes.melee(withArms: boolean): Shape
	local look = lookOf(WeaponConfig.Melee.id)
	local wood, light = look.body, look.body:Lerp(Color3.new(1, 1, 1), 0.2)
	-- Na mão fica inclinado (primeira pessoa); na vitrine, deitado como as outras armas
	local tilt = if withArms then CFrame.Angles(math.rad(62), math.rad(-8), math.rad(-12)) else CFrame.identity
	local function along(length: number, diameter: number, z: number, color: Color3): PartSpec
		return {
			size = Vector3.new(length, diameter, diameter),
			cframe = tilt * CFrame.new(0, 0, z) * ALONG_Z,
			color = color,
			cylinder = true,
		}
	end
	local parts: { PartSpec } = {
		along(0.06, 0.2, 0.32, look.dark), -- pomo
		along(0.6, 0.13, 0.0, look.dark), -- cabo com fita
		along(0.45, 0.17, -0.5, wood),
		along(0.45, 0.21, -0.92, wood),
		along(0.06, 0.23, -0.72, look.accent), -- anel
		along(0.42, 0.25, -1.33, light),
	}
	if withArms then
		arm(Vector3.new(0, -0.05, 0.1), Vector3.new(0.3, -1.3, 0.8), parts)
	end
	return { parts = parts, muzzle = (tilt * CFrame.new(0, 0, -1.55)).Position, leftHand = nil }
end

-- Forma pelo ID da arma (WeaponConfig): cores e peças daquela arma.
function WeaponShapes.forId(id: string, withArms: boolean): Shape
	if id == WeaponConfig.Melee.id then
		return WeaponShapes.melee(withArms)
	end
	local def = WeaponConfig.get(id)
	return WeaponShapes.gun(if def then def.category else "Rifle", withArms, id)
end

-- Uma peça solta (sem física) a partir da descrição.
function WeaponShapes.makePart(spec: PartSpec): Part
	local part = Instance.new("Part")
	part.Name = "Piece"
	if spec.cylinder then
		part.Shape = Enum.PartType.Cylinder
	end
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
	return model
end

return WeaponShapes
