-- File: StarterPlayer/StarterPlayerScripts/WinUI.client.lua
-- Displays big center-screen win text, bottom-left victory badge, fades to black on win

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RE_Win_Announce = Remotes:WaitForChild("RE_Win_Announce")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "WinUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- Big center text
local centerText = Instance.new("TextLabel")
centerText.Size = UDim2.new(1, 0, 0, 120)
centerText.Position = UDim2.new(0, 0, 0.4, -60)
centerText.BackgroundTransparency = 1
centerText.TextScaled = true
centerText.Font = Enum.Font.GothamBlack
centerText.TextColor3 = Color3.fromRGB(255,255,255)
centerText.TextStrokeTransparency = 0.2
centerText.Text = ""
centerText.Visible = false
centerText.Parent = gui

-- Bottom-left badge
local badge = Instance.new("TextLabel")
badge.Size = UDim2.new(0, 360, 0, 46)
badge.Position = UDim2.new(0, 12, 1, -58)
badge.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
badge.BackgroundTransparency = 0.2
local badgeStroke = Instance.new("UIStroke", badge)
badgeStroke.Color = Color3.fromRGB(60,60,70)
badgeStroke.Thickness = 2
local badgeCorner = Instance.new("UICorner", badge)
badgeCorner.CornerRadius = UDim.new(0, 8)
badge.TextXAlignment = Enum.TextXAlignment.Center
badge.TextYAlignment = Enum.TextYAlignment.Center
badge.TextSize = 18
badge.Font = Enum.Font.GothamBold
badge.TextColor3 = Color3.fromRGB(255,255,255)
badge.Text = ""
badge.Visible = false
badge.Parent = gui

-- Fullscreen fade
local fade = Instance.new("Frame")
fade.BackgroundColor3 = Color3.new(0,0,0)
fade.Size = UDim2.new(1, 0, 1, 0)
fade.Position = UDim2.new(0, 0, 0, 0)
fade.BackgroundTransparency = 1
fade.Visible = true
fade.ZIndex = 10
fade.Parent = gui

local function showWin(payload)
	local winner = payload and payload.winner
	centerText.Visible = true
	badge.Visible = true
	if winner == GameConfig.TEAM.REP then
		centerText.Text = "Republic Has Won"
		centerText.TextColor3 = Color3.fromRGB(60, 120, 255)
		badge.Text = "Victory Achieved - Dominance for the Republic"
		badge.TextColor3 = Color3.fromRGB(180, 200, 255)
	else
		centerText.Text = "Separatists Have Won"
		centerText.TextColor3 = Color3.fromRGB(220, 60, 60)
		badge.Text = "Victory Achieved - Dominance for the Separatists"
		badge.TextColor3 = Color3.fromRGB(255, 180, 180)
	end
	-- Fade in text
	centerText.TextTransparency = 1
	badge.TextTransparency = 1
	TweenService:Create(centerText, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
	TweenService:Create(badge, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
	-- After 9s, fade the whole screen to black (server teleports at ~10s)
	task.delay(9, function()
		TweenService:Create(fade, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = 0 }):Play()
	end)
end

RE_Win_Announce.OnClientEvent:Connect(showWin)
