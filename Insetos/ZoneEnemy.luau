--!strict
-- Inimigo preso a uma zona: passeia dentro da Part da zona e persegue/ataca
-- qualquer jogador que entrar nela. Funciona com qualquer modelo (não precisa de Humanoid):
-- o modelo é ancorado e movido pelo servidor.
-- Inimigos com "FlyHeight" voam: pairam acima da zona, balançam e descem até o jogador para atacar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Config"))

local ZoneEnemy = {}

local FIND_TIMEOUT = 15 -- segundos procurando o modelo/zona no Workspace

type EnemyConfig = {
	Model: string,
	Zone: string,
	Build: string?, -- usa um modelo próprio de games/<jogo>/server/Models/<Build>.luau
	Count: number?, -- quantos iguais criar (só com Build); nomes Model1, Model2, ...
	Damage: number,
	AttackRange: number,
	AttackCooldown: number,
	ChaseSpeed: number,
	WanderSpeed: number,
	EdgeMargin: number,
	FacingOffset: number,
	Scale: number?, -- multiplica o tamanho do modelo (0.5 = metade, 2 = dobro)
	-- Só para voadores:
	FlyHeight: number?, -- altura (studs) acima do topo da zona ao passear
	BobAmplitude: number?, -- quanto sobe/desce enquanto voa
	BobSpeed: number?, -- velocidade do balanço (ciclos por segundo)
	VerticalSpeed: number?, -- velocidade para subir/descer (studs/s)
	Jitter: number?, -- tremor do voo (studs), deixa o voo irregular
	FlyTime: { number }?, -- {mín, máx} segundos a voar antes de pousar
	GroundTime: { number }?, -- {mín, máx} segundos pousado (sem isto, nunca pousa)
	GroundSpeed: number?, -- velocidade a andar no chão quando pousado
	WingFlap: number?, -- graus do bater de asas (modelos com asas separadas)
	WingRate: number?, -- batidas de asa por segundo
	-- Saltos (andantes):
	HopInterval: { number }?, -- {mín, máx} segundos entre saltos (sem isto, não salta)
	HopTime: number?, -- duração de cada salto (s)
	HopHeight: number?, -- altura do salto (studs)
	HopDistance: number?, -- distância de cada salto (studs)
	-- Realismo (todos opcionais):
	TurnSpeed: number?, -- graus por segundo para virar
	Acceleration: number?, -- studs/s² para acelerar e frear
	WanderPause: number?, -- pausa máxima (s) ao chegar num ponto de passeio
	StepBob: number?, -- quanto o corpo sobe a cada passo (andantes)
	StepRate: number?, -- passos por stud andado
	TiltAngle: number?, -- graus: balanço lateral (andantes) ou inclinação no voo
	-- Patas (só modelos com Motor6D):
	LegSwing: number?, -- graus que a pata vai para a frente/trás a cada passo
	LegLift: number?, -- graus que a pata levanta a cada passo
	AttackSound: string?, -- som ao atacar: nome de um Sound do modelo ou ID de áudio
	LoopSound: string?, -- som contínuo (ex.: zumbido do mosquito): ID de áudio
	Lunge: number?, -- studs que o corpo avança ao atacar
	LungePitch: number?, -- graus que a cabeça baixa ao atacar
	LegParts: { string }?, -- nomes das peças do 1º segmento de cada pata (quando não seguem o padrão)
}

-- Desliga scripts que vieram com o modelo (Toolbox pode trazer backdoor), detectores que
-- deixariam o jogador arrastar o modelo, e constraints de ragdoll.
local function neutralize(model: Model)
	for _, item in model:GetDescendants() do
		if item:IsA("BaseScript") then
			item.Enabled = false
			item:Destroy()
		elseif item:IsA("DragDetector") or item:IsA("ClickDetector") then
			item:Destroy()
		elseif item:IsA("Constraint") then
			item.Enabled = false
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
		elseif item:IsA("Humanoid") then
			item.PlatformStand = true
			-- Sem nome nem barra de vida por cima do inimigo.
			item.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			item.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
	end
end

-- ===== Animação procedural das patas (modelos com Motor6D) =====
-- As juntas são reconhecidas pelo nome da peça que mexem (Part1 do Motor6D):
--   <Left|Right><Front|Mid|Back>Leg1 = quadril, ...Leg2 = joelho,
--   ...Antennae1 = antena, ...Mandible = mandíbula.
-- Os eixos de rotação são calculados a partir da pose inicial, por isso funciona
-- mesmo sem saber como o modelo foi montado.

type Joint = {
	motor: Motor6D,
	base: CFrame, -- C0 original
	kind: string, -- "hip" | "knee" | "antenna" | "mandible" | "limb" (R6)
	swingAxis: Vector3, -- eixo vertical do corpo, no espaço da junta
	liftAxis: Vector3, -- eixo que levanta a pata, no espaço da junta
	swingSign: number, -- +1/-1 para "rodar para a frente"
	openSign: number, -- +1/-1 para abrir (mandíbulas)
	phase: number, -- 0 ou pi: os dois grupos do passo em tripé
}

-- Passo em tripé dos insetos: estas três patas mexem juntas, as outras três ao contrário.
local TRIPOD_A = { LeftFront = true, RightMid = true, LeftBack = true }

-- Modelos montados sobre um esqueleto R6 (Torso + braços/pernas): as patas visíveis costumam
-- estar presas aos membros. Pares diagonais mexem juntos, como num passo de inseto.
local R6_LIMBS: { [string]: number } = {
	["Left Shoulder"] = 0,
	["Right Hip"] = 0,
	["Right Shoulder"] = math.pi,
	["Left Hip"] = math.pi,
}

-- Descobre a peça raiz: a que nunca é "Part1" de nenhum Motor6D.
local function findRoot(model: Model, motors: { Motor6D }): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local driven: { [BasePart]: boolean } = {}
	for _, motor in motors do
		if motor.Part1 then
			driven[motor.Part1] = true
		end
	end
	for _, motor in motors do
		local part0 = motor.Part0
		if part0 and not driven[part0] then
			return part0
		end
	end
	return nil
end

-- Prepara o rig: só a raiz fica ancorada, o resto fica preso a ela pelos Motor6D,
-- para podermos rodar as juntas. Devolve nil se o modelo não tiver juntas.
local function setupRig(model: Model, facing: CFrame, legParts: { string }?): { Joint }?
	local motors: { Motor6D } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") and item.Part0 and item.Part1 then
			table.insert(motors, item)
		end
	end
	if #motors == 0 then
		return nil
	end
	local root = findRoot(model, motors)
	if not root then
		warn(`[ZoneEnemy] "{model.Name}": não achei a peça raiz das juntas; patas ficam paradas`)
		return nil
	end

	-- Partes ligadas por Motor6D deixam de ser ancoradas (a raiz ancorada segura tudo).
	local jointed: { [BasePart]: boolean } = {}
	for _, motor in motors do
		motor.Enabled = true
		jointed[motor.Part1 :: BasePart] = true
	end
	for part in jointed do
		if part ~= root then
			part.Anchored = false
			part.Massless = true
		end
	end
	root.Anchored = true

	-- Direções do corpo na pose inicial.
	local body = model:GetPivot() * facing:Inverse()
	local up = body.UpVector
	local forward = body.LookVector
	local right = body.RightVector

	-- Patas indicadas na Config (LegParts): descobre o lado e a ordem (frente -> trás) pela
	-- posição, e monta o passo em tripé a partir disso.
	local customPhase: { [string]: number } = {}
	if legParts then
		local isHip: { [string]: boolean } = {}
		for _, legName in legParts do
			isHip[legName] = true
		end
		local leftLegs, rightLegs = {}, {}
		for _, motor in motors do
			local p1 = motor.Part1 :: BasePart
			if isHip[p1.Name] then
				local offset = ((motor.Part0 :: BasePart).CFrame * motor.C0).Position - root.Position
				local list = if offset:Dot(right) > 0 then rightLegs else leftLegs
				table.insert(list, { name = p1.Name, ahead = offset:Dot(forward) })
			end
		end
		for _, list in { leftLegs, rightLegs } do
			table.sort(list, function(a, b)
				return a.ahead > b.ahead
			end)
			for i, leg in list do
				local groupA = if list == leftLegs then i % 2 == 1 else i % 2 == 0
				customPhase[leg.name] = if groupA then 0 else math.pi
			end
		end
	end

	local joints: { Joint } = {}
	for _, motor in motors do
		local name = (motor.Part1 :: BasePart).Name
		local side, pos, segment = string.match(name, "^(%a-)(Front)Leg(%d)$")
		if not side then
			side, pos, segment = string.match(name, "^(%a-)(Mid)Leg(%d)$")
		end
		if not side then
			side, pos, segment = string.match(name, "^(%a-)(Back)Leg(%d)$")
		end
		local kind: string? = nil
		local limbPhase = if legParts then nil else R6_LIMBS[motor.Name]
		local parentName = (motor.Part0 :: BasePart).Name
		if legParts then
			-- Só as patas da Config: o quadril e o segmento logo a seguir (joelho).
			if customPhase[name] then
				kind = "hip"
				limbPhase = customPhase[name]
			elseif customPhase[parentName] then
				kind = "knee"
				limbPhase = customPhase[parentName]
			end
		elseif limbPhase then
			kind = "limb"
		elseif segment == "1" then
			kind = "hip"
		elseif segment == "2" then
			kind = "knee"
		elseif string.match(name, "Antennae?1$") then
			kind = "antenna"
		elseif string.match(name, "Antennae?2$") then
			kind = "antenna2"
		elseif string.match(name, "HindLeg1$") then
			kind = "hind1" -- patas de saltar (gafanhoto): coxa
		elseif string.match(name, "HindLeg2$") then
			kind = "hind2" -- patas de saltar: tíbia
		elseif string.match(name, "Mandible$") then
			kind = "mandible"
		elseif string.match(string.lower(name), "wing") or string.match(string.lower(name), "^asa") then
			kind = "wing"
		end
		if kind then
			local jointCF = (motor.Part0 :: BasePart).CFrame * motor.C0
			local isRight = (jointCF.Position - root.Position):Dot(right) > 0
			local outward: Vector3
			if kind == "hip" or kind == "knee" or kind == "wing" then
				-- Patas e asas saem para o lado do corpo: usa a direção lateral pura, para
				-- as patas da frente/de trás balançarem igual às do meio.
				outward = if isRight then right else -right
			else
				outward = jointCF.Position - root.Position
				outward -= up * outward:Dot(up)
				if outward.Magnitude < 1e-3 then
					outward = right
				end
				outward = outward.Unit
			end
			local liftWorld = outward:Cross(up)
			if liftWorld.Magnitude < 1e-3 then
				liftWorld = right
			end
			table.insert(joints, {
				motor = motor,
				base = motor.C0,
				kind = kind,
				-- Membros R6 balançam para a frente/trás (eixo lateral); patas de inseto, no eixo vertical.
				-- Asas batem à volta do eixo frente-trás.
				swingAxis = jointCF:VectorToObjectSpace(
					if kind == "limb"
							or kind == "hind1"
							or kind == "hind2"
						then right
						elseif kind == "wing" then forward
						else up
				).Unit,
				liftAxis = jointCF:VectorToObjectSpace(liftWorld.Unit).Unit,
				swingSign = if up:Cross(outward):Dot(forward) >= 0 then 1 else -1,
				openSign = if isRight then -1 else 1,
				phase = if limbPhase
					then limbPhase
					elseif side and pos and TRIPOD_A[`{side}{pos}`] then 0
					else math.pi,
			})
		end
	end
	return joints
end

-- Aplica a pose da frame atual a todas as juntas.
-- gait: 0 (parado) a 1 (andando); bite: 0 a 1 (mandíbulas fechando).
local function animateRig(
	joints: { Joint },
	stepPhase: number,
	gait: number,
	bite: number,
	now: number,
	legSwing: number,
	legLift: number,
	flap: number, -- 0 (asas paradas) a 1 (a voar)
	wingFlap: number, -- amplitude do bater de asas (radianos)
	wingRate: number, -- batidas por segundo
	kick: number, -- 0 a 1: patas de saltar esticadas (início do salto)
	alert: number -- 0 (calmo) a 1 (a perseguir): antenas mais agitadas
)
	for i, joint in joints do
		local rotation: CFrame
		if joint.kind == "limb" then
			local swing = math.sin(stepPhase + joint.phase) * legSwing * gait
			rotation = CFrame.fromAxisAngle(joint.swingAxis, swing)
		elseif joint.kind == "hip" or joint.kind == "knee" then
			local p = stepPhase + joint.phase
			-- A pata vai para a frente no ar (cos > 0) e volta para trás apoiada no chão.
			local lift = math.max(0, math.cos(p)) * legLift * gait
			if joint.kind == "hip" then
				local swing = math.sin(p) * legSwing * gait * joint.swingSign
				rotation = CFrame.fromAxisAngle(joint.swingAxis, swing)
					* CFrame.fromAxisAngle(joint.liftAxis, lift)
			else
				rotation = CFrame.fromAxisAngle(joint.liftAxis, lift * 0.6)
			end
		elseif joint.kind == "antenna" then
			-- Antenas sempre a mexer, mesmo parada; mais rápidas quando persegue.
			local speed = 1 + alert * 1.5
			local sway = math.sin(now * 2.3 * speed + i) * 0.35 + math.sin(now * 6.1 * speed + i * 2) * 0.1
			rotation = CFrame.fromAxisAngle(joint.swingAxis, sway)
				* CFrame.fromAxisAngle(joint.liftAxis, math.sin(now * 1.9 * speed + i) * 0.2)
		elseif joint.kind == "antenna2" then
			-- Ponta da antena: mexe desfasada, como se estivesse a "tatear".
			local speed = 1 + alert * 1.5
			rotation = CFrame.fromAxisAngle(joint.swingAxis, math.sin(now * 3.7 * speed + i * 1.3) * 0.3)
				* CFrame.fromAxisAngle(joint.liftAxis, math.sin(now * 2.9 * speed + i) * 0.25)
		elseif joint.kind == "hind1" then
			-- Coxa da pata de saltar: empurra para baixo/trás no salto.
			rotation = CFrame.fromAxisAngle(joint.swingAxis, 0.6 * kick)
		elseif joint.kind == "hind2" then
			-- Tíbia: estica (abre o "joelho") no salto.
			rotation = CFrame.fromAxisAngle(joint.swingAxis, -1.5 * kick)
		elseif joint.kind == "wing" then
			-- As duas asas sobem e descem juntas (espelhadas pelo lado).
			local beat = math.sin(now * wingRate * math.pi * 2) * wingFlap * flap
			rotation = CFrame.fromAxisAngle(joint.swingAxis, beat * joint.openSign)
		else -- mandíbula
			local open = (0.08 + math.sin(now * 3 + i) * 0.04) * (1 - bite) - 0.15 * bite
			rotation = CFrame.fromAxisAngle(joint.swingAxis, open * joint.openSign)
		end
		joint.motor.C0 = joint.base * rotation
	end
end

-- Som do inimigo: o nome de um Sound que já está no modelo (ex.: "Bite") ou um ID de
-- áudio ("rbxassetid://123" ou só "123"), que cria um Sound novo preso ao modelo.
local function findSound(model: Model, nameOrId: string?, looped: boolean): Sound?
	if not nameOrId or nameOrId == "" then
		return nil
	end
	local id = string.match(nameOrId, "^rbxassetid://(%d+)$") or string.match(nameOrId, "^(%d+)$")
	if not id then
		local found = model:FindFirstChild(nameOrId, true)
		return if found and found:IsA("Sound") then found else nil
	end
	local holder = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not holder then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = if looped then "SomContinuo" else "SomAtaque"
	sound.SoundId = `rbxassetid://{id}`
	sound.Looped = looped
	sound.Volume = if looped then 0.4 else 0.8
	sound.RollOffMaxDistance = 60
	sound.Parent = holder
	return sound
end

-- Procura pelo nome em todo o Workspace (inclusive dentro de pastas), esperando até aparecer.
local function findInWorkspace(name: string): Instance?
	local deadline = os.clock() + FIND_TIMEOUT
	repeat
		local found = workspace:FindFirstChild(name, true)
		if found then
			return found
		end
		task.wait(0.5)
	until os.clock() > deadline
	return nil
end

-- Posição dentro da zona, nos eixos locais da Part.
local function toLocal(zone: BasePart, worldPos: Vector3): Vector3
	return zone.CFrame:PointToObjectSpace(worldPos)
end

local function isInside(zone: BasePart, worldPos: Vector3, ceiling: number): boolean
	local p = toLocal(zone, worldPos)
	local half = zone.Size / 2
	return math.abs(p.X) <= half.X
		and math.abs(p.Z) <= half.Z
		and p.Y > -half.Y - 2
		and p.Y < half.Y + ceiling
end

-- Converte (x, z locais + altura acima do topo) em posição no mundo. Com margem, fica dentro
-- da zona; sem margem (nil), pode estar fora (inseto a perseguir noutra zona).
local function zonePoint(zone: BasePart, x: number, z: number, margin: number?, height: number): Vector3
	local half = zone.Size / 2
	local cx, cz = x, z
	if margin then
		cx = math.clamp(x, -half.X + margin, half.X - margin)
		cz = math.clamp(z, -half.Z + margin, half.Z - margin)
	end
	return zone.CFrame:PointToWorldSpace(Vector3.new(cx, half.Y + height, cz))
end

-- Zonas seguras (spawn, fazenda e descanso): os insetos não perseguem ninguém lá dentro.
local SAFE_PREFIXES: { string } = (Config :: any).ZonasSeguras
	or { "ZonaPrincipal", "ZonaFazenda", "ZonaDescanso" }
local safeParts: { BasePart } = {}
local safeScannedAt = -math.huge

local function isSafe(position: Vector3): boolean
	if os.clock() - safeScannedAt > 10 then
		safeScannedAt = os.clock()
		table.clear(safeParts)
		for _, item in workspace:GetDescendants() do
			if item:IsA("BasePart") then
				for _, prefix in SAFE_PREFIXES do
					if string.sub(item.Name, 1, #prefix) == prefix then
						table.insert(safeParts, item)
						break
					end
				end
			end
		end
	end
	for _, part in safeParts do
		local p = part.CFrame:PointToObjectSpace(position)
		local half = part.Size / 2
		if
			math.abs(p.X) <= half.X
			and math.abs(p.Z) <= half.Z
			and p.Y > -half.Y - 2
			and p.Y < half.Y + 30
		then
			return true
		end
	end
	return false
end

-- Quem leva ovos (atributo "CarregandoOvo", posto pelo módulo Ovos), vivo, fora das zonas
-- seguras e a menos de "leash" studs do centro da zona do inseto. Devolve o mais próximo.
local function findCarrier(from: Vector3, center: Vector3, leash: number): (Humanoid?, BasePart?)
	local best: Humanoid?, bestRoot: BasePart?, bestDist = nil, nil, math.huge
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("CarregandoOvo") ~= nil then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if
				humanoid
				and root
				and humanoid.Health > 0
				and (root.Position - center).Magnitude <= leash
				and not isSafe(root.Position)
			then
				local dist = (root.Position - from).Magnitude
				if dist < bestDist then
					best, bestRoot, bestDist = humanoid, root, dist
				end
			end
		end
	end
	return best, bestRoot
end

local function randomXZ(zone: BasePart, margin: number): (number, number)
	local half = zone.Size / 2
	local x = (math.random() * 2 - 1) * math.max(half.X - margin, 0)
	local z = (math.random() * 2 - 1) * math.max(half.Z - margin, 0)
	return x, z
end

local function findTarget(zone: BasePart, from: Vector3, ceiling: number): (Humanoid?, BasePart?)
	local best: Humanoid?, bestRoot: BasePart?, bestDist = nil, nil, math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and humanoid.Health > 0 and isInside(zone, root.Position, ceiling) then
			local dist = (root.Position - from).Magnitude
			if dist < bestDist then
				best, bestRoot, bestDist = humanoid, root, dist
			end
		end
	end
	return best, bestRoot
end

local function run(cfg: EnemyConfig, name: string)
	local zone = findInWorkspace(cfg.Zone)
	if not zone or not zone:IsA("BasePart") then
		warn(`[ZoneEnemy] zona "{cfg.Zone}" não encontrada (crie uma Part com o nome "{cfg.Zone}")`)
		return
	end

	local model: Instance?
	if cfg.Build then
		-- Modelo próprio, construído em código (games/<jogo>/server/Models/<Build>.luau).
		local models = script.Parent and script.Parent:FindFirstChild("Models")
		local builder = models and models:FindFirstChild(cfg.Build)
		if not builder or not builder:IsA("ModuleScript") then
			warn(`[ZoneEnemy] construtor de modelo "{cfg.Build}" não encontrado na pasta Models`)
			return
		end
		-- Um modelo antigo com o mesmo nome no Workspace sai só durante o jogo (o place não muda).
		local old = workspace:FindFirstChild(name, true)
		if old then
			old:Destroy()
			print(`[ZoneEnemy] modelo antigo "{name}" substituído pelo modelo próprio "{cfg.Build}"`)
		end
		-- Nasce num ponto aleatório da zona, virado para um lado qualquer.
		local sx, sz = randomXZ(zone, cfg.EdgeMargin)
		local spawnAt = zone.CFrame
			* CFrame.new(sx, zone.Size.Y / 2, sz)
			* CFrame.Angles(0, math.random() * math.pi * 2, 0)
		local built = (require(builder) :: any).build(name, spawnAt) :: Model
		built.Parent = workspace
		model = built
	else
		model = findInWorkspace(name)
	end
	if not model or not model:IsA("Model") then
		warn(`[ZoneEnemy] modelo "{name}" não encontrado no Workspace (confira o nome exato)`)
		return
	end

	neutralize(model)
	-- Tamanho: Scale multiplica o tamanho original do modelo (0.5 = metade).
	if cfg.Scale and cfg.Scale > 0 and cfg.Scale ~= 1 then
		model:ScaleTo(model:GetScale() * cfg.Scale)
	end
	local facing = CFrame.Angles(0, math.rad(cfg.FacingOffset), 0)
	local joints = setupRig(model, facing, cfg.LegParts)
	local legSwing = math.rad(cfg.LegSwing or 25)
	local legLift = math.rad(cfg.LegLift or 20)
	local attackSound = findSound(model, cfg.AttackSound, false)
	local loopSound = findSound(model, cfg.LoopSound, true)
	if loopSound then
		loopSound:Play()
	end
	local lunge = cfg.Lunge or 1
	local lungePitch = math.rad(cfg.LungePitch or 12)
	local biteUntil = 0
	local ATTACK_TIME = 0.3 -- duração da investida/mordida

	local flying = cfg.FlyHeight ~= nil
	local bobAmplitude = cfg.BobAmplitude or 0
	local bobSpeed = cfg.BobSpeed or 1
	local verticalSpeed = cfg.VerticalSpeed or 6
	local turnSpeed = math.rad(cfg.TurnSpeed or 270)
	local acceleration = cfg.Acceleration or 30
	local wanderPause = cfg.WanderPause or 0
	local stepBob = cfg.StepBob or 0
	local stepRate = cfg.StepRate or 1
	local tilt = math.rad(cfg.TiltAngle or 0)
	local jitter = cfg.Jitter or 0
	local seed = math.random() * 1000
	local wingFlap = math.rad(cfg.WingFlap or 50)
	local wingRate = cfg.WingRate or 12

	-- Voadores que também pousam: alternam entre voar (FlyTime) e andar no chão (GroundTime).
	local function randomRange(range: { number }?, default: number): number
		if not range then
			return default
		end
		local lo, hi = range[1], range[2] or range[1]
		return lo + math.random() * (hi - lo)
	end
	local canLand = flying and cfg.GroundTime ~= nil
	local groundSpeed = cfg.GroundSpeed or cfg.WanderSpeed * 0.3
	local airborne = true
	local stateUntil = os.clock() + randomRange(cfg.FlyTime, 8)

	-- Saltos (andantes com HopInterval, ex.: gafanhoto): de vez em quando dá um pulo para a frente.
	local canHop = not flying and cfg.HopInterval ~= nil
	local hopTime = cfg.HopTime or 0.5
	local hopHeight = cfg.HopHeight or 2
	local hopDistance = cfg.HopDistance or 4
	local hopStart = -math.huge
	local nextHop = os.clock() + randomRange(cfg.HopInterval, 3)

	-- Altura do modelo acima do topo da zona.
	local startLocal = toLocal(zone, model:GetPivot().Position)
	-- Andantes: apoia a parte de baixo do modelo no topo da zona (vale para qualquer tamanho).
	local boxCF, boxSize = model:GetBoundingBox()
	local pivotAboveBottom = model:GetPivot().Position.Y - (boxCF.Position.Y - boxSize.Y / 2)
	local groundHeight = math.max(pivotAboveBottom, 0)
	local cruiseHeight = if flying then cfg.FlyHeight :: number else groundHeight
	-- Voadores detectam jogadores até um pouco acima da altura de voo.
	local ceiling = math.max(20, cruiseHeight + 10)

	local x, z = startLocal.X, startLocal.Z
	local height = if flying then cruiseHeight else groundHeight
	local wanderX, wanderZ = randomXZ(zone, cfg.EdgeMargin)
	local nextWander = 0
	local pausedUntil = 0
	local pausedHere = false -- já pausou no ponto de passeio atual
	local lastAttack = 0
	-- Direção atual (ângulo nos eixos X/Z da zona) e velocidade atual: o inimigo vira e
	-- acelera aos poucos em vez de mudar de direção instantaneamente.
	local yaw = math.random() * math.pi * 2
	local currentSpeed = 0
	local stepPhase = 0

	-- Dormir junto ao ninho: enquanto a zona tiver o atributo Acordado = false (posto pelo
	-- módulo Ovos), o inseto ignora os jogadores, vai para o seu lugar à volta do ninho (no
	-- centro da zona) e fica quieto, virado para o ovo. Sem o atributo, está sempre acordado.
	local homeAngle = math.random() * math.pi * 2
	local homeExtra = 2 + math.random() * 3
	local function homeXZ(): (number, number)
		local radius = (zone:GetAttribute("NinhoRaio") :: number? or 6) + homeExtra
		return math.cos(homeAngle) * radius, math.sin(homeAngle) * radius
	end

	-- Vida própria (zonas com ovos): cada inseto alterna sozinho entre "dormir" (no lugar à
	-- volta do ninho) e "passear" (pela zona). Quem passeia ataca quem se aproximar demasiado.
	-- Quando alguém com ovos está na zona, todos acordam e perseguem-no, mesmo para fora da
	-- zona (até "Alcance" studs do centro), mas nunca dentro das zonas seguras.
	local sleepChance = cfg.SonoChance or 0.5
	local aggroRange = cfg.AggroRange or 12
	local leash = cfg.Alcance or 250
	local mode = if math.random() < sleepChance then "dormir" else "passear"
	local modeUntil = os.clock() + math.random(10, 40)
	local hunting = false

	local hasInsectLegs = false
	for _, joint in joints or {} do
		if joint.kind == "hip" then
			hasInsectLegs = true
		end
	end
	if not flying and not hasInsectLegs then
		-- Ajuda a configurar: lista as juntas (peça presa -> peça que mexe), para saber
		-- a que peça as patas estão presas.
		local links = {}
		for _, item in model:GetDescendants() do
			if item:IsA("JointInstance") then
				local p0 = if item.Part0 then item.Part0.Name else "?"
				local p1 = if item.Part1 then item.Part1.Name else "?"
				table.insert(links, `{item.Name}: {p0} -> {p1}`)
			end
		end
		print(`[ZoneEnemy] "{name}" juntas: {table.concat(links, "; ")}`)
	end
	local _, finalSize = model:GetBoundingBox()
	local rigInfo = if joints then `, {#joints} juntas animadas` else ""
	print(
		`[ZoneEnemy] "{name}" ativo na zona "{cfg.Zone}"{if flying then " (voando)" else ""}{rigInfo}`
			.. `, tamanho {math.floor(math.max(finalSize.X, finalSize.Z) * 10 + 0.5) / 10} studs`
	)

	RunService.Heartbeat:Connect(function(dt)
		if not model.Parent or not zone.Parent then
			return
		end
		local now = os.clock()
		local position = zonePoint(zone, x, z, nil, height)
		local humanoid: Humanoid?, root: BasePart? = nil, nil
		local asleep = false -- a ir para o lugar de dormir (ou já lá)
		local alarm = zone:GetAttribute("Acordado")
		if alarm == nil then
			-- Zona sem ovos: comportamento antigo (ataca quem entrar na zona).
			humanoid, root = findTarget(zone, position, ceiling)
		else
			-- Alguém com ovos na zona (ou já a ser perseguido): persegue quem leva ovos.
			if alarm == true or hunting then
				humanoid, root = findCarrier(position, zone.Position, leash)
			end
			hunting = humanoid ~= nil
			if not hunting then
				-- Vida própria: muda de vez em quando entre dormir e passear.
				if now >= modeUntil then
					mode = if math.random() < sleepChance then "dormir" else "passear"
					modeUntil = now + (if mode == "dormir" then math.random(20, 60) else math.random(15, 40))
				end
				if mode == "passear" then
					-- A passear: ataca quem se aproximar demasiado (dentro da zona dele).
					local h, r = findTarget(zone, position, ceiling)
					if
						h
						and r
						and (r.Position - position).Magnitude <= aggroRange
						and not isSafe(r.Position)
					then
						humanoid, root = h, r
					end
				else
					asleep = true
				end
			end
		end
		local sleeping = false -- já está no lugar, a dormir

		-- Pousar / levantar voo. Se vir um jogador, levanta voo logo para atacar.
		if canLand then
			if asleep then
				airborne = false -- voadores pousam para dormir
			elseif humanoid then
				if not airborne then
					airborne = true
					stateUntil = now + randomRange(cfg.FlyTime, 8)
				end
			elseif now >= stateUntil then
				airborne = not airborne
				stateUntil = now
					+ (if airborne then randomRange(cfg.FlyTime, 8) else randomRange(cfg.GroundTime, 5))
				nextWander = 0 -- escolhe um ponto novo para o próximo voo/passeio
			end
		end
		-- No chão = pousado e já desceu até ao chão.
		local onGround = not flying or (not airborne and height <= groundHeight + 0.05)

		local goalX, goalZ, goalHeight, speed
		if humanoid and root then
			local targetLocal = toLocal(zone, root.Position)
			goalX, goalZ = targetLocal.X, targetLocal.Z
			speed = cfg.ChaseSpeed
			-- Voador desce até a altura do tronco do jogador para picar.
			goalHeight = if flying then math.max(targetLocal.Y - zone.Size.Y / 2, 1) else groundHeight

			local toTarget = root.Position - position
			local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
			local inReach = flat.Magnitude <= cfg.AttackRange
				and (not flying or math.abs(toTarget.Y) <= cfg.AttackRange)
			if inReach and now - lastAttack >= cfg.AttackCooldown then
				lastAttack = now
				biteUntil = now + ATTACK_TIME
				humanoid:TakeDamage(cfg.Damage)
				if attackSound then
					attackSound:Play()
				end
			end
		elseif asleep then
			-- Vai para o lugar à volta do ninho; quando chega, fica quieto.
			goalX, goalZ = homeXZ()
			goalHeight = groundHeight
			if Vector2.new(goalX - x, goalZ - z).Magnitude < 0.8 then
				speed = 0
				sleeping = true
			elseif flying and not onGround then
				speed = 0 -- primeiro desce
			else
				speed = if flying then groundSpeed else cfg.WanderSpeed
			end
		else
			local arrived = Vector2.new(wanderX - x, wanderZ - z).Magnitude < 1
			if arrived and not pausedHere then
				-- Chegou ao ponto: para um pouco, como um inseto "farejando".
				pausedHere = true
				pausedUntil = now + math.random() * wanderPause
			end
			if now >= nextWander or (arrived and now >= pausedUntil) then
				wanderX, wanderZ = randomXZ(zone, cfg.EdgeMargin)
				nextWander = now + math.random(3, 6)
				pausedHere = false
			end
			goalX, goalZ = wanderX, wanderZ
			goalHeight = if airborne then cruiseHeight else groundHeight
			if now < pausedUntil then
				speed = 0
			elseif flying and not airborne then
				-- A pousar: desce no sítio; depois de pousado, anda devagar.
				speed = if onGround then groundSpeed else 0
			else
				speed = cfg.WanderSpeed
			end
		end

		local flatDelta = Vector2.new(goalX - x, goalZ - z)
		local distance = flatDelta.Magnitude
		-- Não encosta no jogador: para quando já está no alcance do ataque.
		if humanoid and distance <= cfg.AttackRange * 0.6 then
			speed = 0
		end

		-- Vira aos poucos na direção do objetivo.
		local turnAmount = 0
		if sleeping then
			-- A dormir: vira-se devagar para o ninho (centro da zona).
			local wanted = math.atan2(-z, -x)
			local diff = (wanted - yaw + math.pi) % (math.pi * 2) - math.pi
			turnAmount = math.clamp(diff, -turnSpeed * 0.3 * dt, turnSpeed * 0.3 * dt)
			yaw += turnAmount
			speed = 0
		elseif distance > 0.05 then
			local wanted = math.atan2(flatDelta.Y, flatDelta.X)
			local diff = (wanted - yaw + math.pi) % (math.pi * 2) - math.pi
			turnAmount = math.clamp(diff, -turnSpeed * dt, turnSpeed * dt)
			yaw += turnAmount
			-- Curva fechada: anda mais devagar enquanto vira.
			speed *= math.clamp(1 - math.abs(diff) / math.pi, 0.2, 1)
		else
			speed = 0
		end

		-- Acelera/freia aos poucos e anda na direção em que está virado.
		currentSpeed += math.clamp(speed - currentSpeed, -acceleration * dt, acceleration * dt)
		local stepLen = math.min(currentSpeed * dt, distance)
		local half = zone.Size / 2
		-- Dentro da zona fica preso a ela; a perseguir (ou ainda a voltar de uma perseguição
		-- lá fora) anda livre, até voltar a entrar na zona.
		local limX, limZ = half.X - cfg.EdgeMargin, half.Z - cfg.EdgeMargin
		local function move(dist: number)
			local nx, nz = x + math.cos(yaw) * dist, z + math.sin(yaw) * dist
			local outside = math.abs(x) > limX or math.abs(z) > limZ
			if hunting or outside then
				x, z = nx, nz
			else
				x, z = math.clamp(nx, -limX, limX), math.clamp(nz, -limZ, limZ)
			end
		end
		move(stepLen)

		-- Salto: começa quando chega a hora (mais vezes a perseguir) e há espaço à frente.
		local hopT = (now - hopStart) / hopTime
		local inHop = hopT < 1
		if canHop and not asleep and not inHop and now >= nextHop and distance > cfg.AttackRange then
			hopStart, hopT, inHop = now, 0, true
			local wait = randomRange(cfg.HopInterval, 3) * (if humanoid then 0.5 else 1)
			nextHop = now + hopTime + wait
		end
		if inHop then
			move(hopDistance / hopTime * dt)
		end
		-- Coice das patas de trás: estica no arranque e volta a dobrar no ar.
		local kick = 0
		if inHop then
			kick = if hopT < 0.2 then hopT / 0.2 else math.max(0, 1 - (hopT - 0.2) / 0.3)
		end

		local speedRatio = math.clamp(currentSpeed / math.max(cfg.ChaseSpeed, 0.01), 0, 1)
		local offsetY, pitch, roll = 0, 0, 0
		local wobbleX, wobbleZ = 0, 0
		if flying then
			height += math.clamp(goalHeight - height, -verticalSpeed * dt, verticalSpeed * dt)
		end
		if not onGround then
			-- No ar: balança e treme como um mosquito. Perto do chão, treme menos.
			local airFactor = math.clamp((height - groundHeight) / 2, 0.2, 1)
			offsetY = math.sin(now * bobSpeed * math.pi * 2 + seed) * bobAmplitude * airFactor
			wobbleX = (math.sin(now * 3.1 + seed) + math.sin(now * 7.3 + seed * 2)) * 0.5 * jitter * airFactor
			wobbleZ = (math.sin(now * 4.7 + seed * 3) + math.sin(now * 6.1 + seed)) * 0.5 * jitter * airFactor
			offsetY += math.sin(now * 5.3 + seed * 4) * jitter * 0.5 * airFactor
			pitch = -tilt * speedRatio -- inclina para a frente quando voa rápido
			roll = -turnAmount / math.max(turnSpeed * dt, 1e-3) * tilt * 0.5 -- inclina nas curvas
		else
			-- Passada: o corpo sobe e desce e balança um pouco de lado a lado.
			stepPhase += currentSpeed * stepRate * dt * math.pi * 2
			offsetY = math.abs(math.sin(stepPhase)) * stepBob * speedRatio
			roll = math.sin(stepPhase) * tilt * speedRatio
			if inHop then
				-- Arco do salto; levanta o nariz ao sair e baixa ao aterrar.
				offsetY = 4 * hopHeight * hopT * (1 - hopT)
				pitch = 0.35 * (1 - 2 * hopT)
				roll = 0
			end
		end

		-- Ataque: avança o corpo e baixa a cabeça por um instante (0 -> 1 -> 0).
		local bite = if now < biteUntil then math.sin((biteUntil - now) / ATTACK_TIME * math.pi) else 0
		local forward = zone.CFrame:VectorToWorldSpace(Vector3.new(math.cos(yaw), 0, math.sin(yaw)))
		local basePos = zonePoint(zone, x + wobbleX, z + wobbleZ, nil, height + offsetY)
			+ forward * lunge * bite
		pitch -= lungePitch * bite
		model:PivotTo(CFrame.lookAt(basePos, basePos + forward) * CFrame.Angles(pitch, 0, roll) * facing)

		-- Zumbido só enquanto está no ar.
		if loopSound then
			if onGround and loopSound.IsPlaying then
				loopSound:Pause()
			elseif not onGround and not loopSound.IsPlaying then
				loopSound:Resume()
			end
		end

		if joints then
			local walkRef = if flying then groundSpeed else cfg.WanderSpeed
			local gait = if onGround and not inHop
				then math.clamp(currentSpeed / math.max(walkRef, 0.01), 0, 1)
				else 0
			local flap = if onGround then 0 else 1
			animateRig(
				joints,
				stepPhase,
				math.max(gait, bite),
				bite,
				now,
				legSwing,
				legLift,
				flap,
				wingFlap,
				wingRate,
				kick,
				if humanoid then 1 elseif sleeping then -0.6 else 0 -- a dormir: antenas lentas
			)
		end
	end)
end

-- Inseto "de estimação" (ex.: na fazenda): passeia devagar dentro de um retângulo, faz
-- pausas, mexe as patas ao andar e as antenas sempre. Não ataca ninguém.
-- area = centro do retângulo (no chão); halfX/halfZ = metade do tamanho; speed em studs/s.
-- Para sozinho quando o modelo é destruído.
function ZoneEnemy.pet(model: Model, area: CFrame, halfX: number, halfZ: number, speed: number)
	local joints = setupRig(model, CFrame.identity, nil)
	local start = area:ToObjectSpace(model:GetPivot())
	local x, z, y = start.X, start.Z, start.Y
	local yaw = math.random() * math.pi * 2
	local currentSpeed = 0
	local stepPhase = 0
	local goalX, goalZ = x, z
	local pauseUntil = os.clock() + math.random() * 3
	local turnSpeed = math.rad(160)
	local legSwing, legLift = math.rad(20), math.rad(15)
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not model.Parent then
			connection:Disconnect()
			return
		end
		-- 30 atualizações por segundo chegam e poupam o servidor (há muitos na fazenda).
		elapsed += dt
		if elapsed < 1 / 30 then
			return
		end
		dt, elapsed = elapsed, 0
		local now = os.clock()

		local delta = Vector2.new(goalX - x, goalZ - z)
		local target = 0
		if now >= pauseUntil then
			if delta.Magnitude < 0.5 then
				-- Chegou: pausa e escolhe outro ponto.
				pauseUntil = now + 1 + math.random() * 4
				goalX = (math.random() * 2 - 1) * halfX
				goalZ = (math.random() * 2 - 1) * halfZ
			else
				target = speed
				local wanted = math.atan2(delta.Y, delta.X)
				local diff = (wanted - yaw + math.pi) % (math.pi * 2) - math.pi
				yaw += math.clamp(diff, -turnSpeed * dt, turnSpeed * dt)
				target *= math.clamp(1 - math.abs(diff) / math.pi, 0.2, 1)
			end
		end
		currentSpeed += math.clamp(target - currentSpeed, -8 * dt, 8 * dt)
		local step = math.min(currentSpeed * dt, delta.Magnitude)
		x = math.clamp(x + math.cos(yaw) * step, -halfX, halfX)
		z = math.clamp(z + math.sin(yaw) * step, -halfZ, halfZ)
		stepPhase += currentSpeed * 0.6 * dt * math.pi * 2

		local gait = math.clamp(currentSpeed / math.max(speed, 0.01), 0, 1)
		local bob = math.abs(math.sin(stepPhase)) * 0.05 * gait
		local pos = area:PointToWorldSpace(Vector3.new(x, y + bob, z))
		local forward = area:VectorToWorldSpace(Vector3.new(math.cos(yaw), 0, math.sin(yaw)))
		model:PivotTo(CFrame.lookAt(pos, pos + forward))
		if joints then
			animateRig(joints, stepPhase, gait, 0, now, legSwing, legLift, 0, 0, 0, 0, -0.3)
		end
	end)
end

function ZoneEnemy.start()
	for _, cfg in Config.Enemies do
		-- Count > 1: vários inimigos iguais (só com modelos próprios), chamados Nome1, Nome2, ...
		local count = math.max(1, math.floor((cfg :: any).Count or 1))
		if count > 1 and not (cfg :: any).Build then
			warn(`[ZoneEnemy] "{cfg.Model}": Count só funciona com Build (modelo próprio); a criar 1`)
			count = 1
		end
		for i = 1, count do
			local name = if count > 1 then `{cfg.Model}{i}` else cfg.Model
			task.spawn(run, cfg :: any, name)
		end
	end
end

return ZoneEnemy
