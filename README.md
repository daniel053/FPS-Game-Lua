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
