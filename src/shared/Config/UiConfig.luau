--!strict
-- Números da interface final (F7): atalhos, tempos de aviso, minimapa e editor de botões.
-- Cores e tamanhos visuais ficam no Theme; textos no Strings.

local UiConfig = {
	-- Atalhos fixos (GDD 13.3, ESTILO 3). ESC é do Roblox e nunca é usado.
	Keys = {
		Settings = Enum.KeyCode.P,
		Abilities = Enum.KeyCode.B,
		Scoreboard = Enum.KeyCode.Tab,
		-- Controle: Select e Start são do Roblox (navegação da interface e menu).
		SettingsPad = Enum.KeyCode.DPadRight,
		AbilitiesPad = Enum.KeyCode.DPadDown,
		ScoreboardPad = Enum.KeyCode.DPadLeft,
		-- Comunicação (F8): toque curto = ping rápido; segurar = roda. Botão do meio do mouse = ping rápido.
		Ping = Enum.KeyCode.Z,
		Phrase = Enum.KeyCode.V,
		Emote = Enum.KeyCode.G,
		Praise = Enum.KeyCode.H,
		PingPad = Enum.KeyCode.ButtonR3,
		PhrasePad = Enum.KeyCode.ButtonL3, -- a roda de frases também leva aos emotes e ao elogio
	},
	-- Texto dos chips das dicas fixas (o que aparece na tela)
	KeyLabels = {
		Settings = "P",
		Abilities = "B",
		Scoreboard = "Tab",
		SettingsPad = "→",
		AbilitiesPad = "↓",
		ScoreboardPad = "←",
		Ping = "Z",
		Phrase = "V",
		Emote = "G",
		Praise = "H",
		PingPad = "R3",
		PhrasePad = "L3",
	},

	-- Configurações: as mudanças de uma aba são salvas ao trocar de aba ou fechar o painel
	-- (um pedido só, validado no servidor).
	Settings = {
		SliderStep = 0.05,
		AudioStep = 0.05,
	},

	-- Legendas de avisos sonoros importantes (ESTILO 5)
	Captions = {
		Seconds = 2.5,
		MaxLines = 3,
	},

	-- Aviso de abate "N KILL" (GDD 7.7)
	KillNotice = {
		PopScale = 1.25, -- entra um pouco maior e volta ao normal
		PopSeconds = 0.18,
	},

	-- Minimapa (GDD 7.6, ESTILO T6): mostra a ilha inteira, norte para cima (sem girar)
	Minimap = {
		Padding = 0.08, -- margem em volta da ilha (fração do mapa)
		EnemySeenSeconds = 1.5, -- inimigo continua no mapa por este tempo depois de sumir da vista
		RefreshSeconds = 0.1,
		-- Tamanho escolhido nas configurações (settings.minimapSize) [PROPOSTA]
		SizeOrder = { "small", "medium", "large" },
		SizeScale = { small = 0.8, medium = 1, large = 1.25 } :: { [string]: number },
		-- Marcador "X" onde alguém foi derrubado (verde = aliado, cor de inimigo = inimigo) [PROPOSTA]
		DeathMarkSeconds = 8, -- some aos poucos no fim
		DeathMarkFadeSeconds = 2,
		DeathMarkMax = 6, -- passou disso, o mais antigo sai
		DeathMarkSize = 14,
		AllyArrowSize = 12,
	},

	-- Editor de posição e tamanho dos botões do celular (GDD 13.1 [PROPOSTA])
	LayoutEditor = {
		ScaleStep = 0.1,
	},

	-- Placar (Tab): segurar no PC/controle; no celular, o botão do topo abre e fecha
	Scoreboard = {
		HoldToShow = true,
	},
}

return UiConfig
