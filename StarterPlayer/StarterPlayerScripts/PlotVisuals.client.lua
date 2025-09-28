-- File: StarterPlayer/StarterPlayerScripts/PlotVisuals.client.lua
-- Summary: Visual treatment for empty BuildPlot parts. Empty plots are 80% transparent; when the local player stands on/touches them, they become fully opaque. Reverts when leaving.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local localPlayer = Players.LocalPlayer

local plots = {} -- [BasePart] = true

local function isPlot(part)
	return part and part:IsA("BasePart") and part.Name:match("^BuildPlot_%w+_%d+_[A-H]$") ~= nil
end

local function scanPlots()
	local plotsFound = {}
	local map = workspace:FindFirstChild("Ryloth")
	if not map then return end
	for _, d in ipairs(map:GetDescendants()) do
		if isPlot(d) then
			plotsFound[d] = true
			if plots[d] == nil then
				plots[d] = true
				-- Attribute listeners keep transparency responsive
				d:GetAttributeChangedSignal("Occupied"):Connect(function()
					-- immediate visual update next tick
				end)
			end
		end
	end
	-- Remove lost references
	for p,_ in pairs(plots) do
		if plotsFound[p] ~= true then plots[p] = nil end
	end
end

local function withinPartXZ(part, worldPos)
	-- Convert to part-local space and test within XZ extents
	local localPos = part.CFrame:PointToObjectSpace(worldPos)
	local halfX = part.Size.X * 0.5
	local halfZ = part.Size.Z * 0.5
	return math.abs(localPos.X) <= (halfX + 0.2) and math.abs(localPos.Z) <= (halfZ + 0.2)
end

local function updateVisuals()
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	for part,_ in pairs(plots) do
		-- Default visual for empty plots: 80% transparent; occupied: opaque
		local occupied = part:GetAttribute("Occupied") and true or false
		local desired = 0
		if not occupied then desired = 0.8 end
		-- Player-on-plot override: while player stands on/within XZ of the plot, make opaque
		if hrp and not occupied then
			local onTop = withinPartXZ(part, hrp.Position) and (math.abs(hrp.Position.Y - part.Position.Y) <= 8)
			if onTop then desired = 0 end
		end
		-- Apply locally; do not override server Transparency
		if part.LocalTransparencyModifier ~= desired then
			part.LocalTransparencyModifier = desired
		end
	end
end

-- Initial scan and periodic refresh
scanPlots()
RunService.Heartbeat:Connect(function(step)
	updateVisuals()
end)
-- Rescan occasionally in case of map rebuild
while true do
	scanPlots()
	task.wait(2)
end
