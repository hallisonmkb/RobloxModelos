--!strict
-- Modelo próprio da formiga-de-fogo (operária de Solenopsis), montado em código.
-- Cabeça e tórax castanho-avermelhados, gáster (a "barriga") castanho-escuro, pecíolo com
-- dois nós entre o tórax e o gáster, antenas cotoveladas com clava na ponta, mandíbulas,
-- olhos pequenos e seis patas com três segmentos.
--
-- Os nomes seguem o padrão que o ZoneEnemy anima:
--   <Left|Right><Front|Mid|Back>Leg1/2/3 = patas, <Left|Right>Antennae1/2 = antenas,
--   LeftMandible/RightMandible = mandíbulas (fecham ao morder).
-- Raiz: "Torso" (o tórax). Medidas em studs, virada para -Z, chão em Y = 0.
-- Comprimento das mandíbulas à ponta do gáster: cerca de 4,3 studs (Scale = 1).

local Parts = require(script.Parent:WaitForChild("Parts"))
local ellipsoid = Parts.ellipsoid
local longEllipsoid = Parts.longEllipsoid
local segment = Parts.segment
local joint = Parts.joint
local mirror = Parts.mirror

local Formiga = {}

local RED = Color3.fromRGB(150, 62, 30)
local RED_DARK = Color3.fromRGB(120, 48, 24)
local GASTER = Color3.fromRGB(62, 32, 20)
local GASTER_BAND = Color3.fromRGB(90, 48, 28)
local LEG = Color3.fromRGB(160, 75, 40)
local LEG_TIP = Color3.fromRGB(95, 45, 25)
local EYE = Color3.fromRGB(15, 12, 12)

-- Pontos de cada pata: anca (no tórax), joelho (alto), tornozelo (no chão) e ponta.
local LEGS = {
	Front = {
		hip = Vector3.new(0.2, 0.72, -0.75),
		knee = Vector3.new(0.75, 1.15, -1.05),
		ankle = Vector3.new(1.05, 0.08, -1.55),
		toe = Vector3.new(1.15, 0.03, -1.8),
	},
	Mid = {
		hip = Vector3.new(0.22, 0.7, -0.4),
		knee = Vector3.new(0.95, 1.2, -0.35),
		ankle = Vector3.new(1.45, 0.08, -0.2),
		toe = Vector3.new(1.6, 0.03, -0.1),
	},
	Back = {
		hip = Vector3.new(0.22, 0.7, -0.1),
		knee = Vector3.new(0.9, 1.25, 0.35),
		ankle = Vector3.new(1.4, 0.08, 1.2),
		toe = Vector3.new(1.5, 0.03, 1.45),
	},
}

-- Cria a formiga com o chão em origin.Y e virada para a frente de "origin".
function Formiga.build(name: string, origin: CFrame): Model
	local b = Parts.newBuilder(name, origin)
	local model = b.model

	-- Tórax (raiz) com o pronoto mais alto à frente.
	local torso =
		longEllipsoid(b, "Torso", Vector3.new(0, 0.95, -0.95), Vector3.new(0, 0.9, 0.05), 0.55, 0.6, RED)
	model.PrimaryPart = torso
	local pronotum = ellipsoid(b, "Pronoto", Vector3.new(0, 1.05, -0.72), Vector3.new(0.62, 0.58, 0.5), RED)
	joint(b, torso, pronotum, Vector3.new(0, 1.05, -0.72))

	-- Cabeça, olhos e mandíbulas.
	local head = ellipsoid(b, "Head", Vector3.new(0, 0.98, -1.4), Vector3.new(0.8, 0.65, 0.85), RED_DARK)
	joint(b, torso, head, Vector3.new(0, 0.98, -1.05))
	for _, side in { -1, 1 } do
		local eye = ellipsoid(
			b,
			if side > 0 then "RightEye" else "LeftEye",
			Vector3.new(0.36 * side, 1.05, -1.45),
			Vector3.new(0.12, 0.14, 0.16),
			EYE
		)
		eye.Reflectance = 0.3
		joint(b, head, eye, Vector3.new(0.36 * side, 1.05, -1.45))

		local mBase = Vector3.new(0.2 * side, 0.82, -1.75)
		local mTip = Vector3.new(0.05 * side, 0.78, -2.05)
		local mandible =
			segment(b, if side > 0 then "RightMandible" else "LeftMandible", mBase, mTip, 0.1, LEG_TIP)
		joint(b, head, mandible, mBase)
	end

	-- Antenas cotoveladas: escapo comprido para cima e funículo para a frente, com clava.
	for _, side in { -1, 1 } do
		local prefix = if side > 0 then "Right" else "Left"
		local base = Vector3.new(0.2 * side, 1.12, -1.72)
		local elbow = Vector3.new(0.55 * side, 1.6, -1.95)
		local tip = Vector3.new(0.75 * side, 1.3, -2.6)
		local scape = segment(b, `{prefix}Antennae1`, base, elbow, 0.065, RED_DARK)
		local funiculus = segment(b, `{prefix}Antennae2`, elbow, tip, 0.055, RED_DARK)
		joint(b, head, scape, base)
		joint(b, scape, funiculus, elbow)
		local club = ellipsoid(b, `{prefix}Clava`, tip, Vector3.new(0.1, 0.1, 0.18), LEG_TIP)
		joint(b, funiculus, club, tip)
	end

	-- Pecíolo com dois nós.
	local stalk = segment(b, "Peciolo", Vector3.new(0, 0.88, 0.0), Vector3.new(0, 0.95, 0.75), 0.13, RED_DARK)
	joint(b, torso, stalk, Vector3.new(0, 0.88, 0.0))
	for i, z in { 0.28, 0.55 } do
		local node =
			ellipsoid(b, `No{i}`, Vector3.new(0, 1.0, z), Vector3.new(0.28 + i * 0.02, 0.4, 0.22), RED_DARK)
		joint(b, stalk, node, Vector3.new(0, 1.0, z))
	end

	-- Gáster escuro com faixas dos segmentos e o ferrão na ponta.
	local gaster = ellipsoid(b, "Gaster", Vector3.new(0, 0.98, 1.45), Vector3.new(1.1, 0.95, 1.6), GASTER)
	gaster.Reflectance = 0.12
	joint(b, stalk, gaster, Vector3.new(0, 0.95, 0.72))
	for i, z in { 1.05, 1.45, 1.85 } do
		local shrink = 1 - math.abs(z - 1.45) * 0.45
		local band = ellipsoid(
			b,
			`FaixaGaster{i}`,
			Vector3.new(0, 0.98, z),
			Vector3.new(1.12 * shrink, 0.97 * shrink, 0.06),
			GASTER_BAND
		)
		band.Transparency = 0.3
		joint(b, gaster, band, Vector3.new(0, 0.98, z))
	end
	local stinger = segment(b, "Ferrao", Vector3.new(0, 0.95, 2.2), Vector3.new(0, 0.9, 2.32), 0.05, GASTER)
	joint(b, gaster, stinger, Vector3.new(0, 0.95, 2.2))

	-- Seis patas: coxa (Leg1), tíbia (Leg2) e tarso (Leg3).
	for _, side in { -1, 1 } do
		local prefix = if side > 0 then "Right" else "Left"
		for position, p in LEGS do
			local hip, knee = mirror(p.hip, side), mirror(p.knee, side)
			local ankle, toe = mirror(p.ankle, side), mirror(p.toe, side)
			local femur = segment(b, `{prefix}{position}Leg1`, hip, knee, 0.12, LEG)
			local tibia = segment(b, `{prefix}{position}Leg2`, knee, ankle, 0.09, LEG)
			local tarsus = segment(b, `{prefix}{position}Leg3`, ankle, toe, 0.07, LEG_TIP)
			joint(b, torso, femur, hip)
			joint(b, femur, tibia, knee)
			joint(b, tibia, tarsus, ankle)
		end
	end

	-- A referência do modelo tem de olhar para a frente (-Z). O tórax (peça principal) é um
	-- elipsoide comprido criado a apontar para trás, por isso corrige-se o pivô dele.
	Parts.setPivot(b, Vector3.new(0, 0.93, -0.45))
	return model
end

return Formiga
