--!strict
-- Áreas de descanso entre as zonas dos insetos: todas as Parts cujo nome começa por
-- Config.Descanso.Prefixo ("ZonaDescanso", "ZonaDescanso2", ...).
-- - Decoração feita em código ao arrancar: bancos, candeeiro, flores e uma placa.
-- - Quem estiver lá dentro recupera vida (Config.Descanso.CuraPorSegundo).
-- Os insetos nunca entram aqui (cada um fica preso à sua zona).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Config"))

local Descanso = {}

local areas: { BasePart } = {}

local WOOD = Color3.fromRGB(130, 90, 55)
local METAL = Color3.fromRGB(60, 60, 65)
local FLOWERS = {
	Color3.fromRGB(240, 90, 120),
	Color3.fromRGB(255, 210, 70),
	Color3.fromRGB(150, 110, 230),
	Color3.fromRGB(255, 255, 255),
}

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function bench(parent: Instance, at: CFrame)
	block(parent, "Assento", Vector3.new(6, 0.4, 2), at * CFrame.new(0, 1.6, 0), WOOD, Enum.Material.Wood)
	block(parent, "Encosto", Vector3.new(6, 1.6, 0.3), at * CFrame.new(0, 2.6, 0.9), WOOD, Enum.Material.Wood)
	for _, x in { -2.6, 2.6 } do
		block(
			parent,
			"Pe",
			Vector3.new(0.3, 1.4, 1.8),
			at * CFrame.new(x, 0.7, 0),
			METAL,
			Enum.Material.Metal
		)
	end
	local seat = Instance.new("Seat")
	seat.Name = "Lugar"
	seat.Anchored = true
	seat.Transparency = 1
	seat.Size = Vector3.new(5.5, 0.3, 1.8)
	seat.CFrame = at * CFrame.new(0, 1.85, 0) * CFrame.Angles(0, math.pi, 0)
	seat.Parent = parent
end

local function lamp(parent: Instance, at: CFrame)
	block(parent, "Poste", Vector3.new(0.5, 9, 0.5), at * CFrame.new(0, 4.5, 0), METAL, Enum.Material.Metal)
	local bulb = block(
		parent,
		"Lampada",
		Vector3.new(1.4, 1.4, 1.4),
		at * CFrame.new(0, 9.4, 0),
		Color3.fromRGB(255, 230, 160),
		Enum.Material.Neon
	)
	bulb.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 160)
	light.Range = 22
	light.Brightness = 1.4
	light.Parent = bulb
end

local function sign(parent: Instance, at: CFrame)
	block(parent, "PostePlaca", Vector3.new(0.4, 4, 0.4), at * CFrame.new(0, 2, 0), WOOD, Enum.Material.Wood)
	local board =
		block(parent, "Placa", Vector3.new(5, 1.8, 0.3), at * CFrame.new(0, 4.4, 0), WOOD, Enum.Material.Wood)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(250, 90)
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "Área de descanso\n(recupera vida)"
		label.TextColor3 = Color3.fromRGB(255, 245, 220)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = gui
	end
end

local function decorate(area: BasePart)
	local folder = Instance.new("Folder")
	folder.Name = `Decoracao{area.Name}`
	folder.Parent = workspace
	local top = area.CFrame * CFrame.new(0, area.Size.Y / 2, 0)
	local hx, hz = area.Size.X / 2, area.Size.Z / 2

	bench(folder, top * CFrame.new(-math.min(hx * 0.45, 8), 0, 0) * CFrame.Angles(0, math.pi / 2, 0))
	bench(folder, top * CFrame.new(math.min(hx * 0.45, 8), 0, 0) * CFrame.Angles(0, -math.pi / 2, 0))
	lamp(folder, top * CFrame.new(0, 0, -math.min(hz * 0.6, 10)))
	sign(folder, top * CFrame.new(0, 0, math.min(hz * 0.6, 10)))

	-- Canteiro de flores à volta.
	local rng = Random.new(#area.Name * 31 + 5)
	for i = 1, 18 do
		local x = rng:NextNumber(-hx + 1, hx - 1)
		local z = rng:NextNumber(-hz + 1, hz - 1)
		if math.abs(x) > hx * 0.6 or math.abs(z) > hz * 0.6 then
			local at = top * CFrame.new(x, 0, z)
			block(
				folder,
				"Caule",
				Vector3.new(0.15, 1.2, 0.15),
				at * CFrame.new(0, 0.6, 0),
				Color3.fromRGB(60, 140, 50)
			)
			local petal = block(
				folder,
				"Flor",
				Vector3.new(0.8, 0.8, 0.8),
				at * CFrame.new(0, 1.3, 0),
				FLOWERS[(i % #FLOWERS) + 1]
			)
			petal.Shape = Enum.PartType.Ball
			petal.CanCollide = false
		end
	end
end

local function isInside(area: BasePart, position: Vector3): boolean
	local p = area.CFrame:PointToObjectSpace(position)
	local half = area.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Z) <= half.Z and p.Y > -half.Y - 2 and p.Y < half.Y + 20
end

function Descanso.start()
	for _, item in workspace:GetDescendants() do
		if
			item:IsA("BasePart")
			and string.sub(item.Name, 1, #Config.Descanso.Prefixo) == Config.Descanso.Prefixo
		then
			table.insert(areas, item)
			local ok, err = pcall(decorate, item)
			if not ok then
				warn(`[Descanso] erro ao decorar {item.Name}: {err}`)
			end
		end
	end
	if #areas == 0 then
		warn(`[Descanso] nenhuma Part "{Config.Descanso.Prefixo}..." encontrada; crie as áreas no Studio`)
		return
	end
	print(`[Descanso] {#areas} áreas de descanso prontas`)

	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if humanoid and root and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
					for _, area in areas do
						if isInside(area, root.Position) then
							humanoid.Health = math.min(
								humanoid.MaxHealth,
								humanoid.Health + Config.Descanso.CuraPorSegundo * 0.5
							)
							break
						end
					end
				end
			end
		end
	end)
end

return Descanso
