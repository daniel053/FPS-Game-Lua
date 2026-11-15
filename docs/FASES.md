# [NOME DO JOGO] — Fases de desenvolvimento

> **Versão:** 0.1
> **Documentos irmãos:** `docs/GDD.md`, `docs/ESTILO-E-TELAS.md`, `docs/DADOS-JOGADOR.md`

---

## 0. Como usar este documento (para o Claude Code)

- O jogo é construído em **12 fases**, uma de cada vez, nesta ordem.
- **Não começar uma fase antes da anterior ser aceita** pelo dono do projeto.
- Cada fase tem: objetivo, dependências, tarefas, entregáveis, critérios de aceite, como testar e o que fica fora.
- Se uma fase depende de um item `[ABERTO]` dos documentos, **parar e perguntar** antes de implementar aquele item (o resto da fase pode seguir).
- Ao terminar uma fase:
  1. rodar todos os testes da fase;
  2. escrever um resumo curto do que foi feito e do que ficou pendente;
  3. atualizar os documentos com qualquer decisão nova;
  4. marcar a fase como concluída na tabela da seção 1;
  5. pedir ao dono do projeto para testar.

### Regras que valem em toda fase

- Funciona no **celular e no PC** desde a primeira versão de cada tela ou controle. Não deixar "mobile para depois".
- Primeira pessoa sempre.
- Números em `Config`, cores em `Theme`, textos em `Strings`.
- Servidor é a autoridade.
- Visual "cinza" (blocos simples) é aceito até a F10. Lógica e controles precisam estar certos antes da arte.

---

## 1. Visão geral

| Fase | Nome | Resultado | Status |
|---|---|---|---|
| F0 | Base do projeto | Projeto organizado, 3 places, configs vazias | ✅ |
| F1 | Dados do jogador | Perfil salvo com segurança | ✅ |
| F2 | Combate | Atirar e derrubar com as 18 armas + corpo a corpo | ✅ |
| F3 | Loop da partida | Partida completa em arenas cinza | ✅ |
| F4 | Cartas | 4 cartas funcionando | ✅ |
| ⭐ | **Marco: primeiro jogável** | Teste interno com amigos | ✅ |
| F5 | Lobby e fila | Entrar na fila e cair na partida com amigos | ✅ |
| F6 | Tutorial | Primeira entrada guiada | ✅ |
| F7 | Interface final | Telas T1–T6 no estilo definitivo | ✅ |
| F8 | Social e voz | Dupla se comunica e continua junta | ✅ |
| F9 | Elo, economia e arsenal | Progressão completa | ✅ |
| F10 | Mapas e arte | 4 ilhas, mirante, personagem, armas | ☐ |
| ⭐ | **Marco: beta fechado** | Teste com jogadores de fora | ☐ |
| F11 | Robux e lançamento | Jogo público | ☐ |

Por que essa ordem:
- **Dados (F1) antes de tudo:** tutorial, configurações, elo e moedas dependem do perfil.
- **Combate e partida (F2–F4) antes do lobby:** o mais importante é o jogo ser divertido; dá para testar a partida inteira dentro de um servidor só, sem fila.
- **Interface final (F7) e arte (F10) depois:** mudar visual é barato; mudar regra depois de pintar tudo é caro.

---

## F0 · Base do projeto

**Objetivo:** projeto organizado e pronto para crescer.

**Depende de:** nada.

**Tarefas:**
- Configurar Rojo, Wally, Selene, StyLua e `--!strict`.
- Criar a experiência com 3 places: Tutorial, Lobby, Match.
- Estrutura de pastas do GDD seção 16.3.
- Módulos vazios: `Theme.luau`, `Strings.luau` e todos os `Config/*.luau` (com os valores dos documentos já preenchidos onde existirem).
- Câmera travada em primeira pessoa nos 3 places.
- Teleporte simples entre os places (botões de teste).
- Separar ambiente de teste (`DEV_`) do real.

**Entregáveis:** repositório organizado; README de como rodar.

**Critérios de aceite:**
- Projeto sincroniza do editor para o Studio.
- Câmera não sai da primeira pessoa em nenhum place.
- Teleporte entre os 3 places funciona.
- Selene e StyLua sem erros.

**Fora:** qualquer gameplay.

---

## F1 · Dados do jogador

**Objetivo:** perfil salvo com segurança, conforme `DADOS-JOGADOR.md`.

**Depende de:** F0.

**Tarefas:**
- Tipos `PlayerData.luau` e `DefaultProfile.luau`.
- `DataService` com trava de sessão (biblioteca de perfis), salvamento automático, ao sair e ao fechar servidor.
- Migrações (estrutura pronta, mesmo sem nenhuma ainda).
- Validações da seção 4 de `DADOS-JOGADOR.md`.
- Cópia somente leitura para o cliente, com atualização quando muda.
- Pedidos do cliente para salvar configurações (retícula, sensibilidade) com validação.
- Comandos de teste (só em `DEV_`): dar moedas, resetar perfil, ver perfil.

**Critérios de aceite:** todos os testes da seção 10 de `DADOS-JOGADOR.md` passam (exceto compras em Robux, que ficam para a F11).

**Fora:** telas de configurações bonitas (F7), elo e economia (F9).

---

## F2 · Combate

**Objetivo:** atirar, acertar e derrubar, com sensação boa no celular e no PC.

**Depende de:** F0, F1 (para ler sensibilidade e retícula).

**Tarefas:**
- Personagem base (blocos simples), hitbox única, sem região de cabeça.
- HP 100 + escudo 50, regeneração do escudo.
- **18 armas + corpo a corpo** com os números do GDD 7.2, todas em `WeaponConfig`.
- Primária, secundária e corpo a corpo; troca de arma; recarga; modo alternativo/mira.
- Tiro instantâneo validado no servidor (cadência, munição, distância, linha de visão).
- Perda de dano com a distância, recuo simples, espalhamento.
- Controles do GDD 7.2.6: toque, mouse e controle; tiro automático por tipo de arma; assistência de mira.
- Contornos do GDD 7.6: inimigo vermelho só visível; parceiro só com corpo inteiro escondido. *(Revisto na F6: contorno e barra vermelhos no inimigo, barra verde e silhueta verde no aliado.)*
- Feedback do GDD 7.7: sem sangue, número de dano, marcador de acerto, aviso `N KILL`, sons provisórios.
- Retícula e sensibilidade lidas do perfil.
- Arena de teste cinza com alvos e coberturas.

**Critérios de aceite:**
- Dois jogadores se derrubam com cada uma das 18 armas.
- Nenhuma arma derruba quem tem vida cheia com um tiro (teste automático com os números da config).
- Tempo para derrubar de cada arma bate com a tabela (±10%).
- Contorno do parceiro aparece só com o corpo inteiro atrás da parede.
- Tudo jogável num celular de verdade.
- Exploit simples (cliente atirando mais rápido que a cadência) é bloqueado.

**Fora:** escolha de arma por fase (F3), cartas (F4), arte das armas (F10).

---

## F3 · Loop da partida

**Objetivo:** uma partida completa, do início ao campeão, dentro de um servidor.

**Depende de:** F2.

**Tarefas:**
- Servidor de partida com **mirante** (ilha central plana) e **4 ilhas cinza** em volta e abaixo.
- Máquina de estados do GDD 4.1.
- Formação de duplas (sem fila ainda: quem estiver no servidor), jogador ímpar joga 1v2.
- Sorteio de confrontos, folga, sorteio de ilha.
- Rodadas, vidas, zona, desempate por HP + escudo.
- **Rodada da Virada** (GDD 4.5).
- **Fases de armas por rodada** (GDD 7.2.2).
- **Modal de preparação** em versão simples (GDD 4.10; visual final na F7): etapas carta (só placeholder até a F4) e armas, parceiro em tempo real, repetir última, confirmar.
- Mirante: assistir de cima, barreira invisível, sem interferência; telhados transparentes só para quem está no mirante.
- Espectar o parceiro em primeira pessoa ao morrer.
- Eliminação, final, campeão.
- Tela de fim de partida com as escolhas do GDD 4.8 (botões funcionam, mas "Nova partida" só volta ao lobby vazio até a F5).
- Casos especiais do GDD 4.9 (saída, AFK).
- Comandos de teste: pular rodada, tirar vida de uma dupla, forçar Virada.

**Critérios de aceite:**
- Partida completa com 4, 7, 8 e 16 jogadores (teste com vários clientes no Studio).
- Armas certas em cada rodada; primária só a partir da 3ª.
- Virada acontece uma vez só, no momento certo, com +1 vida limitado a 5.
- Jogador ímpar joga sozinho, sem bônus.
- Folga gira e nunca repete antes de todos.
- Quem está no mirante enxerga os 4 duelos e não consegue interferir.

**Fora:** fila e lobby real (F5), elo e moedas (F9).

---

## F4 · Cartas

**Objetivo:** as 4 cartas da primeira versão funcionando.

**Depende de:** F3.

**Tarefas:**
- `CardConfig` com Nuvem (C), Impulso (Q), Tremor (E), Renascer (X): números do GDD 8.4.
- Escolha de carta na 1ª rodada (15 s), sem escolha = sem carta, travada nas rodadas seguintes.
- Ult liberada para todos a partir da 4ª rodada, 1 uso por rodada.
- Validação no servidor (cargas, recarga, alcance).
- Controles: teclas C/Q/E/X no PC, botões fixos no celular, botões de ombro no controle.
- Efeitos visuais provisórios (brilho permitido só nos efeitos).
- Mirante: telhados e efeitos legíveis de cima.
- Regra de coleção (uma carta por tecla) já validada no servidor, mesmo sem loja.
- Comando de teste para dar as 4 cartas (até o tutorial existir).

**Critérios de aceite:**
- Cada carta faz exatamente o descrito no GDD.
- Ult travada até a 4ª rodada.
- Funciona no toque, teclado e controle.
- Cliente não consegue usar carta em recarga ou que não escolheu.

**Fora:** Girar e raridades (F9 e evoluções futuras), arte final dos efeitos (F10).

---

## ⭐ Marco: primeiro jogável

Antes de seguir:
- Jogar várias partidas com amigos (celular e PC misturados).
- Anotar: duração das partidas, armas fortes ou fracas demais, cartas confusas, controles ruins no celular.
- Ajustar números nas configs.
- Atualizar o GDD com o que mudar.

Só seguir para a F5 quando a partida for divertida em blocos cinza.

---

## F5 · Lobby e fila

**Objetivo:** entrar no lobby, entrar na fila (sozinho ou com amigo) e cair numa partida.

**Depende de:** F3, F4.

**Tarefas:**
- Lobby funcional (visual simples) com botão Jogar, grupo de 2, convidar amigos.
- Fila compartilhada entre servidores de lobby (MemoryStore).
- Regras do GDD 6.2: começa com 7, espera até 16 por 15 s, flexível a partir de 4 após 20 s (decidido na F5; era 60 s).
- Separação por faixa (GDD 6.3), juntando as faixas quando não há gente.
- Dupla fixa entra junta e cai junta.
- Criação de servidor reservado e teleporte do grupo; `MatchHandoff` com a composição.
- Pós-partida (GDD 4.8): assistir, nova partida, "seguir com [nome]?".
- Servidor de partida que recebe gente faltando (alguém não chegou) segue com quem chegou.

**Critérios de aceite:**
- Duas contas amigas entram na fila juntas e caem na mesma partida, na mesma dupla, várias vezes seguidas.
- Com 3 contas na fila, a partida começa com o que tiver: após 20 s em produção (mínimo 4); após 5 s em teste (mínimo 2).
- Ninguém fica preso em teleporte; dados não duplicam.

**Fora:** visual final do lobby (F7), ranking (F9).

---

## F6 · Tutorial

**Objetivo:** primeira entrada guiada, uma única vez (GDD seção 5).

**Depende de:** F2, F4, F5.

**Tarefas:**
- Place Tutorial com as 8 etapas do GDD 5.2.
- Entrega das 4 cartas ao concluir cada etapa de carta.
- Tela de voz (informativa; teste de microfone se disponível).
- Configuração de sensibilidade (incluindo mira aberta) e retícula com prévia, salvas no perfil.
- Retomar da etapa em que parou (`tutorialStep`).
- Ao terminar: `tutorialDone = true`, teleporte ao lobby, nunca mais volta.
- Jogador antigo (com `tutorialDone`) nunca cai no tutorial.

**Critérios de aceite:**
- Conta nova: cai no tutorial, termina em 3 a 5 minutos, sai com as 4 cartas e configurações salvas.
- Sair no meio e voltar: retoma da etapa.
- Funciona inteiro no celular.

**Fora:** visual final (F7), arte (F10).

---

## F7 · Interface final

**Objetivo:** todas as telas no estilo definitivo do `ESTILO-E-TELAS.md`.

**Depende de:** F3 a F6.

**Tarefas:**
- `Theme.luau` completo (cores, raridades, fontes, tamanhos).
- Componentes reutilizáveis: botão principal e secundário, aba, cartão de item, chip de tecla, modal, barras, aviso de abate.
- Telas T1 (Cartas), T2 (Modal de preparação), T3 (Lobby), T4 (tela de mapas), T5 (Arsenal, sem loja ainda), T6 (HUD).
- PC: botões de toque escondidos, dicas fixas B / P / Tab; painel B (habilidades); painel P (configurações sem pausar).
- Celular: layout de botões editável (salvo em `settings.mobileLayout`).
- Placar Tab substituindo a lista padrão do Roblox.
- Acessibilidade da seção 5 do guia de estilo.
- Logo provisória.

**Critérios de aceite:**
- Checklist da seção 6 do guia de estilo passa em todas as telas.
- Nenhum modal com fundo preto opaco.
- Testado em celular pequeno, celular grande, tablet e PC.

**Fora:** arte 3D (F10).

---

## F8 · Social e voz

**Objetivo:** a dupla se comunica e continua junta (GDD seção 12).

**Depende de:** F5, F7.

**Tarefas:**
- Pings com roda (toque) e tecla (PC).
- Frases prontas.
- Emotes no mirante e no fim da rodada.
- Chat de texto do Roblox em canal da dupla.
- Voz só da dupla durante a rodada; proximidade no mirante (verificar viabilidade da API de áudio; se não der, documentar e perguntar).
- Botões "Adicionar amigo" e "Jogar de novo juntos" na tela final.
- Elogio ao parceiro; `recentPartners` no perfil.
- Denunciar sempre acessível.

**Critérios de aceite:**
- Dupla sem voz e sem texto consegue combinar estratégia só com pings e frases.
- Voz da dupla não vaza para a dupla adversária durante a rodada.

---

## F9 · Elo, economia e arsenal

**Objetivo:** progressão completa (GDD seções 9, 10, 11 e 8.9).

**Depende de:** F1, F5, F7.

**Tarefas:**
- `RankService`: pontos por colocação, proteção das 10 primeiras partidas, perdas dobradas a partir de Mestre, faixas por nível.
- Elo ADM pelo UserId.
- Ícone de elo no lobby, placar e fim de partida; ranking global (`RankLeaderboard_v1`).
- `EconomyService`: moedas por rodada, abate, colocação, primeira vitória do dia, bônus de mesmo parceiro.
- Arsenal (T5) com skins: equipar, comprar com moedas.
- Catálogo inicial de skins (com IDs); raridades na moldura.
- Tela de Cartas (T1) com raridades. **Girar**: implementar conforme a decisão do GDD 8.9 (se ainda estiver `[ABERTO]`, construir só a tela e deixar o botão desativado).
- Partidas privadas não mexem no elo.

**Critérios de aceite:**
- Elo e moedas corretos depois de partidas de teste com colocações diferentes.
- Não é possível comprar ou equipar sem ter / sem saldo (teste de exploit).
- Ranking atualiza sem estourar limites de requisição.

---

## F10 · Mapas e arte

**Objetivo:** o jogo com cara de jogo.

**Depende de:** marco do primeiro jogável e F7.

**Tarefas:**
- Plantas baixas aprovadas pelo dono do projeto antes de construir cada ilha.
- 4 ilhas de duelo: Praça, Fábrica, Porto, Torre (GDD seção 15), com zonas nomeadas e pontos de escudo.
- Mirante final (plano, sem torre) e céu/nuvens.
- Lobby 3D final.
- Braços e armas em primeira pessoa (o personagem é o avatar do jogador desde a F6, GDD 3.2).
- Modelos das 18 armas + corpo a corpo.
- Efeitos finais das 4 cartas (únicos com brilho, junto com a carta Celestial).
- Sons finais (tiro macio, "crack" de abate) — aprovação do dono do projeto.
- Orçamento de desempenho: 30 fps no celular de referência.

**Critérios de aceite:**
- Cada ilha legível de cima (mirante) e jogável em primeira pessoa.
- Nenhum neon fora das exceções.
- 30 fps estáveis no celular de referência com 16 jogadores.

---

## ⭐ Marco: beta fechado

- Convidar um grupo de jogadores de fora (crianças e adultos, celular e PC).
- Medir: duração média das partidas, taxa de quem termina o tutorial, quantos voltam no dia seguinte, quantos jogam com o mesmo parceiro de novo.
- Ajustar números e corrigir problemas antes do lançamento.

---

## F11 · Robux e lançamento

**Objetivo:** jogo público e preparado para receber dinheiro com segurança.

**Depende de:** beta fechado.

**Tarefas:**
- Produtos em Robux (skins) com `ProcessReceipt` idempotente (`DADOS-JOGADOR.md` seção 6).
- Servidores privados (preço decidido).
- Procedimento de exclusão de dados (`DADOS-JOGADOR.md` seção 9).
- Revisão final contra loot box (GDD 8.9) e contra uso de nomes/arte de outros jogos.
- Classificação de conteúdo da experiência no Roblox (questionário de maturidade).
- Ícone, thumbnails e descrição da página do jogo.
- Monitoramento de erros e de falhas de DataStore.

**Critérios de aceite:**
- Compra repetida pelo Roblox dá o item uma vez só.
- Pedido de exclusão apaga perfil, rankings e recibos do jogador.
- Página do jogo pronta.

---

## Pendências que bloqueiam fases

| Pendência (documento) | Bloqueia |
|---|---|
| ~~Girar: sorteio ou visualização (GDD 8.9)~~ Respondida na F9: visualização | — |
| ~~Raridade muda poder? (GDD 8.9)~~ Respondida na F9: não | — |
| ~~Segunda moeda (GDD 18, DADOS 11)~~ Respondida na F9: não por enquanto | — |
| ~~Tutorial pode ser pulado? (GDD 18)~~ Respondida na F6: só as configurações | — |
| ~~Plantas do Porto, da Fábrica e da Torre (GDD 15.8)~~ Respondida na F10: aprovadas. ~~Tamanhos~~ respondido na F10: mesmo tamanho | — |
| Preços em Robux (GDD 10.3) | F11 |
