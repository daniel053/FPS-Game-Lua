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
	} :: { [Types.Rarity]: RarityStyle },
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

	-- Contorno do inimigo (GDD 7.6) e opções para daltônicos (ESTILO 5). Escolha salva em settings.enemyOutlineColor.
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

	-- Animação (ESTILO 2.7) [PROPOSTA]
	Animation = {
		ModalOpenOffset = 24,
		ModalOpenTime = 0.2,
		TabSwitchTime = 0.15,
		SelectScale = 1.04,
		SelectTime = 0.1,
	},
}

return Theme
