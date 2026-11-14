--!strict
-- GDD 12 (F8): voz da dupla, chat por canal, pings, emotes e elogio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local DefaultProfile = require(Shared.Config.DefaultProfile)
local SocialConfig = require(Shared.Config.SocialConfig)
local SocialRules = require(Shared.Social.SocialRules)

local ServerScriptService = game:GetService("ServerScriptService")

type Presence = SocialRules.Presence

local function p(userId: number, teamId: string?, location: string?): Presence
	return { userId = userId, teamId = teamId, location = location }
end

return function(t: any)
	-- Rodada: Azul (1, 2) contra Laranja (3, 4) na ilha 1; Verde (5, 6) no mirante (folga).
	local a1 = p(1, "Azul", "Island1")
	local a2 = p(2, "Azul", "Island1")
	local l3 = p(3, "Laranja", "Island1")
	local l4 = p(4, "Laranja", "Island1")
	local v5 = p(5, "Verde", "Mirante")
	local v6 = p(6, "Verde", "Mirante")
	local everyone = { a1, a2, l3, l4, v5, v6 }

	t.test("durante a rodada a dupla se ouve direto, sem depender da distância", function()
		t.eq(SocialRules.voiceMode(a1, a2), "Direct")
		t.eq(SocialRules.voiceMode(a2, a1), "Direct")
	end)

	t.test("a voz da dupla não vaza para a dupla adversária nem para o mirante", function()
		t.deepEq(SocialRules.voiceListeners(a1, everyone), { 2 })
		t.deepEq(SocialRules.voiceListeners(l3, everyone), { 4 })
		t.eq(SocialRules.voiceMode(l3, a1), "None")
		t.eq(SocialRules.voiceMode(v5, a1), "None")
	end)

	t.test("quem está no mirante não fala com quem está na ilha (a não ser o parceiro)", function()
		t.eq(SocialRules.voiceMode(a1, v5), "None")
		local partnerUp = p(2, "Azul", "Mirante")
		t.eq(SocialRules.voiceMode(a1, partnerUp), "Direct")
		t.eq(SocialRules.voiceMode(partnerUp, a1), "Direct")
	end)

	t.test("no mirante, todos por proximidade (inclusive a própria dupla)", function()
		t.eq(SocialRules.voiceMode(v5, v6), "Spatial")
		local other = p(9, "Rosa", "Mirante")
		t.eq(SocialRules.voiceMode(v5, other), "Spatial")
		t.deepEq(SocialRules.voiceListeners(v5, { v5, v6, other, a1 }), { 6, 9 })
	end)

	t.test("derrubado (fora do mundo) continua só com o parceiro", function()
		local down = p(1, "Azul", nil)
		t.eq(SocialRules.voiceMode(a2, down), "Direct")
		t.eq(SocialRules.voiceMode(l3, down), "None")
		t.eq(SocialRules.voiceMode(v5, down), "None")
	end)

	t.test("antes de formar as duplas, todos no mirante por proximidade", function()
		t.eq(SocialRules.voiceMode(p(1, nil, "Mirante"), p(2, nil, "Mirante")), "Spatial")
		t.eq(SocialRules.voiceMode(p(1, nil, "Island1"), p(2, nil, "Island1")), "None")
	end)

	t.test("ninguém se ouve de volta", function()
		t.eq(SocialRules.voiceMode(a1, a1), "None")
		t.eq(SocialRules.voiceMode(v5, v5), "None")
	end)

	t.test("canais de texto: dupla sempre, mirante só lá", function()
		local duo = SocialConfig.Chat.DuoChannelPrefix .. "Azul"
		local mirante = SocialConfig.Chat.MiranteChannel
		t.deepEq(SocialRules.chatChannels(a1), { [duo] = true })
		t.deepEq(SocialRules.chatChannels(p(1, "Azul", "Mirante")), { [duo] = true, [mirante] = true })
		t.deepEq(SocialRules.chatChannels(p(1, nil, "Mirante")), { [mirante] = true })
		t.eq(SocialRules.chatTarget(a1), duo)
		t.eq(SocialRules.chatTarget(p(1, "Azul", "Mirante")), mirante)
	end)

	t.test("ping só na ilha de duelo", function()
		t.ok(SocialRules.canPing("Island1"))
		t.ok(SocialRules.canPing("Island4"))
		t.ok(not SocialRules.canPing("Mirante"))
		t.ok(not SocialRules.canPing(nil))
	end)

	t.test("ping: tipo e alcance validados", function()
		t.ok(SocialRules.isPingKind("Enemy"))
		t.ok(not SocialRules.isPingKind("Bomba"))
		t.ok(not SocialRules.isPingKind(3))
		local origin = Vector3.new(0, 10, 0)
		t.ok(SocialRules.pingInReach(origin, Vector3.new(0, 10, SocialConfig.Ping.MaxDistance)))
		t.ok(not SocialRules.pingInReach(origin, Vector3.new(0, 10, SocialConfig.Ping.MaxDistance + 100)))
		t.ok(not SocialRules.pingInReach(origin, Vector3.new(0 / 0, 0, 0)))
		t.ok(not SocialRules.pingInReach(origin, Vector3.new(math.huge, 0, 0)))
		t.ok(not SocialRules.pingInReach(origin, "perto"))
	end)

	t.test("frases e emotes só da lista", function()
		for _, id in SocialConfig.Phrases.Ids do
			t.ok(SocialRules.isPhrase(id), id)
		end
		t.ok(not SocialRules.isPhrase("Texto livre"))
		t.ok(SocialRules.emoteDef("Wave") ~= nil)
		t.ok(SocialRules.emoteDef("Outro") == nil)
		t.ok(SocialRules.emoteDef(nil) == nil)
	end)

	t.test("emote no mirante e no fim da rodada, nunca no meio do duelo", function()
		t.ok(SocialRules.canEmote("Mirante", "Combat"))
		t.ok(SocialRules.canEmote("Island1", "RoundEnd"))
		t.ok(SocialRules.canEmote(nil, "EndScreen"))
		t.ok(not SocialRules.canEmote("Island1", "Combat"))
		t.ok(not SocialRules.canEmote("Island1", "Prep"))
		t.ok(not SocialRules.canEmote(nil, "Combat"))
	end)

	t.test("elogio: uma chave por rodada e uma no fim da partida", function()
		t.eq(SocialRules.praiseKey("RoundEnd", 3), "r3")
		t.eq(SocialRules.praiseKey("RoundEnd", 4), "r4")
		t.eq(SocialRules.praiseKey("Champion", 7), "end")
		t.eq(SocialRules.praiseKey("EndScreen", 7), "end")
		t.eq(SocialRules.praiseKey("Combat", 3), nil)
		t.eq(SocialRules.praiseKey("Prep", 3), nil)
	end)

	t.test("limite de frequência", function()
		t.ok(SocialRules.intervalOk(nil, 10, 1))
		t.ok(not SocialRules.intervalOk(10, 10.5, 1))
		t.ok(SocialRules.intervalOk(10, 11, 1))
		local window = { start = 0, count = 0 }
		local passed = 0
		for _ = 1, SocialConfig.RateLimit.MaxRequests + 5 do
			if SocialRules.windowAllows(window, 1) then
				passed += 1
			end
		end
		t.eq(passed, SocialConfig.RateLimit.MaxRequests)
		t.ok(SocialRules.windowAllows(window, 1 + SocialConfig.RateLimit.WindowSeconds))
	end)

	t.test("elogio recebido soma no perfil", function()
		local ProfileRules = require(ServerScriptService.Common.Data.ProfileRules)
		local profile = DefaultProfile.new(0)
		t.ok((ProfileRules.addPraise(profile)))
		t.ok((ProfileRules.addPraise(profile)))
		t.eq(profile.social.praisesReceived, 2)
	end)
end
