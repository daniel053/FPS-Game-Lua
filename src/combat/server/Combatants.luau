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
local MatchTypes = require(Shared.Match.MatchTypes)

local ATTR = CombatNames.Attr
local ISLAND_ATTR = MatchTypes.Attr.Island

export type Combatant = {
	model: Model,
	player: Player?,
	hitbox: BasePart,
	health: HealthMath.Health,
	teamId: string,
	island: number?, -- ilha da partida (F3): só acerta e é acertado por quem está na mesma
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
type DamagedCallback = (target: Combatant, source: DamageSource?, dealt: number) -> ()

local Combatants = {}

local byModel: { [Model]: Combatant } = {}
local byHitbox: { [BasePart]: Combatant } = {}
local knockedCallbacks: { KnockedCallback } = {}
local damagedCallbacks: { DamagedCallback } = {}
-- Antes de derrubar: se o guarda devolver true, o combatente NÃO cai (ex.: ult Renascer, GDD 8.4).
-- O guarda é quem decide o que acontece (vida cheia, voltar à marca).
local knockGuard: ((target: Combatant) -> boolean)? = nil

local function publish(c: Combatant)
	c.model:SetAttribute(ATTR.Hp, math.ceil(c.health.hp))
	c.model:SetAttribute(ATTR.Shield, math.ceil(c.health.shield))
	c.model:SetAttribute(ATTR.Alive, c.alive)
	c.model:SetAttribute(ATTR.TeamId, c.teamId)
	c.model:SetAttribute(ATTR.DisplayName, c.displayName)
	c.model:SetAttribute(ISLAND_ATTR, c.island)
end

export type RegisterOptions = {
	player: Player?,
	teamId: string,
	island: number?,
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
		island = options.island,
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
	-- Sem registro = fora do combate (mirante): o cliente para de atirar e esconde a vida.
	for _, name in { ATTR.Hp, ATTR.Shield, ATTR.Alive, ISLAND_ATTR } do
		model:SetAttribute(name, nil)
	end
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

-- `attacker` pode machucar `target`? Só na mesma ilha (F3) e sem fogo amigo (CombatConfig).
function Combatants.canDamage(attacker: Combatant, target: Combatant): boolean
	if attacker.island ~= target.island then
		return false
	end
	if CombatConfig.FriendlyFire then
		return true
	end
	return attacker.teamId ~= target.teamId
end

function Combatants.setTeam(c: Combatant, teamId: string)
	c.teamId = teamId
	publish(c)
end

function Combatants.onKnocked(callback: KnockedCallback)
	table.insert(knockedCallbacks, callback)
end

-- Todo dano que entrou de verdade (para as estatísticas da partida, F9). Não pode esperar (yield).
function Combatants.onDamaged(callback: DamagedCallback)
	table.insert(damagedCallbacks, callback)
end

function Combatants.setKnockGuard(guard: ((target: Combatant) -> boolean)?)
	knockGuard = guard
end

-- Ia cair: o guarda salva? (vale para dano de arma e da zona; não para sair do mapa ou do jogo)
local function guarded(target: Combatant): boolean
	local guard = knockGuard
	if guard == nil then
		return false
	end
	local ok, saved = pcall(guard, target)
	if not ok then
		warn(`[Combate] Erro no guarda de queda: {saved}`)
		return false
	end
	return saved == true
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
	for _, callback in damagedCallbacks do
		local ok, err = pcall(function(): string?
			callback(target, source, result.dealt)
			return nil
		end)
		if not ok then
			warn(`[Combate] Erro ao contar dano: {err}`)
		end
	end
	if result.knocked and guarded(target) then
		target.firstHitAt = nil
		publish(target)
		return {
			dealt = result.dealt,
			toShield = result.toShield,
			toHp = result.toHp,
			shieldBroken = result.shieldBroken,
			knocked = false,
		}
	end
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

-- Dano da zona (GDD 4.4): ignora o escudo, vai direto na vida.
function Combatants.applyZoneDamage(target: Combatant, amount: number)
	if not target.alive or amount ~= amount or amount <= 0 then
		return
	end
	target.health.hp = math.max(0, target.health.hp - amount)
	if target.health.hp > 0 then
		publish(target)
		return
	end
	if guarded(target) then
		publish(target)
		return
	end
	target.alive = false
	publish(target)
	for _, callback in knockedCallbacks do
		task.spawn(callback, target, nil, { seconds = 0, shots = 0 })
	end
end

-- Caiu da ilha (MapConfig.General.FallOutLosesShield): perde o escudo.
function Combatants.clearShield(target: Combatant)
	target.health.shield = 0
	target.lastDamageAt = os.clock()
	publish(target)
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

-- Atualiza os atributos depois que outro sistema mexeu na vida (ex.: Renascer).
function Combatants.publish(target: Combatant)
	publish(target)
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
