-- File: ReplicatedStorage/Modules/HeartSystem.lua
-- Summary: Manages the multi-stage health, damage, and destruction of all game units.

local HeartSystem = {}
HeartSystem.__index = HeartSystem

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Debris = game:GetService("Debris")

--[[
    Private data store for all registered units.
    Structure:
    {
        [unitId] = {
            instance = Instance,
            hearts = {
                purple = number,
                stage2 = number,
                stage1 = number,
                normal = number,
            },
            initialCounts = { ... }, -- To calculate percentages
            currentStage = "purple" | "stage2" | "stage1" | "normal",
            isAlive = true,
            isStunned = false,
        }
    }
]]
local units = {}

-- Simple event dispatcher
local eventListeners = {
    StageTransition = {},
    Destroyed = {},
    Stunned = {},
}

function HeartSystem.On(eventName, callback)
    if eventListeners[eventName] then
        table.insert(eventListeners[eventName], callback)
    else
        warn("[HeartSystem] Attempted to subscribe to a non-existent event:", eventName)
    end
end

local function fireEvent(eventName, ...)
    if eventListeners[eventName] then
        for _, callback in ipairs(eventListeners[eventName]) do
            -- Use task.spawn to prevent one listener's error from stopping others
            task.spawn(callback, ...)
        end
    end
end

local function applyStun(unitData)
    if unitData.isStunned then return end
    unitData.isStunned = true
    fireEvent("Stunned", unitData.id, true)

    task.delay(GameConfig.DEFAULTS.STUN_DURATION, function()
        -- Ensure the unit still exists and hasn't been destroyed
        if units[unitData.id] and units[unitData.id].isAlive then
            units[unitData.id].isStunned = false
            fireEvent("Stunned", unitData.id, false)
        end
    end)
end

local function handleDestruction(unitData, attacker)
    unitData.isAlive = false
    fireEvent("Destroyed", unitData.id, attacker)
    -- Clean up the unit from the system after a delay to allow listeners to react
    task.delay(5, function()
        if units[unitData.id] == unitData then
            units[unitData.id] = nil
        end
    end)
end

-- Public API Methods

function HeartSystem.RegisterUnit(unitId, initialStagesTable, instance)
    if not unitId or not initialStagesTable then
        warn("[HeartSystem] RegisterUnit failed: invalid unitId or initialStagesTable.")
        return
    end

    local hearts = {
        purple = initialStagesTable.purple or 0,
        stage2 = initialStagesTable.stage2 or 0,
        stage1 = initialStagesTable.stage1 or 0,
        normal = initialStagesTable.normal or 0,
    }

    local currentStage
    if hearts.purple > 0 then currentStage = "purple"
    elseif hearts.stage2 > 0 then currentStage = "stage2"
    elseif hearts.stage1 > 0 then currentStage = "stage1"
    elseif hearts.normal > 0 then currentStage = "normal"
    else
        warn("[HeartSystem] RegisterUnit failed: unit has no hearts.", unitId)
        return
    end

    units[unitId] = {
        id = unitId,
        instance = instance,
        hearts = hearts,
        initialCounts = table.clone(hearts),
        currentStage = currentStage,
        isAlive = true,
        isStunned = false,
    }
    --print("[HeartSystem] Registered unit:", unitId, "with stage", currentStage)
end

function HeartSystem.TakeHit(unitId, damageType, attacker)
    local unitData = units[unitId]
    if not unitData or not unitData.isAlive or unitData.isStunned then
        return
    end

    local stage = unitData.currentStage
    local hearts = unitData.hearts

    -- Special damage type rules
    if damageType == "Torpedo" then
        if stage ~= "purple" then return end -- Torpedoes only damage purple hearts
        hearts.purple -= 1
    elseif damageType == "Tesla" then
        -- Tesla melts through all stages without stunning
        local stages = {"purple", "stage2", "stage1", "normal"}
        for _, s in ipairs(stages) do
            if hearts[s] > 0 then
                hearts[s] -= 1
                stage = s -- Update stage to the one that was hit
                break
            end
        end
    else
        -- Standard damage
        hearts[stage] -= 1
    end

    -- Check for stage transition or destruction
    if hearts[stage] <= 0 then
        local oldStage = stage
        local newStage = nil

        if stage == "purple" then
            if damageType == "Torpedo" then
                newStage = "stage2"
                applyStun(unitData)
            else
                -- Destroyed by non-torpedo damage (e.g., Tesla)
                handleDestruction(unitData, attacker)
                return
            end
        elseif stage == "stage2" then
            newStage = "stage1"
            applyStun(unitData)
        elseif stage == "stage1" then
            newStage = "normal"
            applyStun(unitData)
        elseif stage == "normal" then
            handleDestruction(unitData, attacker)
            return
        end

        if newStage then
            unitData.currentStage = newStage
            fireEvent("StageTransition", unitId, oldStage, newStage)
        end
    end
end

function HeartSystem.GetHealthPercent(unitId)
    local unitData = units[unitId]
    if not unitData then return 0 end

    local currentTotal = 0
    local initialTotal = 0

    for stage, count in pairs(unitData.hearts) do
        currentTotal += count
    end
    for stage, count in pairs(unitData.initialCounts) do
        initialTotal += count
    end

    if initialTotal == 0 then return 0 end
    return (currentTotal / initialTotal) * 100
end

function HeartSystem.IsAlive(unitId)
    local unit = units[unitId]
    return unit and unit.isAlive
end

function HeartSystem.GetUnitData(unitId)
    return units[unitId]
end

function HeartSystem.ForceTransition(unitId, newStage)
    local unitData = units[unitId]
    if not unitData or not unitData.isAlive then return end

    if unitData.hearts[newStage] and unitData.hearts[newStage] > 0 then
        local oldStage = unitData.currentStage
        unitData.currentStage = newStage
        fireEvent("StageTransition", unitId, oldStage, newStage)
    else
        warn("[HeartSystem] ForceTransition failed: invalid or empty target stage:", newStage)
    end
end

return HeartSystem