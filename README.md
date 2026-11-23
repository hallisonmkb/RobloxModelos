# Modelos reaproveitáveis

Peças criadas no projeto `roblox-kit-base` (jogo de exemplo dos insetos), guardadas aqui
para usar noutros jogos. Tudo é **código Luau**: não há ficheiros `.rbxm`. Os modelos são
montados por código quando o jogo arranca, e o cenário é criado ao colar um script na
Command Bar do Studio.

Cópia de 23/11/2026. A versão "oficial" continua no repositório
https://github.com/hallisonmkb/RobloxInsetos. Se lá mudar alguma coisa, volte a copiar.

## Conteúdo

| Pasta / ficheiro | O que é |
| --- | --- |
| `Insetos/Models/Parts.luau` | Peças básicas para montar modelos (esferas, cilindros, juntas Motor6D, pivô). Os outros modelos precisam dele. |
| `Insetos/Models/Formiga.luau` | Formiga-de-fogo (cabeça e tórax avermelhados, gáster escuro, antenas cotoveladas, mandíbulas). |
| `Insetos/Models/Pulgao.luau` | Pulgão verde (corpo em pera, olhos vermelhos, antenas compridas, sifúnculos). |
| `Insetos/Models/MosquitoTigre.luau` | Mosquito-tigre (preto com riscas brancas, patas às faixas, asas que batem). |
| `Insetos/Models/Gafanhoto.luau` | Gafanhoto (patas de saltar enormes, asas dobradas). |
| `Insetos/ZoneEnemy.luau` | O "cérebro" dos insetos: passear numa zona, perseguir e atacar o jogador, voar, pousar, saltar e animar patas, antenas e asas. |
| `Insetos/Config.exemplo.luau` | Exemplo de `Config` com a secção `Config.Enemies` já afinada para os 4 insetos. |
| `Cenario/Montanhas.luau` | Esculpe montanhas realistas (relva, rocha, neve) à volta da Baseplate com Terrain. |
| `Cenario/Muro.luau` | Muro (cópias de um modelo "StudWall" ou tijolo) a seguir o contorno das Parts "Zona...". |
| `Ferramentas/LimpezaScripts.luau` | Apaga scripts de terceiros (backdoors da Toolbox). Correr sempre que se insere um modelo da Toolbox. |

## Como reaproveitar noutro jogo feito a partir do roblox-kit-base

1. Copie a pasta `Insetos/Models` para `games/<jogo>/server/Models`.
2. Copie `Insetos/ZoneEnemy.luau` para `games/<jogo>/server/ZoneEnemy.luau`.
3. Em `games/<jogo>/shared/Config.luau`, cole a secção `Config.Enemies` do
   `Config.exemplo.luau`. Mantenha só os insetos que quiser e troque os nomes das zonas.
4. No Studio, crie uma Part para cada zona, com o nome igual ao campo `Zone` da Config
   (ex.: `ZonaFormiga`), e com **Transparency** = 1, **CanCollide** desligado e
   **Anchored** ligado.
5. Dê **Play**. Os insetos nascem sozinhos dentro das zonas.

Campos principais de cada inseto na Config: `Build` (qual modelo), `Count` (quantos),
`Scale` (tamanho), `Damage`, `ChaseSpeed`/`WanderSpeed`, `FlyHeight` (voadores),
`HopInterval` (saltos), `AttackSound` (ID de áudio).

### Noutro jogo que NÃO usa o kit

O `ZoneEnemy.luau` espera encontrar a Config em `ReplicatedStorage.Game.Config` e a pasta
`Models` ao lado dele (no mesmo sítio dentro do ServerScriptService). Também precisa de
alguém que chame `ZoneEnemy.start()` (no kit, isso é feito automaticamente).

## Como usar o cenário (Montanhas e Muro)

1. Abra o place no Studio, **sem** estar em Play.
2. Abra o ficheiro (ex.: `Cenario/Montanhas.luau`), selecione tudo (Ctrl+A) e copie.
3. Cole na barra **"Execute a command…"** do Studio e carregue em **Enter**.
4. Veja o resultado. **Ctrl+Z** desfaz tudo de uma vez.
5. Guarde com **File → Save to Roblox**.

Os valores de ajuste estão no topo de cada script (`SEMENTE`, `ALTURA_MAX`, `NEVE`,
`MARGEM`, `MODELO`, …).
