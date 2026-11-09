--!strict
-- Ferramentas de teste. Só funcionam no ambiente DEV_ (ver Env.luau).

local DevConfig = {
	-- Painel de teleporte de teste
	TeleportCooldownSeconds = 3, -- limite de pedidos por jogador
	PanelToggleKey = Enum.KeyCode.T, -- PC
	PanelToggleGamepadButton = Enum.KeyCode.DPadUp, -- controle

	-- Testes de dados (F1). Moedas e tempos de confirmação ficam em DataConfig.
	SensitivityStep = 0.5, -- botão "SENSIBILIDADE +": soma isto e volta ao mínimo ao passar do máximo
	InvalidSensitivity = 99, -- valor fora do intervalo para testar a recusa do servidor
	PanelMaxSize = Vector2.new(360, 640),
	PanelHeightScale = 0.85, -- o painel rola quando não cabe (celular deitado)
}

return DevConfig
