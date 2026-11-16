--!strict
-- Tema visual único: TODAS as cores, fontes e tamanhos de interface ficam aqui (ESTILO-E-TELAS seção 2).
-- Nenhuma tela define cor ou fonte "na mão".
--
-- Transparência no Roblox: 0 = opaco, 1 = invisível. "92% de opacidade" = 0.08 de transparência.

local Types = require(script.Parent.Parent.Types)

local hex = Color3.fromHex

export type RarityStyle = {
	color: Color3,
	borderThickness: number,
	glow: "leve" | "medio" | "neon",
	icon: "losango" | "estrela" | "coroa" | "sol",
}

local Theme = {
	-- Cores da interface (ESTILO 2.1) [PROPOSTA]; roxo como acento [DECIDIDO]
	Color = {
		Overlay = hex("#0B0F1E"), -- escurecimento atrás de modais
		PanelBase = hex("#141A2E"),
		PanelRaised = hex("#1E2640"),
		PanelBorder = hex("#2E3858"),
		TextPrimary = hex("#FFFFFF"),
		TextSecondary = hex("#AEB6D0"),
		Accent = hex("#8B5CF6"),
		AccentGlow = hex("#A970FF"),
		AccentPressed = hex("#6D3FE0"),
		Success = hex("#4ADE80"),
		Hp = hex("#7CE38B"),
		Shield = hex("#4FA8FF"),
		Danger = hex("#FF3B4E"), -- só perigo, inimigo e dano recebido
		Coin = hex("#F5B700"),
	},

	Transparency = {
		Overlay = 0.45, -- 55% de opacidade
		PanelBase = 0.08, -- 92% de opacidade
		AccentGlow = 0.6, -- 40% de opacidade
	},

	-- Raridades (ESTILO 2.2) [DECIDIDO]. Sempre acompanhar de nome e ícone (nunca só cor).
	Rarity = {
		Comum = { color = hex("#3B82F6"), borderThickness = 3, glow = "leve", icon = "losango" },
		Epica = { color = hex("#A855F7"), borderThickness = 3, glow = "leve", icon = "estrela" },
		Lendaria = { color = hex("#F5B700"), borderThickness = 3, glow = "medio", icon = "coroa" },
		Celestial = { color = hex("#FF1F3D"), borderThickness = 4, glow = "neon", icon = "sol" },
	} :: { [string]: RarityStyle }, -- chave: Types.Rarity (string por causa do verificador de tipos)
	CelestialPulseSeconds = 2,

	-- Cores de equipe (GDD 3.3) [DECIDIDO]
	Team = {
		Azul = hex("#2F6BFF"),
		Laranja = hex("#E5671A"),
		Verde = hex("#1E9E5A"),
		Roxo = hex("#7B48D6"),
		Amarelo = hex("#F2C230"),
		Branco = hex("#F2F4F8"),
		Rosa = hex("#E0559B"),
		Ciano = hex("#2BA8B8"),
	} :: { [Types.TeamColorId]: Color3 },

	-- Marcação de aliado (GDD 7.6) [DECIDIDO]: verde fluorescente na silhueta atrás da parede e
	-- verde na barra de vida. Não é material Neon (ESTILO 2.6): é cor de Highlight e de interface.
	Marker = {
		AllySilhouette = hex("#3DFF6E"),
		AllyBar = hex("#4ADE80"),
		BarBack = hex("#141A2E"),
		BarBorder = hex("#0B0F1E"),
		ShieldLine = hex("#4FA8FF"),
		AllyName = hex("#FFFFFF"),
	},
	MarkerBarBackTransparency = 0.25,

	-- Cores prontas da retícula no editor (tutorial e configurações). Salvas como hex no perfil.
	-- Sem vermelho (reservado ao inimigo e ao perigo).
	CrosshairPalette = { "#FFFFFF", "#7CFF6B", "#FFE14D", "#4DE8FF", "#FF7AF2", "#C9A0FF" },

	-- Contorno e barra do inimigo (GDD 7.6) e opções para daltônicos (ESTILO 5). Escolha salva em settings.enemyOutlineColor.
	EnemyOutline = {
		red = hex("#FF3B4E"),
		yellow = hex("#FFD23F"),
		magenta = hex("#FF3BD4"),
	} :: { [string]: Color3 },

	-- Combate (F2). Sem neon; faíscas em cor neutra (GDD 7.7).
	Combat = {
		BodyNeutral = hex("#C9CDD8"), -- corpo do personagem base (cinza claro)
		BodyDark = hex("#3A4058"), -- detalhes (pernas, luvas)
		DummyBody = hex("#B7A58A"), -- alvos da arena de teste
		WeaponBody = hex("#5C6178"),
		WeaponDark = hex("#3A3F55"),
		WeaponLight = hex("#8A90A8"),
		Glove = hex("#2E3247"),
		Sleeve = hex("#C3C8DA"),
		MeleeHandle = hex("#8C6A4A"),
		Tracer = hex("#FFE2A8"),
		MuzzleFlash = hex("#FFC46B"),
		HitSpark = hex("#F2F4F8"),
		Knockdown = hex("#E8E6DF"),
		DamageNumber = hex("#FFFFFF"),
		DamageNumberShield = hex("#9FD0FF"),
		HitMarker = hex("#FFFFFF"),
		ScopeDark = hex("#0B0F1E"),
		ScopeReticle = hex("#141A2E"),
		ArenaFloor = hex("#B9BBC2"),
		ArenaWall = hex("#8E929E"),
		ArenaCover = hex("#A3A7B2"),
		ArenaThin = hex("#C7B79A"), -- coberturas finas (o Moedor atravessa)
		ArenaMarker = hex("#6F7486"),
	},
	ScopeDarkTransparency = 0.05,

	-- Partida (F3): mundo cinza, zona e destaques do HUD. Sem neon (ESTILO 2.6).
	Match = {
		MiranteFloor = hex("#C9CCD4"),
		MiranteEdge = hex("#9AA0AE"),
		-- Mirante octogonal (F10): piso de vidro claro meio azulado, grade e aro escuros
		MiranteGlass = hex("#B9D6EC"),
		MiranteFrame = hex("#7E8AA3"),
		-- Céu (ESTILO T4: céu claro, nuvens baixas, nada escuro)
		Cloud = hex("#F4F7FB"),
		CloudShade = hex("#E2E9F3"),
		CloudSea = hex("#DDE7F2"),
		SkyAtmosphere = hex("#C8DDF0"),
		SkyDecay = hex("#9FB7D4"),
		IslandFloor = hex("#B9BBC2"),
		IslandRail = hex("#8E929E"),
		IslandCover = hex("#A3A7B2"),
		IslandWall = hex("#8E929E"),
		IslandRoof = hex("#7C8191"),
		IslandRamp = hex("#ADB1BC"),
		IslandUnderside = hex("#6F7486"),
		-- Ponto de recarga de escudo no chão dos mapas (azul do escudo, sem brilho)
		ShieldPad = hex("#7FBFF5"),
		ShieldPadOff = hex("#6B7389"), -- ponto usado, esperando reacender
		ShieldPadRim = hex("#4A5368"),
		IslandLabel = hex("#4A5068"),
		Zone = hex("#8B5CF6"), -- parede da zona: roxo do acento, bem transparente
		Virada = hex("#F5B700"), -- selo e avisos da Rodada da Virada
		Final = hex("#A970FF"),
		LifeLost = hex("#5A6280"),
	},
	ZoneTransparency = 0.82,

	-- Paletas dos mapas (KIT-MODULAR, F10). Cenário menos saturado que os personagens; nunca vermelho
	-- puro (cor do inimigo) e nunca neon.
	Maps = {
		Praca = {
			Reboco = hex("#EFE3CF"),
			Tijolo = hex("#C08A6A"),
			Telha = hex("#C47A52"),
			Folhas = hex("#4F9A62"),
			Grama = hex("#8FCF8A"),
			Porta = hex("#4F7FB8"),
			Pedra = hex("#B9B2A6"),
			ToldoCreme = hex("#F4EAD2"),
			ToldoPetroleo = hex("#3C8C8C"),
			Agua = hex("#4FA3C7"),
			Madeira = hex("#B98A5A"), -- caixas de madeira (mesma madeira do kit do Porto)
			-- Tons de acabamento da arte final (F10)
			Piso = hex("#D9CFBC"), -- lajota clara do chão da praça
			PisoFaixa = hex("#C6BAA4"), -- juntas e faixas das lajotas
			PedraEscura = hex("#948D82"), -- juntas e frisos da pedra
			TijoloEscuro = hex("#A3715A"), -- juntas do tijolo
			TelhaEscura = hex("#A8663F"), -- linhas das telhas e cumeeira
			MadeiraEscura = hex("#8E6540"), -- moldura e travessa das caixas, postes da barraca
			Tronco = hex("#8A5E40"),
			FolhasClaras = hex("#6DB07A"), -- camada do meio da copa
			Janela = hex("#56627D"), -- vidro chapado das janelas
			Metal = hex("#4A5368"), -- poste de luz e pés do banco
			Terra = hex("#A08A6E"), -- rocha logo abaixo do chão
			TerraEscura = hex("#7F6D58"), -- rocha mais funda
		},
		Porto = {
			Chapa = hex("#6F8FA6"),
			Ferrugem = hex("#B5652E"),
			FerrugemEscura = hex("#8A4A24"),
			Concreto = hex("#B9B2A6"),
			Metal = hex("#4A5368"),
			Madeira = hex("#B98A5A"),
			Agua = hex("#4FA3C7"),
			Aviso = hex("#F2C230"),
			Guindaste = hex("#E0A526"),
			ConteinerLaranja = hex("#D9773A"),
			ConteinerPetroleo = hex("#3C7A8C"),
			ConteinerMusgo = hex("#6E8F4E"),
			ConteinerMostarda = hex("#D9A93A"),
			Rocha = hex("#857E73"), -- rocha embaixo da ilha (concreto escurecido)
			-- Tons de acabamento da arte final (F10)
			ChapaEscura = hex("#5A7A91"), -- ondulação da parede de chapa
			ConcretoEscuro = hex("#9E978B"), -- juntas do piso do cais
			MadeiraEscura = hex("#8E6540"), -- estacas e frestas do píer
			MadeiraClara = hex("#C99B6B"), -- tábuas alternadas do píer
			AguaClara = hex("#6FB8D6"), -- ondinhas chapadas
			GuindasteEscuro = hex("#B8851C"), -- diagonais da treliça
			ConteinerLaranjaEscuro = hex("#B8632E"), -- ondulação e quadro de cada contêiner
			ConteinerPetroleoEscuro = hex("#306475"),
			ConteinerMusgoEscuro = hex("#5A7740"),
			ConteinerMostardaEscuro = hex("#B88E2E"),
		},
		Fabrica = {
			Painel = hex("#8FA3B8"),
			Tijolo = hex("#B97C5E"),
			Maquina = hex("#5F9A7A"),
			Tubos = hex("#D9773A"),
			Borracha = hex("#3A3F4F"),
			Papelao = hex("#C9A46B"),
			Janela = hex("#BFE3FF"),
			Metal = hex("#4A5368"),
			Aviso = hex("#F2C230"),
			Piso = hex("#C4C7CC"), -- chão de concreto liso do galpão (F10, planta)
			Rocha = hex("#6B6F7E"), -- rocha embaixo da ilha (F10, planta)
			-- Tons de acabamento da arte final (F10)
			PainelEscuro = hex("#7589A0"), -- ondulação do painel e linhas da grade
			TijoloEscuro = hex("#9C6549"), -- juntas do tijolo
			MaquinaEscura = hex("#4A7D62"), -- frisos da máquina e flanges dos tubos verdes
			TubosEscuro = hex("#B8632E"), -- flanges dos tubos laranja
			PapelaoEscuro = hex("#A88352"), -- fita das caixas e frestas do pallet
			PisoFaixa = hex("#AEB2B9"), -- juntas do piso do galpão
		},
		Torre = {
			Pedra = hex("#A8A29A"),
			PedraEscura = hex("#7D776F"),
			Musgo = hex("#6E8F4E"),
			Madeira = hex("#9A6B43"),
			Ferro = hex("#4A5368"),
			Terra = hex("#B49A74"),
			Estandarte = hex("#E9E3D5"),
			Roxo = hex("#6A4FB0"),
			Chama = hex("#E8913A"),
			ChamaClara = hex("#F2C230"), -- ponta amarela da chama da tocha (prancha do kit)
			-- Tons de acabamento da arte final (F10)
			PedraJunta = hex("#8F8981"), -- juntas dos blocos de pedra
			PedraSombra = hex("#696359"), -- juntas sobre a pedra escura
			PedraClara = hex("#BDB7AE"), -- degraus alternados, lajes do caminho e topo dos merlões
			MadeiraEscura = hex("#7A5334"), -- frestas das tábuas
		},
	},

	-- Cartas (F4): uma cor por carta (GDD 14). Brilho/neon só nos EFEITOS das cartas (ESTILO 2.6);
	-- no HUD as mesmas cores aparecem sem brilho. Nenhuma é vermelha (vermelho = inimigo e perigo).
	Cards = {
		card_nuvem = hex("#C9C3E8"), -- lilás bem claro
		card_impulso = hex("#5ED6FF"), -- azul-céu
		card_tremor = hex("#F2A93B"), -- âmbar
		card_renascer = hex("#6EE7B7"), -- verde-menta
		Smoke = hex("#E6E3F2"), -- a nuvem em si (fosca, sem neon)
		Locked = hex("#5A6280"), -- ult com cadeado, carta sem carga
	} :: { [string]: Color3 },
	SmokeTransparency = 0.03, -- quase opaca: bloqueia a visão de quem está na ilha
	CardFxTransparency = 0.3, -- onda do Tremor, marca do Renascer, arco da Nuvem

	-- Fontes (ESTILO 2.3) [PROPOSTA]
	Font = {
		Title = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold),
		Number = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold),
		Body = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular),
		BodyStrong = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold),
	},

	-- Tamanhos mínimos de texto, em escala de celular (ESTILO 2.3)
	TextSize = {
		Label = 12,
		Body = 14,
		PrimaryButton = 18,
		Title = 22,
	},

	-- Alvos de toque (ESTILO 3 e GDD 13.1)
	Touch = {
		MinTarget = 44,
		ActionButton = 64,
		CardButton = 64,
		FireButton = 80,
		ButtonGap = 12,
	},

	-- Componentes (ESTILO 2.5)
	PrimaryButtonMinHeight = 56,
	SmallCardCornerRadius = 6,
	ScreenMargin = 16,

	-- Cantos chanfrados (ESTILO 2.5): corte diagonal no canto superior esquerdo e no inferior direito,
	-- em pixels. Painéis e botões principais; cartões pequenos usam o canto arredondado de 6 px.
	Chamfer = {
		Panel = 14,
		Button = 10,
		Tab = 6,
	},

	-- Visual de cada arma (modelos low poly provisórios até a F10; referência ref-menus-armas.webp):
	-- corpo, partes escuras e cor de destaque. O destaque também é o marcador do cartão no Arsenal e no
	-- modal de preparação. Nenhum vermelho (GDD 11: vermelho é do contorno de inimigo).
	WeaponLook = {
		weapon_bolinha = { body = hex("#4A4F66"), dark = hex("#2B2F40"), accent = hex("#A970FF") },
		weapon_chumbinho = { body = hex("#8A90A8"), dark = hex("#3A3F55"), accent = hex("#C9CDD8") },
		weapon_zumbido = { body = hex("#4A4F66"), dark = hex("#2B2F40"), accent = hex("#F2A93B") },
		weapon_precisa = { body = hex("#6F7690"), dark = hex("#2E3247"), accent = hex("#4DE8FF") },
		weapon_tambor = { body = hex("#9AA0B8"), dark = hex("#3A3F55"), accent = hex("#5E8CFF") },
		weapon_ferrao = { body = hex("#3A3F55"), dark = hex("#24283A"), accent = hex("#E0559B") },
		weapon_vespa = { body = hex("#3A3F55"), dark = hex("#24283A"), accent = hex("#F5C542") },
		weapon_balde = { body = hex("#3A3F55"), dark = hex("#24283A"), accent = hex("#F28C38") },
		weapon_varredor = { body = hex("#5C6B3A"), dark = hex("#2E3322"), accent = hex("#C7D36B") },
		-- Tático e Atirador: modelos detalhados (referência docs/referencias/ref-tatico-atirador.webp)
		weapon_tatico = {
			body = hex("#C9A266"),
			dark = hex("#2B2D33"),
			accent = hex("#F5A623"),
			metal = hex("#7E8494"),
			lens = hex("#F28C28"),
		},
		weapon_atirador = {
			body = hex("#7A8B3A"),
			dark = hex("#2B2D33"),
			accent = hex("#7CE38B"),
			metal = hex("#7E8494"),
			lens = hex("#2BA8B8"),
		},
		weapon_rajada = { body = hex("#3A3F55"), dark = hex("#24283A"), accent = hex("#F28C38") },
		weapon_trovao = { body = hex("#3B6FD8"), dark = hex("#24283A"), accent = hex("#9FD0FF") },
		weapon_matapato = { body = hex("#5FA34A"), dark = hex("#2B3A28"), accent = hex("#B7F28A") },
		weapon_gemea = { body = hex("#D7DAE4"), dark = hex("#4A4F66"), accent = hex("#4DE8FF") },
		weapon_luneta = { body = hex("#D9A441"), dark = hex("#3A3528"), accent = hex("#F5C542") },
		weapon_martelo = { body = hex("#3A3F55"), dark = hex("#1E2130"), accent = hex("#A970FF") },
		weapon_moedor = { body = hex("#C9CDD8"), dark = hex("#2B2F40"), accent = hex("#AEB6D0") },
		weapon_bastao = { body = hex("#C98A4B"), dark = hex("#2B2F40"), accent = hex("#F28C38") },
	} :: { [string]: { body: Color3, dark: Color3, accent: Color3, metal: Color3?, lens: Color3? } },

	-- Sombreado dos menus [DECIDIDO] (F7, dono do projeto; referência docs/referencias/ref-menus-armas.webp):
	-- todo fundo (painel, botão, aba, cartão) tem a cor cheia em cima e escurece até ShadeBottom × a cor
	-- embaixo. Degradê suave, de uma cor só (nada de degradê de várias cores). Os painéis usam um tom de
	-- cima um pouco mais claro que panel.base para o meio do painel ficar igual ao token.
	Shade = {
		Bottom = 0.62, -- multiplicador da cor na parte de baixo
		PanelTop = hex("#1F2845"),
		RaisedTop = hex("#2A3456"),
		SelectedTop = hex("#7C4DEB"), -- cartão selecionado: roxo do acento sombreado
		Spot = hex("#3A4775"), -- "luz" atrás da arma/carta dentro do cartão
		SpotTransparency = 0.78,
		Highlight = hex("#FFFFFF"), -- filete claro no topo dos painéis
		HighlightTransparency = 0.9,
	},

	-- Espaçamentos padrão dos componentes (F7)
	Space = {
		Small = 6,
		Medium = 10,
		Large = 14,
		PanelPadding = 16,
	},

	-- Item selecionado (ESTILO 2.5): borda do acento + brilho discreto em volta (accent.glow)
	Selected = {
		BorderThickness = 3,
		GlowPadding = 4,
	},
	DisabledTransparency = 0.45, -- botão desativado ("Em breve")

	-- HUD em partida (ESTILO T6, F7). Tamanhos em pixels de celular; sem neon.
	Hud = {
		BarWidth = 220,
		BarHeight = 12,
		AmmoTextSize = 34,
		KillTextSize = 36,
		TopAvatarSize = 30,
		TopHeartSize = 18,
		TimerTextSize = 30,
		MinimapSize = 132,
		MinimapSizeSmall = 104,
		CardTile = 60,
		HintKeyGap = 14,
	},

	-- Minimapa (GDD 7.6 e ESTILO T6): ilha cinza, zona roxa, aliado verde, inimigo na cor de acessibilidade
	Minimap = {
		Background = hex("#141A2E"),
		Island = hex("#5A6280"),
		Cover = hex("#8A90A8"),
		Zone = hex("#8B5CF6"),
		Me = hex("#FFFFFF"),
		Ally = hex("#4ADE80"),
	},
	MinimapBackgroundTransparency = 0.15,

	-- Comunicação (F8). Cada ping tem ícone e nome escritos (nunca só a cor, ESTILO 5).
	-- "Inimigo aqui" usa a cor do contorno do inimigo escolhida pelo jogador (EnemyOutline).
	Social = {
		PingGoing = hex("#4ADE80"), -- verde do aliado
		PingDanger = hex("#FFB020"), -- laranja de aviso (não é vermelho)
		PingHelp = hex("#4FA8FF"),
		PhraseBubble = hex("#141A2E"),
		PhraseText = hex("#FFFFFF"),
		Praise = hex("#F5B700"),
	},
	SocialBubbleTransparency = 0.15,
	PingMarkerSize = 34, -- marcador no mundo (px, tamanho fixo na tela)
	PingMinimapDot = 10,

	-- Placar (Tab): linha da minha dupla com fundo do acento bem leve
	ScoreboardMineTransparency = 0.75,

	-- Editor de botões do celular (F7)
	LayoutEditor = {
		Ghost = hex("#1E2640"),
		GhostSelected = hex("#8B5CF6"),
		Grid = hex("#AEB6D0"),
	},
	LayoutEditorGhostTransparency = 0.2,

	-- Lobby (T3): o fundo é o mundo cinza do lobby; o cartão do modo tem uma faixa de cor no topo
	Lobby = {
		ModeBanner = hex("#2B3460"),
	},

	-- Elo (GDD 9, F9): uma cor por faixa, sempre junto do ícone e do nome (Strings.RankIcons e
	-- Strings.Ranks), nunca só a cor. Nenhum vermelho; ADM no roxo do acento.
	Rank = {
		Bronze = hex("#D08A4E"),
		Prata = hex("#C9D1E0"),
		Ouro = hex("#F5B700"),
		Platina = hex("#4FD1C5"),
		Mestre = hex("#B98CFF"),
		Deus = hex("#FFE27A"),
		Adm = hex("#A970FF"),
	} :: { [string]: Color3 },
	RankUp = hex("#4ADE80"), -- ganho de PE na tela final
	RankDown = hex("#AEB6D0"), -- perda de PE: cinza de apoio (vermelho é só perigo e inimigo)

	-- Skins de arma (GDD 11, F9): cada tema troca só as cores do modelo low poly. Sem vermelho e sem
	-- neon (o material continua o mesmo das armas padrão). metal/lens ausentes = os da arma.
	SkinLook = {
		areia = { body = hex("#D9C29A"), dark = hex("#7A6646"), accent = hex("#F2E3C2") },
		floresta = { body = hex("#5E7A45"), dark = hex("#2F3B24"), accent = hex("#A8C77A") },
		oceano = { body = hex("#2D5FA8"), dark = hex("#16294D"), accent = hex("#5CE1F0"), lens = hex("#5CE1F0") },
		ouro = {
			body = hex("#E0B23A"),
			dark = hex("#3A3020"),
			accent = hex("#FFF1B8"),
			metal = hex("#C99A2E"),
			lens = hex("#7FD6FF"),
		},
	} :: { [string]: { body: Color3, dark: Color3, accent: Color3, metal: Color3?, lens: Color3? } },

	-- Ranking (F9): linha do jogador e a do ADM com fundo do acento bem leve
	RankingMeTransparency = 0.82,

	-- Animação (ESTILO 2.7) [PROPOSTA]
	Animation = {
		ModalOpenOffset = 24,
		ModalOpenTime = 0.2,
		TabSwitchTime = 0.15,
		SelectScale = 1.04,
		SelectTime = 0.1,
		CardFlipTime = 0.5, -- GIRAR na tela de Cartas (F9): fecha e abre, metade cada
	},
}

return Theme
