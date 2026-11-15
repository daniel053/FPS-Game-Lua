--!strict
-- Esteiras da Fábrica (GDD 15.5, KIT-MODULAR 3): quem pisa na correia é carregado no sentido das
-- setas, e as caixas de papelão andam com ela e reaparecem no início.
--
-- O mundo é montado com tudo ancorado (`Shared/Maps`). Aqui, só no servidor da partida:
--   * a correia (peça com o atributo `Conveyor`) ganha velocidade de superfície: o Roblox carrega
--     o personagem que está em cima, sem mexer na peça;
--   * cada caixa (atributo `ConveyorBox`) é solta e presa à sua correia por um trilho
--     (PrismaticConstraint com motor): só anda ao longo da esteira, não gira e ninguém a empurra
--     para o lado. O servidor é o dono da física dela (o tiro é validado contra a posição real).
--     Ao chegar ao fim da correia, volta para o início.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Kit = require(Shared.Maps.Kits.Fabrica)
local MapConfig = require(Shared.Config.MapConfig)

local Conveyors = {}

type Rider = {
	box: BasePart,
	belt: BasePart,
	travel: number, -- quanto a caixa anda antes de voltar ao início
	limit: number, -- posição (no X local da correia) em que ela volta
}

local MOTOR_FORCE = 1e6

local connection: RBXScriptConnection? = nil

-- A correia em que a caixa está apoiada (a caixa fica dentro do retângulo da correia, visto de cima).
local function beltUnder(box: BasePart, belts: { BasePart }): BasePart?
	for _, belt in belts do
		local p = belt.CFrame:PointToObjectSpace(box.Position)
		if math.abs(p.X) <= belt.Size.X / 2 and math.abs(p.Z) <= belt.Size.Z / 2 then
			return belt
		end
	end
	return nil
end

local function release(box: BasePart, belt: BasePart, speed: number): boolean
	-- O acabamento da caixa (fita, etiqueta) anda soldado nela
	local model = box.Parent
	if model then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part ~= box then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = box
				weld.Part1 = part
				weld.Parent = part
				part.Massless = true
				part.Anchored = false
			end
		end
	end

	-- Trilho: o eixo X dos dois encaixes é o sentido da correia (o X local dela). O encaixe fixo fica
	-- na base da esteira, e não na correia: a correia tem velocidade de superfície, e o motor do
	-- trilho somaria com ela (a caixa andaria ao dobro da velocidade).
	local conveyor = belt.Parent
	local fixed = if conveyor and conveyor:IsA("Model") and conveyor.PrimaryPart then conveyor.PrimaryPart else nil
	if fixed == nil or fixed == belt then
		return false
	end
	local axis = belt.CFrame.Rotation + box.Position
	local onBelt = Instance.new("Attachment")
	onBelt.Name = "Trilho"
	onBelt.Parent = fixed
	onBelt.WorldCFrame = axis
	local onBox = Instance.new("Attachment")
	onBox.Name = "Trilho"
	onBox.Parent = box
	onBox.WorldCFrame = axis

	local rail = Instance.new("PrismaticConstraint")
	rail.Name = "Trilho"
	rail.Attachment0 = onBelt
	rail.Attachment1 = onBox
	rail.ActuatorType = Enum.ActuatorType.Motor
	rail.Velocity = speed
	rail.MotorMaxForce = MOTOR_FORCE
	rail.Parent = box

	box.Anchored = false
	box:SetNetworkOwner(nil)
	return true
end

-- Liga as esteiras de `world` (a pasta do mundo da partida). Chamar uma vez, depois de montar o mundo.
function Conveyors.start(world: Instance)
	local speed = MapConfig.Fabrica.ConveyorSpeed
	local belts: { BasePart } = {}
	local boxes: { BasePart } = {}
	for _, item in world:GetDescendants() do
		if item:IsA("BasePart") then
			local direction = item:GetAttribute(Kit.ConveyorAttribute)
			if typeof(direction) == "Vector3" then
				item.AssemblyLinearVelocity = direction * speed
				table.insert(belts, item)
			elseif item:GetAttribute(Kit.ConveyorBoxAttribute) then
				table.insert(boxes, item)
			end
		end
	end

	local riders: { Rider } = {}
	for _, box in boxes do
		local belt = beltUnder(box, belts)
		if belt and release(box, belt, speed) then
			local travel = belt.Size.X - box.Size.X
			table.insert(riders, { box = box, belt = belt, travel = travel, limit = travel / 2 })
		end
	end

	if connection then
		connection:Disconnect()
	end
	connection = RunService.Heartbeat:Connect(function()
		for _, rider in riders do
			local x = rider.belt.CFrame:PointToObjectSpace(rider.box.Position).X
			if x >= rider.limit then
				rider.box.CFrame -= rider.belt.CFrame.XVector * rider.travel
			end
		end
	end)
end

return Conveyors
