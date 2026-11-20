--!strict
-- [BOTS] Corpo de um bot de preenchimento (docs/BOTS.md): blocos com pele, camiseta e calça sorteadas
-- (Theme.Bots, nada de catálogo), o mesmo tamanho do avatar dos jogadores, a mesma hitbox, e as
-- animações padrão do Roblox tocadas pelo servidor (o script Animate só roda em personagem de jogador).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local BotConfig = require(Shared.Config.BotConfig)
local CharacterConfig = require(Shared.Config.CharacterConfig)
local Theme = require(Shared.Config.Theme)

local CharacterService = require(ServerScriptService.Combat.CharacterService)
local Combatants = require(ServerScriptService.Combat.Combatants)

local BotBody = {}

local function pick<T>(list: { T }, rng: Random): T
	return list[rng:NextInteger(1, #list)]
end

function BotBody.description(rng: Random): HumanoidDescription
	local skin = pick(Theme.Bots.Skin, rng)
	local shirt = pick(Theme.Bots.Shirt, rng)
	local pants = pick(Theme.Bots.Pants, rng)
	local description = CharacterService.baseDescription(shirt)
	description.HeadColor = skin
	local bareArms = rng:NextNumber() < 0.5 -- camiseta de manga curta (braço na cor da pele)
	description.LeftArmColor = if bareArms then skin else shirt
	description.RightArmColor = if bareArms then skin else shirt
	description.LeftLegColor = pants
	description.RightLegColor = pants
	local avatar = CharacterConfig.Avatar
	description.HeightScale = avatar.HeightScale
	description.WidthScale = avatar.WidthScale
	description.DepthScale = avatar.DepthScale
	description.HeadScale = avatar.HeadScale
	description.BodyTypeScale = avatar.BodyTypeScale
	description.ProportionScale = avatar.ProportionScale
	return description
end

-- ID da animação que o corpo criado já traz (script Animate › pasta › primeira Animation), ou a reserva.
local function animationId(model: Model, name: string): string
	local animate = model:FindFirstChild("Animate")
	local folder = animate and animate:FindFirstChild(name)
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Animation") and child.AnimationId ~= "" then
				return child.AnimationId
			end
		end
	end
	return BotConfig.Animations[name]
end

-- Parado, andando, pulando e caindo. As conexões somem junto com o corpo.
local function animate(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		local created = Instance.new("Animator")
		created.Parent = humanoid
		animator = created
	end
	local tracks: { [string]: AnimationTrack } = {}
	for name in BotConfig.Animations do
		local animation = Instance.new("Animation")
		animation.AnimationId = animationId(model, name)
		local ok, track = pcall(function(): AnimationTrack
			return (animator :: Animator):LoadAnimation(animation)
		end)
		if ok then
			tracks[name] = track
		end
	end
	local idle: AnimationTrack?, walk: AnimationTrack? = tracks.idle, tracks.walk
	local jump: AnimationTrack?, fall: AnimationTrack? = tracks.jump, tracks.fall
	if idle then
		idle.Looped = true
		idle:Play(0.2)
	end
	if walk then
		walk.Looped = true
	end
	local walking = false
	humanoid.Running:Connect(function(speed: number)
		if walk == nil then
			return
		end
		if speed > 0.75 then
			if not walking then
				walking = true
				walk:Play(0.2)
				if idle then
					idle:Stop(0.2)
				end
			end
			walk:AdjustSpeed(math.clamp(speed / BotConfig.WalkAnimationSpeed, 0.4, 1.5))
		elseif walking then
			walking = false
			walk:Stop(0.2)
			if idle then
				idle:Play(0.2)
			end
		end
	end)
	humanoid.StateChanged:Connect(function(_old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
		if new == Enum.HumanoidStateType.Jumping and jump then
			jump:Play(0.1)
		elseif new == Enum.HumanoidStateType.Freefall and fall then
			fall:Play(0.2)
		elseif new == Enum.HumanoidStateType.Landed and fall then
			fall:Stop(0.2)
		end
	end)
end

-- Cria o corpo solto na base, registrado como combatente (vida e escudo cheios).
function BotBody.spawn(name: string, teamId: string, island: number, cframe: CFrame, rng: Random): Combatants.Combatant?
	local combatant =
		CharacterService.spawnBot(name, teamId, island, cframe, { description = BotBody.description(rng), free = true })
	if combatant then
		animate(combatant.model)
	end
	return combatant
end

return BotBody
