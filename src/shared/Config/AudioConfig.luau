--!strict
-- Sons (GDD 7.7). Todos os sons precisam ser ORIGINAIS (nunca de outros jogos).
--
-- F10: os sons finais são SINTETIZADOS por código (`scripts/sons/gerar.js`, decisão do dono do
-- projeto) e ficam em `assets/sons/<arquivo>.wav`. Cada som abaixo diz o seu `file`. Enquanto o arquivo
-- não foi enviado ao Roblox, toca o som provisório (`id`, da biblioteca que vem com o Roblox). Depois
-- do envio, o número do asset entra em `AudioAssets` e o som final passa a tocar sozinho
-- (`AudioConfig.resolve`). README: "Sons".
-- String vazia em `id` = sem som.

local AudioAssets = require(script.Parent.AudioAssets)

export type SoundDef = { id: string, file: string?, volume: number, pitch: number }

local GUN = "rbxasset://sounds/paintball.wav" -- estalo macio, provisório

-- Tiro: o som final já tem a afinação própria de cada arma (pitch 1); o provisório usa o tom.
local function gun(file: string, volume: number, provisionalPitch: number): SoundDef
	return { id = GUN, file = file, volume = volume, pitch = provisionalPitch }
end

local AudioConfig = {
	-- Som de tiro de cada arma, por ID de arma (macio, nada estridente).
	WeaponFire = {
		weapon_bolinha = gun("tiro_bolinha", 0.5, 1.25),
		weapon_chumbinho = gun("tiro_chumbinho", 0.7, 0.7),
		weapon_zumbido = gun("tiro_zumbido", 0.4, 1.45),
		weapon_precisa = gun("tiro_precisa", 0.5, 1.15),
		weapon_tambor = gun("tiro_tambor", 0.7, 0.8),
		weapon_ferrao = gun("tiro_ferrao", 0.4, 1.5),
		weapon_vespa = gun("tiro_vespa", 0.4, 1.35),
		weapon_balde = gun("tiro_balde", 0.8, 0.6),
		weapon_varredor = gun("tiro_varredor", 0.7, 0.7),
		weapon_tatico = gun("tiro_tatico", 0.5, 1.1),
		weapon_atirador = gun("tiro_atirador", 0.6, 0.95),
		weapon_martelo = gun("tiro_martelo", 0.45, 1.0),
		weapon_moedor = gun("tiro_moedor", 0.45, 0.9),
		weapon_rajada = gun("tiro_rajada", 0.35, 1.2), -- discreto
		weapon_trovao = gun("tiro_trovao", 0.6, 0.85),
		weapon_matapato = gun("tiro_matapato", 0.7, 0.75),
		weapon_gemea = gun("tiro_gemea", 0.75, 0.65),
		weapon_luneta = gun("tiro_luneta", 0.85, 0.55),
	} :: { [string]: SoundDef },

	MeleeSwing = { id = "rbxasset://sounds/swordslash.wav", file = "golpe_leve", volume = 0.5, pitch = 1.1 } :: SoundDef,
	MeleeHeavy = { id = "rbxasset://sounds/swordlunge.wav", file = "golpe_forte", volume = 0.6, pitch = 0.9 } :: SoundDef,
	Reload = { id = "rbxasset://sounds/switch.wav", file = "recarga", volume = 0.5, pitch = 1 } :: SoundDef,
	Equip = { id = "rbxasset://sounds/unsheath.wav", file = "sacar", volume = 0.3, pitch = 1.3 } :: SoundDef,
	Empty = { id = "rbxasset://sounds/clickfast.wav", file = "sem_municao", volume = 0.4, pitch = 1 } :: SoundDef,
	HitMarker = { id = "rbxasset://sounds/hit.wav", file = "acerto", volume = 0.35, pitch = 1.4 } :: SoundDef,
	-- Comunicação (F8)
	Ping = { id = "rbxasset://sounds/clickfast.wav", file = "ping", volume = 0.45, pitch = 1.6 } :: SoundDef,
	Phrase = { id = "rbxasset://sounds/clickfast.wav", file = "frase", volume = 0.3, pitch = 1.2 } :: SoundDef,
	ShieldBreak = { id = "rbxasset://sounds/glassbreak.wav", file = "escudo_quebrado", volume = 0.25, pitch = 1.6 } :: SoundDef, -- GDD 7.3
	-- "Crack" de abate: estalo curto, oco e macio (GDD 7.7)
	KillCrack = { id = "rbxasset://sounds/snap.wav", file = "crack_abate", volume = 0.8, pitch = 0.8 } :: SoundDef,
	Knockdown = { id = "rbxasset://sounds/collide.wav", file = "derrubado", volume = 0.4, pitch = 1.4 } :: SoundDef, -- poeira ao sumir
	-- Cartas (F10): sem som provisório (só tocam depois do envio)
	Cards = {
		NuvemThrow = { id = "", file = "carta_nuvem_arremesso", volume = 0.5, pitch = 1 },
		NuvemPuff = { id = "", file = "carta_nuvem_puf", volume = 0.6, pitch = 1 },
		Impulso = { id = "", file = "carta_impulso", volume = 0.6, pitch = 1 },
		Tremor = { id = "", file = "carta_tremor", volume = 0.7, pitch = 1 },
		RenascerMark = { id = "", file = "carta_renascer_marca", volume = 0.5, pitch = 1 },
		RenascerReturn = { id = "", file = "carta_renascer_volta", volume = 0.6, pitch = 1 },
	} :: { [string]: SoundDef },
	-- Ponto de escudo (F10)
	ShieldPickup = { id = "", file = "escudo_recarga", volume = 0.5, pitch = 1 } :: SoundDef,
	ViradaMusic = "", -- música da Rodada da Virada (GDD 4.5)

	-- Distância até onde se ouve o tiro dos outros (studs)
	ShotHearingDistance = 250,
}

-- O som que toca: o final (enviado ao Roblox, em `AudioAssets`) ou o provisório. O som final já vem
-- com a afinação certa, então toca com o tom 1.
function AudioConfig.resolve(def: SoundDef): (string, number)
	local asset = if def.file then AudioAssets[def.file] else nil
	if asset and asset > 0 then
		return `rbxassetid://{asset}`, 1
	end
	return def.id, def.pitch
end

return AudioConfig
