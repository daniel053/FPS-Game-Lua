--!strict
-- DADOS 4 e 10: regras de integridade (moedas, carta por tecla, skins, emotes, parceiros, abates, elo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CardConfig = require(ReplicatedStorage.Shared.Config.CardConfig)
local DefaultProfile = require(ReplicatedStorage.Shared.Config.DefaultProfile)
local ProfileRules = require(ServerScriptService.Common.Data.ProfileRules)

-- Catálogo de exemplo com DUAS cartas C (o jogo real ainda só tem uma por tecla).
local fakeCards: { [string]: any } = {
	card_c1 = { id = "card_c1", key = "C" },
	card_c2 = { id = "card_c2", key = "C" },
	card_q1 = { id = "card_q1", key = "Q" },
}
local fakeSkins: { [string]: any } = {
	skin_rajada_laranja = { id = "skin_rajada_laranja", slot = "weapon", weaponId = "weapon_rajada" },
	skin_corpo_azul = { id = "skin_corpo_azul", slot = "body" },
	emote_1 = { id = "emote_1", slot = "emote" },
	emote_2 = { id = "emote_2", slot = "emote" },
	emote_3 = { id = "emote_3", slot = "emote" },
	emote_4 = { id = "emote_4", slot = "emote" },
	emote_5 = { id = "emote_5", slot = "emote" },
}
local fake = {
	getCard = function(id: string)
		return fakeCards[id]
	end,
	getSkin = function(id: string)
		return fakeSkins[id]
	end,
	isValidWeapon = function(id: string)
		return id == "weapon_rajada"
	end,
}

return function(t: any)
	t.test("moedas nunca ficam negativas", function()
		local p = DefaultProfile.new(0)
		t.ok(ProfileRules.addCoins(p, 100))
		t.eq(p.coins, 100)
		local ok, err = ProfileRules.addCoins(p, -150)
		t.eq(ok, false)
		t.eq(err, "InsufficientCoins")
		t.eq(p.coins, 100, "nada mudou")
		t.ok(ProfileRules.addCoins(p, -100))
		t.eq(p.coins, 0)
		t.eq((ProfileRules.addCoins(p, 1.5)), false, "fração")
		t.eq((ProfileRules.addCoins(p, 0 / 0)), false, "NaN")
	end)

	t.test("segunda carta da mesma tecla é recusada", function()
		local p = DefaultProfile.new(0)
		t.ok(ProfileRules.grantCard(p, "card_c1", "shop", 1, fake))
		local ok, err = ProfileRules.grantCard(p, "card_c2", "shop", 2, fake)
		t.eq(ok, false)
		t.eq(err, "KeyTaken")
		t.eq(p.cards.owned.card_c2, nil)
		t.ok(ProfileRules.grantCard(p, "card_q1", "shop", 3, fake), "outra tecla pode")
	end)

	t.test("carta repetida ou desconhecida é recusada", function()
		local p = DefaultProfile.new(0)
		t.ok(ProfileRules.grantCard(p, "card_c1", "admin", 1, fake))
		t.eq(select(2, ProfileRules.grantCard(p, "card_c1", "admin", 1, fake)), "AlreadyOwned")
		t.eq(select(2, ProfileRules.grantCard(p, "card_inexistente", "admin", 1, fake)), "UnknownCard")
	end)

	t.test("as 4 cartas iniciais reais cabem juntas (uma por tecla)", function()
		local p = DefaultProfile.new(0)
		for _, id in CardConfig.StarterCards do
			local ok, err = ProfileRules.grantCard(p, id, "tutorial", 1)
			t.ok(ok, `{id}: {err}`)
		end
		t.eq(p.cards.owned.card_nuvem.source, "tutorial")
	end)

	t.test("só equipa skin que tem e do slot certo", function()
		local p = DefaultProfile.new(0)
		t.eq(select(2, ProfileRules.equipSkin(p, "skin_rajada_laranja", fake)), "NotOwned")
		t.ok(ProfileRules.grantSkin(p, "skin_rajada_laranja", "shop_coins", 1, fake))
		t.ok(ProfileRules.equipSkin(p, "skin_rajada_laranja", fake))
		t.eq(p.cosmetics.equipped.weapons.weapon_rajada, "skin_rajada_laranja")
		t.ok(ProfileRules.grantSkin(p, "skin_corpo_azul", "reward", 1, fake))
		t.ok(ProfileRules.equipSkin(p, "skin_corpo_azul", fake))
		t.eq(p.cosmetics.equipped.body, "skin_corpo_azul")
		t.ok(ProfileRules.grantSkin(p, "emote_1", "reward", 1, fake))
		t.eq(select(2, ProfileRules.equipSkin(p, "emote_1", fake)), "WrongSlot", "emote não é equipado assim")
		t.eq(select(2, ProfileRules.equipSkin(p, "skin_nao_existe", fake)), "UnknownSkin")
	end)

	t.test("no máximo 4 emotes, todos do jogador", function()
		local p = DefaultProfile.new(0)
		for i = 1, 5 do
			ProfileRules.grantSkin(p, `emote_{i}`, "reward", 1, fake)
		end
		t.ok(ProfileRules.setEmotes(p, { "emote_1", "emote_2", "emote_3", "emote_4" }, fake))
		t.eq(#p.cosmetics.equipped.emotes, 4)
		t.eq(
			select(2, ProfileRules.setEmotes(p, { "emote_1", "emote_2", "emote_3", "emote_4", "emote_5" }, fake)),
			"TooMany"
		)
		t.eq(select(2, ProfileRules.setEmotes(p, { "emote_1", "emote_1" }, fake)), "Duplicate")
		t.eq(select(2, ProfileRules.setEmotes(p, { "skin_corpo_azul" }, fake)), "WrongSlot", "skin que não é emote")
		t.eq(select(2, ProfileRules.setEmotes(p, { "emote_nao_existe" }, fake)), "UnknownSkin")
	end)

	t.test("parceiros recentes: 10 no máximo, mais recente primeiro, sem repetir", function()
		local p = DefaultProfile.new(0)
		for i = 1, 12 do
			ProfileRules.addRecentPartner(p, 100 + i, i)
		end
		local list = p.social.recentPartners
		t.eq(#list, 10)
		t.eq(list[1].userId, 112, "mais recente primeiro")
		ProfileRules.addRecentPartner(p, 105, 50)
		t.eq(list[1].userId, 105, "jogou de novo: sobe para o topo")
		t.eq(#list, 10)
		local count = 0
		for _, entry in list do
			if entry.userId == 105 then
				count += 1
			end
		end
		t.eq(count, 1, "sem repetir")
	end)

	t.test("abates só com ID de arma do WeaponConfig", function()
		local p = DefaultProfile.new(0)
		t.ok(ProfileRules.addWeaponKills(p, "weapon_rajada", 2))
		t.eq(p.stats.killsByWeapon.weapon_rajada, 2)
		t.eq(select(2, ProfileRules.addWeaponKills(p, "weapon_inventada", 1)), "UnknownWeapon")
		t.eq(p.stats.killsByWeapon.weapon_inventada, nil)
	end)

	t.test("pontos de elo nunca negativos e pico atualizado", function()
		local p = DefaultProfile.new(0)
		ProfileRules.applyRankDelta(p, 30)
		t.eq(p.rank.peakPoints, 30)
		ProfileRules.applyRankDelta(p, -100)
		t.eq(p.rank.points, 0)
		t.eq(p.rank.peakPoints, 30)
	end)
end
