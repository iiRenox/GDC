-- File: ReplicatedStorage/Modules/HeartSystem.lua
-- Modified/Created by: GPT-5 (Cursor) — 2025-08-09
-- Based on: New module
-- Summary: Multi-stage heart system with stun and callbacks.

local HeartSystem = {}

local units = {}
local listeners = { StageTransition = {}, Destroyed = {} }

local function emit(eventName, ...)
    for _, cb in ipairs(listeners[eventName]) do
        task.spawn(cb, ...)
    end
end

function HeartSystem:On(eventName, callback)
    if listeners[eventName] then table.insert(listeners[eventName], callback) end
end

function HeartSystem:RegisterUnit(unitId: string, initial)
    units[unitId] = {
        stage2 = initial.stage2 or 0,
        stage1 = initial.stage1 or 0,
        normal = initial.normal or 0,
        purple = initial.purple or 0,
        currentStage = initial.currentStage or (initial.purple and initial.purple > 0 and "purple") or (initial.stage2 and initial.stage2 > 0 and "stage2") or (initial.stage1 and initial.stage1 > 0 and "stage1") or "normal",
        stunnedUntil = 0,
    }
end

function HeartSystem:IsAlive(unitId)
    local u = units[unitId]
    if not u then return false end
    if u.currentStage == "normal" then return u.normal > 0 end
    if u.currentStage == "stage1" then return u.stage1 > 0 or u.normal > 0 end
    if u.currentStage == "stage2" then return u.stage2 > 0 or u.stage1 > 0 or u.normal > 0 end
    if u.currentStage == "purple" then return u.purple > 0 end
    return false
end

function HeartSystem:GetHealthPercent(unitId)
    local u = units[unitId]
    if not u then return 0 end
    local total, current = 0, 0
    total += u.purple or 0; current += u.purple or 0
    total += u.stage2 or 0; current += u.stage2 or 0
    total += u.stage1 or 0; current += u.stage1 or 0
    total += u.normal or 0; current += u.normal or 0
    if total <= 0 then return 0 end
    return math.clamp((current/total) * 100, 0, 100)
end

function HeartSystem:ForceTransition(unitId, newStage: string)
    local u = units[unitId]
    if not u then return end
    u.currentStage = newStage
    emit("StageTransition", unitId, newStage)
end

function HeartSystem:TakeHit(unitId, damageType: string, attacker)
    local u = units[unitId]
    if not u then return end
    local now = os.clock()
    if now < (u.stunnedUntil or 0) then return end

    local function applyStun()
        local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("GameConfig"))
        local dur = (GameConfig.DEFAULTS and GameConfig.DEFAULTS.STUN_DURATION) or 2
        u.stunnedUntil = now + dur
        return dur
    end

    local stage = u.currentStage
    if stage == "purple" then
        u.purple = math.max(0, (u.purple or 0) - 1)
        if u.purple <= 0 then
            emit("Destroyed", unitId, attacker)
        end
        return
    elseif stage == "stage2" then
        u.stage2 = math.max(0, (u.stage2 or 0) - 1)
        if u.stage2 <= 0 then
            local dur = applyStun()
            u.currentStage = "stage1"
            emit("StageTransition", unitId, "stage1", dur)
        end
        return
    elseif stage == "stage1" then
        u.stage1 = math.max(0, (u.stage1 or 0) - 1)
        if u.stage1 <= 0 then
            local dur = applyStun()
            u.currentStage = "normal"
            emit("StageTransition", unitId, "normal", dur)
        end
        return
    else -- normal
        u.normal = math.max(0, (u.normal or 0) - 1)
        if u.normal <= 0 then
            emit("Destroyed", unitId, attacker)
        end
    end
end

return HeartSystem


