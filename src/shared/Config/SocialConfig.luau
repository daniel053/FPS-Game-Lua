--!strict
-- Comunicação e social (GDD 12, F8): pings, frases prontas, emotes, elogio, voz e chat de texto.
-- Números [PROPOSTA]: fáceis de mudar aqui. Textos no Strings (Strings.Social), cores no Theme.

export type PingKind = "Enemy" | "Going" | "Danger" | "Help"
export type EmoteDef = { id: string, animationId: string, looped: boolean }

local SocialConfig = {
	-- Pings (GDD 12.3): só para o parceiro, só de quem está numa ilha de duelo.
	Ping = {
		Kinds = { "Enemy", "Going", "Danger", "Help" } :: { PingKind },
		-- Ping rápido (toque curto / tecla): "Inimigo aqui" se a mira está num inimigo, senão "Vou para cá".
		QuickDefault = "Going" :: PingKind,
		QuickOnEnemy = "Enemy" :: PingKind,
		MaxDistance = 300, -- alcance do raio da mira (studs)
		ServerSlack = 12, -- folga do servidor (o personagem anda entre o pedido e a chegada)
		Seconds = 5, -- quanto tempo o marcador fica na tela
		MaxActive = 2, -- marcadores de cada jogador ao mesmo tempo (o mais velho some)
		MinInterval = 0.5, -- segundos entre dois pings do mesmo jogador
	},

	-- Frases prontas (GDD 12.3): para o parceiro, em qualquer momento da partida.
	Phrases = {
		Ids = { "Nice", "Thanks", "Together", "UsedCard", "UltReady", "PlayAgain" },
		MinInterval = 1.2,
		BubbleSeconds = 3, -- balão em cima do parceiro
	},

	-- Emotes (GDD 12.3): no mirante e no fim da rodada. Animações padrão do próprio Roblox (R15),
	-- grátis para todos até a loja de emotes (F9, cosmetics.equipped.emotes).
	Emotes = {
		List = {
			{ id = "Wave", animationId = "rbxassetid://507770239", looped = false },
			{ id = "Point", animationId = "rbxassetid://507770453", looped = false },
			{ id = "Cheer", animationId = "rbxassetid://507770677", looped = false },
			{ id = "Dance", animationId = "rbxassetid://507771019", looped = true },
		} :: { EmoteDef },
		MaxSeconds = 8, -- emote em repetição para sozinho
		CancelSpeed = 2, -- andar (studs/s no chão) cancela o emote
		MinInterval = 1,
	},

	-- Elogio ao parceiro (GDD 12.4): 1 por rodada (fim da rodada) e 1 no fim da partida.
	-- Só soma social.praisesReceived; não dá moedas.
	Praise = {
		MaxReceived = 1e9, -- teto do contador salvo
	},

	-- Voz (GDD 12.2): durante a rodada só a dupla, sem depender da distância; no mirante, por proximidade.
	Voice = {
		InputName = "TeamVoice", -- AudioDeviceInput criado pelo servidor no Player
		NearDistance = 12, -- até aqui, volume cheio (mirante)
		FarDistance = 70, -- a partir daqui, ninguém ouve (mirante)
		RefreshSeconds = 1, -- conferência periódica, além das mudanças de atributo
	},

	-- Chat de texto do Roblox (GDD 12.3): canal da dupla e canal do mirante.
	Chat = {
		DuoChannelPrefix = "Dupla_",
		MiranteChannel = "Mirante",
	},

	-- Limite geral de pedidos sociais por jogador (além dos intervalos de cada tipo)
	RateLimit = {
		WindowSeconds = 5,
		MaxRequests = 15,
	},

	-- Rodas (ping, frases, emotes): segurar a tecla/botão por este tempo abre a roda; toque curto = rápido.
	Wheel = {
		HoldSeconds = 0.25,
		Radius = 120, -- distância do centro até cada opção (px), reduz em tela pequena
		RadiusSmall = 92,
	},

	-- Botões de toque (celular). Posição padrão a partir do canto SUPERIOR ESQUERDO da área segura,
	-- numa linha embaixo da engrenagem e do PLACAR; editáveis no editor de botões (TouchLayout).
	Touch = {
		Small = {
			ButtonSize = 52,
			Ping = Vector2.new(40, 196),
			Phrase = Vector2.new(102, 196),
			Emote = Vector2.new(164, 196),
		},
		Large = {
			ButtonSize = 64,
			Ping = Vector2.new(50, 240),
			Phrase = Vector2.new(126, 240),
			Emote = Vector2.new(202, 240),
		},
	},
}

return SocialConfig
