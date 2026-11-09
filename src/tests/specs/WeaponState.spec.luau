--!strict
-- Máquina de estados das armas (cliente e servidor) e o bloqueio de exploit de cadência (FASES F2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponState = require(Shared.Combat.WeaponState)

local SLACK = CombatConfig.Validation.TimingSlackSeconds

local function def(id: string): WeaponConfig.WeaponDef
	local found = WeaponConfig.get(id)
	assert(found, `arma {id} não existe`)
	return found
end

return function(t: any)
	t.test("cadência: tiro antes do intervalo é recusado", function()
		local state = WeaponState.new(def("weapon_rajada")) -- 9/s
		t.ok(WeaponState.fire(state, 0, 0), "primeiro tiro")
		local ok, reason = WeaponState.fire(state, 0.05, 0)
		t.eq(ok, false)
		t.eq(reason, "cadence")
		t.ok(WeaponState.fire(state, 1 / 9, 0), "tiro no intervalo certo")
	end)

	t.test("exploit: 20 tiros de uma vez, o servidor aceita só o que a cadência permite", function()
		local state = WeaponState.new(def("weapon_ferrao")) -- 13/s, o mais rápido
		local accepted = 0
		for i = 1, 20 do
			if WeaponState.fire(state, 10 + (i - 1) * 0.001, SLACK) then
				accepted += 1
			end
		end
		t.eq(accepted, 1, "tiros aceitos")
	end)

	t.test("exploit: atirar o dobro da cadência por 2 s aceita no máximo a cadência", function()
		local weapon = def("weapon_vespa")
		local state = WeaponState.new(weapon)
		local accepted = 0
		local interval = 1 / weapon.fireRate / 2
		local time = 0
		while time < 2 do
			if WeaponState.fire(state, time, SLACK) then
				accepted += 1
			elseif state.ammo <= 0 then
				break
			end
			time += interval
		end
		t.ok(accepted <= math.floor(2 * weapon.fireRate) + 1, `aceitou {accepted}`)
	end)

	t.test("sem munição: recusa e recarrega no tempo certo", function()
		local weapon = def("weapon_tambor")
		local state = WeaponState.new(weapon)
		local time = 0
		for _ = 1, weapon.magazine do
			t.ok(WeaponState.fire(state, time, 0))
			time += 1 / weapon.fireRate
		end
		local ok, reason = WeaponState.fire(state, time, 0)
		t.eq(ok, false)
		t.eq(reason, "empty")
		t.ok(WeaponState.startReload(state, time), "começa a recarregar")
		local _, during = WeaponState.fire(state, time + weapon.reloadTime / 2, 0)
		t.eq(during, "reloading")
		t.ok(WeaponState.fire(state, time + weapon.reloadTime, 0), "atira depois da recarga")
		t.eq(state.ammo, weapon.magazine - 1)
	end)

	t.test("recarga com o pente cheio não faz nada", function()
		local state = WeaponState.new(def("weapon_bolinha"))
		t.eq(WeaponState.startReload(state, 0), false)
	end)

	t.test("trocar de arma: espera sacar e cancela a recarga", function()
		local state = WeaponState.new(def("weapon_rajada"))
		WeaponState.fire(state, 0, 0)
		WeaponState.startReload(state, 0.2)
		WeaponState.equip(state, 0.3)
		t.eq(state.reloadEndsAt, nil, "recarga cancelada")
		local _, reason = WeaponState.fire(state, 0.3 + WeaponConfig.EquipTime / 2, 0)
		t.eq(reason, "equipping")
		t.ok(WeaponState.fire(state, 0.3 + WeaponConfig.EquipTime, 0), "atira depois de sacar")
	end)

	t.test("metralhadora: precisa aquecer antes do primeiro tiro", function()
		local weapon = def("weapon_martelo")
		local state = WeaponState.new(weapon)
		local _, notSpinning = WeaponState.fire(state, 0, 0)
		t.eq(notSpinning, "spinning", "sem segurar o gatilho")
		WeaponState.setSpin(state, true, 1)
		local _, early = WeaponState.fire(state, 1 + (weapon.spinUpTime or 0) / 2, 0)
		t.eq(early, "spinning")
		t.ok(WeaponState.fire(state, 1 + (weapon.spinUpTime or 0), 0), "atira aquecida")
		WeaponState.setSpin(state, false, 2)
		local _, stopped = WeaponState.fire(state, 3, 0)
		t.eq(stopped, "spinning", "soltou o gatilho: esfria")
	end)

	t.test("rajada do modo alternativo (Bolinha): 3 tiros rápidos e depois espera", function()
		local weapon = def("weapon_bolinha")
		local burst = weapon.burst
		assert(burst, "Bolinha sem rajada")
		local state = WeaponState.new(weapon)
		WeaponState.setAlt(state, true)
		local time = 0
		for i = 1, burst.count do
			t.ok(WeaponState.fire(state, time, 0), `tiro {i} da rajada`)
			if i < burst.count then
				t.ok(WeaponState.burstInProgress(state), "rajada continua")
				time += 1 / burst.rate
			end
		end
		t.eq(WeaponState.burstInProgress(state), false, "rajada terminou")
		local _, reason = WeaponState.fire(state, time + burst.cooldown / 2, 0)
		t.eq(reason, "cadence")
		t.ok(WeaponState.fire(state, time + burst.cooldown, 0), "próxima rajada")
	end)

	t.test("corpo a corpo: golpe leve a cada 0,5 s e forte a cada 1,2 s", function()
		local melee = WeaponState.newMelee(WeaponConfig.Melee)
		t.ok(WeaponState.swing(melee, false, 0, 0))
		t.eq(WeaponState.swing(melee, false, 0.3, 0), false)
		t.ok(WeaponState.swing(melee, true, 0.5, 0))
		t.eq(WeaponState.swing(melee, false, 1.0, 0), false)
		t.ok(WeaponState.swing(melee, false, 1.7, 0))
	end)
end
