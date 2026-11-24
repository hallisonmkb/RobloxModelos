--!strict
-- Fazenda pessoal: cada jogador recebe um lote na Part "ZonaFazenda" e lá aparecem os
-- insetos que já trouxe (guardados no save, em data.Fazenda).
-- Ciclo de cada inseto: Ovo (ChocaEm s) -> Bebé (CresceEm s) -> Adulto.
-- Quanto maior o nível do jogador, mais curtos são estes tempos (Config.Fazenda).
-- Rendimento por segundo: Adulto = Rende, Bebé = Rende * RendeBebe, Ovo = 0.
-- Entregar ovos dá XP (Dificuldade x XPPorDificuldade).
-- O tempo conta pelo relógio do servidor (os.time), por isso continua a passar com o
-- jogador fora do jogo; as moedas só são pagas enquanto está no jogo.
--
-- A área: um celeiro com fardos de palha numa ponta e lotes de terra lavrada com cerca,
-- portão, placa e um ninho de palha para cada inseto. Se a Part "ZonaFazenda" não existir,
-- é criada ao lado da ZonaPrincipal (ou do spawn).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Config"))
local Services = ServerScriptService:WaitForChild("Server"):WaitForChild("Services")
local DataService = require(Services:WaitForChild("DataService")) :: any
local CurrencyService = require(Services:WaitForChild("CurrencyService")) :: any
local ProgressionService = require(Services:WaitForChild("ProgressionService")) :: any
local Models = script.Parent:WaitForChild("Models")
local Ovo = require(Models:WaitForChild("Ovo")) :: any
local ZoneEnemy = require(script.Parent:WaitForChild("ZoneEnemy")) :: any

local Fazenda = {}

type Entry = { Tipo: string, Nasceu: number }
type Shown = { stage: string, model: Model?, label: TextLabel? }
type Plot = {
	index: number,
	center: CFrame, -- centro do lote, no topo da zona
	sizeX: number,
	sizeZ: number,
	folder: Folder,
	owner: Player?,
}

local zone: BasePart? = nil
local plots: { Plot } = {}
local plotOf: { [Player]: Plot } = {}
local shown: { [Player]: { [number]: Shown } } = {}
local pending: { [Player]: number } = {} -- moedas fracionárias ainda por pagar

local SLOT_COLUMNS = 4
local BARN_LENGTH = 34 -- espaço reservado ao celeiro numa ponta da fazenda

local WOOD = Color3.fromRGB(140, 100, 60)
local SOIL = Color3.fromRGB(110, 75, 45)
local STRAW = Color3.fromRGB(215, 180, 95)
local BARN_RED = Color3.fromRGB(150, 45, 35)
local ROOF = Color3.fromRGB(70, 55, 50)
local TRIM = Color3.fromRGB(235, 230, 220)

-- Fator de tempo pelo nível do jogador (1 = tempo normal; menor = mais rápido).
local function speedFactor(player: Player): number
	local level = ProgressionService.getLevel(player)
	local cfg = Config.Fazenda
	return math.max(cfg.FatorMinimo, 1 - cfg.ReducaoPorNivel * (level - 1))
end

local function stageOf(entry: Entry, now: number, factor: number): (string, number)
	local info = Config.Insetos[entry.Tipo]
	local hatch = info.ChocaEm * factor
	local grow = info.CresceEm * factor
	local age = now - entry.Nasceu
	if age < hatch then
		return "Ovo", hatch - age
	elseif age < hatch + grow then
		return "Bebe", hatch + grow - age
	end
	return "Adulto", 0
end

local function incomeOf(entry: Entry, now: number, factor: number): number
	local info = Config.Insetos[entry.Tipo]
	local stage = stageOf(entry, now, factor)
	if stage == "Adulto" then
		return info.Rende
	elseif stage == "Bebe" then
		return info.Rende * Config.Fazenda.RendeBebe
	end
	return 0
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	collide: boolean?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	part.CanCollide = collide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Posição de cada inseto dentro do lote (grelha de SLOT_COLUMNS colunas).
local function slotCFrame(plot: Plot, index: number): CFrame
	local rows = math.ceil(Config.Fazenda.MaxInsetos / SLOT_COLUMNS)
	local col = (index - 1) % SLOT_COLUMNS
	local row = (index - 1) // SLOT_COLUMNS
	local dx = (plot.sizeX - 2) / SLOT_COLUMNS
	local dz = (plot.sizeZ - 6) / rows
	local x = -(plot.sizeX - 2) / 2 + dx * (col + 0.5)
	local z = -(plot.sizeZ - 6) / 2 + 3 + dz * (row + 0.5)
	return plot.center * CFrame.new(x, 0.3, z) * CFrame.Angles(0, math.pi, 0)
end

local function makeLabel(parent: BasePart, height: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(190, 48)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 80
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	return label
end

-- Constrói o modelo de um inseto da fazenda no estado atual (ovo, bebé ou adulto).
local function buildShown(plot: Plot, index: number, entry: Entry, stage: string): Model?
	local info = Config.Insetos[entry.Tipo]
	local at = slotCFrame(plot, index)
	local model: Model
	if stage == "Ovo" then
		model = Ovo.build(`Ovo{entry.Tipo}`, at, {
			Altura = Config.Ovos.Altura * 0.6,
			Cor = info.CorOvo,
			CorPintas = info.CorPintas,
			Forma = info.FormaOvo,
		})
	else
		local builder = Models:FindFirstChild(info.Build)
		if not builder then
			warn(`[Fazenda] modelo "{info.Build}" não encontrado em Models`)
			return nil
		end
		model = (require(builder) :: any).build(`{entry.Tipo}{index}`, at)
		local scale = info.EscalaFazenda * (if stage == "Bebe" then 0.55 else 1)
		if scale ~= 1 then
			model:ScaleTo(scale)
			-- ScaleTo encolhe à volta do pivô: volta a pousar no chão.
			local box, size = model:GetBoundingBox()
			local bottom = box.Position.Y - size.Y / 2
			model:PivotTo(model:GetPivot() + Vector3.new(0, at.Position.Y - bottom, 0))
		end
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
		end
	end
	model.Parent = plot.folder
	if stage ~= "Ovo" then
		-- Bebés e adultos passeiam pelo lote (patas e antenas a mexer); os bebés mais devagar.
		local speed = if stage == "Bebe" then 1.2 else 2
		ZoneEnemy.pet(
			model,
			plot.center,
			math.max(plot.sizeX / 2 - 3, 1),
			math.max(plot.sizeZ / 2 - 4, 1),
			speed
		)
	end
	return model
end

-- Atualiza o que se vê no lote do jogador (só reconstrói quando muda de estado).
local function refresh(player: Player)
	local plot = plotOf[player]
	local data = DataService.get(player)
	if not plot or not data then
		return
	end
	local now = os.time()
	local factor = speedFactor(player)
	local list = shown[player] or {}
	shown[player] = list
	for index, entry in data.Fazenda :: { Entry } do
		local info = Config.Insetos[entry.Tipo]
		if info then
			local stage, remaining = stageOf(entry, now, factor)
			local current = list[index]
			if not current or current.stage ~= stage then
				if current and current.model then
					current.model:Destroy()
				end
				local model = buildShown(plot, index, entry, stage)
				local label = nil
				if model and model.PrimaryPart then
					local _, size = model:GetBoundingBox()
					label = makeLabel(model.PrimaryPart, size.Y + 1.5)
				end
				current = { stage = stage, model = model, label = label }
				list[index] = current
			end
			if current.label then
				local income = incomeOf(entry, now, factor)
				local text: string
				if stage == "Ovo" then
					text = `Ovos de {info.Nome}\nchocam em {formatTime(remaining)}`
				elseif stage == "Bebe" then
					text = `{info.Nome} bebé  +{income}/s\nadulto em {formatTime(remaining)}`
				else
					text = `{info.Nome}  +{income}/s`
				end
				current.label.Text = text
			end
		end
	end
end

local function clearShown(player: Player)
	for _, item in shown[player] or {} do
		if item.model then
			item.model:Destroy()
		end
	end
	shown[player] = nil
end

-- Lote: terra lavrada, cerca com postes e portão virado para o caminho, placa e ninhos de
-- palha onde ficam os ovos/insetos.
local function decoratePlot(plot: Plot)
	local f = plot.folder
	local hx, hz = plot.sizeX / 2, plot.sizeZ / 2
	block(
		f,
		"Terra",
		Vector3.new(plot.sizeX - 1, 0.3, plot.sizeZ - 1),
		plot.center * CFrame.new(0, 0.15, 0),
		SOIL,
		Enum.Material.Ground,
		false
	)
	-- Sulcos da terra lavrada.
	for i = 1, 6 do
		local x = -hx + 1 + (plot.sizeX - 2) * (i - 0.5) / 6
		block(
			f,
			"Sulco",
			Vector3.new(0.5, 0.15, plot.sizeZ - 3),
			plot.center * CFrame.new(x, 0.35, 0),
			SOIL:Lerp(Color3.new(0, 0, 0), 0.2),
			Enum.Material.Ground,
			false
		)
	end
	-- Cerca: dois varões e postes, com um portão aberto no lado da frente (-Z).
	local gate = 6
	local function rails(a: Vector3, b: Vector3)
		local len = (b - a).Magnitude
		if len < 0.5 then
			return
		end
		local mid = (a + b) / 2
		for _, y in { 1.2, 2.4 } do
			block(
				f,
				"Cerca",
				Vector3.new(0.3, 0.3, len),
				plot.center * CFrame.lookAt(mid + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0)),
				WOOD,
				Enum.Material.Wood
			)
		end
		local posts = math.max(1, math.floor(len / 4))
		for i = 0, posts do
			local p = a:Lerp(b, i / posts)
			block(
				f,
				"Poste",
				Vector3.new(0.5, 3, 0.5),
				plot.center * CFrame.new(p + Vector3.new(0, 1.5, 0)),
				WOOD,
				Enum.Material.Wood
			)
		end
	end
	rails(Vector3.new(-hx, 0, hz), Vector3.new(hx, 0, hz))
	rails(Vector3.new(-hx, 0, -hz), Vector3.new(-hx, 0, hz))
	rails(Vector3.new(hx, 0, -hz), Vector3.new(hx, 0, hz))
	rails(Vector3.new(-hx, 0, -hz), Vector3.new(-gate / 2, 0, -hz))
	rails(Vector3.new(gate / 2, 0, -hz), Vector3.new(hx, 0, -hz))
	block(
		f,
		"Placa",
		Vector3.new(0.5, 6, 0.5),
		plot.center * CFrame.new(gate / 2 + 1, 3, -hz - 0.5),
		WOOD,
		Enum.Material.Wood
	)
	-- Ninhos de palha para cada inseto.
	for index = 1, Config.Fazenda.MaxInsetos do
		local at = slotCFrame(plot, index)
		local nest = block(
			f,
			"NinhoPalha",
			Vector3.new(4.5, 0.4, 4.5),
			at * CFrame.new(0, -0.1, 0),
			STRAW,
			Enum.Material.Fabric,
			false
		)
		nest.Shape = Enum.PartType.Cylinder
		nest.Size = Vector3.new(0.4, 4.5, 4.5)
		nest.CFrame = at * CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.pi / 2)
	end
end

-- Celeiro vermelho com telhado, porta e fardos de palha.
local function buildBarn(parent: Instance, at: CFrame, width: number, depth: number)
	local height = 12
	local folder = Instance.new("Folder")
	folder.Name = "Celeiro"
	folder.Parent = parent
	local hw, hd = width / 2, depth / 2
	block(
		folder,
		"Chao",
		Vector3.new(width, 0.4, depth),
		at * CFrame.new(0, 0.2, 0),
		WOOD,
		Enum.Material.WoodPlanks
	)
	block(
		folder,
		"ParedeTras",
		Vector3.new(width, height, 1),
		at * CFrame.new(0, height / 2, hd),
		BARN_RED,
		Enum.Material.WoodPlanks
	)
	block(
		folder,
		"ParedeEsq",
		Vector3.new(1, height, depth),
		at * CFrame.new(-hw, height / 2, 0),
		BARN_RED,
		Enum.Material.WoodPlanks
	)
	block(
		folder,
		"ParedeDir",
		Vector3.new(1, height, depth),
		at * CFrame.new(hw, height / 2, 0),
		BARN_RED,
		Enum.Material.WoodPlanks
	)
	-- Frente com porta grande aberta no meio.
	local door = math.min(10, width * 0.4)
	local side = (width - door) / 2
	block(
		folder,
		"FrenteEsq",
		Vector3.new(side, height, 1),
		at * CFrame.new(-hw + side / 2, height / 2, -hd),
		BARN_RED,
		Enum.Material.WoodPlanks
	)
	block(
		folder,
		"FrenteDir",
		Vector3.new(side, height, 1),
		at * CFrame.new(hw - side / 2, height / 2, -hd),
		BARN_RED,
		Enum.Material.WoodPlanks
	)
	block(
		folder,
		"Verga",
		Vector3.new(door, 3, 1),
		at * CFrame.new(0, height - 1.5, -hd),
		BARN_RED,
		Enum.Material.WoodPlanks
	)
	block(
		folder,
		"Moldura",
		Vector3.new(door + 1, 0.6, 1.2),
		at * CFrame.new(0, height - 3, -hd),
		TRIM,
		Enum.Material.Wood
	)
	-- Telhado de duas águas (duas placas inclinadas).
	local roofRise = 6
	local slope = math.sqrt(hw * hw + roofRise * roofRise)
	local angle = math.atan2(roofRise, hw)
	for _, s in { -1, 1 } do
		block(
			folder,
			"Telhado",
			Vector3.new(slope + 1, 0.6, depth + 2),
			at * CFrame.new(s * hw / 2, height + roofRise / 2, 0) * CFrame.Angles(0, 0, -s * angle),
			ROOF,
			Enum.Material.Slate
		)
	end
	-- Empena da frente e de trás (triângulo aproximado com uma cunha de cada lado).
	for _, z in { -hd, hd } do
		for _, s in { -1, 1 } do
			local wedge = Instance.new("WedgePart")
			wedge.Name = "Empena"
			wedge.Anchored = true
			wedge.Color = BARN_RED
			wedge.Material = Enum.Material.WoodPlanks
			wedge.Size = Vector3.new(1, roofRise, hw)
			wedge.CFrame = at
				* CFrame.new(s * hw / 2, height + roofRise / 2, z)
				* CFrame.Angles(0, s * math.pi / 2, 0)
			wedge.Parent = folder
		end
	end
	-- Fardos de palha à porta.
	for i, offset in
		{
			Vector3.new(-hw - 3, 0, -hd + 2),
			Vector3.new(-hw - 3, 0, -hd + 6),
			Vector3.new(hw + 3, 0, -hd + 3),
		}
	do
		local bale = block(
			folder,
			`Fardo{i}`,
			Vector3.new(4, 3, 3),
			at * CFrame.new(offset + Vector3.new(0, 1.5, 0)),
			STRAW,
			Enum.Material.Fabric
		)
		bale.Shape = Enum.PartType.Cylinder
	end
end

local function setSign(plot: Plot, text: string)
	local post = plot.folder:FindFirstChild("Placa")
	if not post or not post:IsA("BasePart") then
		return
	end
	local gui = post:FindFirstChildOfClass("BillboardGui")
	local label: TextLabel
	if gui then
		label = gui:FindFirstChildOfClass("TextLabel") :: TextLabel
	else
		label = makeLabel(post, 4.5)
	end
	label.Text = text
end

local function signText(player: Player): string
	local level = ProgressionService.getLevel(player)
	local pct = math.floor((1 - speedFactor(player)) * 100 + 0.5)
	local plot = plotOf[player]
	local title = if plot
		then `Lote {plot.index}: {player.DisplayName}`
		else `Fazenda de {player.DisplayName}`
	return if pct > 0
		then `{title}\nNível {level}: crescem {pct}% mais rápido`
		else `{title}\nNível {level}`
end

-- Devolve o lote do jogador (ou nil).
function Fazenda.plotOf(player: Player): Plot?
	return plotOf[player]
end

-- Verdadeiro se a posição está dentro da ZonaFazenda.
function Fazenda.isInside(position: Vector3): boolean
	local z = zone
	if not z then
		return false
	end
	local p = z.CFrame:PointToObjectSpace(position)
	return math.abs(p.X) <= z.Size.X / 2 and math.abs(p.Z) <= z.Size.Z / 2 and p.Y < z.Size.Y / 2 + 25
end

-- Acrescenta ovos à fazenda do jogador e dá XP. Devolve (ok, mensagem para o jogador).
function Fazenda.addInsect(player: Player, tipo: string): (boolean, string)
	local info = Config.Insetos[tipo]
	local data = DataService.get(player)
	if not info or not data then
		return false, "Não foi possível guardar os ovos."
	end
	if #data.Fazenda >= Config.Fazenda.MaxInsetos then
		return false, `A tua fazenda está cheia ({Config.Fazenda.MaxInsetos} insetos).`
	end
	table.insert(data.Fazenda, { Tipo = tipo, Nasceu = os.time() })
	local xp = (info.Dificuldade or 1) * Config.Fazenda.XPPorDificuldade
	local levels = ProgressionService.addXP(player, xp)
	refresh(player)
	local hatch = formatTime(info.ChocaEm * speedFactor(player))
	local plot = plotOf[player]
	local where = if plot then ` no teu lote {plot.index} (feixe de luz)` else " na fazenda"
	local message = `Ovos de {info.Nome}{where}! Chocam em {hatch}. +{xp} XP`
	if levels > 0 then
		message ..= ` - subiste para o nível {ProgressionService.getLevel(player)}!`
	end
	return true, message
end

-- Feixe de luz alto no meio do lote do jogador, para o encontrar de longe.
local function addBeacon(plot: Plot, player: Player)
	local beam = block(
		plot.folder,
		"Farol",
		Vector3.new(1.2, 60, 1.2),
		plot.center * CFrame.new(0, 30, 0),
		Color3.fromRGB(255, 220, 90),
		Enum.Material.Neon,
		false
	)
	beam.Transparency = 0.55
	beam.CanQuery = false
	beam.CastShadow = false
	local label = makeLabel(beam, 31)
	label.Text = `Lote {plot.index}: {player.DisplayName}`
end

local function assignPlot(player: Player)
	if plotOf[player] then
		return
	end
	for _, plot in plots do
		if not plot.owner then
			plot.owner = player
			plotOf[player] = plot
			setSign(plot, signText(player))
			addBeacon(plot, player)
			player:SetAttribute("LoteFazenda", plot.index)
			refresh(player)
			return
		end
	end
	warn(`[Fazenda] sem lotes livres para {player.Name}; aumente Config.Fazenda.Lotes`)
end

local function releasePlot(player: Player)
	local plot = plotOf[player]
	clearShown(player)
	pending[player] = nil
	if plot then
		plot.owner = nil
		plotOf[player] = nil
		setSign(plot, `Lote {plot.index} livre`)
		local beacon = plot.folder:FindFirstChild("Farol")
		if beacon then
			beacon:Destroy()
		end
	end
end

-- Procura a ZonaFazenda em todo o Workspace (o tools/Mapa.luau põe-na na pasta "Zonas");
-- se não existir, cria-a ao lado da ZonaPrincipal ou do spawn.
local function findOrCreateZone(): BasePart
	local deadline = os.clock() + 5
	repeat
		local found = workspace:FindFirstChild(Config.Fazenda.Zone, true)
		if found and found:IsA("BasePart") then
			return found
		end
		task.wait(0.5)
	until os.clock() > deadline

	local size = Config.Fazenda.TamanhoAuto
	local anchor = workspace:FindFirstChild("ZonaPrincipal", true)
		or workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local cf: CFrame
	if anchor and anchor:IsA("BasePart") then
		local top = anchor.Position.Y + anchor.Size.Y / 2
		cf = CFrame.new(
			anchor.Position.X - anchor.Size.X / 2 - size.X / 2 - 2,
			top - size.Y / 2,
			anchor.Position.Z
		)
	else
		cf = CFrame.new(0, size.Y / 2, -150)
	end
	local part = Instance.new("Part")
	part.Name = Config.Fazenda.Zone
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = Color3.fromRGB(135, 105, 70)
	part.Material = Enum.Material.Ground
	part.Parent = workspace
	warn(
		`[Fazenda] não havia "{Config.Fazenda.Zone}": criada uma ao lado da zona principal. Corra o tools/Mapa.luau para a pôr no sítio certo.`
	)
	return part
end

local function startAsync()
	local z = findOrCreateZone()
	zone = z

	local folder = Instance.new("Folder")
	folder.Name = "Fazendas"
	folder.Parent = workspace

	-- Celeiro numa ponta (a mais afastada do centro do mapa) e lotes no resto.
	local alongX = z.Size.X >= z.Size.Z
	local length = if alongX then z.Size.X else z.Size.Z
	local width = if alongX then z.Size.Z else z.Size.X
	local axis = if alongX then Vector3.xAxis else Vector3.zAxis
	local outward = if z.CFrame:VectorToWorldSpace(axis):Dot(-z.Position) < 0 then 1 else -1
	local barnLen = math.min(BARN_LENGTH, length * 0.3)
	local function along(offset: number, y: number): CFrame
		local v = if alongX then Vector3.new(offset, y, 0) else Vector3.new(0, y, offset)
		return z.CFrame * CFrame.new(v)
	end
	local barnCenter = along(outward * (length / 2 - barnLen / 2), z.Size.Y / 2)
	local barnFacing = barnCenter
		* CFrame.Angles(0, if alongX then outward * math.pi / 2 else (if outward > 0 then math.pi else 0), 0)
	buildBarn(folder, barnFacing, math.min(width * 0.6, 26), barnLen - 6)

	-- Lotes em duas filas, com um caminho no meio; os portões dão para o caminho.
	local count = Config.Fazenda.Lotes
	local perRow = math.ceil(count / 2)
	local path = 12
	local plotDepth = (width - path) / 2 - 2
	local plotsLength = length - barnLen
	local start = -length / 2 + (if outward < 0 then barnLen else 0)
	local step = plotsLength / perRow
	local lateralAxis = if alongX then Vector3.zAxis else Vector3.xAxis
	for i = 1, count do
		local row = if i <= perRow then 1 else -1
		local col = ((i - 1) % perRow) + 1
		local longOffset = start + step * (col - 0.5)
		local local3 = (if alongX then Vector3.xAxis else Vector3.zAxis) * longOffset
			+ lateralAxis * row * (path / 2 + plotDepth / 2 + 1)
			+ Vector3.new(0, z.Size.Y / 2, 0)
		local pos = z.CFrame:PointToWorldSpace(local3)
		local towardPath = z.CFrame:VectorToWorldSpace(-lateralAxis * row)
		local plotFolder = Instance.new("Folder")
		plotFolder.Name = `Lote{i}`
		plotFolder.Parent = folder
		local plot: Plot = {
			index = i,
			-- -Z do lote (lado do portão) virado para o caminho.
			center = CFrame.lookAt(pos, pos + towardPath),
			sizeX = step - 2,
			sizeZ = plotDepth,
			folder = plotFolder,
			owner = nil,
		}
		local ok, err = pcall(decoratePlot, plot)
		if not ok then
			warn(`[Fazenda] erro a decorar o lote {i}: {err}`)
		end
		table.insert(plots, plot)
	end

	-- Os primeiros lotes a ser dados são os mais perto da entrada (zona principal/spawn).
	local entrance = workspace:FindFirstChild("ZonaPrincipal", true)
		or workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local entrancePos = if entrance and entrance:IsA("BasePart") then entrance.Position else Vector3.zero
	table.sort(plots, function(a, b)
		return (a.center.Position - entrancePos).Magnitude < (b.center.Position - entrancePos).Magnitude
	end)
	for i, plot in plots do
		plot.index = i
		plot.folder.Name = `Lote{i}`
		setSign(plot, `Lote {i} livre`)
	end
	print(`[Fazenda] {count} lotes e celeiro prontos em "{z.Name}"`)

	DataService.Loaded:Connect(function(player: Player)
		assignPlot(player)
	end)
	for _, player in Players:GetPlayers() do
		if DataService.get(player) then
			assignPlot(player)
		end
	end
	Players.PlayerRemoving:Connect(releasePlot)
	-- Ao subir de nível, a placa mostra a nova velocidade.
	ProgressionService.LevelUp:Connect(function(player: Player)
		local plot = plotOf[player]
		if plot then
			setSign(plot, signText(player))
		end
	end)

	-- A cada segundo: paga o rendimento e atualiza os letreiros/estados.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for player in plotOf do
				local ok, err = pcall(function()
					local data = DataService.get(player)
					if not data then
						return
					end
					local factor = speedFactor(player)
					local total = 0
					for _, entry in data.Fazenda :: { Entry } do
						if Config.Insetos[entry.Tipo] then
							total += incomeOf(entry, now, factor)
						end
					end
					local owed = (pending[player] or 0) + total
					local whole = math.floor(owed)
					if whole > 0 then
						CurrencyService.add(player, whole, true)
					end
					pending[player] = owed - whole
					refresh(player)
				end)
				if not ok then
					warn(`[Fazenda] erro no ciclo de {player.Name}: {err}`)
				end
			end
		end
	end)
end

function Fazenda.start()
	task.spawn(startAsync) -- não bloqueia o arranque dos outros módulos à espera da zona
end

return Fazenda
