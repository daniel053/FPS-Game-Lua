--!strict
-- Prepara um perfil carregado do DataStore (docs/DADOS-JOGADOR.md seção 5.1, passos 4 e validação).
--   * Campos ausentes recebem o padrão (sem migração: seção 7).
--   * Campo com tipo errado volta ao padrão.
--   * Números limitados (contadores nunca negativos; configurações no intervalo).
--   * Campos DESCONHECIDOS são preservados (seção 1.6: uma versão mais nova pode tê-los escrito).
-- Roda depois das migrações. Devolve a lista do que foi corrigido, para o Output.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local DataConfig = require(Shared.Config.DataConfig)
local DefaultProfile = require(Shared.Config.DefaultProfile)
local PlayerData = require(Shared.Types.PlayerData)
local SettingsValidation = require(Shared.SettingsValidation)

type Dict = { [string]: any }

local ProfileSanitizer = {}

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Completa `target` com `defaults` (só chaves de texto). Tipo diferente do padrão = troca pelo padrão.
function ProfileSanitizer.fillDefaults(target: Dict, defaults: Dict, path: string?, fixes: { string }?)
	local prefix = if path then path .. "." else ""
	for key, default in defaults do
		if typeof(key) ~= "string" then
			continue
		end
		local current = target[key]
		if current == nil then
			target[key] = deepCopy(default)
		elseif typeof(current) ~= typeof(default) then
			target[key] = deepCopy(default)
			if fixes then
				table.insert(fixes, `{prefix}{key}: tipo errado ({typeof(current)}), voltou ao padrão`)
			end
		elseif typeof(default) == "table" then
			ProfileSanitizer.fillDefaults(current, default, prefix .. key, fixes)
		end
	end
end

local function isFinite(n: unknown): boolean
	return typeof(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- Contador: inteiro, nunca negativo.
local function fixCounter(t: Dict, key: string, path: string, fixes: { string })
	local value = t[key]
	local fixed = if isFinite(value) then math.max(0, math.floor(value :: number)) else 0
	if fixed ~= value then
		t[key] = fixed
		table.insert(fixes, `{path}.{key}: {tostring(value)} -> {fixed}`)
	end
end

local COUNTERS: { [string]: { string } } = {
	[""] = { "coins", "gems", "tutorialStep" },
	rank = { "points", "matchesPlayed", "peakPoints" },
	stats = {
		"matchesPlayed",
		"matchesWon",
		"podiums",
		"roundsPlayed",
		"roundsWon",
		"kills",
		"deaths",
		"damageDealt",
		"viradasWon",
		"soloRoundsWon",
	},
	social = { "praisesReceived" },
	daily = { "loginStreak" },
	moderation = { "warnings" },
}

-- Recebe o perfil já migrado (tabela solta) e devolve o perfil pronto + correções feitas.
function ProfileSanitizer.sanitize(raw: Dict, now: number): (PlayerData.Profile, { string })
	local fixes: { string } = {}

	ProfileSanitizer.fillDefaults(raw, DefaultProfile.new(now) :: any, nil, fixes)

	for group, keys in COUNTERS do
		local t = if group == "" then raw else raw[group]
		for _, key in keys do
			fixCounter(t, key, if group == "" then "profile" else group, fixes)
		end
	end

	local rank = raw.rank :: Dict
	if rank.peakPoints < rank.points then
		rank.peakPoints = rank.points
	end

	raw.settings = SettingsValidation.sanitize(raw.settings)

	-- Parceiros recentes: entradas válidas, no máximo 10 (seção 4).
	local partners: { Dict } = {}
	for _, entry in raw.social.recentPartners do
		if typeof(entry) == "table" and isFinite(entry.userId) and isFinite(entry.at) then
			table.insert(partners, entry)
		end
	end
	while #partners > DataConfig.MaxRecentPartners do
		table.remove(partners)
	end
	if #partners ~= #raw.social.recentPartners then
		table.insert(fixes, "social.recentPartners: entradas inválidas ou excesso removidos")
	end
	raw.social.recentPartners = partners

	-- Emotes equipados: textos, no máximo 4 (seção 4).
	local emotes: { string } = {}
	for _, id in raw.cosmetics.equipped.emotes do
		if typeof(id) == "string" and #emotes < DataConfig.MaxEquippedEmotes then
			table.insert(emotes, id)
		end
	end
	if #emotes ~= #raw.cosmetics.equipped.emotes then
		table.insert(fixes, "cosmetics.equipped.emotes: excesso ou inválidos removidos")
	end
	raw.cosmetics.equipped.emotes = emotes

	if typeof(raw.tutorialDone) ~= "boolean" then
		raw.tutorialDone = false
	end

	return raw :: PlayerData.Profile, fixes
end

return ProfileSanitizer
