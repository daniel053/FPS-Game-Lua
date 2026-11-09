--!strict
-- Números do sistema de dados do jogador (docs/DADOS-JOGADOR.md seções 2, 4 e 5).
-- Os limites das configurações valem no servidor (validação) e no cliente (sliders da F6/F7).

local DataConfig = {
	-- Armazenamento (seção 2). O prefixo DEV_ é aplicado por Env.dataStoreName.
	ProfileStoreName = "PlayerProfile_v1",
	ProfileKeyPrefix = "u_", -- chave = "u_<UserId>"

	-- Salvamento e trava de sessão (seção 5) [PROPOSTA]
	AutoSaveSeconds = 120, -- salvamento automático a cada 2 min
	LockFirstRetrySeconds = 5, -- perfil aberto em outro servidor: tenta de novo após 5 s...
	LockRetrySeconds = 5, -- ...e depois a cada 5 s
	LockTakeoverSeconds = 5, -- após ~10 s de espera, este servidor assume a trava
	StaleLockSeconds = 300, -- trava sem atualização há 5 min = servidor caiu; assume na hora
	LoadTimeoutSeconds = 30, -- desiste de carregar (erros do DataStore) e avisa o jogador
	TeleportReleaseTimeoutSeconds = 10, -- espera máxima para salvar e liberar antes do teleporte

	-- Tamanho (seção 1.9)
	MaxProfileBytes = 50 * 1024, -- aviso no Output se o perfil passar disso

	-- Pedidos de configuração vindos do cliente: limite de frequência
	SettingsRequestWindowSeconds = 5,
	SettingsRequestMaxPerWindow = 10,

	-- Limites das configurações (seção 4: "cada número é limitado ao intervalo do tipo")
	Limits = {
		Sensitivity = { Min = 0.1, Max = 5.0 }, -- toque, mouse e controle
		ScopedMultiplier = { Min = 0.1, Max = 2.0 },
		CrosshairSize = { Min = 1, Max = 10 }, -- inteiros
		CrosshairThickness = { Min = 1, Max = 5 }, -- inteiros
		CrosshairGap = { Min = 0, Max = 10 }, -- inteiros
		CrosshairOutlineOpacity = { Min = 0, Max = 1 },
		Audio = { Min = 0, Max = 1 },
		UiScaleOptions = { 1.0, 1.15, 1.3 },
		MobileButtonScale = { Min = 0.5, Max = 2.0 },
		MobileLayoutMaxButtons = 24,
		MobileButtonIdMaxLength = 32,
	},

	-- Regras de integridade (seção 4)
	MaxRecentPartners = 10,
	MaxEquippedEmotes = 4,

	-- Teste (só em DEV_). Atributo no ServerStorage que faz toda carga de perfil falhar.
	DevSimulateLoadFailureAttribute = "DEV_SimulateLoadFailure",
	DevAddCoinsAmount = 100,
	DevResetConfirmSeconds = 3, -- tocar de novo em "Resetar" dentro deste tempo para confirmar
}

return DataConfig
