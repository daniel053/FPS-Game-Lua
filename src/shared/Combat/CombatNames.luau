--!strict
-- Nomes compartilhados entre servidor e cliente no combate (tags, atributos, grupos de colisão).

return {
	-- Tag (CollectionService) de todo modelo que pode levar dano: personagens e alvos da arena.
	CombatantTag = "Combatant",

	-- Atributos no modelo do combatente (replicam para os clientes)
	Attr = {
		TeamId = "TeamId", -- dupla (cor da equipe) ou "Alvo"
		Hp = "Hp",
		Shield = "Shield",
		Alive = "Alive",
		DisplayName = "CombatName",
		Kills = "Kills", -- no Player: abates na partida (aviso "N KILL")
		-- ID da arma na mão agora (WeaponConfig, ou o Bastão); nil = sem arma. Os outros clientes
		-- desenham a arma na mão e a pose de mira (combat/client/HeldWeapons).
		Held = "HeldWeapon",
	},

	-- Nome do modelo da arma na mão, dentro do personagem (só no cliente) e do ponto da boca do cano
	HeldModelName = "HeldWeapon",
	MuzzleName = "Muzzle",

	-- Dupla dos alvos da arena de teste: inimigos de todos.
	DummyTeam = "Alvo",

	-- Peça invisível que recebe os tiros (uma por personagem).
	HitboxName = "Hitbox",

	-- Grupos de colisão (o servidor registra; os raios do cliente usam os mesmos nomes)
	Groups = {
		Body = "CharacterBody", -- corpo dos personagens (colide com o mapa; os tiros passam)
		Hitbox = "Hitbox", -- só os tiros acertam
		ShotRay = "ShotRay", -- raio de tiro: acerta mapa e hitboxes
		SightRay = "SightRay", -- raio de visão: só o mapa
	},

	-- Pasta de efeitos e da arma em primeira pessoa no cliente (ignorada pelos raios)
	EffectsFolder = "CombatEffects",
}
