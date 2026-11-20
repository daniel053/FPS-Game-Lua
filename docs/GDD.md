# [NOME DO JOGO] — Documento de Game Design (GDD)

> **Versão:** 0.6 (rascunho para discussão)
> **Documentos irmãos:** `docs/ESTILO-E-TELAS.md` (telas e estilo), `docs/FASES.md` (fases de desenvolvimento), `docs/DADOS-JOGADOR.md` (dados salvos)
> **Plataforma:** Roblox, mobile em primeiro lugar (também PC e console)
> **Público:** 8 a 30 anos
> **Gênero:** tiro em **primeira pessoa**, arena 2v2, formato torneio por eliminação

### Mudanças desde a v0.5 (F10)

- **Mapas:** plantas da Praça, do Porto, da Fábrica e da Torre aprovadas e construídas com os kits; zonas com nome nos pings; pontos de escudo que recarregam; esteiras da Fábrica em movimento (seções 15.4 a 15.7 e 15.1).
- **Mirante octogonal** com piso de vidro e **lobby 3D** numa pracinha flutuante com o mundo ao fundo (seção 6.5 e ESTILO T3).
- **Primeira pessoa:** armas da F7 aprovadas como finais; mãos e braços finais (seção 3.1).
- **Cartas:** efeitos finais e arte própria de cada carta (seção 8.4).
- **Sons:** sintetizados por código, estilo FPS tático, nada retrô (seção 7.7).
- **Desempenho:** versão leve dos mapas no gráfico baixo ou com quadros baixos (seção 13.2).

### Mudanças desde a v0.4

- **Raridades de carta** (Comum azul, Épica roxa, Lendária amarela, Celestial vermelha com neon) e função **Girar cartas** (seção 8.9).
- **Arma corpo a corpo** como terceiro slot (seção 7.2).
- **Tela de preparação vira um modal** sobre o mapa, com carta e arma juntas (seção 4.10 e `ESTILO-E-TELAS.md`).
- **Mirante = ilha flutuante central de chão plano**, acima das 4 ilhas de duelo; quem está nela olha para baixo e assiste aos duelos (seção 6.5).
- **Mapas renomeados para os temas definidos:** Praça, Fábrica, Porto e Torre (seção 15).
- **Atalhos de PC visíveis na tela:** B para habilidades, P para configurações (seção 13.3).
- **Direção de arte da interface:** acento roxo no lugar do vermelho; exceções de neon definidas (seção 14).

### Mudanças desde a v0.3

- **Cartas fixas na primeira versão:** todos têm as mesmas 4 cartas (Nuvem C, Impulso Q, Tremor E, Renascer X), dadas no tutorial. Loja de cartas e escolha entre opções ficam para depois (seções 8.8 e 19).
- **Arsenal completo** no formato do Valorant: 18 armas em 7 categorias, com nomes próprios (seção 7.2).
- **Luneta com 135 de dano** por tiro: nunca derruba com um tiro quem tem vida cheia.
- **Pistola secundária** a partir da 3ª rodada.
- **Controles de cada arma para celular, PC e controle**, incluindo tiro automático por tipo de arma (seção 7.2.6).

### Mudanças desde a v0.2

- **Uma carta básica por partida.** Coleção limitada a **uma carta por tecla** (C, Q, E, X); a loja esconde cartas de uma tecla que o jogador já tem (seção 8).
- **Ult liberada a partir da 4ª rodada** para todos, sem sistema de carga (seção 8.5).
- **Jogador sem par joga sozinho (1v2)**, sem bot e sem bônus (seção 4.2).
- **Progressão de armas por rodada**: pistolas nas rodadas 1–2, armas médias na 3ª, armas pesadas da 4ª em diante. Dez armas com números propostos (seção 7.2).
- **Tela de preparação** a cada rodada: arma no topo, carta embaixo (seção 4.10).

### Mudanças desde a v0.1

- Público ampliado para 8 a 30 anos.
- Câmera sempre em primeira pessoa (terceira pessoa proibida).
- Novo **tutorial** em place separado, feito uma única vez (seção 5).
- Novo sistema de **elo** (Bronze a Deus, mais o elo ADM) (seção 9).
- Servidor reestruturado: **lobby separado da partida**, fila com início aos 7 jogadores e separação por nível quando houver gente suficiente (seção 6).
- Novo sistema de **cartas de habilidade**: escolha em 15 s no início da partida, cada habilidade com tecla fixa (seção 8).
- Marcação de jogadores: contorno vermelho no inimigo, contorno do aliado só atrás da parede (seção 7.6).
- Sem sangue; sons de tiro e de abate definidos; aviso de abate na tela (seção 7.7).
- Equipe eliminada assiste do mirante ou vai para outra partida; dupla de amigos pode seguir junta (seção 4.8).

---

## 0. Como usar este documento (leitura obrigatória para o Claude Code)

Este documento é a fonte da verdade do jogo. Ele é escrito para ser lido por quem vai implementar.

**Marcadores de status.** Cada regra tem um marcador:

| Marcador | Significado | O que o implementador faz |
|---|---|---|
| `[DECIDIDO]` | Definido pelo dono do projeto | Implementar exatamente assim |
| `[PROPOSTA]` | Sugestão ainda não confirmada | Implementar, mas deixar fácil de mudar (valor em config) |
| `[ABERTO]` | Ainda não definido | Não implementar; perguntar antes |

**Regras gerais de implementação.**

1. Todo número de balanceamento (dano, tempo, preço, recarga, tamanho, limites de fila, faixas de elo) fica em módulos de configuração em `src/shared/Config/`, nunca espalhado no código. Os valores deste documento são o ponto de partida.
2. O servidor é a autoridade de tudo: dano, vidas, moedas, elo, compras, cooldowns. O cliente só pede e mostra.
3. Luau em modo `--!strict`.
4. Toda tela e todo controle precisam funcionar no celular antes de funcionar no PC.
5. Seguir as fases da seção 17. Não pular fase.
6. Toda tela e todo elemento visual seguem `docs/ESTILO-E-TELAS.md`. Se este documento e o de estilo discordarem sobre regra de jogo, vale este; sobre aparência, vale o de estilo.
7. Nunca usar nomes, logos, sons, ícones ou arte de outros jogos (incluindo os nomes de armas que aparecem na imagem de referência). A coluna "Referência" das tabelas é só para entender o papel de cada item.

---

## 1. Visão

**Resumo em uma frase.** Duplas se enfrentam em duelos rápidos de 2v2 em primeira pessoa, em arenas cartoon, com habilidades simples e tiroteios longos, até sobrar uma dupla campeã.

**Público.** 8 a 30 anos. `[DECIDIDO]` As crianças são a maior parte dos jogadores do Roblox, mas o jogo precisa ser interessante para adultos também. Na prática:

- **Fácil de entrar:** controles simples, tutorial guiado, habilidades com efeito visível.
- **Profundo para quem joga sério:** elo, posicionamento, combinação de habilidades na dupla, mapas com rotas e alturas.
- **Visual cartoon, mas não infantilizado:** nada de cores bebê ou interface de desenho animado para menores; o tom é "divertido e bem-feito".

**Pilares.**

1. **Jogar junto.** O jogo existe para jogar em dupla com um amigo ou fazer um amigo novo.
2. **Luta que dura.** Ninguém morre num piscar de olhos. Sem tiro na cabeça que mata. Dá tempo de reagir e virar o duelo.
3. **Fácil de entender, difícil de dominar.**
4. **Celular primeiro.**

**Referência de inspiração.** O formato vem do modo de duelos curtos 2v2 de jogos de tiro tático (como a Contenda do Valorant). Copiamos **a mecânica, o ritmo e o padrão de teclas das habilidades**, nunca a arte, nomes, mapas, sons ou interface. `[DECIDIDO]`

---

## 2. Glossário

| Termo | Definição |
|---|---|
| **Tutorial** | Place separado, jogado uma única vez na primeira entrada. |
| **Lobby** | Place onde os jogadores esperam na fila, compram e configuram. |
| **Fila** | Lista de jogadores esperando partida no lobby. |
| **Servidor de partida** | Servidor reservado criado para uma partida. Tem 4 arenas e um mirante. |
| **Mirante** | Área elevada no servidor de partida, de onde se assiste aos duelos. |
| **Arena** | Um dos 4 espaços de combate do servidor de partida. Cada arena recebe um mapa. |
| **Dupla** | Dois jogadores do mesmo time. A unidade que compete. |
| **Partida** | Um torneio completo, do começo até sobrar uma dupla. |
| **Rodada** | Um duelo 2v2 dentro de uma partida. |
| **Vida** | Ponto da dupla na partida. Toda dupla começa com 5. Perder a rodada tira 1. |
| **Rodada da Virada** | Rodada especial que acontece uma vez por partida (seção 4.5). |
| **Folga** | Quando sobra uma dupla sem adversário na rodada. |
| **Carta** | Uma habilidade que o jogador possui e pode escolher levar para a partida. |
| **Elo** | Nível competitivo do jogador (Bronze a Deus). |
| **HP** | Pontos de saúde do personagem (100). |
| **Escudo** | Camada extra que absorve dano antes do HP (50). |
| **Moedas** | Dinheiro do jogo, ganho jogando. |
| **Ult** | Habilidade forte, carregada ao longo das rodadas. |

---

## 3. Personagem e câmera

### 3.1 Câmera `[DECIDIDO]`

- **Sempre primeira pessoa.** Em nenhum momento, em nenhum place (tutorial, lobby, partida, mirante), a câmera vai para terceira pessoa.
- Implementação: travar a câmera em primeira pessoa no jogo inteiro e não oferecer nenhuma opção de troca. Exceções apenas para câmeras cinematográficas sem controle do jogador (ex.: cerimônia de campeão, telão) — `[ABERTO]`, confirmar se até essas devem ser em primeira pessoa.
- Ao assistir (morto na rodada ou no mirante), a visão é a **primeira pessoa do jogador assistido** ou a vista fixa do mirante.
- Braços e arma visíveis na tela (modelo de primeira pessoa), em low poly. Modelos das armas da F7 aprovados como finais; mãos e braços finais na F10 `[DECIDIDO]` (dono do projeto).

### 3.2 Personagem

- Cada jogador aparece com o **próprio avatar do Roblox**, com o tamanho do corpo igualado (escalas padrão), para todos terem a mesma altura. `[DECIDIDO]` (F6; antes era um corpo base igual para todos, sem avatar)
- Jogadores de teste e avatares que não carregam usam o corpo base de blocos.
- Risco aceito: roupas vermelhas do avatar não podem ser controladas pelo jogo; o contorno e a barra do inimigo (seção 7.6) continuam sendo a identificação principal.
- Hitbox: cápsula única, igual para todos. Não existe região de cabeça com dano extra. `[DECIDIDO]`

### 3.3 Cor da equipe `[DECIDIDO]`

- Cada dupla tem uma cor na partida. Ela **não** fica no corpo do personagem (a faixa nos braços e o capacete saíram na F6): dentro da ilha, aliado e inimigo são reconhecidos pela marcação verde e vermelha (seção 7.6). `[DECIDIDO]`
- A cor da equipe aparece no **HUD e no placar** e, só para quem assiste do **mirante**, no nome sobre cada jogador que está duelando. `[DECIDIDO]`
- A manga da arma em primeira pessoa é neutra (sem cor de equipe).

| Time | Hex de referência |
|---|---|
| Azul | `#2F6BFF` |
| Laranja | `#E5671A` |
| Verde | `#1E9E5A` |
| Roxo | `#7B48D6` |
| Amarelo | `#F2C230` |
| Branco | `#F2F4F8` |
| Rosa | `#E0559B` |
| Ciano | `#2BA8B8` |

Observação: o **vermelho não é cor de equipe**, porque é reservado ao contorno de inimigo (seção 7.6).

---

## 4. Loop da partida

### 4.1 Máquina de estados do servidor de partida

```
RECEBENDO_JOGADORES (teleportados do lobby, até 20 s)
  → FORMANDO_DUPLAS
  → loop de rodadas:
       SORTEIO_CONFRONTOS → TELEPORTE (3 s)
       → PREPARACAO (15 s na 1ª rodada, 10 s nas demais, congelado;
                     tela de arma + carta, seção 4.10)
       → COMBATE (até 90 s) → FIM_RODADA (5 s, placar) → volta ao mirante
  → (sobrou 1 dupla) CAMPEAO (15 s, cerimônia)
  → RECOMPENSAS E ELO
  → TELA_FINAL (escolhas da seção 4.8) → teleporte de volta ao lobby
```

### 4.2 Formação de duplas

Ordem de prioridade: `[PROPOSTA]`

1. **Dupla fixa** vinda do lobby (amigos que entraram juntos na fila).
2. **Amigos no Roblox** que caíram na mesma partida.
3. **Solo com solo**, pareando por elo parecido.
4. **Jogador sem par** (número ímpar de jogadores, ex.: 7): **joga sozinho, 1v2**. Sem bot e sem nenhum bônus de escudo, vida ou dano. Conta como uma dupla de uma pessoa só, com 5 vidas como qualquer outra. `[DECIDIDO]`
   - Quem fica sem par: o de **maior elo** entre os que sobraram sem dupla (é quem melhor aguenta o 1v2). `[PROPOSTA]` (F3, `MatchConfig.OddPlayerSolo`)

### 4.3 Rodada (duelo 2v2)

- Cada dupla nasce em uma base no lado oposto do mapa.
- Não existe renascer dentro da rodada. Morreu, assiste o parceiro em primeira pessoa. (Exceção: ult Renascer.)
- A rodada termina quando as duas pessoas de uma dupla caem, ou o tempo acaba (90 s).
- A dupla que perde a rodada perde **1 vida**. `[DECIDIDO]`
- Todo mundo começa a rodada seguinte com HP e escudo cheios.

### 4.4 Tempo esgotado e zona `[PROPOSTA]`

- Aos 60 s, uma zona fecha até o centro do mapa em 30 s. Fora dela: 10 de dano por segundo, ignora escudo.
- Aos 90 s com as duas duplas vivas: vence quem tiver mais HP + escudo somados. Empate exato: ninguém perde vida.

### 4.5 Rodada da Virada `[DECIDIDO]`

- Acontece **uma única vez por partida**.
- Gatilho: a primeira vez que qualquer dupla fica com **1 vida**.
- A rodada seguinte é a Rodada da Virada, em todas as arenas.
- Toda dupla que **vencer** nessa rodada ganha **+1 vida**, teto 5. Quem perde, perde 1 vida normalmente.
- Aviso grande na tela, música e cor diferentes.
- Depois dela, a regra não volta naquela partida.
- Na final (seção 4.7) as vidas não contam, então não existe Virada nela: se a primeira dupla com 1 vida aparecer na mesma rodada em que sobram 2 duplas, a partida vai direto para a final. `[DECIDIDO]` (consequência da regra da final, F3)

### 4.6 Sorteio de confrontos `[PROPOSTA]`

- A cada rodada, as duplas vivas são pareadas de forma aleatória, evitando repetir o confronto anterior quando possível.
- **Número ímpar de duplas:** uma dupla fica de folga. A folga gira, e tem prioridade quem tem **mais** vidas.
- A dupla de folga não ganha nem perde vida e assiste do mirante.
- Cada arena recebe um mapa sorteado entre os 4, sem repetir o mesmo mapa duas rodadas seguidas na mesma arena.
  - Como cada ilha em volta do mirante é um mapa fixo, na prática o sorteio é **da ilha de cada duelo**: cada duelo vai para uma ilha diferente e a dupla não joga na mesma ilha duas rodadas seguidas, quando possível. `[PROPOSTA]` (F3)
- "A folga gira" quer dizer: nenhuma dupla repete a folga antes de todas as duplas vivas terem tido a sua; ao recomeçar o ciclo, quem teve a última folga não repete logo em seguida. `[PROPOSTA]` (F3)

### 4.7 Fim da partida

- Dupla com 0 vidas é eliminada (ver 4.8).
- Quando sobram 2 duplas: final melhor de 3 numa arena só, com todos assistindo. `[DECIDIDO]` (F3)
  - Na final **as vidas param de contar**: vence quem ganhar 2 rodadas primeiro, não importa quantas vidas tem. Empate (tempo esgotado com HP + escudo iguais) não dá ponto a ninguém.
  - Com 4 jogadores (2 duplas desde o começo), a partida inteira é a final.
  - A final pode ser desligada em `MatchConfig.Final.Enabled` (aí as vidas continuam contando até sobrar uma dupla).
- Duração alvo de uma partida: 8 a 12 minutos. `[PROPOSTA]`

### 4.8 Equipe eliminada e continuidade da dupla `[DECIDIDO]`

Quando uma dupla é eliminada, cada jogador vê uma tela com duas opções:

1. **Assistir** — fica no **mirante** (área elevada sobre as arenas) vendo os duelos até o fim, e recebe as recompensas finais normalmente.
2. **Nova partida** — volta ao lobby e entra direto na fila de uma nova partida. Recompensas da partida atual (moedas e elo da colocação já definida) são creditadas na saída.

**Seguir com o amigo.** Se os dois da dupla escolherem "Nova partida", aparece a pergunta **"Ir para a próxima partida com [nome]?"** para os dois:

- Os dois aceitam → entram na fila **como dupla fixa** e caem juntos na próxima partida.
- Um recusa → cada um vai sozinho para a fila.

A mesma pergunta aparece ao fim da partida para todos os jogadores, para que amigos (novos ou antigos) não se percam.

- Na tela final, a dupla que respondeu "sim" dos dois lados volta junta ao lobby e entra direto na fila. Se um dos dois aperta **Nova partida** depois dos dois "sim", o parceiro vai junto. `[DECIDIDO]` (F5)

### 4.9 Casos especiais

| Situação | Regra |
|---|---|
| Um jogador sai no meio da partida | O parceiro joga sozinho (1v2) até o fim da rodada; segue sozinho no resto da partida. `[PROPOSTA]` |
| Alguém da fila não chegou à partida | A partida espera até 20 s e segue com quem chegou, a partir de **2 jogadores**. Com menos de 2, quem chegou volta ao lobby e entra direto na fila, **na frente**. `[DECIDIDO]` (F5) |
| Jogador que não estava na composição da partida | Volta ao lobby (servidor reservado de outro grupo). `[DECIDIDO]` (F5) |
| Os dois saem | Dupla eliminada. |
| Jogador ausente (AFK) 30 s em combate | Aviso; aos 60 s é mandado de volta ao lobby. |

### 4.10 Tela de preparação `[DECIDIDO]` com tempos `[PROPOSTA]`

Aparece no começo de **toda rodada**, com o jogador já **dentro do mapa**, congelado na base. É um **modal (pop-up) sobre o jogo**, nunca uma tela separada com fundo preto: o mapa continua visível atrás. Layout detalhado: `ESTILO-E-TELAS.md`, tela T2.

- **Uma só janela** para carta e arma, em duas etapas: 1) carta (só na 1ª rodada), 2) armas. Botão **Confirmar** fecha o modal.
- Cada arma aparece **uma única vez** (sem imagem repetida em outro lugar do modal).
- **Armas** liberadas para aquela rodada (seção 7.2), organizadas por categoria como no menu de armas do Valorant. A partir da 3ª rodada, duas escolhas: primária e secundária. A escolha vale só para a rodada. Se não escolher a tempo, mantém a escolha anterior (ou a primeira arma da lista). `[PROPOSTA]`
- **No celular:** uma aba por categoria (Pistolas, Submetralhadoras, Escopetas, Fuzis leves, Fuzis, Snipers, Metralhadoras), cartões grandes (mín. 64 px) e um botão **"Repetir última escolha"** para decidir em um toque. No PC, todas as categorias aparecem lado a lado em colunas. `[PROPOSTA]`
- **Carta.** Só pode ser escolhida na **1ª rodada** (15 s). Nas rodadas seguintes a carta escolhida aparece travada. Se não escolheu na 1ª rodada, joga a partida inteira sem carta. `[DECIDIDO]`
- Ult (X): aparece com cadeado até a 4ª rodada (seção 8.5).
- Mostra em tempo real a arma e a carta do parceiro, para a dupla combinar.
- Tempo: 15 s na 1ª rodada, 10 s nas demais.

---

## 5. Tutorial `[DECIDIDO]`

### 5.1 Regras gerais

- Place **separado** dentro da mesma experiência.
- Todo jogador novo cai no tutorial ao entrar pela primeira vez.
- Ao terminar, o perfil marca `tutorialDone = true` e o jogador é levado ao lobby. **Nunca mais acessa o tutorial.**
- As configurações feitas no tutorial (sensibilidade, retícula, voz) continuam disponíveis no menu de configurações do lobby e da partida.
- Pode ser pulado? **Só as configurações** (voz, sensibilidade e retícula) têm botão Pular, que mantém os valores padrão. Movimento, armas e cartas são obrigatórios. `[DECIDIDO]` (F6)
- Duração alvo: 3 a 5 minutos. `[PROPOSTA]`

### 5.2 Etapas

1. **Boas-vindas** — tela curta com o objetivo do jogo em uma frase.
2. **Movimento** — andar, pular, olhar (adaptado ao dispositivo: toque, teclado/mouse ou controle).
3. **Armas** — o jogador testa uma arma de cada categoria (pistola, submetralhadora, escopeta, fuzil, sniper, metralhadora) acertando alvos. Ensina: atirar, mirar/modo alternativo, recarregar, trocar primária e secundária, e como as armas mudam a cada fase da partida (pistolas → médias → pesadas). No celular, ensina também o tiro automático.
4. **Cartas de habilidade** — uma por vez. Para cada carta:
   - a carta aparece grande na tela, com nome, tecla fixa (C, Q, E ou X) e uma frase do que faz;
   - o jogador usa a habilidade num desafio curto (ex.: Impulso para alcançar uma plataforma);
   - ao completar, **"Você ganhou a carta [nome]!"** com animação, e a carta entra na coleção.
   - Cartas ensinadas: as cartas iniciais (seção 8.4).
5. **Voz** — tela bonita e chamativa explicando que conversar com a dupla faz muita diferença. Mostra:
   - se o chat de voz já está disponível para a conta, um teste de microfone;
   - se não está, como ativar nas configurações do Roblox (ativação e regras de idade são da plataforma; o jogo não ativa nada sozinho);
   - botão "Agora não", sem culpa.
6. **Sensibilidade da mira** — campo de treino com alvos em movimento e um controle deslizante. Separado para toque, mouse e controle, e uma segunda sensibilidade para quando a mira de sniper está aberta.
7. **Retícula** — editor da mira: formato (ponto, cruz, círculo), cor, tamanho, espessura, contorno, com prévia ao vivo.
8. **Final** — "Você está pronto!" e botão **"Ir para o lobby"**.

---

## 6. Servidor, lobby e matchmaking

### 6.1 Estrutura de places `[PROPOSTA]`

| Place | Função |
|---|---|
| **Tutorial** | Primeira entrada (seção 5). |
| **Lobby** | Ponto de entrada normal. Fila, loja, coleção de cartas, configurações, ranking, treino. |
| **Partida** | Servidor reservado, criado por partida. 4 arenas + mirante. |

- Do lobby para a partida: o lobby forma o grupo e teleporta todos juntos para um servidor reservado novo.
- Da partida para o lobby: teleporte ao sair, com o que o jogador escolheu (assistir ou nova partida).

### 6.2 Fila `[DECIDIDO]` com valores `[PROPOSTA]`

- O jogador entra na fila pelo lobby (sozinho ou em dupla fixa).
- A partida é montada quando a fila junta **7 jogadores**. `[DECIDIDO]`
- Ao atingir 7, a fila espera mais **15 s** para completar até **16 jogadores**, e então teleporta o grupo. `[PROPOSTA]`
- **Flexibilidade com poucos jogadores:** se a fila não chegar a 7 em **20 s**, a partida começa com quem houver, a partir de **4 jogadores**. O tempo é `[DECIDIDO]` (F5; era 60 s, longo demais no teste); o mínimo de 4 continua `[PROPOSTA]`.
- **Modo de teste (`DEV_`):** com 2 ou mais na fila, a partida sai em **5 s** (as faixas também se juntam em 5 s). `[DECIDIDO]` (F5)
- A fila é **compartilhada entre todos os servidores de lobby** (não só o servidor onde o jogador está), para juntar gente mais rápido.
- 7 jogadores formam 3 duplas e 1 jogador sem par, que joga sozinho (1v2), sem bônus, como na seção 4.2. `[DECIDIDO]`

### 6.3 Separação por nível `[PROPOSTA]`

Objetivo: jogadores muito bons não estragarem a experiência de quem está começando.

- Duas faixas de fila:
  - **Aprendizes:** contas com menos de 10 partidas, Bronze e Prata.
  - **Experientes:** Ouro, Platina, Mestre e Deus.
- **Só separa quando há gente suficiente.** Regra: se uma faixa não consegue juntar 7 jogadores em 45 s, ela se junta com a outra faixa naquela partida.
- No começo do jogo, com poucos jogadores, na prática todo mundo joga junto. Isso é esperado.
- Dentro da partida, as duplas solo são pareadas por elo parecido.
- Dupla fixa com elos diferentes entra na fila do **maior** elo da dupla (para ninguém usar um amigo novato para jogar na faixa fácil).

### 6.4 Lobby

- **Botão principal "Jogar"** (entra na fila), com estado da fila visível ("Procurando partida… 5/7").
- **Convidar amigos** (convite nativo do Roblox) e **entrar em fila com amigo** (forma dupla fixa).
- **Coleção de cartas** e loja.
- **Configurações:** sensibilidade, retícula, áudio, voz, gráficos.
- **Ranking** (top do servidor e global, por elo).
- **Treino:** alvos para testar armas e cartas enquanto espera na fila.
- Câmera do lobby em primeira pessoa (seção 3.1).

Grupo de 2 e fila `[DECIDIDO]` (F5):
- O grupo se forma com **qualquer jogador do mesmo servidor de lobby**, por convite dentro do jogo (ele aceita ou recusa). Amigos de fora chegam pelo convite nativo do Roblox e caem no mesmo servidor. Juntar-se a alguém de outro servidor de lobby fica fora.
- Cada um aperta **Jogar** e fica "Pronto"; com os 2 prontos, a dupla entra na fila como dupla fixa. Qualquer um pode cancelar, e a dupla sai da fila.
- Se um dos dois sai do jogo ou da dupla, o outro sai da fila com um aviso e precisa apertar Jogar de novo.
- A área de **Treino** fica para depois (não entra na F5).

### 6.5 Mirante (dentro do servidor de partida)

- **Ilha flutuante central, de chão plano** (sem torre, sem prédio no meio), posicionada **acima** das 4 ilhas de duelo. `[DECIDIDO]`
- **Formato de octógono**, com um lado de frente para cada ilha. `[DECIDIDO]` (F10)
- **Piso levemente transparente** (vidro claro), para quem está no mirante ver os duelos olhando para baixo sem precisar ir até a borda. Grade e aro opacos, para o piso continuar parecendo chão. Sem rocha embaixo. `[DECIDIDO]` (F10; transparência em `MapConfig.Mirante.GlassTransparency` `[PROPOSTA]`)
- As 4 ilhas de duelo ficam em volta e abaixo dela, uma de cada lado: norte, leste, sul e oeste. Quem está no mirante **olha para baixo** para assistir ao duelo daquela ilha. `[DECIDIDO]`
- **Sem interferência:** ninguém no mirante pode atirar, usar carta ou afetar os duelos. Bordas com barreira invisível. `[DECIDIDO]`
- As ilhas de duelo precisam ser **legíveis de cima**: áreas cobertas (galpões, túneis) têm telhado que fica transparente só para quem está no mirante (ajuste local no cliente). Quem joga na arena continua vendo o telhado normalmente. `[PROPOSTA]`
- Os jogadores na arena não veem os espectadores do mirante (para não revelar nada nem distrair). `[PROPOSTA]`
- Telões flutuantes opcionais com a visão em primeira pessoa de cada duelo, para quem prefere assistir de perto. `[PROPOSTA]`
- Ficam aqui: duplas de folga, duplas eliminadas que escolheram assistir, e todos entre uma rodada e outra.
- Placar da partida com todas as duplas, cores e vidas.

### 6.6 Servidores privados

- Permitidos para grupos de amigos. Preço em Robux `[ABERTO]`.
- Partidas privadas **não mexem no elo** e dão **metade das moedas**. `[DECIDIDO]` (F9; as partidas privadas em si chegam na F11)

---

## 7. Combate

### 7.1 Saúde `[PROPOSTA]`

| Atributo | Valor |
|---|---|
| HP | 100 |
| Escudo | 50 |
| Regeneração de escudo | após 4 s sem levar dano, 10 por segundo |
| Regeneração de HP | não existe durante a rodada |
| Multiplicador de cabeça | **não existe** `[DECIDIDO]` |

### 7.2 Armas e progressão por rodada

#### 7.2.1 Regras gerais `[DECIDIDO]`

- **O arsenal segue o do Valorant**: mesmas categorias, mesma organização e o mesmo papel de cada arma, adaptados para este jogo (sem tiro na cabeça e com 150 de vida total). Nomes, modelos, sons e interface são **próprios**; a coluna "Referência" existe só para o implementador entender o papel da arma e nunca aparece no jogo.
- Não existe compra de armas. As armas são **liberadas por fase**, conforme o número da rodada, e todos têm acesso às mesmas.
- Cada jogador carrega **duas armas de fogo**: uma **primária** e uma **secundária (pistola)**. Nas rodadas 1 e 2 só existe a pistola.
- Todos carregam também uma arma **corpo a corpo**, sempre disponível (seção 7.2.7). Ela não é escolhida a cada rodada; o jogador só escolhe a skin dela no Arsenal.
- Objetivo: obrigar todo mundo a jogar com cada tipo de arma ao longo da partida.
- **Nenhuma arma mata com um tiro.** O maior dano possível de um único tiro é **135** (Luneta). Sem multiplicador de cabeça.
- Skins mudam só a aparência.

#### 7.2.2 Fases

| Fase | Rodadas | Primária | Secundária |
|---|---|---|---|
| **Pistolas** | 1ª e 2ª | — (a pistola é a única arma) | Bolinha, Chumbinho, Zumbido, Precisa |
| **Médias** | 3ª | Ferrão, Vespa, Balde, Varredor, Tático, Atirador, Martelo, Mata-Pato | qualquer pistola + **Tambor** |
| **Pesadas** | 4ª até o fim | Rajada, Trovão, Moedor, Gêmea, Luneta | qualquer pistola + Tambor |

- Da 4ª rodada em diante, **só** as primárias da fase Pesadas podem ser escolhidas. `[DECIDIDO]`
- O Tambor (revólver pesado) só fica disponível a partir da 3ª rodada. `[PROPOSTA]`
- Moedor e Gêmea entram na fase Pesadas, junto com Rajada, Trovão e Luneta. `[DECIDIDO]`

#### 7.2.3 Tabela de armas `[PROPOSTA]`

Alvo: 150 de vida total. Quanto mais avançada a fase, mais rápido se derruba, mas o tiroteio continua longo. Exceção natural: escopetas coladas no alvo, que precisam acertar todos os bagos.

| Arma | Categoria | Referência (papel) | Modo | Dano por tiro | Cadência | Pente | Recarga | Tiros p/ derrubar | Tempo p/ derrubar |
|---|---|---|---|---|---|---|---|---|---|
| **Bolinha** | Pistola | Classic | semi; alternativo: rajada de 3 | 13 | 4/s | 12 | 1,75 s | 12 | ~2,8 s |
| **Chumbinho** | Pistola | Shorty | escopeta de bolso | 12 bagos × 6 = 72 | 1,3/s | 3 | 1,75 s | 3 | ~1,5 s (colado) |
| **Zumbido** | Pistola | Frenzy | auto | 9 | 10/s | 20 | 1,6 s | 17 | ~1,6 s |
| **Precisa** | Pistola | Ghost | semi | 15 | 4,5/s | 15 | 1,5 s | 10 | ~2,0 s |
| **Tambor** | Pistola | Sheriff | semi | 40 | 1,6/s | 6 | 2,25 s | 4 | ~1,9 s |
| **Ferrão** | Submetralhadora | Stinger | auto; alternativo: rajada de 4 | 8 | 13/s | 25 | 2,25 s | 19 | ~1,4 s |
| **Vespa** | Submetralhadora | Spectre | auto | 9 | 11/s | 30 | 2,25 s | 17 | ~1,45 s |
| **Balde** | Escopeta | Bucky | semi; alternativo: tiro concentrado | 15 bagos × 4 = 60 | 1,1/s | 5 | 2,5 s | 3 | ~1,8 s (colado) |
| **Varredor** | Escopeta | Judge | auto | 10 bagos × 3,5 = 35 | 3/s | 7 | 2,2 s | 5 | ~1,35 s (colado) |
| **Tático** | Fuzil leve | Bulldog | auto; mirando: rajada de 3 | 10 | 9/s | 24 | 2,5 s | 15 | ~1,6 s |
| **Atirador** | Fuzil leve | Guardian | semi, com mira curta | 30 | 2,8/s | 12 | 2,5 s | 5 | ~1,45 s |
| **Martelo** | Metralhadora | Ares | auto, aquece em 0,5 s | 9 | 11/s | 50 | 3,25 s | 17 | ~2,0 s |
| **Mata-Pato** | Sniper | Marshal | ferrolho, com mira | 55 | 1 a cada 1,1 s | 5 | 2,5 s | 3 | ~2,2 s |
| **Rajada** | Fuzil | Phantom | auto, rastro discreto | 11 | 9/s | 30 | 2,5 s | 14 | ~1,45 s |
| **Trovão** | Fuzil | Vandal | auto | 16 | 6,5/s | 25 | 2,5 s | 10 | ~1,4 s |
| **Moedor** | Metralhadora | Odin | auto, aquece em 1 s | 9 | 12/s | 100 | 5,0 s | 17 | ~2,4 s |
| **Gêmea** | Sniper | Outlaw | 2 tiros rápidos, depois recarga | 70 | 2 tiros em 0,4 s | 2 | 2,8 s | 3 | ~3,2 s (precisa recarregar) |
| **Luneta** | Sniper | Operator | ferrolho, com mira | **135** | 1 a cada 1,6 s | 5 | 3,7 s | 2 | ~1,6 s |

#### 7.2.4 Identidade de cada arma `[PROPOSTA]`

**Pistolas**
- **Bolinha:** a arma de começo, fácil. Modo alternativo dispara rajada de 3 com espalhamento, boa de perto.
- **Chumbinho:** só funciona colado; de longe os bagos se espalham e o dano quase some.
- **Zumbido:** pistola automática; forte de perto, fraca de longe.
- **Precisa:** a pistola de média distância; pouca perda de dano.
- **Tambor:** poucos tiros e muito dano; recompensa calma.

**Submetralhadoras**
- **Ferrão:** a mais rápida de perto; espalha muito em movimento contínuo.
- **Vespa:** a mais equilibrada; atirar andando é preciso.

**Escopetas**
- **Balde:** um tiro forte por vez; modo alternativo concentra os bagos para alcançar um pouco mais longe.
- **Varredor:** automática, ótima para defender cantos e portas.

**Fuzis leves**
- **Tático:** automático parado ou andando; mirando, dispara em rajadas precisas.
- **Atirador:** semiautomático com mira curta; bom em média e longa distância.

**Metralhadoras**
- **Martelo:** pente grande, demora 0,5 s para chegar ao ritmo máximo, deixa o jogador 15% mais lento.
- **Moedor:** pente enorme, aquece em 1 s, atravessa coberturas finas com dano reduzido; 20% mais lento.

**Fuzis**
- **Rajada:** o fuzil fácil: pouco recuo, rastro dos tiros discreto (difícil saber de onde vem), perde um pouco de dano de longe.
- **Trovão:** o fuzil difícil: mais dano por tiro, **sem perda de dano com a distância**, recuo forte.

**Snipers**
- **Mata-Pato:** sniper leve, rápida de manusear.
- **Gêmea:** dois tiros seguidos de 70 (140, sem derrubar alguém com vida cheia); obriga a terminar com a pistola ou esperar a recarga.
- **Luneta:** a sniper pesada. 135 por tiro: **nunca derruba alguém com vida cheia com um tiro**, mas derruba quem já levou 15 ou mais de dano. Mirando, o jogador fica 30% mais lento.
- Todas as snipers: sem mira, o tiro espalha muito.

#### 7.2.5 Outras regras

- Munição reserva infinita.
- Perda de dano com a distância e padrões de recuo: valores por arma em config, ajustados em teste.
- O jogador escolhe uma arma da fase atual; se não escolher a tempo, recebe a escolha anterior (ou, na primeira vez, a primeira arma da lista). `[PROPOSTA]`

#### 7.2.6 Armas no celular e no PC `[PROPOSTA]`

Toda arma precisa ser igualmente jogável com toque, mouse e controle.

| Ação | PC (teclado e mouse) | Celular (toque) | Controle |
|---|---|---|---|
| Atirar | botão esquerdo | botão Atirar (ou tiro automático) | gatilho direito |
| Mirar / modo alternativo | botão direito | botão Mira (só aparece em armas que têm mira ou modo alternativo) | gatilho esquerdo |
| Recarregar | R | botão Recarregar (recarga automática ao esvaziar) | X / Quadrado |
| Primária / secundária / corpo a corpo | 1 / 2 / 3 / roda do mouse | botão de troca (toque alterna primária ↔ secundária; segurar abre as 3 opções) | Y / Triângulo |
| Cartas | C, Q, E, X | botões fixos (seção 13.1) | botões de ombro: **LB** = a carta básica escolhida, **RB** = a ult `[PROPOSTA]` (F4) |

**Tiro automático no celular, por tipo de arma:**

| Tipo | Comportamento |
|---|---|
| Automáticas (fuzis, submetralhadoras, metralhadoras, Zumbido) | atira enquanto a retícula estiver sobre um inimigo |
| Semiautomáticas (Bolinha, Precisa, Tambor, Atirador) | atira na cadência máxima enquanto a retícula estiver sobre um inimigo |
| Escopetas | atira só quando o inimigo está dentro do alcance eficaz |
| Snipers | atira só **com a mira aberta** e a retícula sobre o inimigo por 0,2 s |
| Metralhadoras com aquecimento | começam a aquecer quando a retícula se aproxima do inimigo |

**Outras adaptações:**
- Sensibilidade separada para mira aberta (snipers e Atirador), configurável no tutorial e no menu.
- Assistência de mira leve para toque e controle; desligada no mouse.
- Recuo com padrão simples e previsível em todas as armas, para quem usa toque conseguir controlar.
- Botão de mira e de modo alternativo só aparece quando a arma equipada usa.

#### 7.2.7 Corpo a corpo `[PROPOSTA]`

| Atributo | Valor |
|---|---|
| Nome padrão | **Bastão** |
| Dano por golpe | 50 |
| Golpes por segundo | 2 |
| Alcance | 4 studs |
| Golpes para derrubar | 3 (~1,0 s colado) |
| Golpe forte (botão direito / segurar no celular) | 75 de dano, 1 golpe a cada 1,2 s |
| Velocidade com ele na mão | +10% |

- Útil para se mover mais rápido entre coberturas e para terminar um inimigo machucado de perto.
- Skins de corpo a corpo são itens de destaque na loja (cada tema muda o objeto: raquete, guarda-chuva, peixe de borracha…).

### 7.3 Tiro e acerto

- Tiro instantâneo (hitscan) com rastro visual.
- O cliente mostra o tiro na hora; o servidor valida e aplica o dano.
- Marcador de acerto na retícula e som diferente quando o escudo quebra.
- **Sem fogo amigo:** o tiro e o golpe não machucam o parceiro; o tiro passa por ele. `[DECIDIDO]`

### 7.4 Movimento `[PROPOSTA]`

| Ação | Valor |
|---|---|
| Velocidade | 16 studs/s |
| Correr | não existe |
| Agachar | não existe |
| Pular | existe, pulo padrão do Roblox (altura em config) `[DECIDIDO]` |
| Velocidade mirando | só a **Luneta** deixa mais lento: 70% com a mira aberta `[DECIDIDO]`; as outras armas não mudam a velocidade ao mirar |

### 7.5 Retícula e sensibilidade

- Configuráveis no tutorial e nas configurações (seção 5.2).
- A retícula é personalizada só para o próprio jogador.

### 7.6 Marcação de jogadores `[DECIDIDO]` (revista na F6, conforme o guia visual do dono do projeto)

| Situação | Contorno | Barra de vida sobre a cabeça | Nome |
|---|---|---|---|
| **Inimigo à vista** (qualquer parte do corpo visível) | **Vermelho**, pulsando devagar, só no que aparece (não atravessa paredes) | **Vermelha** | — |
| Inimigo atrás de parede ou de Nuvem | — (nada) | — | — |
| **Aliado à vista** | Nenhum (visual limpo) | **Verde** | Branco |
| **Aliado com o corpo inteiro escondido** | **Silhueta verde fluorescente** através da parede | — | — |
| Quem assiste do mirante | — | — | Nome de quem duela, na cor da equipe |

- **Barra:** a vida preenche a barra na cor da marcação (vermelha ou verde); uma **linha azul fina** em cima mostra o escudo. `[DECIDIDO]`
- A cor de acessibilidade do inimigo (vermelho, amarelo ou magenta; ESTILO 5) vale para o contorno e para a barra.
- Com "reduzir efeitos" ligado, o contorno do inimigo não pulsa.
- **Minimapa** (ponto verde do aliado fora de alcance; inimigo só quando visto ou marcado): entra com o minimapa do HUD, na F7.
- Só entre jogadores da mesma ilha. Quem foi derrubado e assiste ao parceiro não vê marcações.

Notas de implementação:

- Checagem no cliente a cada ~0,1 s, lançando raios da câmera até 6 pontos do corpo (cabeça, tronco, mãos, pés). **Algum** livre = à vista; **todos** bloqueados = escondido.
- Contorno do inimigo: destaque que não atravessa paredes (só desenha o que está visível). Silhueta do aliado: destaque que atravessa paredes.
- Regra pura em `Shared/Combat/MarkerRules`; números em `CombatConfig.Markers`; cores em `Theme.Marker` e `Theme.EnemyOutline`.
- O vermelho do inimigo nunca pode ser usado em skins de forma que confunda.

### 7.7 Feedback de dano, abate e sons `[DECIDIDO]`

- **Sem sangue.** Acerto mostra faíscas/estilhaço cartoon na cor neutra e o número de dano. Personagem derrubado some em um efeito de poeira/estrelinhas, sem corpo no chão.
- **Som de tiro:** agradável e macio, nada estridente ou realista demais. Cada arma com som próprio.
- **Abate:**
  - Aviso na **parte de baixo da tela, centralizado**: `1 KILL`, `2 KILLS`, … contando os abates do jogador **na partida inteira** (não zera entre rodadas). `[DECIDIDO]`
  - Som de **"crack"**: estalo curto, oco e macio. A ser revisado com o dono do projeto antes da versão final.
- Todos os sons são **originais** (não usar sons de outros jogos).
- **Sons finais sintetizados por código** `[DECIDIDO]` (F10, dono do projeto): `scripts/sons/gerar.js` gera os 36 sons em `assets/sons/` (18 tiros, um por arma; corpo a corpo, recarga, sacar, sem munição, acerto, escudo quebrado, crack de abate, derrubado, ping, frase, 6 das cartas e o do ponto de escudo). O dono ouve e aprova cada um; o envio ao Roblox é pela conta dele (README, "Sons"). Afinação, volume e receita `[PROPOSTA]`.
- **Estilo dos sons** `[DECIDIDO]` (F10, dono do projeto): **FPS tático, não ultra-realista** (a sensação de referência é a dos FPS táticos atuais, mas nenhum som é copiado deles). **Nada de som retrô ou de 8 bits**: a primeira versão, feita de tons puros afinados, foi recusada por lembrar jogo antigo.

---

## 8. Habilidades (cartas)

### 8.1 Princípios

- Cada habilidade é uma **carta**. O jogador coleciona cartas (ganhas no tutorial ou compradas com moedas).
- Cada carta faz uma coisa só, com efeito visível e fácil de entender.
- Nenhuma carta causa dano alto; elas servem para posicionamento e virada.
- Efeitos de habilidade são o **único lugar do jogo onde brilho é permitido** (seção 14).

### 8.2 Escolha de carta `[DECIDIDO]`

- Na tela de preparação da **1ª rodada** (seção 4.10), o jogador tem **15 segundos** para escolher **uma carta básica** (C, Q ou E) entre as que possui.
- **Se não escolher a tempo, joga a partida inteira sem carta básica.**
- A escolha vale para a partida inteira.
- A ult (X) não é escolhida: quem possui uma carta X a recebe automaticamente a partir da 4ª rodada (seção 8.5).
- Dupla **de folga na 1ª rodada** (número ímpar de duplas) não passa pela preparação da 1ª rodada: ela escolhe a carta na **sua primeira preparação**, com os mesmos 15 s. `[PROPOSTA]` (F4, `CardConfig.ByeTeamChoosesOnFirstPrep`)
- **Repetir última** na etapa da carta também escolhe a carta da última partida (`loadout.lastCard`), se o jogador ainda a tiver. Sem tocar em nada, continua valendo "sem escolha = sem carta". `[PROPOSTA]` (F4)

### 8.3 Teclas fixas e coleção `[DECIDIDO]`

- Cada carta tem **uma tecla fixa**, que nunca muda: **C, Q, E** (básicas) ou **X** (ult).
- A tecla de cada carta **segue a tecla da habilidade equivalente no Valorant**.
- No celular, o botão de cada tecla fica sempre na mesma posição.
- **Uma carta por tecla na coleção.** Cada jogador pode ter no máximo 4 cartas: uma C, uma Q, uma E e uma X.
- **Loja:** depois que o jogador tem uma carta de uma tecla, a loja **deixa de mostrar** as outras cartas daquela tecla. Exemplo: comprou uma carta C → só aparecem cartas Q, E e X.
- Vale também para o futuro: mesmo que existam várias ults, o jogador só pode ter uma.
- Trocar uma carta por outra da mesma tecla depois de comprada: `[ABERTO]`.

**Atenção — conflito a decidir.** No Valorant, o dash da Jett (Tailwind) fica no **E**, não no C. Duas saídas:

1. Seguir o Valorant à risca: dash no **E**.
2. Abrir exceção: dash no **C**, como você prefere.

`[ABERTO]` — até decidir, a tabela abaixo segue o Valorant.

### 8.4 Cartas

Nomes próprios do jogo. A referência no Valorant é só para tecla e mecânica (nunca copiar nome, arte ou som).

| Carta | Tecla | Referência (Valorant) | Como se obtém |
|---|---|---|---|
| **Nuvem** | C | Cloudburst (Jett, C) | tutorial (fixa na v1) |
| **Impulso** | Q | Updraft (Jett, Q) | tutorial (fixa na v1) |
| **Tremor** | E | Fault Line (Breach, E) | tutorial (fixa na v1) |
| **Renascer** | X (ult) | Run It Back (Phoenix, X) | tutorial (fixa na v1) |
| **Dash** | E | Tailwind (Jett, E) | futuro (seção 19) |

Observação: Tremor e Dash usam a mesma tecla (E). No futuro, seriam opções concorrentes na escolha da tecla E.

#### Nuvem (C) — fumaça arremessável
- Arremessa uma bola que vira uma nuvem esférica que bloqueia a visão.
- Raio 8 studs, duração 7 s, 2 cargas por rodada. `[PROPOSTA]`
- Celular: toque para arremessar; segurar mostra o arco. No PC e no controle é igual: segurar a tecla mostra o arco, soltar arremessa. `[PROPOSTA]` (F4)
- A bola sai a 48 studs/s com um empurrão para cima (alcance de ~60 studs) e vira nuvem onde bate; no ar, vira nuvem depois de 1,3 s. Caindo no chão, o centro sobe um pouco para cobrir uma pessoa em pé. `[PROPOSTA]` (F4, `CardConfig`)
- A nuvem **bloqueia a visão, não as balas**: quem atira através dela acerta normalmente; o contorno do inimigo atrás dela some, e o tiro automático e a assistência de mira não "enxergam" através dela. Dentro dela a tela fica coberta de névoa. Do mirante ela fica translúcida, para dar para assistir. `[PROPOSTA]` (F4)

#### Impulso (Q) — salto para cima
- Lança o jogador ~18 studs para cima. 1 carga, recarga 20 s. `[PROPOSTA]`
- Dá para atirar no ar com precisão reduzida.

#### Tremor (E) — onda no chão
- Onda em linha reta à frente: 20 studs de comprimento, 6 de largura. Não atravessa paredes. `[PROPOSTA]`
- Quem está no chão e é atingido fica com **50% de lentidão e mira tremida por 2 s**. Sem dano.
- 1 carga, recarga 25 s.
- Só pega **inimigos** (o parceiro não, como o fogo amigo). A onda anda a 40 studs/s: o efeito chega quando ela passa, e só pega quem ainda está no chão nesse momento. "No chão" = pés até 3 studs acima ou abaixo da onda (quem está numa plataforma de 2º nível não é atingido). `[PROPOSTA]` (F4)

#### Renascer (X, ult) — segunda chance
- Deixa uma marca no chão. Por 8 s, se o jogador cair, volta à marca com HP e escudo cheios.
- Se os 8 s passarem sem cair, volta à marca mantendo a vida atual. `[PROPOSTA]` (configurável: `CardConfig.RenascerReturnOnExpire`)
- Vale para queda por tiro, golpe e zona. Não vale para sair do mapa (cair da ilha já leva de volta à base, seção 4). Ao voltar, 0,5 s de proteção. Quem atirou não ganha o abate. `[PROPOSTA]` (F4)

#### Efeitos finais das cartas `[DECIDIDO]` (F10, plano aprovado pelo dono do projeto); tamanhos e tempos `[PROPOSTA]` (`Theme.CardFx`)
Brilho só nos efeitos, uma cor por carta, curto e sem cobrir a tela; com "reduzir efeitos", menos peças.
- **Nuvem (lilás):** a bolinha brilhante voa em arco com um rastro curto; a nuvem ganha contorno de nuvem de desenho animado (bolas foscas em volta da esfera que bloqueia a visão), cresce ao aparecer e se desfaz no fim.
- **Impulso (azul-céu):** anel que se abre no chão e riscos subindo. O servidor avisa todos, então o adversário e o mirante também veem.
- **Tremor (âmbar):** faixa brilhante no chão e pedras foscas que sobem e afundam quando a onda passa.
- **Renascer (verde-menta):** a marca é um selo de 6 lados no chão; na volta, uma coluna de luz curta e o anel.

#### Dash — impulso horizontal (exemplo)
- Avança ~8 studs rapidamente na direção do movimento. 1 carga, recarga 12 s. `[PROPOSTA]`

### 8.5 Liberação da ult `[DECIDIDO]`

- **Não existe sistema de carga.** A ult é liberada para todos a partir da **4ª rodada**.
- Motivo: com 5 vidas, a primeira eliminação possível acontece na 5ª rodada. Assim, toda dupla que está para cair já tem a ult na disputa decisiva.
- A Rodada da Virada pode acontecer no mínimo na 5ª rodada (uma dupla que perdeu as 4 primeiras fica com 1 vida). Ou seja, quando ela acontece, todos já têm a ult.
- Usos por rodada a partir da 4ª: **1 por rodada**. `[PROPOSTA]`

### 8.6 Ficha padrão para novas cartas

```
Nome:
Tecla (C, Q, E ou X) e habilidade equivalente no Valorant:
Faz (1 frase):
Números: alcance, raio, duração, dano, cargas, recarga
Como se defende dela:
Controle no celular:
Visual do efeito:
Preço em moedas:
Raridade:
```

### 8.7 Ideias para próximas cartas `[ABERTO]`

| Nome provisório | Faz | Tecla provável (pela referência) |
|---|---|---|
| Muro | parede temporária | a definir pela referência |
| Radar | mostra silhuetas inimigas por 2 s | a definir |
| Bolha | escudo em área por 4 s | a definir |
| Cura | recupera 40 de HP do parceiro | a definir |

### 8.8 Cartas na primeira versão `[DECIDIDO]`

- O tutorial ensina e **entrega as 4 cartas**: Nuvem (C), Impulso (Q), Tremor (E) e Renascer (X).
- Na primeira versão do jogo, **só existem essas 4 cartas**, iguais para todos. Não há loja de cartas.
- A cada partida, o jogador escolhe 1 entre Nuvem, Impulso e Tremor (seção 8.2); o Renascer é liberado a todos na 4ª rodada.
- O sistema de cartas deve ser construído **pronto para crescer** (cartas definidas em config, tecla fixa por carta, uma por tecla na coleção), porque novas cartas virão depois (seção 19).

### 8.9 Raridades e Girar cartas

#### Raridades `[DECIDIDO]`

| Raridade | Cor | Moldura |
|---|---|---|
| **Comum** | azul | borda azul, brilho leve |
| **Épica** | roxa | borda roxa, brilho leve |
| **Lendária** | amarela / dourada | borda dourada, brilho médio |
| **Celestial** | **vermelho forte e vibrante** | **contorno neon vermelho intenso** (a única carta com neon forte) |

- Celestial é a raridade mais alta e mais difícil de conseguir.
- A mesma escala de raridade vale para skins. `[PROPOSTA]`
- A raridade de carta muda **só o quanto ela é difícil de conseguir e o visual**, nunca o poder: cartas da mesma tecla têm poder equilibrado, para o jogo não ficar injusto. `[DECIDIDO]` (F9)
- As 4 cartas iniciais (Nuvem, Impulso, Tremor e Renascer) são **Comuns**. `[DECIDIDO]` (F9)

#### Girar cartas `[DECIDIDO]` (F9: visualização)

A tela de Cartas tem o botão **GIRAR**. É uma função importante do jogo.

- **Na primeira versão, GIRAR é visualização (B):** vira a carta para ver a frente e o verso. Sem sorteio e sem custo. `[DECIDIDO]` (F9)
- Um sorteio de carta nova (A) pode voltar a ser discutido quando houver cartas novas. Nesse caso valem as regras abaixo.

**Se um dia houver sorteio (A), regras obrigatórias** `[PROPOSTA]`:

- **Nunca** pode custar Robux, nem moeda que possa ser comprada com Robux. No Brasil, o ECA Digital (Lei 15.211/2025) proíbe caixas de recompensa aleatória em jogos voltados ou acessíveis a crianças e adolescentes. O giro só usa **moedas ganhas jogando**, ou é **grátis** (ex.: 1 giro grátis por dia).
- Chances de cada raridade **sempre visíveis** antes de girar.
- O sorteio só oferece cartas de **teclas que o jogador ainda não tem** (regra de uma carta por tecla, seção 8.3). Nunca dá carta repetida.
- Antes de lançar, validar o desenho com um advogado.
- Na primeira versão só existem as 4 cartas fixas, então o giro não tem o que sortear. A tela e o sistema podem ser construídos, mas só são ativados quando houver cartas novas.

---

## 9. Elo `[DECIDIDO]` com valores `[PROPOSTA]`

### 9.1 Faixas

| Elo | Pontos de elo (PE) |
|---|---|
| Bronze | 0 – 999 |
| Prata | 1.000 – 1.999 |
| Ouro | 2.000 – 2.999 |
| Platina | 3.000 – 3.999 |
| Mestre | 4.000 – 4.999 |
| Deus | 5.000 ou mais |
| **ADM** | Exclusivo do dono do projeto (ver 9.4) |

### 9.2 Ganho e perda por partida `[PROPOSTA]`

| Colocação da dupla | PE |
|---|---|
| 1º | +40 |
| 2º | +25 |
| 3º–4º | +10 |
| 5º–6º | −5 |
| 7º–8º | −15 |

- Em partidas com menos duplas, a tabela é proporcional: a colocação é levada para a escala de 8 duplas (1º continua 1º, o último vira 8º) e arredondada. Ex.: com 4 duplas, 1º → +40, 2º → +10, 3º → −5, 4º → −15. `[PROPOSTA]` (F9, `RankConfig.ReferenceTeams`)
- Quem sai no meio da partida (ou volta ao lobby por ausência) conta como se a dupla tivesse caído naquele momento: fica atrás de todas as duplas ainda vivas. Não existe perda menor para quem desiste. `[DECIDIDO]` (F9)
- Bronze não perde PE abaixo de 0.
- Nas 10 primeiras partidas, o jogador não perde PE.
- A partir de Mestre, as perdas dobram.

### 9.3 Exibição

- Ícone do elo ao lado do nome no lobby, no placar da partida e no fim da partida.
- Ranking global por PE no lobby.

### 9.4 Elo ADM `[DECIDIDO]`

- Elo visual exclusivo do dono do projeto, definido pelo **UserId** dele em config (nunca pelo nome).
- Só cosmético: ícone e título próprios. Não dá vantagem de jogo.
- No ranking global, o ADM fica **fixo no topo com o selo ADM**, fora da contagem dos 100. `[DECIDIDO]` (F9)
- Ferramentas de administrador (expulsar, banir, dar moedas, etc.): `[ABERTO]`. Fora da F9: só os comandos de teste do ambiente `DEV_`.

---

## 10. Economia

### 10.1 Moedas `[PROPOSTA]`

| Fonte | Moedas |
|---|---|
| Participar de uma rodada | 5 |
| Vencer uma rodada | 10 |
| Derrubar inimigo | 3 |
| 1º lugar na partida | 100 |
| 2º lugar | 60 |
| 3º e 4º | 30 |
| Primeira vitória do dia | 150 |
| Jogar a partida inteira com o mesmo parceiro | +10% |

- **Primeira vitória do dia** = a primeira **rodada** vencida no dia (UTC). `[DECIDIDO]` (F9)
- **Mesmo parceiro:** +10% sobre as moedas da partida (sem contar a primeira vitória do dia), para quem terminou com o parceiro do começo. Quem joga sozinho (1v2) não tem parceiro e não ganha o bônus. `[PROPOSTA]` (F9)
- **Quando as moedas e o elo entram:** a dupla eliminada recebe na hora em que cai (a colocação já está definida; quem fica para assistir recebe o mesmo); a campeã e a vice, no fim; quem sai no meio, na saída (seção 9.2). A dupla de folga não ganha moedas de participação naquela rodada. `[PROPOSTA]` (F9)

### 10.2 Preços `[PROPOSTA]`

Na primeira versão as moedas compram **só skins** (não há loja de cartas, seção 8.8). Preços de cartas ficam definidos para quando a loja de cartas existir.

| Item | Moedas |
|---|---|
| Carta básica comum (futuro) | 1.500 |
| Carta básica rara (futuro) | 3.000 |
| Carta ult (futuro) | 5.000 |
| Skin Comum | 600 |
| Skin Épica | 2.000 |
| Skin Lendária | 5.000 |
| Skin Celestial | não é vendida por moedas (só eventos) |

As skins seguem a escala de raridade das cartas (seção 8.9); a tabela antiga falava em "rara", que não existe na escala. `[DECIDIDO]` (F9)

### 10.3 Robux

- **Cartas nunca são vendidas por Robux.** `[PROPOSTA]`
- Skins podem ser compradas por Robux. Faixas: `[ABERTO]`.
- Sem caixas aleatórias. `[PROPOSTA]`

---

## 11. Skins

- Tipos: roupa, chapéu/acessório, skin de arma, efeito de vitória, emote. `[PROPOSTA]`
- **Catálogo inicial (F9):** só **skins de arma e do Bastão**, porque o personagem é o avatar do jogador (seção 3.2). Quatro temas de cores, cada um para as 18 armas e o Bastão: **Areia** e **Floresta** (Comum), **Oceano** (Épica) e **Ouro** (Lendária). Cada skin só troca as cores do modelo; o ID é `skin_<arma>_<tema>` (ex.: `skin_rajada_areia`). `[DECIDIDO]` (F9, proposta aprovada pelo dono do projeto)
- Skins de versos de carta, efeito de vitória e emotes ficam para depois da F9.
- Uma skin **nunca**: esconde a marcação de aliado ou inimigo (seção 7.6), usa vermelho de forma que pareça o contorno de inimigo, muda a hitbox, ou tem neon.
- Em primeira pessoa, o jogador vê principalmente **os próprios braços e a arma**: skins de arma e de luva/manga têm prioridade de produção. `[PROPOSTA]`

---

## 12. Comunicação e social

### 12.1 Regras da plataforma

O Roblox exige verificação de idade para usar o chat e limita conversas a faixas de idade próximas. Muitos jogadores não vão ter chat de texto nem voz. O jogo precisa ser totalmente jogável e social **sem texto livre**. `[DECIDIDO pela plataforma]`

### 12.2 Voz

- Incentivada desde o tutorial (seção 5.2).
- Durante a rodada, a voz é **só da dupla**, independentemente da distância. No mirante, voz por proximidade com todos que estão lá. `[DECIDIDO]` (F8; viável com a API de áudio do Roblox, ver seção 20)
  - Quem foi derrubado e está espectando o parceiro continua falando e ouvindo **só a dupla** até o fim da rodada. `[DECIDIDO]` (F8)
  - Quem está no mirante não fala com quem está numa ilha, exceto o próprio parceiro. `[DECIDIDO]` (F8)
  - Distâncias da proximidade no mirante (volume cheio até 12 studs, nada a partir de 70) em `SocialConfig.Voice`. `[PROPOSTA]`
- No lobby, a voz é a padrão do Roblox (por proximidade). `[DECIDIDO]` (F8)
- Quem pode usar voz é decidido pelo Roblox, não pelo jogo.

### 12.3 Sem voz e sem texto

1. **Pings**: "Inimigo aqui", "Vou para cá", "Cuidado", "Preciso de ajuda". No celular: botão de ping; segurar abre uma roda. `[DECIDIDO]` (F8)
   - Só para o parceiro, só de quem está numa ilha de duelo (preparação e combate). Marcador no mundo (ícone, nome e distância), no minimapa e numa legenda. `[DECIDIDO]` (F8)
   - Ping rápido (toque curto): "Inimigo aqui" se a mira está num inimigo, senão "Vou para cá". O "Inimigo aqui" marca o lugar, não segue o inimigo. `[DECIDIDO]` (F8)
   - Duração (5 s), alcance (300 studs) e intervalo entre pings em `SocialConfig.Ping`. `[PROPOSTA]`
   - O nome da zona no ping entra na F10, quando os mapas tiverem zonas nomeadas (seção 15.1).
2. **Frases prontas**: "Boa!", "Valeu!", "Vamos juntos", "Usei minha carta", "Minha ult está pronta", "Joga de novo comigo?". Para o parceiro, em qualquer momento da partida: legenda e balão em cima de quem falou. `[DECIDIDO]` (F8)
3. **Emotes** no mirante e no fim da rodada. Na primeira versão, **4 emotes grátis para todos**, com animações padrão do próprio Roblox: Acenar, Apontar, Comemorar e Dançar. Andar cancela o emote. Emotes da loja (até 4 equipados) ficam para a F9. `[DECIDIDO]` (F8)
4. **Chat de texto** do Roblox em canal da dupla, para quem tem permissão. Na partida **não existe o canal geral**: só o canal da dupla e, para quem está no mirante, o canal do mirante. O que o jogador digita vai para o mirante quando ele está lá e para a dupla na ilha. No lobby, o chat geral continua. `[DECIDIDO]` (F8)

### 12.4 Fazer amizade

- "Ir para a próxima partida com [nome]?" (seção 4.8).
- "Adicionar amigo" (pedido nativo do Roblox) na tela de fim. Some quando os dois já são amigos. `[DECIDIDO]` (F8)
- "Jogar de novo juntos": na tela final, é o "sim" da pergunta da seção 4.8. `[DECIDIDO]` (F8)
- Elogio ao parceiro: **1 no fim de cada rodada e 1 no fim da partida** (botão ELOGIAR e opção na roda de frases). Soma `social.praisesReceived` do parceiro, que recebe o aviso "[nome] elogiou você". Não dá moedas. `[DECIDIDO]` (F8)
- Botão de denunciar sempre acessível: no placar (Tab) e na tela final. **Só o fluxo do Roblox**: o jogo não guarda denúncias. Como o Roblox não deixa o jogo abrir a denúncia de um jogador, a tela explica o caminho pelo menu do Roblox e oferece **Bloquear** (pedido nativo). `[DECIDIDO]` (F8)

---

## 13. Mobile

### 13.1 Controles na tela (primeira pessoa)

```
┌──────────────────────────────────────────────┐
│ [vidas e placar]           [tempo]    [ping] │
│                                              │
│                  + (retícula)                │
│                                              │
│ (joystick)                   [Q]  [E]  [C]   │
│  esquerdo  [arma 1⇄2]  [MIRA*]  [ATIRAR]     │
│            [recarregar]          [X ult]     │
│                  1 KILL                      │
│ * só aparece em armas com mira/modo alternativo │
└──────────────────────────────────────────────┘
```

- Esquerda: joystick de movimento. Direita: arrastar para olhar.
- Botões C, Q, E e X sempre na mesma posição (seção 8.3).
- Atirar mín. 80 px; cartas mín. 64 px; 12 px entre botões.
- Tiro automático opcional, ligado por padrão no celular. `[PROPOSTA]`
- Assistência de mira leve no celular e no controle; desligada no mouse.
- Editor de posição e tamanho dos botões. `[PROPOSTA]`
- Interface com escala relativa e área segura.

### 13.2 Desempenho

Alvo: **30 fps estáveis num Android básico de ~3 anos**. `[PROPOSTA]`

- Streaming de instâncias ligado.
- Orçamento de peças por arena (ex.: até ~3.000), medido em teste.
- Sem sombras dinâmicas pesadas; sem pós-processamento pesado no gráfico baixo.
- Partículas com limite; versão reduzida no gráfico baixo.
- **Versão leve dos mapas** `[DECIDIDO]` (F10): as peças de acabamento pequenas (juntas, ondulação, frisos, tábuas) somem na tela de quem está no gráfico baixo do Roblox ou, no gráfico automático, quando os quadros ficam abaixo de 27 por 5 s seguidos. Nada que colide some, e os sinais (setas da esteira, faixas de aviso, vagas) nunca somem. As poucas luzes reais do Porto apagam. Cada ilha cai de 1.150 a 2.420 peças (o Porto, depois da passada de detalhe) para 730 a 1.030. Valores em `MapConfig.Performance` `[PROPOSTA]`.
- **Medidor no painel TESTE** (seção DESEMPENHO, só em teste): quadros por segundo, modo do mapa e peças escondidas, com um botão para alternar a versão leve e comparar no aparelho.
- Modelo de primeira pessoa (braços e arma) leve.

---

### 13.3 PC: atalhos sempre visíveis `[DECIDIDO]`

- No PC, os botões de toque **não aparecem**. No lugar, a tela mostra **dicas de atalho fixas**, num canto onde o jogador sempre vê (ex.: canto inferior esquerdo, acima da vida):
  - **B** — Habilidades: abre um painel rápido com as cartas, o que cada uma faz e o tempo de recarga.
  - **P** — Configurações: retícula, sensibilidade, áudio, voz e acessibilidade, **sem sair da partida** e sem pausar o jogo.
  - **Tab** — Placar da partida (substitui a lista de jogadores padrão do Roblox, que fica desligada).
- **ESC é reservado pelo Roblox** (menu do Roblox) e não deve ser usado pelo jogo.
- Cada tecla de carta (C, Q, E, X) aparece embaixo do ícone da carta no HUD.
- No celular, os mesmos painéis abrem por botões: ícone de engrenagem (configurações) e toque longo nas cartas (detalhes da habilidade).
- Layout detalhado: `ESTILO-E-TELAS.md`, tela T6.

---

## 14. Direção de arte

- **Estilo:** low poly cartoon, formas arredondadas, cores sólidas, sombras simples. `[DECIDIDO]`
- **Tom para 8 a 30 anos:** divertido e bem-acabado, não infantilizado.
- **Neon: proibido em cenário, personagens, armas e skins.** `[DECIDIDO]`
- **Onde brilho/neon é permitido** (lista fechada): `[DECIDIDO]`
  1. efeitos de habilidade (curto, uma cor por carta, nunca cobrindo a tela);
  2. moldura da carta **Celestial** (neon vermelho forte) e, em menor intensidade, as molduras de raridade das outras cartas;
  3. logo do jogo (roxo com neon);
  4. destaque discreto do item selecionado na interface.
- **Interface:** painéis escuros translúcidos com **acento roxo**. O vermelho como cor principal da interface e qualquer símbolo em "V" estão proibidos (evitar semelhança com a marca de outro jogo). Regras completas: `ESTILO-E-TELAS.md`.
- **Contra o visual genérico de IA:** sem degradês chamativos (o sombreado suave de uma cor só nos menus é permitido, ESTILO 2.5), sem contornos luminosos decorativos fora da lista acima, sem excesso de partículas. Toda skin começa por uma ideia (tema e silhueta), não por efeito.
- **Sem sangue.** `[DECIDIDO]`
- **Vermelho no jogo** (fora da carta Celestial): só contorno de inimigo e avisos de perigo.
- **Luz:** dia ou fim de tarde. `[PROPOSTA]` Luz real de cenário só no Porto: até 8 luzes branco-quentes, sem sombra, que apagam na versão leve (KIT-MODULAR 1). `[DECIDIDO]`
- Paleta de cores da interface: `ESTILO-E-TELAS.md`. Paleta de cada mapa: as do `KIT-MODULAR.md` (seções 2 a 5), em `Theme.Maps`. `[DECIDIDO]` (F10)

---

## 15. Mapas

### 15.1 Regras gerais `[PROPOSTA]`

| Regra | Valor |
|---|---|
| Área jogável | ~140 × 105 studs, mais as 2 bases (40 × 36) nas pontas (F10) |
| Simetria | espelhada |
| Rotas | 3 (esquerda, meio, direita) |
| Níveis de altura | 2 ou 3 |
| Base até o centro | ~6 s andando |
| Linha de visão longa | 1 por mapa, sempre com rota alternativa coberta |
| Cobertura | a cada ~10 studs em qualquer rota |
| Recarga de escudo | 2 pontos simétricos, reativam em 20 s. Quem passa em cima com o escudo incompleto fica com o escudo cheio na hora e o ponto apaga; com o escudo cheio o ponto não é gasto. Todos acendem no começo de cada rodada (F10) |
| Proteção na base | 3 s de invulnerabilidade após o teleporte |
| Queda para fora | volta à base sem morrer, perde o escudo |
| Nomes de lugares | cada zona com nome curto e visível (usado nos pings: a legenda do ping mostra a zona, ex.: "Ana: Inimigo aqui · Muro Leste") (F10) |

Observação para primeira pessoa: corredores com no mínimo 8 studs de largura e portas com 6, para não dar sensação de aperto; cuidado com cantos cegos muito fechados.

### 15.2 Ficha padrão de mapa

```
Nome:
Tema:
Ideia central:
Zonas (nome, nível de altura, função):
Rotas:
Linha de visão longa:
Pontos de escudo:
Pontos de altura (Impulso/trampolim):
Elemento especial:
Cartas que brilham aqui:
Paleta:
```

### 15.3 Mundo do servidor de partida: ilhas flutuantes `[DECIDIDO]`

```
                       [PORTO]
                          |
          [TORRE] —— ( MIRANTE ) —— [FÁBRICA]     ← mirante: octógono mais alto, piso de vidro
                          |
                       [PRAÇA]
```

- O servidor de partida é um céu aberto com **5 ilhas flutuantes**: o **Mirante** no centro e mais alto (seção 6.5) e as **4 ilhas de duelo** em volta e abaixo dele.
- Cada ilha de duelo tem **um tema próprio e bem marcado**: Praça, Fábrica, Porto e Torre. Posições como no desenho acima: Porto ao norte, Fábrica a leste, Praça ao sul, Torre a oeste. `[DECIDIDO]` (F10, plantas do dono do projeto)
- Cada ilha fica **de lado** para o mirante: as duas bases ficam nas pontas, à esquerda e à direita de quem olha da borda, fora da área de duelo. Assim quem assiste vê os dois times por igual. `[DECIDIDO]` (F10)
- Ao trocar de ilha entre rodadas, o jogador muda **totalmente** de clima visual.
- Cada ilha é uma arena fechada de duelo rápido 2v2. A borda da ilha funciona como "queda para fora" (volta à base sem morrer, perde o escudo).
- Tamanhos: as 4 ilhas têm o **mesmo tamanho** `[DECIDIDO]` (F10, dono do projeto): área de duelo de até 140 × 105 studs e bases de 36 × 42 nas pontas, com passagem de 14. Ilhas a 180 studs do centro do mirante, que fica 70 acima (valores em `MapConfig.World`, `[PROPOSTA]`).
- Todos os mapas precisam ser **legíveis de cima** (seção 6.5).

### 15.4 Praça — planta `[DECIDIDO]` (F10, dono do projeto); medidas e alturas `[PROPOSTA]`
- **Tema:** praça de cidade pequena (arte com o kit da Praça, KIT-MODULAR 4).
- **Ideia central:** mapa de estreia, fácil de entender.
- **Planta** (`docs/referencias/f10/praca-0-planta-do-dono.png`; código em `Shared/Maps/Islands/Praca`): duas áreas chanfradas encaixadas, com **simetria de giro** (o que existe numa metade existe girado 180° na outra). As metades se ligam pelo meio por uma passagem de 18 studs. Cada metade tem:
  - **Passarela elevada** (nível 1, 5 studs, 10 de largura) ao longo do lado diagonal, com rampa nas duas pontas e mureta do lado do vazio `[DECIDIDO]` (F10);
  - **Muro comprido** (20 × 2 × 4) com uma **caixa de madeira** (6 × 6 × 6) na ponta;
  - **Canteiro de grama** em triângulo, rente ao chão (não protege de tiro);
  - **Caixa de madeira** (6 × 6 × 6) encostada na borda `[DECIDIDO]` (F10).
- **Sem coreto e sem chafariz** (dono do projeto, F10).
- **Zonas** (nomes para os pings) `[DECIDIDO]` (F10): *Passarela*, *Muro*, *Canteiro* e *Meio*, com Leste/Oeste para diferenciar as metades, mais *Base*.
- **Decoração** `[DECIDIDO]` (F10): sobrados e árvores ficam **fora** da área de duelo, como moldura; postes e bancos dentro, nas bordas, sem criar cobertura nova nas rotas. A copa da árvore não bloqueia tiro (só o tronco); confirmar em teste.
- **Cartas que brilham:** Impulso para subir na passarela sem a rampa; Tremor em quem desce a rampa. `[PROPOSTA]`

### 15.5 Fábrica — planta `[DECIDIDO]` (F10, dono do projeto); medidas e alturas `[PROPOSTA]`
- **Tema:** fábrica colorida, com caixas, tubos e **esteiras em movimento** (arte com o kit da Fábrica, KIT-MODULAR 3).
- **Ideia central:** esteiras carregam quem pisa nelas; caixas sobre a esteira são cobertura que se move. Velocidade de 8 studs/s (metade da corrida) `[PROPOSTA]` (F10, `MapConfig.Fabrica.ConveyorSpeed`); a caixa que chega ao fim da correia volta ao início.
- **Planta** (contorno em `docs/referencias/f10/fabrica-0-planta-do-dono.png`, bloco aprovado em `fabrica-1-de-cima.jpg` e `fabrica-2-do-mirante.jpg`; código em `Shared/Maps/Islands/Fabrica`): cintura estreita no meio, chanfro de um lado e degrau reto do outro, com **simetria de giro**. Cada metade tem:
  - **Controle** (centro, nível 1, 6 studs): plataforma atravessada na frente da base, com rampa de frente para a base; as duas plataformas se ligam por uma passarela com grade, e passa-se por baixo dela;
  - **Depósito**: prateleiras altas em linha, uma máquina, um corredor de prateleiras atrás e tubulação na parede do fundo;
  - **Esteira**: duas esteiras em linha com um vão de 6 entre elas, andando para fora, com caixas de papelão em cima;
  - um **ponto de escudo** no meio de cada corredor lateral.
- **Zonas** `[DECIDIDO]` (F10): *Controle*, *Depósito*, *Esteira* e *Meio*, com Leste/Oeste, mais *Base*.
- **Cartas que brilham:** Tremor na passarela estreita; escopetas no Depósito. `[PROPOSTA]`

### 15.6 Porto — planta `[DECIDIDO]` (F10, dono do projeto); medidas e alturas `[PROPOSTA]`
- **Tema:** porto com contêineres, guindaste, píer de madeira e água (arte com o kit do Porto, KIT-MODULAR 2).
- **Planta** (contorno em `docs/referencias/f10/porto-0-planta-do-dono.png`, bloco aprovado em `porto-1-de-cima.jpg` e `porto-2-do-mirante.jpg`; código em `Shared/Maps/Islands/Porto`): retângulo com um recorte de água no meio das bordas norte e sul, com **simetria de giro**.
  - **Guindaste** (centro): pilha de contêineres em ponte; a rota do meio passa por baixo (vão de 8). Cada ponta é uma plataforma (nível 1, 8,5) com escada do chão e outra até o topo (nível 2, 17, linha de visão longa).
  - **Pátio** (leste e oeste): dois contêineres em pé, em linha, com um portão de 8 entre eles; um deles fica na frente da porta da base e quebra a linha reta base a base. Parede de chapa e caixas de madeira do lado mais aberto.
  - **Píer** (nos dois recortes): tablado de madeira sobre a água, sem mureta, com o **ponto de escudo** no meio.
- **Sem Armazém** (não está na planta aprovada): o Porto não tem área coberta.
- **Zonas** `[DECIDIDO]` (F10): *Guindaste*, *Píer*, *Pátio* e *Meio*, com Leste/Oeste, mais *Base*.
- **Especial:** cair na água volta à base.
- **Cartas que brilham:** Luneta e Mata-Pato no Guindaste; Nuvem no portão do Pátio. `[PROPOSTA]`

### 15.7 Torre — planta `[DECIDIDO]` (F10, dono do projeto); medidas e alturas `[PROPOSTA]`
- **Tema:** torre/castelinho em ruínas no alto da ilha, com muralhas, escadarias e ponte (arte com o kit da Torre, KIT-MODULAR 5).
- **Ideia central:** o mapa mais vertical; disputa pelo alto da torre.
- **Planta** (contorno em `docs/referencias/f10/torre-0-planta-do-dono.png`, bloco aprovado em `torre-1-de-cima.jpg` e `torre-2-do-mirante.jpg`; código em `Shared/Maps/Islands/Torre`): **simetria espelhada** (a única ilha assim: o contorno do dono só é simétrico desse jeito), com um vão central em colchete.
  - **Topo** (centro, 12 studs, com ameias, aberto e exposto), igual para os dois times;
  - **Escadaria**: dois lances espelhados encostados no Topo, um de cada time; única subida sem carta;
  - **Ponte**: tábuas sobre o vão, coladas no Topo (rota do meio, sem cobertura); cair no vão volta à base;
  - **Muralha** (nível 1, 8,5): caminho de ronda do lado oposto ao mirante, com uma escada em cada ponta e a guarita no meio;
  - **Pátio** (nível 0, do lado do mirante): só peças baixas (escombros).
  - Dois **pontos de escudo** no eixo do meio: um no Pátio e um na Muralha.
- **Zonas** `[DECIDIDO]` (F10): *Topo*, *Escadaria*, *Ponte*, *Muralha*, *Pátio* e *Meio*, com Leste/Oeste onde há duas, mais *Base*.
- **Cartas que brilham:** Impulso para chegar ao topo sem a escadaria; Tremor em quem desce a escadaria. `[PROPOSTA]`

### 15.8 Em aberto
- ~~Plantas do Porto, da Fábrica e da Torre.~~ Respondida na F10: aprovadas em bloco colorido pelo dono do projeto (15.5 a 15.7). Falta conferir em jogo, em primeira pessoa: largura dos corredores, cantos cegos e tempo da base ao centro.
- ~~Quais mapas são maiores e quais menores.~~ Respondida na F10: as 4 ilhas têm o mesmo tamanho (15.3).
- ~~Paleta de cada mapa.~~ Respondida na F10: as do KIT-MODULAR (seção 14).

---

## 16. Arquitetura técnica (para o Claude Code)

### 16.1 Ferramentas
- Rojo, Wally, Selene, StyLua. Luau `--!strict`.

### 16.2 Places
- `Tutorial`, `Lobby`, `Match` (servidor reservado por partida). Código compartilhado entre os três.

### 16.3 Estrutura de pastas sugerida

```
src/
  shared/
    Config/
      MatchConfig.luau        -- tempos, vidas, Rodada da Virada
      QueueConfig.luau        -- 7 jogadores, esperas, faixas de nível
      RankConfig.luau         -- faixas de elo, tabela de PE, AdminUserId
      WeaponConfig.luau       -- 18 armas, categorias, fases por rodada, tiro automático por tipo (seção 7.2)
      CardConfig.luau         -- cartas, teclas fixas, rodada de liberação da ult
      EconomyConfig.luau
      ShopCatalog.luau
      MapConfig.luau
      TeamColors.luau
      AudioConfig.luau        -- ids dos sons de tiro, crack de abate
    Types.luau
    Remotes.luau
  tutorial/
    server/TutorialService.luau
    client/TutorialController.luau
  lobby/
    server/QueueService.luau        -- fila entre servidores, faixas, dupla fixa
    server/ShopService.luau
    client/LobbyController.luau
    client/SettingsController.luau -- sensibilidade, retícula, voz
  combat/                           -- carregado pela Partida e pelo Tutorial (F6)
    server/CombatService.luau
    server/CardService.luau         -- validação das cartas
    server/CharacterService.luau    -- avatar, hitbox
    client/WeaponController.luau
    client/CardController.luau
    client/TeamMarkers.luau         -- marcação de aliado e inimigo (seção 7.6)
    client/CombatHUD.luau           -- inclui aviso "N KILL"
  match/
    server/MatchService.luau        -- máquina de estados (seção 4), escolha de carta (15 s)
    server/MatchWorld.luau
    server/RankService.luau
    server/LobbyReturn.luau         -- assistir / nova partida / seguir com amigo
    client/SpectateCamera.luau
  common/
    server/DataService.luau         -- perfil com trava de sessão
    client/InputController.luau
    client/FirstPersonCamera.luau   -- trava em primeira pessoa
```

### 16.4 Dados salvos por jogador

Esquema completo, valores padrão, regras de integridade, salvamento, teleporte, compras em Robux, migrações e testes: **`docs/DADOS-JOGADOR.md`**.

### 16.5 Fila e teleportes
- Fila compartilhada entre servidores de lobby (armazenamento em memória do Roblox).
- Um servidor de lobby "líder" monta o grupo, cria o servidor reservado e teleporta todos.
- Dupla fixa viaja junta e mantém o vínculo no servidor de partida.
- Dados da partida (quem é dupla de quem, faixa de nível) passam junto no teleporte.

### 16.6 Segurança
- Servidor valida tiro (cadência, munição, distância, linha de visão), cartas (cooldown, cargas, escolha válida), elo e moedas.
- Limite de frequência em todos os remotes.
- ADM identificado só por UserId no servidor.

---

## 17. Fases de desenvolvimento

O plano completo está em **`docs/FASES.md`**: 12 fases (F0 a F11) e dois marcos de teste, cada fase com tarefas, critérios de aceite e o que fica fora.

Ordem resumida: F0 Base → F1 Dados do jogador → F2 Combate → F3 Loop da partida → F4 Cartas → ⭐ primeiro jogável → F5 Lobby e fila → F6 Tutorial → F7 Interface final → F8 Social e voz → F9 Elo, economia e arsenal → F10 Mapas e arte → ⭐ beta fechado → F11 Robux e lançamento.

---

## 18. Perguntas em aberto

1. Nome do jogo.
2. ~~Moedor e Gêmea na fase Pesadas?~~ Respondida: entram (seção 7.2.2).
3. ~~Aviso de abate por rodada ou por partida?~~ Respondida: pela partida (seção 7.7).
4. ~~O tutorial pode ser pulado?~~ Respondida na F6: só as telas de configuração (seção 5.1).
5. ~~Girar cartas: sorteio (A) ou visualização (B)?~~ Respondida na F9: visualização (seção 8.9).
6. ~~Raridade da carta muda o poder dela?~~ Respondida na F9: não, só a dificuldade e o visual (seção 8.9).
7. ~~O diamante roxo do mockup é uma segunda moeda?~~ Respondida na F9: não há segunda moeda por enquanto (`gems` fica 0).
8. ~~Quais mapas são maiores e quais menores?~~ Respondida na F10: mesmo tamanho (seção 15.3).
9. Ferramentas de ADM além do elo visual.
10. Câmeras cinematográficas (cerimônia de campeão) também em primeira pessoa?
11. ~~Onde fica a cor da equipe no personagem?~~ Respondida na F6: não fica no personagem; marcação verde/vermelha na ilha (seções 3.3 e 7.6).
12. ~~Final melhor de 3: sim ou não?~~ Respondida: sim, e na final as vidas param de contar (seção 4.7).
13. Preços em Robux e passe VIP.
14. ~~Plantas baixas dos mapas.~~ Respondida na F10: as 4 aprovadas (seções 15.4 a 15.7). ~~Paletas.~~ Respondida na F10: as do KIT-MODULAR.
15. ~~Temas das primeiras skins.~~ Respondida na F9: Areia, Floresta, Oceano e Ouro, só em armas (seção 11).

---

## 19. Evoluções futuras (não implementar na primeira versão)

- **Escolha de cartas por tecla:** ao começar o jogo, o jogador escolhe 1 entre 2 opções de cada tecla (ex.: na tecla E, Tremor ou Dash). Uma carta por tecla na coleção, como descrito na seção 8.3.
- **Loja de cartas** com moedas, mostrando só cartas de teclas que o jogador ainda não preencheu.
- **Novas cartas**, sempre com tecla fixa seguindo a habilidade equivalente no Valorant (ideias na seção 8.7).
- **Modo ranqueado** separado e fila entre regiões.

---

## 20. Decisões técnicas

Detalhes de implementação decididos durante o desenvolvimento (não são regras de jogo).

### F0 · Base do projeto

| Decisão | Por quê |
|---|---|
| **Rokit** gerencia as versões das ferramentas (`rokit.toml`): Rojo 7.7.1, Wally 0.3.2, Selene 0.32.0, StyLua 2.6.0, luau-lsp 1.70.1. | Qualquer computador instala as mesmas versões com `rokit install`. |
| **Um projeto do Rojo por place** (`lobby.project.json`, `tutorial.project.json`, `match.project.json`), cada um na sua porta (34872, 34873, 34874). | O código comum é o mesmo; só muda a pasta do place. |
| **O Rojo não gerencia Workspace, Lighting nem Terrain.** O código fica em subpastas próprias (`ReplicatedStorage.Shared`, `ServerScriptService.Common` / `.Place`, `StarterPlayerScripts.Common` / `.Place`), e os serviços ignoram instâncias desconhecidas. | Mapas montados no Studio nunca são apagados nem sobrescritos. |
| Os projetos do Rojo ficam na **raiz** do repositório. | O luau-lsp resolve os caminhos do sourcemap a partir da raiz. |
| **Inicialização:** um script `Boot` por lado (`src/common/server`, `src/common/client`) usa `Shared/Loader` para carregar os módulos das pastas `Common` e `Place`, chamando `Init()` em todos e depois `Start()` em todos. | Um só ponto de entrada; cada sistema é um módulo. |
| `Types` é uma pasta (`src/shared/Types/init.luau`). Os tipos do perfil entram em `Types/PlayerData.luau` na F1. | Atende ao GDD 16.3 (`Types.luau`) e ao DADOS-JOGADOR 3.1 (`Types/PlayerData.luau`) ao mesmo tempo. |
| As migrações de dados (DADOS-JOGADOR 7) ficarão em `src/common/server/Data/Migrations.luau`. | O perfil é carregado nos 3 places, então o código de dados é comum. |
| Configs extras além da lista do GDD 16.3: `CharacterConfig` (saúde, movimento, câmera), `PlaceConfig` (IDs da experiência e dos places) e `DevConfig` (ferramentas de teste). | Números só em `Config/`. |
| Cores de equipe ficam no `Theme` (`Theme.Team`). O `TeamColors.luau` guarda só a ordem de distribuição. | Regra "cores só em `Theme.luau`". |
| Os nomes de armas, cartas, mapas e elos são lidos do `Strings` pelo **ID** (ex.: `Strings.Weapons.weapon_rajada`). | Regra "textos só em `Strings.luau`"; os IDs são os mesmos salvos no perfil. |
| **Ambiente `DEV_`** (`src/shared/Env.luau`): é **real** só fora do Studio, na experiência de produção (`PlaceConfig.Production.GameId`). Todo o resto é teste: Studio, a experiência atual (GameId 10775571935) e cópias. Antes do lançamento (F11), cria-se uma experiência separada de produção. | Nunca misturar dados de teste com dados reais. Na dúvida, é teste. |
| **Câmera em primeira pessoa em três camadas:** propriedades do `StarterPlayer` pelo Rojo, `CameraService` no servidor e `FirstPersonCamera` no cliente, que reaplicam a trava se algo mudar. | GDD 3.1: nunca sair da primeira pessoa. |
| **Teleporte de teste:** o painel TESTE só existe em `DEV_`. O servidor valida o destino e limita a frequência (3 s). A Partida usa servidor reservado (`ReserveServerAsync` + `TeleportToPrivateServer`). Atalhos: botão na tela (celular), tecla T (PC), direcional para cima (controle). | FASES F0. Com o painel aberto, `Modal` libera o mouse da primeira pessoa no PC. |
| **Verificação** (`scripts/check.ps1`): StyLua, Selene (`std = roblox`) e `luau-lsp analyze` com os tipos do Roblox, um place por vez. | Critério de aceite da F0 e regra `--!strict`. |
| O repositório fica fora do OneDrive (`C:\dev\spin-shoot-power-cards`). | A sincronização do OneDrive trava arquivos e corrompe `.git`. |

### F1 · Dados do jogador

| Decisão | Por quê |
|---|---|
| **ProfileStore oficial copiado** em `vendor/ProfileStore/` (commit e SHA-256 em `ORIGEM.md`), sem alterações, sincronizado em `ServerStorage.Vendor`. O jogo só o usa pelo `Data/ProfileStoreAdapter.luau`. | O Wally não tem o pacote oficial, só cópias de terceiros. Fixar o commit evita mudanças não revisadas. |
| **Trava de sessão:** se o perfil está aberto em outro servidor, o ProfileStore pede a liberação na hora (MessagingService), tenta de novo após 5 s e **assume a trava após ~10 s**. Trava sem atualização há 5 min é assumida na hora. O servidor que perde a trava para de salvar e manda o jogador entrar de novo. Números em `DataConfig`. | DADOS 5.1. "Nunca dois abertos": quem perde a trava não consegue mais gravar. |
| Falha de carga: o ProfileStore repete com espera crescente (1, 2, 4, 8… s) até `DataConfig.LoadTimeoutSeconds` (30 s); depois o jogador é expulso com mensagem, **sem** criar perfil por cima. | DADOS 5.1.6 e 5.2. |
| O template do ProfileStore fica **vazio**: perfil sem dados = perfil novo (`DefaultProfile.new`). Perfil existente passa por **migrações → completar campos → validar** (`Data/Migrations`, `Data/ProfileSanitizer`). Campos desconhecidos são preservados. | Migrar antes de completar; preservar dados de versões mais novas (DADOS 1.6). |
| Migração com erro: os dados salvos não são tocados (a migração trabalha numa cópia), a sessão é liberada e o jogador é avisado. | Nunca perder progresso. |
| **Toda mudança no perfil passa por `DataService.update(player, função)`**; as regras da seção 4 de DADOS ficam em `Data/ProfileRules.luau` (funções puras). Moedas só pelo `EconomyService`. | Um só caminho de escrita, fácil de auditar e testar. |
| **Teleporte:** antes de teleportar, `DataService.releaseForTeleportAsync` salva e libera a trava, esperando o DataStore confirmar (até 10 s). Se o teleporte falhar, o perfil é reaberto no mesmo servidor. | DADOS 5.3. |
| **Cópia para o cliente:** o servidor envia o perfil inteiro (remote `ProfileSnapshot`) ao carregar e a cada mudança; mudanças no mesmo quadro saem num envio só. No cliente, `PlayerDataClient` guarda a cópia congelada (`table.freeze`). Inclui `moderation` (só o número de avisos do próprio jogador). | Perfil pequeno (~2 KB); simples e sem risco de cópia desatualizada. |
| **Pedidos de configuração** (`SettingsUpdateRequest`): o cliente manda só os campos que mudaram. Qualquer valor inválido (fora do intervalo, NaN, tipo errado, cor que não é `#RRGGBB`, campo desconhecido) **recusa o pedido inteiro**. Limite: 10 pedidos a cada 5 s. Todas as configurações da seção 3.1 de DADOS já são aceitas. `mobileLayout = false` volta ao layout padrão. | DADOS 4 e 10. Validação em `src/shared/SettingsValidation.luau`, que o cliente também pode usar. |
| Limites das configurações que o documento não dava: sensibilidade de mouse e controle 0,1 a 5,0 (igual ao toque); multiplicador da mira 0,1 a 2,0; tamanho, espessura e espaço da retícula são inteiros; escala dos botões do celular 0,5 a 2,0, até 24 botões. | Valores técnicos em `DataConfig.Limits`, fáceis de mudar. |
| No carregamento, valores salvos inválidos são **corrigidos** (limitados ao intervalo ou voltam ao padrão) e a correção aparece no Output. | Um perfil estragado não impede o jogador de entrar. |
| `lastLoginAt` é atualizado ao carregar e `lastSaveAt` a cada salvamento. `loginStreak`/`lastLoginDay` ficam para a F9 (economia). | Fora do escopo da F1. |
| **Comandos de teste** no painel TESTE (só `DEV_`): +100 moedas, sensibilidade +0,5 e "config inválida" (pelo remote real de configurações), ver perfil (JSON completo no Output do servidor) e resetar perfil (pede segundo toque). Atributo `DEV_SimulateLoadFailure = true` no `ServerStorage` faz a carga falhar. | FASES F1 e teste "falha simulada" de DADOS 10. |
| **Testes automáticos** em `src/tests` (sincronizado em `ServerStorage.Tests`): `require(game.ServerStorage.Tests.Runner).run()` no Studio. | Lógica pura testável sem servidor. |
| Botão **TESTE** numa `ScreenGui` própria com `ScreenInsets = CoreUISafeInsets`, para ficar abaixo da barra do Roblox (menu, chat) em qualquer aparelho. O painel em si continua centralizado. | Na F0 o botão ficava por baixo do menu do Roblox. Regra para toda interface: elementos no topo da tela usam `CoreUISafeInsets`. |

### F2 · Combate

| Decisão | Por quê |
|---|---|
| **Uma só máquina de estados das armas** (`Shared/Combat/WeaponState`) roda no cliente (resposta na hora) e no servidor (autoridade): munição, cadência, recarga, rajada, aquecimento e tempo de sacar (`WeaponConfig.EquipTime`). | Cliente e servidor nunca discordam da regra; os testes usam o mesmo código. |
| **Validação do tiro:** o cliente manda o horário do tiro em tempo do servidor (`GetServerTimeNow`). O servidor só aceita horários até 0,5 s no passado e 0,1 s no futuro, sempre em ordem, e roda a cadência com esses horários. Também confere: origem perto da cabeça, alvo inimigo e vivo, distância ≤ alcance, ponto de acerto perto da hitbox (folga de 6 studs pelo atraso da rede) e linha de visão contra o mapa. Números em `CombatConfig.Validation`. | Cadência exata mesmo com a rede oscilando, sem deixar o cliente atirar mais rápido (teste: 20 tiros de uma vez → 1 aceito). |
| **O cliente decide em quem acertou e o servidor confere** (sem rebobinar posições no servidor). | Simples e responsivo; a folga cobre o atraso. Rebobinar fica para depois, se o teste mostrar necessidade. |
| **Hitbox:** um cilindro invisível em pé (`Hitbox`, raio 1,1 × altura 5,2) preso ao personagem. Grupos de colisão: o corpo (`CharacterBody`) não para tiros; os tiros (`ShotRay`) só acertam o mapa e as hitboxes; a visão (`SightRay`) só o mapa. | GDD 3.2: cápsula única, sem cabeça. O Roblox não tem cápsula; o servidor usa a conta da cápsula com folga. |
| **Personagem base:** blocos padrão do Roblox via `HumanoidDescription` (cinza, pernas escuras), sem avatar, acessórios nem roupa. `CharacterAutoLoads` desligado; o servidor cria e recria o personagem. Derrubado: o modelo some na hora (poeira nos clientes) e volta em 3 s na arena de teste. | GDD 3.2 e 7.7. |
| **Vida e escudo** ficam no servidor (`Combatants`); o cliente lê os atributos `Hp`, `Shield`, `Alive` e `TeamId` do modelo. A vida do `Humanoid` não é usada (cair no vazio conta como derrubado sem atacante). Proteção de 3 s ao aparecer. | Servidor é a autoridade (CLAUDE.md). |
| **Metralhadoras:** segurando o gatilho, o primeiro tiro sai depois do tempo de aquecimento (0,5 s / 1 s); soltar esfria. | É o modelo que bate com o tempo para derrubar da tabela 7.2.3. |
| **Gêmea:** cada toque no gatilho é um tiro (intervalo mínimo 0,4 s); com 2 no pente, recarrega em seguida. | Bate com os 3,2 s da tabela. |
| **Modo alternativo:** no PC e no controle, segurar (botão direito / gatilho esquerdo); no celular, o botão MIRA/MODO liga e desliga. Rajadas continuam sozinhas depois de começar. | Mesmo comportamento nos três controles, sem segurar dois botões no toque. |
| **Sensibilidade:** `AimCamera` (comum aos 3 places) roda logo depois da câmera do Roblox e multiplica o giro do quadro pela sensibilidade do perfil do controle em uso (× multiplicador da mira aberta). Recuo, assistência de mira e "arrastar no botão ATIRAR" entram como rotações extras. Campo de visão 80°. | Funciona igual para toque, mouse e controle, sem trocar a câmera do Roblox (a trava em primeira pessoa da F0 continua). |
| **Recuo:** sobe e balança sempre no mesmo padrão; ao parar de atirar, volta à mira original. **Espalhamento** cresce a cada tiro seguido e ao andar/pular. Valores por arma em `WeaponConfig`. | GDD 7.2.6: recuo simples e previsível. |
| **Assistência de mira** (toque e controle, se ligada no perfil): freia a mira perto do inimigo (×0,6) e puxa 4°/s só enquanto o jogador se mexe. **Tiro automático** (toque, se ligado no perfil) conforme o tipo de arma do GDD 7.2.6. | GDD 7.2.6 e 13.1. |
| **Moedor atravessa** uma cobertura de até 1,5 stud de espessura, com 50% do dano. | "Dano reduzido" do GDD 7.2.4. |
| **Contornos:** `Highlight` com profundidade "Occluded" no inimigo (só o que aparece) e "AlwaysOnTop" no parceiro, ligado só quando os 6 pontos do corpo estão escondidos (checagem a cada 0,1 s). Nomes em cima da cabeça só para o parceiro. *(Substituído na F6: ver "Marcação de aliado e inimigo".)* | GDD 7.6. |
| **Arma em primeira pessoa:** modelo de blocos só no cliente, preso à câmera, com as posições do guia por categoria (`CombatConfig.ViewModel`). No celular, 10% menor e mais baixa. Some com a mira de sniper aberta (luneta redonda no HUD). | Guia da arma em primeira pessoa. Modelos finais na F10. |
| **Sons provisórios** da biblioteca que vem com o Roblox (`rbxasset://sounds`), com tom diferente por arma. | Originais (não são de outro jogo); os finais são da F10. |
| **Arena de teste** montada por código ao iniciar o servidor (`TestArenaService`, nada salvo no place): bases das duas duplas, coberturas cheias e de meia altura, cobertura fina, parede para o contorno do parceiro, estande com alvos a 10–100 studs e alvos que andam. Desligada na F3 (`CombatConfig.TestArena.Enabled`). | FASES F2. |
| **Duplas de teste:** quem entra vai para Azul ou Laranja (a que tiver menos gente); o painel TESTE troca. A formação de verdade é da F3. | Dá para testar inimigo e parceiro com 2 a 4 jogadores. |
| **Painel TESTE › COMBATE** (só `DEV_`, só na Partida): escolher qualquer uma das 18 armas, trocar de dupla, vida cheia, alvos andando/parados e o teste de exploit de cadência. Ao derrubar, o HUD mostra o tempo e os tiros (medidos pelos horários dos tiros). | Critérios de aceite da F2. |
| `TextUtil.upper` converte letras acentuadas. | O `string.upper` do Luau deixava "BASTãO". |

### F3 · Loop da partida

| Decisão | Por quê |
|---|---|
| **Regras puras separadas** em `Shared/Match/MatchRules` (duplas, folga, confrontos, ilhas, vidas, Virada, final, campeã) e `Shared/Match/LoadoutRules` (armas por rodada). O `MatchService` cuida do tempo, dos personagens e da rede. | Os testes simulam partidas inteiras (4, 7, 8 e 16 jogadores, 50 sementes cada) sem servidor. |
| **Máquina de estados** no `MatchService`: `Receiving → Forming → [Draw → Prep → Combat → RoundEnd]… → Champion → EndScreen`. `Draw` junta SORTEIO_CONFRONTOS e TELEPORTE (3 s com os confrontos na tela; depois todos vão para as ilhas). RECOMPENSAS E ELO fica vazio até a F9. | GDD 4.1. Nomes curtos no código; o painel de teste mostra os nomes em português. |
| **Começo sem fila (até a F5):** entram os jogadores do servidor. A partida começa 20 s depois do primeiro jogador, com o mínimo de `MatchConfig.Start.MinPlayers` (4; 2 em `DEV_`), ou na hora com 16. Quem chega no meio assiste do mirante e entra na próxima. | FASES F3: "quem estiver no servidor". |
| **2 jogadores (só em teste):** se a formação daria uma dupla só, cada um vira uma dupla de uma pessoa. | Dá para testar a partida com 2 clientes. Em produção o mínimo é 4. |
| **Amigos no Roblox** (`IsFriendsWithAsync`) são conferidos em paralelo, até 5 s no total. Duplas fixas vindas do lobby entram pelo `TeleportData` na F5 (a função já aceita). | GDD 4.2. |
| **Mundo cinza montado por código** (`MatchWorld`, nada salvo no place): mirante em losango a 70 studs de altura, plano, com barreira invisível nas 4 bordas; cada borda fica de frente para uma ilha. As 4 ilhas (140 × 100) ficam nas diagonais, abaixo, com o mesmo desenho simétrico: bases nas pontas, galpão coberto no centro, rotas laterais, plataformas de 2º nível, cobertura fina e mureta. Medidas em `MapConfig.Gray`. *(Revisto na F10: mirante octogonal com piso de vidro, ilhas nos 4 lados, `MapConfig.World`, e os mapas também são montados por código; ver F10.)* | FASES F3 e ESTILO T4. |
| **Mesma ilha:** o combatente tem o atributo `Island`; o servidor só aceita dano entre combatentes da mesma ilha, e o cliente só mira e contorna quem está na mesma ilha. No mirante ninguém é combatente (sem vida, sem armas, sem contorno). | "Quem está no mirante não interfere" e uma ilha não atira na outra. |
| **Preparação:** o jogador nasce na base congelado (`HumanoidRootPart` ancorado: não anda, mas olha em volta) e sem armas; as armas só chegam no começo do combate. | GDD 4.10: congelado na base. Nada a validar durante a preparação. |
| **Armas sem escolha a tempo:** escolha atual → escolha da rodada anterior → última salva no perfil para a fase (`loadout.lastPrimaryByPhase`, `lastSecondary`) → primeira da lista. O perfil é atualizado no começo de cada combate e serve para **Repetir última**. | GDD 4.10 e DADOS 3.1. |
| **Zona:** círculo por ilha, centrado no meio da ilha, que começa cobrindo a ilha inteira e fecha até 8 studs de raio entre 60 s e 90 s. Fora dele, 10 de dano por segundo direto na vida. No cliente, um cilindro roxo bem transparente (sem neon). | GDD 4.4. Valores em `MatchConfig.Zone`. |
| **Cair da ilha:** abaixo de 25 studs do chão, volta para a sua base e perde o escudo; no mirante, volta para o mirante. | `MapConfig.General.FallOutReturnsToBase` / `FallOutLosesShield`. |
| **Espectar o parceiro:** cada cliente manda para onde olha (`LookSync`, sem garantia de entrega, até 15 por segundo); o servidor confere e guarda no atributo `LookDir` do personagem. Quem caiu põe a câmera na cabeça do parceiro, olhando para essa direção, e esconde o corpo dele só na própria tela. | GDD 4.3, sempre em primeira pessoa (GDD 3.1). |
| **Mirante:** no cliente, telhados com a tag `MiranteRoof` ficam 85% transparentes e os nomes das ilhas aparecem só para quem está no mirante; quem joga numa ilha não vê os espectadores do mirante. | GDD 6.5. |
| **Duelo que acaba antes:** a dupla volta ao mirante 3 s depois, para assistir os outros. | Ninguém fica parado numa ilha vazia. |
| **Saída e ausência (GDD 4.9):** quem sai deixa o parceiro sozinho; sem ninguém da dupla, ela é eliminada no fim da rodada. Ausência conta só no combate (andar, olhar ou usar arma zera): aviso aos 30 s, volta ao lobby aos 60 s (no Studio, onde não há teleporte, o jogador é desconectado com a mensagem). | Regras do GDD 4.9. |
| **Volta ao lobby** (`LobbyReturn`): salva e libera o perfil e teleporta com `TeleportData = { from, reason, partyWith }`; `partyWith` é o parceiro quando os dois responderam "sim" a "seguir juntos". No Studio não teleporta: avisa e, no fim, a partida recomeça no mesmo servidor. | GDD 4.8 e DADOS 5.3. A fila da F5 lê `partyWith`. |
| **Mensagens:** `MatchState` (foto completa da partida a cada mudança, para todos), `MatchEvent` (preparação, avisos, telas de saída, para um jogador), `MatchRequest` (pedidos do cliente: escolha de armas, confirmar, assistir, nova partida, resposta do parceiro; até 20 por segundo, tudo validado). | Servidor é a autoridade; o cliente só mostra. |
| **Telas provisórias** (HUD da partida, modal de preparação, telas de eliminação e fim) com `Theme` e `Strings`, modal sobre o jogo (nunca fundo preto), mouse livre no PC enquanto abertas, atalhos 1–8 e Enter no modal, primeiro cartão selecionado no controle. | Visual final na F7. |
| **Painel TESTE › PARTIDA** (só `DEV_`): começar agora, pular rodada (no combate decide pelo tempo esgotado), tirar 1 vida de uma dupla (entre rodadas na hora; no meio da rodada, no fim dela), forçar Virada, jogadores de teste (alvos parados; duelo só entre eles é sorteado depois de 6 s) e recomeçar a partida. | Comandos de teste da FASES F3; com jogadores de teste dá para montar partidas de 4 a 16 com um cliente só. |
| A arena de teste da F2 continua no código: `CombatConfig.TestArena.Enabled = true` volta a ela (sem partida). | Para testar só o combate. |

### F4 · Cartas

| Decisão | Por quê |
|---|---|
| **Cargas e recarga numa máquina pura** (`Shared/Cards/CardState`), a mesma no servidor (autoridade) e no cliente (botão responde na hora). Cada rodada começa com as cargas cheias; com recarga, a carga volta uma por vez; entre dois usos há um intervalo mínimo (`minInterval`). A ult tem `CardConfig.UltUsesPerRound` usos. Regras da escolha, da ult na 4ª rodada e a geometria (arco, onda, nuvem) em `Shared/Cards/CardRules`. | Igual às armas (WeaponState): cliente e servidor nunca discordam; os testes usam o mesmo código. |
| **`CardService` no servidor** valida cada pedido (`CardAction`): carta valendo nesta rodada para este jogador, vivo, no combate, horário em tempo do servidor (mesma janela dos tiros), carga, recarga, intervalo e até 10 pedidos por segundo. Recusou: manda o estado certo de volta (`CardEvent "Cards"`). | CLAUDE.md: servidor é a autoridade das cartas. Teste: 10 pedidos de uma vez → 1 aceito; carta não escolhida e ult travada → 0. |
| **Escolha da carta** fica no `MatchService` (pedido `PrepCard`, só na etapa da carta, só carta básica que o jogador tem). No fim da etapa ela trava; sem escolha = sem carta básica. A carta escolhida é salva em `loadout.lastCard`. As cartas são armadas (`CardService.arm`) no começo de cada combate e tiradas ao ir para o mirante, ao ser derrubado e no fim da rodada. | GDD 8.2 e DADOS 3.1. |
| **Impulso:** o cliente aplica a velocidade para cima (`√(2·g·altura)`) na hora; o servidor só gasta a carga. | No Roblox o corpo do jogador é simulado pelo próprio cliente; o servidor não consegue empurrá-lo sem atraso. Quem trapaceia no movimento já consegue voar de qualquer jeito. |
| **Nuvem:** o servidor calcula o arco a partir da cabeça do jogador e da direção da câmera, com raios contra o mapa, e cria a esfera (`CardWorldEffects`, tag `CardSmoke`, sem colisão e invisível para raios). Os clientes animam a bola e fazem a nuvem crescer. O cliente esconde o contorno do inimigo e desliga tiro automático/assistência quando a linha até ele passa por uma nuvem (`Smoke.blocks`). | O contorno (`Highlight`) aparece através de peças transparentes; sem essa conta ele "furaria" a nuvem. |
| **Tremor:** o servidor limita a onda na primeira parede à frente, escolhe os inimigos dentro do retângulo, sem parede no meio e na mesma altura, e aplica o efeito quando a onda passa (se ainda estiverem no chão: raio para baixo de até 4,5 studs). Lentidão: `CombatService.applySlow` multiplica a velocidade de andar. Mira tremida: atributo `TremorUntil` no personagem; o cliente balança a câmera (ruído suave, sem acumular desvio). | GDD 8.4. A lentidão é do servidor; o tremor da mira é do cliente (como o recuo). |
| **Renascer:** guarda de queda no `Combatants` (`setKnockGuard`): antes de derrubar por tiro, golpe ou zona, o `CardService` leva o jogador à marca com vida e escudo cheios e 0,5 s de proteção; sem queda, sai do mesmo jeito depois de 8 s mantendo a vida. Marca no chão em neon (efeito de carta). | GDD 8.4. Sem corpo derrubado, sem abate para quem atirou. |
| **Controles:** PC C/Q/E/X; controle LB = básica e RB = ult (só dá para levar uma básica e a ult); celular com botões redondos fixos ([Q][E][C] ao lado da MIRA, [X] ao lado de RECARREGAR, posições em `CombatConfig.TouchLayout`). Nuvem: segurar mostra o arco, soltar arremessa (nos três). Celular: segurar as outras cartas abre os detalhes. | GDD 7.2.6 e 13.1. Só aparecem as cartas da partida, cada uma no lugar da sua tecla. |
| **HUD das cartas provisório** (`CardHUD`): no PC/controle, cartas embaixo no centro com chip da tecla, cargas, segundos de recarga e cadeado da ult; dica fixa **[B] Habilidades**; painel de habilidades (B, direcional ↓ ou toque longo) com o que cada carta faz. Avisos "RENASCER · N s" e "ATINGIDO PELO TREMOR". Sem neon no HUD; cada carta com a sua cor (`Theme.Cards`). | ESTILO T6 e GDD 13.3. Visual final na F7. |
| **Etapa CARTA no modal:** cartões com nome, tecla, o que faz e atalho 1–3; a ult ao lado com cadeado; travada (🔒) depois. Sem moldura de raridade, porque a raridade das cartas iniciais está `[ABERTO]` (GDD 8.9): borda na cor da carta. | ESTILO T2. |
| **Comandos de teste:** DADOS › DAR AS 4 CARTAS / TIRAR AS CARTAS (pela regra real de uma carta por tecla); PARTIDA › CARTAS: cargas cheias, levar 300 de dano (`DevConfig.HurtSelfDamage`), carta 10× de uma vez e carta não escolhida (contados pelo servidor). | FASES F4: comando para dar as 4 cartas até o tutorial existir; critério "cliente não consegue usar carta em recarga ou que não escolheu". |
| **Teleporte de teste "levar todos"** (só `DEV_`): o mesmo pedido `DevTeleportRequest` com `todos = true` salva e libera o perfil de todos os jogadores do servidor e teleporta a lista de uma vez (na Partida, um único servidor reservado). Um pedido a cada 10 s por servidor (`DevConfig.TeleportGroupCooldownSeconds`); o botão pede um segundo toque. | Testes em grupo do marco "primeiro jogável" antes da fila (F5): sem isso, cada jogador caía numa Partida diferente. |
| Nas cartas novas, a tecla é guardada como `string` (os valores continuam sendo só C, Q, E e X). | O verificador de tipos do Luau perde o tipo `"C" \| "Q" \| "E" \| "X"` ao ler de tabelas e acusava erro em todo uso. |

### F5 · Lobby e fila

| Decisão | Por quê |
|---|---|
| **Regras da fila puras** em `Shared/Queue/QueueRules` (7 → espera 15 s até 16; flexível a partir de 4 depois de 20 s; faixas que se juntam depois de 45 s; dupla nunca separada; prioridade). "Quando a fila chegou a 7" não é guardado: é o horário de chegada da ficha que fez a conta passar de 7, recalculado a cada ciclo. | Os testes simulam a fila sem servidor; nenhum estado escondido entre servidores. |
| **Fila no MemoryStore como mapa ordenado** (`MatchQueue_v1`), não como fila (`MemoryStoreQueue`): uma **ficha** por grupo, com validade de 30 s renovada a cada 3 s pelo lobby dono. Servidor que cai = fichas somem sozinhas. | O líder precisa ler a fila inteira (faixas, tempos, duplas); a fila do MemoryStore só entrega itens um a um. |
| **Um lobby líder** por vez (trava no `MatchQueueControl_v1`, 10 s). O líder lê as fichas a cada 1 s, monta as partidas, reserva o servidor, grava o `MatchHandoff`, marca as fichas com o código e avisa os lobbies (MessagingService). O líder também grava o estado da fila (contagem "5/7"), que os outros lobbies leem a cada 2 s. | GDD 16.5. Um só servidor decide: duas partidas nunca pegam a mesma ficha (a marca é feita com `UpdateAsync`, que recusa ficha já marcada). |
| **Cada lobby teleporta os seus jogadores** (`TeleportToPrivateServer`). O aviso pelo MessagingService pode se perder; a renovação da ficha descobre a marca em até 3 s. Teleporte que falha ou trava (30 s) → perfil reaberto e o grupo volta para a fila, **na frente**. | O Roblox só teleporta quem está no servidor. FASES F5: ninguém fica preso em teleporte. |
| **`MatchHandoff_v1`** usa a chave **`PrivateServerId`** (devolvida pelo `ReserveServerAsync`), não o código de acesso: o servidor de partida lê `game.PrivateServerId`. Expira em 5 min. Contém os UserIds, as duplas fixas e a faixa. | O servidor reservado não conhece o próprio código de acesso. |
| **Volta da partida pelo `LobbyHandoff_v1`** (chave `u_<UserId>`, 2 min): "entrar direto na fila", "passar na frente" e "dupla fixa com X". O `partyWith` saiu do TeleportData (F3). A dupla só é refeita se os dois apontam um para o outro; ela viaja num teleporte só e cai no mesmo lobby. Se o parceiro não chegar em 20 s, segue sozinho. | DADOS 5.3: dados de teleporte passam pelo cliente. |
| Nomes no MemoryStore com o prefixo `DEV_` em teste e o sufixo `_Studio` no Studio. | Testes no Studio não se misturam com os servidores publicados de teste. |
| **No Studio** não há servidor reservado nem teleporte: a fila funciona (dá para testar grupo e fila com vários clientes no Studio), mas a partida "encontrada" só gera um aviso. | O teste de verdade (critérios de aceite) é no jogo publicado. |
| **Faixa de fila:** `stats.matchesPlayed` < 10 ou elo Bronze/Prata = Aprendizes. Elo pela tabela `RankConfig.Tiers`. Até a F9, todo mundo é Aprendiz (ninguém ganha partidas nem pontos ainda). | GDD 6.3. |
| **Teste:** `QueueConfig.Dev` = mínimo 2, começa em 5 s, faixas juntas em 5 s. Painel TESTE › FILA (só no lobby, só `DEV_`): estado da fila, **começar já com quem está na fila** (respeita o mínimo de teste) e lista das fichas no Output. | FASES F5: "mínimo 4 em produção; reduzir em teste". |
| **Lobby simples** (`LobbyScreen`): dupla à esquerda, cartão do modo com JOGAR / "Procurando partida… 5/7" / CANCELAR à direita, moedas no topo, janela de convite e convite recebido. PC: `[Enter]` jogar/cancelar, `[G]` convidar, `[Y]`/`[N]` aceitar/recusar, chips visíveis. Controle: X e Y, seleção pelos botões. **No PC o mouse fica livre no lobby** (é um menu); a câmera continua em primeira pessoa. | ESTILO T3 e 3. Visual final na F7. |
| As peças de interface provisórias (`MatchUi`) foram para `Shared/Ui/ProvisionalUi`, usadas pela partida e pelo lobby. *(Substituídas na F7 por `Shared/Ui/Ui` e `Common/Ui/Widgets`.)* | Evitar duas cópias até os componentes finais da F7. |
| Partida vinda da fila: começa quando todos chegam ou 20 s depois do primeiro; segue com 2 ou mais (`MatchConfig.Start.MinArrived`). Quem não estava na composição volta ao lobby (fora de `DEV_`). A composição vale só para a primeira partida do servidor. Sem composição (teleporte de teste), vale a regra da F3. | GDD 4.1 e 4.9 (decisões da F5). |

### F6 · Tutorial (e revisão da marcação de times)

| Decisão | Por quê |
|---|---|
| **Marcação de aliado e inimigo** (`TeamMarkers` no cliente, regra pura em `Shared/Combat/MarkerRules`): a cada 0,1 s, raios da câmera até 6 pontos do corpo. Inimigo à vista: `Highlight` "Occluded" vermelho, com a transparência do contorno pulsando em seno (`CombatConfig.Markers`), e barra vermelha. Aliado à vista: barra verde e nome. Aliado todo escondido: `Highlight` "AlwaysOnTop" verde com preenchimento. A barra é um `BillboardGui` de tamanho fixo na tela, ligado só quando a regra manda (por isso pode ficar "por cima de tudo"). | GDD 7.6 revisto pelo dono do projeto (guia visual de marcação). |
| **Avatar do Roblox** carregado no servidor (`GetHumanoidDescriptionFromUserId`, uma vez por sessão), com as escalas do corpo zeradas para o padrão (`CharacterConfig.Avatar`). Falhou ou UserId de teste (≤ 0, como os jogadores do Studio): corpo base. Acessórios ficam no grupo de colisão do corpo (tiros e visão atravessam). | GDD 3.2. A hitbox continua a mesma para todos. |
| **Combate e cartas numa pasta própria** (`src/combat/{server,client}`), mapeada como `ServerScriptService.Combat` e `StarterPlayerScripts.Combat` só na Partida e no Tutorial. O Boot carrega Common → Combat → Place. Os efeitos das cartas leem o mirante pelo atributo do jogador, sem depender do `MatchClient`. | O tutorial usa as mesmas armas e cartas da partida, sem cópia. |
| **Tutorial conduzido pelo servidor** (`TutorialService`, regras puras em `Shared/Tutorial/TutorialRules`, números em `TutorialConfig`): o servidor confere cada tarefa (alvo derrubado com quem atirou, recarga/troca/mira aceitas pelo `CombatService`, uso das cartas pelo `CardService`, posição a cada 0,1 s) e manda uma foto (`TutorialState`). O cliente só pede (`TutorialRequest`: continuar, pular, olhei, terminar). | CLAUDE.md: servidor é a autoridade das cartas e do perfil. |
| **`tutorialStep`** guarda a etapa em que o jogador está (1 a 8; 0 = nunca começou), salva ao entrar em cada etapa. Lições de armas não são salvas por dentro (a etapa recomeça); cartas já ganhas são puladas. | FASES F6: "retomar da etapa". |
| **Cartas entregues ao completar cada desafio** (`source = "tutorial"`), salvando na hora. No final, por segurança, quem chega lá recebe as que faltarem. O DADOS 3.2 dizia "ao terminar o tutorial"; vale o GDD 5.2 e a FASES (corrigido no DADOS). | GDD 5.2. |
| **Desafios das cartas:** Impulso = subir numa plataforma de 13 studs (o pulo normal não alcança); Nuvem = cair dentro de um círculo; Tremor = acertar 2 alvos; Renascer = ativar e pisar numa área de perigo (vermelha), que só derruba com o Renascer ativo (sem ele, volta ao começo). Errou: as cargas voltam em poucos segundos. A ult fica liberada no tutorial. | Tutorial curto (3 a 5 min) sem esperar recargas. |
| **Armas:** 6 lições (Bolinha, Ferrão, Balde, Tático, Luneta, Martelo), cada uma ensinando uma coisa: atirar, recarregar, trocar de arma, modo alternativo, mira de sniper e metralhadora; depois um painel com as fases da partida (lido de `WeaponConfig.Phases`). O fuzil é o Tático (fuzil leve) porque o Rajada não tem modo alternativo. | GDD 5.2. |
| **"Olhei os marcadores"** é a única tarefa avisada pelo cliente (o servidor não sabe para onde a câmera aponta); não dá nada além de passar dessa tarefa. | Sem risco: cartas e `tutorialDone` continuam só no servidor. |
| **Voz:** `VoiceChatService:IsVoiceEnabledForUserIdAsync` no cliente. Ligada: medidor do microfone pela API de áudio (`AudioDeviceInput` do jogador → `AudioAnalyzer`); se o Roblox não der o áudio, só o texto. Desligada: como ativar nas configurações do Roblox. Ao continuar ou pular, `settings.voicePromptSeen = true`. | GDD 5.2 e 12. O jogo não ativa nada sozinho. |
| **Sensibilidade com prévia na hora** (`AimCamera.setPreview`), um controle para o aparelho em uso e outro para a mira aberta (sniper na mão). Salvar usa o pedido normal de configuração (validado). No PC/controle, TESTAR esconde o painel para mirar com o mouse preso; F/B volta. | GDD 5.2 e 7.5. |
| **Retícula:** desenho em `Shared/Ui/Crosshair`, usado pelo HUD e pela prévia do editor. Cores prontas em `Theme.CrosshairPalette` (sem vermelho). | Uma só implementação da retícula. |
| **Lobby → Tutorial** (`TutorialGate` no lobby, `PlaceTeleport` comum): perfil carregado com `tutorialDone = false` → servidor reservado só para o jogador. **Tutorial → Lobby:** ao terminar, ou na hora para quem já terminou. Perfil salvo e liberado antes (DADOS 5.3). No Studio não há teleporte: o lobby segue normal e o tutorial deixa refazer. | GDD 5.1. |
| **Arena do tutorial** montada por código (`TutorialWorld`, nada salvo no place), em Y = 200, 7 estações fechadas (com teto invisível). Os alvos são jogadores de teste do time "Alvo" (contorno e barra vermelhos, como inimigos). | Visual cinza aceito até a F10. |

### F7 · Interface final

| Decisão | Por quê |
|---|---|
| **Duas camadas de interface:** `Shared/Ui/Ui` (peças básicas: telas, textos, listas, painel chanfrado, chip de tecla) e `Common/Ui/Widgets` (componentes: botão principal e secundário, abas, cartão de item, modal, barras, barras de atributo, slider, escolha, liga/desliga, raridade, animações). `Common/Ui` também tem `Avatars`, `Logo` e `WeaponPreview`. O `ProvisionalUi` saiu. | Os componentes precisam saber o controle em uso (chips de tecla), que só existe no cliente. |
| **Canto chanfrado sem imagem:** o fundo do painel são 3 retângulos que não se sobrepõem + 2 quadradinhos com `UIGradient` a 45° que deixa só a metade (um triângulo). Corte no canto superior esquerdo e no inferior direito (`Theme.Chamfer`). Por isso listas e espaçamentos vão no quadro **Content** do painel (`Ui.panel` devolve painel e conteúdo), e o painel automático acompanha a altura do conteúdo por código. | ESTILO 2.5. Sem subir imagem para o Roblox; transparência igual em todo o painel. |
| **Tamanho do texto (100/115/130%)** pelo `TextScale`: toda tela criada com `Ui.screen` guarda o tamanho "base" de cada texto e mostra base × escala; mudar o tamanho no código vira a base nova. Texto de botão que não cabe encolhe até o tamanho de rótulo (`Widgets.fitText`), já contando a escala. | ESTILO 5. Funciona em todas as telas sem cada uma tratar a escala. |
| **Painel P (configurações)** no `SettingsController`, igual nos 3 places: abas Retícula, Sensibilidade (com tiro automático no toque e assistência de mira no toque/controle), Áudio, Voz, Acessibilidade e, só no toque, Botões. O jogo não pausa. As mudanças de uma aba são salvas **ao trocar de aba ou fechar** (um pedido só, e só se algo mudou); as escolhas de botão (cor do inimigo, tamanho do texto, reduzir efeitos) valem na hora. Os editores de retícula, sensibilidade e voz são os do tutorial, agora em `Common/Settings`. Qualidade gráfica fica no menu do Roblox (sem campo novo no perfil). | GDD 13.3 e ESTILO T6. Poucos pedidos ao servidor (limite de 10 a cada 5 s). |
| **Atalhos** em `UiConfig.Keys`: P configurações, B habilidades, Tab placar (segurar). Controle: direcional → configurações, ↓ habilidades, ← placar (Select e Start são do Roblox). Celular: engrenagem e botão PLACAR no canto superior esquerdo; toque longo na carta para as habilidades. | GDD 13.3; ESC nunca é usado. |
| **Editor de botões do celular** (`LayoutEditor`): tela cheia com os 8 botões de combate (ATIRAR, MIRA, 1⇄2, RECARREGAR, Q, E, C, X); arrastar move, − / + mudam a escala (50% a 200%), PADRÃO volta tudo. Salva `settings.mobileLayout` com o centro relativo (0 a 1) da área segura e a escala sobre o tamanho padrão. `Shared/Ui/TouchLayout` resolve padrão × salvo para os botões e as cartas. | GDD 13.1 [PROPOSTA]; DADOS 3.1. |
| **HUD (T6):** topo com 2 avatares de cada lado (anel na cor da equipe), corações e tempo numa placa; encolhe (até 70%) em tela estreita para não encostar na engrenagem nem no minimapa. Dicas fixas [B] [P] [Tab] acima das barras, só no PC/controle. Aviso `N KILL` entra um pouco maior e volta. | ESTILO T6 e GDD 13.3. |
| **Minimapa:** redondo (`CanvasGroup` para recortar o círculo), norte para cima, ilha atual desenhada a partir das **peças do mapa** acima do chão (serve para os mapas da F10 sem mudar código), zona, você (seta na direção da câmera), parceiro em verde e inimigos só enquanto o contorno deles está ligado (`TeamMarkers.seenEnemies`), mais 1,5 s. | GDD 7.6: inimigo só quando visto. Pings entram na F8. |
| **Placar (Tab)** desliga a lista de jogadores do Roblox na Partida. Mostra todas as duplas (cor + nome da cor), jogadores com avatar e abates (atributo `Kills`), vidas e situação; a minha dupla primeiro. Ícone de elo fica para a F9. | GDD 13.3. |
| **Legendas** (`Captions`): "Inimigo usou X" (mesma ilha), "Parceiro usou X", escudo quebrado e zona fechando. Os efeitos das cartas (`CardFx`) passaram a mandar quem usou (`caster`). | ESTILO 5. |
| **Modal de preparação (T2):** etapas como abas; cartões de arma com a arma em 3D pequena (`WeaponPreview`, formas de blocos movidas para `Shared/Combat/WeaponShapes`); barras de atributo só nas etapas de arma; no celular uma aba por categoria; com uma categoria só (pistolas) os cartões ficam em linha. X do controle confirma. | GDD 4.10 e ESTILO T2. |
| **Lobby (T3):** painéis presos embaixo da barra do topo; abaixo de 440 px de altura (celular deitado) some a faixa e a frase do modo e as linhas da dupla diminuem, sem reduzir alvos de toque. Navegação Jogar / Arsenal / Cartas / Mapas / Ranking / Loja; **Ranking e Loja aparecem desativados ("Em breve")** até a F9/F11. Fundo: mirante e ilhas cinza flutuantes montados só no cliente (`LobbyBackdrop`). | ESTILO T3. Decisão provisória, fácil de trocar se o dono preferir esconder. |
| **Cartas (T1), revista pelo dono do projeto** (referência `docs/referencias/ref-t1-cartas.webp`): filtros numa linha (TODAS, tecla C/Q/E/X e raridade, que se combinam; filtro sem carta fica apagado), carrossel em ordem de tecla, selo de raridade ao lado do nome, linha de atributos lida do `CardConfig`, EQUIPAR (mostra "EQUIPADA": uma carta por tecla, GDD 8.3), GIRAR desativado (GDD 8.9 [ABERTO]) e aba "Skins de cartas / versos" desativada (F9). As 4 cartas iniciais seguem **sem raridade** (GDD 8.9 [ABERTO]): borda na cor da carta e "Raridade a definir". Arte das cartas na F10. | Pedido do dono no teste da F7: os filtros de raridade deixavam a tela vazia e a coleção vai crescer por tecla. |
| **Arsenal (T5), revisto pelo dono do projeto** (referência `docs/referencias/ref-t5-arsenal.png`): sem abas e sem rolagem; as 18 armas + corpo a corpo em 4 linhas de grupos (Pistolas · SMG + Escopetas + Corpo a corpo · Fuzis leves + Fuzis · Snipers + Metralhadoras), com o tamanho dos cartões calculado pelo espaço da tela. Painel com a arma girando, barras de Dano, Cadência, Alcance e Mobilidade (`Shared/Combat/WeaponStats`, as mesmas do modal de preparação), EQUIPAR e a fila de skins logo abaixo (Padrão + espaços com cadeado até a F9). Barras no acento roxo (a referência tinha vermelho, reservado a inimigo e perigo). | Pedido do dono no teste da F7: tudo numa tela, as armas são fixas e o que muda é a skin. |
| **Logo provisória** (`Common/Ui/Logo`): `Strings.GameName` em Oswald + carta roxa inclinada com uma estrela e brilho roxo. O nome continua [ABERTO]. | ESTILO 2.4. |
| **Sombreado dos menus** (`Theme.Shade`, pedido do dono com a referência `docs/referencias/ref-menus-armas.webp`): o fundo chanfrado tem peças com a cor de cima (topo), um `UIGradient` que multiplica a cor até `Shade.Bottom` (meio) e a cor escura (base), então encaixam sem emenda e qualquer cor fica sombreada do mesmo jeito (`Ui.setFill`, `Ui.addShade`). Painéis com filete claro no topo. Cartão de item com luz atrás da imagem, marcador de cor (`setMarker`) e seleção roxa com ✓. Títulos de seção "// TÍTULO" (`Widgets.titleText`). | Menus sem o "preto com borda roxa". |
| **Modelos low poly detalhados das 18 armas e do Bastão** (`Shared/Combat/WeaponModels`, pedido do dono; referências `ref-menus-armas.webp` e `ref-tatico-atirador.webp`; resultado `docs/referencias/resultado-todas-as-armas.jpg`): cada arma montada peça por peça (caixas, cilindros e cunhas, ~30 a 60 peças) com conjuntos comuns — empunhadura, trilho com dentes, freio de boca, fendas, pente curvo ou reto, luneta, mira holográfica, red dot, alças de ferro, coronha AR — e as peças próprias de cada uma (ex.: tambor de revólver, silenciador, coronha dobrável, porta-cartuchos, carregador de tambor, alça de transporte, cano duplo, para-sol e bipé, caixa de munição, 6 canos). Cores no `Theme.WeaponLook` (corpo, escuro, destaque, metal, lente); nenhuma vermelha. Cada modelo diz onde ficam a boca do cano e as mãos; o `WeaponShapes` só monta (mãos na primeira pessoa, Bastão inclinado na mão) e guarda uma forma simples de reserva. **Pentes curvos inclinam a base para a frente e encaixam embaixo do encaixe** (correção pedida no Tático e no Atirador). Vitrines: `WorldPivot` fixo no modelo para a caixa envolvente não herdar o giro da primeira peça. Arte final continua na F10. | Diferenciar as armas e mostrar o nível possível com peças do Roblox. |
| **Símbolos nos textos:** só caracteres que a fonte do Roblox desenha (testado no Studio): ◆ ★ ☀ ● ◉ ◎ ▲ ▼ ⏱ ✓ ‹ › ∞ ♥ ♡ ⇄ − e os emojis 🔒 👑 🔄. Coroa da Lendária = 👑; recarga e GIRAR = 🔄. | ♛, ⟳, ⇡, ⇣, ◷ e ✕ apareciam como quadradinho. |
| Testes automáticos novos (`Interface.spec`): layout dos botões (padrão, salvo, escala, validação), contraste de 4,5:1, nenhum vermelho fora de perigo/inimigo, raridade com nome e ícone, alvos de toque mínimos e modal nunca opaco. | Checklist do ESTILO 6 no que dá para testar sem tela. |

### F8 · Social e voz

| Decisão | Por quê |
|---|---|
| **Voz pela API de áudio, com a voz padrão desligada na Partida** (`match.project.json`: `VoiceChatService.EnableDefaultVoice = false`, `UseAudioApi = Enabled`). O servidor (`VoiceService`) cria o microfone de cada jogador (`AudioDeviceInput` "TeamVoice" no Player) com `AccessType = Allow` e a lista de quem pode ouvir (`SetUserIdAccessList`), refeita quando muda a dupla ou o lugar (`MatchLocation`) e a cada 1 s. O cliente (`VoiceRouter`) só escolhe o caminho: parceiro ligado direto num `AudioDeviceOutput` (sem distância); no mirante, `AudioEmitter` no personagem de quem fala + `AudioListener` na câmera. Tudo passa por um `AudioFader` com o volume master × voz das configurações. | GDD 12.2. A lista de acesso fica no servidor: a voz da dupla não chega à adversária nem a um cliente modificado. Testado no Studio que um plugin (o Rojo) consegue gravar essas propriedades. |
| **Regra da voz pura** (`Shared/Social/SocialRules.voiceMode`): os dois no mirante → proximidade; mesma dupla, fora disso → direto; o resto → ninguém ouve. Se a voz padrão continuar ligada no place por engano, o servidor aplica a lista de acesso também no microfone que o Roblox cria (scripts do jogo não conseguem ler `EnableDefaultVoice`, então não há aviso). | Testável sem servidor (`SocialRules.spec`). |
| **Chat por canais** (`ChatChannels` no servidor): `TextChatService.CreateDefaultTextChannels = false` na Partida; um `TextChannel` por dupla (`Dupla_<cor>`) e um `Mirante`, com `AddUserAsync` e a `TextSource` apagada ao sair. O cliente (`ChatTarget`) aponta a barra do chat para o mirante (lá) ou para a dupla (na ilha) e põe "[Dupla]" / "[Mirante]" na frente das mensagens. Jogadores de teste do Studio (UserId negativo) ficam fora dos canais. | GDD 12.3: só a dupla, para quem o Roblox deixa usar o chat. |
| **Pings, frases, emotes e elogio** pelo `SocialService` (remotes `SocialRequest`/`SocialEvent`, tipos em `Shared/Social/SocialTypes`). O servidor confere tipo, lugar (ping só na ilha; emote no mirante e no fim da rodada), alcance do ping (300 + 12 studs do personagem), intervalo de cada tipo e o limite geral (15 pedidos a cada 5 s). Ping e frase vão só para quem fez e o parceiro. O emote é tocado pelo servidor no `Animator` (todos veem) e para quando o jogador anda, muda de lugar ou passa de 8 s. | CLAUDE.md: o servidor é a autoridade; o cliente só pede e mostra. |
| **Rodas** (`SocialWheel`): opções em volta do centro, com botões que liberam o mouse. PC: segurar a tecla abre e soltar escolhe a opção sob o mouse; toque curto em V/G deixa a roda aberta. Celular: segurar o botão abre, tocar escolhe, tocar fora fecha. Controle: segurar abre com a primeira opção selecionada, A escolhe, B fecha. A roda de frases também leva aos emotes e ao elogio quando valem (assim o controle chega a tudo com R3 e L3). | GDD 13.3 e ESTILO 3: tudo no toque, teclado e controle. |
| **Atalhos** (`UiConfig.Keys`): Z ping (toque curto = rápido, segurar = roda), botão do meio do mouse = ping rápido, V frases, G emotes, H elogiar; controle R3 ping, L3 frases. Dicas fixas numa segunda linha acima de [B] [P] [Tab], só na Partida. | Teclas livres no jogo e no Roblox; ESC nunca. |
| **Botões de toque PING, FRASES e EMOTES** no editor de botões (`TouchLayout.ButtonIds`), por padrão numa linha no canto superior esquerdo, embaixo do PLACAR (`SocialConfig.Touch`). PING só aparece na ilha; EMOTES só quando vale. | GDD 13.1: o layout é do jogador. |
| **Marcador do ping:** `BillboardGui` por cima de tudo, num `Attachment` no Terrain, com ícone, nome curto e distância em metros (1 stud ≈ 0,28 m); no minimapa, o ícone na cor do ping (`Minimap.addPing`). "Inimigo aqui" usa a cor de contorno de inimigo escolhida pelo jogador; "Cuidado" é laranja, não vermelho. No máximo 2 marcadores por jogador; somem fora da preparação e do combate. | ESTILO 5: nunca só a cor. |
| **Tela final:** linha ADICIONAR AMIGO (`SetCore "PromptSendFriendRequest"`, some como "JÁ SÃO AMIGOS" pelo `IsFriendsWith`), ELOGIAR e DENUNCIAR, também na tela de dupla eliminada. O SIM da pergunta do fim virou "JOGAR DE NOVO JUNTOS". | GDD 12.4. |
| **Denunciar** (`ReportPanel`, pelo placar e pela tela final): o `SetCore` do Roblox não tem a denúncia ("PromptReportAbuse" não existe; testado no Studio), então a tela explica o caminho pelo menu do Roblox e tem BLOQUEAR por jogador (`SetCore "PromptBlockPlayer"`). O botão DENUNCIAR do placar libera o mouse enquanto o placar está aberto (no PC, segurando Tab, a câmera para de girar). | GDD 12.4 e decisão do dono: só o fluxo do Roblox. |
| **Parceiros recentes:** quando a dupla se forma na partida (`TeamService.onChanged`), os dois entram no `social.recentPartners` um do outro (`ProfileRules.addRecentPartner`: 10, mais recente primeiro, sem repetir). Elogio: `ProfileRules.addPraise`. | DADOS 3 e 4. |
| **Sons provisórios** de ping e de frase do parceiro em `AudioConfig` (estalo curto). | Sons finais na F10. |
| **Boot do cliente espera a pasta `Place`** (até 10 s) antes de carregar os módulos. Num place gerado do zero, o Roblox copiou `Place` para o jogador depois de o Boot rodar, e as telas da Partida não abriam. | Achado nos testes da F8; os 3 places têm a pasta `Place`. |

### F9 · Elo, economia e arsenal

| Decisão | Por quê |
|---|---|
| **Regras puras em `Shared/Progression`:** `RankRules` (faixa, ADM, tabela proporcional, proteção das 10 primeiras partidas, perda dobrada em Mestre+, colocação de quem sai) e `EconomyRules` (moedas da partida peça por peça, primeira vitória do dia por dia UTC, bônus do parceiro, corte da partida privada). Testadas em `Progression.spec`. | Números só em config; regras testáveis sem servidor. |
| **`RankService`** (Common, os 3 places) é o único que muda `rank`: aplica o PE da colocação, conta a partida ranqueada e grava no `RankLeaderboard_v1` (OrderedDataStore, chave = UserId) por uma fila com novas tentativas e espera crescente, respeitando o orçamento de pedidos; o servidor espera a fila esvaziar ao fechar (até 20 s). O ADM e jogadores de teste (UserId ≤ 0) não são gravados. Atributo `RankTier` no Player (faixa ou "Adm") para o placar mostrar o elo dos outros. | DADOS 4 e 8. |
| **`MatchRewards`** (Partida) conta rodadas jogadas/vencidas, Viradas e rodadas 1v2 vencidas (fim de cada rodada), abates, mortes, dano e abates por arma (`Combatants.onKnocked` e o novo `Combatants.onDamaged`). Credita **uma vez** por jogador: ao cair a dupla, no fim (campeã e vice) ou antes de o perfil deixar o servidor. Partida interrompida pelo painel de teste não credita. | GDD 4.8, 9 e 10. |
| **`DataService.onBeforeRelease`:** funções chamadas logo antes de o perfil sair do servidor (o jogador saiu ou vai ser teleportado), com o perfil ainda aberto. É por aqui que quem sai no meio recebe (com a colocação de agora). | Sem isso, a saída fechava o perfil antes da recompensa. |
| **Partida privada:** `MatchHandoff.isPrivate` (a fila sempre manda `false`; as privadas chegam na F11). Elo não muda e as moedas valem `EconomyConfig.PrivateMatchRewardMultiplier` (0,5). | GDD 6.6. |
| **Evento `Rewards`** (MatchEvent) com moedas (e o detalhe), PE, faixa antes e depois, proteção e perda dobrada. A tela de dupla eliminada e a tela final mostram numa linha (`EndScreen`), com ícone e cor do elo. | GDD 9.3. |
| **Loja de skins no lobby** (`ShopService`, remotes `ShopRequest`/`ShopResult`): Buy, Equip e Unequip, só com IDs válidos, limite de 10 pedidos a cada 5 s. Comprar é `ProfileRules.buySkinWithCoins` (tudo ou nada) pelo `EconomyService.buySkin`, que salva na hora. | DADOS 4 e 5.2. Teste de exploit no `Progression.spec`. |
| **Catálogo gerado** (`ShopCatalog`): tema × (18 armas + Bastão), preço pela raridade (`EconomyConfig.Prices.SkinByRarity`). Cores dos temas em `Theme.SkinLook`; o `WeaponShapes` aplica a skin por cima das cores da arma (vitrines e arma em primeira pessoa, que lê a skin equipada no perfil). | ESTILO 2 e GDD 11. Sem vermelho e sem neon (teste no `Interface.spec`). |
| **Arsenal (T5):** a fila de skins mostra Padrão + os 4 temas com moldura de raridade, amostra de cores (3 faixas, sem mais um modelo 3D) e cadeado com preço; o botão principal age sobre a skin escolhida: COMPRAR (preço, apagado sem saldo), EQUIPAR ou EQUIPADA. Os cartões da grade mostram a skin equipada. | ESTILO T5. |
| **Ranking (T3 › RANKING):** `LeaderboardService` no lobby lê os 100 primeiros a cada 5 min (30 s em `DEV_`), busca os nomes em lote (`UserService`) e manda a lista para todos; abrir a tela só pede a cópia em memória. ADM fixo no topo. Sem avatares nas linhas (100 miniaturas por tela). | DADOS 8: não estourar limites. |
| **Elo na interface** (`Common/Ui/RankBadge`): ícone + nome na cor da faixa (`Strings.RankIcons`, `Theme.Rank`), em texto rico. Lobby (dupla), placar (ícone antes do nome), tela final e ranking. | ESTILO 2.2: nunca só a cor. |
| **Cartas (T1):** as 4 iniciais são Comuns; o fundo continua na cor da carta e a moldura fica na cor da raridade. GIRAR (e R no PC) estreita a carta e abre o verso (cor da carta escura, moldura da raridade, símbolo e nome do jogo); de novo volta à frente. | GDD 8.9. |
| **Comandos de teste** (`DEV_`, painel de dados): ±500 PE, zerar elo, simular uma partida de 8 duplas com colocação sorteada (moedas e elo pelo caminho real), primeira vitória do dia de novo e tirar as skins. | Testar elo e economia sem jogar partidas inteiras. |

### F10 · Mapas e arte

| Decisão | Por quê |
|---|---|
| **Mundo montado por código também na F10** (muda a decisão da F3, que previa construir os mapas à mão no Studio). `Shared/Maps/Build` (peças básicas: bloco, triângulo deitado, peça no chão, peça espelhada) e `Shared/Maps/WorldBuilder` (mirante, ilhas, nuvens e luz). O `MatchWorld` da partida só chama o `WorldBuilder`; o lobby e a prévia no Studio usam o mesmo código. Os kits de cada mapa (KIT-MODULAR) e as plantas entram em `Shared/Maps` à medida que cada mapa for aprovado. | Tudo fica no git (dá para revisar e voltar atrás), as mesmas peças servem à partida, ao lobby e ao minimapa, e nada se perde se o place for refeito. Em `Shared` só há `require` relativo, então a prévia no Studio carrega uma cópia nova a cada mudança (o Studio guarda os módulos já carregados). |
| **Posição das ilhas** (`MapConfig.Maps`, `PositionDirection`, `PositionYaw`): Porto N, Fábrica L, Praça S, Torre O, a `MapConfig.World.IslandDistance` do centro. Cada ilha tem um quadro (`WorldLayout.islandFrame`) com o eixo X local de base a base, tangente ao mirante. `baseSpawn`, `islandAt`, `islandExtent` e a zona trabalham nesse quadro. | Plantas do dono do projeto (F10). O mesmo código serve para ilhas deitadas e em pé. |
| **Bases fora da área de duelo:** 40 × 36 em cada ponta, com parede de 7 studs e passagem de 8 para a área de duelo. Nascer no meio da base (~90 studs do centro ≈ 5,6 s andando). | Proporções das plantas; GDD 15.1 (~6 s até o centro). |
| **Mirante octogonal:** grade em "#" divide o piso de vidro em quadrado do centro, 4 painéis retos e 4 triângulos (cada triângulo é uma `WedgePart` deitada). Sem placa opaca: olhando para uma ilha (15° a 30° para baixo) o olhar atravessa o piso a 10–20 studs de quem olha, e uma placa no meio tapava a ilha (visto na prévia); as vigas ficam em cima das emendas, então nenhum vidro se sobrepõe a outro (sobreposição dobra a transparência). Aro de 0,6 (sem faixa opaca embaixo, que tapava a ilha vista da borda); barreira invisível de 14 em cada um dos 8 lados. Vidro em SmoothPlastic (sem reflexo), sem sombra. | GDD 6.5 revisto pelo dono do projeto (F10). `World.spec` confere que vidro + placa cobrem exatamente o octógono. |
| **Céu:** luz do dia (`MapConfig.Sky.ClockTime`) e o `Atmosphere` do place (reaproveitado, nunca um segundo) com névoa leve, aplicados pelo servidor. **Mar de nuvens** bem abaixo (y = −500, 5 × 5 ladrilhos de 2048, a maior peça do Roblox), para o fundo olhando para baixo ficar claro e a borda sumir no horizonte; a −170 as sombras das ilhas e do mirante apareciam nele como buracos escuros. Nuvens de desenho animado (bolas brancas encostadas, sem colisão e sem raio) em cima do mar, entre as ilhas e o mar (aparecem pelo vidro) e no horizonte, com semente fixa. Tudo num `Model` com streaming persistente (o place usa streaming com raio de 1024, e o mar e o horizonte ficam mais longe). Chão e rocha das ilhas sem sombra. O `SpawnLocation` do place, que ficava embaixo do mirante e aparecia pelo vidro, vai para o centro do mirante, invisível e sem colisão. | ESTILO T4: céu claro e nuvens baixas, nada escuro. Sem pós-processamento pesado (GDD 13.2). Visto na prévia no Studio (fotos em `docs/referencias/f10/`). |
| **Minimapa:** desenha o chão a partir das peças com o atributo `MapGround` (área de duelo e bases) e as construções por cima; o tamanho vem de `WorldLayout.islandExtent` (ilhas em pé ou deitadas). | Serve para os mapas finais sem mudar o código do minimapa. |
| **Uma planta por mapa** em `Shared/Maps/Islands/<Mapa>` (função que monta a área de duelo no quadro da ilha); o `WorldBuilder` usa a do mapa ou, sem planta ainda, o desenho cinza da F3. As **bases** (iguais em todas as ilhas: chão, mureta, parede da frente de 7 com a passagem, rocha) e a âncora do nome ficam em `Shared/Maps/IslandCommon`. Ilhas com simetria de giro montam uma metade e a outra com o quadro girado 180° (`IslandCommon.rotated`). | Cada mapa muda sem mexer nos outros; as bases e as regras de nascer são as mesmas para todos. |
| **Medidas da planta** tiradas do desenho do dono na escala da área de duelo (140 studs de base a base). Bases 36 × 42 e passagem de 14 (`MapConfig.World`), medidas na planta da Praça. Coordenadas da planta ficam no módulo do mapa (são o desenho do nível, não números de balanceamento). | Planta do dono = fonte da verdade; o bloco cinza é conferido de cima, lado a lado com o desenho. |
| **Peças novas do `Build`:** parede entre dois pontos (`wall`), retângulo e triângulo de chão em coordenadas da ilha (`floorRect`, `floorTriangle`) e rampa (`ramp`, uma `WedgePart`). A rocha embaixo da ilha fica sempre por dentro do contorno do chão (nos recortes ela aparecia de cima). | Plantas com chanfros e diagonais. |
| **Minimapa:** os triângulos de chão (chanfros e diagonais) são desenhados em 10 faixas finas, porque a interface do Roblox não tem triângulo. Peças de acabamento (`MapDetail`) ficam de fora. | Plantas com chanfros; milhares de peças de acabamento não podem virar milhares de quadros na interface. |
| **Mundo salvo no place da Partida** (muda a decisão acima de "nada fica salvo no place"; pedido do dono do projeto). O código em `Shared/Maps` continua sendo a fonte; `WorldBuilder.bake()` monta o mundo em `Workspace.MatchWorld` no modo de edição (comando no README) e o place é salvo com ele. Ao iniciar, o servidor monta uma cópia em memória e compara com a salva (`WorldBuilder.sameWorld`: quantidade de peças e somas de posição, tamanho, cor, transparência, colisão e giro); se forem iguais usa a salva, senão monta de novo, avisa no Output e marca `RebuiltAtStart` (um teste acusa). O que for mexido à mão dentro de `MatchWorld` se perde na próxima montagem. | O dono quer abrir o place e ver o mapa. O código como fonte mantém o histórico no git e deixa vários mapas avançarem ao mesmo tempo; a conferência no início impede que um place velho vá para os jogadores. |
| **Kits em código:** cada componente do KIT-MODULAR é uma função em `Shared/Maps/Kits/<Mapa>` que devolve um `Model` (em vez de um modelo guardado em `ReplicatedStorage/Kits`). O módulo da ilha devolve `{ style, build }` (`IslandCommon.Island`): `style` dá as cores das bases e `build` monta a área de duelo. | Mesma razão: tudo no git, e a planta não muda quando o acabamento de um componente muda. |
| **Peças de acabamento** (`Build.Detail`): juntas, tábuas, ferrugem, molduras. Não colidem, não bloqueiam tiro, não fazem sombra e levam o atributo `MapDetail`. A peça que colide é sempre uma caixa simples por baixo. Cilindros são prismas de 6 ou 8 lados feitos de blocos cruzados (`Build.prism`). | Colisão e validação de tiro simples e baratas; visual do kit sem textura (KIT-MODULAR 1). |
| **Zonas e pontos de escudo no mapa:** `IslandCommon.zone` cria uma caixa invisível com o atributo `MapZone` (id em `Strings.Zones`) e, nas metades, `MapZoneSide` (Leste/Oeste); `IslandCommon.shieldPoint` cria a placa de 6 lados com a tag `ShieldPoint`. Nesta etapa são só as marcas no mapa: o nome da zona no ping e a regra de recarga do escudo entram depois das plantas aprovadas. | FASES F10: ilhas com zonas nomeadas e pontos de escudo. |
| **Arte do Porto:** o acabamento de cada componente fica dentro da função do kit (`Kits/Porto`), sem mudar a planta. Tons mais escuros de cada cor (ondulação, quadro, juntas) entram em `Theme.Maps.Porto`. Ondulação do contêiner = placas que atravessam a largura e passam do teto (uma peça serve aos dois lados e à vista de cima). Porto com a arte: ~1.540 peças (limite de 3.000). | KIT-MODULAR 1 e 2; a vista do mirante é a principal. |
| **Esteiras da Fábrica** (`match/server/Conveyors`): o mundo é montado com tudo ancorado; ao iniciar a partida o servidor dá velocidade de superfície à correia (`AssemblyLinearVelocity` numa peça ancorada: o Roblox carrega o personagem) e solta cada caixa num trilho (`PrismaticConstraint` com motor, preso à base da esteira e não à correia, senão as velocidades somam). O servidor é o dono da física das caixas; no fim da correia a caixa volta ao início. Conferido no Play: caixa e boneco a 8 studs/s. | Movimento suave no cliente sem enviar posição a cada quadro; o tiro é validado contra a posição real da caixa no servidor; a comparação do mundo salvo com o código continua valendo (tudo ancorado no place). |
| **Arte da Fábrica:** acabamento dentro de `Kits/Fabrica`, sem mudar as peças que colidem da planta aprovada. Fábrica com a arte: ~1.920 peças (limite de 3.000). | KIT-MODULAR 1 e 3. |
| **Arte da Torre:** acabamento dentro de `Kits/Torre` (`Kit.Juntas` desenha os blocos de pedra em qualquer parede), sem mudar as peças que colidem da planta aprovada. Torre com a arte: ~1.150 peças (limite de 3.000). | KIT-MODULAR 1 e 5. |
| **Zona no ping** (`Shared/Maps/Zones`): o servidor acha a zona do ponto marcado (caixas invisíveis com a tag `MapZone`) e manda o nome pronto em `PingData.zone`; o cliente só mostra na legenda. Pontos no eixo do meio da ilha caem na fronteira entre Leste e Oeste e levam o nome de um dos lados. | Servidor é a autoridade; quem marcou e o parceiro leem o mesmo nome. |
| **Pontos de escudo** (`match/server/ShieldPoints`, regras puras em `Shared/Match/ShieldPointRules`): a cada 0,1 s o servidor confere os combatentes vivos que estão numa ilha; alcance de 3 studs do centro da placa e até 6 acima (`MapConfig.General.ShieldPickupRadius/Height` `[PROPOSTA]`). O ponto usado fica escuro (`Theme.Match.ShieldPadOff`) e com o atributo `ShieldPointActive` = false. | GDD 15.1. O cliente não pede nada: não há o que explorar. |
| **Telhados para o mirante:** nenhuma das 4 plantas aprovadas tem área coberta, então não há telhado para deixar transparente. O mecanismo (`IslandCommon.roof` + `MiranteView`) continua pronto para um mapa futuro. | GDD 6.5. |
| **Testes automáticos depois de mudar `Shared`:** rodar no Play (servidor), não no modo de edição, que guarda os módulos antigos (README). | Na F10 os testes do mundo só enxergaram os kits novos no Play. |
| **Lobby 3D** (`Shared/Maps/LobbyBuilder`): a ilha do lobby é montada pelo servidor ao iniciar (`lobby/server/LobbyWorld`), com o kit da Praça; a placa cinza do place fica invisível e o ponto de nascer vai para a ilha. O fundo é o mundo da partida montado em cada cliente pelo mesmo `WorldBuilder`, aos poucos, deslocado (`MapConfig.Lobby.WorldOffset`), sem colisão, sem sombra e sem as peças de acabamento com a maior face menor que 4 studs²: ~3.430 peças em vez de ~6.300 (limite de 4.500, conferido em teste). A ilha do lobby tem ~230 peças. Nada do lobby fica salvo no place. | ESTILO T3. O fundo é só ambientação: não vale o custo de replicar nem de colidir. De pé no meio de uma ilha não se vê o que está embaixo, por isso o jogador nasce na beira da frente e a mureta ali é baixa (visto na prévia). |
| **Mãos e braços em primeira pessoa** (`Shared/Combat/WeaponShapes`): luva de blocos (dorso, 3 dedos que dão a volta na empunhadura e terminam do lado que a câmera vê, polegar, indicador esticado ao lado do guarda-mato), mão esquerda embaixo do guarda-mão com os dedos subindo pelo lado da câmera, punho da luva, punho dobrado da manga e manga que engrossa até o cotovelo, com costura. No Bastão a mão fecha em volta do cabo. Cores em `Theme.Combat` (`Glove`, `GloveShade`, `GlovePad`, `Sleeve`, `SleeveShade`). | Guia da arma em primeira pessoa; manga neutra (GDD 3.3). |
| **Enquadramento automático** (`Shared/Combat/ViewModelFit`, regras em `CombatConfig.ViewModel.Frame` `[PROPOSTA]`): numa tela de referência 16:9 com o campo de visão da câmera (80°), confere a ponta do cano (à direita de 60% da largura e abaixo de 60% da altura), a ZONA DA ARMA (58% e 52%) e o CENTRO LIVRE (raio de 20% da altura). A arma que não cabe fica menor em passos de 2%, até 80%. Com as posições novas por categoria, só 3 armas encolhem (Luneta 92%, Atirador e Mata-Pato 98%); um teste confere as 18 no PC e no celular. O Bastão fica de fora (é erguido). | O guia pedia ~62% de largura para o cano com modelos mais curtos; com os modelos da F7 a regra que manda é o centro livre, e o guia permite a arma menor. |
| **Efeitos das cartas** (`combat/client/CardVisuals`): só no cliente, na pasta de efeitos. A nuvem do servidor continua sendo a esfera que bloqueia a visão (regra igual); o contorno de bolas é só desenho e sai um pouco dela. A marca do Renascer do servidor fica invisível na tela de cada um e o selo é desenhado em volta. O Impulso, que o cliente aplica, agora tem um efeito do servidor (`CardFx` "ImpulsoLaunch") depois de validar a carga. | ESTILO 2.6; o que muda a regra continua no servidor. |
| **Arte das cartas** (`Shared/Ui/CardArt`): desenho com quadros da interface (círculos, barras e losangos em escala), sem imagem enviada ao Roblox, para escalar em qualquer tamanho e servir em todas as telas. | Sem dependência de upload; mesma arte na tela de Cartas, HUD, preparação e tutorial. |
| **Sons sintetizados** (`scripts/sons/gerar.js`, Node, sem dependências): cada som em camadas, como nos efeitos de FPS: tiro = estalo (ruído agudo de 4 ms) + presença (ruído em 1,5 a 4 kHz) + explosão (ruído filtrado) + soco grave curto + cliques metálicos do mecanismo (parciais desafinadas) + cauda de reverberação de campo aberto + saturação leve; crack de abate = batida oca (ruído em faixas estreitas de 230 e 520 Hz) + estalo + toque metálico curto; habilidades com ruído em movimento, graves e sinos de FM. Nenhum tom puro afinado (era o que soava retrô). O equilíbrio do tiro foi conferido pela energia por faixa: o grave não cobre o estalo, porque no celular quase não se ouve abaixo de 150 Hz. Mono, 44,1 kHz, 16 bits, pico em -2 dB, semente fixa (o mesmo código gera os mesmos arquivos). Cada som do `AudioConfig` aponta para o seu arquivo (`file`); `AudioAssets` guarda o número do asset depois do envio e `AudioConfig.resolve` toca o final (tom 1) ou, sem número, o provisório. Sons novos: 6 das cartas (`CardVisuals`) e o do ponto de escudo (`match/client/ShieldPointFx`, quando o ponto apaga). | Originais de verdade (GDD 7.7) e reproduzíveis; trocar um som é mudar a receita e rodar de novo. O envio de áudio exige a conta do dono. |
| **Versão leve dos mapas** (`Shared/Maps/MapDetail` = regra pura; `common/client/MapDetailLevel` = cliente): esconde com `LocalTransparencyModifier = 1` (o Roblox não desenha peça invisível) as peças com `MapDetail`, sem `MapSignal` e com a maior face abaixo de 4 studs², no `MatchWorld`, no `LobbyWorld` e no `LobbyBackdrop`, inclusive as que chegam depois pelo streaming. Liga com o gráfico do Roblox de 1 a 3 (`UserGameSettings.SavedQualityLevel`) ou, no automático, com média abaixo de 27 quadros por 5 s seguidos (e fica leve até o fim da sessão, para não ficar trocando). Sinais marcados nos kits com `Build.Signal`. Um teste confere que cada ilha fica com no máximo 1.500 peças visíveis na versão leve e que nenhum sinal some. | GDD 13.2: 75% das peças do mundo são acabamento; esconder as pequenas corta o desenho pela metade sem mudar nada do jogo. O automático do Roblox não diz o nível escolhido, por isso a queda de quadros é o gatilho. |
| **Luz e detalhe do Porto** (`Build.light`, atributo `MapLight`; peças em `Kits/Porto`, posições em `Islands/Porto.dress`): `PointLight` dentro da lente da luminária, cor `Theme.Maps.Porto.LuzQuente`, `Shadows = false`, brilho e alcance em `MapConfig.Porto.Lights`. O `MapDetailLevel` apaga (`Enabled = false`) toda luz com `MapLight` na versão leve, só na tela de quem está nela. A pintura no chão fica em camadas de altura (placa 0,01, sombra 0,014, luz 0,018, óleo 0,021, linhas 0,025), sempre abaixo das juntas (0,03), vagas (0,04) e faixas de aviso (0,1), para nada piscar. Testes: luz só no Porto, marcada, sem sombra, no limite; e toda peça da passada de detalhe é acabamento. | KIT-MODULAR 1 e 2 (exceção de luz decidida pelo dono). Sombra de luz pontual é cara no celular; a mancha pintada dá o efeito de luz mesmo de dia. |
