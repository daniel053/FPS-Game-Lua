--!strict
-- F9: elo (GDD 9), moedas (GDD 10), catálogo de skins (GDD 11) e as regras do perfil para comprar e
-- equipar skins e somar estatísticas (DADOS 4 e 10, incluindo os testes de exploit da compra).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local CardConfig = require(Shared.Config.CardConfig)
local DefaultProfile = require(Shared.Config.DefaultProfile)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local EconomyRules = require(Shared.Progression.EconomyRules)
local RankConfig = require(Shared.Config.RankConfig)
local RankRules = require(Shared.Progression.RankRules)
local ShopCatalog = require(Shared.Config.ShopCatalog)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local ProfileRules = require(ServerScriptService.Common.Data.ProfileRules)

local function outcome(placement: number, teamCount: number): RankRules.Outcome
	return { placement = placement, teamCount = teamCount }
end

return function(t: any)
	-- Elo ----------------------------------------------------------------------------------------

	t.test("faixas do GDD 9.1", function()
		t.eq(RankRules.tierOf(0), "Bronze")
		t.eq(RankRules.tierOf(999), "Bronze")
		t.eq(RankRules.tierOf(1000), "Prata")
		t.eq(RankRules.tierOf(2999), "Ouro")
		t.eq(RankRules.tierOf(3000), "Platina")
		t.eq(RankRules.tierOf(4000), "Mestre")
		t.eq(RankRules.tierOf(5000), "Deus")
		t.eq(RankRules.tierOf(99999), "Deus")
	end)

	t.test("elo ADM só pelo UserId", function()
		local admin = RankConfig.AdminUserIds[1]
		t.ok(RankRules.isAdmin(admin))
		t.eq(RankRules.displayTier(admin, 0), "Adm")
		t.ok(not RankRules.isAdmin(1))
		t.eq(RankRules.displayTier(1, 2500), "Ouro")
	end)

	t.test("tabela de colocação com 8 duplas (GDD 9.2)", function()
		local expected = { 40, 25, 10, 10, -5, -5, -15, -15 }
		for place, points in expected do
			t.eq(RankRules.delta(2500, 50, outcome(place, 8)).delta, points, `{place}º de 8`)
		end
	end)

	t.test("tabela proporcional com menos duplas: 1º sempre +40, último sempre −15", function()
		for teams = 2, 8 do
			t.eq(RankRules.delta(2500, 50, outcome(1, teams)).delta, 40, `1º de {teams}`)
			t.eq(RankRules.delta(2500, 50, outcome(teams, teams)).delta, -15, `último de {teams}`)
		end
		-- 4 duplas: 1º, 3º, 6º e 8º da escala de 8
		t.eq(RankRules.scaledPlace(2, 4), 3)
		t.eq(RankRules.scaledPlace(3, 4), 6)
		t.eq(RankRules.delta(2500, 50, outcome(2, 4)).delta, 10)
		t.eq(RankRules.delta(2500, 50, outcome(3, 4)).delta, -5)
	end)

	t.test("nas 10 primeiras partidas não perde PE, mas ganha", function()
		local early = RankRules.delta(500, 0, outcome(8, 8))
		t.eq(early.delta, 0)
		t.ok(early.protected)
		t.eq(RankRules.delta(500, RankConfig.ProtectedMatches - 1, outcome(8, 8)).delta, 0)
		t.eq(RankRules.delta(500, RankConfig.ProtectedMatches, outcome(8, 8)).delta, -15)
		t.eq(RankRules.delta(500, 0, outcome(1, 8)).delta, 40)
	end)

	t.test("a partir de Mestre as perdas dobram (ganhos não)", function()
		t.eq(RankRules.delta(3999, 50, outcome(8, 8)).delta, -15)
		local master = RankRules.delta(4000, 50, outcome(8, 8))
		t.eq(master.delta, -30)
		t.ok(master.doubled)
		t.eq(RankRules.delta(5200, 50, outcome(1, 8)).delta, 40)
	end)

	t.test("Bronze não perde abaixo de 0 e o pico acompanha", function()
		local p = DefaultProfile.new(0)
		p.rank.points = 10
		ProfileRules.applyRankDelta(p, RankRules.delta(10, 50, outcome(8, 8)).delta)
		t.eq(p.rank.points, 0)
		ProfileRules.applyRankDelta(p, 40)
		t.eq(p.rank.peakPoints, 40)
		ProfileRules.countRankedMatch(p)
		t.eq(p.rank.matchesPlayed, 1)
	end)

	t.test("quem sai no meio fica atrás de todas as duplas vivas", function()
		t.eq(RankRules.leaverPlacement(5), 5)
		t.eq(RankRules.leaverPlacement(2), 2)
		t.eq(RankRules.leaverPlacement(0), 1)
	end)

	-- Moedas -------------------------------------------------------------------------------------

	local R = EconomyConfig.Rewards
	local base = { roundsPlayed = 6, roundsWon = 3, kills = 4 }

	t.test("moedas da partida (GDD 10.1)", function()
		local c = EconomyRules.matchCoins(
			base,
			{ placement = 2, samePartner = false, isPrivate = false, firstWinAvailable = false }
		)
		t.eq(c.rounds, 6 * R.RoundParticipation)
		t.eq(c.wins, 3 * R.RoundWin)
		t.eq(c.kills, 4 * R.Kill)
		t.eq(c.placement, R.PlacementByPlace[2])
		t.eq(c.total, c.rounds + c.wins + c.kills + c.placement)
		t.eq(EconomyRules.placementCoins(5), 0)
		t.eq(EconomyRules.placementCoins(nil), 0)
	end)

	t.test("bônus do mesmo parceiro e primeira vitória do dia", function()
		local c = EconomyRules.matchCoins(
			base,
			{ placement = 1, samePartner = true, isPrivate = false, firstWinAvailable = true }
		)
		local plain = c.rounds + c.wins + c.kills + c.placement
		t.eq(c.partnerBonus, math.floor(plain * R.SamePartnerWholeMatchBonus))
		t.eq(c.firstWin, R.FirstWinOfDay)
		t.ok(c.gotFirstWin)
		t.eq(c.total, plain + c.partnerBonus + R.FirstWinOfDay)
		-- Sem rodada vencida não há "primeira vitória"
		local noWin = EconomyRules.matchCoins(
			{ roundsPlayed = 2, roundsWon = 0, kills = 0 },
			{ placement = 8, samePartner = false, isPrivate = false, firstWinAvailable = true }
		)
		t.ok(not noWin.gotFirstWin)
		t.eq(noWin.firstWin, 0)
	end)

	t.test("partida privada vale metade", function()
		local normal = EconomyRules.matchCoins(
			base,
			{ placement = 1, samePartner = false, isPrivate = false, firstWinAvailable = false }
		)
		local private = EconomyRules.matchCoins(
			base,
			{ placement = 1, samePartner = false, isPrivate = true, firstWinAvailable = false }
		)
		t.eq(private.total, math.floor(normal.total * EconomyConfig.PrivateMatchRewardMultiplier))
		t.eq(private.privateCut, normal.total - private.total)
	end)

	t.test("primeira vitória: uma por dia (UTC)", function()
		local day = 20000 * 86400
		t.ok(EconomyRules.firstWinAvailable(nil, day))
		t.ok(not EconomyRules.firstWinAvailable(EconomyRules.dayOf(day), day + 3600))
		t.ok(EconomyRules.firstWinAvailable(EconomyRules.dayOf(day), day + 86400))
	end)

	-- Catálogo -----------------------------------------------------------------------------------

	t.test("catálogo: cada arma e o Bastão têm uma skin por tema, IDs únicos", function()
		local seen: { [string]: boolean } = {}
		for _, skin in ShopCatalog.Skins do
			t.ok(not seen[skin.id], `ID repetido: {skin.id}`)
			seen[skin.id] = true
			t.ok(WeaponConfig.isValidId(skin.weaponId :: string), skin.id)
			t.ok(Theme.SkinLook[skin.theme :: string] ~= nil, `cores do tema {skin.theme}`)
			t.ok(Strings.Skins.Themes[skin.theme :: string] ~= nil, `nome do tema {skin.theme}`)
		end
		local weapons = #WeaponConfig.Weapons + 1
		t.eq(#ShopCatalog.Skins, weapons * #ShopCatalog.Themes)
		t.eq(#ShopCatalog.skinsFor(WeaponConfig.Melee.id), #ShopCatalog.Themes)
		local meleeSkin = ShopCatalog.getSkin(ShopCatalog.skinId(WeaponConfig.Melee.id, "areia"))
		t.eq(if meleeSkin then meleeSkin.slot else nil, "melee")
		t.eq(ShopCatalog.skinId("weapon_rajada", "areia"), "skin_rajada_areia")
	end)

	t.test("preço pela raridade; Celestial não é vendida por moedas", function()
		for _, skin in ShopCatalog.Skins do
			if skin.rarity == "Celestial" then
				t.eq(skin.priceCoins, nil, skin.id)
			else
				t.eq(skin.priceCoins, EconomyConfig.Prices.SkinByRarity[skin.rarity], skin.id)
			end
			t.eq(skin.robuxProductId, nil, "Robux só na F11")
		end
	end)

	t.test("as 4 cartas iniciais são Comuns (GDD 8.9)", function()
		for _, id in CardConfig.StarterCards do
			local card = CardConfig.get(id)
			t.ok(card ~= nil and card.rarity == "Comum", id)
		end
	end)

	-- Comprar e equipar (exploit) ----------------------------------------------------------------

	local skinId = ShopCatalog.skinId("weapon_rajada", "areia")
	local price = (ShopCatalog.getSkin(skinId) :: ShopCatalog.SkinDef).priceCoins :: number

	t.test("não compra sem saldo e não muda nada", function()
		local p = DefaultProfile.new(0)
		p.coins = price - 1
		local ok, err = ProfileRules.buySkinWithCoins(p, skinId, 0)
		t.ok(not ok)
		t.eq(err, "InsufficientCoins")
		t.eq(p.coins, price - 1)
		t.eq(p.cosmetics.owned[skinId], nil)
	end)

	t.test("compra com saldo: desconta e dá a skin, uma vez só", function()
		local p = DefaultProfile.new(0)
		p.coins = price * 2
		t.ok(ProfileRules.buySkinWithCoins(p, skinId, 10))
		t.eq(p.coins, price)
		t.eq(p.cosmetics.owned[skinId].source, "shop_coins")
		local ok, err = ProfileRules.buySkinWithCoins(p, skinId, 11)
		t.ok(not ok)
		t.eq(err, "AlreadyOwned")
		t.eq(p.coins, price)
	end)

	t.test("não compra skin inexistente nem fora de venda", function()
		local p = DefaultProfile.new(0)
		p.coins = 1000000
		local ok1, err1 = ProfileRules.buySkinWithCoins(p, "skin_que_nao_existe", 0)
		t.ok(not ok1)
		t.eq(err1, "UnknownSkin")
		local fake = {
			getCard = CardConfig.get,
			getSkin = function(id: string): any
				return if id == "skin_evento" then { id = id, slot = "weapon", weaponId = "weapon_rajada" } else nil
			end,
			isValidWeapon = WeaponConfig.isValidId,
		}
		local ok2, err2 = ProfileRules.buySkinWithCoins(p, "skin_evento", 0, fake)
		t.ok(not ok2)
		t.eq(err2, "NotForSale")
		t.eq(p.coins, 1000000)
	end)

	t.test("não equipa sem ter; equipa e volta ao padrão (arma e Bastão)", function()
		local p = DefaultProfile.new(0)
		local ok, err = ProfileRules.equipSkin(p, skinId)
		t.ok(not ok)
		t.eq(err, "NotOwned")
		t.eq(p.cosmetics.equipped.weapons.weapon_rajada, nil)
		p.coins = price
		ProfileRules.buySkinWithCoins(p, skinId, 0)
		t.ok(ProfileRules.equipSkin(p, skinId))
		t.eq(p.cosmetics.equipped.weapons.weapon_rajada, skinId)
		t.ok(ProfileRules.unequipWeaponSkin(p, "weapon_rajada"))
		t.eq(p.cosmetics.equipped.weapons.weapon_rajada, nil)

		local meleeSkin = ShopCatalog.skinId(WeaponConfig.Melee.id, "areia")
		p.cosmetics.owned[meleeSkin] = { acquiredAt = 0, source = "admin" }
		t.ok(ProfileRules.equipSkin(p, meleeSkin))
		t.eq(p.cosmetics.equipped.melee, meleeSkin)
		t.ok(ProfileRules.unequipWeaponSkin(p, WeaponConfig.Melee.id))
		t.eq(p.cosmetics.equipped.melee, nil)
		local bad = ProfileRules.unequipWeaponSkin(p, "weapon_inexistente")
		t.ok(not bad)
	end)

	-- Estatísticas -------------------------------------------------------------------------------

	t.test("estatísticas da partida somam e ignoram arma inexistente", function()
		local p = DefaultProfile.new(0)
		t.ok(ProfileRules.addMatchStats(p, {
			placement = 1,
			roundsPlayed = 7,
			roundsWon = 6,
			kills = 9,
			deaths = 2,
			damageDealt = 1234.6,
			viradasWon = 1,
			soloRoundsWon = 2,
			killsByWeapon = { weapon_rajada = 5, weapon_inexistente = 3 },
		}))
		local s = p.stats
		t.eq(s.matchesPlayed, 1)
		t.eq(s.matchesWon, 1)
		t.eq(s.podiums, 1)
		t.eq(s.roundsPlayed, 7)
		t.eq(s.roundsWon, 6)
		t.eq(s.kills, 9)
		t.eq(s.deaths, 2)
		t.eq(s.damageDealt, 1234)
		t.eq(s.viradasWon, 1)
		t.eq(s.soloRoundsWon, 2)
		t.eq(s.killsByWeapon.weapon_rajada, 5)
		t.eq(s.killsByWeapon.weapon_inexistente, nil)
		ProfileRules.addMatchStats(p, {
			placement = 5,
			roundsPlayed = 3,
			roundsWon = 0,
			kills = 0,
			deaths = 3,
			damageDealt = 0,
			viradasWon = 0,
			soloRoundsWon = 0,
			killsByWeapon = {},
		})
		t.eq(s.matchesPlayed, 2)
		t.eq(s.matchesWon, 1)
		t.eq(s.podiums, 1)
		local ok = ProfileRules.addMatchStats(p, {
			placement = nil,
			roundsPlayed = -1,
			roundsWon = 0,
			kills = 0,
			deaths = 0,
			damageDealt = 0,
			viradasWon = 0,
			soloRoundsWon = 0,
			killsByWeapon = {},
		})
		t.ok(not ok, "número negativo é recusado")
		t.eq(s.matchesPlayed, 2)
	end)
end
