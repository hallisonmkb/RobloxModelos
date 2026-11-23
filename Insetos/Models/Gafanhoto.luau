--!strict
-- Modelo próprio do gafanhoto, montado em código a partir de peças.
-- Baseado nas fotos: corpo verde com abdómen verde-amarelado segmentado, cabeça alta com
-- olho grande castanho, antenas curtas e finas, pronoto em "sela", asas castanhas
-- translúcidas dobradas ao longo do corpo, quatro patas da frente finas e duas patas de
-- trás enormes (coxa grossa em forma de coxa de frango, joelho escuro e tíbia fina com
-- espinhos).
--
-- Nomes que o ZoneEnemy anima:
--   <Left|Right><Front|Mid>Leg1/2/3 = patas de andar (passo alternado),
--   <Left|Right>HindLeg1/2 = patas de saltar (coice no salto),
--   <Left|Right>Antennae1/2 = antenas.
-- Raiz: "Thorax". Medidas em studs, virado para -Z, chão em Y = 0.
-- Comprimento da cabeça à ponta das asas: cerca de 4,4 studs (Scale = 1).

local Parts = require(script.Parent:WaitForChild("Parts"))
local ellipsoid = Parts.ellipsoid
local longEllipsoid = Parts.longEllipsoid
local segment = Parts.segment
local joint = Parts.joint
local mirror = Parts.mirror

local Gafanhoto = {}

local GREEN = Color3.fromRGB(120, 170, 50)
local GREEN_DARK = Color3.fromRGB(95, 140, 40)
local GREEN_LIGHT = Color3.fromRGB(175, 200, 70)
local ABDOMEN = Color3.fromRGB(180, 195, 65)
local ABDOMEN_BAND = Color3.fromRGB(140, 155, 45)
local EYE = Color3.fromRGB(75, 45, 30)
local WING = Color3.fromRGB(150, 120, 75)
local WING_VEIN = Color3.fromRGB(110, 85, 50)
local LEG = Color3.fromRGB(135, 180, 60)
local TIBIA = Color3.fromRGB(185, 160, 95)
local DARK = Color3.fromRGB(60, 35, 25)
local ANTENNA = Color3.fromRGB(150, 145, 70)

-- Patas de andar (frente e meio): anca, joelho, tornozelo e ponta. Lado direito (+X).
local WALK_LEGS = {
	Front = {
		hip = Vector3.new(0.25, 0.55, -0.75),
		knee = Vector3.new(0.55, 0.85, -1.05),
		ankle = Vector3.new(0.75, 0.06, -1.25),
		toe = Vector3.new(0.82, 0.02, -1.42),
	},
	Mid = {
		hip = Vector3.new(0.28, 0.55, -0.35),
		knee = Vector3.new(0.65, 0.85, -0.35),
		ankle = Vector3.new(0.9, 0.06, -0.25),
		toe = Vector3.new(0.98, 0.02, -0.08),
	},
}

-- Pata de saltar: anca, joelho (bem acima do corpo, atrás), pé e ponta (no chão).
local HIND = {
	hip = Vector3.new(0.33, 0.6, -0.05),
	knee = Vector3.new(0.48, 1.45, 1.6),
	foot = Vector3.new(0.55, 0.08, 0.55),
	toe = Vector3.new(0.58, 0.02, 0.85),
}

-- Cria o gafanhoto com o chão em origin.Y e virado para a frente de "origin".
function Gafanhoto.build(name: string, origin: CFrame): Model
	local b = Parts.newBuilder(name, origin)
	local model = b.model

	-- Tórax (raiz) e pronoto em sela por cima.
	local thorax = ellipsoid(b, "Thorax", Vector3.new(0, 0.82, -0.45), Vector3.new(0.68, 0.78, 1.0), GREEN)
	model.PrimaryPart = thorax
	local pronotum =
		ellipsoid(b, "Pronoto", Vector3.new(0, 0.98, -0.55), Vector3.new(0.78, 0.72, 0.85), GREEN_DARK)
	joint(b, thorax, pronotum, Vector3.new(0, 0.98, -0.55))
	local keel =
		ellipsoid(b, "Quilha", Vector3.new(0, 1.33, -0.55), Vector3.new(0.12, 0.06, 0.8), GREEN_LIGHT)
	joint(b, pronotum, keel, Vector3.new(0, 1.33, -0.55))

	-- Cabeça alta, virada um pouco para baixo, com olhos grandes e boca escura.
	local head =
		longEllipsoid(b, "Head", Vector3.new(0, 1.22, -1.0), Vector3.new(0, 0.6, -1.32), 0.6, 0.58, GREEN)
	joint(b, thorax, head, Vector3.new(0, 1.0, -0.95))
	for _, side in { -1, 1 } do
		local eye = ellipsoid(
			b,
			if side > 0 then "RightEye" else "LeftEye",
			Vector3.new(0.27 * side, 1.12, -1.18),
			Vector3.new(0.14, 0.27, 0.21),
			EYE
		)
		eye.Reflectance = 0.3
		joint(b, head, eye, Vector3.new(0.27 * side, 1.12, -1.18))
	end
	local mouth = ellipsoid(b, "Boca", Vector3.new(0, 0.6, -1.36), Vector3.new(0.22, 0.16, 0.14), DARK)
	joint(b, head, mouth, Vector3.new(0, 0.6, -1.36))

	-- Antenas curtas e finas, para a frente e para cima.
	for _, side in { -1, 1 } do
		local prefix = if side > 0 then "Right" else "Left"
		local base = Vector3.new(0.12 * side, 1.2, -1.32)
		local mid = Vector3.new(0.25 * side, 1.6, -1.72)
		local tip = Vector3.new(0.38 * side, 1.95, -2.0)
		local a1 = segment(b, `{prefix}Antennae1`, base, mid, 0.05, ANTENNA)
		local a2 = segment(b, `{prefix}Antennae2`, mid, tip, 0.04, DARK)
		joint(b, head, a1, base)
		joint(b, a1, a2, mid)
	end

	-- Abdómen comprido, verde-amarelado, com as faixas dos segmentos.
	local aStart, aEnd = Vector3.new(0, 0.75, 0.1), Vector3.new(0, 0.58, 2.6)
	local abdomen = longEllipsoid(b, "Abdomen", aStart, aEnd, 0.6, 0.62, ABDOMEN)
	joint(b, thorax, abdomen, aStart)
	for i = 1, 6 do
		local t = 0.15 + i * 0.11
		local center = aStart:Lerp(aEnd, t)
		local shrink = 1 - math.max(t - 0.55, 0) * 1.1
		local band = ellipsoid(
			b,
			`FaixaAbdomen{i}`,
			center,
			Vector3.new(0.62 * shrink, 0.64 * shrink, 0.05),
			ABDOMEN_BAND
		)
		joint(b, abdomen, band, center)
	end

	-- Asas dobradas ao longo do corpo (lâminas castanhas translúcidas dos dois lados).
	for _, side in { -1, 1 } do
		local prefix = if side > 0 then "Right" else "Left"
		local base = Vector3.new(0.2 * side, 1.08, -0.15)
		local tip = Vector3.new(0.24 * side, 0.9, 3.05)
		local tegmen = longEllipsoid(b, `{prefix}Tegmen`, base, tip, 0.05, 0.55, WING)
		tegmen.Transparency = 0.2
		joint(b, thorax, tegmen, base)
		local vein = segment(
			b,
			`{prefix}Nervura`,
			base + Vector3.new(0.02 * side, -0.05, 0.3),
			tip + Vector3.new(0.02 * side, 0.02, -0.4),
			0.04,
			WING_VEIN
		)
		joint(b, tegmen, vein, base)
	end

	-- Quatro patas de andar (finas): coxa, tíbia e tarso.
	for _, side in { -1, 1 } do
		local prefix = if side > 0 then "Right" else "Left"
		for position, p in WALK_LEGS do
			local hip, knee = mirror(p.hip, side), mirror(p.knee, side)
			local ankle, toe = mirror(p.ankle, side), mirror(p.toe, side)
			local femur = segment(b, `{prefix}{position}Leg1`, hip, knee, 0.1, LEG)
			local tibia = segment(b, `{prefix}{position}Leg2`, knee, ankle, 0.075, LEG)
			local tarsus = segment(b, `{prefix}{position}Leg3`, ankle, toe, 0.065, TIBIA)
			joint(b, thorax, femur, hip)
			joint(b, femur, tibia, knee)
			joint(b, tibia, tarsus, ankle)
		end
	end

	-- Duas patas de saltar: coxa grossa, joelho escuro, tíbia fina com espinhos e pé.
	for _, side in { -1, 1 } do
		local prefix = if side > 0 then "Right" else "Left"
		local hip, knee = mirror(HIND.hip, side), mirror(HIND.knee, side)
		local foot, toe = mirror(HIND.foot, side), mirror(HIND.toe, side)
		local femur = longEllipsoid(b, `{prefix}HindLeg1`, hip, knee, 0.3, 0.42, LEG)
		joint(b, thorax, femur, hip)
		-- Riscas em espinha na coxa (marca típica das fotos).
		for i, t in { 0.35, 0.55, 0.75 } do
			local mark = segment(
				b,
				`{prefix}HindRisca{i}`,
				hip:Lerp(knee, t) + Vector3.new(0.13 * side, -0.05, 0),
				hip:Lerp(knee, t + 0.08) + Vector3.new(0.13 * side, 0.08, 0),
				0.035,
				GREEN_DARK
			)
			joint(b, femur, mark, hip:Lerp(knee, t))
		end
		local kneeCap = ellipsoid(b, `{prefix}HindJoelho`, knee, Vector3.new(0.2, 0.2, 0.2), DARK)
		joint(b, femur, kneeCap, knee)
		local tibia = segment(b, `{prefix}HindLeg2`, knee, foot, 0.08, TIBIA)
		joint(b, femur, tibia, knee)
		for i, t in { 0.3, 0.5, 0.7, 0.85 } do
			local at = knee:Lerp(foot, t)
			local spine =
				segment(b, `{prefix}HindEspinho{i}`, at, at + Vector3.new(0, 0.02, 0.13), 0.03, DARK)
			joint(b, tibia, spine, at)
		end
		local tarsus = segment(b, `{prefix}HindLeg3`, foot, toe, 0.07, DARK)
		joint(b, tibia, tarsus, foot)
	end

	-- Referência do modelo virada para a frente (-Z).
	Parts.setPivot(b, Vector3.new(0, 0.82, -0.45))
	return model
end

return Gafanhoto
