--!strict
-- Montanhas realistas à volta do mapa, feitas com o Terrain do Roblox.
-- NÃO é sincronizado pelo Rojo: copiar tudo, colar na Command Bar do Studio (em modo de
-- edição, sem Play) e carregar em Enter. Pode demorar até cerca de 1 minuto.
-- Depois: File -> Save to Roblox. Ctrl+Z desfaz tudo de uma vez.
--
-- Como funciona:
-- - Mede o mapa pela "Baseplate" e cria uma faixa de montanhas junto às bordas.
-- - Nunca cobre as Parts "Zona..." nem o SpawnLocation (deixa pelo menos 30 studs livres).
-- - Relva em baixo, terra e rocha nas encostas, rocha nas partes íngremes e neve nos picos.
-- - Correr outra vez substitui as montanhas antigas (mude SEMENTE para obter outras).

local SEMENTE = 7 -- número qualquer: muda a forma das montanhas
local ALTURA_MAX: number? = nil -- altura dos picos em studs (nil = automático)
local LARGURA_FAIXA: number? = nil -- largura da faixa de montanhas (nil = automático)
local NEVE = true -- neve nos picos mais altos

local RES = 4 -- resolução do Terrain (sempre 4)
local CHUNK = 128 -- tamanho de cada bloco processado de uma vez (studs)

local Terrain = workspace.Terrain
local CHS = game:GetService("ChangeHistoryService")

-- 1) Área do mapa
local center = Vector3.zero
local halfX, halfZ, groundY = 256, 256, 0
local base = workspace:FindFirstChild("Baseplate")
if base and base:IsA("BasePart") then
	center = base.Position
	halfX, halfZ = base.Size.X / 2, base.Size.Z / 2
	groundY = base.Position.Y + base.Size.Y / 2
else
	warn("[Montanhas] não há 'Baseplate'; a usar um mapa de 512 x 512 à volta do centro")
end

-- 2) Espaço livre obrigatório: zonas dos insetos e ponto de spawn
local clearX, clearZ = 0, 0
for _, item in workspace:GetDescendants() do
	if item:IsA("BasePart") and (string.sub(item.Name, 1, 4) == "Zona" or item:IsA("SpawnLocation")) then
		local rel = item.Position - center
		local reach = math.max(item.Size.X, item.Size.Z) / 2 + 30
		clearX = math.max(clearX, math.abs(rel.X) + reach)
		clearZ = math.max(clearZ, math.abs(rel.Z) + reach)
	end
end

local band = LARGURA_FAIXA or math.clamp(math.min(halfX, halfZ) * 0.25, 60, 260)
local innerX = math.max(halfX - band, clearX)
local innerZ = math.max(halfZ - band, clearZ)
-- Se as zonas estiverem muito perto da borda, as montanhas passam para fora da Baseplate.
local outerX = math.max(halfX, innerX + 60) + 40
local outerZ = math.max(halfZ, innerZ + 60) + 40
local bandX, bandZ = outerX - 40 - innerX, outerZ - 40 - innerZ
local hMax = ALTURA_MAX or math.clamp(math.min(bandX, bandZ) * 1.3, 80, 320)
local snowLine = hMax * 0.72

print(
	`[Montanhas] mapa {math.floor(halfX * 2)} x {math.floor(halfZ * 2)}, faixa ~{math.floor(band)} studs, `
		.. `picos até ~{math.floor(hMax)} studs. A esculpir...`
)

-- 3) Altura do terreno em cada ponto (x, z relativos ao centro do mapa)
local function bandDepth(x: number, z: number): number
	-- 0 na borda de dentro da faixa, 1 na borda da Baseplate (pode passar de 1 lá fora)
	local dx = (math.abs(x) - innerX) / bandX
	local dz = (math.abs(z) - innerZ) / bandZ
	return math.max(dx, dz)
end

local function heightAt(x: number, z: number): number
	local d = bandDepth(x, z) + math.noise(x / 90, z / 90, SEMENTE + 0.5) * 0.3 -- borda irregular
	if d <= 0 then
		return 0
	end
	local t = math.clamp(d / 0.75, 0, 1)
	local ramp = t * t * (3 - 2 * t) -- sobe suave a partir do vale
	local big = math.noise(x / 220, z / 220, SEMENTE) * 0.5 + 0.5
	local mid = math.noise(x / 80, z / 80, SEMENTE + 3.3) * 0.5 + 0.5
	local ridge = 1 - math.abs(math.noise(x / 140, z / 140, SEMENTE + 11.1)) * 2 -- cristas
	local small = math.noise(x / 22, z / 22, SEMENTE + 7.7)
	local h = hMax * (0.3 + 0.45 * big + 0.25 * math.max(ridge, 0)) * (0.8 + 0.35 * mid) + small * 5
	return math.max(ramp * h, 0)
end

local function surfaceMaterial(x: number, z: number, h: number): Enum.Material
	local slope = (
		math.abs(heightAt(x + RES, z) - heightAt(x - RES, z))
		+ math.abs(heightAt(x, z + RES) - heightAt(x, z - RES))
	) / (4 * RES)
	local wiggle = math.noise(x / 30, z / 30, SEMENTE + 20) * 12
	if NEVE and h > snowLine + wiggle then
		return if slope > 1.6 then Enum.Material.Rock else Enum.Material.Snow
	elseif slope > 1.0 then
		return Enum.Material.Rock
	elseif h > hMax * 0.45 + wiggle then
		return if math.noise(x / 18, z / 18, SEMENTE + 30) > 0
			then Enum.Material.Rock
			else Enum.Material.Ground
	elseif slope > 0.6 or h > hMax * 0.3 + wiggle then
		return Enum.Material.Ground
	end
	return Enum.Material.Grass
end

-- 4) Esculpir bloco a bloco
local okRec, rec = pcall(function()
	return CHS:TryBeginRecording("Montanhas")
end)

local yMin = math.floor((groundY - 4) / RES) * RES
local yMax = yMin + math.ceil((hMax * 1.4 + 20) / RES) * RES
local x0 = math.floor((center.X - outerX) / RES) * RES
local z0 = math.floor((center.Z - outerZ) / RES) * RES
local x1 = math.ceil((center.X + outerX) / RES) * RES
local z1 = math.ceil((center.Z + outerZ) / RES) * RES
local chunks = 0

for wx = x0, x1 - 1, CHUNK do
	for wz = z0, z1 - 1, CHUNK do
		-- Salta blocos totalmente no vale (longe da faixa), para não mexer no terreno de lá.
		local crossesX = wx < center.X and wx + CHUNK > center.X
		local crossesZ = wz < center.Z and wz + CHUNK > center.Z
		local farX = if crossesX
			then 0
			else math.max(math.abs(wx - center.X), math.abs(wx + CHUNK - center.X))
		local farZ = if crossesZ
			then 0
			else math.max(math.abs(wz - center.Z), math.abs(wz + CHUNK - center.Z))
		local inValley = farX < innerX - bandX * 0.35 and farZ < innerZ - bandZ * 0.35
		if not inValley then
			local region = Region3.new(
				Vector3.new(wx, yMin, wz),
				Vector3.new(math.min(wx + CHUNK, x1), yMax, math.min(wz + CHUNK, z1))
			):ExpandToGrid(RES)
			local materials, occupancies = Terrain:ReadVoxels(region, RES)
			local size = materials.Size
			for i = 1, size.X do
				local cx = region.CFrame.Position.X - region.Size.X / 2 + (i - 0.5) * RES - center.X
				for k = 1, size.Z do
					local cz = region.CFrame.Position.Z - region.Size.Z / 2 + (k - 0.5) * RES - center.Z
					-- Só reescreve colunas na faixa (assim também apaga montanhas de uma corrida anterior).
					if bandDepth(cx, cz) > -0.35 then
						local h = heightAt(cx, cz)
						local top = groundY + h
						local surface = if h > 0 then surfaceMaterial(cx, cz, h) else Enum.Material.Air
						for j = 1, size.Y do
							local y0 = yMin + (j - 1) * RES
							local occ = if h > 0 then math.clamp((top - y0) / RES, 0, 1) else 0
							occupancies[i][j][k] = occ
							if occ <= 0 then
								materials[i][j][k] = Enum.Material.Air
							elseif top - y0 > 8 then
								materials[i][j][k] = Enum.Material.Rock -- por dentro é rocha
							else
								materials[i][j][k] = surface
							end
						end
					end
				end
			end
			Terrain:WriteVoxels(region, RES, materials, occupancies)
			chunks += 1
			task.wait() -- deixa o Studio respirar entre blocos
		end
	end
end

-- 5) Névoa leve no horizonte, para as montanhas parecerem distantes (só se ainda não existir)
local Lighting = game:GetService("Lighting")
if not Lighting:FindFirstChildOfClass("Atmosphere") then
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(199, 205, 215)
	atmosphere.Decay = Color3.fromRGB(106, 120, 140)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
	print("[Montanhas] adicionada névoa leve (Lighting.Atmosphere)")
end

if okRec and rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
print(`[Montanhas] pronto: {chunks} blocos esculpidos. Guarde com File -> Save to Roblox.`)
