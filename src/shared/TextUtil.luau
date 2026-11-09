--!strict
-- Utilidades de texto. O string.upper do Luau só conhece letras sem acento ("Bastão" -> "BASTãO");
-- este upper também converte as letras acentuadas do português.

local ACCENTS: { [string]: string } = {
	["á"] = "Á",
	["à"] = "À",
	["â"] = "Â",
	["ã"] = "Ã",
	["é"] = "É",
	["ê"] = "Ê",
	["í"] = "Í",
	["ó"] = "Ó",
	["ô"] = "Ô",
	["õ"] = "Õ",
	["ú"] = "Ú",
	["ü"] = "Ü",
	["ç"] = "Ç",
}

local TextUtil = {}

function TextUtil.upper(text: string): string
	local result = string.upper(text)
	for lower, upper in ACCENTS do
		result = string.gsub(result, lower, upper)
	end
	return result
end

return TextUtil
