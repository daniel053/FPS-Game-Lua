--!strict
-- Formato das mensagens de combate entre cliente e servidor (remotes em Remotes.luau).
-- O servidor nunca confia nesses formatos: tudo o que chega do cliente é checado campo a campo.

export type Slot = "primary" | "secondary" | "melee"

-- Cliente -> servidor, remote "WeaponAction": (ação, horário t em tempo do servidor, argumento)
export type WeaponActionName = "Equip" | "Reload" | "Alt" | "Spin" | "Fire" | "Melee"

-- Um bago/bala que acertou alguém.
export type FireHit = {
	part: BasePart, -- a hitbox atingida
	position: Vector3, -- ponto de acerto
	pellet: number, -- índice do bago (1..pellets)
}

-- Argumento de "Fire"
export type FirePayload = {
	origin: Vector3, -- posição da câmera no tiro
	ends: { Vector3 }, -- fim de cada bago/bala (para o rastro que os outros veem)
	hits: { FireHit },
}

-- Argumento de "Melee"
export type MeleePayload = {
	heavy: boolean,
	part: BasePart?, -- hitbox atingida (nil = golpe no ar)
}

-- Servidor -> cliente, remote "CombatEvent": (tipo, dados)
export type CombatEventName =
	"Loadout" -- LoadoutData: armas do jogador e a equipada
	| "Disarm" -- nil: sem armas (mirante, preparação)
	| "Sync" -- SyncData: corrige munição/recarga depois de um pedido recusado
	| "Hit" -- HitData: confirmação de acerto para quem atirou (número de dano, marcador)
	| "Damaged" -- DamagedData: quem levou dano (direção)
	| "Kill" -- KillData: abate para quem derrubou (aviso "N KILL")
	| "Knocked" -- KnockedData: alguém foi derrubado (efeito de poeira para todos)

export type LoadoutData = {
	primary: string?,
	secondary: string,
	melee: string,
	equipped: Slot,
}

export type SyncData = { slot: Slot, ammo: number, reloadEndsAt: number? }

export type HitData = {
	position: Vector3,
	damage: number,
	shieldBroken: boolean,
	knocked: boolean,
	toShield: number,
}

export type DamagedData = { from: Vector3 }

export type KillData = {
	kills: number, -- abates na partida
	victimName: string,
	weaponId: string,
	seconds: number, -- do primeiro dano (com vida cheia) até derrubar
	shots: number, -- tiros que acertaram nesse tempo
}

export type KnockedData = { position: Vector3 }

return {}
