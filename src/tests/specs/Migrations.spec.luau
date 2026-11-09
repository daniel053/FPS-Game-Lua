--!strict
-- DADOS 7 e 10: "Perfil da versão anterior — migra sem perder dados".
-- Ainda não existe migração real (esquema v1); estes testes provam que o mecanismo funciona.

local ServerScriptService = game:GetService("ServerScriptService")

local Migrations = require(ServerScriptService.Common.Data.Migrations)

-- Migrações de exemplo: v1 -> v2 renomeia um campo; v2 -> v3 separa um campo em dois.
local fakeSteps: { [number]: (any) -> any } = {
	[1] = function(p)
		p.moedas = p.coins
		p.coins = nil
		return p
	end,
	[2] = function(p)
		p.audioMaster = p.settings.audio.master
		return p
	end,
}

local function sampleV1(): any
	return {
		schemaVersion = 1,
		coins = 250,
		tutorialDone = true,
		settings = { audio = { master = 0.4 } },
		campoDoFuturo = "preservar",
	}
end

return function(t: any)
	t.test("versão atual (1) não muda nada", function()
		local data = sampleV1()
		local ok, result = Migrations.run(data)
		t.ok(ok)
		t.eq(result, data, "mesma tabela")
		t.eq(result.coins, 250)
	end)

	t.test("migra em sequência até a versão alvo sem perder dados", function()
		local ok, result = Migrations.run(sampleV1(), fakeSteps, 3)
		t.ok(ok, tostring(result))
		t.eq(result.schemaVersion, 3, "versão final")
		t.eq(result.moedas, 250, "campo renomeado")
		t.eq(result.coins, nil, "nome antigo removido")
		t.eq(result.audioMaster, 0.4, "campo separado")
		t.eq(result.tutorialDone, true, "campo não tocado")
		t.eq(result.campoDoFuturo, "preservar", "campo desconhecido preservado")
	end)

	t.test("migração com erro deixa o original intacto", function()
		local data = sampleV1()
		local broken: { [number]: (any) -> any } = {
			[1] = function(p)
				p.coins = 0
				error("falha de propósito")
				return p
			end,
		}
		local ok = Migrations.run(data, broken, 2)
		t.eq(ok, false)
		t.eq(data.coins, 250, "original não mudou")
		t.eq(data.schemaVersion, 1)
	end)

	t.test("falta de migração intermediária é erro", function()
		local ok = Migrations.run(sampleV1(), { [1] = fakeSteps[1] }, 3)
		t.eq(ok, false)
	end)

	t.test("schemaVersion inválido é erro", function()
		t.eq((Migrations.run({ schemaVersion = "x" })), false)
		t.eq((Migrations.run({})), false)
		t.eq((Migrations.run({ schemaVersion = 0 })), false)
	end)

	t.test("perfil de versão mais nova que o código não é tocado", function()
		local data = { schemaVersion = 5, coins = 10 }
		local ok, result = Migrations.run(data)
		t.ok(ok)
		t.eq(result.schemaVersion, 5)
	end)
end
