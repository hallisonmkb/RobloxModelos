--!strict
-- Ninhos onde ficam as posturas de ovos:
--   Folha       -> pulgão: uma folha grande deitada no chão, com a postura em cima.
--   Formigueiro -> formiga: monte de terra em cone (dá para subir a andar), coberto de
--                  palhinhas e com entradas; uma postura no topo e as outras junto às entradas.
--   Poca        -> mosquito: poça de água com juncos; a "jangada" de ovos flutua nela.
--   Toca        -> gafanhoto: terra remexida com o casulo de ovos meio enterrado.
-- Folha/Poca/Toca devolvem (Model, CFrame da base da postura).
-- Formigueiro devolve (Model, lista de CFrames das posturas).

local Parts = require(script.Parent:WaitForChild("Parts"))
local ellipsoid = Parts.ellipsoid
local segment = Parts.segment

local Ninhos = {}

local LEAF = Color3.fromRGB(70, 145, 45)
local VEIN = Color3.fromRGB(150, 195, 95)
local SOIL = Color3.fromRGB(150, 105, 60)
local SOIL_DARK = Color3.fromRGB(105, 70, 40)
local STRAW = Color3.fromRGB(200, 160, 90)
local HOLE = Color3.fromRGB(35, 22, 15)
local GRASS = Color3.fromRGB(80, 150, 50)
local MUD = Color3.fromRGB(95, 80, 55)
local WATER = Color3.fromRGB(70, 115, 125)
local PEBBLE = Color3.fromRGB(140, 135, 125)

local function deco(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
end

local function grassTuft(b: Parts.Builder, name: string, at: Vector3, rng: Random)
	for k = 1, 4 do
		local lean = Vector3.new(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5))
		local h = rng:NextNumber(1.2, 2.4)
		local blade = segment(b, `{name}_{k}`, at, at + Vector3.new(0, h, 0) + lean, 0.12, GRASS)
		deco(blade)
	end
end

-- Pulgão: uma folha grande (com nervuras) deitada no chão.
function Ninhos.Folha(origin: CFrame): (Model, CFrame)
	local b = Parts.newBuilder("NinhoFolha", origin)
	local leaf =
		Parts.longEllipsoid(b, "Folha", Vector3.new(0, 0.3, 6.5), Vector3.new(0, 0.3, -6.5), 7, 0.4, LEAF)
	leaf.Material = Enum.Material.Grass
	leaf.Anchored = true
	leaf.CanCollide = true
	local midrib = segment(b, "Nervura", Vector3.new(0, 0.52, 6.2), Vector3.new(0, 0.52, -6.2), 0.18, VEIN)
	deco(midrib)
	for i = -2, 2 do
		for _, side in { -1, 1 } do
			local z0 = i * 2.2
			local vein = segment(
				b,
				`NervuraLateral{i}_{side}`,
				Vector3.new(0, 0.5, z0),
				Vector3.new(side * 2.6, 0.48, z0 - 1.3),
				0.1,
				VEIN
			)
			deco(vein)
		end
	end
	local stem = segment(b, "Peciolo", Vector3.new(0, 0.3, 6.4), Vector3.new(0, 0.2, 8.5), 0.35, VEIN)
	deco(stem)
	return b.model, origin * CFrame.new(0, 0.5, 0)
end

-- Formiga: monte de terra em cone feito de cunhas à volta do centro (rampa contínua, sobe-se
-- a andar), com palhinhas, entradas e relva à volta. "count" = quantas posturas.
function Ninhos.Formigueiro(origin: CFrame, count: number): (Model, { CFrame })
	local b = Parts.newBuilder("Formigueiro", origin)
	local rng = Random.new(42)
	local radius, height = 8, 5.5
	local wedges = 28
	for i = 1, wedges do
		local a = (i / wedges) * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local wedge = Instance.new("WedgePart")
		wedge.Name = `Encosta{i}`
		wedge.Anchored = true
		wedge.Material = Enum.Material.Sand
		wedge.Color = SOIL:Lerp(SOIL_DARK, rng:NextNumber(0, 0.35))
		-- Lado alto da cunha no centro, rampa a descer para fora.
		wedge.Size = Vector3.new(2 * math.pi * radius / wedges * 1.08, height, radius)
		local mid = dir * radius / 2 + Vector3.new(0, height / 2, 0)
		wedge.CFrame = origin * CFrame.lookAt(mid, mid + dir)
		wedge.Parent = b.model
	end
	-- Palhinhas e pauzinhos espalhados pela encosta.
	for i = 1, 70 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.8, radius - 0.4)
		local y = height * (1 - r / radius) + 0.08
		local at = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
		local along =
			Vector3.new(-math.sin(a + rng:NextNumber(-1, 1)), 0, math.cos(a + rng:NextNumber(-1, 1)))
		local straw = segment(
			b,
			`Palha{i}`,
			at - along * 0.6,
			at + along * 0.6,
			0.09,
			STRAW:Lerp(SOIL_DARK, rng:NextNumber(0, 0.4))
		)
		deco(straw)
	end
	-- Entradas escuras na encosta.
	local entrances = { 0.4, 2.5, 4.4 }
	for i, a in entrances do
		local r = radius * 0.55
		local pos = Vector3.new(math.cos(a) * r, height * (1 - r / radius) + 0.1, math.sin(a) * r)
		local hole = ellipsoid(b, `Entrada{i}`, pos, Vector3.new(1.4, 0.25, 1.1), HOLE)
		deco(hole)
	end
	local top = ellipsoid(b, "Topo", Vector3.new(0, height - 0.1, 0), Vector3.new(2.6, 0.6, 2.6), SOIL)
	top.Material = Enum.Material.Sand
	deco(top)
	-- Relva à volta da base.
	for i = 1, 16 do
		local a = (i / 16) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local r = radius + rng:NextNumber(0.2, 1.5)
		grassTuft(b, `Relva{i}`, Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), rng)
	end

	-- Posturas: uma no topo e as outras à volta da base, em frente às entradas.
	local spots = { origin * CFrame.new(0, height - 0.2, 0) }
	for i = 2, math.max(count, 1) do
		local a = entrances[((i - 2) % #entrances) + 1] + (i - 2) // #entrances * 0.6
		local r = radius + 3
		table.insert(spots, origin * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r))
	end
	return b.model, spots
end

-- Mosquito: poça de água com margem de lama e juncos.
function Ninhos.Poca(origin: CFrame): (Model, CFrame)
	local b = Parts.newBuilder("NinhoPoca", origin)
	local rng = Random.new(9)
	local water = Parts.basePart(b, "Agua", WATER)
	water.Shape = Enum.PartType.Cylinder
	water.Size = Vector3.new(0.2, 10, 10)
	water.CFrame = origin * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2)
	water.Material = Enum.Material.Glass
	water.Transparency = 0.25
	water.Reflectance = 0.3
	deco(water)
	for i = 1, 14 do
		local a = (i / 14) * math.pi * 2
		local mud = ellipsoid(
			b,
			`Lama{i}`,
			Vector3.new(math.cos(a) * 5.1, 0.12, math.sin(a) * 5.1),
			Vector3.new(rng:NextNumber(2, 3), 0.35, rng:NextNumber(1.2, 1.8)),
			MUD
		)
		mud.CFrame = origin * CFrame.new(math.cos(a) * 5.1, 0.12, math.sin(a) * 5.1) * CFrame.Angles(0, -a, 0)
		mud.Material = Enum.Material.Mud
		deco(mud)
	end
	for i = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local at = Vector3.new(math.cos(a) * 5.4, 0, math.sin(a) * 5.4)
		for k = 1, 3 do
			local top = at
				+ Vector3.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(3, 4.5), rng:NextNumber(-0.4, 0.4))
			local reed = segment(b, `Junco{i}_{k}`, at, top, 0.14, Color3.fromRGB(95, 125, 55))
			deco(reed)
		end
	end
	return b.model, origin * CFrame.new(0, 0.2, 0)
end

-- Gafanhoto: terra remexida, pedrinhas e relva; o casulo fica meio enterrado.
function Ninhos.Toca(origin: CFrame): (Model, CFrame)
	local b = Parts.newBuilder("NinhoToca", origin)
	local rng = Random.new(13)
	local dirt = ellipsoid(b, "Terra", Vector3.new(0, 0.2, 0), Vector3.new(8, 0.9, 8), SOIL_DARK)
	dirt.Material = Enum.Material.Ground
	deco(dirt)
	for i = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(3.5, 4.5)
		local s = rng:NextNumber(0.5, 1)
		local stone = ellipsoid(
			b,
			`Pedra{i}`,
			Vector3.new(math.cos(a) * r, s * 0.3, math.sin(a) * r),
			Vector3.new(s, s * 0.7, s),
			PEBBLE
		)
		stone.Material = Enum.Material.Slate
		deco(stone)
	end
	for i = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		grassTuft(b, `Relva{i}`, Vector3.new(math.cos(a) * 4.8, 0, math.sin(a) * 4.8), rng)
	end
	-- Base da postura abaixo do chão: o casulo fica meio enterrado.
	return b.model, origin * CFrame.new(0, -0.6, 0)
end

return Ninhos
