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
	},

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
