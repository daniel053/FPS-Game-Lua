--!strict
-- Moedas do jogador. Único lugar do jogo que muda `coins` (docs/DADOS-JOGADOR.md seção 4).
--   * addCoins / spendCoins: o básico (F1; comandos de teste).
--   * creditMatch: moedas de uma partida (F9, GDD 10.1), calculadas pelo EconomyRules.
--   * buySkin: compra de skin com moedas (F9, GDD 10.2), tudo ou nada, salva na hora (DADOS 5.2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyRules = require(ReplicatedStorage.Shared.Progression.EconomyRules)

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

-- A "primeira vitória do dia" ainda vale hoje para este jogador? (nil = perfil não carregado)
function EconomyService.firstWinAvailable(player: Player, now: number): boolean?
	local profile = DataService.getProfile(player)
	if profile == nil then
		return nil
	end
	return EconomyRules.firstWinAvailable(profile.daily.lastFirstWinDay, now)
end

-- Credita as moedas de uma partida (o cálculo vem pronto do EconomyRules.matchCoins).
-- Marca a primeira vitória do dia junto, na mesma mudança.
function EconomyService.creditMatch(player: Player, coins: EconomyRules.Breakdown, now: number): (boolean, string?)
	local ok, err = DataService.update(player, function(profile)
		local total = coins.total
		if coins.gotFirstWin then
			if EconomyRules.firstWinAvailable(profile.daily.lastFirstWinDay, now) then
				profile.daily.lastFirstWinDay = EconomyRules.dayOf(now)
			else
				total = math.max(0, total - coins.firstWin) -- já ganhou hoje (outra partida terminou antes)
			end
		end
		if total > 0 then
			local added, reason = ProfileRules.addCoins(profile, total)
			if not added then
				return false, reason
			end
		end
		return true, nil
	end)
	if not ok then
		warn(`[Economia] creditMatch({player.UserId}, {coins.total}) recusado: {err}`)
	end
	return ok, err
end

-- Compra uma skin com moedas. Salva na hora quando dá certo.
function EconomyService.buySkin(player: Player, skinId: string): (boolean, string?)
	local now = os.time()
	local ok, err = DataService.update(player, function(profile)
		return ProfileRules.buySkinWithCoins(profile, skinId, now)
	end)
	if ok then
		DataService.saveNow(player)
	end
	return ok, err
end

return EconomyService
