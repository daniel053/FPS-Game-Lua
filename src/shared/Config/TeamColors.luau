--!strict
-- Cores de equipe (GDD 3.3) [DECIDIDO].
-- A ordem é a ordem de distribuição das cores entre as duplas. O valor de cada cor fica no Theme.
-- Vermelho NÃO é cor de equipe: é reservado ao contorno de inimigo (GDD 7.6).

local Theme = require(script.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

local TeamColors = {
	Order = { "Azul", "Laranja", "Verde", "Roxo", "Amarelo", "Branco", "Rosa", "Ciano" } :: { Types.TeamColorId },
}

function TeamColors.getColor(id: Types.TeamColorId): Color3
	return Theme.Team[id]
end

return TeamColors
