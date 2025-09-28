-- Ensures Roblox CoreGui (Topbar, PlayerList, etc.) is fully disabled for every player
local StarterGui = game:GetService("StarterGui")

local function disableAllCoreGui()
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
        -- Explicitly enable Chat only
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
        -- And keep everything else off
        StarterGui:SetCore("TopbarEnabled", false)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
    end)
end

disableAllCoreGui()
-- Re-assert disabling on respawn and after short delay to handle Roblox enabling behaviors
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
lp.CharacterAdded:Connect(function()
	task.wait(0.25)
	disableAllCoreGui()
end)

-- Periodic check (cheap) to ensure UI stays disabled in edge cases
while true do
	task.wait(5)
	disableAllCoreGui()
end
