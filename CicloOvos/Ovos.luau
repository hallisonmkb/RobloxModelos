--!strict
-- Ovos dos insetos (posturas):
-- - Em cada zona de Config.Insetos há OvosNaZona posturas, cada uma no seu ninho (folha,
--   poça, toca) ou, na formiga, no formigueiro do centro (uma no topo, as outras na base).
--   Os insetos da zona dormem à volta do centro (atributo Acordado na Part da zona).
-- - Quem segurar E numa postura pega nela: fica nos braços e os insetos ACORDAM.
-- - A zona fica acordada enquanto houver alguém lá dentro com uma postura dela. Quando o
--   último sai, os insetos voltam a dormir.
-- - Cada sítio vazio recebe uma postura nova Config.Ovos.VoltaEm segundos depois de a
--   anterior sair da zona (ou ser entregue).
-- - Se o jogador morrer (ou sair do jogo) ainda dentro da zona, a postura volta logo ao
--   sítio; fora da zona, perde-se.
-- - Ao entrar na ZonaFazenda, a postura vai para a fazenda do jogador (módulo Fazenda).
-- Tudo é decidido no servidor; o cliente só vê os atributos "Estado" e "Aviso".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Config"))
local Models = script.Parent:WaitForChild("Models")
local Ovo = require(Models:WaitForChild("Ovo")) :: any
local Ninhos = require(Models:WaitForChild("Ninhos")) :: any
local Fazenda = require(script.Parent:WaitForChild("Fazenda")) :: any
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Ovos = {}

local FIND_TIMEOUT = 15

type ZoneState = {
	tipo: string,
	info: any,
	zone: BasePart,
	folder: Folder,
	spots: { Spot },
}
type Spot = {
	zone: ZoneState,
	index: number,
	base: CFrame, -- onde fica a base da postura
	egg: Model?,
	respawnAt: number?,
}
type Carry = {
	spot: Spot,
	model: Model,
	inZone: boolean, -- ainda não saiu da zona de onde veio
	warnedFull: boolean,
	healthConn: RBXScriptConnection?, -- deteta quando é picado
}

local zones: { [string]: ZoneState } = {}
local carrying: { [Player]: Carry } = {}

-- Mensagem curta para o jogador (o cliente mostra-a no ecrã).
local function notice(player: Player, text: string)
	player:SetAttribute("Aviso", text)
	player:SetAttribute("AvisoId", ((player:GetAttribute("AvisoId") :: number?) or 0) + 1)
end

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

local function isInZone(zone: BasePart, position: Vector3): boolean
	local p = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Z) <= half.Z and p.Y > -half.Y - 2 and p.Y < half.Y + 40
end

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Acordada enquanto houver lá dentro alguém com ovos nas mãos (de qualquer inseto: voltar
-- a entrar com ovos também acorda os insetos).
local function refreshAwake(state: ZoneState)
	local awake = false
	for player in carrying do
		local root = aliveRoot(player)
		if root and isInZone(state.zone, root.Position) then
			awake = true
			break
		end
	end
	if state.zone:GetAttribute("Acordado") ~= awake then
		state.zone:SetAttribute("Acordado", awake)
	end
end

local pickUp: (Player, Model, Spot) -> ()

-- Posturas caídas no chão (soltas pelo jogador ou ao ser picado): voltam ao ninho se
-- ninguém as apanhar a tempo.
local loose: { [Model]: { spot: Spot, expiresAt: number } } = {}

local function addPrompt(egg: Model, spot: Spot)
	local info = spot.zone.info
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pegar ovos"
	prompt.ObjectText = `Ovos de {info.Nome}`
	prompt.HoldDuration = Config.Ovos.SegurarPor
	prompt.MaxActivationDistance = Config.Ovos.Altura * 2.5
	prompt.RequiresLineOfSight = false
	prompt.Parent = egg.PrimaryPart
	prompt.Triggered:Connect(function(player: Player)
		local ok, err = pcall(pickUp, player, egg, spot)
		if not ok then
			warn(`[Ovos] erro ao pegar ovos: {err}`)
		end
	end)
end

local function spawnEgg(spot: Spot)
	if spot.egg then
		return
	end
	local info = spot.zone.info
	local egg = Ovo.build(`Ovo{spot.zone.tipo}{spot.index}`, spot.base, {
		Altura = Config.Ovos.Altura,
		Cor = info.CorOvo,
		CorPintas = info.CorPintas,
		Forma = info.FormaOvo,
	}) :: Model
	addPrompt(egg, spot)
	egg.Parent = spot.zone.folder
	spot.egg = egg
	spot.respawnAt = nil
end

local function scheduleRespawn(spot: Spot)
	if not spot.egg and not spot.respawnAt then
		spot.respawnAt = os.clock() + Config.Ovos.VoltaEm
	end
end

local function clearCarrying(player: Player)
	local carry = carrying[player]
	if carry and carry.healthConn then
		carry.healthConn:Disconnect()
	end
	carrying[player] = nil
	if player.Parent then
		player:SetAttribute("CarregandoOvo", nil)
		player:SetAttribute("Estado", nil)
		player:SetAttribute("Acao", nil)
	end
end

local drop: (Player, string) -> ()

pickUp = function(player: Player, egg: Model, spot: Spot)
	if spot.egg ~= egg and not loose[egg] then
		return -- já foi apanhada por outra pessoa
	end
	if carrying[player] then
		notice(player, "Já estás a levar ovos!")
		return
	end
	local root = aliveRoot(player)
	if not root then
		return
	end

	if spot.egg == egg then
		spot.egg = nil
	else
		loose[egg] = nil
	end
	local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt:Destroy()
	end
	-- A postura passa a fazer parte do personagem: solta, sem peso e sem colisão.
	for _, item in egg:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = false
			item.Massless = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
	local _, size = egg:GetBoundingBox()
	egg:PivotTo(root.CFrame * CFrame.new(0, -2.6, -(size.Z / 2 + 0.9)))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = egg.PrimaryPart
	weld.Parent = egg.PrimaryPart
	egg.Parent = player.Character

	local info = spot.zone.info
	-- Só acorda os insetos se a postura for apanhada dentro da zona deles.
	local inZone = isInZone(spot.zone.zone, root.Position)
	local carry: Carry = { spot = spot, model = egg, inZone = inZone, warnedFull = false, healthConn = nil }
	carrying[player] = carry
	-- Se for picado (perder vida), deixa cair os ovos.
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and Config.Ovos.CaiAoSerPicado then
		local last = humanoid.Health
		carry.healthConn = humanoid.HealthChanged:Connect(function(health)
			if health < last and health > 0 and carrying[player] == carry then
				task.defer(drop, player, "picado")
			end
			last = health
		end)
	end
	player:SetAttribute("CarregandoOvo", info.Nome)
	local lot = player:GetAttribute("LoteFazenda")
	local destination = if type(lot) == "number"
		then `o teu lote {lot} da fazenda (feixe de luz)`
		else "a fazenda"
	player:SetAttribute("Estado", `A levar ovos de {info.Nome} - leva-os para {destination}!`)
	player:SetAttribute("Acao", "Soltar ovos")
	refreshAwake(spot.zone)
	if inZone then
		notice(player, `Pegaste ovos de {info.Nome}! Os insetos acordaram - leva-os para a fazenda!`)
	end
end

-- Pousa a postura no chão à frente do jogador (soltar com G ou ao ser picado).
drop = function(player: Player, reason: string)
	local carry = carrying[player]
	local root = aliveRoot(player)
	if not carry or not root then
		return
	end
	clearCarrying(player)
	local egg = carry.model
	local weld = egg.PrimaryPart and egg.PrimaryPart:FindFirstChildOfClass("WeldConstraint")
	if weld then
		weld:Destroy()
	end
	for _, item in egg:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.Massless = false
		end
	end
	-- Procura o chão à frente do jogador (ignorando o personagem e a própria postura).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance, egg }
	local ahead = root.Position + root.CFrame.LookVector * 3
	local hit = workspace:Raycast(ahead + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params)
	local ground = if hit then hit.Position else ahead - Vector3.new(0, 3, 0)
	local _, yaw, _ = root.CFrame:ToOrientation()
	egg:PivotTo(CFrame.new(ground) * CFrame.Angles(0, yaw, 0))
	egg.Parent = carry.spot.zone.folder
	addPrompt(egg, carry.spot)
	loose[egg] = { spot = carry.spot, expiresAt = os.clock() + Config.Ovos.CaidoVoltaEm }
	refreshAwake(carry.spot.zone)
	notice(
		player,
		if reason == "picado"
			then "Foste picado e deixaste cair os ovos! Apanha-os de novo."
			else "Soltaste os ovos."
	)
end

-- O jogador deixou de levar a postura sem a entregar (morreu ou saiu do jogo).
local function lose(player: Player, carry: Carry)
	clearCarrying(player)
	if carry.model.Parent then
		carry.model:Destroy()
	end
	local spot = carry.spot
	if carry.inZone then
		-- Ainda dentro da zona: a postura volta já ao sítio.
		spawnEgg(spot)
		if player.Parent then
			notice(player, "Os ovos voltaram para o ninho!")
		end
	else
		scheduleRespawn(spot)
		if player.Parent then
			notice(player, "Perdeste os ovos!")
		end
	end
	refreshAwake(spot.zone)
end

local function update()
	for player, carry in carrying do
		local root = aliveRoot(player)
		if not root or not carry.model.Parent then
			lose(player, carry)
			continue
		end
		local spot = carry.spot
		if carry.inZone and not isInZone(spot.zone.zone, root.Position) then
			-- Saiu da zona: o sítio prepara uma postura nova.
			carry.inZone = false
			scheduleRespawn(spot)
			refreshAwake(spot.zone)
		end
		if Fazenda.isInside(root.Position) then
			local ok, message = Fazenda.addInsect(player, spot.zone.tipo)
			if ok then
				clearCarrying(player)
				carry.model:Destroy()
				scheduleRespawn(spot)
				refreshAwake(spot.zone)
				notice(player, message)
			elseif not carry.warnedFull then
				carry.warnedFull = true
				notice(player, message)
			end
		else
			carry.warnedFull = false
		end
	end

	local now = os.clock()
	-- Posturas caídas há demasiado tempo voltam para o ninho.
	for egg, info in loose do
		if now >= info.expiresAt then
			loose[egg] = nil
			egg:Destroy()
			info.spot.respawnAt = nil
			spawnEgg(info.spot)
		end
	end
	for _, state in zones do
		refreshAwake(state) -- acorda/adormece conforme quem está lá dentro com ovos
		for _, spot in state.spots do
			if not spot.egg and spot.respawnAt and now >= spot.respawnAt then
				spawnEgg(spot)
			end
		end
	end
end

local function setupZone(tipo: string, info: any)
	local zone = findInWorkspace(info.Zone)
	if not zone or not zone:IsA("BasePart") then
		warn(`[Ovos] zona "{info.Zone}" não encontrada; os ovos de {info.Nome} não foram criados`)
		return
	end
	local count = math.max(1, info.OvosNaZona or 1)
	local folder = Instance.new("Folder")
	folder.Name = `Ninhos{tipo}`
	folder.Parent = workspace
	local top = zone.CFrame * CFrame.new(0, zone.Size.Y / 2, 0)

	local bases: { CFrame } = {}
	local sleepRadius = 4
	if info.Ninho == "Formigueiro" then
		-- Formigueiro no centro; as posturas são do próprio formigueiro.
		local mound, spots = Ninhos.Formigueiro(top, count)
		mound.Parent = folder
		bases = spots
		sleepRadius = 10
	else
		-- Posturas em círculo à volta do centro, cada uma com o seu ninho; os insetos dormem
		-- no meio, entre elas.
		local builder = Ninhos[info.Ninho] or Ninhos.Toca
		local ring = math.clamp(math.min(zone.Size.X, zone.Size.Z) * 0.3, 10, 40)
		for i = 1, count do
			local a = (i / count) * math.pi * 2
			local at = top * CFrame.new(math.cos(a) * ring, 0, math.sin(a) * ring) * CFrame.Angles(0, -a, 0)
			local nest, base = builder(at)
			nest.Parent = folder
			table.insert(bases, base)
		end
	end

	zone:SetAttribute("NinhoRaio", sleepRadius)
	zone:SetAttribute("Acordado", false) -- os insetos começam a dormir
	local state: ZoneState = { tipo = tipo, info = info, zone = zone, folder = folder, spots = {} }
	for i, base in bases do
		local spot: Spot = { zone = state, index = i, base = base, egg = nil, respawnAt = nil }
		table.insert(state.spots, spot)
		spawnEgg(spot)
	end
	zones[tipo] = state
	print(`[Ovos] {#bases} posturas de {info.Nome} prontas em "{info.Zone}"`)
end

function Ovos.start()
	for tipo, info in Config.Insetos do
		task.spawn(function()
			local ok, err = pcall(setupZone, tipo, info)
			if not ok then
				warn(`[Ovos] erro ao preparar {tipo}: {err}`)
			end
		end)
	end

	-- Botão/tecla de ação do HUD (G): soltar os ovos.
	Remotes.onServer("Acao", 3, function(player: Player)
		if carrying[player] then
			drop(player, "soltou")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local carry = carrying[player]
		if carry then
			lose(player, carry)
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		local ok, err = pcall(update)
		if not ok then
			warn(`[Ovos] erro: {err}`)
		end
	end)
end

return Ovos
