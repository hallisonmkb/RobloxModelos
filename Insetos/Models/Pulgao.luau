--!strict
-- Modelo próprio do pulgão (afídeo), montado em código a partir de peças simples.
-- Baseado em fotos reais: corpo verde-claro em forma de pera, cabeça pequena com olhos
-- vermelho-escuros, antenas finas e compridas, seis patas compridas com três segmentos,
-- dois sifúnculos (os "tubinhos" na traseira) e a cauda.
--
-- Os nomes das peças seguem o padrão que o ZoneEnemy anima:
--   <Left|Right><Front|Mid|Back>Leg1/2/3 = patas, <Left|Right>Antennae1/2 = antenas.
-- Todas as peças estão ligadas por Motor6D à raiz ("Abdomen").
--
-- Medidas em studs, com o pulgão virado para -Z (a frente), +X à direita e o chão em Y = 0.

local Pulgao = {}

local BODY = Color3.fromRGB(150, 200, 95)
local BODY_DARK = Color3.fromRGB(120, 170, 75)
local THORAX = Color3.fromRGB(165, 205, 100)
local HEAD = Color3.fromRGB(175, 205, 110)
local LEG = Color3.fromRGB(165, 180, 120)
local LEG_TIP = Color3.fromRGB(95, 95, 65)
local EYE = Color3.fromRGB(110, 20, 20)
local ANTENNA = Color3.fromRGB(150, 165, 110)
local ANTENNA_TIP = Color3.fromRGB(80, 85, 60)

local Parts = require(script.Parent:WaitForChild("Parts"))
type Builder = Parts.Builder
local ellipsoid = Parts.ellipsoid
local segment = Parts.segment
local joint = Parts.joint
local mirror = Parts.mirror

local LEGS = {
	Front = {
		hip = Vector3.new(0.38, 0.72, -1.0),
		knee = Vector3.new(1.0, 1.1, -1.55),
		ankle = Vector3.new(1.35, 0.07, -2.25),
		toe = Vector3.new(1.47, 0.03, -2.45),
	},
	Mid = {
		hip = Vector3.new(0.45, 0.72, -0.7),
		knee = Vector3.new(1.25, 1.15, -0.65),
		ankle = Vector3.new(1.8, 0.07, -0.5),
		toe = Vector3.new(1.98, 0.03, -0.45),
	},
	Back = {
		hip = Vector3.new(0.42, 0.72, -0.35),
		knee = Vector3.new(1.15, 1.2, 0.3),
		ankle = Vector3.new(1.6, 0.07, 1.5),
		toe = Vector3.new(1.72, 0.03, 1.72),
	},
}

-- Cria o pulgão com o chão em origin.Y e virado para a frente de "origin".
function Pulgao.build(name: string, origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = name
	local b: Builder = { model = model, origin = origin }

	-- Corpo: abdómen grande (raiz), tórax e cabeça.
	local abdomen = ellipsoid(b, "Abdomen", Vector3.new(0, 0.9, 0.55), Vector3.new(1.5, 1.15, 2.3), BODY)
	local thorax = ellipsoid(b, "Thorax", Vector3.new(0, 0.92, -0.75), Vector3.new(1.0, 0.85, 1.05), THORAX)
	local head = ellipsoid(b, "Head", Vector3.new(0, 0.95, -1.35), Vector3.new(0.75, 0.6, 0.55), HEAD)
	model.PrimaryPart = abdomen
	joint(b, abdomen, thorax, Vector3.new(0, 0.92, -0.45))
	joint(b, thorax, head, Vector3.new(0, 0.95, -1.15))

	-- Segmentos do abdómen: faixas um pouco mais escuras, como nas fotos.
	for i, z in { 0.05, 0.55, 1.05 } do
		local width = 1.52 - math.abs(z - 0.45) * 0.35
		local ring = ellipsoid(
			b,
			`Segmento{i}`,
			Vector3.new(0, 0.92, z),
			Vector3.new(width, 1.12 - math.abs(z - 0.45) * 0.3, 0.12),
			BODY_DARK
		)
		ring.Transparency = 0.35
		joint(b, abdomen, ring, Vector3.new(0, 0.92, z))
	end

	-- Olhos vermelho-escuros dos lados da cabeça.
	for _, side in { -1, 1 } do
		local eye = ellipsoid(
			b,
			if side > 0 then "RightEye" else "LeftEye",
			Vector3.new(0.32 * side, 1.05, -1.45),
			Vector3.new(0.17, 0.17, 0.17),
			EYE
		)
		eye.Reflectance = 0.2
		joint(b, head, eye, Vector3.new(0.32 * side, 1.05, -1.45))
	end

	-- Bico (rostro) por baixo da cabeça, virado para trás.
	local rostrum = segment(b, "Rostrum", Vector3.new(0, 0.72, -1.5), Vector3.new(0, 0.45, -0.95), 0.07, LEG)
	joint(b, head, rostrum, Vector3.new(0, 0.72, -1.5))

	-- Antenas: compridas e finas, para a frente e para os lados.
	for _, side in { -1, 1 } do
		local prefix = if side > 0 then "Right" else "Left"
		local base = Vector3.new(0.17 * side, 1.18, -1.58)
		local mid = Vector3.new(0.45 * side, 1.6, -2.3)
		local tip = Vector3.new(0.95 * side, 1.85, -3.8)
		local a1 = segment(b, `{prefix}Antennae1`, base, mid, 0.06, ANTENNA)
		local a2 = segment(b, `{prefix}Antennae2`, mid, tip, 0.045, ANTENNA_TIP)
		joint(b, head, a1, base)
		joint(b, a1, a2, mid)
	end

	-- Seis patas, cada uma com coxa (Leg1), tíbia (Leg2) e pé (Leg3).
	for _, side in { -1, 1 } do
		local prefix = if side > 0 then "Right" else "Left"
		for position, p in LEGS do
			local hip, knee = mirror(p.hip, side), mirror(p.knee, side)
			local ankle, toe = mirror(p.ankle, side), mirror(p.toe, side)
			local femur = segment(b, `{prefix}{position}Leg1`, hip, knee, 0.13, LEG)
			local tibia = segment(b, `{prefix}{position}Leg2`, knee, ankle, 0.095, LEG)
			local tarsus = segment(b, `{prefix}{position}Leg3`, ankle, toe, 0.075, LEG_TIP)
			joint(b, thorax, femur, hip)
			joint(b, femur, tibia, knee)
			joint(b, tibia, tarsus, ankle)
		end
	end

	-- Sifúnculos (dois tubinhos na traseira) e cauda.
	for _, side in { -1, 1 } do
		local a = Vector3.new(0.35 * side, 1.25, 1.2)
		local c = Vector3.new(0.5 * side, 1.45, 1.8)
		local tube =
			segment(b, if side > 0 then "RightSiphunculus" else "LeftSiphunculus", a, c, 0.11, BODY_DARK)
		joint(b, abdomen, tube, a)
	end
	local cauda = ellipsoid(b, "Cauda", Vector3.new(0, 0.85, 1.75), Vector3.new(0.22, 0.2, 0.4), BODY_DARK)
	joint(b, abdomen, cauda, Vector3.new(0, 0.85, 1.6))

	model.WorldPivot = abdomen.CFrame
	return model
end

return Pulgao
