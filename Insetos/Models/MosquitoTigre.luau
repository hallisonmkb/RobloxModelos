--!strict
-- Modelo próprio do mosquito-tigre (Aedes albopictus), montado em código a partir de peças.
-- Baseado em fotos reais: corpo preto com uma risca branca no dorso do tórax, manchas
-- brancas dos lados do tórax e do abdómen, patas compridas pretas com faixas brancas (a
-- ponta das patas de trás é branca), tromba comprida, palpos com ponta branca, olhos
-- grandes e asas translúcidas.
--
-- Os nomes seguem o padrão que o ZoneEnemy anima:
--   <Left|Right><Front|Mid|Back>Leg1/2/3 = patas, <Left|Right>Antennae1/2 = antenas,
--   LeftWing/RightWing = asas (batem enquanto voa).
-- Todas as peças estão ligadas por Motor6D à raiz ("Thorax").
--
-- Medidas em studs, virado para -Z (a frente), +X à direita e o chão em Y = 0.

local MosquitoTigre = {}

local BLACK = Color3.fromRGB(22, 22, 26)
local BLACK_SHINY = Color3.fromRGB(35, 35, 42)
local WHITE = Color3.fromRGB(240, 240, 235)
local EYE = Color3.fromRGB(30, 30, 38)
local WING = Color3.fromRGB(175, 178, 190)
local ANTENNA = Color3.fromRGB(60, 60, 65)

local Parts = require(script.Parent:WaitForChild("Parts"))
type Builder = Parts.Builder
local ellipsoid = Parts.ellipsoid
local longEllipsoid = Parts.longEllipsoid
local segment = Parts.segment
local joint = Parts.joint
local mirror = Parts.mirror

local function bands(
	b: Builder,
	owner: BasePart,
	baseName: string,
	a: Vector3,
	c: Vector3,
	thickness: number,
	at: { number }
)
	for i, t in at do
		local p0 = a:Lerp(c, t)
		local p1 = a:Lerp(c, math.min(t + 0.07, 1))
		local band = segment(b, `{baseName}Faixa{i}`, p0, p1, thickness * 1.3, WHITE)
		joint(b, owner, band, p0)
	end
end

-- Pontos de cada pata: anca, joelho (alto), tornozelo e ponta (no chão).
-- X positivo = lado direito; o lado esquerdo é espelhado.
local LEGS = {
	Front = {
		hip = Vector3.new(0.2, 1.35, -0.25),
		knee = Vector3.new(0.7, 1.95, -0.85),
		ankle = Vector3.new(1.1, 0.55, -1.6),
		toe = Vector3.new(1.25, 0.02, -2.35),
	},
	Mid = {
		hip = Vector3.new(0.25, 1.3, 0.05),
		knee = Vector3.new(0.95, 2.0, 0.0),
		ankle = Vector3.new(1.6, 0.55, 0.1),
		toe = Vector3.new(2.1, 0.02, 0.2),
	},
	Back = {
		hip = Vector3.new(0.22, 1.3, 0.3),
		knee = Vector3.new(0.8, 2.1, 0.85),
		ankle = Vector3.new(1.3, 0.6, 1.8),
		toe = Vector3.new(1.6, 0.02, 2.75),
	},
}

function MosquitoTigre.build(name: string, origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = name
	local b: Builder = { model = model, origin = origin }

	-- Tórax (raiz), corcunda, com a risca branca no dorso e manchas brancas dos lados.
	local thorax = ellipsoid(b, "Thorax", Vector3.new(0, 1.6, 0), Vector3.new(0.7, 0.75, 0.9), BLACK_SHINY)
	model.PrimaryPart = thorax
	local stripe =
		ellipsoid(b, "RiscaDorsal", Vector3.new(0, 1.955, -0.05), Vector3.new(0.09, 0.08, 0.68), WHITE)
	joint(b, thorax, stripe, Vector3.new(0, 1.955, -0.05))
	for _, side in { -1, 1 } do
		for i, z in { -0.15, 0.2 } do
			local spot = ellipsoid(
				b,
				`ManchaTorax{side > 0 and "D" or "E"}{i}`,
				Vector3.new(0.33 * side, 1.55 - i * 0.05, z),
				Vector3.new(0.06, 0.14, 0.16),
				WHITE
			)
			joint(b, thorax, spot, Vector3.new(0.33 * side, 1.55, z))
		end
	end

	-- Cabeça com olhos grandes.
	local head = ellipsoid(b, "Head", Vector3.new(0, 1.55, -0.6), Vector3.new(0.42, 0.42, 0.42), BLACK)
	joint(b, thorax, head, Vector3.new(0, 1.55, -0.45))
	for _, side in { -1, 1 } do
		local eye = ellipsoid(
			b,
			if side > 0 then "RightEye" else "LeftEye",
			Vector3.new(0.15 * side, 1.6, -0.68),
			Vector3.new(0.24, 0.3, 0.26),
			EYE
		)
		eye.Reflectance = 0.25
		joint(b, head, eye, Vector3.new(0.15 * side, 1.6, -0.68))
	end

	-- Tromba comprida, para a frente e para baixo.
	local proboscis =
		segment(b, "Proboscis", Vector3.new(0, 1.45, -0.78), Vector3.new(0, 0.95, -1.95), 0.05, BLACK)
	joint(b, head, proboscis, Vector3.new(0, 1.45, -0.78))

	-- Palpos curtos com a ponta branca.
	for _, side in { -1, 1 } do
		local a = Vector3.new(0.06 * side, 1.47, -0.78)
		local c = Vector3.new(0.11 * side, 1.18, -1.15)
		local palp = segment(b, if side > 0 then "RightPalp" else "LeftPalp", a, c, 0.055, BLACK)
		joint(b, head, palp, a)
		local tip = ellipsoid(b, `{palp.Name}Ponta`, c, Vector3.new(0.08, 0.08, 0.08), WHITE)
		joint(b, palp, tip, c)
	end

	-- Antenas finas, para a frente e para cima.
	for _, side in { -1, 1 } do
		local prefix = if side > 0 then "Right" else "Left"
		local base = Vector3.new(0.08 * side, 1.66, -0.75)
		local mid = Vector3.new(0.25 * side, 1.95, -1.25)
		local tip = Vector3.new(0.4 * side, 2.1, -1.65)
		local a1 = segment(b, `{prefix}Antennae1`, base, mid, 0.035, ANTENNA)
		local a2 = segment(b, `{prefix}Antennae2`, mid, tip, 0.03, ANTENNA)
		joint(b, head, a1, base)
		joint(b, a1, a2, mid)
	end

	-- Abdómen comprido e fino, um pouco inclinado para baixo, com manchas brancas
	-- dos lados em cada segmento e faixas brancas no dorso.
	local abdomenStart = Vector3.new(0, 1.55, 0.35)
	local abdomenEnd = Vector3.new(0, 1.25, 2.4)
	local abdomen = longEllipsoid(b, "Abdomen", abdomenStart, abdomenEnd, 0.5, 0.45, BLACK)
	joint(b, thorax, abdomen, abdomenStart)
	for i, t in { 0.2, 0.37, 0.54, 0.71, 0.86 } do
		local center = abdomenStart:Lerp(abdomenEnd, t)
		local taper = 1 - math.max(t - 0.5, 0) * 1.2
		for _, side in { -1, 1 } do
			local spot = ellipsoid(
				b,
				`ManchaAbdomen{side > 0 and "D" or "E"}{i}`,
				center + Vector3.new(0.22 * side * taper, -0.03, 0),
				Vector3.new(0.09, 0.13 * taper, 0.17),
				WHITE
			)
			joint(b, abdomen, spot, center)
		end
		local band = ellipsoid(
			b,
			`FaixaAbdomen{i}`,
			center + Vector3.new(0, 0.2 * taper, 0),
			Vector3.new(0.3 * taper, 0.05, 0.07),
			WHITE
		)
		joint(b, abdomen, band, center)
	end

	-- Asas translúcidas, para trás e um pouco abertas, por cima do abdómen.
	for _, side in { -1, 1 } do
		local base = Vector3.new(0.2 * side, 1.85, 0.15)
		local tip = Vector3.new(0.75 * side, 1.9, 2.0)
		local wing =
			longEllipsoid(b, if side > 0 then "RightWing" else "LeftWing", base, tip, 0.45, 0.02, WING)
		wing.Transparency = 0.55
		wing.Reflectance = 0.15
		wing.CastShadow = false
		joint(b, thorax, wing, base)
	end

	-- Seis patas compridas: coxa (Leg1), tíbia (Leg2) e tarso (Leg3), pretas com faixas brancas.
	for _, side in { -1, 1 } do
		local prefix = if side > 0 then "Right" else "Left"
		for position, p in LEGS do
			local hip, knee = mirror(p.hip, side), mirror(p.knee, side)
			local ankle, toe = mirror(p.ankle, side), mirror(p.toe, side)
			local legName = `{prefix}{position}Leg`
			local femur = segment(b, `{legName}1`, hip, knee, 0.07, BLACK)
			local tibia = segment(b, `{legName}2`, knee, ankle, 0.055, BLACK)
			local tarsus = segment(b, `{legName}3`, ankle, toe, 0.042, BLACK)
			joint(b, thorax, femur, hip)
			joint(b, femur, tibia, knee)
			joint(b, tibia, tarsus, ankle)
			bands(b, femur, `{legName}1`, hip, knee, 0.07, { 0.85 })
			bands(b, tibia, `{legName}2`, knee, ankle, 0.055, { 0.05 })
			bands(b, tarsus, `{legName}3`, ankle, toe, 0.042, { 0.05, 0.35, 0.65 })
			if position == "Back" then
				-- Ponta das patas de trás toda branca.
				local whiteTip = segment(b, `{legName}3Ponta`, ankle:Lerp(toe, 0.82), toe, 0.05, WHITE)
				joint(b, tarsus, whiteTip, ankle:Lerp(toe, 0.82))
			end
		end
	end

	model.WorldPivot = thorax.CFrame
	return model
end

return MosquitoTigre
