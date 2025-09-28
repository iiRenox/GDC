-- File: ServerScriptService/TestMatches/Test_BuildFlow.lua
-- Summary: Simple diagnostic to print category availability per core for each player and verify costs/limits in payload.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local BuildManager = require(ServerScriptService:WaitForChild("Services"):WaitForChild("BuildManager"))

local function getAllCoreIds()
    local ids = {}
    local mapFolder = Workspace:FindFirstChild("Ryloth")
    if not mapFolder then return ids end
    for _, child in ipairs(mapFolder:GetChildren()) do
        if child:IsA("Folder") and (child.Name:match("^Core_Rep_%d+$") or child.Name:match("^Core_CIS_%d+$")) then
            table.insert(ids, child.Name)
        end
    end
    table.sort(ids)
    return ids
end

local function stringifyCats(arr)
    local t = {}
    for i,v in ipairs(arr or {}) do table.insert(t, string.format("%d:%s", i, v and "T" or "F")) end
    return table.concat(t, ",")
end

local function ownerToString(owner)
    if owner == GameConfig.TEAM.REP then return "REP" end
    if owner == GameConfig.TEAM.CIS then return "CIS" end
    return "NEUTRAL"
end

local function logCoreStatus(coreId)
    local core = BuildManager:GetCore(coreId)
    if not core then
        print(string.format("[TEST][BuildFlow] core=%s not registered", tostring(coreId)))
        return
    end
    local status = BuildManager:GetCoreStatus(coreId)
    local ownerStr = ownerToString(status and status.ownerTeam)
    local contested = (core.contested and true) or false
    local ringState = (core.colorRing and core.colorRing.Parent) and (core.colorRing.Transparency < 1 and "VISIBLE" or "HIDDEN") or "MISSING"
    local ballHasFX = (core.fxBall and core.fxBall.ball and core.fxBall.beam) and true or false
    print(string.format("[TEST][Core] id=%s owner=%s contested=%s ring=%s ballFX=%s", coreId, ownerStr, tostring(contested), ringState, tostring(ballHasFX)))
    -- Plot occupied flags
    local occupiedCount, total = 0, 0
    for letter, plot in pairs(core.plots or {}) do
        total += 1
        local occ = plot.occupied and true or false
        if occ then occupiedCount += 1 end
    end
    print(string.format("[TEST][Core] id=%s plots=%d occupied=%d", coreId, total, occupiedCount))
end

Players.PlayerAdded:Connect(function(p)
    task.wait(1)
    local teamName = p.Team and p.Team.Name or "(no team)"
    print(string.format("[TEST][BuildFlow] Player %s joined team=%s", p.Name, teamName))
    local coreIds = getAllCoreIds()
    for _, cid in ipairs(coreIds) do
        local cats = BuildManager:GetAvailableCategoriesForPlayer(p, cid)
        print(string.format("[TEST][BuildFlow] core=%s cats=[%s]", cid, stringifyCats(cats)))
        logCoreStatus(cid)
    end
    -- Re-log after short delay to observe ownership + visuals stabilization
    task.delay(3, function()
        for _, cid in ipairs(getAllCoreIds()) do logCoreStatus(cid) end
    end)
end)
