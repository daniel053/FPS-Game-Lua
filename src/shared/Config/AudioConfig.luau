--!strict
-- Sons (GDD 7.7). Todos os sons precisam ser ORIGINAIS (nunca de outros jogos).
-- F2: sons PROVISÓRIOS da biblioteca que vem com o Roblox (rbxasset://sounds), com tom diferente por arma.
-- Os sons finais (tiro macio, "crack" de abate) entram na F10, com aprovação do dono do projeto.
-- String vazia = sem som.

export type SoundDef = { id: string, volume: number, pitch: number }

local GUN = "rbxasset://sounds/paintball.wav" -- estalo macio, provisório

local AudioConfig = {
	-- Som de tiro de cada arma, por ID de arma (macio, nada estridente). Tom diferente = som próprio.
	WeaponFire = {
		weapon_bolinha = { id = GUN, volume = 0.5, pitch = 1.25 },
		weapon_chumbinho = { id = GUN, volume = 0.7, pitch = 0.7 },
		weapon_zumbido = { id = GUN, volume = 0.4, pitch = 1.45 },
		weapon_precisa = { id = GUN, volume = 0.5, pitch = 1.15 },
		weapon_tambor = { id = GUN, volume = 0.7, pitch = 0.8 },
		weapon_ferrao = { id = GUN, volume = 0.4, pitch = 1.5 },
		weapon_vespa = { id = GUN, volume = 0.4, pitch = 1.35 },
		weapon_balde = { id = GUN, volume = 0.8, pitch = 0.6 },
		weapon_varredor = { id = GUN, volume = 0.7, pitch = 0.7 },
		weapon_tatico = { id = GUN, volume = 0.5, pitch = 1.1 },
		weapon_atirador = { id = GUN, volume = 0.6, pitch = 0.95 },
		weapon_martelo = { id = GUN, volume = 0.45, pitch = 1.0 },
		weapon_moedor = { id = GUN, volume = 0.45, pitch = 0.9 },
		weapon_rajada = { id = GUN, volume = 0.35, pitch = 1.2 }, -- discreto
		weapon_trovao = { id = GUN, volume = 0.6, pitch = 0.85 },
		weapon_matapato = { id = GUN, volume = 0.7, pitch = 0.75 },
		weapon_gemea = { id = GUN, volume = 0.75, pitch = 0.65 },
		weapon_luneta = { id = GUN, volume = 0.85, pitch = 0.55 },
	} :: { [string]: SoundDef },

	MeleeSwing = { id = "rbxasset://sounds/swordslash.wav", volume = 0.5, pitch = 1.1 } :: SoundDef,
	MeleeHeavy = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.6, pitch = 0.9 } :: SoundDef,
	Reload = { id = "rbxasset://sounds/switch.wav", volume = 0.5, pitch = 1 } :: SoundDef,
	Equip = { id = "rbxasset://sounds/unsheath.wav", volume = 0.3, pitch = 1.3 } :: SoundDef,
	Empty = { id = "rbxasset://sounds/clickfast.wav", volume = 0.4, pitch = 1 } :: SoundDef,
	HitMarker = { id = "rbxasset://sounds/hit.wav", volume = 0.35, pitch = 1.4 } :: SoundDef,
	ShieldBreak = { id = "rbxasset://sounds/glassbreak.wav", volume = 0.25, pitch = 1.6 } :: SoundDef, -- GDD 7.3
	KillCrack = { id = "rbxasset://sounds/snap.wav", volume = 0.8, pitch = 0.8 } :: SoundDef, -- estalo curto, oco e macio
	Knockdown = { id = "rbxasset://sounds/collide.wav", volume = 0.4, pitch = 1.4 } :: SoundDef, -- poeira ao sumir
	ViradaMusic = "", -- música da Rodada da Virada (GDD 4.5)

	-- Distância até onde se ouve o tiro dos outros (studs)
	ShotHearingDistance = 250,
}

return AudioConfig
