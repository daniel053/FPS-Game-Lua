# Guia: como desenvolver o jogo com o Claude Code

Este guia é para **você** (dono do projeto), não para o Claude Code. Guarde junto dos outros documentos.

---

## Parte 1 · Preparação (uma vez só)

### 1.1 Salve uma cópia do seu mapa
Antes de qualquer coisa, no Roblox Studio: **Arquivo › Salvar no arquivo como…** e guarde um `.rbxl` de backup fora da pasta do projeto. Se algo der errado na sincronização, você não perde o mapa.

### 1.2 Publique o jogo no Roblox
Várias coisas **só funcionam em jogo publicado**:
- Salvar dados (DataStores) dentro do Studio exige o jogo publicado e a opção **Configurações do jogo › Segurança › Permitir acesso do Studio aos serviços de API** ligada.
- Teleporte entre places (Tutorial → Lobby → Partida) **não funciona dentro do Studio**, só no jogo publicado (pode ser privado).

Publique como privado: **Arquivo › Publicar no Roblox**.

### 1.3 Ferramentas
O Claude Code vai instalar e configurar as ferramentas na Fase F0 (Rojo, Wally, Selene, StyLua). Você só precisa:
- instalar o **plugin do Rojo** no Roblox Studio quando ele pedir;
- confirmar as instalações que ele propuser.

O Rojo é a ponte: o Claude Code escreve o código em arquivos na pasta, e o Rojo joga esse código para dentro do Studio enquanto você testa.

### 1.4 Git
Peça para o Claude Code iniciar um repositório git na F0. Cada fase vira um ou mais commits. Se algo quebrar, dá para voltar.

### 1.5 Conectar o Claude Code ao Studio (MCP oficial do Roblox)
O Roblox Studio tem um servidor MCP embutido. Com ele, o Claude Code consegue ver a árvore do jogo, rodar Luau, apertar Play, ler o console e tirar **capturas de tela** do Studio — essencial para construir e conferir os mapas.

1. Atualize o Roblox Studio e o Claude Code.
2. No Studio: abra o **Assistant** › **…** › **Manage MCP Servers** e ligue **Enable Studio as MCP server**.
3. Em **Quick connect**, ligue **Claude Code**.
4. Reinicie o Studio e o Claude Code. Confira o indicador verde em Manage MCP Servers.

Divisão de trabalho:
- **Código** (scripts, configs, interface): arquivos na pasta, sincronizados pelo **Rojo**.
- **Construção e conferência no Studio** (montar componentes do kit, posicionar ilhas, testar, capturas de tela): **MCP do Studio**.

### 1.6 Skills
- **Roblox Brain** (que você já instalou): use normalmente.
- **building-maps** e **building-3d-objects** (repositório `ohzw/roblox-dev-skills`): guias para construir mapas e objetos no Studio via MCP. Instalação: `npx skills add https://github.com/ohzw/roblox-dev-skills --skill building-maps`. Foram feitas para um MCP com a ferramenta `run_code`; com o MCP oficial do Studio (que usa `execute_luau`) podem precisar de adaptação. Teste numa cópia do place antes da F10.
- Não encontrei skill confiável específica para low poly ou FPS. O `KIT-MODULAR.md` e as pranchas cumprem esse papel.
- Cuidado com skills desconhecidas: elas podem rodar comandos no seu computador. Instale só de fontes com histórico e auditorias.

---

## Parte 2 · Primeiro prompt (começar a F0)

Abra o Claude Code na pasta do projeto e cole:

```
Leia o CLAUDE.md e depois docs/FASES.md, docs/GDD.md, docs/ESTILO-E-TELAS.md e docs/DADOS-JOGADOR.md.

Vamos começar a Fase F0 (Base do projeto).

Contexto importante:
- Eu já tenho um place aberto no Roblox Studio com um mapa preparado no Workspace. Esse mapa NÃO pode ser apagado nem sobrescrito. Configure o Rojo para gerenciar só o código (ServerScriptService, ReplicatedStorage, StarterPlayer, StarterGui etc.) e deixar o Workspace fora da sincronização.
- Eu não sou programador experiente. Explique cada passo que eu preciso fazer fora do terminal (no Studio ou no site do Roblox) de forma simples, um passo por vez.
- Detecte meu sistema operacional e instale o que faltar (Rojo, Wally, Selene, StyLua), pedindo confirmação.
- Inicie um repositório git.

Antes de escrever código, me mostre o plano da F0 e espere minha aprovação.
```

Dica: no Claude Code, **Shift+Tab** alterna para o **modo de planejamento**, em que ele só planeja e não mexe em arquivos. É um bom jeito de revisar o plano de cada fase antes de liberar.

---

## Parte 3 · Como trabalhar cada fase

### 3.1 O ciclo

1. **Começar a fase** (prompt 4.1).
2. **Revisar o plano** que ele mostrar. Se algo estiver diferente do que você quer, diga antes de aprovar.
3. **Deixar ele implementar.** Ele vai pedir para você fazer coisas no Studio (conectar o Rojo, apertar Play, testar). Faça e conte o que aconteceu.
4. **Testar** (Parte 5).
5. **Reportar problemas** (prompt 4.3) até tudo funcionar.
6. **Fechar a fase** (prompt 4.4): ele roda os testes, atualiza os documentos e faz o commit.
7. **Limpar a conversa** com `/clear` antes da próxima fase. A memória do projeto está nos documentos, não na conversa; começar limpo evita confusão.

### 3.2 Ordem das fases
F0 Base → F1 Dados → F2 Combate → F3 Loop da partida → F4 Cartas → ⭐ **teste com amigos** → F5 Lobby e fila → F6 Tutorial → F7 Interface final → F8 Social e voz → F9 Elo, economia e arsenal → F10 Mapas e arte → ⭐ **beta fechado** → F11 Robux e lançamento.

Não pule fases. Não peça arte bonita antes da F10: o jogo precisa ser divertido em blocos cinza primeiro.

### 3.3 Sobre o seu mapa pronto
O seu mapa pode virar uma das ilhas na F10, ou servir de cenário de teste antes disso. Na F2 ou F3, avise o Claude Code:
```
O mapa que está no Workspace é [descreva: tema, tamanho]. Quero usá-lo como [ilha de teste / a ilha Praça / ...]. Adapte a fase para isso sem apagar nada do mapa.
```

---

## Parte 4 · Prompts prontos

### 4.1 Começar uma fase
```
Leia o CLAUDE.md e docs/FASES.md. Vamos começar a Fase [F?] ([nome]).
Releia nos documentos tudo o que essa fase usa.
Liste os itens [ABERTO] que afetam esta fase e me pergunte antes de implementá-los.
Mostre o plano e espere minha aprovação.
```

### 4.2 Retomar depois de uma pausa
```
Leia o CLAUDE.md e docs/FASES.md. Veja o status das fases e o histórico do git.
Me diga em que ponto paramos, o que falta na fase atual e qual o próximo passo.
```

### 4.3 Reportar um problema
```
Problema na Fase [F?]:
- O que eu fiz: [ex.: apertei Play com 2 jogadores e atirei com a Rajada]
- O que eu esperava: [ex.: o outro perder vida]
- O que aconteceu: [ex.: nada; apareceu este erro na janela Output: ...]
- Onde: [celular / PC / Studio]
Investigue a causa antes de corrigir e me explique o que era.
```
Sempre que possível, copie a mensagem de erro da janela **Output** do Studio (Visualizar › Output).

### 4.4 Fechar uma fase
```
Acho que a Fase [F?] está pronta.
1. Rode/liste todos os critérios de aceite da fase em docs/FASES.md e diga quais passaram e quais eu preciso testar manualmente (com o passo a passo).
2. Atualize os documentos com as decisões que tomamos nesta fase.
3. Marque a fase como concluída em docs/FASES.md.
4. Faça o commit.
5. Me dê um resumo do que foi feito e do que ficou pendente.
```

### 4.5 Mudar uma regra ou um número
```
Decidi mudar: [ex.: a Luneta passa a dar 120 de dano / a partida começa com 8 jogadores].
Atualize o documento correspondente (marcando como [DECIDIDO]) e a config.
Me diga se essa mudança afeta outra coisa no jogo.
```

### 4.6 Responder uma pendência
```
Decisão sobre [item ABERTO, ex.: Girar cartas]: [sua resposta].
Atualize os documentos e me diga quais fases isso afeta.
```

### 4.7 Ajustar balanceamento depois de testar
```
Depois de jogar, percebi: [ex.: a Vespa está forte demais; as partidas estão durando 18 minutos].
Sugira ajustes nos números, explique o efeito de cada um e espere eu escolher.
```

### 4.8 Revisão de segurança (no fim das fases F2, F3, F5, F9 e F11)
```
Faça uma revisão de segurança do que foi feito até agora: remotes sem validação, dados que o cliente consegue alterar, moedas ou elo que podem ser duplicados. Liste os problemas por gravidade antes de corrigir.
```

---

## Parte 5 · Como testar

| O que testar | Como |
|---|---|
| Vários jogadores | Studio › aba **Testar** › **Clientes e servidores**, escolha o número de jogadores (ex.: 4, 7, 8). |
| Celular | Studio › **Testar** › **Emulação de dispositivo**: escolha um celular. Depois teste no seu celular real com o jogo publicado (privado). |
| PC | Play normal no Studio. |
| Salvar dados | Precisa do jogo publicado e do acesso a API ligado (1.2). |
| Teleporte entre places e fila | Só no jogo publicado. Entre com duas contas (a sua e a de um amigo, ou uma conta de teste). |
| Desempenho no celular | Jogo publicado, aberto num celular simples; use o comando de mostrar FPS que o Claude Code criar. |

Marco ⭐ **primeiro jogável** (depois da F4): jogue com amigos, anote o que é chato, confuso, forte ou fraco demais, e use o prompt 4.7.

---

## Parte 6 · Boas práticas

- **Uma coisa por vez.** Pedidos grandes demais geram confusão. Prefira terminar a fase e depois pedir a próxima.
- **Sempre leia o plano** antes de aprovar.
- **Não deixe ele inventar regra de jogo.** Se ele perguntar algo que não está nos documentos, decida você, e peça para ele registrar.
- **Use `/clear` entre fases.** Se a conversa ficar muito longa no meio de uma fase, use `/compact`.
- **Faça backup do place** (`.rbxl`) antes de fases grandes (F3, F5, F10).
- **Commits frequentes.** Se algo quebrar: *"volte para o último commit que funcionava e me explique o que mudou depois dele"*.

---

## Parte 7 · Pendências que ele vai te perguntar

Decida quando a fase correspondente chegar:

| Pendência | Fase |
|---|---|
| Aviso de abate conta por rodada ou por partida | F2 |
| Moedor e Gêmea entram na fase Pesadas? | F2/F3 |
| O tutorial pode ser pulado? | F6 |
| Girar cartas: sorteio ou só visualização 3D | F9 |
| Raridade muda o poder da carta? | F9 |
| Segunda moeda (diamante roxo) existe? | F9 |
| Temporadas de elo? Elo ADM no ranking? | F9 |
| Plantas baixas e tamanhos dos 4 mapas | F10 |
| Preços em Robux | F11 |
| Nome e logo do jogo | antes da F11 |
