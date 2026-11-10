# [NOME DO JOGO] — Guia de Estilo e Telas

> **Versão:** 0.1
> **Documento irmão:** `docs/GDD.md` (regras de jogo)
> **Imagem de referência:** `docs/referencias/mockup-v1.png`

---

## 0. Como usar este documento (para o Claude Code)

- Este documento define **como cada tela do jogo é e se comporta**: layout, cores, fontes, componentes e diferenças entre celular e PC.
- As regras de jogo (números, tempos, lógica) ficam no GDD. Se os dois discordarem sobre regra de jogo, vale o GDD; sobre aparência, vale este.
- Usa os mesmos marcadores do GDD: `[DECIDIDO]`, `[PROPOSTA]`, `[ABERTO]`.
- Todas as cores, tamanhos e fontes deste documento vão para um módulo de tema único (`src/shared/Config/Theme.luau`). Nenhuma tela define cor ou fonte "na mão".
- Todo texto visível ao jogador é em **português do Brasil**, centralizado num módulo de textos (`src/shared/Config/Strings.luau`) para facilitar tradução futura.

---

## 1. A imagem de referência

`docs/referencias/mockup-v1.png` é um mockup gerado por IA, dividido em 6 telas. Ele mostra **a ideia de layout e de clima**, não um modelo para copiar pixel a pixel.

| Tela no mockup | Seção aqui |
|---|---|
| Cartas (alto, esquerda) | T1 |
| Seleção de arma + carta (alto, direita) | T2 |
| Lobby (meio, esquerda) | T3 |
| Mapas de duelo (meio, direita) | T4 |
| Arsenal (baixo, esquerda) | T5 |
| HUD em partida, celular (baixo, direita) | T6 |

### 1.1 O que seguir do mockup `[DECIDIDO]`

- Organização geral do Lobby (grupo à esquerda, modo de jogo e botão de jogar à direita, cenário 3D no centro, moedas e engrenagem no topo direito).
- Ilha central com 4 ilhas de duelo em volta.
- Organização do Arsenal (abas no topo, grade de armas por categoria, painel de detalhe à direita, botão Equipar).
- Carrossel de cartas com molduras por raridade e botão Girar.
- Disposição do HUD (placar e tempo no topo, minimapa no canto, vida e escudo embaixo à esquerda, cartas embaixo no centro, munição embaixo à direita, controles de toque).
- Painéis escuros, títulos em caixa alta, cantos chanfrados.

### 1.2 O que NÃO copiar do mockup `[DECIDIDO]`

| No mockup | Correção |
|---|---|
| Nomes de armas de outro jogo (os nomes escritos nos cartões de arma) | Usar os nomes próprios do GDD (Bolinha, Vespa, Rajada, Trovão, Luneta…) |
| Símbolo em "V" vermelho (logo e ícones) | Proibido. Logo provisória roxa (seção 2.4) |
| Vermelho como cor principal da interface | Acento **roxo** (seção 2.1) |
| Torre no meio da ilha central | Ilha central **plana**, sem construção no meio |
| Tela de seleção com fundo preto, como se fosse outro lugar | **Modal sobre o mapa**, com o jogo visível atrás (T2) |
| A mesma arma aparecendo duas vezes na seleção (no cartão e em tamanho grande) | Cada arma aparece **uma vez só** (T2) |
| Barra de vida vermelha | Vida em **verde-claro**, escudo em **azul** (vermelho é do inimigo) |
| Placar com 4 jogadores de cada lado | 2v2: **2 de cada lado**, mais as vidas da dupla |
| Munição reserva "75" | Munição reserva é infinita: mostrar só o pente (`25`) com o símbolo `∞` |

---

## 2. Identidade visual da interface

### 2.1 Cores `[PROPOSTA]` (o roxo como acento é `[DECIDIDO]`)

| Token | Uso | Hex |
|---|---|---|
| `bg.overlay` | escurecimento atrás de modais (sobre o jogo) | `#0B0F1E` a 55% de opacidade |
| `panel.base` | fundo de painéis | `#141A2E` a 92% de opacidade |
| `panel.raised` | cartões e itens dentro de painéis | `#1E2640` |
| `panel.border` | bordas de cartões | `#2E3858` |
| `text.primary` | texto principal | `#FFFFFF` |
| `text.secondary` | texto de apoio | `#AEB6D0` |
| `accent` | botão principal, aba ativa, item selecionado | `#8B5CF6` (roxo) |
| `accent.glow` | brilho discreto do item selecionado | `#A970FF` a 40% |
| `accent.pressed` | botão principal pressionado | `#6D3FE0` |
| `success` | "pronto", confirmações | `#4ADE80` |
| `hp` | barra de vida | `#7CE38B` |
| `shield` | barra de escudo | `#4FA8FF` |
| `danger` | contorno de inimigo, avisos de perigo, dano recebido | `#FF3B4E` |
| `coin` | moeda do jogo | `#F5B700` |

Regras:
- **Vermelho** na interface só em: perigo, inimigo e carta Celestial.
- Contraste mínimo de 4,5:1 entre texto e fundo. Texto `text.secondary` sobre `panel.base` passa; não usar cinza mais escuro que ele.

### 2.2 Raridades `[DECIDIDO]`

| Raridade | Cor base | Moldura |
|---|---|---|
| Comum | azul `#3B82F6` | borda 3 px, brilho leve |
| Épica | roxo `#A855F7` | borda 3 px, brilho leve |
| Lendária | dourado `#F5B700` | borda 3 px, brilho médio, cantos com detalhe |
| Celestial | **vermelho vibrante `#FF1F3D`** | borda 4 px, **neon vermelho forte** pulsando devagar (ciclo de ~2 s), partículas finas em volta |

- A raridade nunca é indicada **só pela cor**: sempre há o nome da raridade escrito e um ícone próprio (losango, estrela, coroa, sol) para quem é daltônico.
- O neon forte é **exclusivo da Celestial**. Nenhuma outra raridade chega perto daquele brilho.

### 2.3 Tipografia `[PROPOSTA]`

| Uso | Fonte (Roblox) | Estilo |
|---|---|---|
| Títulos de tela e botões | Oswald (ou outra condensada disponível no Roblox) | negrito, CAIXA ALTA |
| Texto corrido e descrições | Montserrat | regular / semibold |
| Números (tempo, munição, moedas) | Oswald | negrito |

Tamanhos mínimos (em escala de tela de celular): texto corrido 14, rótulos 12, títulos 22, botão principal 18.

### 2.4 Logo `[ABERTO]`

- Provisória: o nome do jogo em Oswald negrito, branco, com um símbolo simples **roxo com neon**.
- Proibido: letra "V", formato de presa, vermelho, ou qualquer forma que lembre a marca de outro jogo.

### 2.5 Formas e componentes

- **Cantos chanfrados** (corte diagonal) nos painéis e botões principais, como no mockup. Cartões pequenos podem ter canto arredondado de 6 px.
- **Botão principal:** fundo `accent`, texto branco em caixa alta, seta "›" à direita, altura mín. 56 px no celular.
- **Botão secundário:** fundo `panel.raised`, borda `panel.border`.
- **Aba:** texto em caixa alta; a aba ativa tem fundo `accent`; as inativas, fundo `panel.raised`.
- **Cartão de item** (arma, skin, carta): `panel.raised`, imagem centralizada, nome embaixo em caixa alta. Selecionado = borda `accent` + `accent.glow`.
- **Chip de tecla:** quadradinho com a letra (C, Q, E, X, B, P), fundo `panel.raised`, borda `text.secondary`. Usado no HUD e nas dicas.
- **Modal:** `panel.base` sobre `bg.overlay`. Nunca fundo opaco cobrindo a tela inteira.

### 2.6 Neon e brilho na interface `[DECIDIDO]`

Permitido **somente** em:
1. moldura da carta Celestial (forte);
2. molduras das outras raridades (leve a médio);
3. logo (roxo);
4. item selecionado (`accent.glow`, discreto).

Proibido em todo o resto: fundos, textos, ícones, barras, botões comuns, HUD.

### 2.7 Animação `[PROPOSTA]`

- Abrir modal: sobe 24 px e aparece em 0,2 s.
- Trocar aba: transição de 0,15 s.
- Seleção de item: leve aumento de escala (1,04) em 0,1 s.
- Nada pisca rápido. Nada de animação contínua fora da carta Celestial, do botão Girar e do contorno do inimigo em jogo (pulso lento de ~1,2 s, GDD 7.6; desligado com "reduzir efeitos").

---

## 3. Celular × PC `[DECIDIDO]`

| Tema | Celular | PC |
|---|---|---|
| Controles de toque | visíveis | **escondidos** |
| Dicas de teclas | não aparecem | **sempre visíveis** (chips de tecla) |
| Abas de categoria | rolagem horizontal | todas visíveis lado a lado |
| Configurações na partida | botão de engrenagem | tecla **P** |
| Detalhes das habilidades | toque longo na carta do HUD | tecla **B** |
| Placar | botão no topo | tecla **Tab** |
| Menu do Roblox | — | **ESC (reservado pelo Roblox, não usar)** |

- Toda tela é desenhada primeiro para celular deitado (paisagem) e depois ajustada para PC.
- Usar escala relativa e respeitar a área segura (entalhe da câmera).
- Alvo de toque mínimo: 44 px; botões de ação em combate: 64 px; botão de atirar: 80 px.

---

## 4. Telas

### T1 · Cartas (coleção e Girar)

**Função:** ver as cartas, ver raridades, girar cartas.

**Layout (paisagem):**
```
┌─────────────────────────────────────────────────────────┐
│ ‹ CARTAS                  ◆COMUM ◆ÉPICA ◆LENDÁRIA ☀CELESTIAL │
│                                                         │
│     [carta]   [ CARTA EM DESTAQUE ]   [carta] [carta]   │
│        ‹                                      ›          │
│              Nome da carta · Tecla C                    │
│              Uma frase do que ela faz                   │
│                   [ ⟳ GIRAR ]                           │
└─────────────────────────────────────────────────────────┘
```

- Carrossel com a carta selecionada no centro, maior; as outras ao lado, menores e levemente inclinadas.
- No topo, filtros por raridade (com nome e ícone, não só cor).
- Painel de informação: nome, tecla fixa (chip), raridade, descrição de uma frase.
- **Botão GIRAR** sempre visível embaixo da carta. Comportamento: GDD seção 8.9 `[ABERTO]` (sorteio ou visualização). Se for sorteio: mostrar custo e chances **antes** de girar.
- Cartas que o jogador não tem: silhueta escura com cadeado.
- Celular: arrastar para os lados troca a carta. PC: setas ou roda do mouse.

### T2 · Modal de preparação (carta + arma)

**Função:** no começo de cada rodada, escolher carta (só na 1ª rodada) e armas. Regras: GDD seção 4.10.

**Decisões visuais** `[DECIDIDO]`:
- É um **modal sobre o jogo**. O jogador já está no mapa, na base, congelado. O mapa aparece atrás, escurecido (`bg.overlay`), **nunca** um fundo preto de tela separada.
- **Uma janela só** para carta e arma.
- Cada arma aparece **uma vez**. Sem imagem grande repetida da arma selecionada.

**Layout (paisagem):**
```
            (mapa visível e escurecido atrás)
   ┌───────────────────────────────────────────────────┐
   │ RODADA 3 · ARMAS MÉDIAS                    ⏱ 10   │
   │ [1 CARTA ✓]  [2 PRIMÁRIA]  [3 SECUNDÁRIA]          │  ← etapas
   │ ┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐   │
   │ │VESP││FERR││BALD││VARR││TÁTI││ATIR││MART││MATA│   │  ← armas da fase
   │ └────┘└────┘└────┘└────┘└────┘└────┘└────┘└────┘   │
   │  Dano ▮▮▮▯▯  Cadência ▮▮▮▮▯  Alcance ▮▮▯▯▯          │  ← da selecionada
   │ ─────────────────────────────────────────────────  │
   │ Sua carta: [Nuvem · C]   Parceiro: Vespa · Impulso │
   │                 [REPETIR ÚLTIMA]   [ CONFIRMAR › ] │
   └───────────────────────────────────────────────────┘
```

- **Etapas** no topo: Carta → Primária → Secundária. Na 1ª e 2ª rodadas só existem Carta (na 1ª) e Secundária (pistola). A partir da 2ª rodada, a etapa Carta aparece travada com a carta escolhida.
- **Etapa Carta:** as 3 cartas básicas lado a lado com moldura de raridade; a ult (X) aparece ao lado com cadeado e o texto "Libera na 4ª rodada".
- **Etapa de armas:** grade com as armas da fase, agrupadas por categoria (título pequeno acima de cada grupo). A selecionada fica com borda `accent`. Abaixo, barras simples de atributos da selecionada (sem segunda imagem).
- **Rodapé:** carta escolhida (miniatura + tecla), escolhas do parceiro em tempo real, botão **Repetir última**, botão **Confirmar**.
- Ao confirmar, o modal fecha e mostra no centro da tela "Aguardando início · 4 s".
- **Celular:** o modal ocupa ~90% da largura e ~80% da altura; grade com rolagem horizontal; cartões de arma de 64 px no mínimo.
- **PC:** atalhos 1 a 8 para escolher armas, Enter para confirmar.

### T3 · Lobby

**Função:** ponto de partida. Grupo, fila, navegação.

**Layout (paisagem):**
```
┌──────────────────────────────────────────────────────────┐
│ [logo] LOBBY                       ● 2.350   ◆ 120   ⚙   │
│                                                          │
│ [avatar] Player123 · Ouro          (cena 3D: ilhas        │  DUELO EM DUPLA
│          Pronto                     flutuantes ao fundo)  │  [imagem do modo]
│ [avatar] Amigo123 · Prata                                │  Mapa central +
│          Pronto                                          │  4 ilhas de duelo
│ [+ CONVIDAR AMIGOS]                                      │  ✓ 2/2 prontos
│                                                          │  [ JOGAR › ]
│ [JOGAR] [ARSENAL] [CARTAS] [RANKING] [LOJA]              │
└──────────────────────────────────────────────────────────┘
```

- **Esquerda:** grupo (até 2 jogadores): avatar, nome, ícone do elo, estado (Pronto / Escolhendo). Botão **Convidar amigos**.
- **Centro:** cena 3D com as ilhas flutuantes ao fundo (só ambientação). A ilha central é plana.
- **Direita:** cartão do modo ("Duelo em dupla"), imagem, prontos "x/2", botão principal **Jogar** (entra na fila). Na fila, o botão vira "Procurando partida… 5/7" com opção de cancelar.
- **Topo direito:** moedas (ícone amarelo), segunda moeda se existir `[ABERTO]`, engrenagem de configurações.
- **Navegação:** Jogar, Arsenal (T5), Cartas (T1), Ranking, Loja.
- Seguir a organização do mockup, **sem** o símbolo em V e sem vermelho como cor principal.

### T4 · Mapas de duelo (mundo do servidor de partida)

**Função:** descrever como o mundo da partida é montado. Regras: GDD seções 6.5 e 15.

```
            [PRAÇA]                [TORRE]
                  \                /
                   ( MIRANTE CENTRAL )   ← mais alto, chão plano
                  /                \
          [FÁBRICA]                [PORTO]
```

- **Mirante:** ilha central, **plana, sem torre, sem prédio no meio**. Está acima das outras. Bordas com barreira invisível.
- De cada borda do mirante se vê, olhando para baixo, uma ilha de duelo.
- **Ilhas de duelo:** 4 temas bem diferentes (Praça, Fábrica, Porto, Torre). Cada uma com paleta própria, mas todas no mesmo estilo low poly cartoon.
- Ilhas e mirante cercados por céu claro e nuvens baixas; nada de fundo escuro ou espacial.
- Pode existir também uma **tela de informação** (no lobby) mostrando as 4 ilhas com nome e descrição curta, no estilo do painel "Mapas de duelo" do mockup. `[PROPOSTA]`

### T5 · Arsenal

**Função:** ver todas as armas e **escolher a skin** de cada uma. Não serve para escolher a arma da partida (isso é na T2).

**Layout (paisagem):**
```
┌─────────────────────────────────────────────────────────┐
│ ‹ ARSENAL   [TODAS][PRIMÁRIA][SECUNDÁRIA][CORPO A CORPO][HABILIDADE] │
│ ┌────┐┌────┐┌────┐┌────┐┌────┐      ┌───────────────────┐ │
│ │    ││    ││    ││    ││    │      │  (arma em 3D,     │ │
│ └────┘└────┘└────┘└────┘└────┘      │   girando devagar) │ │
│ ┌────┐┌────┐┌────┐┌────┐┌────┐      │ BOLINHA           │ │
│ │    ││    ││    ││    ││    │      │ Pistola confiável. │ │
│ └────┘└────┘└────┘└────┘└────┘      │ SKINS:            │ │
│ ┌────┐┌────┐┌────┐┌────┐┌────┐      │ [■][■][■][🔒][🔒]  │ │
│ │    ││    ││    ││    ││    │      │ [ EQUIPAR › ]     │ │
│ └────┘└────┘└────┘└────┘└────┘      └───────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

- **Abas:** Todas, Primária, Secundária, Corpo a corpo, Habilidade. `[DECIDIDO]`
- **Grade:** cartões de arma com a skin equipada e o nome próprio do jogo. Na aba Todas, agrupar por categoria.
- **Painel de detalhe:** arma em 3D girando devagar, nome, descrição de uma frase, **fila de skins** (miniaturas com moldura de raridade; as que o jogador não tem ficam com cadeado e preço), botão **Equipar**. `[DECIDIDO]`
- Aba **Habilidade:** mostra as cartas com suas skins de efeito (futuro) e leva à T1.
- Celular: o painel de detalhe abre por cima da grade (ocupando metade direita da tela).

### T6 · HUD em partida (primeira pessoa)

**Função:** tudo que o jogador vê enquanto joga. Regras: GDD seções 7, 8 e 13.

**Layout no celular (paisagem):**
```
┌──────────────────────────────────────────────────────────┐
│ ⚙        [😀😀] ♥♥♥♥♥  1:24  ♥♥♥ [😀😀]          (minimapa) │
│                                                           │
│                          +                         [mira*]│
│                                                           │
│ (joystick)                                   [  ATIRAR  ] │
│                    1 KILL                    [arma ⇄]     │
│ ▮▮▮▮ 50  escudo        [C][Q][E][X]              25 | ∞   │
│ ▮▮▮▮ 100 vida                                   [recarregar]│
└──────────────────────────────────────────────────────────┘
```

**Layout no PC:** igual, mas **sem** joystick e botões de toque, e com o bloco de dicas fixo:
```
 [B] Habilidades   [P] Configurações   [Tab] Placar
```
posicionado no canto inferior esquerdo, logo acima das barras de escudo e vida, sempre visível e discreto (texto `text.secondary`, chips de tecla).

Elementos:
- **Topo centro:** as duas duplas (2 avatares de cada lado, com a cor da equipe), vidas de cada dupla em corações, tempo da rodada no meio. Na Rodada da Virada, o tempo ganha um selo "VIRADA".
- **Topo direito:** minimapa redondo com o mapa da ilha atual, a posição do jogador e do parceiro (inimigos só aparecem quando vistos ou marcados por ping).
- **Topo esquerdo (celular):** engrenagem de configurações.
- **Centro:** retícula configurada pelo jogador.
- **Baixo esquerdo:** escudo (`shield`) e vida (`hp`) em barras com o número ao lado.
- **Baixo centro:** as cartas com a tecla embaixo de cada uma (chip). Carta em recarga mostra o tempo restante sobre o ícone; ult travada mostra cadeado até a 4ª rodada.
- **Baixo centro, acima das cartas:** aviso de abate `1 KILL`, `2 KILLS` (GDD 7.7).
- **Baixo direito:** munição do pente e `∞`; no celular, botões de atirar, mira (só em armas que usam), trocar arma e recarregar.
- **Painel B (Habilidades):** sobreposto, metade da tela, lista as cartas com nome, tecla, o que fazem e recarga. Fecha com B de novo.
- **Painel P (Configurações):** modal (T2 como modelo) com abas Retícula, Sensibilidade, Áudio, Voz, Acessibilidade. **O jogo não pausa.**
- Nada de neon no HUD.

---

## 5. Acessibilidade `[PROPOSTA]`

- Opção de cor do contorno de inimigo: vermelho (padrão), amarelo ou magenta, para daltônicos.
- Raridade, estado e equipe nunca indicados só por cor (sempre com texto ou ícone).
- Tamanho do texto da interface ajustável (100%, 115%, 130%).
- Opção de reduzir efeitos de tela (tremor da câmera, flashes).
- Legendas para avisos sonoros importantes (ex.: "Inimigo usou Tremor").

---

## 6. Checklist de revisão de qualquer tela

- [ ] Funciona no celular deitado, com o polegar alcançando os botões.
- [ ] No PC, sem botões de toque e com atalhos visíveis.
- [ ] Cores e fontes vêm do `Theme.luau`.
- [ ] Nenhum nome, logo ou ícone de outro jogo.
- [ ] Nenhum vermelho fora de perigo/inimigo/Celestial.
- [ ] Neon só onde a seção 2.6 permite.
- [ ] Nenhum modal com fundo preto opaco cobrindo o jogo.
- [ ] Contraste de texto de pelo menos 4,5:1.
- [ ] Textos vêm do `Strings.luau`.
