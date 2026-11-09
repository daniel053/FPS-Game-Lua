--!strict
-- IDs de som (GDD 7.7). Todos os sons precisam ser ORIGINAIS (nunca de outros jogos).
-- Vazio até existirem sons provisórios (F2) e finais (F10, com aprovação do dono do projeto).
-- Formato: "rbxassetid://123456". String vazia = sem som.

local AudioConfig = {
	-- Som de tiro de cada arma, por ID de arma (macio, nada estridente)
	WeaponFire = {} :: { [string]: string },

	KillCrack = "", -- estalo curto, oco e macio ao derrubar
	ShieldBreak = "", -- som diferente quando o escudo quebra (GDD 7.3)
	HitMarker = "",
	ViradaMusic = "", -- música da Rodada da Virada (GDD 4.5)
}

return AudioConfig
