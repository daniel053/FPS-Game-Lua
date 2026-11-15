# [NOME DO JOGO]

Tiro em primeira pessoa no Roblox, duelos 2v2 em formato de torneio. Os documentos de design estão em `docs/`, e o ponto de partida é `docs/FASES.md`.

## O que tem aqui

| Pasta / arquivo | O que é |
|---|---|
| `src/shared/` | Código usado por servidor e cliente nos 3 places: `Config/` (números, `Theme`, `Strings`), `Types`, `Remotes`, `Env` |
| `src/common/` | Código que roda igual nos 3 places (`server/` e `client/`) |
| `src/combat/` | Combate e cartas, usados pela Partida e pelo Tutorial (`server/` e `client/`) |
| `src/lobby/`, `src/tutorial/`, `src/match/` | Código de cada place |
| `src/tests/` | Testes automáticos da lógica (rodam no Studio) |
| `vendor/ProfileStore/` | Biblioteca de perfis com trava de sessão (cópia oficial, ver `ORIGEM.md`) |
| `lobby.project.json`, `tutorial.project.json`, `match.project.json` | Um projeto do Rojo para cada place |
| `rokit.toml` | Versões das ferramentas (Rojo, Wally, Selene, StyLua, luau-lsp) |
| `scripts/check.ps1` | Confere formatação, boas práticas e tipos |

**O Rojo nunca mexe no Workspace** (mapas), na Lighting nem no Terrain. Ele só sincroniza:
- `ReplicatedStorage.Shared` e `ReplicatedStorage.Packages`
- `ServerScriptService.Common`, `ServerScriptService.Combat` (Partida e Tutorial) e `ServerScriptService.Place`
- `ServerStorage.Vendor` (ProfileStore) e `ServerStorage.Tests`
- `StarterPlayer.StarterPlayerScripts.Common`, `.Combat` (Partida e Tutorial) e `.Place`
- as propriedades de câmera do `StarterPlayer` (primeira pessoa travada)

Qualquer outra coisa que você criar à mão nesses serviços é preservada.

## Preparar um computador novo (uma vez)

1. Instale o [Rokit](https://github.com/rojo-rbx/rokit) e, na pasta do projeto, rode `rokit install`.
2. Instale o plugin do Rojo no Studio: `rojo plugin install`. Depois reinicie o Studio.
3. (Opcional) No VS Code, instale as extensões recomendadas (o VS Code oferece sozinho ao abrir a pasta).

## Trabalhar no dia a dia

Cada place tem a sua porta. Abra o place no Studio e rode **só o comando daquele place** no terminal, dentro da pasta do projeto:

| Place | Comando | Porta |
|---|---|---|
| Lobby (place inicial) | `rojo serve lobby.project.json` | 34872 |
| Tutorial | `rojo serve tutorial.project.json` | 34873 |
| Partida | `rojo serve match.project.json` | 34874 |

No Studio: aba **Plugins › Rojo**, confira a porta e clique em **Connect**. A partir daí, cada arquivo salvo na pasta aparece no Studio na hora.

> Nunca use `rojo build` para gerar um place por cima de um place existente: o `Workspace` (onde fica o mapa salvo) não vem do Rojo.

## Mapa salvo no place (Partida)

O mundo da partida (mirante, 4 ilhas e nuvens) é **desenhado em código**, em `src/shared/Maps/`, e fica **salvo no place da Partida**, em `Workspace.MatchWorld`. Assim ele aparece ao abrir o place no Studio.

- **Para mudar um mapa**, mude o código (`Maps/Islands/<Mapa>.luau` e `Maps/Kits/<Mapa>.luau`). O que for mexido à mão dentro de `Workspace.MatchWorld` se perde na próxima montagem.
- **Para atualizar o que está salvo**, com o Rojo conectado e em modo de edição, rode na barra de comandos do Studio e depois salve o place (Ctrl+S):

```lua
local s = game.ReplicatedStorage.Shared:Clone() s.Parent = game.ServerStorage require(s.Maps.WorldBuilder).bake() s:Destroy()
```

(A cópia do `Shared` serve para o Studio carregar o código novo, e não o que ele já tinha na memória.)

- **Se esquecer**, nada quebra: ao iniciar, o servidor compara o mundo salvo com o que o código monta. Se estiverem diferentes, ele monta de novo e avisa no Output; o teste "o mundo salvo no place da Partida está em dia com o código" também acusa.

## Conferir o código antes de um commit

```bash
powershell -ExecutionPolicy Bypass -File scripts/check.ps1
```

Para corrigir a formatação automaticamente:

```bash
powershell -ExecutionPolicy Bypass -File scripts/check.ps1 -Fix
```

## Testes automáticos

Com o Rojo conectado, na barra de comandos do Studio (Visualizar › Barra de comandos):

```lua
require(game.ServerStorage.Tests.Runner).run()
```

O resultado aparece no Output (✓ passou, ✗ falhou).

No modo de edição o Studio guarda os módulos já carregados: depois de mudar o código, rode de novo com um Play (barra de comandos no lado do servidor) ou reabra o place, senão o resultado é o da versão antiga.

## Salvar dados no Studio

Para o Studio salvar perfis de verdade (em `DEV_PlayerProfile_v1`): **Configurações do jogo › Segurança › Permitir acesso do Studio aos serviços de API**. Sem isso, o Output avisa que nada será salvo.

> Mudou um arquivo `*.project.json`? Pare o `rojo serve` (Ctrl+C), rode de novo e clique em **Connect** no Studio. O Rojo não recarrega o arquivo de projeto sozinho.

## Ambiente de teste (`DEV_`)

`src/shared/Env.luau` decide o ambiente:
- **Teste (`DEV_`)**: Studio, a experiência de teste atual e qualquer cópia. Os DataStores ganham o prefixo `DEV_`, e o painel **TESTE** aparece na tela.
- **Real**: só a experiência de produção configurada em `src/shared/Config/PlaceConfig.luau` (criada antes do lançamento, na F11).

### Painel de teleporte de teste

| Dispositivo | Como abrir |
|---|---|
| Celular | botão **TESTE**, no canto superior esquerdo |
| PC | tecla **T** (com o painel aberto, o mouse fica livre) |
| Controle | direcional para **cima** |

O teleporte **não funciona dentro do Studio**, só no jogo publicado (pode ser privado). Os IDs dos places ficam em `PlaceConfig.luau`.

### Painel de dados do jogador (F1)

No mesmo painel **TESTE**, seção **DADOS DO JOGADOR**:

| Botão | O que testa |
|---|---|
| **+100 MOEDAS** | dar moedas pelo servidor; o número na tela atualiza sozinho (cópia do cliente) |
| **SENSIBILIDADE +0,5** | pedido de configuração válido; deve continuar igual depois de sair e voltar |
| **ENVIAR CONFIG INVÁLIDA** | o servidor tem que recusar e nada muda |
| **VER PERFIL** | resumo na tela e o perfil completo no Output do servidor |
| **RESETAR PERFIL** | volta ao perfil novo (toque duas vezes para confirmar) |

Para simular falha do DataStore: no Studio, selecione o **ServerStorage**, adicione o atributo booleano `DEV_SimulateLoadFailure` marcado e aperte Play. O jogador deve ser expulso com a mensagem de falha, sem perder nada. Apague o atributo depois.

## Testar a comunicação e a voz (F8)

**Uma vez, no place Partida:** depois de atualizar, pare o `rojo serve match.project.json`, rode de novo e clique em **Connect**. O projeto agora grava no place:
- `VoiceChatService.EnableDefaultVoice = false` e `UseAudioApi = Enabled` (o jogo cria a voz só da dupla);
- `TextChatService.ChatVersion = TextChatService` e `CreateDefaultTextChannels = false` (sem chat geral na partida).

Confira no Studio (Explorer › VoiceChatService / TextChatService) e **publique o place Partida**. Nas configurações da experiência no site do Roblox, **Comunicação › Voz** precisa estar ligada.

| Onde | O que fazer |
|---|---|
| **Ping** — PC **Z** (toque curto = rápido; segurar = roda) ou **botão do meio do mouse**; controle **R3**; celular **PING** (toque / segurar) | só na ilha (preparação e combate). Mira num inimigo = "Inimigo aqui"; senão "Vou para cá". Marcador com ícone, nome e distância, no minimapa e na legenda, só para você e o parceiro |
| **Frases** — PC **V**; controle **L3**; celular **FRASES** | 6 frases para o parceiro (legenda + balão em cima de quem falou). A roda também tem EMOTES › e ★ ELOGIAR quando valem |
| **Emotes** — PC **G**; celular **EMOTES** | no mirante e no fim da rodada; andar cancela |
| **Elogiar** — PC **H** ou botão no fim da rodada; tela final | 1 por rodada e 1 no fim; o parceiro vê "[nome] elogiou você ★" |
| **Tela final** | JOGAR DE NOVO JUNTOS, ADICIONAR AMIGO, ELOGIAR, DENUNCIAR |
| **Placar (Tab)** › **DENUNCIAR** | explica a denúncia pelo menu do Roblox e tem BLOQUEAR por jogador |

**Voz e chat só funcionam no jogo publicado**, com contas que têm voz/chat liberados pelo Roblox. Teste dos critérios de aceite (F8):
1. 4 contas (ou pelo menos 3: 2 de uma dupla e 1 da outra) numa partida. Durante a rodada, a dupla se ouve em qualquer distância; a dupla adversária não ouve nada.
2. Quem cai continua ouvindo o parceiro. No mirante, todos se ouvem pela distância (perto = alto, longe = nada).
3. Chat: na ilha, o que você digita aparece só para o parceiro com "[Dupla]"; no mirante, com "[Mirante]" para quem está lá.
4. Sem voz e sem texto: combinar uma jogada só com pings e frases.

## Testar a interface final (F7)

Todas as telas usam os componentes de `src/shared/Ui` (peças básicas) e `src/common/client/Ui` (botões, abas, cartões, modal…), com cores do `Theme` e textos do `Strings`.

| Onde | O que olhar |
|---|---|
| **Lobby** (T3) | logo provisória + LOBBY, moedas e engrenagem no topo; dupla com avatares à esquerda; DUELO EM DUPLA com JOGAR à direita; navegação embaixo (Ranking e Loja "Em breve"); ilhas cinza flutuando ao fundo |
| **Lobby › CARTAS** (T1) | filtros TODAS / tecla C Q E X / raridade (filtro sem carta fica apagado), carrossel em ordem de tecla (arrastar, setas ← →, roda do mouse), selo de raridade, atributos, EQUIPADA, GIRAR desativado |
| **Lobby › MAPAS** (T4) | mirante e as 4 ilhas vistas de cima; tocar numa ilha mostra a descrição |
| **Lobby › ARSENAL** (T5) | todas as armas numa tela, sem abas e sem rolagem, agrupadas por categoria; detalhe com a arma girando, barras, EQUIPAR e a fila de skins embaixo |
| **Partida › preparação** (T2) | modal sobre o mapa, etapas como abas, armas em 3D, barras, parceiro em tempo real, REPETIR ÚLTIMA, CONFIRMAR (Enter / X); no celular uma aba por categoria |
| **Partida › HUD** (T6) | duplas com avatares, vidas e tempo no topo; minimapa; dicas [B] [P] [Tab] no PC; munição "25 | ∞"; aviso N KILL; legendas "Inimigo usou …" |
| **Tab** (PC) / **←** (controle) / **PLACAR** (celular) | placar com todas as duplas; a lista de jogadores do Roblox some |
| **P** (PC) / **→** (controle) / **engrenagem** (celular) | configurações em qualquer place, sem pausar; salva ao trocar de aba ou fechar |
| **Configurações › Botões** (só celular) | EDITAR BOTÕES: arrastar, − / +, PADRÃO, SALVAR; na partida os botões ficam onde você deixou |
| **Configurações › Acessibilidade** | cor do inimigo (contorno, barra e minimapa), tamanho do texto 100/115/130%, reduzir efeitos |

### Checklist (ESTILO seção 6), em cada tela

Testar no emulador do Studio (aba Teste › Dispositivo) em **celular pequeno**, **celular grande** e **tablet**, num **celular de verdade** e no **PC** (e com controle, se tiver):

- [ ] Funciona com o celular deitado, com o polegar alcançando os botões.
- [ ] No PC, sem botões de toque e com os atalhos visíveis.
- [ ] Nenhum vermelho fora de perigo/inimigo/Celestial e nenhum neon fora da logo e do item selecionado.
- [ ] Nenhum modal com fundo preto opaco (o jogo aparece atrás).
- [ ] Textos legíveis (contraste conferido nos testes automáticos) e sem nomes de outros jogos.

Para montar uma partida com um cliente só: painel **TESTE › PARTIDA › +7 JOGADORES DE TESTE** e **COMEÇAR AGORA**; **DADOS › DAR AS 4 CARTAS** antes, para ver a etapa da carta.

## Testar o tutorial (F6)

No place **Tutorial** (porta **34873**). Ao dar Play, o servidor monta a arena cinza do tutorial (7 estações lado a lado, no alto) e leva o jogador pelas 8 etapas: boas-vindas, movimento, armas (6 lições), cartas (Impulso, Nuvem, Tremor e Renascer, cada uma com um desafio), voz, sensibilidade, retícula e final.

- **Conta nova:** cai no tutorial. No jogo publicado, quem entra no **Lobby** com o tutorial pendente é levado sozinho para o Tutorial; quem já terminou nunca volta para ele (o Tutorial manda de volta ao Lobby).
- **No Studio** não há teleporte: abra o place Tutorial direto. Com o tutorial já feito, o Studio deixa refazer (para testar) e o final só avisa.
- **Retomar:** saia no meio e entre de novo: começa da etapa salva. Na etapa das cartas, as que você já ganhou são puladas.
- **Pular:** só voz, sensibilidade e retícula têm **PULAR**.
- **PC:** `Enter` aperta o botão principal. Na sensibilidade, **TESTAR** esconde o painel para mirar; `F` (controle: `B`) volta.

### Painel TESTE

| Botão | Onde | O que faz |
|---|---|---|
| **TUTORIAL: PULAR ETAPA** | Tutorial | conclui a etapa atual (na das cartas, entrega as que faltam) |
| **REFAZER TUTORIAL** | DADOS DO JOGADOR | tutorial pendente desde a etapa 1 (no Lobby publicado, leva ao Tutorial) |
| **CONCLUIR TUTORIAL (PULAR)** | DADOS DO JOGADOR | marca como feito e dá as 4 cartas (para testar o resto do jogo sem fazer o tutorial) |
| **RESETAR PERFIL** | DADOS DO JOGADOR | conta nova de verdade (sem cartas, tutorial pendente) |

### Roteiro dos critérios de aceite

1. **Conta nova:** RESETAR PERFIL e entre no Lobby publicado: você vai para o Tutorial. Faça tudo e cronometre (alvo: 3 a 5 minutos). No final, **IR PARA O LOBBY**: você cai no Lobby e **VER PERFIL** mostra "cartas 4 · tutorial feito".
2. **Configurações salvas:** mude a sensibilidade e a retícula no tutorial; no Lobby e na Partida a mira e a retícula são as que você escolheu.
3. **Sair no meio:** saia na etapa 4 depois de ganhar 2 cartas. Volte: começa na etapa 4, já na 3ª carta.
4. **Jogador antigo:** com o tutorial feito, entre no Tutorial (botão de teleporte do painel): volta ao Lobby na hora.
5. **Celular:** repita o roteiro no emulador (aba Teste › Dispositivo) e num celular de verdade: dicas de toque, botões grandes, painel à esquerda com o lado direito livre para mirar.

Os testes automáticos conferem a ordem das etapas, a retomada, o que pode ser pulado, a ordem das tarefas e que as lições cobrem uma arma de cada categoria e as 4 cartas.

## Marcação de aliado e inimigo (revisão na F6)

Na Partida (ou na arena de teste da F2), entre jogadores da mesma ilha:

| Situação | O que aparece |
|---|---|
| Inimigo à vista | contorno vermelho pulsando devagar + barra de vida vermelha (linha azul do escudo em cima) |
| Inimigo atrás de parede ou Nuvem | nada |
| Aliado à vista | barra verde e nome, sem contorno |
| Aliado todo escondido | silhueta verde através da parede |
| Do mirante | nome de quem duela, na cor da equipe |

Os personagens usam o **avatar do Roblox** de cada jogador (tamanho igualado). No Studio os jogadores de teste não têm avatar e aparecem com o corpo cinza de blocos.

## Testar o lobby e a fila (F5)

**No Studio a partida nunca sai do lobby.** O Studio não tem servidor reservado nem teleporte entre places. No Studio (1 servidor + vários clientes, no place **Lobby**) dá para testar só o grupo e a fila: convites, JOGAR, "Procurando partida… x/7", CANCELAR. Quando a partida fecha, aparece o aviso "Partida encontrada! No Studio não há teleporte" e todos voltam para JOGAR.

Tempos da fila:

| | Produção | Teste (`DEV_`: Studio e jogo de teste) |
|---|---|---|
| Poucos jogadores | começa em **20 s**, com 4 ou mais | começa em **5 s**, com 2 ou mais |
| Chegou a 7 | espera **15 s** para completar até 16 | igual |
| Faixas de elo se juntam | 45 s | 5 s |

Para testar de verdade (cair na partida):

1. Sincronize os 3 places com o Rojo e publique na experiência de **teste**.
2. Entrem no jogo publicado com contas diferentes (cada uma no seu aparelho ou janela).
3. **Dupla:** um toca em **+ CONVIDAR** (PC: `G`) e escolhe o outro; o outro toca em **ACEITAR** (PC: `Y`). Os dois tocam em **JOGAR** (PC: `Enter`).
4. Em 5 s a partida fecha e todos são levados ao mesmo servidor de Partida, com a dupla junta.
5. No fim, **SIM** em "Ir para a próxima partida com…" leva a dupla junta de volta, já na fila.

Painel **TESTE › FILA** (só no lobby): estado da fila, **COMEÇAR JÁ COM QUEM ESTÁ NA FILA** e a lista das fichas no Output do servidor.

## Testar em grupo no jogo publicado (até a fila da F5)

Sem fila, quem vai para a Partida pelo botão IR PARA PARTIDA cai numa partida sozinho (cada pedido cria um servidor reservado). Para jogar juntos:

1. Publique os places na experiência de **teste** (nunca na de produção).
2. Todos entram no **mesmo servidor do lobby**: você entra, e os outros clicam em **Entrar** no seu perfil do Roblox (ou usam um servidor privado).
3. Uma pessoa abre o painel **TESTE** e toca em **LEVAR TODOS PARA PARTIDA** duas vezes (o segundo toque confirma e mostra quantos vão). Todos do servidor vão juntos para a mesma Partida.
4. Lá, a partida começa sozinha em 20 s (ou **COMEÇAR AGORA** no painel). Para completar duplas, use **+N JOGADORES DE TESTE** antes de começar.
5. No fim da partida, cada um volta ao lobby por conta própria e pode cair em servidores diferentes. Para seguir juntos, use **LEVAR TODOS PARA LOBBY** antes do fim, ou entrem de novo pelo perfil de um de vocês.

O botão também existe para o Tutorial. No Studio não funciona (o Roblox não teleporta dentro do Studio).

## Testar as cartas (F4)

No place **Partida**, como na F3. As cartas só existem para quem as tem: até o tutorial (F6), abra o painel **TESTE › DADOS DO JOGADOR** e toque em **DAR AS 4 CARTAS** (o resumo mostra "Cartas: 4"). **TIRAR AS CARTAS** testa a partida sem carta.

### Controles

| Ação | PC | Celular | Controle |
|---|---|---|---|
| Carta básica escolhida | a tecla dela (C, Q ou E) | botão fixo da tecla | **LB** |
| Ult (Renascer) | **X** | botão **X** | **RB** |
| Nuvem | segurar mostra o arco, soltar arremessa | igual (segurar o botão) | igual (LB) |
| Painel de habilidades | **B** | segurar uma carta (menos a Nuvem) | direcional **↓** |

### Painel TESTE › PARTIDA › CARTAS (TESTE)

| Botão | O que faz |
|---|---|
| **CARGAS CHEIAS** | todas as suas cartas prontas de novo |
| **LEVAR 300 DE DANO** | você leva dano como se fosse um tiro (para testar o Renascer sozinho) |
| **TESTE: CARTA 10× DE UMA VEZ** | manda 10 pedidos da sua carta sem esperar; o servidor tem que aceitar no máximo as cargas que você tinha |
| **TESTE: CARTA QUE NÃO ESCOLHI** | pede uma carta que você não tem nesta rodada; o servidor tem que recusar |

### Roteiro dos critérios de aceite

1. **Escolha (1ª rodada):** a etapa CARTA abre primeiro, com Nuvem, Impulso e Tremor (tecla e o que faz) e o Renascer com cadeado. Escolha uma (clique, toque, atalho 1–3 ou controle). Nas rodadas seguintes a etapa aparece travada (🔒) com a carta. Numa outra partida, deixe o tempo acabar sem escolher: você joga sem carta básica (só a ult a partir da 4ª).
2. **Nuvem:** 2 por rodada. A bola faz arco e vira uma nuvem de raio 8 por 7 s. Atrás dela o inimigo some (sem contorno); dentro dela a tela fica coberta; do mirante ela fica translúcida.
3. **Impulso:** sobe ~18 studs; recarga de 20 s (o número aparece na carta).
4. **Tremor:** onda de 20 × 6 à frente, no chão. Precisa de **dois clientes**: quem for atingido no chão fica 50% mais lento e com a mira tremida por 2 s ("ATINGIDO PELO TREMOR"). Não atravessa parede, não pega o parceiro nem quem está no ar ou em outra altura. Recarga de 25 s.
5. **Renascer (4ª rodada em diante; use PULAR RODADA):** use X, afaste-se e toque em LEVAR 300 DE DANO dentro dos 8 s: você volta à marca com vida e escudo cheios. Use de novo em outra rodada e espere os 8 s: volta à marca mantendo a vida. Só 1 por rodada.
6. **Ult travada:** nas rodadas 1 a 3, X não faz nada e a carta mostra 🔒 4ª.
7. **Toque, teclado e controle:** repita 2 a 5 no emulador de celular (aba Teste › Dispositivo) e com um controle.
8. **Exploit:** os dois botões TESTE do painel. Esperado com a carta pronta: "aceitou 1 de 10" (mesmo a Nuvem com 2 cargas: há um intervalo mínimo entre usos); em recarga: "aceitou 0 de 10"; carta que não escolheu: "aceitou 0 de 1".

Os testes automáticos conferem os números do GDD 8.4, cargas e recargas, ult na 4ª rodada, opções da escolha, a geometria da Nuvem e do Tremor e o bloqueio de pedidos repetidos.

## Testar a partida (F3)

No place **Partida** (porta **34874**). Ao dar Play, o servidor monta o **mirante** (losango no alto) e as **4 ilhas cinza** em volta e abaixo, e roda a partida sozinho. A arena de teste da F2 fica desligada (`CombatConfig.TestArena.Enabled = true` volta a ela).

> Conecte o Rojo **uma vez só** no Studio da Partida. Se o Studio estiver conectado duas vezes, cada arquivo novo aparece duplicado (e a partida roda em dobro).

### Como começar

- A partida começa **20 s** depois do primeiro jogador, com pelo menos **2** (em teste; 4 no jogo real), ou na hora pelo botão **COMEÇAR AGORA**.
- **Vários clientes:** aba **Teste › Clientes e servidores**, escolha o número de jogadores e **Iniciar**.
- **Jogadores de teste:** no painel TESTE › PARTIDA, antes de começar, **+1 / +3 / +7 JOGADORES DE TESTE**. Eles são alvos parados com a cor da dupla. Duelo só entre jogadores de teste é sorteado depois de 6 s. Assim dá para montar partidas de 4 a 16 com um cliente só (ex.: você + 3 = 4; você + 6 = 7; você + 7 = 8; você + 15 = 16).

### Painel TESTE › PARTIDA

| Botão | O que faz |
|---|---|
| **COMEÇAR AGORA** | começa sem esperar os 20 s |
| **PULAR RODADA** | encerra a etapa atual; no combate, decide como tempo esgotado (mais HP + escudo vence) |
| **FORÇAR VIRADA** | a próxima rodada é a Virada (se ainda não aconteceu e não é a final) |
| **TIRAR 1 VIDA DE…** (um botão por dupla) | entre rodadas tira na hora; no meio da rodada, no fim dela |
| **+N JOGADORES DE TESTE / TIRAR** | só antes de começar |
| **RECOMEÇAR PARTIDA** | encerra sem resultado e volta a esperar jogadores |

### Roteiro dos critérios de aceite

1. **Partida completa com 4, 7, 8 e 16 jogadores:** monte cada número (clientes + jogadores de teste) e jogue até a campeã. Use PULAR RODADA para acelerar. Confira: duplas formadas, o placar no mirante, eliminações, a final melhor de 3 (vidas param de contar), a cerimônia e a tela final. No Studio, a tela final avisa que o teleporte não funciona e a partida recomeça.
2. **Armas por rodada:** rodadas 1 e 2 só pistolas (sem Tambor); 3ª armas médias + pistola (com Tambor); 4ª em diante armas pesadas. Teste também REPETIR ÚLTIMA, CONFIRMAR, os atalhos 1–8 e Enter no PC, e deixar o tempo acabar sem escolher.
3. **Virada:** use TIRAR 1 VIDA até uma dupla ficar com 1 vida. A rodada seguinte mostra RODADA DA VIRADA e o selo VIRADA; quem vencer ganha +1 vida (até 5). Depois disso ela não volta.
4. **Jogador ímpar:** com 7 (ou 3), um jogador fica sozinho, com 5 vidas, sem bônus.
5. **Folga:** com número ímpar de duplas (ex.: 6 jogadores = 3 duplas), uma fica de folga no mirante; a folga gira e só repete depois de todas.
6. **Mirante:** quem está de folga (ou eliminado) anda até as bordas e vê os duelos de cima: o telhado do galpão fica transparente e o nome da ilha aparece. Não dá para atirar nem cair do mirante. Quem joga numa ilha não vê os espectadores.
7. **Espectar o parceiro:** caia antes do parceiro; a câmera vai para a cabeça dele, em primeira pessoa.
8. **Casos especiais:** feche um cliente no meio (o parceiro segue sozinho); fique 30 s parado no combate (aviso) e 60 s (sai da partida).

Os testes automáticos (`require(game.ServerStorage.Tests.Runner).run()`) simulam 50 partidas para cada número de jogadores (4, 7, 8 e 16) e conferem Virada, folga, vidas, final e armas por rodada.

## Testar o combate (F2)

Para testar só o combate, ligue a arena de teste (`CombatConfig.TestArena.Enabled = true`). No place **Partida**: rode `rojo serve match.project.json` e conecte o Studio da Partida na porta **34874**. Ao dar Play, a arena de teste cinza é montada pelo código (nada fica salvo no place).

### Controles

| Ação | PC | Controle | Celular |
|---|---|---|---|
| Atirar | botão esquerdo | gatilho direito | botão ATIRAR (arrastar o dedo nele também gira a câmera) |
| Mira / modo alternativo | segurar botão direito | segurar gatilho esquerdo | botão MIRA ou MODO (liga/desliga) |
| Recarregar | R | X | botão RECARREGAR (e sozinho ao esvaziar) |
| Trocar arma | 1 / 2 / 3 ou roda do mouse | Y (segurar = corpo a corpo) | 1⇄2 (segurar = escolher 1, 2 ou 3) |
| Golpe forte (corpo a corpo) | botão direito | gatilho esquerdo | segurar ATIRAR |

Tiro automático e assistência de mira (toque e controle) seguem o perfil (ligados por padrão).

### Painel TESTE › COMBATE

| Botão | O que testa |
|---|---|
| **ESCOLHER ARMA** (18 botões) | equipa qualquer arma (primária ou pistola, pelo espaço dela) |
| **TROCAR DE DUPLA** | passa entre Azul e Laranja (inimigo × parceiro) |
| **VIDA E ESCUDO CHEIOS** | recupera tudo |
| **ALVOS: ANDANDO / PARADOS** | liga e desliga o movimento dos alvos que andam |
| **TESTE: ATIRAR RÁPIDO DEMAIS** | manda 20 tiros de uma vez; o servidor tem que aceitar só 1 |

Ao derrubar um alvo, aparece embaixo do aviso `N KILL` o tempo e o número de tiros (compare com a tabela do GDD 7.2.3, ±10%).

### Na arena

- **Estande** (lado leste): alvos a 10, 20, 40, 60, 80 e 100 studs da linha de tiro, para ver a perda de dano com a distância.
- **Cobertura fina** (bege): o Moedor atravessa com metade do dano; as outras armas, não.
- **Parede grande** perto da base Azul: para testar o contorno do parceiro (só aparece com o corpo inteiro escondido).
- **Dois ou mais jogadores no Studio:** aba **Teste › Clientes e servidores**, escolha 2 (ou mais) jogadores e **Iniciar**. Com 2 jogadores, vocês são inimigos; use TROCAR DE DUPLA para ficar parceiros.
- **Celular no Studio:** aba **Teste › Dispositivo** (emulador) para ver os botões de toque. O teste de verdade é num celular, com o jogo publicado.
