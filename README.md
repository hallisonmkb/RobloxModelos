# Modelos reaproveitáveis

Peças criadas no projeto `roblox-kit-base` (jogo de exemplo dos insetos), guardadas aqui
para usar noutros jogos. Tudo é **código Luau**: não há ficheiros `.rbxm`. Os modelos são
montados por código quando o jogo arranca, e o cenário é criado ao colar um script na
Command Bar do Studio.

Cópia atualizada a 24/11/2026 (commit 31f5619 do RobloxInsetos). A versão "oficial"
continua no repositório https://github.com/hallisonmkb/RobloxInsetos. Se lá mudar
alguma coisa, volte a copiar.

## Conteúdo

| Pasta / ficheiro | O que é |
| --- | --- |
| `Insetos/Models/Parts.luau` | Peças básicas para montar modelos (esferas, cilindros, juntas Motor6D, pivô). Os outros modelos precisam dele. |
| `Insetos/Models/Formiga.luau` | Formiga-de-fogo (cabeça e tórax avermelhados, gáster escuro, antenas cotoveladas, mandíbulas). |
| `Insetos/Models/Pulgao.luau` | Pulgão verde (corpo em pera, olhos vermelhos, antenas compridas, sifúnculos). |
| `Insetos/Models/MosquitoTigre.luau` | Mosquito-tigre (preto com riscas brancas, patas às faixas, asas que batem). |
| `Insetos/Models/Gafanhoto.luau` | Gafanhoto (patas de saltar enormes, asas dobradas). |
| `Insetos/Models/Ovo.luau` | Posturas de ovos realistas: `Pulgao` (cacho amarelo), `Formiga` ("grãos de arroz" creme), `Mosquito` (jangada castanha), `Gafanhoto` (casulo de terra), `Unico` (ovo grande). |
| `Insetos/Models/Ninhos.luau` | Ninhos: `Folha`, `Formigueiro` (monte em cone onde se sobe a andar), `Poca` (água com juncos), `Toca` (terra remexida). |
| `Insetos/ZoneEnemy.luau` | O "cérebro" dos insetos: dormir/passear sozinhos, acordar com ovos na zona, perseguir quem leva ovos (até fora da zona, nunca em zonas seguras), voar, pousar, saltar e animar patas, antenas e asas. `ZoneEnemy.pet(...)` faz um inseto pacífico passear numa área (fazenda). |
| `Insetos/Config.exemplo.luau` | Config completa do jogo dos insetos: `Enemies`, `Insetos` (ovos), `Ovos`, `Fazenda`, `Progressao`, `Descanso`. |
| `CicloOvos/Ovos.luau` | Ninhos e posturas em cada zona; pegar (E), soltar (G), cair ao ser picado, voltar ao ninho, entregar na fazenda. |
| `CicloOvos/Fazenda.luau` | Fazenda pessoal guardada: celeiro, 12 lotes em duas filas, feixe de luz no lote do dono, ovo -> bebé -> adulto, moedas por segundo, tempo menor por nível. |
| `CicloOvos/Descanso.luau` | Áreas de descanso (`ZonaDescanso*`): bancos, candeeiro, flores e cura. |
| `Kit/ProgressionService.luau` | Serviço do kit: XP, níveis, evento `LevelUp`, atributos Level/XP/XPNext e leaderstats. A Fazenda precisa dele. |
| `Kit/HUD.client.luau` | Cópia do cliente do kit: moedas, nível com barra de XP, faixa de "Estado", avisos e botão de ação (G). |
| `Cenario/Mapa.luau` | Cria todas as zonas do jogo dos insetos numa fila (fazenda, spawn, descansos e zonas dos insetos). |
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

### O ciclo completo (ovos, fazenda, níveis e descanso)

Precisa do kit (DataService, CurrencyService e Remotes) e de:
1. `Kit/ProgressionService.luau` em `src/server/Services/`, acrescentado à lista `ORDER`
   do `src/server/init.server.luau` depois do CurrencyService.
2. `CicloOvos/*.luau` em `games/<jogo>/server/`, ao lado do ZoneEnemy e da pasta Models.
3. Na Config: `DefaultData.Fazenda = {}` e as secções `Insetos`, `Ovos`, `Fazenda`,
   `Progressao` e `Descanso` do `Config.exemplo.luau`.
4. O HUD do `Kit/HUD.client.luau` (ou pelo menos as partes de "Estado", "Aviso", "Acao"
   e nível) em `src/client/init.client.luau`.
5. As zonas: correr o `Cenario/Mapa.luau` (ou criar as Parts à mão) e depois o
   `Cenario/Muro.luau`.

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
