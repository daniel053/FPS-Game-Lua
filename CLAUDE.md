# [NOME DO JOGO] — instruções para o Claude Code

Jogo de tiro em primeira pessoa no Roblox, duelos 2v2 em formato de torneio, low poly cartoon, mobile em primeiro lugar.

## Leia antes de qualquer tarefa

1. `docs/FASES.md` — **em qual fase estamos** e o que fazer nela. Comece sempre por aqui.
2. `docs/GDD.md` — regras de jogo, números e arquitetura.
3. `docs/ESTILO-E-TELAS.md` — aparência e comportamento de cada tela, cores, fontes, celular × PC.
4. `docs/DADOS-JOGADOR.md` — tudo o que é salvo do jogador, como salvar e como migrar.
5. `docs/KIT-MODULAR.md` e `docs/referencias/visuais/` — componentes dos 4 mapas (medidas, cores, regras) e guia da arma em primeira pessoa. Obrigatórios na F2 (arma) e na F10 (mapas).
6. `docs/referencias/mockup-v1.png` — mockup de referência. Leia a seção 1 do guia de estilo antes de usá-lo: ele contém erros e nomes de outro jogo que **não** devem ser copiados.
7. `docs/BOTS.md` — **bots de preenchimento (temporários)**: completam a fila e a partida quando há pouca gente. Como ajustar, como **desligar** (1 linha) e como **remover** de vez. Todo código deles tem a marca `[BOTS]`; não espalhe lógica de bot fora desses pontos.

## Regras que valem sempre

- Marcadores dos documentos: `[DECIDIDO]` implementar como está; `[PROPOSTA]` implementar com o valor em config, fácil de mudar; `[ABERTO]` não implementar, perguntar ao dono do projeto.
- Trabalhar **uma fase por vez** (`docs/FASES.md`). Ao terminar uma fase, parar e pedir teste antes da próxima.
- Câmera **sempre em primeira pessoa**, em todos os places. Nunca oferecer terceira pessoa.
- Servidor é a autoridade de dano, vidas, moedas, elo, cartas e compras. O cliente só pede e mostra.
- Luau `--!strict`. Rojo, Wally, Selene, StyLua.
- Números de balanceamento só em `src/shared/Config/`. Cores e fontes só em `Theme.luau`. Textos visíveis só em `Strings.luau` (português do Brasil).
- Todo controle e toda tela funcionam no celular **e** no PC (e controle). No PC, botões de toque somem e atalhos ficam visíveis. ESC é reservado pelo Roblox.
- Nunca usar nomes, logos, ícones, sons ou arte de outros jogos. As colunas "Referência" das tabelas só explicam o papel de cada item.
- Sem sangue. Neon só onde o guia de estilo permite (seção 2.6).
- Nenhuma mecânica de recompensa aleatória paga (ver GDD seção 8.9).

## Quando algo não estiver nos documentos

Perguntar antes de inventar regra de jogo. Detalhe técnico de implementação pode ser decidido, mas registre a decisão no fim do GDD numa seção "Decisões técnicas".

## Atualizando os documentos

Quando o dono do projeto decidir algo novo durante o desenvolvimento, atualize o documento correspondente (mudando o marcador para `[DECIDIDO]`) no mesmo commit da implementação.
