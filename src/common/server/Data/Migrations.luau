--!strict
-- Migrações do perfil (docs/DADOS-JOGADOR.md seção 7).
--
-- Uma função por versão: Steps[1] leva da versão 1 para a 2, Steps[2] da 2 para a 3, e assim por diante.
-- Ao carregar, as migrações são aplicadas em sequência até DefaultProfile.SchemaVersion.
-- Toda migração nova precisa de um teste com um perfil de exemplo da versão anterior (src/tests).
--
-- Quando migrar: renomear campo, mudar o formato de um campo, separar um campo em dois.
-- Quando NÃO migrar: adicionar campo novo com padrão (o carregamento completa sozinho).
--
-- Exemplo (para quando existir a versão 2):
--   Steps[1] = function(profile)
--       profile.novoNome = profile.nomeAntigo
--       profile.nomeAntigo = nil
--       return profile
--   end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DefaultProfile = require(ReplicatedStorage.Shared.Config.DefaultProfile)

export type RawProfile = { [string]: any }
export type Step = (RawProfile) -> RawProfile

local Migrations = {}

-- Nenhuma migração ainda: o esquema está na versão 1.
Migrations.Steps = {} :: { [number]: Step }

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Leva `data` até a versão `target`. Trabalha numa CÓPIA: se algo der errado, o original fica intacto.
-- Retorna (true, perfil migrado) ou (false, mensagem de erro).
-- Perfil de versão MAIS NOVA que o código (servidor antigo durante uma atualização): não mexe.
-- `steps` e `target` só são passados nos testes.
function Migrations.run(data: RawProfile, steps: { [number]: Step }?, target: number?): (boolean, any)
	local useSteps = steps or Migrations.Steps
	local targetVersion = target or DefaultProfile.SchemaVersion

	local version = data.schemaVersion
	if typeof(version) ~= "number" or version % 1 ~= 0 or version < 1 then
		return false, `schemaVersion inválido: {tostring(version)}`
	end
	if version >= targetVersion then
		return true, data
	end

	local ok, result = pcall(function()
		local current = deepCopy(data)
		local v = version :: number
		while v < targetVersion do
			local step = useSteps[v]
			if step == nil then
				error(`falta a migração da versão {v} para {v + 1}`)
			end
			current = step(current)
			if typeof(current) ~= "table" then
				error(`a migração {v} -> {v + 1} não devolveu uma tabela`)
			end
			v += 1
			current.schemaVersion = v
		end
		return current
	end)

	if not ok then
		return false, tostring(result)
	end
	return true, result
end

return Migrations
