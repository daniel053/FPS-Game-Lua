--!strict
-- Validação das configurações do jogador (docs/DADOS-JOGADOR.md seção 4).
-- Lógica pura, sem serviços do Roblox: usada pelo servidor (autoridade) e testada em src/tests.
--
--   applyPatch(atual, pedido): aplica um pedido do cliente. Qualquer valor inválido recusa o pedido INTEIRO.
--   sanitize(salvo): corrige um valor salvo ao carregar o perfil (limita números, troca inválidos pelo padrão).
--
-- Formato do pedido: só os campos que mudaram, com a mesma forma de Settings. Exemplo:
--   { sensitivity = { mouse = 1.5 }, crosshair = { color = "#FF00AA" }, autoFire = false }
-- `mobileLayout = false` volta ao layout padrão (nil no perfil).

local DataConfig = require(script.Parent.Config.DataConfig)
local DefaultProfile = require(script.Parent.Config.DefaultProfile)
local PlayerData = require(script.Parent.Types.PlayerData)

type Range = { Min: number, Max: number }
type Dict = { [string]: any }

-- Erros possíveis (devolvidos ao cliente para depuração):
--   NotTable, Empty, UnknownField, WrongType, OutOfRange, NotInteger,
--   InvalidColor, InvalidOption, TooManyButtons, InvalidButtonId
export type ErrorKey = string

local Limits = DataConfig.Limits

local SettingsValidation = {}

-- Número de verdade: rejeita NaN e infinito (exploits comuns em remotes).
function SettingsValidation.isFiniteNumber(value: unknown): boolean
	if typeof(value) ~= "number" then
		return false
	end
	local n = value :: number
	return n == n and n ~= math.huge and n ~= -math.huge
end

-- "#ffaa00" -> "#FFAA00". Aceita só # seguido de 6 dígitos hexadecimais.
function SettingsValidation.normalizeHex(value: unknown): string?
	if typeof(value) ~= "string" then
		return nil
	end
	local s = value :: string
	if string.match(s, "^#%x%x%x%x%x%x$") == nil then
		return nil
	end
	return string.upper(s)
end

local CROSSHAIR_SHAPES = { dot = true, cross = true, circle = true, cross_dot = true }
local OUTLINE_COLORS = { red = true, yellow = true, magenta = true }

local function isUiScaleOption(n: number): boolean
	for _, option in Limits.UiScaleOptions do
		if math.abs(option - n) < 1e-6 then
			return true
		end
	end
	return false
end

local function isValidButtonId(id: unknown): boolean
	if typeof(id) ~= "string" then
		return false
	end
	local s = id :: string
	return #s >= 1 and #s <= Limits.MobileButtonIdMaxLength and string.match(s, "^[%w_]+$") ~= nil
end

-- Descrição de cada campo numérico/simples: como validar no pedido e como corrigir no carregamento.
type FieldRule = {
	kind: "number" | "integer" | "boolean" | "option" | "hex" | "uiScale",
	range: Range?,
	options: { [string]: boolean }?,
}

local SENSITIVITY_RULES: { [string]: FieldRule } = {
	touch = { kind = "number", range = Limits.Sensitivity },
	mouse = { kind = "number", range = Limits.Sensitivity },
	gamepad = { kind = "number", range = Limits.Sensitivity },
	scopedMultiplier = { kind = "number", range = Limits.ScopedMultiplier },
}

local CROSSHAIR_RULES: { [string]: FieldRule } = {
	shape = { kind = "option", options = CROSSHAIR_SHAPES },
	color = { kind = "hex" },
	size = { kind = "integer", range = Limits.CrosshairSize },
	thickness = { kind = "integer", range = Limits.CrosshairThickness },
	gap = { kind = "integer", range = Limits.CrosshairGap },
	outline = { kind = "boolean" },
	outlineOpacity = { kind = "number", range = Limits.CrosshairOutlineOpacity },
}

local AUDIO_RULES: { [string]: FieldRule } = {
	master = { kind = "number", range = Limits.Audio },
	sfx = { kind = "number", range = Limits.Audio },
	music = { kind = "number", range = Limits.Audio },
	voice = { kind = "number", range = Limits.Audio },
}

local TOP_RULES: { [string]: FieldRule } = {
	autoFire = { kind = "boolean" },
	aimAssist = { kind = "boolean" },
	enemyOutlineColor = { kind = "option", options = OUTLINE_COLORS },
	uiScale = { kind = "uiScale" },
	reduceEffects = { kind = "boolean" },
	voicePromptSeen = { kind = "boolean" },
}

local GROUP_RULES: { [string]: { [string]: FieldRule } } = {
	sensitivity = SENSITIVITY_RULES,
	crosshair = CROSSHAIR_RULES,
	audio = AUDIO_RULES,
}

-- Valida um valor vindo do cliente. Retorna (valor normalizado, nil) ou (nil, erro).
local function checkValue(rule: FieldRule, value: unknown): (any, ErrorKey?)
	if rule.kind == "boolean" then
		if typeof(value) ~= "boolean" then
			return nil, "WrongType"
		end
		return value, nil
	elseif rule.kind == "option" then
		if typeof(value) ~= "string" then
			return nil, "WrongType"
		end
		local options = rule.options :: { [string]: boolean }
		if options[value :: string] ~= true then
			return nil, "InvalidOption"
		end
		return value, nil
	elseif rule.kind == "hex" then
		if typeof(value) ~= "string" then
			return nil, "WrongType"
		end
		local hex = SettingsValidation.normalizeHex(value)
		if hex == nil then
			return nil, "InvalidColor"
		end
		return hex, nil
	elseif rule.kind == "uiScale" then
		if not SettingsValidation.isFiniteNumber(value) then
			return nil, "WrongType"
		end
		if not isUiScaleOption(value :: number) then
			return nil, "InvalidOption"
		end
		return value, nil
	else -- number / integer
		if not SettingsValidation.isFiniteNumber(value) then
			return nil, "WrongType"
		end
		local n = value :: number
		if rule.kind == "integer" and n % 1 ~= 0 then
			return nil, "NotInteger"
		end
		local range = rule.range :: Range
		if n < range.Min or n > range.Max then
			return nil, "OutOfRange"
		end
		return n, nil
	end
end

-- Corrige um valor salvo: limita números ao intervalo; tipo errado volta ao padrão.
local function repairValue(rule: FieldRule, value: unknown, default: any): any
	if rule.kind == "number" or rule.kind == "integer" then
		if not SettingsValidation.isFiniteNumber(value) then
			return default
		end
		local range = rule.range :: Range
		local n = math.clamp(value :: number, range.Min, range.Max)
		if rule.kind == "integer" then
			n = math.round(n)
		end
		return n
	end
	local fixed, err = checkValue(rule, value)
	if err then
		return default
	end
	return fixed
end

local function checkMobileLayout(value: unknown): (PlayerData.MobileButtonLayout?, ErrorKey?)
	if value == false then
		return nil, nil -- volta ao layout padrão
	end
	if typeof(value) ~= "table" then
		return nil, "WrongType"
	end
	local result: PlayerData.MobileButtonLayout = {}
	local count = 0
	for id, placement in value :: Dict do
		if not isValidButtonId(id) then
			return nil, "InvalidButtonId"
		end
		count += 1
		if count > Limits.MobileLayoutMaxButtons then
			return nil, "TooManyButtons"
		end
		if typeof(placement) ~= "table" then
			return nil, "WrongType"
		end
		local p = placement :: Dict
		for key in p do
			if key ~= "x" and key ~= "y" and key ~= "scale" then
				return nil, "UnknownField"
			end
		end
		local x, y, scale = p.x, p.y, p.scale
		if
			not SettingsValidation.isFiniteNumber(x)
			or not SettingsValidation.isFiniteNumber(y)
			or not SettingsValidation.isFiniteNumber(scale)
		then
			return nil, "WrongType"
		end
		if x < 0 or x > 1 or y < 0 or y > 1 then
			return nil, "OutOfRange"
		end
		if scale < Limits.MobileButtonScale.Min or scale > Limits.MobileButtonScale.Max then
			return nil, "OutOfRange"
		end
		result[id :: string] = { x = x, y = y, scale = scale }
	end
	return result, nil
end

local function deepCopy<T>(value: T): T
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = deepCopy(v)
	end
	return copy :: any
end

-- Aplica um pedido do cliente sobre as configurações atuais.
-- Sucesso: (novas configurações, nil). Falha: (nil, erro) — nada muda.
function SettingsValidation.applyPatch(current: PlayerData.Settings, patch: unknown): (PlayerData.Settings?, ErrorKey?)
	if typeof(patch) ~= "table" then
		return nil, "NotTable"
	end
	local request = patch :: Dict
	if next(request) == nil then
		return nil, "Empty"
	end

	local result = deepCopy(current) :: Dict

	for field, value in request do
		if typeof(field) ~= "string" then
			return nil, "UnknownField"
		end
		local group = GROUP_RULES[field]
		local rule = TOP_RULES[field]
		if group then
			if typeof(value) ~= "table" then
				return nil, "WrongType"
			end
			local target = result[field] :: Dict
			for subField, subValue in value :: Dict do
				local subRule = if typeof(subField) == "string" then group[subField] else nil
				if subRule == nil then
					return nil, "UnknownField"
				end
				local fixed, err = checkValue(subRule, subValue)
				if err then
					return nil, err
				end
				target[subField] = fixed
			end
		elseif rule then
			local fixed, err = checkValue(rule, value)
			if err then
				return nil, err
			end
			result[field] = fixed
		elseif field == "mobileLayout" then
			local layout, err = checkMobileLayout(value)
			if err then
				return nil, err
			end
			result.mobileLayout = layout
		else
			return nil, "UnknownField"
		end
	end

	return result :: PlayerData.Settings, nil
end

-- Corrige configurações salvas (ao carregar o perfil). Nunca falha.
-- Campos desconhecidos são preservados (DADOS 1.6: uma versão mais nova pode tê-los escrito).
function SettingsValidation.sanitize(saved: unknown): PlayerData.Settings
	local defaults = DefaultProfile.settings() :: Dict
	if typeof(saved) ~= "table" then
		return defaults :: PlayerData.Settings
	end
	local result = deepCopy(saved) :: Dict

	for groupName, rules in GROUP_RULES do
		local defaultGroup = defaults[groupName] :: Dict
		local group = result[groupName]
		if typeof(group) ~= "table" then
			result[groupName] = defaultGroup
			continue
		end
		for field, rule in rules do
			group[field] = repairValue(rule, group[field], defaultGroup[field])
		end
	end

	for field, rule in TOP_RULES do
		result[field] = repairValue(rule, result[field], defaults[field])
	end

	if result.mobileLayout ~= nil then
		local layout, err = checkMobileLayout(result.mobileLayout)
		result.mobileLayout = if err then nil else layout
	end

	return result :: PlayerData.Settings
end

return SettingsValidation
