--!strict
-- Vida, escudo e validações do servidor (GDD 7.1 e 16.6).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CharacterConfig = require(Shared.Config.CharacterConfig)
local CombatConfig = require(Shared.Config.CombatConfig)
local HealthMath = require(Shared.Combat.HealthMath)
local ShotValidation = require(Shared.Combat.ShotValidation)

local HEALTH = CharacterConfig.Health
local VALIDATION = CombatConfig.Validation

return function(t: any)
	t.test("escudo absorve primeiro; o resto vai para a vida", function()
		local h = HealthMath.full()
		local r = HealthMath.applyDamage(h, 30)
		t.eq(h.shield, HEALTH.MaxShield - 30)
		t.eq(h.hp, HEALTH.MaxHp)
		t.eq(r.shieldBroken, false)
		r = HealthMath.applyDamage(h, 40)
		t.eq(h.shield, 0)
		t.eq(h.hp, HEALTH.MaxHp - 20)
		t.eq(r.shieldBroken, true, "escudo quebrou")
		t.eq(r.toShield, 20)
		t.eq(r.toHp, 20)
	end)

	t.test("derrubado ao zerar a vida; dano não passa do que restava", function()
		local h = HealthMath.full()
		local r = HealthMath.applyDamage(h, 1000)
		t.eq(r.knocked, true)
		t.eq(r.dealt, HEALTH.MaxHp + HEALTH.MaxShield)
		t.eq(h.hp, 0)
	end)

	t.test("dano inválido (negativo, NaN) é ignorado", function()
		local h = HealthMath.full()
		HealthMath.applyDamage(h, -50)
		HealthMath.applyDamage(h, 0 / 0)
		t.eq(h.hp, HEALTH.MaxHp)
		t.eq(h.shield, HEALTH.MaxShield)
	end)

	t.test("escudo regenera só depois do tempo sem levar dano", function()
		local h = { hp = 80, shield = 0 }
		t.eq(HealthMath.regenShield(h, 1, HEALTH.ShieldRegenDelay - 0.1), false, "cedo demais")
		t.eq(h.shield, 0)
		HealthMath.regenShield(h, 1, HEALTH.ShieldRegenDelay)
		t.eq(h.shield, HEALTH.ShieldRegenPerSecond)
		HealthMath.regenShield(h, 100, 100)
		t.eq(h.shield, HEALTH.MaxShield, "limite do escudo")
		t.eq(h.hp, 80, "vida não regenera")
	end)

	t.test("horário do tiro: passado, futuro, ordem e valor inválido", function()
		local now = 1000
		t.ok(ShotValidation.checkTime(now - 0.1, now, 0), "atraso normal")
		local _, past = ShotValidation.checkTime(now - VALIDATION.MaxPastSeconds - 0.01, now, 0)
		t.eq(past, "past")
		local _, future = ShotValidation.checkTime(now + VALIDATION.MaxFutureSeconds + 0.01, now, 0)
		t.eq(future, "future")
		local _, order = ShotValidation.checkTime(now - 0.2, now, now - 0.1)
		t.eq(order, "order")
		local _, nan = ShotValidation.checkTime(0 / 0, now, 0)
		t.eq(nan, "invalid")
		local _, text = ShotValidation.checkTime("1000", now, 0)
		t.eq(text, "invalid")
	end)

	t.test("distância até a hitbox em cápsula", function()
		local center = Vector3.new(0, 3, 0)
		local h, r = 5, 1
		t.ok(ShotValidation.distanceToCapsule(Vector3.new(0, 3, 0), center, h, r) < 0, "dentro")
		local side = ShotValidation.distanceToCapsule(Vector3.new(3, 3, 0), center, h, r)
		t.ok(math.abs(side - 2) < 1e-6, `lado: {side}`)
		local top = ShotValidation.distanceToCapsule(Vector3.new(0, 3 + 2.5 + 1, 0), center, h, r)
		t.ok(math.abs(top - 1) < 1e-6, `topo: {top}`)
	end)

	t.test("vetores inválidos são recusados", function()
		t.ok(ShotValidation.isFiniteVector(Vector3.new(1, 2, 3)))
		t.eq(ShotValidation.isFiniteVector(Vector3.new(0 / 0, 0, 0)), false)
		t.eq(ShotValidation.isFiniteVector(Vector3.new(math.huge, 0, 0)), false)
		t.eq(ShotValidation.isFiniteVector("x"), false)
	end)
end
