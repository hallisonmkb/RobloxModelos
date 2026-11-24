--!strict
-- ProgressionService: XP e nível do jogador (guardados em data.XP e data.Level).
-- XP para passar do nível N ao N+1 = floor(XPBase * Crescimento^(N-1)), até NivelMax.
-- Publica para o cliente os atributos "Level", "XP" e "XPNext" e o valor "Nível" na
-- leaderstats. Tudo decidido no servidor; os jogos só chamam addXP.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Config"))
local DataService = require(script.Parent.DataService)

local ProgressionService = {}

local defaults = { XPBase = 100, Crescimento = 1.35, NivelMax = 50, Nome = "Nível" }
local settings: any = (Config :: any).Progressao or defaults

local levelUpEvent = Instance.new("BindableEvent")
ProgressionService.LevelUp = levelUpEvent.Event -- (player, novoNivel)

local function setting(key: string): any
	local value = settings[key]
	if value == nil then
		return (defaults :: any)[key]
	end
	return value
end

-- XP necessário para sair do nível "level" (math.huge no nível máximo).
function ProgressionService.xpToNext(level: number): number
	if level >= setting("NivelMax") then
		return math.huge
	end
	return math.floor(setting("XPBase") * setting("Crescimento") ^ (level - 1))
end

local function publish(player: Player, data: { [string]: any })
	local nextXP = ProgressionService.xpToNext(data.Level)
	player:SetAttribute("Level", data.Level)
	player:SetAttribute("XP", data.XP)
	player:SetAttribute("XPNext", if nextXP == math.huge then 0 else nextXP)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	local value = (leaderstats :: Instance):FindFirstChild(setting("Nome"))
	if not value then
		value = Instance.new("IntValue")
		value.Name = setting("Nome")
		value.Parent = leaderstats
	end
	(value :: IntValue).Value = data.Level
end

function ProgressionService.getLevel(player: Player): number
	local data = DataService.get(player)
	return if data then data.Level else 1
end

-- Dá XP (só valores positivos e finitos) e sobe de nível quantas vezes for preciso.
-- Devolve quantos níveis subiu.
function ProgressionService.addXP(player: Player, amount: number): number
	local data = DataService.get(player)
	if not data or type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then
		return 0
	end
	data.XP += math.floor(amount)
	local gained = 0
	while data.XP >= ProgressionService.xpToNext(data.Level) do
		data.XP -= ProgressionService.xpToNext(data.Level)
		data.Level += 1
		gained += 1
	end
	publish(player, data)
	if gained > 0 then
		levelUpEvent:Fire(player, data.Level)
	end
	return gained
end

function ProgressionService.start()
	DataService.Loaded:Connect(function(player: Player, data)
		publish(player, data)
	end)
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			publish(player, data)
		end
	end
end

return ProgressionService
