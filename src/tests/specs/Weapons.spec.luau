--!strict
-- FASES F2: "nenhuma arma derruba quem tem vida cheia com um tiro" e
-- "tempo para derrubar de cada arma bate com a tabela (±10%)".
-- O tempo é simulado com a MESMA máquina de estados do jogo (WeaponState): cadência, pente,
-- recarga e aquecimento, com alguém segurando o gatilho colado no alvo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CharacterConfig = require(Shared.Config.CharacterConfig)
local CombatConfig = require(Shared.Config.CombatConfig)
local Strings = require(Shared.Config.Strings)
local ViewModelFit = require(Shared.Combat.ViewModelFit)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponMath = require(Shared.Combat.WeaponMath)
local WeaponShapes = require(Shared.Combat.WeaponShapes)

local FULL = CharacterConfig.Health.MaxHp + CharacterConfig.Health.MaxShield
local TOLERANCE = 0.10

return function(t: any)
	t.test("são 18 armas de fogo, todas com nome em Strings", function()
		t.eq(#WeaponConfig.Weapons, 18, "número de armas")
		for _, def in WeaponConfig.Weapons do
			t.ok(Strings.Weapons[def.id] ~= nil, `sem nome: {def.id}`)
		end
		t.ok(Strings.Weapons[WeaponConfig.Melee.id] ~= nil, "corpo a corpo sem nome")
	end)

	t.test("nenhum tiro único derruba vida cheia (máx. 135)", function()
		for _, def in WeaponConfig.Weapons do
			local maxShot = WeaponMath.maxShotDamage(def)
			t.ok(maxShot < FULL, `{def.id} derruba com um tiro ({maxShot})`)
			t.ok(maxShot <= WeaponConfig.MaxSingleShotDamage, `{def.id} passa de 135 ({maxShot})`)
		end
		t.ok(WeaponConfig.Melee.heavyDamage < FULL, "golpe forte derruba com um golpe")
		t.ok(WeaponConfig.Melee.damage < FULL, "golpe leve derruba com um golpe")
	end)

	t.test("Luneta: 135 por tiro, derruba quem já levou 15 ou mais", function()
		local luneta = WeaponConfig.get("weapon_luneta")
		assert(luneta, "Luneta não existe")
		t.eq(WeaponMath.maxShotDamage(luneta), 135)
		t.ok(WeaponMath.maxShotDamage(luneta) >= FULL - 15, "não derruba quem levou 15")
	end)

	for _, def in WeaponConfig.Weapons do
		t.test(`tempo para derrubar: {def.id}`, function()
			local result = WeaponMath.simulateTimeToKill(def, FULL)
			t.eq(result.shots, def.referenceShotsToKill, `tiros para derrubar de {def.id}`)
			local reference = def.referenceTimeToKill
			local diff = math.abs(result.seconds - reference) / reference
			t.ok(
				diff <= TOLERANCE,
				string.format("%s: %.2f s, tabela %.2f s (%.0f%%)", def.id, result.seconds, reference, diff * 100)
			)
		end)
	end

	t.test("tempo para derrubar: corpo a corpo (3 golpes, ~1,0 s)", function()
		local result = WeaponMath.simulateMeleeTimeToKill(FULL, false)
		t.eq(result.shots, 3)
		t.ok(math.abs(result.seconds - 1.0) <= 0.1, `{result.seconds} s`)
	end)

	t.test("perda de dano com a distância", function()
		local trovao = WeaponConfig.get("weapon_trovao")
		local zumbido = WeaponConfig.get("weapon_zumbido")
		assert(trovao and zumbido, "armas não existem")
		t.eq(WeaponMath.falloffMultiplier(trovao, 200), 1, "Trovão não perde dano")
		local falloff = zumbido.falloff
		assert(falloff, "Zumbido sem perda")
		t.eq(WeaponMath.falloffMultiplier(zumbido, 0), 1)
		t.eq(WeaponMath.falloffMultiplier(zumbido, falloff.finish + 50), falloff.minMultiplier)
		local middle = WeaponMath.falloffMultiplier(zumbido, (falloff.start + falloff.finish) / 2)
		t.ok(middle < 1 and middle > falloff.minMultiplier, "meio da curva")
		for _, def in WeaponConfig.Weapons do
			local f = def.falloff
			if f then
				t.ok(f.start < f.finish and f.minMultiplier > 0 and f.minMultiplier <= 1, `curva inválida: {def.id}`)
			end
		end
	end)

	t.test("armas por rodada (GDD 7.2.2)", function()
		t.eq(#WeaponConfig.getPrimariesForRound(1), 0, "rodada 1 sem primária")
		t.eq(#WeaponConfig.getPrimariesForRound(2), 0, "rodada 2 sem primária")
		t.eq(#WeaponConfig.getPrimariesForRound(3), 8, "médias")
		local heavy = WeaponConfig.getPrimariesForRound(4)
		t.eq(#heavy, 5, "pesadas")
		t.ok(table.find(heavy, "weapon_moedor") ~= nil and table.find(heavy, "weapon_gemea") ~= nil, "Moedor e Gêmea")
		t.eq(#WeaponConfig.getPrimariesForRound(9), 5, "pesadas até o fim")
		t.ok(table.find(WeaponConfig.getSecondariesForRound(2), "weapon_tambor") == nil, "Tambor antes da 3ª")
		t.ok(table.find(WeaponConfig.getSecondariesForRound(3), "weapon_tambor") ~= nil, "Tambor na 3ª")
		for round = 1, 6 do
			for _, id in WeaponConfig.getPrimariesForRound(round) do
				local def = WeaponConfig.get(id)
				t.ok(def ~= nil and def.slot == "primary", `{id} não é primária`)
			end
		end
	end)

	t.test("só a Luneta deixa mais lento com a mira aberta", function()
		for _, def in WeaponConfig.Weapons do
			local scoped = WeaponMath.walkSpeed(def, true, false)
			local hip = WeaponMath.walkSpeed(def, false, false)
			if def.id == "weapon_luneta" then
				t.ok(math.abs(scoped / hip - 0.7) < 1e-6, "Luneta 70%")
			else
				t.eq(scoped, hip, `{def.id} muda a velocidade com a mira`)
			end
		end
	end)
	t.test("primeira pessoa: cada arma cabe no quadro do guia, no PC e no celular", function()
		local VM = CombatConfig.ViewModel
		local ids = {}
		for _, round in { 1, 3, 4 } do
			for _, list in { WeaponConfig.getPrimariesForRound(round), WeaponConfig.getSecondariesForRound(round) } do
				for _, id in list do
					ids[id] = true
				end
			end
		end
		local count = 0
		for id in ids do
			local def = WeaponConfig.get(id) :: any
			local shape = WeaponShapes.forId(id, true, nil)
			for _, touch in { false, true } do
				local base = if touch then VM.TouchScale else 1
				local offset = VM.Offsets[def.category]
				if touch then
					offset = offset * VM.TouchScale + Vector3.new(0, VM.TouchExtraDown, 0)
				end
				local scale = ViewModelFit.scale(shape.parts, shape.muzzle, offset, base)
				local report = ViewModelFit.measure(shape.parts, shape.muzzle, offset, scale * base)
				t.ok(
					report.fits,
					`{id} ({if touch then "celular" else "PC"}): cano {report.muzzle}, esquerda {report.left}, topo {report.top}, centro {report.center}, escala {scale}`
				)
				t.ok(scale >= 0.9, `{id}: escala {scale} (a arma não pode ficar pequena demais)`)
			end
			count += 1
		end
		t.eq(count, 18, "as 18 armas de fogo")
	end)
end
