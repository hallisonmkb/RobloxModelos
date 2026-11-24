--!strict
-- Cria (ou recria) todas as zonas do jogo dos insetos, já com tamanho para vários jogadores.
-- NÃO é sincronizado pelo Rojo: copiar tudo, colar na Command Bar do Studio (em modo de
-- edição, sem Play) e carregar em Enter. Depois: correr tools/Muro.luau outra vez e
-- File -> Save to Roblox. Ctrl+Z desfaz.
--
-- ATENÇÃO: apaga as Parts "Zona..." e os SpawnLocation que existirem e cria-os de novo.
--
-- Disposição (da esquerda para a direita, ao longo do eixo X, no centro da Baseplate):
--   Fazenda | Principal (spawn) | Descanso1 | Pulgão | Descanso2 | Formiga | Descanso3 |
--   Mosquito | Descanso4 | Gafanhoto
-- Do mais fácil (perto do spawn) para o mais difícil (mais longe).

-- Nome, largura (X), profundidade (Z), cor e material de cada zona, pela ordem.
local ZONAS = {
	{ "ZonaFazenda", 220, 120, Color3.fromRGB(135, 105, 70), Enum.Material.Ground },
	{ "ZonaPrincipal", 80, 80, Color3.fromRGB(120, 175, 80), Enum.Material.Grass },
	{ "ZonaDescanso1", 30, 40, Color3.fromRGB(150, 195, 105), Enum.Material.LeafyGrass },
	{ "ZonaPulgao", 140, 140, Color3.fromRGB(85, 160, 65), Enum.Material.Grass },
	{ "ZonaDescanso2", 30, 40, Color3.fromRGB(150, 195, 105), Enum.Material.LeafyGrass },
	{ "ZonaFormiga", 140, 140, Color3.fromRGB(185, 155, 105), Enum.Material.Sand },
	{ "ZonaDescanso3", 30, 40, Color3.fromRGB(150, 195, 105), Enum.Material.LeafyGrass },
	{ "ZonaMosquito", 150, 150, Color3.fromRGB(85, 115, 75), Enum.Material.Mud },
	{ "ZonaDescanso4", 30, 40, Color3.fromRGB(150, 195, 105), Enum.Material.LeafyGrass },
	{ "ZonaGafanhoto", 160, 160, Color3.fromRGB(140, 170, 65), Enum.Material.Grass },
}
local ESPESSURA = 1 -- altura das Parts das zonas (ficam pousadas na Baseplate)

local CHS = game:GetService("ChangeHistoryService")

-- Chão e centro: a Baseplate, se existir.
local center = Vector3.zero
local groundY = 0
local base = workspace:FindFirstChild("Baseplate")
if base and base:IsA("BasePart") then
	center = base.Position
	groundY = base.Position.Y + base.Size.Y / 2
end

local okRec, rec = pcall(function()
	return CHS:TryBeginRecording("Mapa dos insetos")
end)

-- 1) Apaga as zonas e spawns antigos.
local removed = 0
for _, item in workspace:GetDescendants() do
	if
		item:IsA("BasePart")
		and item.Parent
		and (string.sub(item.Name, 1, 4) == "Zona" or item:IsA("SpawnLocation"))
	then
		item:Destroy()
		removed += 1
	end
end

-- 2) Cria as zonas lado a lado.
local folder = workspace:FindFirstChild("Zonas")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Zonas"
	folder.Parent = workspace
end

local total = 0
for _, z in ZONAS do
	total += z[2]
end
local x = center.X - total / 2
for _, z in ZONAS do
	local name, sizeX, sizeZ, color, material = z[1], z[2], z[3], z[4], z[5]
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = Vector3.new(sizeX, ESPESSURA, sizeZ)
	part.CFrame = CFrame.new(x + sizeX / 2, groundY + ESPESSURA / 2, center.Z)
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder
	x += sizeX

	if name == "ZonaPrincipal" then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "SpawnLocation"
		spawn.Anchored = true
		spawn.Size = Vector3.new(12, 1, 12)
		spawn.CFrame = part.CFrame * CFrame.new(0, ESPESSURA / 2 + 0.5, 0)
		spawn.Duration = 0 -- sem campo de força
		spawn.Parent = folder
	end
end

if okRec and rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
print(
	`[Mapa] pronto: {#ZONAS} zonas criadas ({math.floor(total)} studs de comprimento), {removed} peças antigas apagadas. `
		.. "Agora corra o tools/Muro.luau e guarde com File -> Save to Roblox."
)
