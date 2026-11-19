--!strict
-- Efeitos de combate no cliente (GDD 7.3 e 7.7): rastro do tiro, clarão, faíscas neutras, número de dano,
-- poeira ao derrubar e sons. Sem sangue, sem neon (só cores quentes e neutras do Theme).
-- Tudo é local (só este jogador vê) e vive na pasta CombatEffects, ignorada pelos raios.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local AudioConfig = require(Shared.Config.AudioConfig)
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local CombatTypes = require(Shared.Combat.CombatTypes)
local Remotes = require(Shared.Remotes)
local Theme = require(Shared.Config.Theme)
local WeaponConfig = require(Shared.Config.WeaponConfig)

local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)

local FX = CombatConfig.Effects
local COLORS = Theme.Combat

local CombatEffects = {}

local folder: Folder

function CombatEffects.getFolder(): Folder
	return folder
end

local function reduced(): boolean
	local profile = PlayerDataClient.get()
	return profile ~= nil and profile.settings.reduceEffects
end

local function sfxVolume(): number
	local profile = PlayerDataClient.get()
	if profile == nil then
		return 1
	end
	return profile.settings.audio.master * profile.settings.audio.sfx
end

local function effectPart(size: Vector3, cframe: CFrame, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Transparency = transparency
	part.Parent = folder
	return part
end

local function anchorAt(position: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	return attachment
end

-- Sons -------------------------------------------------------------------------------------------

local function makeSound(def: AudioConfig.SoundDef, parent: Instance): Sound?
	local id, pitch = AudioConfig.resolve(def)
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = def.volume * sfxVolume()
	sound.PlaybackSpeed = pitch
	sound.Parent = parent
	return sound
end

-- Som "na cabeça" do jogador (tiros próprios, marcador de acerto, abate).
function CombatEffects.playSound(def: AudioConfig.SoundDef)
	local sound = makeSound(def, SoundService)
	if sound then
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
		Debris:AddItem(sound, 4)
	end
end

-- Som 3D num ponto do mundo (tiros dos outros).
function CombatEffects.playSoundAt(def: AudioConfig.SoundDef, position: Vector3)
	local attachment = anchorAt(position)
	local sound = makeSound(def, attachment)
	if sound then
		sound.RollOffMaxDistance = AudioConfig.ShotHearingDistance
		sound:Play()
	end
	Debris:AddItem(attachment, 4)
end

-- Visual -----------------------------------------------------------------------------------------

function CombatEffects.tracer(from: Vector3, to: Vector3, style: WeaponConfig.TracerStyle)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local transparency = if style == "Subtle" then FX.SubtleTracerTransparency else FX.TracerTransparency
	local width = FX.TracerWidth
	local part = effectPart(
		Vector3.new(width, width, length),
		CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2),
		COLORS.Tracer,
		transparency
	)
	Debris:AddItem(part, FX.TracerSeconds)
end

function CombatEffects.muzzleFlash(position: Vector3)
	local size = 0.35
	local part = effectPart(Vector3.one * size, CFrame.new(position), COLORS.MuzzleFlash, 0.2)
	part.Shape = Enum.PartType.Ball
	Debris:AddItem(part, FX.MuzzleFlashSeconds)
end

-- Faíscas/estilhaço cartoon em cor neutra (GDD 7.7).
function CombatEffects.spark(position: Vector3)
	local count = FX.HitSparkCount
	if reduced() then
		count = math.max(1, math.floor(count * FX.ReducedEffectsScale))
	end
	for _ = 1, count do
		local piece = effectPart(Vector3.one * 0.15, CFrame.new(position), COLORS.HitSpark, 0)
		local direction = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit
		local tween = TweenService:Create(
			piece,
			TweenInfo.new(FX.HitSparkSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = position + direction * 1.2, Transparency = 1, Size = Vector3.one * 0.05 }
		)
		tween:Play()
		Debris:AddItem(piece, FX.HitSparkSeconds)
	end
end

-- Número de dano flutuando sobre o ponto de acerto.
function CombatEffects.damageNumber(position: Vector3, amount: number, onShield: boolean)
	local attachment = anchorAt(position)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 32)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = attachment
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Theme.Font.Number
	label.TextSize = Theme.TextSize.Title
	label.TextColor3 = if onShield then COLORS.DamageNumberShield else COLORS.DamageNumber
	label.TextStrokeTransparency = 0.3
	label.Text = tostring(math.round(amount))
	label.Parent = gui
	gui.Parent = attachment

	local info = TweenInfo.new(FX.DamageNumberSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, FX.DamageNumberRise, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(attachment, FX.DamageNumberSeconds)
end

-- Personagem derrubado some numa nuvem de poeira e estrelinhas, sem corpo no chão (GDD 7.7).
function CombatEffects.knockdown(position: Vector3)
	local attachment = anchorAt(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(COLORS.Knockdown)
	emitter.LightEmission = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.5, FX.KnockdownSeconds)
	emitter.Speed = NumberRange.new(4, 9)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Parent = attachment
	local count = FX.KnockdownParticles
	if reduced() then
		count = math.max(4, math.floor(count * FX.ReducedEffectsScale))
	end
	emitter:Emit(count)
	CombatEffects.playSoundAt(AudioConfig.Knockdown, position)
	Debris:AddItem(attachment, FX.KnockdownSeconds + 0.2)
end

-- Tiro de outro jogador: rastro e som 3D.
local function onShotFx(shooter: unknown, weaponId: unknown, origin: unknown, ends: unknown)
	if typeof(weaponId) ~= "string" or typeof(origin) ~= "Vector3" or typeof(ends) ~= "table" then
		return
	end
	local def = WeaponConfig.get(weaponId)
	if def == nil then
		return
	end
	local from = origin :: Vector3
	-- O rastro sai um pouco à frente e à direita da cabeça (perto da arma).
	if typeof(shooter) == "Instance" and (shooter :: Instance):IsA("Model") then
		local head = (shooter :: Model):FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			from = (head.CFrame * CFrame.new(0.6, -0.5, -1)).Position
		end
	end
	for _, e in ends :: { any } do
		if typeof(e) == "Vector3" then
			CombatEffects.tracer(from, e, def.tracer)
		end
	end
	local sound = AudioConfig.WeaponFire[weaponId]
	if sound then
		CombatEffects.playSoundAt(sound, from)
	end
end

function CombatEffects.Init()
	local existing = workspace:FindFirstChild(CombatNames.EffectsFolder)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = CombatNames.EffectsFolder
		folder.Parent = workspace
	end
end

function CombatEffects.Start()
	Remotes.unreliable("ShotFx").OnClientEvent:Connect(onShotFx)
	Remotes.event("CombatEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Knocked" then
			local knocked = data :: CombatTypes.KnockedData
			CombatEffects.knockdown(knocked.position)
		end
	end)
end

return CombatEffects
