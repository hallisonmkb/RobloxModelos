--!strict
-- Cliente: só mostra a interface e pede coisas ao servidor.
-- Interface provisória do jogo de exemplo; o UI Kit vem depois.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Config = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Config"))

local player = Players.LocalPlayer
local clickRemote = Remotes.get("Click")

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false

local coins = Instance.new("TextLabel")
coins.Size = UDim2.fromOffset(260, 50)
coins.Position = UDim2.new(0.5, -130, 0, 20)
coins.BackgroundTransparency = 0.3
coins.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
coins.TextColor3 = Color3.fromRGB(255, 220, 80)
coins.TextScaled = true
coins.Font = Enum.Font.GothamBold
coins.Parent = gui

local button = Instance.new("TextButton")
button.Size = UDim2.fromOffset(220, 90)
button.Position = UDim2.new(0.5, -110, 1, -130)
button.BackgroundColor3 = Color3.fromRGB(60, 170, 90)
button.TextColor3 = Color3.new(1, 1, 1)
button.TextScaled = true
button.Font = Enum.Font.GothamBold
button.Text = "Clique!"
button.Parent = gui

for _, element in { coins, button } do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = element
end

local function refresh()
	local value = player:GetAttribute("Coins")
	coins.Text = `{Config.Currency.Name}: {value or "..."}`
end

player:GetAttributeChangedSignal("Coins"):Connect(refresh)
refresh()

-- Nível e barra de XP (atributos "Level", "XP" e "XPNext" do ProgressionService).
local levelFrame = Instance.new("Frame")
levelFrame.Size = UDim2.fromOffset(200, 50)
levelFrame.Position = UDim2.new(0, 16, 1, -70)
levelFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
levelFrame.BackgroundTransparency = 0.3
levelFrame.Parent = gui
local levelCorner = Instance.new("UICorner")
levelCorner.CornerRadius = UDim.new(0, 10)
levelCorner.Parent = levelFrame

local levelLabel = Instance.new("TextLabel")
levelLabel.Size = UDim2.new(1, -16, 0, 24)
levelLabel.Position = UDim2.fromOffset(8, 3)
levelLabel.BackgroundTransparency = 1
levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
levelLabel.TextScaled = true
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextXAlignment = Enum.TextXAlignment.Left
levelLabel.Parent = levelFrame

local barBack = Instance.new("Frame")
barBack.Size = UDim2.new(1, -16, 0, 12)
barBack.Position = UDim2.fromOffset(8, 31)
barBack.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
barBack.Parent = levelFrame
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.fromRGB(110, 200, 90)
barFill.Parent = barBack
for _, bar in { barBack, barFill } do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = bar
end

local function refreshLevel()
	local level = player:GetAttribute("Level")
	local xp = player:GetAttribute("XP")
	local nextXP = player:GetAttribute("XPNext")
	levelFrame.Visible = type(level) == "number"
	if type(level) ~= "number" then
		return
	end
	if type(xp) == "number" and type(nextXP) == "number" and nextXP > 0 then
		levelLabel.Text = `Nível {level}   {xp}/{nextXP} XP`
		barFill.Size = UDim2.fromScale(math.clamp(xp / nextXP, 0, 1), 1)
	else
		levelLabel.Text = `Nível {level} (máximo)`
		barFill.Size = UDim2.fromScale(1, 1)
	end
end
for _, attribute in { "Level", "XP", "XPNext" } do
	player:GetAttributeChangedSignal(attribute):Connect(refreshLevel)
end
refreshLevel()

button.Activated:Connect(function()
	clickRemote:FireServer()
end)

-- Ecrã pisca a vermelho sempre que o jogador perde vida (qualquer dano, mesmo pequeno).
local TweenService = game:GetService("TweenService")

local hurtGui = Instance.new("ScreenGui")
hurtGui.Name = "DamageFlash"
hurtGui.ResetOnSpawn = false
hurtGui.IgnoreGuiInset = true -- cobre o ecrã todo, incluindo a barra de cima
hurtGui.DisplayOrder = -1 -- fica por baixo do HUD

local hurt = Instance.new("Frame")
hurt.Size = UDim2.fromScale(1, 1)
hurt.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
hurt.BackgroundTransparency = 1
hurt.BorderSizePixel = 0
hurt.Active = false
hurt.Parent = hurtGui
hurtGui.Parent = player:WaitForChild("PlayerGui")

local fade = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local last = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < last then
			hurt.BackgroundTransparency = 0.55
			TweenService:Create(hurt, fade, { BackgroundTransparency = 1 }):Play()
		end
		last = health
	end)
end

player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	task.spawn(watchCharacter, player.Character)
end

-- Mensagens do servidor (genérico do kit):
-- - atributo "Estado" no jogador: faixa fixa enquanto existir (ex.: "A levar um ovo...");
-- - atributos "Aviso" + "AvisoId": mensagem que aparece uns segundos e desaparece.
local function banner(y: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(520, 40)
	label.Position = UDim2.new(0.5, -260, 0, y)
	label.BackgroundColor3 = color
	label.BackgroundTransparency = 0.2
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Visible = false
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	return label
end

local stateLabel = banner(80, Color3.fromRGB(150, 60, 20))
local noticeLabel = banner(128, Color3.fromRGB(30, 30, 45))

local function refreshState()
	local text = player:GetAttribute("Estado")
	stateLabel.Text = if type(text) == "string" then text else ""
	stateLabel.Visible = type(text) == "string" and text ~= ""
end
player:GetAttributeChangedSignal("Estado"):Connect(refreshState)
refreshState()

-- Botão de ação (genérico do kit): aparece enquanto o atributo "Acao" do jogador tiver um
-- texto (ex.: "Soltar ovos"). Clicar ou carregar em G envia o remote "Acao"; o servidor
-- decide o que fazer.
local UserInputService = game:GetService("UserInputService")
local ACTION_KEY = Enum.KeyCode.G

local actionButton = Instance.new("TextButton")
actionButton.Size = UDim2.fromOffset(220, 56)
actionButton.Position = UDim2.new(0.5, -110, 1, -200)
actionButton.BackgroundColor3 = Color3.fromRGB(200, 110, 40)
actionButton.TextColor3 = Color3.new(1, 1, 1)
actionButton.TextScaled = true
actionButton.Font = Enum.Font.GothamBold
actionButton.Visible = false
actionButton.Parent = gui
local actionCorner = Instance.new("UICorner")
actionCorner.CornerRadius = UDim.new(0, 12)
actionCorner.Parent = actionButton

local function fireAction()
	if not actionButton.Visible then
		return
	end
	task.spawn(function()
		Remotes.get("Acao"):FireServer()
	end)
end

local function refreshAction()
	local text = player:GetAttribute("Acao")
	actionButton.Visible = type(text) == "string" and text ~= ""
	actionButton.Text = if type(text) == "string" then `{text} (G)` else ""
end
player:GetAttributeChangedSignal("Acao"):Connect(refreshAction)
refreshAction()
actionButton.Activated:Connect(fireAction)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == ACTION_KEY then
		fireAction()
	end
end)

local noticeToken = 0
player:GetAttributeChangedSignal("AvisoId"):Connect(function()
	local text = player:GetAttribute("Aviso")
	if type(text) ~= "string" then
		return
	end
	noticeToken += 1
	local token = noticeToken
	noticeLabel.Text = text
	noticeLabel.Visible = true
	task.delay(4, function()
		if token == noticeToken then
			noticeLabel.Visible = false
		end
	end)
end)

gui.Parent = player:WaitForChild("PlayerGui")
