--!strict
-- Posturas de ovos (o que o jogador apanha e leva para a fazenda), uma forma por inseto,
-- baseadas em fotos reais. Cada postura tem cerca de options.Altura studs de largura
-- ("tamanho de dinossauro") e é feita de vários ovos pequenos:
--   "Pulgao"   -> cacho de ovos alongados, amarelos e brilhantes, de pé, encostados.
--   "Formiga"  -> monte de ovos brancos-creme em forma de grão de arroz, deitados ao calhas,
--                 alguns com uma pinta escura na ponta.
--   "Mosquito" -> "jangada": ovos castanhos em forma de tubo, de pé, muito juntos, numa
--                 forma oval (flutua na água).
--   "Gafanhoto"-> casulo de terra aberto, com ovos alongados cor de creme em arcos.
--   "Unico"    -> um só ovo grande com pintas (reserva, para insetos novos).
-- A peça principal é "Base" (invisível); todos os ovos estão presos a ela por Motor6D, por
-- isso a postura inteira pode ser soldada às mãos do jogador. O pivô fica no chão.

local Parts = require(script.Parent:WaitForChild("Parts"))
local ellipsoid = Parts.ellipsoid
local joint = Parts.joint

local Ovo = {}

export type Options = {
	Altura: number,
	Cor: Color3,
	CorPintas: Color3,
	Forma: string?,
}

local function vary(rng: Random, base: Color3, other: Color3, amount: number): Color3
	return base:Lerp(other, rng:NextNumber(0, amount))
end

-- Peça invisível que segura a postura (e o ProximityPrompt).
local function makeBase(b: Parts.Builder, size: Vector3): Part
	local base = Parts.basePart(b, "Base", Color3.new(1, 1, 1))
	base.Size = size
	base.CFrame = b.origin * CFrame.new(0, size.Y / 2, 0)
	base.Transparency = 1
	b.model.PrimaryPart = base
	return base
end

local function pulgao(b: Parts.Builder, s: number, o: Options)
	local base = makeBase(b, Vector3.new(4.6 * s, 1.6 * s, 3.2 * s))
	local rng = Random.new(11)
	local spacing = 0.58 * s
	local i = 0
	for gx = -4, 4 do
		for gz = -3, 3 do
			-- Grelha desencontrada (como favos) recortada numa forma oval.
			local x = gx * spacing + (if gz % 2 == 0 then 0 else spacing / 2)
			local z = gz * spacing * 0.87
			if (x / (2.2 * s)) ^ 2 + (z / (1.45 * s)) ^ 2 <= 1 then
				i += 1
				local h = rng:NextNumber(1.15, 1.4) * s
				local center = Vector3.new(x, h / 2, z)
				local egg = ellipsoid(
					b,
					`Ovo{i}`,
					center,
					Vector3.new(0.55 * s, h, 0.55 * s),
					vary(rng, o.Cor, o.CorPintas, 0.35)
				)
				egg.Reflectance = 0.18
				-- Ligeiramente inclinados, como na foto.
				egg.CFrame = b.origin
					* CFrame.new(center)
					* CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15))
				joint(b, base, egg, center)
			end
		end
	end
end

local function formiga(b: Parts.Builder, s: number, o: Options)
	local base = makeBase(b, Vector3.new(4.4 * s, 1.8 * s, 4.4 * s))
	local rng = Random.new(23)
	local radius = 1.9 * s
	for i = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber(0, 1)) * radius
		-- Monte: mais alto no meio.
		local y = 0.3 * s + (1 - r / radius) * rng:NextNumber(0.2, 1.1) * s
		local center = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
		local egg = ellipsoid(
			b,
			`Ovo{i}`,
			center,
			Vector3.new(0.6 * s, 0.6 * s, 1.5 * s),
			vary(rng, o.Cor, Color3.new(1, 1, 1), 0.5)
		)
		egg.Material = Enum.Material.SmoothPlastic
		egg.Reflectance = 0.05
		local rotation = CFrame.Angles(
			rng:NextNumber(-0.4, 0.4),
			rng:NextNumber(0, math.pi * 2),
			rng:NextNumber(-0.3, 0.3)
		)
		egg.CFrame = b.origin * CFrame.new(center) * rotation
		joint(b, base, egg, center)
		if rng:NextNumber() < 0.4 then
			-- Pinta escura numa das pontas (como nas fotos dos ovos de formiga).
			local tipLocal = (CFrame.new(center) * rotation):PointToWorldSpace(Vector3.new(0, 0, -0.7 * s))
			local dot =
				ellipsoid(b, `Pinta{i}`, tipLocal, Vector3.new(0.18 * s, 0.18 * s, 0.12 * s), o.CorPintas)
			joint(b, egg, dot, tipLocal)
		end
	end
end

local function mosquito(b: Parts.Builder, s: number, o: Options)
	local base = makeBase(b, Vector3.new(4.4 * s, 1.0 * s, 2.2 * s))
	local rng = Random.new(37)
	local d = 0.3 * s -- diâmetro de cada ovo
	local spacing = d * 1.05
	local rx, rz = 2.1 * s, 0.95 * s
	local i = 0
	for gx = -12, 12 do
		for gz = -6, 6 do
			local x = gx * spacing + (if gz % 2 == 0 then 0 else spacing / 2)
			local z = gz * spacing * 0.87
			local e = (x / rx) ^ 2 + (z / rz) ^ 2
			if e <= 1 then
				i += 1
				local h = 0.9 * s
				-- Os da borda inclinam-se um pouco para fora, como numa jangada.
				local tilt = e * 0.35
				local outward = Vector3.new(x, 0, z)
				local foot = Vector3.new(x, 0.05 * s, z)
				local tubeCF = CFrame.new(foot)
				if outward.Magnitude > 0.01 then
					local axis = Vector3.new(0, 1, 0):Cross(outward.Unit)
					tubeCF *= CFrame.fromAxisAngle(axis, tilt)
				end
				local tube = Parts.basePart(b, `Ovo{i}`, vary(rng, o.Cor, o.CorPintas, 0.25))
				tube.Shape = Enum.PartType.Cylinder
				tube.Size = Vector3.new(h, d, d)
				tube.CFrame = b.origin * tubeCF * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
				tube.Reflectance = 0.12
				joint(b, base, tube, foot)
				-- Ponta de cima mais escura e arredondada.
				local tipPos = (tubeCF * CFrame.new(0, h, 0)).Position
				local tip = ellipsoid(b, `Ponta{i}`, tipPos, Vector3.new(d, d * 0.6, d), o.CorPintas)
				joint(b, tube, tip, tipPos)
			end
		end
	end
end

-- Gafanhoto: casulo de terra (ooteca) aberto em cima, com ovos alongados cor de creme
-- arrumados em arcos lá dentro, como nas fotos. options.CorPintas = cor da terra.
local function gafanhoto(b: Parts.Builder, s: number, o: Options)
	local base = makeBase(b, Vector3.new(3.6 * s, 2.4 * s, 4.6 * s))
	local soil = o.CorPintas
	local clod =
		ellipsoid(b, "Casulo", Vector3.new(0, 0.95 * s, 0), Vector3.new(3.4 * s, 1.9 * s, 4.4 * s), soil)
	clod.Material = Enum.Material.Ground
	joint(b, base, clod, Vector3.new(0, 0.95 * s, 0))
	-- Rebordo de terra mais escura à volta da abertura.
	local rim = ellipsoid(
		b,
		"Rebordo",
		Vector3.new(0, 1.75 * s, 0),
		Vector3.new(3.0 * s, 0.45 * s, 3.9 * s),
		soil:Lerp(Color3.new(0, 0, 0), 0.25)
	)
	rim.Material = Enum.Material.Ground
	joint(b, clod, rim, Vector3.new(0, 1.75 * s, 0))
	-- Ovos em arcos concêntricos, inclinados, a sair da terra.
	local rng = Random.new(53)
	local i = 0
	for ring, count in { 6, 10, 13 } do
		local r = ring * 0.42 * s
		for k = 1, count do
			i += 1
			local a = (k / count) * math.pi * 2 + ring * 0.3
			local pos = Vector3.new(math.cos(a) * r * 0.8, 1.85 * s - ring * 0.08 * s, math.sin(a) * r)
			local egg = ellipsoid(
				b,
				`Ovo{i}`,
				pos,
				Vector3.new(0.45 * s, 1.05 * s, 0.45 * s),
				vary(rng, o.Cor, Color3.new(1, 1, 1), 0.3)
			)
			-- Deitados para fora, como pétalas.
			local outward = Vector3.new(pos.X, 0, pos.Z)
			local tiltAxis = if outward.Magnitude > 0.01
				then Vector3.new(0, 1, 0):Cross(outward.Unit)
				else Vector3.xAxis
			egg.CFrame = b.origin
				* CFrame.new(pos)
				* CFrame.fromAxisAngle(tiltAxis, 0.25 + ring * 0.2 + rng:NextNumber(-0.1, 0.1))
			joint(b, clod, egg, pos)
		end
	end
end

local function unico(b: Parts.Builder, s: number, o: Options)
	local h = 5 * s
	local w = h * 0.72
	local base = makeBase(b, Vector3.new(w, h, w))
	local shell = ellipsoid(b, "Casca", Vector3.new(0, h * 0.38, 0), Vector3.new(w, h * 0.76, w), o.Cor)
	shell.Reflectance = 0.08
	joint(b, base, shell, Vector3.new(0, h * 0.38, 0))
	local top =
		ellipsoid(b, "Ponta", Vector3.new(0, h * 0.6, 0), Vector3.new(w * 0.83, h * 0.8, w * 0.83), o.Cor)
	top.Reflectance = 0.08
	joint(b, shell, top, Vector3.new(0, h * 0.6, 0))
	local rng = Random.new(5)
	for i = 1, 14 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local y = rng:NextNumber(0.15, 0.85)
		local t = (y - 0.45) / 0.5
		local radius = (w / 2) * math.sqrt(math.max(0, 1 - t * t)) * (if y > 0.45 then 0.9 else 1)
		local pos = Vector3.new(math.cos(angle) * radius, y * h, math.sin(angle) * radius)
		local size = rng:NextNumber(0.08, 0.16) * h
		local spot = ellipsoid(b, `Pinta{i}`, pos, Vector3.new(size, size * 0.8, size * 0.25), o.CorPintas)
		spot.CFrame = b.origin * CFrame.lookAt(pos, pos + Vector3.new(pos.X, 0, pos.Z))
		joint(b, shell, spot, pos)
	end
end

local FORMS =
	{ Pulgao = pulgao, Formiga = formiga, Mosquito = mosquito, Gafanhoto = gafanhoto, Unico = unico }

-- Cria a postura com o chão em origin. options.Altura = tamanho total (studs).
function Ovo.build(name: string, origin: CFrame, options: Options): Model
	local b = Parts.newBuilder(name, origin)
	local s = options.Altura / 5
	local form = FORMS[options.Forma or "Unico"] or unico
	form(b, s, options)

	local base = b.model.PrimaryPart :: BasePart
	local light = Instance.new("PointLight")
	light.Color = options.Cor
	light.Brightness = 0.6
	light.Range = options.Altura * 2.5
	light.Parent = base

	for _, item in b.model:GetDescendants() do
		if item:IsA("BasePart") then
			item.CanCollide = false
		end
	end
	Parts.setPivot(b, Vector3.zero) -- pivô no chão, no centro da postura
	return b.model
end

return Ovo
