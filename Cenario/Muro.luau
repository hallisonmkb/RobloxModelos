--!strict
-- Muro à volta da área de jogo, para o personagem não sair dela.
-- NÃO é sincronizado pelo Rojo: copiar tudo, colar na Command Bar do Studio (em modo de
-- edição, sem Play) e carregar em Enter. Depois: File -> Save to Roblox. Ctrl+Z desfaz.
--
-- Como funciona:
-- - Segue o contorno de todas as Parts cujo nome começa por "Zona" (zonas dos insetos e
--   ZonaPrincipal) e do SpawnLocation, alargadas pela MARGEM: o muro acompanha a forma das
--   zonas (L, degraus, etc.), não é só um retângulo.
-- - Se existir no Workspace um modelo chamado MODELO (ex.: o "StudWall"), usa cópias dele,
--   lado a lado, como blocos do muro. Senão, constrói um muro de tijolo com pilares.
-- - Por cima do muro há uma barreira invisível alta, para não se conseguir saltar por cima.
-- - Tudo fica num Model "MuroDaArea". Correr outra vez substitui o muro antigo.
-- IMPORTANTE: se o modelo veio da Toolbox, correr antes o tools/LimpezaScripts.luau.

local MODELO = "StudWall" -- nome do bloco de muro a copiar (nil = muro de tijolo)
local MARGEM = 4 -- distância (studs) entre as zonas e o muro
local BARREIRA = 60 -- altura da barreira invisível por cima do muro
-- Só para o muro de tijolo (quando não há MODELO):
local ALTURA = 12
local ESPESSURA = 2
local PILAR_A_CADA = 24
local COR = Color3.fromRGB(150, 85, 65)
local COR_PILAR = Color3.fromRGB(135, 75, 58)
local COR_TOPO = Color3.fromRGB(125, 122, 115)

local CHS = game:GetService("ChangeHistoryService")

-- 1) Área a cercar
local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
local groundY: number? = nil
local found = 0
local areas: { BasePart } = {}
for _, item in workspace:GetDescendants() do
	if item:IsA("BasePart") and (string.sub(item.Name, 1, 4) == "Zona" or item:IsA("SpawnLocation")) then
		found += 1
		table.insert(areas, item)
		local half = item.Size / 2
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = item.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, 0, half.Z * sz))
				minX, maxX = math.min(minX, corner.X), math.max(maxX, corner.X)
				minZ, maxZ = math.min(minZ, corner.Z), math.max(maxZ, corner.Z)
			end
		end
		local bottom = item.Position.Y - half.Y
		groundY = if groundY then math.min(groundY, bottom) else bottom
	end
end
if found == 0 then
	error("[Muro] não encontrei nenhuma Part 'Zona...' nem SpawnLocation no Workspace")
end
local base = workspace:FindFirstChild("Baseplate")
if base and base:IsA("BasePart") then
	groundY = base.Position.Y + base.Size.Y / 2
end
local y0 = groundY :: number

-- Grelha: cada célula está "dentro" se o centro dela cair numa zona (alargada pela MARGEM).
-- O muro vai nas arestas entre células dentro e fora, por isso segue o contorno das zonas.
local GRELHA = 2 -- tamanho da célula (studs): menor = contorno mais fiel
local gx0 = math.floor((minX - MARGEM - GRELHA) / GRELHA) * GRELHA
local gz0 = math.floor((minZ - MARGEM - GRELHA) / GRELHA) * GRELHA
local nx = math.ceil((maxX + MARGEM + GRELHA - gx0) / GRELHA)
local nz = math.ceil((maxZ + MARGEM + GRELHA - gz0) / GRELHA)

local function insideArea(p: Vector3): boolean
	for _, area in areas do
		local rel = area.CFrame:PointToObjectSpace(p)
		if math.abs(rel.X) <= area.Size.X / 2 + MARGEM and math.abs(rel.Z) <= area.Size.Z / 2 + MARGEM then
			return true
		end
	end
	return false
end

local inside: { { boolean } } = {}
for i = 0, nx + 1 do
	inside[i] = {}
	for k = 0, nz + 1 do
		local p = Vector3.new(gx0 + (i - 0.5) * GRELHA, y0, gz0 + (k - 0.5) * GRELHA)
		inside[i][k] = i >= 1 and i <= nx and k >= 1 and k <= nz and insideArea(p)
	end
end

-- 2) Preparação
local okRec, rec = pcall(function()
	return CHS:TryBeginRecording("Muro da área")
end)

local old = workspace:FindFirstChild("MuroDaArea")
if old then
	old:Destroy()
end
local model = Instance.new("Model")
model.Name = "MuroDaArea"

local template: Model? = nil
if MODELO then
	-- Procura primeiro no ServerStorage (sítio bom para guardar o original) e depois no Workspace.
	local t = game:GetService("ServerStorage"):FindFirstChild(MODELO, true)
		or workspace:FindFirstChild(MODELO, true)
	if t and t:IsA("Model") then
		template = t
	else
		warn(`[Muro] modelo "{MODELO}" não encontrado; a construir muro de tijolo`)
	end
end

-- Medidas do bloco do modelo: comprimento (eixo horizontal mais comprido), altura e espessura.
local blockLength, blockHeight, blockThick = 0, ALTURA, ESPESSURA
local boxToPivot = CFrame.identity -- do centro da caixa do modelo para o pivô dele
local lengthAlongX = true
if template then
	local boxCF, boxSize = template:GetBoundingBox()
	boxToPivot = boxCF:ToObjectSpace(template:GetPivot())
	lengthAlongX = boxSize.X >= boxSize.Z
	blockLength = math.max(boxSize.X, boxSize.Z)
	blockThick = math.min(boxSize.X, boxSize.Z)
	blockHeight = boxSize.Y
end

local function part(name: string, size: Vector3, cf: CFrame, material: Enum.Material, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Material = material
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Coloca uma cópia do modelo com o centro da base em "pos" e o comprimento ao longo de "dir".
local function placeBlock(pos: Vector3, dir: Vector3)
	local t = template :: Model
	local clone = t:Clone()
	-- Caixa desejada: centro à meia altura, eixo comprido da caixa ao longo do lado.
	local center = pos + Vector3.new(0, blockHeight / 2, 0)
	local look = CFrame.lookAt(center, center + dir)
	-- lookAt aponta -Z para "dir"; se o comprimento do modelo for no X, roda 90 graus.
	local box = if lengthAlongX then look * CFrame.Angles(0, math.pi / 2, 0) else look
	clone:PivotTo(box * boxToPivot)
	clone.Parent = model
end

local function pillar(x: number, z: number)
	local w = ESPESSURA + 1.4
	part(
		"Pilar",
		Vector3.new(w, ALTURA + 1.5, w),
		CFrame.new(x, y0 + (ALTURA + 1.5) / 2, z),
		Enum.Material.Brick,
		COR_PILAR
	)
	part(
		"TopoPilar",
		Vector3.new(w + 0.8, 0.8, w + 0.8),
		CFrame.new(x, y0 + ALTURA + 1.9, z),
		Enum.Material.Slate,
		COR_TOPO
	)
end

-- Um lado do muro, de "a" até "b" (no chão).
local function side(a: Vector3, b: Vector3)
	local dir = (b - a).Unit
	-- Estica um pouco nas pontas para os cantos ficarem fechados.
	a -= dir * blockThick / 2
	b += dir * blockThick / 2
	local length = (b - a).Magnitude

	if template then
		-- Blocos lado a lado (ligeiramente sobrepostos, para não haver frestas).
		local count = math.max(1, math.ceil(length / (blockLength * 0.98)))
		for i = 1, count do
			placeBlock(a:Lerp(b, (i - 0.5) / count), dir)
		end
	else
		local pieces = math.ceil(length / 2000) -- peças do Roblox têm no máximo 2048 studs
		for i = 1, pieces do
			local pa, pb = a:Lerp(b, (i - 1) / pieces), a:Lerp(b, i / pieces)
			local look = CFrame.lookAt((pa + pb) / 2, pb)
			local len = (pb - pa).Magnitude
			part(
				"Muro",
				Vector3.new(ESPESSURA, ALTURA, len),
				look + Vector3.new(0, ALTURA / 2, 0),
				Enum.Material.Brick,
				COR
			)
			part(
				"Remate",
				Vector3.new(ESPESSURA + 0.6, 0.8, len + 0.6),
				look + Vector3.new(0, ALTURA + 0.4, 0),
				Enum.Material.Slate,
				COR_TOPO
			)
		end
		local posts = math.max(1, math.floor(length / PILAR_A_CADA))
		for i = 0, posts do
			local p = a:Lerp(b, i / posts)
			pillar(p.X, p.Z)
		end
	end

	-- Barreira invisível por cima (dividida se o lado for muito comprido).
	local pieces = math.ceil(length / 2000)
	for i = 1, pieces do
		local pa, pb = a:Lerp(b, (i - 1) / pieces), a:Lerp(b, i / pieces)
		local look = CFrame.lookAt((pa + pb) / 2, pb)
		local barrier = part(
			"BarreiraInvisivel",
			Vector3.new(blockThick, BARREIRA, (pb - pa).Magnitude),
			look + Vector3.new(0, blockHeight + BARREIRA / 2, 0),
			Enum.Material.SmoothPlastic,
			COR
		)
		barrier.Transparency = 1
		barrier.CastShadow = false
	end
end

-- 3) Contorno: junta as arestas da fronteira em troços retos e põe muro em cada um
local segments = 0
-- Troços paralelos ao eixo X (linhas entre as filas k e k+1 da grelha)
for k = 0, nz do
	local z = gz0 + k * GRELHA
	local start: number? = nil
	for i = 1, nx + 1 do
		local edge = i <= nx and inside[i][k] ~= inside[i][k + 1]
		if edge and not start then
			start = i
		elseif not edge and start then
			side(Vector3.new(gx0 + (start - 1) * GRELHA, y0, z), Vector3.new(gx0 + (i - 1) * GRELHA, y0, z))
			segments += 1
			start = nil
		end
	end
end
-- Troços paralelos ao eixo Z (colunas entre i e i+1)
for i = 0, nx do
	local x = gx0 + i * GRELHA
	local start: number? = nil
	for k = 1, nz + 1 do
		local edge = k <= nz and inside[i][k] ~= inside[i + 1][k]
		if edge and not start then
			start = k
		elseif not edge and start then
			side(Vector3.new(x, y0, gz0 + (start - 1) * GRELHA), Vector3.new(x, y0, gz0 + (k - 1) * GRELHA))
			segments += 1
			start = nil
		end
	end
end
model.Parent = workspace

if okRec and rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
local kind = if template then `cópias de "{MODELO}"` else "tijolo"
print(
	`[Muro] pronto ({kind}): {segments} troços a seguir o contorno de {found} zonas/spawn. `
		.. "Guarde com File -> Save to Roblox."
)
