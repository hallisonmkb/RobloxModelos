--!strict
-- Peças básicas para montar modelos próprios em código (insetos, etc.).
-- Usado pelos ficheiros desta pasta (Pulgao, MosquitoTigre, Formiga...). Não é um modelo.
--
-- Convenção: coordenadas do modelo em studs, virado para -Z (a frente), +X à direita,
-- chão em Y = 0. "origin" é onde o modelo nasce no mundo.

local Parts = {}

export type Builder = {
	model: Model,
	origin: CFrame,
}

function Parts.newBuilder(name: string, origin: CFrame): Builder
	local model = Instance.new("Model")
	model.Name = name
	return { model = model, origin = origin }
end

function Parts.basePart(b: Builder, name: string, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = 0.05
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = b.model
	return part
end

local function sphereMesh(part: Part)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
end

-- Elipsoide alinhado com os eixos do modelo.
function Parts.ellipsoid(b: Builder, name: string, center: Vector3, size: Vector3, color: Color3): Part
	local part = Parts.basePart(b, name, color)
	part.Size = size
	part.CFrame = b.origin * CFrame.new(center)
	sphereMesh(part)
	return part
end

-- Elipsoide comprido de "a" até "c" (abdómen, asas). width = largura, height = espessura.
function Parts.longEllipsoid(
	b: Builder,
	name: string,
	a: Vector3,
	c: Vector3,
	width: number,
	height: number,
	color: Color3
): Part
	local part = Parts.basePart(b, name, color)
	part.Size = Vector3.new(width, height, (c - a).Magnitude)
	part.CFrame = b.origin * CFrame.lookAt((a + c) / 2, c)
	sphereMesh(part)
	return part
end

-- Segmento cilíndrico de "a" até "c" (patas, antenas, tromba).
function Parts.segment(
	b: Builder,
	name: string,
	a: Vector3,
	c: Vector3,
	thickness: number,
	color: Color3
): Part
	local part = Parts.basePart(b, name, color)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new((c - a).Magnitude, thickness, thickness)
	-- O cilindro do Roblox é comprido no eixo X: roda para o X apontar de "a" para "c".
	part.CFrame = b.origin * CFrame.lookAt((a + c) / 2, c) * CFrame.Angles(0, math.pi / 2, 0)
	return part
end

-- Junta Motor6D com o ponto de rotação em "point" (coordenadas do modelo).
-- O nome da junta é o da peça que mexe (Part1), que é o que o ZoneEnemy reconhece.
function Parts.joint(b: Builder, part0: BasePart, part1: BasePart, point: Vector3)
	local world = b.origin * CFrame.new(point)
	local motor = Instance.new("Motor6D")
	motor.Name = part1.Name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = part0.CFrame:Inverse() * world
	motor.C1 = part1.CFrame:Inverse() * world
	motor.Parent = part0
end

-- Define a "frente" do modelo: posição "center" (coordenadas do modelo), virada para -Z.
-- Atenção: com PrimaryPart, o Roblox ignora model.WorldPivot e usa o pivô da peça
-- principal, por isso o ajuste é feito no PivotOffset dela.
function Parts.setPivot(b: Builder, center: Vector3)
	local pivot = b.origin * CFrame.new(center)
	local primary = b.model.PrimaryPart
	if primary then
		primary.PivotOffset = primary.CFrame:ToObjectSpace(pivot)
	else
		b.model.WorldPivot = pivot
	end
end

-- Espelha um ponto do lado direito (+X) para o lado "side" (+1 direito, -1 esquerdo).
function Parts.mirror(v: Vector3, side: number): Vector3
	return Vector3.new(v.X * side, v.Y, v.Z)
end

return Parts
