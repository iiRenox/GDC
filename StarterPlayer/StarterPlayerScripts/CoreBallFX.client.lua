-- File: StarterPlayer/StarterPlayerScripts/CoreBallFX.client.lua
-- Client-side hover + lightning FX for core balls. Server is disabled for performance.
-- Detects per-core plot occupancy (Occupied attribute) and local player presence on plots.
-- When shouldHover = occupied or local player on a plot, start a TweenService loop and enable beams.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LOCAL_PLAYER = Players.LocalPlayer

local stateByCore = {}
local scanInterval = 0.5 -- seconds between occupancy re-evaluation
local presenceMaxY = 12

-- Adjustable hover parameters
-- HOVER_MIN: distance above plate surface (studs) at lowest point
-- HOVER_MAX: distance above plate surface (studs) at highest point
-- HOVER_TIME: tween time from min->max or max->min
-- ROT_SPEED: degrees added per tween step on each axis (X, Y, Z)
local HOVER_MIN = 2.0
local HOVER_MAX = 5.0
local HOVER_TIME = 1.4
local ROT_SPEED = Vector3.new(60, 120, 80)

local function withinPartXZ(part, worldPos)
	local localPos = part.CFrame:PointToObjectSpace(worldPos)
	local halfX = part.Size.X * 0.5
	local halfZ = part.Size.Z * 0.5
	return math.abs(localPos.X) <= (halfX + 0.2) and math.abs(localPos.Z) <= (halfZ + 0.2)
end

local function getHRP()
	local char = LOCAL_PLAYER.Character or LOCAL_PLAYER.CharacterAdded:Wait()
	return char:FindFirstChild("HumanoidRootPart")
end

local function findPartByNamePattern(root, pattern)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Name:match(pattern) then
			return d
		end
	end
	return nil
end

local function findBallAndPlate(coreFolder)
	local sideName = coreFolder.Name:match("^Core_(Rep)_%d+$") or coreFolder.Name:match("^Core_(CIS)_%d+$")
	local idx = coreFolder.Name:match("^Core_%w+_(%d+)$")
	local plate = coreFolder:FindFirstChild(string.format("Core_%s_%s_Plate", sideName or "Rep", idx or "1"), true)
	if not (plate and plate:IsA("BasePart")) then
		-- Fallback: any descendant containing 'Plate'
		for _, d in ipairs(coreFolder:GetDescendants()) do
			if d:IsA("BasePart") and string.find(d.Name, "Plate", 1, true) then plate = d break end
		end
	end
	local ball = coreFolder:FindFirstChild(string.format("Core_%s_%s_Ball", sideName or "Rep", idx or "1"), true)
	if not (ball and ball:IsA("BasePart")) then
		ball = coreFolder:FindFirstChild(string.format("Core_%s_%s_Bal", sideName or "Rep", idx or "1"), true)
	end
	if not (ball and ball:IsA("BasePart")) then
		-- Fallback: any descendant whose name contains 'Ball' or 'Bal'
		for _, d in ipairs(coreFolder:GetDescendants()) do
			if d:IsA("BasePart") and (string.find(d.Name, "Ball", 1, true) or string.find(d.Name, "Bal", 1, true)) then ball = d break end
		end
	end
	return ball, plate
end

local function collectPlots(coreFolder)
	local plots = {}
	for _, d in ipairs(coreFolder:GetDescendants()) do
		if d:IsA("BasePart") and d.Name:match("^BuildPlot_%w+_%d+_[A-H]$") then
			table.insert(plots, d)
		end
	end
	return plots
end

local function ensureFX(core)
	local st = stateByCore[core]
	if not st then return end
	if st.fxInitialized then return end
	st.fxInitialized = true
	-- Attachments
	st.attPlate = Instance.new("Attachment")
	st.attPlate.Name = "FX_Att_Plate_Client"
	st.attPlate.Parent = st.plate
	st.attBall = Instance.new("Attachment")
	st.attBall.Name = "FX_Att_Ball_Client"
	st.attBall.Parent = st.renderBall
	-- Central beam
	st.beam = Instance.new("Beam")
	st.beam.Name = "FX_CoreBeam_Client"
	st.beam.Attachment0 = st.attPlate
	st.beam.Attachment1 = st.attBall
	st.beam.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
	st.beam.Width0 = 0.3
	st.beam.Width1 = 0.3
	st.beam.Brightness = 2
	st.beam.Transparency = NumberSequence.new(0.1)
	st.beam.FaceCamera = true
	st.beam.Enabled = false
	st.beam.Parent = st.plate
	-- Simple static rim arcs (no flicker)
	st.rimAtts = {}
	st.arcs = {}
	local rimRadius = math.max(st.plate.Size.X, st.plate.Size.Z) * 0.45
	for i = 1, 4 do
		local att = Instance.new("Attachment")
		att.Name = string.format("FX_Att_RimC_%d", i)
		local angle = (i / 4) * math.pi * 2
		att.Position = Vector3.new(math.cos(angle) * rimRadius, 0.2, math.sin(angle) * rimRadius)
		att.Parent = st.plate
		st.rimAtts[i] = att
		local b = Instance.new("Beam")
		b.Name = string.format("FX_ArcC_%d", i)
		b.Attachment0 = att
		b.Attachment1 = st.attBall
		b.Color = ColorSequence.new(Color3.fromRGB(180, 220, 255))
		b.Width0 = 0.12
		b.Width1 = 0.05
		b.Brightness = 1.5
		b.Transparency = NumberSequence.new(0.25)
		b.FaceCamera = false
		b.Enabled = false
		b.Parent = st.plate
		st.arcs[i] = b
	end
end
local function setFXEnabled(core, on)
    local st = stateByCore[core]
    if not st or not st.fxInitialized then return end
    if st.beam then st.beam.Enabled = on end
    if st.arcs then
        for _, a in ipairs(st.arcs) do if a then a.Enabled = on end end
    end
    st.rotX, st.rotY, st.rotZ = 0, 0, 0
end

local function stopHover(core)
    local st = stateByCore[core]
    if not st then return end
    st.shouldHover = false
    if st.bobTween then pcall(function() st.bobTween:Cancel() end) end
    st.bobTween = nil
    setFXEnabled(core, false)
    -- Rest ball on plate
    if st.renderBall and st.renderBall.Parent and st.plate then
        local y = st.plate.Position.Y + (st.renderBall.Size.Y * 0.5)
        st.centerCFrame = CFrame.new(Vector3.new(st.plate.Position.X, y, st.plate.Position.Z))
        st.renderBall.CFrame = st.centerCFrame
        st.rotX, st.rotY, st.rotZ = 0, 0, 0
    end
end

local function hoverStep(core)
    local st = stateByCore[core]
    if not st or not st.shouldHover or not (st.renderBall and st.renderBall.Parent and st.centerCFrame) then return end
    local goingUp = (st.bobDir or 1) == 1
    local targetHeight = goingUp and HOVER_MAX or HOVER_MIN
    -- accumulate continuous rotation for all axes
    st.rotX = ((st.rotX or 0) + ROT_SPEED.X) % 360
    st.rotY = ((st.rotY or 0) + ROT_SPEED.Y) % 360
    st.rotZ = ((st.rotZ or 0) + ROT_SPEED.Z) % 360
    local target = st.centerCFrame * CFrame.new(0, targetHeight, 0)
        * CFrame.Angles(math.rad(st.rotX), math.rad(st.rotY), math.rad(st.rotZ))
    local tw = TweenService:Create(st.renderBall, TweenInfo.new(HOVER_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = target })
    st.bobTween = tw
    tw.Completed:Connect(function()
        if not st.shouldHover then return end
        st.bobDir = -((st.bobDir or 1))
        hoverStep(core)
    end)
    tw:Play()
end

local function startHover(core)
    local st = stateByCore[core]
    if not st then return end
    if st.shouldHover then return end
    st.shouldHover = true
    -- Center CFrame from plate surface for consistent min/max heights across cores
    local y = st.plate.Position.Y + (st.renderBall.Size.Y * 0.5)
    st.centerCFrame = CFrame.new(Vector3.new(st.plate.Position.X, y, st.plate.Position.Z))
    -- Anchor locally to avoid physics jitter (client-only clone)
    pcall(function()
        st.renderBall.Anchored = true
        st.renderBall.CanCollide = false
    end)
    ensureFX(core)
    setFXEnabled(core, true)
    -- Initialize at min height and reset spin, then go upward first
    st.renderBall.CFrame = st.centerCFrame * CFrame.new(0, HOVER_MIN, 0)
    st.rotX, st.rotY, st.rotZ = 0, 0, 0
    st.bobDir = 1 -- go to max on first tween
    hoverStep(core)
end

local function recomputeShouldHover(core)
    local st = stateByCore[core]
    if not st then return end
    local occupied = false
    for _, p in ipairs(st.plots) do
        if p:GetAttribute("Occupied") then
            occupied = true
            break
        end
    end
    if not occupied then
        for _, d in ipairs(core:GetDescendants()) do
            if d:IsA("Model") and d:GetAttribute("IsBuilding") and d.Parent then
                occupied = true
                break
            end
        end
    end
    -- Presence on any plot (local player only)
    local hrp = getHRP()
    local present = false
    if hrp then
        for _, p in ipairs(st.plots) do
            if withinPartXZ(p, hrp.Position) and math.abs(hrp.Position.Y - p.Position.Y) <= presenceMaxY then
                present = true
                break
            end
        end
    end
    return occupied or present
end

local function trackCore(coreFolder)
	local ball, plate = findBallAndPlate(coreFolder)
	if not (ball and plate) then return end
	stateByCore[coreFolder] = stateByCore[coreFolder] or {}
	local st = stateByCore[coreFolder]
	st.ball = ball
	st.plate = plate
	st.plots = collectPlots(coreFolder)
	-- Create a client-only clone for smooth local animation
	if not st.renderBall or not st.renderBall.Parent then
		local clone = ball:Clone()
		clone.Name = ball.Name .. "_Client"
		clone.Anchored = true
		clone.CanCollide = false
		clone.CFrame = ball.CFrame
		clone.Parent = Workspace
		st.renderBall = clone
		-- Hide the original ball for this client only
		pcall(function() ball.LocalTransparencyModifier = 1 end)
	end
	-- React to Occupied attribute changes
	for _, p in ipairs(st.plots) do
		p:GetAttributeChangedSignal("Occupied"):Connect(function()
			local should = recomputeShouldHover(coreFolder)
			if should then startHover(coreFolder) else stopHover(coreFolder) end
		end)
	end
	-- Initial state
	local should = recomputeShouldHover(coreFolder)
	if should then startHover(coreFolder) else stopHover(coreFolder) end
end

local function scan()
	local map = Workspace:FindFirstChild("Ryloth")
	if not map then return end
	for _, child in ipairs(map:GetChildren()) do
		if child:IsA("Folder") and (child.Name:match("^Core_Rep_%d+$") or child.Name:match("^Core_CIS_%d+$")) then
			if not stateByCore[child] then
				trackCore(child)
			end
		end
	end
end

-- Periodic scan for new cores, and presence reevaluation
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc >= scanInterval then
		acc = 0
		scan()
		-- Recheck hover state (presence can change)
		for core, _ in pairs(stateByCore) do
			local should = recomputeShouldHover(core)
			if should and not stateByCore[core].shouldHover then
				startHover(core)
			elseif (not should) and stateByCore[core].shouldHover then
				stopHover(core)
			end
		end
	end
end)
