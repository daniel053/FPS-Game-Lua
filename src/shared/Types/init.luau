--!strict
-- Tipos compartilhados entre servidor e cliente, nos 3 places.
-- Os tipos do perfil do jogador ficam em Types/PlayerData.luau (F1, ver docs/DADOS-JOGADOR.md).

export type PlaceName = "Lobby" | "Tutorial" | "Match"

export type CardKey = "C" | "Q" | "E" | "X"
export type Rarity = "Comum" | "Epica" | "Lendaria" | "Celestial"

-- Categorias de arma (GDD 7.2). Os nomes exibidos ficam em Strings.WeaponCategories.
export type WeaponCategory = "Pistol" | "SMG" | "Shotgun" | "LightRifle" | "Rifle" | "Sniper" | "MachineGun"

-- Fases de arma por rodada (GDD 7.2.2). Os IDs batem com LoadoutMemory.lastPrimaryByPhase (DADOS 3.1).
export type WeaponPhaseId = "pistolas" | "medias" | "pesadas"

export type WeaponSlot = "primary" | "secondary" | "melee"

-- Semi: um tiro por toque. Auto: segura e atira. Bolt: ferrolho (sniper). Double: dois tiros rápidos (Gêmea).
export type FireMode = "Semi" | "Auto" | "Bolt" | "Double"

-- Modo alternativo / mira (GDD 7.2.3 e 7.2.4).
export type AltMode = "Burst" | "Scope" | "ScopeBurst" | "FocusedPellets"

-- Tiro automático no celular, por tipo de arma (GDD 7.2.6).
export type AutoFireBehavior =
	"WhileOnTarget" -- automáticas: atira enquanto a retícula está sobre o inimigo
	| "MaxRateOnTarget" -- semiautomáticas: cadência máxima sobre o inimigo
	| "InEffectiveRange" -- escopetas: só dentro do alcance eficaz
	| "ScopedOnTarget" -- snipers: só com a mira aberta e a retícula sobre o inimigo
	| "SpinUpNearTarget" -- metralhadoras com aquecimento

export type TeamColorId = "Azul" | "Laranja" | "Verde" | "Roxo" | "Amarelo" | "Branco" | "Rosa" | "Ciano"

export type RankTierId = "Bronze" | "Prata" | "Ouro" | "Platina" | "Mestre" | "Deus"

export type MapId = "map_praca" | "map_fabrica" | "map_porto" | "map_torre"

return {}
