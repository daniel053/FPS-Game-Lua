--!strict
-- F7: regras da interface que dá para testar sem tela.
--   * Layout dos botões do celular (GDD 13.1): padrão do CombatConfig, posição salva, escala.
--   * Contrato do Theme e do Strings usados pelas telas (ESTILO 2 e 6).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local DataConfig = require(Shared.Config.DataConfig)
local DefaultProfile = require(Shared.Config.DefaultProfile)
local SettingsValidation = require(Shared.SettingsValidation)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local TouchLayout = require(Shared.Ui.TouchLayout)

local SMALL = Vector2.new(800, 400)
local LARGE = Vector2.new(1200, 800)

local function luminance(c: Color3): number
	local function channel(v: number): number
		return if v <= 0.03928 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * channel(c.R) + 0.7152 * channel(c.G) + 0.0722 * channel(c.B)
end

local function contrast(a: Color3, b: Color3): number
	local la, lb = luminance(a), luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

return function(t: any)
	t.test("sem nada salvo, cada botão fica no padrão do CombatConfig", function()
		for _, id in TouchLayout.ButtonIds do
			local p = TouchLayout.resolve(id, SMALL, nil)
			local d = TouchLayout.default(id, SMALL)
			t.eq(p.position, d.position, id)
			t.eq(p.size, d.size, id)
		end
		local fire = TouchLayout.default("Fire", SMALL)
		local small = CombatConfig.TouchLayout.Small
		t.eq(fire.position, UDim2.new(1, small.Fire.X, 1, small.Fire.Y))
		t.eq(fire.size, small.FireSize)
	end)

	t.test("tela grande usa os tamanhos grandes", function()
		t.eq(TouchLayout.default("Fire", LARGE).size, CombatConfig.TouchLayout.Large.FireSize)
		t.eq(TouchLayout.default("Q", LARGE).size, CombatConfig.TouchLayout.Large.CardSize)
	end)

	t.test("botão salvo usa a posição relativa e a escala sobre o tamanho padrão", function()
		local saved = { Fire = { x = 0.8, y = 0.7, scale = 1.5 } }
		local p = TouchLayout.resolve("Fire", SMALL, saved)
		t.eq(p.position, UDim2.fromScale(0.8, 0.7))
		t.eq(p.size, math.floor(CombatConfig.TouchLayout.Small.FireSize * 1.5 + 0.5))
		-- Os outros continuam no padrão
		t.eq(TouchLayout.resolve("Aim", SMALL, saved).position, TouchLayout.default("Aim", SMALL).position)
	end)

	t.test("layout montado pelo editor passa na validação do servidor", function()
		local layout = {}
		for _, id in TouchLayout.ButtonIds do
			local rel = TouchLayout.toRelative(TouchLayout.default(id, SMALL).position, SMALL)
			layout[id] = { x = rel.X, y = rel.Y, scale = DataConfig.Limits.MobileButtonScale.Max }
		end
		local result, err = SettingsValidation.applyPatch(DefaultProfile.settings(), { mobileLayout = layout })
		t.ok(result ~= nil, `recusado: {err}`)
		t.ok(#TouchLayout.ButtonIds <= DataConfig.Limits.MobileLayoutMaxButtons)
	end)

	t.test("toRelative converte o padrão (canto inferior direito) para 0 a 1", function()
		local rel = TouchLayout.toRelative(UDim2.new(1, -80, 1, -40), SMALL)
		t.eq(rel, Vector2.new(0.9, 0.9))
		t.eq(TouchLayout.toRelative(UDim2.new(1, 50, 0, -10), SMALL), Vector2.new(1, 0))
	end)

	t.test("contraste de texto de pelo menos 4,5:1 (ESTILO 2.1 e 6)", function()
		local panel = Theme.Color.PanelBase
		t.ok(contrast(Theme.Color.TextPrimary, panel) >= 4.5, "texto principal no painel")
		t.ok(contrast(Theme.Color.TextSecondary, panel) >= 4.5, "texto de apoio no painel")
		t.ok(contrast(Theme.Color.TextSecondary, Theme.Color.PanelRaised) >= 4.5, "texto de apoio no cartão")
		t.ok(contrast(Theme.Color.TextPrimary, Theme.Color.Accent) >= 3, "texto do botão principal (texto grande)")
	end)

	t.test("vermelho só em perigo, inimigo e Celestial (ESTILO 2.1)", function()
		local function isRed(c: Color3): boolean
			local h, s, v = c:ToHSV()
			return (h < 0.03 or h > 0.95) and s > 0.6 and v > 0.5
		end
		for name, color in Theme.Color :: { [string]: Color3 } do
			if name ~= "Danger" then
				t.ok(not isRed(color), `Theme.Color.{name} não pode ser vermelho`)
			end
		end
		for id, color in Theme.Cards do
			t.ok(not isRed(color), `carta {id}`)
		end
		for id, look in Theme.WeaponLook do
			for part, color in look :: { [string]: Color3 } do
				t.ok(not isRed(color), `arma {id} ({part})`)
			end
		end
		for _, hex in Theme.CrosshairPalette do
			t.ok(not isRed(Color3.fromHex(hex)), `retícula {hex}`)
		end
		-- F9: skins (GDD 11: nunca vermelho que pareça contorno de inimigo) e elo
		for id, look in Theme.SkinLook do
			for part, color in look :: { [string]: Color3 } do
				t.ok(not isRed(color), `skin {id} ({part})`)
			end
		end
		for id, color in Theme.Rank do
			t.ok(not isRed(color), `elo {id}`)
		end
	end)

	t.test("todo elo tem nome, ícone e cor (nunca só a cor, F9)", function()
		for _, tier in { "Bronze", "Prata", "Ouro", "Platina", "Mestre", "Deus", "Adm" } do
			local names = Strings.Ranks :: { [string]: string }
			t.ok(names[tier] ~= nil and names[tier] ~= "", `nome {tier}`)
			t.ok(Strings.RankIcons[tier] ~= nil and Strings.RankIcons[tier] ~= "", `ícone {tier}`)
			t.ok((Theme.Rank :: { [string]: Color3? })[tier] ~= nil, `cor {tier}`)
		end
	end)

	t.test("toda raridade tem nome e ícone (nunca só a cor, ESTILO 2.2)", function()
		for rarity in Theme.Rarity do
			local info = Strings.Rarity[rarity]
			t.ok(info ~= nil and info.name ~= "" and info.icon ~= "", rarity)
		end
	end)

	t.test("alvos de toque mínimos (ESTILO 3)", function()
		t.ok(Theme.Touch.MinTarget >= 44)
		t.ok(Theme.PrimaryButtonMinHeight >= 56)
		t.ok(CombatConfig.TouchLayout.Small.FireSize >= Theme.Touch.FireButton)
		t.ok(CombatConfig.TouchLayout.Small.ButtonSize >= Theme.Touch.ActionButton)
		t.ok(CombatConfig.TouchLayout.Small.CardSize >= Theme.Touch.CardButton)
	end)

	t.test("modal nunca opaco (ESTILO 2.5)", function()
		t.ok(Theme.Transparency.Overlay > 0.2, "escurecimento atrás do modal deixa o jogo visível")
	end)
end
