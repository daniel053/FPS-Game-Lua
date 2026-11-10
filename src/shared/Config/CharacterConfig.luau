--!strict
-- Personagem, saúde, movimento e câmera (GDD 3, 7.1 e 7.4).

local CharacterConfig = {
	-- Saúde (GDD 7.1) [PROPOSTA]
	Health = {
		MaxHp = 100,
		MaxShield = 50,
		ShieldRegenDelay = 4, -- segundos sem levar dano
		ShieldRegenPerSecond = 10,
		HpRegenDuringRound = false,
		HeadshotMultiplier = 1, -- não existe tiro na cabeça [DECIDIDO]
	},

	-- Movimento (GDD 7.4) [PROPOSTA]
	Movement = {
		WalkSpeed = 16,
		CanSprint = false,
		CanCrouch = false,
		CanJump = true, -- pulo padrão do Roblox [DECIDIDO]
		JumpHeight = 7.2, -- studs (padrão do Roblox)
	},

	-- Câmera (GDD 3.1) [DECIDIDO]: sempre primeira pessoa, sem opção de troca.
	Camera = {
		FirstPersonZoomDistance = 0.5,
		FieldOfView = 80, -- graus (guia da arma em primeira pessoa) [PROPOSTA]
		MaxPitchDegrees = 80, -- quanto dá para olhar para cima e para baixo
	},

	-- Personagem (GDD 3.2) [DECIDIDO]: o avatar do Roblox de cada jogador, com o tamanho do corpo
	-- igualado (escalas padrão do Roblox), para todos terem a mesma altura. A hitbox é sempre a mesma.
	-- Sem cor de equipe no corpo (GDD 3.3 e 7.6).
	Avatar = {
		UseRobloxAvatar = true, -- false = todos com o corpo base de blocos
		HeightScale = 1,
		WidthScale = 1,
		DepthScale = 1,
		HeadScale = 1,
		BodyTypeScale = 0,
		ProportionScale = 0,
	},

	-- Altura do personagem em studs (KIT-MODULAR seção 1)
	HeightStuds = 5,
}

return CharacterConfig
