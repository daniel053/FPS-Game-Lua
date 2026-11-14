--!strict
-- Posição e tamanho dos botões de toque do combate (GDD 13.1), com o layout editável pelo jogador
-- (settings.mobileLayout, F7). Sem nada salvo, vale o padrão do CombatConfig.TouchLayout (pixels a
-- partir do canto inferior direito). Com o botão salvo, vale a posição relativa (0 a 1) do centro e
-- a escala sobre o tamanho padrão.
-- Usado pelos botões de toque (Partida e Tutorial) e pelo editor de botões (todos os places).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local PlayerData = require(Shared.Types.PlayerData)
local SocialConfig = require(Shared.Config.SocialConfig)

local LAYOUT = CombatConfig.TouchLayout

export type Placement = { position: UDim2, size: number }

local TouchLayout = {}

-- Todos os botões editáveis, na ordem do editor. Cartas: cada tecla no mesmo lugar (GDD 8.3).
-- Ping, Frases e Emotes (F8) ficam por padrão no canto superior esquerdo (SocialConfig.Touch).
TouchLayout.ButtonIds = { "Fire", "Aim", "Switch", "Reload", "Q", "E", "C", "X", "Ping", "Phrase", "Emote" }

local SOCIAL_IDS: { [string]: boolean } = { Ping = true, Phrase = true, Emote = true }

local function sizeSet(viewport: Vector2): any
	return if math.min(viewport.X, viewport.Y) >= LAYOUT.LargeScreenMinSide then LAYOUT.Large else LAYOUT.Small
end

local function defaultOf(id: string, viewport: Vector2): (Vector2, number)
	local set = sizeSet(viewport)
	if id == "Fire" then
		return set.Fire, set.FireSize
	elseif id == "Aim" then
		return set.Aim, set.ButtonSize
	elseif id == "Switch" then
		return set.Switch, set.ButtonSize
	elseif id == "Reload" then
		return set.Reload, set.ButtonSize
	end
	local card = (set.Cards :: { [string]: Vector2 })[id]
	return card or Vector2.new(-75, -345), set.CardSize
end

-- Padrão: deslocamento em pixels do canto inferior direito da área segura (botões sociais: do canto
-- superior esquerdo).
function TouchLayout.default(id: string, viewport: Vector2): Placement
	if SOCIAL_IDS[id] then
		local small = math.min(viewport.X, viewport.Y) < LAYOUT.LargeScreenMinSide
		local set = if small then SocialConfig.Touch.Small else SocialConfig.Touch.Large
		local offset = (set :: any)[id] :: Vector2
		return { position = UDim2.fromOffset(offset.X, offset.Y), size = set.ButtonSize }
	end
	local offset, size = defaultOf(id, viewport)
	return { position = UDim2.new(1, offset.X, 1, offset.Y), size = size }
end

function TouchLayout.resolve(id: string, viewport: Vector2, saved: PlayerData.MobileButtonLayout?): Placement
	local base = TouchLayout.default(id, viewport)
	local entry = saved and saved[id]
	if entry == nil then
		return base
	end
	return { position = UDim2.fromScale(entry.x, entry.y), size = math.floor(base.size * entry.scale + 0.5) }
end

-- Centro relativo (0 a 1) de uma posição dentro de uma área (para o editor salvar).
function TouchLayout.toRelative(position: UDim2, area: Vector2): Vector2
	local x = position.X.Scale + position.X.Offset / math.max(area.X, 1)
	local y = position.Y.Scale + position.Y.Offset / math.max(area.Y, 1)
	return Vector2.new(math.clamp(x, 0, 1), math.clamp(y, 0, 1))
end

return TouchLayout
