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

	-- Personagem base (GDD 3.2): o mesmo para todos, sem o avatar do jogador [PROPOSTA].
	-- A cor da equipe vai numa faixa em cada braço e no capacete (GDD 3.3) [DECIDIDO].
	BaseBody = {
		ArmBandHeight = 0.35, -- altura da faixa na parte de cima de cada braço
		HelmetHeight = 0.45,
	},

	-- Altura do personagem em studs (KIT-MODULAR seção 1)
	HeightStuds = 5,
}

return CharacterConfig
