--!strict
-- Arma na mão dos outros combatentes (jogadores e bots), vista de fora (pedido do dono do projeto
-- depois da F10). O servidor diz qual arma cada um segura agora (atributo HeldWeapon no corpo, que
-- muda ao trocar de arma); aqui:
--   * o modelo da arma (WeaponShapes, o mesmo da primeira pessoa e do Arsenal) fica preso na mão direita;
--   * os braços ficam na pose de mira (duas mãos nas armas de fogo, uma no Bastão) e sobem e descem com
--     para onde a pessoa olha (atributo LookDir, o mesmo de espectar o parceiro);
--   * a boca do cano tem um ponto (Muzzle): o tiro dos outros sai dali (CombatEffects).
-- Só visual e só no cliente: as peças não colidem, não recebem tiro e não bloqueiam a visão. O próprio
-- jogador não entra (ele vê a arma em primeira pessoa).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local MatchTypes = require(Shared.Match.MatchTypes)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponShapes = require(Shared.Combat.WeaponShapes)

local CFG = CombatConfig.HeldWeapon
local ATTR = CombatNames.Attr

-- Junta do corpo: Motor6D (corpo clássico) ou AnimationConstraint (corpo novo do Roblox, que os
-- avatares e os bots usam hoje). As duas têm Transform, que a animação escreve a cada quadro.
type Joint = Motor6D | AnimationConstraint

type Joints = {
	rightShoulder: Joint?,
	rightElbow: Joint?,
	rightWrist: Joint?,
	leftShoulder: Joint?,
	leftElbow: Joint?,
	leftWrist: Joint?,
}

type Rig = {
	model: Model,
	weaponId: string?,
	weapon: Model?,
	parts: { BasePart },
	hand: BasePart?,
	pose: string, -- "TwoHanded", "Pistol" ou "Melee"
	joints: Joints,
	hidden: number, -- transparência local da mão (espectar o parceiro esconde o corpo dele)
	connections: { RBXScriptConnection },
}

local HeldWeapons = {}

local player = Players.LocalPlayer
local rigs: { [Model]: Rig } = {}

-- Quadro da arma em relação à mão direita: o cano (−Z da arma) vai na direção do braço (−Y da mão) e
-- o cima da arma fica no −Z da mão (com o braço esticado para a frente, −Z da mão aponta para cima).
local GRIP_FRAME = CFrame.fromMatrix(CFG.GripOffset, Vector3.xAxis, -Vector3.zAxis, Vector3.yAxis)

local function isJoint(instance: Instance): boolean
	return instance:IsA("Motor6D") or instance:IsA("AnimationConstraint")
end

local function motor(model: Model, partName: string, jointName: string): Joint?
	local part = model:FindFirstChild(partName)
	local joint = part and part:FindFirstChild(jointName)
	if joint and joint:IsA("Motor6D") then
		return joint
	elseif joint and joint:IsA("AnimationConstraint") then
		return joint
	end
	return nil
end

-- Com StreamingEnabled o corpo pode chegar aos pedaços: as juntas são procuradas de novo quando chegam.
local function findJoints(model: Model): Joints
	return {
		rightShoulder = motor(model, "RightUpperArm", "RightShoulder"),
		rightElbow = motor(model, "RightLowerArm", "RightElbow"),
		rightWrist = motor(model, "RightHand", "RightWrist"),
		leftShoulder = motor(model, "LeftUpperArm", "LeftShoulder"),
		leftElbow = motor(model, "LeftLowerArm", "LeftElbow"),
		leftWrist = motor(model, "LeftHand", "LeftWrist"),
	}
end

local ARM_PARTS = {
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
}

local function poseOf(id: string): string
	if id == WeaponConfig.Melee.id then
		return "Melee"
	end
	local def = WeaponConfig.get(id)
	return if def and def.category == "Pistol" then "Pistol" else "TwoHanded"
end

local function clearWeapon(rig: Rig)
	if rig.weapon then
		rig.weapon:Destroy()
	end
	rig.weapon = nil
	rig.hand = nil
	table.clear(rig.parts)
end

-- Monta o modelo da arma `id` na mão direita do corpo (peças soldadas à mão, sem física).
local function buildWeapon(rig: Rig, id: string)
	clearWeapon(rig)
	rig.joints = findJoints(rig.model)
	local hand = rig.model:FindFirstChild("RightHand")
	if not (hand and hand:IsA("BasePart")) then
		return
	end
	local shape = WeaponShapes.forId(id, false, nil)
	local scale = CFG.Scale
	local grip = GRIP_FRAME
	if id == WeaponConfig.Melee.id then
		grip *= CFrame.Angles(math.rad(CFG.MeleeTilt), 0, 0) -- taco para cima
	end
	local weaponFrame = hand.CFrame * grip * CFrame.new(-shape.grip * scale)

	local model = Instance.new("Model")
	model.Name = CombatNames.HeldModelName
	for _, spec in shape.parts do
		local part = WeaponShapes.makePart(spec)
		part.Size = spec.size * scale
		part.CFrame = weaponFrame * CFrame.new(spec.cframe.Position * scale) * spec.cframe.Rotation
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.CollisionGroup = CombatNames.Groups.Body
		part.LocalTransparencyModifier = hand.LocalTransparencyModifier
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		table.insert(rig.parts, part)
	end
	local first = rig.parts[1]
	if first then
		local muzzle = Instance.new("Attachment")
		muzzle.Name = CombatNames.MuzzleName
		muzzle.CFrame = first.CFrame:ToObjectSpace(weaponFrame * CFrame.new(shape.muzzle * scale))
		muzzle.Parent = first
	end
	model.Parent = rig.model
	rig.weapon = model
	rig.hand = hand
	rig.hidden = hand.LocalTransparencyModifier
end

local function refresh(rig: Rig)
	local value = rig.model:GetAttribute(ATTR.Held)
	local id = if typeof(value) == "string" and (WeaponConfig.get(value) or value == WeaponConfig.Melee.id)
		then value
		else nil
	if id == rig.weaponId and (id == nil or rig.weapon ~= nil) then
		return
	end
	rig.weaponId = id
	if id == nil then
		clearWeapon(rig)
		return
	end
	rig.pose = poseOf(id)
	buildWeapon(rig, id)
end

local function untrack(model: Model)
	local rig = rigs[model]
	if rig == nil then
		return
	end
	rigs[model] = nil
	for _, connection in rig.connections do
		connection:Disconnect()
	end
	clearWeapon(rig)
end

local function track(instance: Instance)
	if not instance:IsA("Model") or rigs[instance] or instance == player.Character then
		return
	end
	local model = instance
	local rig: Rig = {
		model = model,
		weaponId = nil,
		weapon = nil,
		parts = {},
		hand = nil,
		pose = "TwoHanded",
		joints = findJoints(model),
		hidden = 0,
		connections = {},
	}
	rigs[model] = rig
	table.insert(
		rig.connections,
		model:GetAttributeChangedSignal(ATTR.Held):Connect(function()
			refresh(rig)
		end)
	)
	-- Braço ou junta chegando depois (StreamingEnabled): procura as juntas e monta a arma de novo
	table.insert(
		rig.connections,
		model.DescendantAdded:Connect(function(descendant: Instance)
			local parent = descendant.Parent
			if ARM_PARTS[descendant.Name] or (isJoint(descendant) and parent and ARM_PARTS[parent.Name]) then
				task.defer(function()
					if rigs[model] == rig then
						rig.joints = findJoints(model)
						refresh(rig)
					end
				end)
			end
		end)
	)
	table.insert(
		rig.connections,
		model.Destroying:Connect(function()
			untrack(model)
		end)
	)
	refresh(rig)
end

-- Pose de mira -------------------------------------------------------------------------------------

local function set(joint: Joint?, transform: CFrame)
	if joint == nil then
		return
	end
	-- Motor6D e AnimationConstraint têm Transform, mas o verificador de tipos não junta a união
	local target: any = joint
	target.Transform = transform
end

local function pitchOf(model: Model): number
	local look = model:GetAttribute(MatchTypes.Attr.Look)
	if typeof(look) ~= "Vector3" or look.Magnitude < 0.01 then
		return 0
	end
	local limit = math.rad(CFG.PitchLimit)
	return math.clamp(math.asin(math.clamp(look.Unit.Y, -1, 1)), -limit, limit)
end

-- Braços na pose (por cima da animação de andar, que continua nas pernas). O giro em X leva o braço
-- de pendurado para a frente (+90°) e acompanha o olhar; o giro em Y puxa o braço para dentro.
local function applyPose(rig: Rig)
	local joints = rig.joints
	local forward = math.pi / 2 + pitchOf(rig.model)
	if rig.pose == "Melee" then
		set(joints.rightShoulder, CFrame.Angles(forward - math.rad(CFG.MeleeArmDown), 0, 0))
		set(joints.rightElbow, CFrame.identity)
		set(joints.rightWrist, CFrame.identity)
		return
	end
	local pose = CFG.Poses[rig.pose] or CFG.Poses.TwoHanded
	set(joints.rightShoulder, CFrame.Angles(0, math.rad(pose.RightInward), 0) * CFrame.Angles(forward, 0, 0))
	set(joints.rightElbow, CFrame.identity)
	set(joints.rightWrist, CFrame.identity)
	set(joints.leftShoulder, CFrame.Angles(0, -math.rad(pose.LeftInward), 0) * CFrame.Angles(forward, 0, 0))
	set(joints.leftElbow, CFrame.Angles(math.rad(pose.LeftElbow), 0, 0))
	set(joints.leftWrist, CFrame.identity)
end

local function step()
	for _, rig in rigs do
		local hand = rig.hand
		if rig.weapon == nil or hand == nil then
			continue
		end
		if hand.Parent ~= rig.model then
			-- A mão saiu (StreamingEnabled tirou o corpo de perto): a arma some e volta com ela
			clearWeapon(rig)
			rig.weaponId = nil
			continue
		end
		-- Espectar o parceiro esconde o corpo dele só na sua tela: a arma some junto
		local hidden = hand.LocalTransparencyModifier
		if hidden ~= rig.hidden then
			rig.hidden = hidden
			for _, part in rig.parts do
				part.LocalTransparencyModifier = hidden
			end
		end
		applyPose(rig)
	end
end

function HeldWeapons.Start()
	CollectionService:GetInstanceAddedSignal(CombatNames.CombatantTag):Connect(track)
	CollectionService:GetInstanceRemovedSignal(CombatNames.CombatantTag):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			untrack(instance)
		end
	end)
	for _, instance in CollectionService:GetTagged(CombatNames.CombatantTag) do
		track(instance)
	end
	-- Depois das animações do quadro (PreSimulation): a pose vale para o desenho
	RunService.PreSimulation:Connect(step)
end

return HeldWeapons
