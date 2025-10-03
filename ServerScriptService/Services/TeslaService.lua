-- File: ServerScriptService/Services/TeslaService.lua
-- Summary: Manages Tesla Coil buildings, including targeting AI and damage.
-- This version is corrected for performance and proper lifecycle management.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local CombatService = require(ServerScriptService.Services:WaitForChild("CombatService"))

local TeslaService = {}
TeslaService.Name = "TeslaService"

local activeTeslas = {} -- { [Model] = { state } }

-- Constants
local TESLA_RANGE = 135
local TESLA_FIRE_RATE = 0.25 -- 4hz tick rate
local TESLA_DAMAGE_PER_SECOND = 100
local TESLA_DAMAGE_PER_TICK = TESLA_DAMAGE_PER_SECOND * TESLA_FIRE_RATE

-- --- Main Loop ---
local function onHeartbeat(dt)
    for tesla, state in pairs(activeTeslas) do
        if not tesla or not tesla.Parent then
            TeslaService:Unregister(tesla)
            continue
        end

        state.cooldown = state.cooldown - dt
        if state.cooldown > 0 then continue end
        state.cooldown = TESLA_FIRE_RATE

        -- Find potential targets in radius
        local searchCenter = state.model.PrimaryPart.Position
        local partsInRadius = Workspace:GetPartsInRadius(searchCenter, TESLA_RANGE)

        local bestTarget = nil
        local minDistance = TESLA_RANGE + 1

        for _, part in ipairs(partsInRadius) do
            local targetModel = part:FindFirstAncestorWhichIsA("Model")
            if targetModel and targetModel:FindFirstChildOfClass("Humanoid") then
                 -- Check if it's an enemy
                local targetTeam = targetModel:GetAttribute("OwnerTeam")
                if not targetTeam then
                    local player = Players:GetPlayerFromCharacter(targetModel)
                    if player then targetTeam = player:GetAttribute("TeamId") end
                end

                if targetTeam and targetTeam ~= state.teamId then
                    local distance = (targetModel.PrimaryPart.Position - searchCenter).Magnitude
                    if distance < minDistance then
                        minDistance = distance
                        bestTarget = targetModel
                    end
                end
            end
        end

        local oldTarget = state.currentTarget
        state.currentTarget = bestTarget

        if oldTarget and oldTarget ~= newTarget and state.activeTargetAttachment then
            if state.activeTargetAttachment.Parent then
                state.activeTargetAttachment:Destroy()
            end
            state.activeTargetAttachment = nil
        end

        if state.currentTarget then
            CombatService:ApplyDamage(state.model, state.currentTarget, TESLA_DAMAGE_PER_TICK, CombatService.DamageType.Tesla)

            if state.beam then
                if not state.activeTargetAttachment or not state.activeTargetAttachment.Parent then
                    state.activeTargetAttachment = Instance.new("Attachment")
                    state.activeTargetAttachment.Name = "TeslaTargetAttachment"
                    state.activeTargetAttachment.Parent = state.currentTarget.PrimaryPart
                end
                state.beam.Attachment1 = state.activeTargetAttachment
                state.beam.Enabled = true
            end
        else
            if state.beam then
                state.beam.Enabled = false
            end
        end
    end
end

-- --- Service API ---
function TeslaService:Register(coreId, plot, model, teamId)
    if activeTeslas[model] then return end

    local emitterPart = model:FindFirstChild("Emitter", true) or model:FindFirstChild("Part1", true) or model.PrimaryPart
    if not emitterPart then
        warn("[TeslaService] Registration failed: Tesla model", model.Name, "is missing an emitter part.")
        return
    end

    -- Find an existing beam or create a new one
    local beam = emitterPart:FindFirstChildOfClass("Beam")
    if not beam then
        beam = Instance.new("Beam", emitterPart)
        beam.Name = "TeslaBeam"
        beam.Color = ColorSequence.new(Color3.fromRGB(0, 255, 255))
        beam.Width0, beam.Width1 = 0.5, 0.2
        beam.Segments, beam.CurveSize0, beam.CurveSize1 = 10, 10, 10
        beam.Enabled = false
        beam.Attachment0 = emitterPart:FindFirstChildOfClass("Attachment") or Instance.new("Attachment", emitterPart)
    end

    local state = {
        model = model,
        teamId = teamId,
        beam = beam,
        cooldown = 0,
        currentTarget = nil,
        activeTargetAttachment = nil,
    }
    activeTeslas[model] = state
    model:SetAttribute("OwnerTeam", teamId)

    print("[TeslaService] Registered new Tesla:", model.Name)
end

function TeslaService:Unregister(model)
    local state = activeTeslas[model]
    if not state then return end

    -- Clean up any visual effects or lingering state
    if state.beam then state.beam.Enabled = false end
    if state.activeTargetAttachment and state.activeTargetAttachment.Parent then
        state.activeTargetAttachment:Destroy()
    end

    activeTeslas[model] = nil
    print("[TeslaService] Unregistered Tesla:", model.Name)
end

function TeslaService:Init()
    RunService.Heartbeat:Connect(onHeartbeat)
    print("TeslaService Initialized")
end

return TeslaService