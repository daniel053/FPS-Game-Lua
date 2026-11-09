--!strict
-- Registro de tudo o que pode levar dano (personagens dos jogadores e alvos da arena).
-- O servidor é a autoridade da vida e do escudo (GDD 7.1): o cliente só lê os atributos Hp/Shield.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatNames = require(Shared.Combat.CombatNames)
local HealthMath = require(Shared.Combat.HealthMath)

local ATTR = CombatNames.Attr

export type Combatant = {
	model: Model,
	player: Player?,
	hitbox: BasePart,
	health: HealthMath.Health,
	teamId: string,
	displayName: string,
	alive: boolean,
	lastDamageAt: number,
	protectedUntil: number,
	-- Para medir o tempo para derrubar (painel de teste): desde o primeiro dano com tudo cheio
	firstHitAt: number?,
	hitsTaken: number,
}

-- `at` = horário do golpe/tiro em tempo do servidor (o que o cliente informou e o servidor aceitou).
export type DamageSource = { player: Player?, weaponId: string, at: number? }

export type KnockReport = { seconds: number, shots: number }

type KnockedCallback = (target: Combatant, source: DamageSource?, report: KnockReport) -> ()

local Combatants = {}

local byModel: { [Model]: Combatant } = {}
local byHitbox: { [BasePart]: Combatant } = {}
local knockedCallbacks: { KnockedCallback } = {}

local function publish(c: Combatant)
	c.model:SetAttribute(ATTR.Hp, math.ceil(c.health.hp))
	c.model:SetAttribute(ATTR.Shield, math.ceil(c.health.shield))
	c.model:SetAttribute(ATTR.Alive, c.alive)
	c.model:SetAttribute(ATTR.TeamId, c.teamId)
	c.model:SetAttribute(ATTR.DisplayName, c.displayName)
end

export type RegisterOptions = {
	player: Player?,
	teamId: string,
	displayName: string,
	protectSeconds: number?,
}

function Combatants.register(model: Model, hitbox: BasePart, options: RegisterOptions): Combatant
	Combatants.unregister(model)
	local c: Combatant = {
		model = model,
		player = options.player,
		hitbox = hitbox,
		health = HealthMath.full(),
		teamId = options.teamId,
		displayName = options.displayName,
		alive = true,
		lastDamageAt = -math.huge,
		protectedUntil = os.clock() + (options.protectSeconds or 0),
		firstHitAt = nil,
		hitsTaken = 0,
	}
	byModel[model] = c
	byHitbox[hitbox] = c
	publish(c)
	CollectionService:AddTag(model, CombatNames.CombatantTag)
	return c
end

function Combatants.unregister(model: Model)
	local c = byModel[model]
	if c == nil then
		return
	end
	byModel[model] = nil
	byHitbox[c.hitbox] = nil
	CollectionService:RemoveTag(model, CombatNames.CombatantTag)
end

function Combatants.get(model: Model): Combatant?
	return byModel[model]
end

function Combatants.fromHitbox(part: Instance): Combatant?
	if not part:IsA("BasePart") then
		return nil
	end
	return byHitbox[part]
end

function Combatants.getByPlayer(player: Player): Combatant?
	local character = player.Character
	if character == nil then
		return nil
	end
	return byModel[character]
end

-- `a` pode machucar `b`? (sem fogo amigo, GDD/CombatConfig)
function Combatants.canDamage(attackerTeam: string, target: Combatant): boolean
	if CombatConfig.FriendlyFire then
		return true
	end
	return attackerTeam ~= target.teamId
end

function Combatants.setTeam(c: Combatant, teamId: string)
	c.teamId = teamId
	publish(c)
end

function Combatants.onKnocked(callback: KnockedCallback)
	table.insert(knockedCallbacks, callback)
end

-- Aplica dano. Devolve nil se não pôde (já derrubado ou protegido ao aparecer).
function Combatants.applyDamage(target: Combatant, amount: number, source: DamageSource?): HealthMath.DamageResult?
	if not target.alive or os.clock() < target.protectedUntil then
		return nil
	end
	local now = os.clock()
	local stamp = if source and source.at then source.at else workspace:GetServerTimeNow()
	if target.firstHitAt == nil or HealthMath.total(target.health) >= HealthMath.total(HealthMath.full()) then
		target.firstHitAt = stamp
		target.hitsTaken = 0
	end
	local result = HealthMath.applyDamage(target.health, amount)
	if result.dealt <= 0 then
		return result
	end
	target.hitsTaken += 1
	target.lastDamageAt = now
	if result.knocked then
		target.alive = false
		publish(target)
		local report = { seconds = stamp - (target.firstHitAt or stamp), shots = target.hitsTaken }
		target.firstHitAt = nil
		for _, callback in knockedCallbacks do
			task.spawn(callback, target, source, report)
		end
	else
		publish(target)
	end
	return result
end

-- Derrubar sem atacante (caiu para fora do mapa, saiu do jogo, etc.)
function Combatants.knockWithoutSource(target: Combatant)
	if not target.alive then
		return
	end
	target.alive = false
	target.health.hp = 0
	publish(target)
	for _, callback in knockedCallbacks do
		task.spawn(callback, target, nil, { seconds = 0, shots = 0 })
	end
end

-- Vida e escudo cheios (alvos que voltam, comando de teste).
function Combatants.revive(target: Combatant, protectSeconds: number?)
	target.health = HealthMath.full()
	target.alive = true
	target.firstHitAt = nil
	target.hitsTaken = 0
	target.lastDamageAt = -math.huge
	target.protectedUntil = os.clock() + (protectSeconds or 0)
	publish(target)
end

function Combatants.all(): { [Model]: Combatant }
	return byModel
end

function Combatants.Start()
	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		for _, c in byModel do
			if c.alive and HealthMath.regenShield(c.health, dt, now - c.lastDamageAt) then
				local shown = math.ceil(c.health.shield)
				if c.model:GetAttribute(ATTR.Shield) ~= shown then
					c.model:SetAttribute(ATTR.Shield, shown)
				end
			end
		end
	end)
end

return Combatants
