--!strict
-- Armas de cada rodada (GDD 7.2.2 e 4.10), em funções puras usadas pelo servidor, pelo modal de
-- preparação e pelos testes.
--   Rodadas 1 e 2: só pistola. 3ª: médias + pistola (com Tambor). 4ª em diante: pesadas + pistola.
--   Sem escolha a tempo: mantém a escolha anterior; se ela não vale nesta rodada, a última salva no
--   perfil para a fase; se nada valer, a primeira arma da lista.

local WeaponConfig = require(script.Parent.Parent.Config.WeaponConfig)
local Types = require(script.Parent.Parent.Types)

export type Options = {
	phaseId: Types.WeaponPhaseId,
	primaries: { string }, -- vazio nas rodadas de pistola
	secondaries: { string },
}

export type Choice = { primary: string?, secondary: string? }

-- Memória do perfil (DADOS-JOGADOR 3.1, LoadoutMemory)
export type Memory = { lastPrimaryByPhase: { [string]: string }, lastSecondary: string? }

local LoadoutRules = {}

function LoadoutRules.options(round: number): Options
	local phase = WeaponConfig.getPhaseForRound(round)
	return {
		phaseId = phase.id,
		primaries = WeaponConfig.getPrimariesForRound(round),
		secondaries = WeaponConfig.getSecondariesForRound(round),
	}
end

function LoadoutRules.isPrimaryAllowed(options: Options, id: unknown): boolean
	return typeof(id) == "string" and table.find(options.primaries, id) ~= nil
end

function LoadoutRules.isSecondaryAllowed(options: Options, id: unknown): boolean
	return typeof(id) == "string" and table.find(options.secondaries, id) ~= nil
end

-- Armas finais da rodada. `choice` = o que o jogador escolheu agora (pode estar incompleto),
-- `previous` = armas da rodada anterior, `memory` = perfil.
function LoadoutRules.resolve(options: Options, choice: Choice?, previous: Choice?, memory: Memory?): (string?, string)
	local primary: string? = nil
	if #options.primaries > 0 then
		local candidates = {
			choice and choice.primary,
			previous and previous.primary,
			memory and memory.lastPrimaryByPhase[options.phaseId],
		}
		for i = 1, 3 do
			local id = candidates[i]
			if LoadoutRules.isPrimaryAllowed(options, id) then
				primary = id
				break
			end
		end
		if primary == nil then
			primary = options.primaries[1]
		end
	end

	local secondary = options.secondaries[1]
	local candidates = { choice and choice.secondary, previous and previous.secondary, memory and memory.lastSecondary }
	for i = 1, 3 do
		local id = candidates[i]
		if LoadoutRules.isSecondaryAllowed(options, id) then
			secondary = id :: string
			break
		end
	end
	return primary, secondary
end

return LoadoutRules
