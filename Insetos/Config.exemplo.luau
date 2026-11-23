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
-- Cada inimigo anda só dentro da Part da zona e ataca quem estiver nela.
Config.Enemies = {
	{
		Model = "Formiga",
		Zone = "ZonaFormiga",
		-- Modelo próprio da formiga-de-fogo (games/exemplo/server/Models/Formiga.luau).
		Build = "Formiga",
		Count = 2, -- duas formigas (Formiga1 e Formiga2)
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
		Count = 3, -- quantos pulgões (Pulgao1 ... Pulgao3)
	},
	{
		Model = "Gafanhoto",
		Zone = "ZonaGafanhoto",
		-- Modelo próprio (games/exemplo/server/Models/Gafanhoto.luau).
		Build = "Gafanhoto",
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

return Config
