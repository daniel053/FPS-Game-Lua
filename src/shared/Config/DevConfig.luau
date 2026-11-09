--!strict
-- Ferramentas de teste. Só funcionam no ambiente DEV_ (ver Env.luau).

local DevConfig = {
	-- Painel de teleporte de teste
	TeleportCooldownSeconds = 3, -- limite de pedidos por jogador
	PanelToggleKey = Enum.KeyCode.T, -- PC
	PanelToggleGamepadButton = Enum.KeyCode.DPadUp, -- controle
}

return DevConfig
