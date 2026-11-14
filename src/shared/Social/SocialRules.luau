--!strict
-- Regras puras da comunicação (GDD 12, F8). Sem serviços do Roblox: usadas pelo servidor (quem decide)
-- e pelo cliente (só para mostrar), e testadas em tests/specs/SocialRules.spec.

local SocialConfig = require(script.Parent.Parent.Config.SocialConfig)

local MIRANTE = "Mirante"

export type VoiceMode = "Direct" | "Spatial" | "None"

-- O que importa de cada jogador para a voz e o chat (atributos replicados no Player).
export type Presence = {
	userId: number,
	teamId: string?, -- dupla (nil = ainda sem dupla)
	location: string?, -- "Mirante", "Island1".."Island4" ou nil (derrubado, espectando o parceiro)
}

local SocialRules = {}

local function isMirante(p: Presence): boolean
	return p.location == MIRANTE
end

-- Como `listener` ouve `speaker` (GDD 12.2):
--   * os dois no mirante: por proximidade (inclui a própria dupla entre rodadas e antes de formar duplas);
--   * mesma dupla, fora disso: direto, sem depender da distância (rodada, derrubado espectando, um no
--     mirante e o outro na ilha);
--   * qualquer outro caso: não ouve (a voz da dupla nunca vaza para a adversária).
function SocialRules.voiceMode(listener: Presence, speaker: Presence): VoiceMode
	if listener.userId == speaker.userId then
		return "None"
	end
	if isMirante(listener) and isMirante(speaker) then
		return "Spatial"
	end
	if listener.teamId ~= nil and listener.teamId == speaker.teamId then
		return "Direct"
	end
	return "None"
end

-- Quem pode ouvir `speaker` (lista de UserIds para o AudioDeviceInput do servidor).
function SocialRules.voiceListeners(speaker: Presence, everyone: { Presence }): { number }
	local list = {}
	for _, other in everyone do
		if SocialRules.voiceMode(other, speaker) ~= "None" then
			table.insert(list, other.userId)
		end
	end
	table.sort(list)
	return list
end

-- Canais de texto em que o jogador deve estar: o da dupla e, no mirante (ou sem dupla), o do mirante.
function SocialRules.chatChannels(p: Presence): { [string]: boolean }
	local channels: { [string]: boolean } = {}
	if p.teamId then
		channels[SocialConfig.Chat.DuoChannelPrefix .. p.teamId] = true
	end
	if isMirante(p) or p.teamId == nil then
		channels[SocialConfig.Chat.MiranteChannel] = true
	end
	return channels
end

-- Para onde vai o que o jogador digita: mirante quando está lá (ou sem dupla), senão a dupla.
function SocialRules.chatTarget(p: Presence): string
	if isMirante(p) or p.teamId == nil then
		return SocialConfig.Chat.MiranteChannel
	end
	return SocialConfig.Chat.DuoChannelPrefix .. p.teamId
end

-- Pings só de quem está numa ilha de duelo (o mirante não interfere, GDD 6.5).
function SocialRules.canPing(location: string?): boolean
	return location ~= nil and string.match(location, "^Island%d+$") ~= nil
end

-- Emotes: no mirante e no fim da rodada (e na cerimônia e tela final, que também são fim).
function SocialRules.canEmote(location: string?, phase: string?): boolean
	if location == MIRANTE then
		return true
	end
	return phase == "RoundEnd" or phase == "Champion" or phase == "EndScreen"
end

-- Elogio: uma vez no fim de cada rodada e uma vez no fim da partida. Devolve a chave daquele momento
-- (nil = agora não pode).
function SocialRules.praiseKey(phase: string?, round: number): string?
	if phase == "RoundEnd" then
		return `r{round}`
	elseif phase == "Champion" or phase == "EndScreen" then
		return "end"
	end
	return nil
end

local function inList(list: { string }, value: unknown): boolean
	return typeof(value) == "string" and table.find(list, value :: string) ~= nil
end

function SocialRules.isPingKind(value: unknown): boolean
	return inList(SocialConfig.Ping.Kinds :: { any }, value)
end

function SocialRules.isPhrase(value: unknown): boolean
	return inList(SocialConfig.Phrases.Ids, value)
end

function SocialRules.emoteDef(value: unknown): SocialConfig.EmoteDef?
	if typeof(value) ~= "string" then
		return nil
	end
	for _, def in SocialConfig.Emotes.List do
		if def.id == value then
			return def
		end
	end
	return nil
end

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

-- Posição do ping: Vector3 finito, ao alcance de quem marcou (com a folga do servidor).
function SocialRules.pingInReach(origin: Vector3, value: unknown): boolean
	if typeof(value) ~= "Vector3" then
		return false
	end
	local position = value :: Vector3
	if not (finite(position.X) and finite(position.Y) and finite(position.Z)) then
		return false
	end
	return (position - origin).Magnitude <= SocialConfig.Ping.MaxDistance + SocialConfig.Ping.ServerSlack
end

-- Intervalo mínimo entre dois pedidos do mesmo tipo.
function SocialRules.intervalOk(lastAt: number?, now: number, minInterval: number): boolean
	return lastAt == nil or now - lastAt >= minInterval
end

-- Janela de frequência geral: { start, count }. Devolve se o pedido passa.
export type Window = { start: number, count: number }

function SocialRules.windowAllows(window: Window, now: number): boolean
	local cfg = SocialConfig.RateLimit
	if now - window.start >= cfg.WindowSeconds then
		window.start = now
		window.count = 0
	end
	window.count += 1
	return window.count <= cfg.MaxRequests
end

return SocialRules
