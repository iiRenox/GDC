-- File: StarterPlayer/StarterPlayerScripts/HUD.client.lua
-- Minimal first-iteration HUD + Minimap + Shared Timer
-- Disables Roblox CoreGui (except proximity prompts), shows Bits, Hearts, Minimap, Timer, and CC health

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LOCAL_PLAYER = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RE_SharedTimerSync = Remotes:WaitForChild("RE_SharedTimerSync")
local RE_Minimap_Snapshot = Remotes:FindFirstChild("RE_Minimap_Snapshot")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- Disable all core Roblox UI (prompts unaffected)
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)

-- Build GUI
local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

-- Top-right: Bits + Hearts panel
local topRight = Instance.new("Frame")
topRight.Size = UDim2.new(0, 220, 0, 90)
topRight.Position = UDim2.new(1, -230, 0, 10)
topRight.BackgroundTransparency = 0.2
topRight.BackgroundColor3 = Color3.fromRGB(10,10,14)
local trStroke = Instance.new("UIStroke", topRight)
trStroke.Color = Color3.fromRGB(60,60,70)
trStroke.Thickness = 2
local trCorner = Instance.new("UICorner", topRight)
trCorner.CornerRadius = UDim.new(0, 8)
topRight.Parent = gui

local bitsLabel = Instance.new("TextLabel")
bitsLabel.Size = UDim2.new(1, -10, 0, 26)
bitsLabel.Position = UDim2.new(0, 5, 0, 6)
bitsLabel.BackgroundTransparency = 1
bitsLabel.Font = Enum.Font.GothamBold
bitsLabel.TextSize = 20
bitsLabel.TextXAlignment = Enum.TextXAlignment.Right
bitsLabel.TextColor3 = Color3.fromRGB(240, 210, 60)
bitsLabel.Text = "Bits: 0"
bitsLabel.Parent = topRight

local heartsLabel = Instance.new("TextLabel")
heartsLabel.Size = UDim2.new(1, -10, 0, 26)
heartsLabel.Position = UDim2.new(0, 5, 0, 36)
heartsLabel.BackgroundTransparency = 1
heartsLabel.Font = Enum.Font.GothamBold
heartsLabel.TextSize = 18
heartsLabel.TextXAlignment = Enum.TextXAlignment.Right
heartsLabel.TextColor3 = Color3.fromRGB(230,230,230)
heartsLabel.Text = "Hearts: 0/0"
heartsLabel.Parent = topRight

-- Top middle: Minimap foundation
local mini = Instance.new("Frame")
mini.Size = UDim2.new(0, 240, 0, 120)
mini.Position = UDim2.new(0.5, -120, 0, 10)
mini.BackgroundColor3 = Color3.fromRGB(15,15,20)
mini.BackgroundTransparency = 0.2
local mmStroke = Instance.new("UIStroke", mini)
mmStroke.Color = Color3.fromRGB(60,60,70)
mmStroke.Thickness = 2
local mmCorner = Instance.new("UICorner", mini)
mmCorner.CornerRadius = UDim.new(0, 8)
mini.Parent = gui

local miniCanvas = Instance.new("Frame")
miniCanvas.Name = "Canvas"
miniCanvas.BackgroundTransparency = 1
miniCanvas.Size = UDim2.new(1, -8, 1, -8)
miniCanvas.Position = UDim2.new(0, 4, 0, 4)
miniCanvas.Parent = mini
-- Latest minimap snapshot from server
local latestSnapshot = nil
if RE_Minimap_Snapshot then
    RE_Minimap_Snapshot.OnClientEvent:Connect(function(payload)
        latestSnapshot = payload
    end)
end

-- Bottom middle: Shared Timer + CC health
local bottom = Instance.new("Frame")
bottom.Size = UDim2.new(0, 420, 0, 72)
bottom.Position = UDim2.new(0.5, -210, 1, -82)
bottom.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
bottom.BackgroundTransparency = 0.2
local bStroke = Instance.new("UIStroke", bottom)
bStroke.Color = Color3.fromRGB(60,60,70)
bStroke.Thickness = 2
local bCorner = Instance.new("UICorner", bottom)
bCorner.CornerRadius = UDim.new(0, 8)
bottom.Parent = gui

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(0, 160, 1, 0)
timerLabel.Position = UDim2.new(0.5, -80, 0, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.Font = Enum.Font.GothamBlack
timerLabel.TextSize = 28
timerLabel.TextColor3 = Color3.fromRGB(240,240,180)
timerLabel.Text = "00:00"
timerLabel.Parent = bottom

local leftCC = Instance.new("TextLabel")
leftCC.Size = UDim2.new(0, 120, 1, 0)
leftCC.Position = UDim2.new(0, 12, 0, 0)
leftCC.BackgroundTransparency = 1
leftCC.Font = Enum.Font.GothamBold
leftCC.TextSize = 16
leftCC.TextColor3 = Color3.fromRGB(255, 70, 70)
leftCC.TextXAlignment = Enum.TextXAlignment.Left
leftCC.Text = "CIS CC: --%"
leftCC.Parent = bottom

local rightCC = Instance.new("TextLabel")
rightCC.Size = UDim2.new(0, 120, 1, 0)
rightCC.Position = UDim2.new(1, -132, 0, 0)
rightCC.BackgroundTransparency = 1
rightCC.Font = Enum.Font.GothamBold
rightCC.TextSize = 16
rightCC.TextColor3 = Color3.fromRGB(80, 120, 255)
rightCC.TextXAlignment = Enum.TextXAlignment.Right
rightCC.Text = "REP CC: --%"
rightCC.Parent = bottom

-- Shared timer start epoch
local startEpoch: number? = nil
RE_SharedTimerSync.OnClientEvent:Connect(function(payload)
	if payload and payload.startEpoch then
		startEpoch = payload.startEpoch
	end
end)

-- Listen to Bits leaderstats
local function updateBits()
	local ls = LOCAL_PLAYER:FindFirstChild("leaderstats")
	local bits = ls and ls:FindFirstChild("Bits")
	bitsLabel.Text = string.format("Bits: %s", bits and bits.Value or 0)
end

local function hookBits()
	local ls = LOCAL_PLAYER:FindFirstChild("leaderstats")
	if not ls then return end
	local bits = ls:FindFirstChild("Bits")
	if bits and bits:IsA("IntValue") then
		bits:GetPropertyChangedSignal("Value"):Connect(updateBits)
		updateBits()
	end
end

LOCAL_PLAYER.CharacterAdded:Connect(function()
	task.wait(0.2)
	hookBits()
end)
if LOCAL_PLAYER.Character then hookBits() end

-- Hearts: show vehicle/building health if seated in a model with Health IntValue; otherwise humanoid health
local function findVehicleHealth()
	local char = LOCAL_PLAYER.Character
	if not char then return nil, nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return nil, nil end
	-- Check seats
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("Seat") or p:IsA("VehicleSeat") then
			if p.Occupant == hum then
				local m = p:FindFirstAncestorWhichIsA("Model")
				if m then
					local hv = m:FindFirstChild("Health")
					if hv and hv:IsA("IntValue") then
						return hv, hv:GetAttribute("Max") or hv.Value
					end
				end
			end
		end
	end
	return hum, hum.MaxHealth
end

local function updateHearts()
	local hv, max = findVehicleHealth()
	if hv and hv:IsA("IntValue") then
		heartsLabel.Text = string.format("Hearts: %d/%d", hv.Value, max or hv.Value)
	else
		local char = LOCAL_PLAYER.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			heartsLabel.Text = string.format("Hearts: %d/%d", math.floor(hum.Health/10), math.floor(hum.MaxHealth/10))
		end
	end
end

RunService.Heartbeat:Connect(function()
	updateHearts()
end)

-- Minimap foundation: draw player arrow and CC dots (approx.)
local function scanCommandCenters()
	local cis, rep = nil, nil
	for _, m in ipairs(Workspace:GetDescendants()) do
		if m:IsA("Model") and m.Name:find("CommandCenter") then
			if m.Name:find("Rep") then rep = m elseif m.Name:find("CIS") then cis = m end
		end
	end
	return cis, rep
end

local function drawMinimap()
    miniCanvas:ClearAllChildren()
    local char = LOCAL_PLAYER.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    -- Draw player arrow
    if hrp then
        local arrow = Instance.new("Frame")
        arrow.Size = UDim2.new(0, 10, 0, 10)
        arrow.BackgroundTransparency = 1
        arrow.BackgroundColor3 = Color3.fromRGB(240,240,240)
        arrow.AnchorPoint = Vector2.new(0.5, 0.5)
        arrow.Position = UDim2.new(0.5, 0, 0.5, 0)
        arrow.Parent = miniCanvas
    end
    if latestSnapshot and latestSnapshot.cores and #latestSnapshot.cores > 0 then
        local n = #latestSnapshot.cores
        for i, core in ipairs(latestSnapshot.cores) do
            local frac = (i - 0.5) / n
            local owner = core.ownerTeam
            local col = Color3.fromRGB(200, 200, 200)
            if owner == 1 then col = Color3.fromRGB(255, 70, 70) end
            if owner == 2 then col = Color3.fromRGB(80, 120, 255) end
            local center = Instance.new("Frame")
            center.Size = UDim2.new(0, 8, 0, 8)
            center.BackgroundColor3 = col
            center.AnchorPoint = Vector2.new(0.5, 0.5)
            center.Position = UDim2.new(frac, 0, 0.5, 0)
            center.Parent = miniCanvas
            if core.plots then
                local idx = 0
                for _, p in ipairs(core.plots) do
                    idx += 1
                    local yoff = (idx % 2 == 0) and -10 or 10
                    local pl = Instance.new("Frame")
                    pl.Size = UDim2.new(0, 6, 0, 6)
                    pl.BackgroundColor3 = p.occupied and col or Color3.fromRGB(120,120,120)
                    pl.AnchorPoint = Vector2.new(0.5, 0.5)
                    pl.Position = UDim2.new(frac, (idx-1)*2, 0.5, yoff)
                    pl.Parent = miniCanvas
                end
            end
        end
    else
        local cis, rep = scanCommandCenters()
        if cis then
            local dot = Instance.new("Frame")
            dot.Size = UDim2.new(0, 8, 0, 8)
            dot.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
            dot.Position = UDim2.new(0.25, 0, 0.5, 0)
            dot.AnchorPoint = Vector2.new(0.5, 0.5)
            dot.Parent = miniCanvas
        end
        if rep then
            local dot = Instance.new("Frame")
            dot.Size = UDim2.new(0, 8, 0, 8)
            dot.BackgroundColor3 = Color3.fromRGB(60, 100, 240)
            dot.Position = UDim2.new(0.75, 0, 0.5, 0)
            dot.AnchorPoint = Vector2.new(0.5, 0.5)
            dot.Parent = miniCanvas
        end
    end
end

-- CC health readout bottom panel
local function getPercent(hv)
    if not hv then return "--" end
    local max = hv:GetAttribute("Max") or hv.Value
    if max <= 0 then return "0" end
    return tostring(math.floor((math.clamp(hv.Value, 0, max)/max)*100 + 0.5))
end

local function updateBottomPanel()
	local cis, rep = scanCommandCenters()
	local cisHv = cis and cis:FindFirstChild("Health")
	local repHv = rep and rep:FindFirstChild("Health")
	-- Remove BackgroundTransparency for center and plot squares
    for _, c in ipairs(miniCanvas:GetDescendants()) do
        if c:IsA("Frame") then
            c.BackgroundTransparency = 0.2
        end
    end
	leftCC.Text = string.format("CIS CC: %s%%", getPercent(cisHv))
	rightCC.Text = string.format("REP CC: %s%%", getPercent(repHv))
	-- Timer
	if not startEpoch then return end
	local now = os.time()
	local elapsed = now - startEpoch
	if elapsed < 0 then elapsed = 0 end
	local minutes = math.floor(elapsed/60)
	local seconds = elapsed % 60
	timerLabel.Text = string.format("%02d:%02d", minutes, seconds)
end

-- Heartbeat updates
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc >= 0.5 then
		acc = 0
		updateBottomPanel()
		drawMinimap()
	end
end)

