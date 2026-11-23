--!strict
-- Limpeza de scripts de terceiros (backdoors de modelos da Toolbox).
-- NÃO é sincronizado pelo Rojo: é para colar na Command Bar do Studio, em modo de edição.
-- Apaga a pasta "Ant Life Ragdolls" e todos os scripts que não sejam do kit/jogo
-- (Server, Game, Shared, Client). Ctrl+Z desfaz tudo de uma vez.
-- Correr de novo sempre que inserir um modelo da Toolbox.

local CHS = game:GetService("ChangeHistoryService")
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local OURS = {
	SSS:FindFirstChild("Server"),
	SSS:FindFirstChild("Game"),
	RS:FindFirstChild("Shared"),
	RS:FindFirstChild("Game"),
	SPS and SPS:FindFirstChild("Client"),
}
local function isOurs(i: Instance): boolean
	for _, r in OURS do
		if r and (i == r or i:IsDescendantOf(r)) then
			return true
		end
	end
	return false
end
local okRec, rec = pcall(function()
	return CHS:TryBeginRecording("Limpeza de scripts")
end)
local removed, suspicious = 0, 0
local folder = workspace:FindFirstChild("Ant Life Ragdolls")
if folder then
	folder:Destroy()
	print("[Limpeza] apagada a pasta Ant Life Ragdolls")
end
for _, name in
	{
		"Workspace",
		"ServerScriptService",
		"ServerStorage",
		"ReplicatedStorage",
		"ReplicatedFirst",
		"StarterGui",
		"StarterPack",
		"StarterPlayer",
		"Lighting",
		"SoundService",
		"Teams",
		"TextChatService",
		"MaterialService",
	}
do
	local ok, service = pcall(game.GetService, game, name)
	if ok and service then
		for _, item in service:GetDescendants() do
			if item:IsA("LuaSourceContainer") then
				if isOurs(item) then
					local src = (item :: any).Source :: string
					if src:find("getfenv") or src:find("loadstring") or src:find("require%s*%(%s*%d") then
						warn("[Limpeza] ATENÇÃO: código suspeito num script nosso: " .. item:GetFullName())
						suspicious += 1
					end
				else
					print("[Limpeza] apagado: " .. item:GetFullName())
					item:Destroy()
					removed += 1
				end
			end
		end
	end
end
if okRec and rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
print(`[Limpeza] terminado: {removed} scripts apagados, {suspicious} avisos nos nossos scripts`)
