--!strict
-- Elo na interface (F9, GDD 9.3): ícone + nome na cor da faixa, nunca só a cor (ESTILO 2.2).
-- Usado no lobby (dupla), no placar (Tab), na tela final e no ranking. Textos com RichText.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)

local RankBadge = {}

function RankBadge.color(tier: string): Color3
	return Theme.Rank[tier] or Theme.Color.TextSecondary
end

function RankBadge.icon(tier: string): string
	return Strings.RankIcons[tier] or ""
end

function RankBadge.name(tier: string): string
	local names = Strings.Ranks :: { [string]: string }
	return names[tier] or tier
end

-- Texto comum dentro de um label RichText (nomes de jogador).
function RankBadge.escape(text: string): string
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

-- "◎ Bronze" com o ícone e o nome na cor da faixa (o label precisa de RichText = true).
function RankBadge.rich(tier: string?): string
	if tier == nil or tier == "" then
		return ""
	end
	local hex = RankBadge.color(tier):ToHex()
	return `<font color="#{hex}">{RankBadge.icon(tier)} {RankBadge.name(tier)}</font>`
end

-- Só o ícone colorido (linhas apertadas, como o placar).
function RankBadge.richIcon(tier: string?): string
	if tier == nil or tier == "" then
		return ""
	end
	return `<font color="#{RankBadge.color(tier):ToHex()}">{RankBadge.icon(tier)}</font>`
end

return RankBadge
