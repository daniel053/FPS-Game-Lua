--!strict
-- DADOS 10: "Perfil novo — criado com todos os padrões; tutorial pendente".

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataConfig = require(ReplicatedStorage.Shared.Config.DataConfig)
local DefaultProfile = require(ReplicatedStorage.Shared.Config.DefaultProfile)

return function(t: any)
	t.test("perfil novo tem os padrões da seção 3.2", function()
		local p = DefaultProfile.new(1000)
		t.eq(p.schemaVersion, 1, "schemaVersion")
		t.eq(p.createdAt, 1000, "createdAt")
		t.eq(p.lastLoginAt, 1000, "lastLoginAt")
		t.eq(p.lastSaveAt, 0, "lastSaveAt")
		t.eq(p.tutorialDone, false, "tutorialDone")
		t.eq(p.tutorialStep, 0, "tutorialStep")
		t.eq(p.coins, 0, "coins")
		t.eq(p.gems, 0, "gems")
		t.eq(next(p.cards.owned), nil, "sem cartas")
		t.eq(#p.cosmetics.equipped.emotes, 0, "sem emotes")
		t.eq(p.settings.sensitivity.touch, 1.0, "sensibilidade toque")
		t.eq(p.settings.sensitivity.scopedMultiplier, 0.8, "multiplicador da mira")
		t.eq(p.settings.crosshair.shape, "cross", "retícula")
		t.eq(p.settings.crosshair.color, "#FFFFFF", "cor da retícula")
		t.eq(p.settings.audio.music, 0.6, "música")
		t.eq(p.settings.mobileLayout, nil, "layout padrão")
		t.eq(p.settings.enemyOutlineColor, "red", "contorno inimigo")
		t.eq(p.rank.points, 0, "elo")
		t.eq(p.rank.seasonId, 1, "temporada")
		t.eq(p.daily.loginStreak, 0, "sequência")
		t.eq(p.moderation.warnings, 0, "avisos")
	end)

	t.test("cada perfil novo é uma tabela independente", function()
		local a = DefaultProfile.new(1)
		local b = DefaultProfile.new(1)
		a.settings.sensitivity.mouse = 3
		t.eq(b.settings.sensitivity.mouse, 1.0)
	end)

	t.test("perfil novo fica bem abaixo de 50 KB em JSON", function()
		local json = HttpService:JSONEncode(DefaultProfile.new(os.time()))
		t.ok(#json < DataConfig.MaxProfileBytes, `tamanho {#json}`)
	end)
end
