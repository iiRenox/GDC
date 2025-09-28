-- File: ServerScriptService/TestMatches/Test_SmokeStart.lua
-- Summary: Simple smoke test: logs team assignment and Bits on join.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local function logPlayer(p)
    task.wait(1)
    local teamName = p.Team and p.Team.Name or "(no team)"
    local bits = p:FindFirstChild("leaderstats") and p.leaderstats:FindFirstChild("Bits")
    local bitVal = bits and bits.Value or -1
    print(string.format("[TEST][SmokeStart] %s team=%s bits=%d (expect %d)", p.Name, teamName, bitVal, GameConfig.STARTING_BITS))
end

for _, plr in ipairs(Players:GetPlayers()) do
    logPlayer(plr)
end

Players.PlayerAdded:Connect(function(p)
    logPlayer(p)
end)


