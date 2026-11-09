--!strict
-- Testes automáticos da lógica pura (FASES F1: testes da seção 10 de DADOS-JOGADOR que não precisam de servidor).
-- Cada arquivo em specs/ devolve uma função que recebe `t` e registra testes com t.test(nome, função).
--
-- Rodar no Studio (modo de edição ou com o jogo rodando, no lado do servidor):
--   require(game.ServerStorage.Tests.Runner).run()
-- O resultado aparece no Output. A função devolve (passou, falhou, relatório).

export type T = {
	test: (name: string, fn: () -> ()) -> (),
	ok: (condition: any, message: string?) -> (),
	eq: (actual: any, expected: any, message: string?) -> (),
	deepEq: (actual: any, expected: any, message: string?) -> (),
}

local Runner = {}

local function describe(value: any): string
	if typeof(value) == "string" then
		return `"{value}"`
	end
	return tostring(value)
end

local function deepEqual(a: any, b: any): boolean
	if typeof(a) ~= typeof(b) then
		return false
	end
	if typeof(a) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

function Runner.run(): (number, number, string)
	local specsFolder = script.Parent:WaitForChild("specs")
	local modules = specsFolder:GetChildren()
	table.sort(modules, function(a, b)
		return a.Name < b.Name
	end)

	local passed, failed = 0, 0
	local lines: { string } = {}

	for _, module in modules do
		if not module:IsA("ModuleScript") then
			continue
		end
		local tests: { { name: string, fn: () -> () } } = {}
		local t: T = {
			test = function(name: string, fn: () -> ())
				table.insert(tests, { name = name, fn = fn })
			end,
			ok = function(condition: any, message: string?)
				if not condition then
					error(message or "condição falsa", 2)
				end
			end,
			eq = function(actual: any, expected: any, message: string?)
				if actual ~= expected then
					error(
						`{message or "valores diferentes"}: esperado {describe(expected)}, veio {describe(actual)}`,
						2
					)
				end
			end,
			deepEq = function(actual: any, expected: any, message: string?)
				if not deepEqual(actual, expected) then
					error(message or "tabelas diferentes", 2)
				end
			end,
		}

		local loadOk, loadErr = pcall(function()
			local spec = (require(module) :: any) :: (T) -> ()
			spec(t)
		end)
		if not loadOk then
			failed += 1
			table.insert(lines, `✗ {module.Name}: erro ao carregar: {loadErr}`)
			continue
		end

		for _, test in tests do
			local ok, err = pcall(test.fn :: any)
			if ok then
				passed += 1
				table.insert(lines, `✓ {module.Name} › {test.name}`)
			else
				failed += 1
				table.insert(lines, `✗ {module.Name} › {test.name}\n    {err}`)
			end
		end
	end

	local report = table.concat(lines, "\n") .. `\n\n{passed} passaram, {failed} falharam`
	if failed > 0 then
		warn(`[Testes]\n{report}`)
	else
		print(`[Testes]\n{report}`)
	end
	return passed, failed, report
end

return Runner
