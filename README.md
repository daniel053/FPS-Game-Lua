# [NOME DO JOGO]

Tiro em primeira pessoa no Roblox, duelos 2v2 em formato de torneio. Os documentos de design estão em `docs/`, e o ponto de partida é `docs/FASES.md`.

## O que tem aqui

| Pasta / arquivo | O que é |
|---|---|
| `src/shared/` | Código usado por servidor e cliente nos 3 places: `Config/` (números, `Theme`, `Strings`), `Types`, `Remotes`, `Env` |
| `src/common/` | Código que roda igual nos 3 places (`server/` e `client/`) |
| `src/lobby/`, `src/tutorial/`, `src/match/` | Código de cada place |
| `src/tests/` | Testes automáticos da lógica (rodam no Studio) |
| `vendor/ProfileStore/` | Biblioteca de perfis com trava de sessão (cópia oficial, ver `ORIGEM.md`) |
| `lobby.project.json`, `tutorial.project.json`, `match.project.json` | Um projeto do Rojo para cada place |
| `rokit.toml` | Versões das ferramentas (Rojo, Wally, Selene, StyLua, luau-lsp) |
| `scripts/check.ps1` | Confere formatação, boas práticas e tipos |

**O Rojo nunca mexe no Workspace** (mapas), na Lighting nem no Terrain. Ele só sincroniza:
- `ReplicatedStorage.Shared` e `ReplicatedStorage.Packages`
- `ServerScriptService.Common` e `ServerScriptService.Place`
- `ServerStorage.Vendor` (ProfileStore) e `ServerStorage.Tests`
- `StarterPlayer.StarterPlayerScripts.Common` e `.Place`
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

> Nunca use `rojo build` para gerar um place por cima de um place existente. Os mapas vivem só no Studio.

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
