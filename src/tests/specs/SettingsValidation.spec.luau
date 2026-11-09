--!strict
-- DADOS 4 e 10: "Cliente envia valor fora do intervalo — servidor recusa ou limita".
-- Regra adotada: pedido com QUALQUER valor inválido é recusado inteiro e nada muda.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DefaultProfile = require(ReplicatedStorage.Shared.Config.DefaultProfile)
local SettingsValidation = require(ReplicatedStorage.Shared.SettingsValidation)

return function(t: any)
	local function base()
		return DefaultProfile.settings()
	end

	t.test("pedido válido é aplicado sem mexer no resto", function()
		local current = base()
		local result, err = SettingsValidation.applyPatch(current, {
			sensitivity = { mouse = 2.5 },
			crosshair = { color = "#ff00aa", size = 7 },
			autoFire = false,
			uiScale = 1.15,
		})
		t.eq(err, nil)
		local r = result :: any
		t.eq(r.sensitivity.mouse, 2.5)
		t.eq(r.sensitivity.touch, 1.0, "campo não pedido fica igual")
		t.eq(r.crosshair.color, "#FF00AA", "hex normalizado")
		t.eq(r.crosshair.size, 7)
		t.eq(r.autoFire, false)
		t.eq(r.uiScale, 1.15)
		t.eq(current.sensitivity.mouse, 1.0, "atual não é alterado (cópia)")
	end)

	t.test("fora do intervalo é recusado", function()
		local _, err = SettingsValidation.applyPatch(base(), { sensitivity = { mouse = 99 } })
		t.eq(err, "OutOfRange")
		_, err = SettingsValidation.applyPatch(base(), { sensitivity = { touch = 0.05 } })
		t.eq(err, "OutOfRange")
		_, err = SettingsValidation.applyPatch(base(), { crosshair = { thickness = 6 } })
		t.eq(err, "OutOfRange")
		_, err = SettingsValidation.applyPatch(base(), { audio = { music = 1.5 } })
		t.eq(err, "OutOfRange")
	end)

	t.test("um valor inválido recusa o pedido inteiro", function()
		local result, err =
			SettingsValidation.applyPatch(base(), { sensitivity = { mouse = 2 }, crosshair = { size = 11 } })
		t.eq(result, nil)
		t.eq(err, "OutOfRange")
	end)

	t.test("NaN, infinito e tipos errados são recusados", function()
		local _, err = SettingsValidation.applyPatch(base(), { sensitivity = { mouse = 0 / 0 } })
		t.eq(err, "WrongType")
		_, err = SettingsValidation.applyPatch(base(), { sensitivity = { mouse = math.huge } })
		t.eq(err, "WrongType")
		_, err = SettingsValidation.applyPatch(base(), { sensitivity = { mouse = "2" } })
		t.eq(err, "WrongType")
		_, err = SettingsValidation.applyPatch(base(), { autoFire = 1 })
		t.eq(err, "WrongType")
		_, err = SettingsValidation.applyPatch(base(), { sensitivity = 2 })
		t.eq(err, "WrongType")
	end)

	t.test("cor da retícula precisa ser hex válido", function()
		for _, bad in { "FFFFFF", "#FFF", "#GGGGGG", "#FFFFFFF", "red" } do
			local _, err = SettingsValidation.applyPatch(base(), { crosshair = { color = bad } })
			t.eq(err, "InvalidColor", bad)
		end
	end)

	t.test("opções fechadas", function()
		local _, err = SettingsValidation.applyPatch(base(), { uiScale = 1.2 })
		t.eq(err, "InvalidOption")
		_, err = SettingsValidation.applyPatch(base(), { enemyOutlineColor = "blue" })
		t.eq(err, "InvalidOption")
		_, err = SettingsValidation.applyPatch(base(), { crosshair = { shape = "star" } })
		t.eq(err, "InvalidOption")
	end)

	t.test("tamanho, espessura e espaço da retícula são inteiros", function()
		local _, err = SettingsValidation.applyPatch(base(), { crosshair = { gap = 2.5 } })
		t.eq(err, "NotInteger")
	end)

	t.test("campo desconhecido, pedido vazio ou que não é tabela", function()
		local _, err = SettingsValidation.applyPatch(base(), { coins = 999999 })
		t.eq(err, "UnknownField", "não dá para mexer em moedas por aqui")
		_, err = SettingsValidation.applyPatch(base(), { sensitivity = { hack = 1 } })
		t.eq(err, "UnknownField")
		_, err = SettingsValidation.applyPatch(base(), {})
		t.eq(err, "Empty")
		_, err = SettingsValidation.applyPatch(base(), "x")
		t.eq(err, "NotTable")
	end)

	t.test("layout do celular: válido, inválido e volta ao padrão", function()
		local result, err = SettingsValidation.applyPatch(base(), {
			mobileLayout = { fire = { x = 0.8, y = 0.7, scale = 1.2 } },
		})
		t.eq(err, nil)
		t.eq((result :: any).mobileLayout.fire.x, 0.8)

		local _, err2 = SettingsValidation.applyPatch(base(), { mobileLayout = { fire = { x = 2, y = 0, scale = 1 } } })
		t.eq(err2, "OutOfRange")
		local _, err3 =
			SettingsValidation.applyPatch(base(), { mobileLayout = { ["bad id!"] = { x = 0, y = 0, scale = 1 } } })
		t.eq(err3, "InvalidButtonId")

		local withLayout = result :: any
		local reset = SettingsValidation.applyPatch(withLayout, { mobileLayout = false })
		t.eq((reset :: any).mobileLayout, nil)
	end)
end
