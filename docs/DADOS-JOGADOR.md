# [NOME DO JOGO] — Dados salvos do jogador

> **Versão do documento:** 0.1
> **Versão do esquema de dados:** 1
> **Documentos irmãos:** `docs/GDD.md`, `docs/FASES.md`

---

## 0. Como usar este documento (para o Claude Code)

- Este documento define **tudo o que é salvo** sobre cada jogador, como é salvo e como evolui.
- Os tipos abaixo são o contrato. O código deve usar exatamente estes nomes de campo, em `src/shared/Types/PlayerData.luau`.
- Os valores padrão ficam em `src/shared/Config/DefaultProfile.luau`.
- Nada aqui é salvo pelo cliente. **Só o servidor lê e escreve dados.**
- Mesmos marcadores do GDD: `[DECIDIDO]`, `[PROPOSTA]`, `[ABERTO]`.

---

## 1. Princípios `[DECIDIDO]`

1. **Servidor é o dono dos dados.** O cliente recebe uma cópia somente leitura do que precisa mostrar.
2. **Um perfil por jogador**, carregado quando ele entra em qualquer place e salvo quando sai.
3. **Trava de sessão:** o mesmo perfil nunca pode estar aberto em dois servidores ao mesmo tempo (evita duplicar moedas em teleportes).
4. **Nunca perder progresso:** salvamento automático periódico, salvamento ao sair, salvamento quando o servidor fecha, e repetição com espera em caso de falha.
5. **Esquema versionado:** todo perfil tem `schemaVersion`. Mudou o formato, cria-se uma migração. Perfis antigos são migrados ao carregar.
6. **Validar ao carregar:** campos ausentes recebem o padrão; campos desconhecidos são preservados (não apagar dado que uma versão mais nova pode ter escrito).
7. **Guardar o mínimo:** só o que precisa sobreviver entre sessões. Estado da partida (vidas, rodada, arma da rodada) **não** é salvo no perfil.
8. **IDs, não nomes:** cartas, armas e skins são salvas pelo **ID** do catálogo (`"card_nuvem"`, `"weapon_rajada"`, `"skin_rajada_laranja"`), nunca pelo nome exibido. Renomear um item no jogo não quebra dados.
9. **Tamanho:** o perfil deve ficar abaixo de **50 KB** em JSON (o limite do Roblox por chave é bem maior, mas perfis pequenos carregam rápido).

---

## 2. Onde os dados ficam

| Armazenamento | Tipo no Roblox | Chave | Conteúdo |
|---|---|---|---|
| `PlayerProfile_v1` | DataStore | `u_<UserId>` | Perfil completo (seção 3) |
| `PurchaseReceipts_v1` | DataStore | `<PurchaseId>` | Recibos de compras em Robux já processadas (seção 6) |
| `RankLeaderboard_v1` | OrderedDataStore | `<UserId>` | Pontos de elo, para o ranking global |
| `WinsLeaderboard_v1` | OrderedDataStore | `<UserId>` | Vitórias de partida, para o ranking de vitórias `[PROPOSTA]` |
| `MatchQueue_v1` | MemoryStore (mapa ordenado) | `<id da ficha>` | Fila de matchmaking: uma ficha por grupo, expira em 30 s se o lobby dono não renovar (temporário, não é dado do jogador) |
| `MatchQueueControl_v1` | MemoryStore (mapa ordenado) | `leader`, `status` | Trava do lobby líder e contagem da fila (temporário) |
| `MatchHandoff_v1` | MemoryStore (mapa ordenado) | `<PrivateServerId>` | Composição da partida entregue ao servidor de partida (temporário, expira em 5 min) |
| `LobbyHandoff_v1` | MemoryStore (mapa ordenado) | `u_<UserId>` | Volta da partida: entrar direto na fila, passar na frente, dupla fixa (temporário, expira em 2 min) |

- O sufixo `_v1` no nome do DataStore só muda em caso de **recomeço total** (ex.: limpeza antes do lançamento). Mudanças de formato normais usam `schemaVersion` e migração.
- Ambiente de teste (Studio e servidores de teste) usa DataStores com prefixo `DEV_` para não misturar com dados reais. `[PROPOSTA]`

---

## 3. Esquema do perfil (versão 1)

### 3.1 Tipos (contrato)

```lua
--!strict
-- src/shared/Types/PlayerData.luau

export type CardId = string      -- ex.: "card_nuvem"
export type WeaponId = string    -- ex.: "weapon_rajada"
export type SkinId = string      -- ex.: "skin_rajada_laranja"
export type CardKey = "C" | "Q" | "E" | "X"
export type Rarity = "Comum" | "Epica" | "Lendaria" | "Celestial"

export type OwnedCard = {
	acquiredAt: number,          -- os.time() de quando ganhou
	source: "tutorial" | "spin" | "shop" | "event" | "admin",
}

export type OwnedSkin = {
	acquiredAt: number,
	source: "shop_coins" | "shop_robux" | "reward" | "event" | "admin",
}

export type CrosshairSettings = {
	shape: "dot" | "cross" | "circle" | "cross_dot",
	color: string,               -- hex, ex.: "#FFFFFF"
	size: number,                -- 1 a 10
	thickness: number,           -- 1 a 5
	gap: number,                 -- 0 a 10
	outline: boolean,
	outlineOpacity: number,      -- 0 a 1
}

export type SensitivitySettings = {
	touch: number,               -- 0.1 a 5.0
	mouse: number,
	gamepad: number,
	scopedMultiplier: number,    -- multiplicador quando a mira de sniper está aberta
}

-- Chave: botão de combate ("Fire", "Aim", "Switch", "Reload", "Q", "E", "C", "X").
-- x, y: centro do botão, relativo (0 a 1) à área segura da tela; scale: sobre o tamanho padrão.
-- Botão ausente = posição e tamanho padrão (editor de botões do painel de configurações, F7).
export type MobileButtonLayout = {
	[string]: { x: number, y: number, scale: number },  -- posição relativa (0 a 1) e escala
}

export type Settings = {
	sensitivity: SensitivitySettings,
	crosshair: CrosshairSettings,
	autoFire: boolean,                 -- só tem efeito no toque
	aimAssist: boolean,                -- toque e controle
	enemyOutlineColor: "red" | "yellow" | "magenta",
	uiScale: number,                   -- 1.0, 1.15 ou 1.3
	reduceEffects: boolean,
	audio: { master: number, sfx: number, music: number, voice: number },  -- 0 a 1
	mobileLayout: MobileButtonLayout?, -- nil = layout padrão
	voicePromptSeen: boolean,          -- já viu a tela de voz do tutorial
}

export type RankData = {
	points: number,                    -- pontos de elo (PE)
	matchesPlayed: number,             -- partidas ranqueadas jogadas
	peakPoints: number,                -- maior PE já alcançado
	seasonId: number,                  -- temporada atual [ABERTO: existirá temporada?]
}

export type Stats = {
	matchesPlayed: number,
	matchesWon: number,
	podiums: number,                   -- 1º, 2º ou 3º
	roundsPlayed: number,
	roundsWon: number,
	kills: number,
	deaths: number,
	damageDealt: number,
	viradasWon: number,                -- Rodadas da Virada vencidas
	soloRoundsWon: number,             -- rodadas vencidas jogando 1v2
	killsByWeapon: { [WeaponId]: number },
}

export type LoadoutMemory = {
	lastCard: CardId?,                 -- carta escolhida na última partida
	lastPrimaryByPhase: { [string]: WeaponId },  -- "medias" / "pesadas"
	lastSecondary: WeaponId?,
}

export type Social = {
	praisesReceived: number,
	equippedTitle: string?,
	recentPartners: { { userId: number, at: number } },  -- últimos 10, para sugerir "jogar de novo"
}

export type Daily = {
	lastFirstWinDay: number?,          -- dia (UTC) da última "primeira vitória do dia"
	lastFreeSpinDay: number?,          -- dia (UTC) do último giro grátis [depende de GDD 8.9]
	loginStreak: number,
	lastLoginDay: number?,
}

export type Moderation = {
	warnings: number,
	lastWarningAt: number?,
}

export type Profile = {
	schemaVersion: number,
	createdAt: number,
	lastLoginAt: number,
	lastSaveAt: number,

	tutorialDone: boolean,
	tutorialStep: number,              -- etapa em que parou, para retomar se sair no meio

	coins: number,
	gems: number,                      -- [ABERTO] segunda moeda; fica 0 até ser decidida

	cards: {
		owned: { [CardId]: OwnedCard },
		-- regra: no máximo 1 carta por tecla; validado pelo servidor
	},

	cosmetics: {
		owned: { [SkinId]: OwnedSkin },
		equipped: {
			weapons: { [WeaponId]: SkinId },   -- arma sem entrada = skin padrão
			melee: SkinId?,
			body: SkinId?,
			head: SkinId?,
			victoryEffect: SkinId?,
			emotes: { SkinId },                -- até 4
		},
	},

	loadout: LoadoutMemory,
	settings: Settings,
	rank: RankData,
	stats: Stats,
	social: Social,
	daily: Daily,
	moderation: Moderation,

	flags: { [string]: boolean },      -- marcadores diversos (ex.: "seen_spin_intro")
}
```

### 3.2 Valores padrão (perfil novo)

```lua
-- src/shared/Config/DefaultProfile.luau
{
	schemaVersion = 1,
	createdAt = <agora>,
	lastLoginAt = <agora>,
	lastSaveAt = 0,

	tutorialDone = false,
	tutorialStep = 0,

	coins = 0,
	gems = 0,

	cards = { owned = {} },            -- as 4 cartas iniciais são dadas no tutorial, cada uma ao completar o seu desafio (F6)

	cosmetics = {
		owned = {},
		equipped = { weapons = {}, melee = nil, body = nil, head = nil, victoryEffect = nil, emotes = {} },
	},

	loadout = { lastCard = nil, lastPrimaryByPhase = {}, lastSecondary = nil },

	settings = {
		sensitivity = { touch = 1.0, mouse = 1.0, gamepad = 1.0, scopedMultiplier = 0.8 },
		crosshair = { shape = "cross", color = "#FFFFFF", size = 4, thickness = 2, gap = 3, outline = true, outlineOpacity = 0.6 },
		autoFire = true,
		aimAssist = true,
		enemyOutlineColor = "red",
		uiScale = 1.0,
		reduceEffects = false,
		audio = { master = 1, sfx = 1, music = 0.6, voice = 1 },
		mobileLayout = nil,
		voicePromptSeen = false,
	},

	rank = { points = 0, matchesPlayed = 0, peakPoints = 0, seasonId = 1 },

	stats = {
		matchesPlayed = 0, matchesWon = 0, podiums = 0,
		roundsPlayed = 0, roundsWon = 0,
		kills = 0, deaths = 0, damageDealt = 0,
		viradasWon = 0, soloRoundsWon = 0,
		killsByWeapon = {},
	},

	social = { praisesReceived = 0, equippedTitle = nil, recentPartners = {} },
	daily = { lastFirstWinDay = nil, lastFreeSpinDay = nil, loginStreak = 0, lastLoginDay = nil },
	moderation = { warnings = 0, lastWarningAt = nil },
	flags = {},
}
```

### 3.3 O que NÃO vai no perfil

| Dado | Por quê | Onde fica |
|---|---|---|
| Elo exibido (Bronze, Prata…) | é calculado a partir de `rank.points` | `RankConfig.luau` |
| Elo ADM | depende só do UserId | `RankConfig.AdminUserIds` |
| Vidas, rodada, arma e carta da partida atual | estado temporário | memória do servidor de partida |
| Dupla fixa atual | só vale durante a sessão | MemoryStore / dados de teleporte |
| Preços, nomes, raridades de itens | são do catálogo, mudam com atualizações | `ShopCatalog.luau`, `CardConfig.luau` |
| Recibos de compras em Robux | precisam de chave própria para não processar duas vezes | `PurchaseReceipts_v1` |
| Dados pessoais (nome real, e-mail, idade) | o jogo não coleta | — |

---

## 4. Regras de integridade (validadas pelo servidor) `[DECIDIDO]`

| Regra | Validação |
|---|---|
| Moedas | nunca negativas; só mudam pelo `EconomyService` |
| Uma carta por tecla | ao adicionar carta, conferir a tecla no `CardConfig`; recusar se já houver carta dessa tecla |
| Skin equipada | só pode equipar skin que está em `cosmetics.owned` e que pertence àquela arma/slot |
| Emotes | no máximo 4 equipados |
| Configurações | cada número é limitado ao intervalo do tipo (ex.: sensibilidade 0.1 a 5.0); cor da retícula precisa ser hex válido |
| Pontos de elo | nunca negativos; só mudam pelo `RankService` ao fim de partida válida |
| `recentPartners` | no máximo 10, mais recentes primeiro |
| `killsByWeapon` | só IDs que existem no `WeaponConfig` |

O cliente nunca envia o perfil inteiro. Ele envia **pedidos** ("equipar skin X na arma Y", "salvar retícula com estes valores"), e o servidor valida e aplica.

---

## 5. Ciclo de vida do perfil

### 5.1 Carregar
1. Jogador entra em qualquer place (Tutorial, Lobby ou Partida).
2. Servidor tenta abrir o perfil com trava de sessão.
   - Se outro servidor ainda tem a trava (ex.: teleporte em andamento), espera e tenta de novo até ~10 s.
   - Se a trava estiver velha (servidor anterior caiu, mais de 5 min sem atualizar), assume a trava.
3. Aplica migrações se `schemaVersion` for antigo (seção 7).
4. Completa campos ausentes com os padrões.
5. Envia ao cliente a parte que ele precisa (cópia somente leitura).
6. Se falhar de vez, o jogador é avisado e mandado de volta, **sem** criar perfil vazio por cima (isso apagaria o progresso).

### 5.2 Salvar
- **Automático:** a cada 2 minutos. `[PROPOSTA]`
- **Momentos importantes:** imediatamente após compra, fim de partida (elo e moedas) e fim do tutorial.
- **Ao sair:** quando o jogador sai ou é teleportado.
- **Ao fechar o servidor:** salvar todos os perfis abertos antes de desligar.
- Em erro, repetir com espera crescente (1 s, 2 s, 4 s, até 5 tentativas).

### 5.3 Teleporte entre places
- Antes de teleportar, o servidor de origem **salva e libera a trava**.
- O servidor de destino carrega normalmente (passo 5.1).
- Dados da partida (quem é dupla de quem, faixa de nível) vão pelo `MatchHandoff` no MemoryStore, **não** pelos dados de teleporte enviados pelo cliente, que podem ser adulterados.
- Na volta da partida para o lobby, o mesmo vale: "entrar direto na fila" e "dupla fixa com X" vão pelo `LobbyHandoff` no MemoryStore (F5).

### 5.4 Biblioteca
Usar uma biblioteca madura de perfis com trava de sessão em vez de escrever do zero. `[DECIDIDO]`

- Biblioteca: **ProfileStore** oficial (loleris), copiada sem alterações em `vendor/ProfileStore/` com o commit fixado em `ORIGEM.md`. O Wally não tem o pacote oficial, só cópias de terceiros.
- O jogo só usa a biblioteca pelo `src/common/server/Data/ProfileStoreAdapter.luau`.

---

## 6. Compras com Robux `[DECIDIDO]`

1. Roblox chama o `ProcessReceipt` do servidor.
2. O servidor procura o `PurchaseId` em `PurchaseReceipts_v1`.
   - Já existe → responde "concedido" sem dar o item de novo.
3. Se não existe: carrega o perfil (precisa estar aberto neste servidor), aplica o item, **salva o perfil**, grava o recibo, e só então responde "concedido".
4. Qualquer falha antes de terminar → responde "ainda não processado"; o Roblox tenta de novo mais tarde.

Nunca dar item de Robux antes de salvar. Nunca responder "concedido" sem ter salvo.

---

## 7. Migrações

- Arquivo `src/common/server/Data/Migrations.luau` com uma função por versão: `[1] = function(profile) ... return profile end` leva da versão 1 para a 2, e assim por diante.
- Ao carregar, aplicar em sequência até a versão atual.
- Toda migração é **testada** com um perfil de exemplo da versão anterior (seção 10).
- Exemplos de quando migrar: renomear campo, mudar o formato de um campo, separar um campo em dois. Adicionar um campo novo com padrão **não** precisa de migração (o passo 5.1.4 completa).

---

## 8. Ranking

- Ao fim de cada partida válida, o `RankService` atualiza `rank.points` no perfil **e** escreve o valor no `RankLeaderboard_v1`.
- O lobby lê os 100 primeiros a cada 5 minutos (não a cada abertura de tela) para não estourar limites de requisição.
- O elo ADM não aparece no ranking (ou aparece fixo no topo com o selo ADM). `[ABERTO]`

---

## 9. Privacidade e pedidos de exclusão `[DECIDIDO]`

- O jogo não coleta nome real, e-mail, idade ou localização.
- O Roblox envia pedidos de exclusão de dados (direito ao esquecimento). O jogo precisa de um procedimento para apagar o perfil (`PlayerProfile_v1`), as entradas nos rankings e os recibos daquele UserId.
- Fase F11 (lançamento) inclui configurar esse procedimento.

---

## 10. Testes obrigatórios dos dados

| Teste | Resultado esperado |
|---|---|
| Perfil novo | Criado com todos os padrões; tutorial pendente |
| Sair e voltar | Tudo igual ao que estava |
| Teleporte Lobby → Partida → Lobby | Moedas e elo da partida aparecem no lobby; nada duplicado |
| Fechar o servidor com jogadores dentro | Ninguém perde progresso |
| Abrir o mesmo perfil em dois servidores | O segundo espera ou assume a trava velha; nunca dois abertos |
| Compra em Robux repetida pelo Roblox | Item dado uma vez só |
| Perfil da versão anterior | Migra sem perder dados |
| Cliente envia valor fora do intervalo | Servidor recusa ou limita |
| Comprar segunda carta da mesma tecla | Servidor recusa |
| Falha simulada do DataStore | Repete; jogador avisado se falhar de vez; nada sobrescrito |

---

## 11. Em aberto

1. Segunda moeda (`gems`): existe? Comprada com Robux?
2. Haverá temporadas de elo (reset periódico)?
3. Elo ADM aparece no ranking?
4. Guardar histórico das últimas partidas no perfil (ex.: últimas 10)?
