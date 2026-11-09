--!strict
-- Moedas do jogador. Único lugar do jogo que muda `coins` (docs/DADOS-JOGADOR.md seção 4).
-- Na F1 só existe o básico (dar e gastar). Ganhos por rodada, abate, colocação etc. entram na F9 (GDD 10).

local Common = script.Parent
local DataService = require(Common.DataService)
local ProfileRules = require(Common.Data.ProfileRules)

local EconomyService = {}

-- Dá moedas. `reason` explica a origem (aparece no Output se falhar).
function EconomyService.addCoins(player: Player, amount: number, reason: string): (boolean, string?)
	if amount <= 0 then
		return false, "InvalidAmount"
	end
	local ok, err = DataService.update(player, function(profile)
		return ProfileRules.addCoins(profile, amount)
	end)
	if not ok then
		warn(`[Economia] addCoins({player.UserId}, {amount}, {reason}) recusado: {err}`)
	end
	return ok, err
end

-- Gasta moedas. Recusa se não tiver saldo (moedas nunca ficam negativas).
function EconomyService.spendCoins(player: Player, amount: number, reason: string): (boolean, string?)
	if amount <= 0 then
		return false, "InvalidAmount"
	end
	local ok, err = DataService.update(player, function(profile)
		return ProfileRules.addCoins(profile, -amount)
	end)
	if not ok and err ~= "InsufficientCoins" then
		warn(`[Economia] spendCoins({player.UserId}, {amount}, {reason}) recusado: {err}`)
	end
	return ok, err
end

return EconomyService
