--!strict
-- Ranking global (F9, GDD 9.3 e DADOS-JOGADOR 8): o que o servidor do lobby manda para a tela.

export type Entry = {
	userId: number,
	name: string,
	points: number,
	tier: string, -- RankRules.DisplayTier
}

export type Board = {
	available: boolean, -- false = o DataStore não respondeu (a tela avisa)
	updatedAt: number, -- os.time() da última leitura (0 = nunca)
	entries: { Entry }, -- os 100 primeiros, do maior PE para o menor (sem o ADM)
	admins: { Entry }, -- elo ADM, fixo no topo com o selo ADM (fora da contagem)
}

return {}
