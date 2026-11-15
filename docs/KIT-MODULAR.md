# [NOME DO JOGO] — Kit modular dos mapas

> **Versão:** 0.1
> **Documentos irmãos:** `docs/GDD.md` (seção 15), `docs/FASES.md` (fase F10), `docs/ESTILO-E-TELAS.md`
> **Pranchas visuais:** `docs/referencias/visuais/`

## 0. Como usar (para o Claude Code)

- Cada componente abaixo vira uma **função reutilizável** em `src/shared/Maps/Kits/<Mapa>.luau`, que devolve um `Model` (ex.: `Kits.Porto.Conteiner`). A ilha é montada por código e fica salva no place da Partida (GDD 20, F10; README "Mapa salvo no place").
- Medidas em **studs**. As pranchas mostram a forma; este documento manda nas medidas e cores.
- As ilhas são montadas posicionando esses Models. Não modelar peça única fora do kit sem registrar aqui.
- Com o Studio MCP conectado: montar o mundo no place (`WorldBuilder.bake`) e tirar captura de tela para conferir com a prancha.

## 1. Regras de todos os kits `[DECIDIDO]`

- Grade de 1 stud; medidas inteiras ou de meio stud.
- Material liso (SmoothPlastic), **sem textura** (confirmado pelo dono do projeto na F10). Detalhes (tijolos, ferrugem, musgo, sujeira, ondulação) = peças finas ou manchas de **cor chapada**. O bloco cinza das plantas é só a etapa de aprovação: o mapa final leva todo o detalhe do kit.
- Cenário **menos saturado** que os personagens.
- **Proibido:** Neon, PointLight/SurfaceLight coloridos, partículas decorativas, vermelho puro (cor do inimigo), sangue, logotipos e texto escrito em objetos.
- Personagem = 5 studs. **Cobertura cheia ≥ 6 studs**; **meia altura = 3 studs**; cobertura a cada ~10 studs nas rotas.
- Corredores com no mínimo 8 studs de largura; portas e passagens com no mínimo 4 (ideal 6).
- Telhados e coberturas de áreas fechadas ficam transparentes **só para quem está no mirante** (GDD 6.5).
- Orçamento: até ~3.000 peças por ilha; preferir poucas peças grandes a muitas pequenas.
- Cilindros são prismas low poly: 6 ou 8 lados.

## 2. Porto

Prancha: `docs/referencias/visuais/kit-porto.png`

**Paleta**

| Cor | Hex |
|---|---|
| Chapa | `#6F8FA6` |
| Ferrugem | `#B5652E` |
| Ferrugem escura | `#8A4A24` |
| Concreto | `#B9B2A6` |
| Metal | `#4A5368` |
| Madeira | `#B98A5A` |
| Água | `#4FA3C7` |
| Aviso | `#F2C230` |
| Guindaste | `#E0A526` |
| Contêiner Laranja | `#D9773A` |
| Contêiner Petróleo | `#3C7A8C` |
| Contêiner Musgo | `#6E8F4E` |
| Contêiner Mostarda | `#D9A93A` |

**Componentes**

### Parede De Chapa
- **Medidas:** 16 × 1 × 12 studs · ~12 peças
- **Função:** Bloqueia visão
- Módulo padrão: encaixa a cada 16 studs, sempre na grade de 1 stud.
- Ondulação vertical a cada 1 stud (peças finas, não textura).
- Ferrugem só no terço inferior e em escorridos verticais curtos.
- Base de concreto e acabamento de metal escuro no topo.

### Contêiner
- **Medidas:** 20 × 8 × 8,5 studs · ~20 peças
- **Função:** Cobertura cheia
- Cores: Laranja, Petróleo, Musgo, Mostarda. Nunca vermelho (reservado ao inimigo).
- Portas sempre na face menor, com 4 barras de trava.
- Altura 8,5: alto o bastante para esconder o personagem (5 studs).

### Pilha De Contêineres
- **Medidas:** máx. 2 de altura · 17 studs
- **Função:** Ponto alto
- 17 studs: alcançável com Impulso (sobe ~18) ou escada.
- O de cima fica recuado e cria uma plataforma onde dá para ficar.
- Nunca empilhar 3: vira parede e cansa a visão no mirante.

### Caixas De Madeira
- **Medidas:** 6 × 6 × 6 · 3 × 3 × 3 studs
- **Função:** Cobertura alta / baixa
- Caixa grande (6): cobertura cheia. Caixa pequena (3): meia altura, protege as pernas e deixa atirar por cima.
- Moldura e travessa diagonal em madeira mais escura.
- Usar a cada ~10 studs nas rotas (regra de cobertura do GDD).

### Barris
- **Medidas:** Ø 2,6 × 3,2 studs · 8 lados
- **Função:** Decoração / cobertura parcial
- Cilindro low poly de 8 lados, com 2 cintas escuras.
- Agrupar de 2 a 4. Não explodem.
- Petróleo como cor principal; Mostarda como destaque.

### Píer De Madeira
- **Medidas:** módulo 12 × 10 studs · tábuas de 1,5
- **Função:** Piso
- Tábuas com fresta mínima e tons alternados.
- Estacas de 6 lados entrando na água.
- Borda voltada para a água com faixa amarela e preta (aviso de queda).

### Cabeço De Amarração
- **Medidas:** 4 × 4 × 2,6 studs
- **Função:** Detalhe
- Base de concreto, poste de metal de 8 lados e chapéu largo.
- Fica na borda do píer, a cada 12 studs.
- Não bloqueia movimento (colisão só na base).

### Torre Do Guindaste
- **Medidas:** 4 × 4 × 20 studs (módulo de 4)
- **Função:** Linha de visão longa
- Treliça em módulos de 4 studs: dá para empilhar a altura.
- Amarelo de guindaste com ferrugem só no pé.
- Topo = plataforma do sniper (nível 2 do mapa Porto).

## 3. Fábrica

Prancha: `docs/referencias/visuais/kit-fabrica.png`

**Paleta**

| Cor | Hex |
|---|---|
| Painel | `#8FA3B8` |
| Tijolo | `#B97C5E` |
| Máquina | `#5F9A7A` |
| Tubos | `#D9773A` |
| Borracha | `#3A3F4F` |
| Papelão | `#C9A46B` |
| Janela | `#BFE3FF` |
| Metal | `#4A5368` |
| Aviso | `#F2C230` |

**Componentes**

### Parede De Galpão
- **Medidas:** 16 × 1 × 12 studs
- **Função:** Bloqueia visão
- Base de tijolo (4 studs) + painel metálico com ondulação larga.
- Faixa de janelas altas azul-clara (sem transparência real: cor chapada).
- Topo com acabamento de metal escuro.

### Esteira
- **Medidas:** 20 × 4 × 2,5 studs
- **Função:** Move o jogador
- Esteira de borracha escura com setas amarelas mostrando o sentido.
- Laterais com faixa amarela e preta (atenção).
- Velocidade em config; quem pisa é carregado no sentido das setas.

### Caixa Na Esteira
- **Medidas:** 2,6 e 2,2 studs
- **Função:** Cobertura móvel
- Caixas de papelão com fita no meio e etiqueta escura sem texto.
- Andam junto com a esteira e reaparecem no início.
- Meia altura: protege as pernas, não o corpo todo.

### Prateleira Alta
- **Medidas:** 10 × 3 × 12 studs
- **Função:** Bloqueia visão
- Montantes laranja e 3 níveis de metal escuro.
- Caixas variadas nas prateleiras (não sobem até o topo, deixam frestas).
- Forma corredores no Depósito (combate de perto).

### Tubulação
- **Medidas:** 8 × 4 × 10,5 studs
- **Função:** Cobertura cheia
- Tubos verticais de 8 lados com anéis (flanges) mais escuros.
- Verde e laranja alternados; registro amarelo.
- Encosta em paredes; nunca no meio de rota.

### Passarela Com Grade
- **Medidas:** 12 × 3 studs · altura 6
- **Função:** Nível 1
- Piso de grade (linhas) sobre pilares escuros.
- Guarda-corpo amarelo de 3,2 studs: atirar por cima é possível.
- Liga a Sala de Controle às laterais.

### Máquina
- **Medidas:** 7 × 5 × 7,5 studs
- **Função:** Cobertura cheia
- Corpo verde, painel escuro com botões chapados (sem luz).
- Faixa zebrada amarela na base.
- Chaminé curta de 6 lados no topo.

### Pallet Com Tambores
- **Medidas:** 6 × 5 × 3,5 studs
- **Função:** Meia altura
- Pallet de tábuas + 4 tambores de 8 lados.
- Cores do mapa: azul-acinzentado e laranja.
- Agrupar perto das esteiras e do Depósito.

**Regra específica:** setas e faixas zebradas indicam movimento e perigo; nunca texto escrito.

## 4. Praça

Prancha: `docs/referencias/visuais/kit-praca.png`

**Paleta**

| Cor | Hex |
|---|---|
| Reboco | `#EFE3CF` |
| Tijolo | `#C08A6A` |
| Telha | `#C47A52` |
| Folhas | `#4F9A62` |
| Grama | `#8FCF8A` |
| Porta | `#4F7FB8` |
| Pedra | `#B9B2A6` |
| Toldo creme | `#F4EAD2` |
| Toldo petróleo | `#3C8C8C` |
| Água | `#4FA3C7` |

**Componentes**

### Muro De Tijolo
- **Medidas:** 12 × 1 × 4 studs
- **Função:** Meia parede
- Tijolo terracota claro com juntas em linhas; topo de pedra.
- 4 studs: esconde o corpo, mas dá para pular por cima com Impulso.
- Separa a Feira das ruas.

### Sobrado
- **Medidas:** 10 × 8 × 13,5 studs
- **Função:** Nível 1 / janelas
- Reboco creme, telhado de duas águas em telha, porta azul.
- Janelas do 2º andar são pontos de tiro (abertas por dentro).
- Variações: cor de porta e posição da sacada; nunca reboco vermelho.

### Coreto
- **Medidas:** Ø 10 × 10 studs
- **Função:** Centro do mapa
- Base octogonal de pedra (1 stud), 8 colunas finas creme, telhado verde.
- Entre as colunas dá para ver e atirar: cobertura fraca.
- Topo do telhado alcançável só com Impulso.

### Banco De Praça
- **Medidas:** 5 × 2 × 2,9 studs
- **Função:** Meia altura
- Pés de metal escuro, ripas de madeira.
- Usar em pares de frente para o Chafariz e o Coreto.
- Não bloqueia tiro (entre ripas há frestas).

### Chafariz
- **Medidas:** Ø 8,4 × 4 studs
- **Função:** Cobertura baixa
- Bacia octogonal de pedra com água chapada (sem reflexo).
- Coluna central com segunda bacia pequena.
- Borda de 1,3 stud: obstáculo e referência visual, não protege de tiro.

### Barraca De Feira
- **Medidas:** 6 × 4 × 6,5 studs
- **Função:** Cobertura cheia
- Toldo listrado creme e verde-petróleo (nunca vermelho).
- Balcão de madeira com caixotes de frutas em cores chapadas.
- Em fileira na rota da Feira, com espaço de 4 studs entre elas.

### Árvore Low Poly
- **Medidas:** Ø 5,6 × 8,8 studs
- **Função:** Cobertura parcial
- Tronco de 6 lados + copa em 3 camadas de 7 lados.
- Copa sem colisão e sem bloquear tiro; só o tronco colide `[DECIDIDO]` (F10, confirmar em teste).
- Vista de cima (mirante) é a principal marca da Praça.

### Poste De Luz
- **Medidas:** 0,7 × 9,8 studs
- **Função:** Detalhe
- Haste fina escura, luminária creme apagada.
- Sem PointLight e sem brilho (o mapa é de dia).
- A cada 12 studs nas calçadas.

**Regra específica:** mapa de estreia: formas mais simples e leitura mais fácil.

**Na planta aprovada (F10, GDD 15.4):** Coreto e Chafariz **não entram** (decisão do dono). Entram a **Caixa de Madeira** do kit do Porto (6 × 6 × 6, mesma madeira `#B98A5A`), o **Muro de Tijolo** em versão comprida (20 × 2 × 4) e a **passarela elevada** (nível 1, 5 studs, com rampas), que ainda precisa de um componente próprio no kit (piso de pedra, guarda-corpo, rampa).

## 5. Torre

Prancha: `docs/referencias/visuais/kit-torre.png`

**Paleta**

| Cor | Hex |
|---|---|
| Pedra | `#A8A29A` |
| Pedra escura | `#7D776F` |
| Musgo | `#6E8F4E` |
| Madeira | `#9A6B43` |
| Ferro | `#4A5368` |
| Terra | `#B49A74` |
| Estandarte | `#E9E3D5` |
| Roxo do jogo | `#6A4FB0` |
| Chama | `#E8913A` |

**Componentes**

### Muralha De Pedra
- **Medidas:** 16 × 3 × 10 studs
- **Função:** Bloqueia visão
- Blocos grandes (3,2 × 1,6) em fileiras alternadas.
- Musgo só na base, em manchas.
- Espessura 3: dá para andar em cima quando tem ameias.

### Muralha Com Ameias
- **Medidas:** 16 × 4 × 8,5 studs
- **Função:** Nível 1
- Caminho de 4 studs no topo com merlões de 2 × 1 × 2,5.
- Merlões a cada 4 studs: cobertura para quem está em cima.
- São as Muralhas laterais do mapa.

### Escadaria
- **Medidas:** 12 × 6 studs · degrau 0,9
- **Função:** Subida ao topo
- 8 degraus de 1,5 de profundidade; mureta lateral.
- Tons alternados de pedra para ler os degraus.
- Única subida sem carta para o Topo da Torre.

### Ponte Levadiça
- **Medidas:** 10 × 5 studs · vão de 10
- **Função:** Passagem
- Tábuas de madeira sobre o vão, correntes de ferro até os postes.
- Cair no vão = voltar à base (regra de queda).
- Liga as duas bases por baixo do Topo.

### Porta Em Arco
- **Medidas:** 10 × 2 × 10 · vão 4 × 6,5
- **Função:** Passagem
- Arco de pedra mais escura, porta de tábuas com 2 cintas de ferro.
- Passagem aberta: largura mínima de 4 studs.
- Variante fechada vira só decoração.

### Estandarte
- **Medidas:** 0,4 × 11 studs · bandeira 3 × 5,5
- **Função:** Detalhe
- Bandeira creme com losango e faixa roxos (cor do jogo).
- Nunca na cor de uma equipe, para não confundir.
- Marca as bases e o Topo da Torre.

### Tocha (Sem Brilho)
- **Medidas:** suporte 0,6 · chama 1,1 studs
- **Função:** Detalhe
- Chama = duas pirâmides chapadas laranja e amarela.
- Sem luz, sem partícula, sem neon.
- Em pares nas portas e na escadaria.

### Escombros
- **Medidas:** 5 × 2 × 3,5 + pedras
- **Função:** Meia altura
- Pedaço de muro quebrado + pedras de 5 e 6 lados.
- Cobertura de meia altura no Pátio.
- Musgo em manchas, sem textura.

**Regra específica:** toda altura nova precisa de uma subida sem carta (escada ou rampa).

## 6. Arma em primeira pessoa

Prancha: `docs/referencias/visuais/guia-arma-primeira-pessoa.png`. Regras de enquadramento, posição do modelo por categoria e versão para celular estão na prancha; valores `[PROPOSTA]`, ajustar em teste.

## 7. Em aberto

- ~~Copa da árvore da Praça bloqueia tiro?~~ Respondida na F10: não (seção 4); confirmar em teste.
- Plantas baixas: Praça aprovada; Porto, Fábrica e Torre com contorno do dono e interior em aprovação (F10).
