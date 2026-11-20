# Bots de preenchimento — como funcionam, como desligar e como remover

> **Temporário.** Os bots existem porque, no começo, quase não há jogadores na fila. Quando o jogo tiver gente suficiente, eles devem ser **desligados** (1 linha) e, depois, **removidos** (checklist abaixo).
>
> **Para o Claude Code:** este documento é lido antes de qualquer tarefa (vínculo no `CLAUDE.md` e no `docs/FASES.md`). Se o dono do projeto pedir para "tirar", "desligar" ou "remover os bots", siga a seção 4 ou 5 daqui, nessa ordem, sem inventar outro caminho.

Decidido pelo dono do projeto depois da F10 (antes do beta fechado). Regras de jogo no `GDD.md` (seções 4.2, 6.2 e 9.2); decisões técnicas no fim do GDD ("Bots de preenchimento").

---

## 1. O que o jogador vê

- **Na fila:** ninguém espera mais de **35 s**. Aos 10 s de espera "entra" o primeiro bot na contagem ("Procurando partida… 2/7"), e a contagem sobe aos poucos até a sala cheia, quando a partida sai.
- **Cada bot é uma vaga vazia.** Na fila ele só existe como número na tela. Se um jogador de verdade chegar, ele fica com a vaga; o servidor da partida só cria os bots que faltam na hora de começar (quem não chegou da fila também vira bot).
- **Na partida:** a sala é completada até **16** (8 duplas, duelo nas 4 ilhas). Os bots parecem jogadores: nome de jogador, elo no placar, abates, corpo com cores sorteadas, sem a marca "BOT".
- **Os bots jogam como um jogador ruim** (pensando em quem joga no celular):
  - andam pelo mapa procurando o inimigo (depois de 12 s sem achar ninguém, vão atrás dele, como quem ouve os tiros), voltam para dentro da zona, pulam quando travam;
  - veem com campo de visão (parede e Nuvem escondem); percebem quem atira neles;
  - demoram ~1 s para reagir, a mira segue atrasada e com erro grande, atiram em rajadas curtas a 60% da cadência e com 60% do dano, às vezes ficam parados no meio da troca de tiros;
  - usam a arma da rodada (primária e pistola sorteadas), recarregam, sacam a pistola, usam o corpo a corpo colado;
  - usam a carta básica sorteada (Nuvem, Impulso ou Tremor) e o Renascer a partir da 4ª rodada.
  - Duelo só entre bots é jogado de verdade (quem está no mirante assiste), com mira e dano melhores bot contra bot para acabar mais rápido (no teste no Studio, a maioria dos duelos de bots acabou em ~60 s).
- **Recompensas:** moedas e estatísticas normais; **o elo não muda** em partida com bot. A tela final mostra "Partida casual: o elo não muda".

## 2. Onde ajustar (sem mexer no código)

Tudo em `src/shared/Config/BotConfig.luau` (valores `[PROPOSTA]`):

| O quê | Campo |
|---|---|
| Ligar / desligar tudo | `Enabled` |
| Espera máxima na fila | `Queue.StartAfterSeconds` (35) |
| Como a contagem sobe | `Queue.Ramp` (fração da sala por segundo de espera) |
| Tamanho da sala | `Queue.FillTo` e `Match.FillTo` (16) |
| Completar também sem fila (Studio, teleporte de teste) | `Match.FillWithoutHandoff` |
| Elo em partida com bot | `Match.AffectsRank` (false = elo parado) |
| Mostrar "BOT" no placar | `Disguise = false` |
| Dificuldade | `Skill` (reação, erro de mira, cadência, dano, rajadas, visão) |
| Movimento | `Movement` (velocidade, distância preferida por arma, strafe, `HuntAfterSeconds`) |
| Uso das cartas | `Cards` (chance por segundo) |

Nomes dos bots: `Strings.Bots`. Cores do corpo: `Theme.Bots`.

## 3. Onde está o código

Tudo o que mexe com bots tem a marca **`[BOTS]`** num comentário. Para achar: `grep -rn "\[BOTS\]" src docs`.

| Arquivo | Papel |
|---|---|
| `src/shared/Config/BotConfig.luau` | números e chave geral |
| `src/shared/Bots/BotRules.luau` | contas puras: contagem da fila, bots que faltam, erro de mira, nomes, armas e cartas |
| `src/match/server/Bots/init.luau` | serviço dos bots na partida (identidade, corpo, cérebro, abates) |
| `src/match/server/Bots/BotAgent.luau` | cérebro: visão, caminho, troca de tiros, cartas |
| `src/match/server/Bots/BotBody.luau` | corpo (cores sorteadas) e animações |
| `src/tests/specs/Bots.spec.luau` | testes automáticos |
| Ganchos em arquivos existentes | ver a seção 5, passo 3 |

## 4. Desligar (rápido, reversível)

1. Em `src/shared/Config/BotConfig.luau`, troque `Enabled = true` por `Enabled = false`.
2. Publique **Lobby** e **Partida** (os dois leem o `BotConfig`).

Pronto: a fila volta às regras do GDD 6.2 (7 → espera até 16; a partir de 4 depois de 20 s), a partida não cria bots, o elo volta a contar e o jogador ímpar volta a jogar 1v2. Os testes de `Bots.spec` continuam passando (eles ligam os bots só dentro do teste).

> Partidas que já estavam montadas quando você publicou terminam como começaram.

## 5. Remover de vez

Faça depois de desligar e ver que o jogo vai bem sem eles. Ordem:

1. **Apagar** os arquivos novos:
   - `src/shared/Config/BotConfig.luau`
   - `src/shared/Bots/` (pasta inteira)
   - `src/match/server/Bots/` (pasta inteira)
   - `src/tests/specs/Bots.spec.luau`
2. **Achar os ganchos:** `grep -rn "\[BOTS\]" src`. Cada um está num comentário e é pequeno.
3. **Desfazer cada gancho** (o que fazer em cada arquivo):

| Arquivo | O que tirar |
|---|---|
| `src/shared/Queue/QueueRules.luau` | `require` do `BotRules`; campo `bots` de `Params`; `fillBots` de `Plan` e de `makePlan`; o 2º parâmetro `withBots` de `QueueRules.params`; em `evaluatePool`, tudo depois de `local plan, status = evaluateReal(...)` vira só `return plan, status` (dá para juntar `evaluateReal` de volta em `evaluatePool`); em `evaluateReal`, `forceMin` volta a ser `p.flexibleMin` |
| `src/lobby/server/QueueService.luau` | `require` do `BotConfig`; `QueueRules.params(Env.IsDev)` sem o 2º argumento; `fillBots` no `MatchHandoff`; `botNote` no `print` |
| `src/common/server/Matchmaking/Handoff.luau` | campo `fillBots` (tipo e leitura) |
| `src/match/server/MatchService.luau` | `require` de `BotConfig`, `BotRules` e `script.Parent.Bots`; campos `ai` e `rankTier` de `Member` (e em `makeMember`); `aiCounter`; `botFillActive`, `fillWithBots`, `botPrep` (e as chamadas); os ramos `if m.ai` / `member.ai` em `snapshot`, `toBase`, `openPrep`, `closePrepAndArm`, `resetMatch`, `beginRewards`; `BotService.reset()` e `BotService.onKill(...)`; voltar `(m.player or m.ai)` para `m.player`, `(not m.isBot or m.ai)` para `not m.isBot`, e os mínimos (`needed`, `minArrived`) para os valores antigos (`minPlayers()`, `2` e `MatchConfig.Start.MinArrived`) |
| `src/match/server/MatchRewards.luau` | parâmetro `casual` e `isCasual`; `applyMatch` volta a ser chamado sempre que há colocação; campo `casual` do `RewardsData` |
| `src/combat/server/CardService.luau` | `NpcRenascer`, `npcRenascers`, `finishNpcRenascer`, `useNpcRenascer`, `CardService.castForNpc`; o ramo `player == nil` em `useRenascer`, no guarda de queda e no `onKnocked`; o salto do servidor em `useImpulso`; `table.clear(npcRenascers)` no `clearWorld`. `emit`/`casterOf` aceitando `nil` podem ficar (não atrapalham) |
| `src/combat/server/CharacterService.luau` | `BotSpawnOptions` e o 5º parâmetro de `spawnBot` (volta a ser sempre ancorado, corpo base) |
| `src/shared/Cards/CardTypes.luau` | `caster` pode voltar para `Player?` |
| `src/combat/client/Captions.luau` | o ramo `caster:IsA("Model")` (pode ficar: sem bots, nunca chega um Model) |
| `src/shared/Match/MatchTypes.luau` | `rankTier` e `kills` de `MemberView`; `casual` de `RewardsData` |
| `src/match/client/Scoreboard.luau` | `rankOf`/`killsOf` sem o recurso `member.rankTier` / `member.kills` (pode ficar) |
| `src/match/client/EndScreen.luau` | volta a mostrar só `R.Private` |
| `src/match/client/MatchClient.luau` e `Minimap.luau` | `partnerModel` pode ficar (também acha o parceiro jogador); ou volte o minimapa para `partnerPlayer().Character` |
| `src/shared/Config/Strings.luau` | `Strings.Bots` e `Rewards.Casual` |
| `src/shared/Config/Theme.luau` | `Theme.Bots` |

4. **Documentos:** apagar este arquivo (`docs/BOTS.md`), a linha dele no `CLAUDE.md` ("Leia antes de qualquer tarefa") e no `docs/FASES.md` (seção "Bots de preenchimento" e a linha da tabela de pendências); no `GDD.md`, voltar as seções 4.2, 6.2 e 9.2 para "sem bot" e marcar a decisão técnica "Bots de preenchimento" como removida.
5. **Conferir:** `powershell -ExecutionPolicy Bypass -File scripts/check.ps1` sem erro novo, `grep -rn "\[BOTS\]\|BotConfig\|BotService\|BotRules" src` vazio, testes automáticos passando (`require(game.ServerStorage.Tests.Runner).run()`), e uma partida de teste com 4 contas.

## 6. Como testar

- **Testes automáticos** (Studio, barra de comandos): `require(game.ServerStorage.Tests.Runner).run()` — veja `Bots.spec`.
- **Partida no Studio:** abra o place **Partida** com `rojo serve match.project.json` conectado (porta 34874) e dê Play sozinho. A partida começa 20 s depois (ou **TESTE › PARTIDA › COMEÇAR AGORA**) com você + 15 bots. Dá para ver os outros duelos do mirante quando o seu acabar.
- **Fila no jogo publicado (DEV_):** entre no Lobby sozinho e aperte JOGAR: a contagem sobe com os bots e a partida sai em até 35 s.
