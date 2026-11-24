--!strict
-- Configuração do jogo. Balanceie aqui, sem mexer no código dos serviços.

local Config = {}

Config.GameName = "Exemplo"

-- Dados iniciais de todo jogador novo. Campos novos aparecem
-- automaticamente para jogadores antigos (o DataService completa).
Config.DefaultData = {
	Coins = 0,
	TotalCoinsEarned = 0,
	Level = 1,
	XP = 0,
	Rebirths = 0,
	LastLogin = 0,
	DailyStreak = 0,
	-- Insetos na fazenda do jogador: lista de { Tipo = "Pulgao", Nasceu = os.time() }.
	Fazenda = {},
}

Config.Currency = {
	Name = "Moedas",
	StartingMultiplier = 1,
	OfflinePerSecond = 0, -- renda offline por segundo (0 = desligada)
	MaxOfflineSeconds = 8 * 60 * 60, -- limite de 8 h de renda offline
}

-- Mecânica de exemplo: clicar dá moedas.
Config.Click = {
	Reward = 1,
	CooldownSeconds = 0.15,
}

-- Inimigos presos a uma zona. "Model" e "Zone" são os nomes no Workspace.
-- Em zonas com ovos (Config.Insetos), cada inseto alterna sozinho entre dormir e passear;
-- quem passeia ataca quem chegar a menos de AggroRange studs. Quando alguém com ovos entra
-- na zona, todos perseguem-no, mesmo para fora da zona (até Alcance studs do centro), mas
-- nunca dentro das ZonasSeguras. Campos opcionais por inseto: SonoChance (0 a 1, fração do
-- tempo a dormir, 0,5 por omissão), AggroRange (12) e Alcance (250).
Config.Enemies = {
	{
		Model = "Formiga",
		Zone = "ZonaFormiga",
		-- Modelo próprio da formiga-de-fogo (games/exemplo/server/Models/Formiga.luau).
		Build = "Formiga",
		Count = 6, -- quantas formigas (Formiga1 ... Formiga6)
		-- Tamanhos proporcionais (cerca de 0,8 studs por mm real): formiga ~5 mm -> ~4 studs.
		Scale = 1, -- 4,3 studs das mandíbulas à ponta do gáster
		Damage = 10, -- dano por ataque
		AttackRange = 5, -- distância para morder (studs)
		AttackCooldown = 1, -- segundos entre ataques
		ChaseSpeed = 14, -- velocidade perseguindo (studs/s)
		WanderSpeed = 5, -- velocidade passeando
		EdgeMargin = 2, -- distância mínima da borda da zona
		FacingOffset = 0, -- graus para girar o modelo se ele andar de lado/de costas
		-- Realismo:
		TurnSpeed = 240, -- graus por segundo para virar
		Acceleration = 25, -- studs/s² para acelerar e frear
		WanderPause = 2, -- pausa máxima (s) ao chegar num ponto de passeio
		StepBob = 0.12, -- quanto o corpo sobe a cada passo
		StepRate = 0.3, -- ciclos de passo por stud andado
		TiltAngle = 3, -- balanço lateral do corpo ao andar (graus)
		LegSwing = 25, -- graus que cada pata vai para a frente/trás
		LegLift = 20, -- graus que cada pata levanta
		AttackSound = "rbxassetid://9125466770", -- som da mordida (ID de áudio)
	},
	{
		Model = "Pulgao",
		Zone = "ZonaPulgao",
		Scale = 0.6, -- pulgão ~2,5 mm -> corpo ~2,2 studs (1 = 3,6 studs sem antenas)
		Damage = 3, -- pulgão é fraco
		AttackRange = 4,
		AttackCooldown = 1.2,
		ChaseSpeed = 6, -- pulgão é lento
		WanderSpeed = 2.5,
		EdgeMargin = 2,
		FacingOffset = 0,
		TurnSpeed = 150,
		Acceleration = 12,
		WanderPause = 3,
		StepBob = 0.05,
		StepRate = 0.6,
		TiltAngle = 2,
		LegSwing = 20,
		LegLift = 15,
		Lunge = 0.6, -- studs que avança ao atacar
		AttackSound = "rbxassetid://9125466770", -- som da mordida (ID de áudio)
		-- Modelo próprio, feito em código (games/exemplo/server/Models/Pulgao.luau).
		-- Não precisa de modelo no Workspace: nasce num ponto aleatório da zona.
		Build = "Pulgao",
		Count = 8, -- quantos pulgões (Pulgao1 ... Pulgao8)
	},
	{
		Model = "Gafanhoto",
		Zone = "ZonaGafanhoto",
		-- Modelo próprio (games/exemplo/server/Models/Gafanhoto.luau).
		Build = "Gafanhoto",
		Count = 3, -- quantos gafanhotos
		-- Um gafanhoto real (~40 mm) teria ~30 studs; fica maior que os outros, mas não gigante.
		Scale = 2, -- ~8,8 studs da cabeça à ponta das asas
		Damage = 8,
		AttackRange = 6,
		AttackCooldown = 1.3,
		ChaseSpeed = 22, -- mais rápido que o mosquito (18)
		WanderSpeed = 8, -- mosquito passeia a 7
		EdgeMargin = 3,
		FacingOffset = 0,
		TurnSpeed = 180,
		Acceleration = 35,
		WanderPause = 2,
		StepBob = 0.05,
		StepRate = 0.5,
		TiltAngle = 2,
		LegSwing = 20,
		LegLift = 15,
		Lunge = 1,
		AttackSound = "rbxassetid://9125466770",
		-- Saltos:
		HopInterval = { 2, 5 }, -- segundos entre saltos (metade quando persegue)
		HopTime = 0.55, -- duração de cada salto
		HopHeight = 3, -- altura do salto (studs)
		HopDistance = 10, -- distância de cada salto (studs)
	},
	{
		Model = "Mosquito",
		Zone = "ZonaMosquito",
		-- Modelo próprio do mosquito-tigre (games/exemplo/server/Models/MosquitoTigre.luau).
		Build = "MosquitoTigre",
		Count = 4, -- quantos mosquitos
		Scale = 1.2, -- mosquito-tigre ~5 mm -> corpo ~3,8 studs, 5,2 com a tromba
		WingFlap = 55, -- graus do bater de asas
		WingRate = 14, -- batidas de asa por segundo
		LegSwing = 15, -- patas compridas: passo mais curto no chão
		LegLift = 10,
		Damage = 5,
		AttackRange = 4,
		AttackCooldown = 0.8,
		ChaseSpeed = 18, -- mais rápido que a formiga (14)
		WanderSpeed = 7,
		EdgeMargin = 2,
		FacingOffset = 0,
		-- Voador:
		FlyHeight = 8, -- altura acima do topo da zona ao passear (studs)
		BobAmplitude = 0.6, -- quanto sobe/desce enquanto voa
		BobSpeed = 1.5, -- balanços por segundo
		VerticalSpeed = 8, -- velocidade para descer até o jogador e voltar a subir
		Jitter = 0.4, -- tremor do voo (studs)
		FlyTime = { 6, 12 }, -- segundos a voar antes de pousar (mín, máx)
		GroundTime = { 4, 8 }, -- segundos pousado a andar no chão (mín, máx)
		GroundSpeed = 2, -- velocidade a andar no chão
		StepBob = 0.03, -- passada no chão
		StepRate = 1,
		TurnSpeed = 360,
		Acceleration = 40,
		WanderPause = 1,
		TiltAngle = 15, -- inclina para a frente ao voar rápido e de lado nas curvas
		Lunge = 1.5, -- investida ao picar (studs)
		LungePitch = 25, -- aponta o ferrão para baixo ao picar (graus)
		AttackSound = "rbxassetid://9125466770", -- som da picada (ID de áudio)
		LoopSound = "rbxassetid://109978104393702", -- zumbido contínuo enquanto voa
	},
}

-- Ovos e ninhos. A chave é o tipo de inseto; "Zone" é a zona onde está o ninho (os insetos
-- dessa zona dormem até alguém pegar o ovo). Ordem de dificuldade: Pulgao < Formiga <
-- Mosquito < Gafanhoto. Quanto mais difícil, mais moedas rende. Os ovos seguem as fotos
-- reais de cada inseto (forma e cor), por isso a cor já não indica a dificuldade.
Config.Insetos = {
	Pulgao = {
		Nome = "Pulgão",
		Zone = "ZonaPulgao",
		Build = "Pulgao", -- modelo usado na fazenda
		Ninho = "Folha", -- cada postura numa folha grande
		FormaOvo = "Pulgao", -- cacho de ovos alongados amarelos
		OvosNaZona = 4, -- quantas posturas há ao mesmo tempo na zona
		CorOvo = Color3.fromRGB(250, 205, 45), -- amarelo
		CorPintas = Color3.fromRGB(235, 150, 20), -- tom mais alaranjado (variação)
		Dificuldade = 1,
		ChocaEm = 30, -- segundos até o ovo chocar na fazenda
		CresceEm = 120, -- segundos (desde que nasceu) até ficar adulto
		Rende = 1, -- moedas por segundo quando adulto (bebé rende metade)
		EscalaFazenda = 0.6,
	},
	Formiga = {
		Nome = "Formiga-de-fogo",
		Zone = "ZonaFormiga",
		Build = "Formiga",
		Ninho = "Formigueiro", -- monte de terra em cone (sobe-se a andar); uma postura no topo
		FormaOvo = "Formiga", -- monte de ovos brancos-creme em forma de grão de arroz
		OvosNaZona = 4,
		CorOvo = Color3.fromRGB(240, 230, 200), -- creme
		CorPintas = Color3.fromRGB(70, 55, 40), -- pinta escura na ponta
		Dificuldade = 2,
		ChocaEm = 45,
		CresceEm = 180,
		Rende = 3,
		EscalaFazenda = 0.8,
	},
	Mosquito = {
		Nome = "Mosquito-tigre",
		Zone = "ZonaMosquito",
		Build = "MosquitoTigre",
		Ninho = "Poca", -- a jangada de ovos flutua numa poça
		FormaOvo = "Mosquito", -- jangada de ovos castanhos em forma de tubo
		OvosNaZona = 3,
		CorOvo = Color3.fromRGB(125, 85, 45), -- castanho
		CorPintas = Color3.fromRGB(45, 28, 15), -- ponta escura
		Dificuldade = 3,
		ChocaEm = 60,
		CresceEm = 240,
		Rende = 6,
		EscalaFazenda = 0.9,
	},
	Gafanhoto = {
		Nome = "Gafanhoto",
		Zone = "ZonaGafanhoto",
		Build = "Gafanhoto",
		Ninho = "Toca", -- casulo meio enterrado em terra remexida
		FormaOvo = "Gafanhoto", -- casulo de terra com ovos alongados cor de creme
		OvosNaZona = 3,
		CorOvo = Color3.fromRGB(230, 210, 165), -- creme
		CorPintas = Color3.fromRGB(125, 110, 85), -- cor da terra do casulo
		Dificuldade = 4,
		ChocaEm = 90,
		CresceEm = 360,
		Rende = 12,
		EscalaFazenda = 1.2,
	},
}

Config.Ovos = {
	Altura = 5, -- tamanho de cada postura em studs ("tamanho de dinossauro")
	VoltaEm = 20, -- segundos até aparecer uma postura nova no sítio de onde foi levada
	SegurarPor = 0.5, -- segundos a carregar E para pegar no ovo
	CaiAoSerPicado = true, -- se um inseto picar quem leva os ovos, eles caem ao chão
	CaidoVoltaEm = 30, -- segundos que uma postura caída fica no chão antes de voltar ao ninho
}

-- Fazenda pessoal: a Part "ZonaFazenda" é dividida em lotes, um por jogador. Se a Part não
-- existir, o jogo cria-a ao lado da ZonaPrincipal (ou do spawn).
Config.Fazenda = {
	Zone = "ZonaFazenda",
	Lotes = 12, -- quantos jogadores ao mesmo tempo (duas filas de 6); o servidor deve ter no máximo isto
	MaxInsetos = 12, -- máximo de insetos por jogador
	RendeBebe = 0.5, -- fração do rendimento enquanto é bebé
	-- Cada nível do jogador encurta o tempo de chocar e de crescer:
	-- fator = max(FatorMinimo, 1 - ReducaoPorNivel * (nível - 1)).
	-- Ex.: nível 1 = 100 % do tempo, nível 5 = 76 %, nível 10 = 46 %, nível 13+ = 30 %.
	ReducaoPorNivel = 0.06,
	FatorMinimo = 0.3,
	XPPorDificuldade = 25, -- XP ao entregar ovos = Dificuldade do inseto x isto
	TamanhoAuto = Vector3.new(220, 1, 120), -- tamanho da ZonaFazenda criada automaticamente
}

-- Níveis do jogador (ProgressionService do kit).
-- XP para passar do nível N ao N+1 = XPBase * Crescimento^(N-1).
Config.Progressao = {
	XPBase = 100,
	Crescimento = 1.35,
	NivelMax = 50,
	Nome = "Nível", -- nome na tabela de jogadores (leaderstats)
}

-- Áreas de descanso: todas as Parts cujo nome começa por "ZonaDescanso".
Config.Descanso = {
	Prefixo = "ZonaDescanso",
	CuraPorSegundo = 8, -- vida recuperada por segundo dentro da área
}

return Config
