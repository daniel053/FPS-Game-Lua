--!strict
-- DADOS 1.6 e 5.1.4: completar campos ausentes, preservar desconhecidos, corrigir valores inválidos.

local ServerScriptService = game:GetService("ServerScriptService")

local ProfileSanitizer = require(ServerScriptService.Common.Data.ProfileSanitizer)

return function(t: any)
	t.test("campos ausentes recebem o padrão sem perder os existentes", function()
		local raw = { schemaVersion = 1, coins = 77, tutorialDone = true, settings = { sensitivity = { mouse = 2 } } }
		local p = ProfileSanitizer.sanitize(raw, 500)
		t.eq(p.coins, 77, "moedas mantidas")
		t.eq(p.tutorialDone, true, "tutorial mantido")
		t.eq(p.settings.sensitivity.mouse, 2, "sensibilidade mantida")
		t.eq(p.settings.sensitivity.touch, 1.0, "sensibilidade ausente = padrão")
		t.eq(p.settings.crosshair.shape, "cross", "retícula ausente = padrão")
		t.eq(p.rank.points, 0, "rank criado")
		t.ok(typeof(p.stats.killsByWeapon) == "table", "killsByWeapon criado")
		t.eq(p.createdAt, 500, "createdAt ausente = agora")
	end)

	t.test("campos desconhecidos são preservados", function()
		local raw = { schemaVersion = 1, novoCampo = { a = 1 }, stats = { novaEstatistica = 9 } }
		local p = ProfileSanitizer.sanitize(raw, 0) :: any
		t.eq(p.novoCampo.a, 1)
		t.eq(p.stats.novaEstatistica, 9)
	end)

	t.test("tipo errado volta ao padrão", function()
		local raw = { schemaVersion = 1, coins = "muitas", settings = "x", cards = 5 }
		local p, fixes = ProfileSanitizer.sanitize(raw, 0)
		t.eq(p.coins, 0)
		t.eq(p.settings.sensitivity.mouse, 1.0)
		t.ok(typeof(p.cards.owned) == "table")
		t.ok(#fixes >= 3, "correções registradas")
	end)

	t.test("contadores nunca negativos nem quebrados", function()
		local raw = { schemaVersion = 1, coins = -50, gems = 0 / 0, rank = { points = 12.7, peakPoints = 3 } }
		local p = ProfileSanitizer.sanitize(raw, 0)
		t.eq(p.coins, 0, "moedas negativas")
		t.eq(p.gems, 0, "NaN")
		t.eq(p.rank.points, 12, "inteiro")
		t.eq(p.rank.peakPoints, 12, "pico >= pontos")
	end)

	t.test("configurações fora do intervalo são limitadas", function()
		local raw = {
			schemaVersion = 1,
			settings = {
				sensitivity = { touch = 99, mouse = -1 },
				crosshair = { color = "vermelho", size = 50, gap = 2.6 },
				uiScale = 2,
				enemyOutlineColor = "blue",
				minimapSize = 3,
				audio = { master = 3 },
			},
		}
		local p = ProfileSanitizer.sanitize(raw, 0)
		t.eq(p.settings.sensitivity.touch, 5.0)
		t.eq(p.settings.sensitivity.mouse, 0.1)
		t.eq(p.settings.crosshair.color, "#FFFFFF")
		t.eq(p.settings.crosshair.size, 10)
		t.eq(p.settings.crosshair.gap, 3)
		t.eq(p.settings.uiScale, 1.0)
		t.eq(p.settings.enemyOutlineColor, "red")
		t.eq(p.settings.minimapSize, "medium")
		t.eq(p.settings.audio.master, 1)
	end)

	t.test("parceiros recentes limitados a 10 e emotes a 4", function()
		local partners: { any } = {}
		for i = 1, 15 do
			table.insert(partners, { userId = i, at = i })
		end
		table.insert(partners, "lixo")
		local raw = {
			schemaVersion = 1,
			social = { recentPartners = partners },
			cosmetics = { equipped = { emotes = { "a", "b", "c", "d", "e", 7 } :: { any } } },
		}
		local p = ProfileSanitizer.sanitize(raw, 0)
		t.eq(#p.social.recentPartners, 10)
		t.eq(p.social.recentPartners[1].userId, 1, "ordem mantida")
		t.eq(#p.cosmetics.equipped.emotes, 4)
	end)
end
