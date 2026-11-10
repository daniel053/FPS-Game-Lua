--!strict
-- Vitrine 3D de uma arma (ESTILO T2 e T5): o modelo de blocos (WeaponShapes) num ViewportFrame,
-- visto de lado, com a câmera ajustada ao tamanho da arma. `spin` = gira devagar (painel do Arsenal).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponShapes = require(Shared.Combat.WeaponShapes)

export type Preview = {
	root: ViewportFrame,
	set: (weaponId: string?) -> (),
	destroy: () -> (),
}

local SPIN_DEGREES_PER_SECOND = 30

local WeaponPreview = {}

local function categoryOf(weaponId: string): string?
	if weaponId == WeaponConfig.Melee.id then
		return "Melee"
	end
	local def = WeaponConfig.get(weaponId)
	return if def then def.category else nil
end

function WeaponPreview.new(parent: Instance, spin: boolean): Preview
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "WeaponPreview"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(170, 170, 185)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.6)
	viewport.Parent = parent

	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local model: Model? = nil
	local angle = 0
	local connection: RBXScriptConnection? = nil

	local function place()
		local m = model
		if m == nil then
			return
		end
		m:PivotTo(CFrame.Angles(0, math.rad(angle), 0))
	end

	local function set(weaponId: string?)
		if model then
			model:Destroy()
			model = nil
		end
		local category = if weaponId then categoryOf(weaponId) else nil
		if category == nil then
			return
		end
		local m = WeaponShapes.buildModel(WeaponShapes.forWeapon(category))
		-- Centraliza o modelo na origem
		local cf, size = m:GetBoundingBox()
		for _, part in m:GetChildren() do
			if part:IsA("BasePart") then
				part.CFrame = cf:Inverse() * part.CFrame
			end
		end
		local holder = Instance.new("Part")
		holder.Name = "Pivot"
		holder.Transparency = 1
		holder.Size = Vector3.one * 0.05
		holder.Anchored = true
		holder.CFrame = CFrame.identity
		holder.Parent = m
		m.PrimaryPart = holder
		m.Parent = viewport
		model = m
		-- Vista de lado (o cano aponta para -Z): câmera no +X, longe o bastante para caber a arma
		local radius = size.Magnitude / 2
		local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.1
		camera.CFrame = CFrame.lookAt(Vector3.new(distance, radius * 0.25, 0), Vector3.zero)
		angle = 0
		place()
	end

	if spin then
		connection = RunService.RenderStepped:Connect(function(dt: number)
			if model and viewport.Visible then
				angle = (angle + SPIN_DEGREES_PER_SECOND * dt) % 360
				place()
			end
		end)
	end

	return {
		root = viewport,
		set = set,
		destroy = function()
			if connection then
				connection:Disconnect()
			end
			viewport:Destroy()
		end,
	}
end

return WeaponPreview
