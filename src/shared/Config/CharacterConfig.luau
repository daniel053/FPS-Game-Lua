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
	},

	-- Câmera (GDD 3.1) [DECIDIDO]: sempre primeira pessoa, sem opção de troca.
	Camera = {
		FirstPersonZoomDistance = 0.5,
	},

	-- Altura do personagem em studs (KIT-MODULAR seção 1)
	HeightStuds = 5,
}

return CharacterConfig
