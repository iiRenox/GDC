-- File: ServerScriptService/Services/TeslaService.lua
-- Summary: Manages all Tesla tower instances, their targeting, and damage application.

local TeslaService = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local CombatService = require(ServerScriptService.Services:WaitForChild("CombatService"))
local PlayerManager = require(ServerScriptService.Services:WaitForChild("PlayerManager"))
local HeartSystem = require(ReplicatedStorage.Modules.HeartSystem)

local activeTeslas = {} -- { [instance] = { ownerTeam = number } }
local lastTick = 0
local TICK_INTERVAL = 1 -- seconds, how often Teslas check for targets

-- Function to find a valid target (player, troop, or vehicle)
local function findTarget(teslaInstance, ownerTeam)
    local position = teslaInstance.PrimaryPart.Position
    local radius = 135 -- As per "Infos" documentation

    local overlapParams = OverlapParams.new()
    -- Configure filter to find things that can be damaged
    -- This will need to be refined with CollectionService tags for troops/vehicles
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = {teslaInstance}

    local partsInRadius = workspace:GetPartBoundsInRadius(position, radius, overlapParams)

    for _, part in ipairs(partsInRadius) do
        local model = part:FindFirstAncestorWhichIsA("Model")
        if not model then continue end

        local targetTeam = model:GetAttribute("OwnerTeam")
        if not targetTeam then
            local player = game.Players:GetPlayerFromCharacter(model)
            if player then
                targetTeam = PlayerManager.GetTeamId(player)
            end
        end

        -- Check if the target is an enemy
        if targetTeam and targetTeam ~= ownerTeam then
            -- Check if it's a damageable entity registered in the HeartSystem
            local unitId = model:GetAttribute("UnitId")
            if unitId and HeartSystem.IsAlive(unitId) then
                return model -- Return the first valid enemy model found
            end
        end
    end

    return nil
end

function TeslaService:Init()
    print("[TeslaService] Initializing...")

    -- Listen for when a Tesla is destroyed to remove it from the active list
    HeartSystem.On("Destroyed", function(unitId, attacker)
        for instance, data in pairs(activeTeslas) do
            if instance:GetAttribute("UnitId") == unitId then
                activeTeslas[instance] = nil
                print("[TeslaService] Unregistered destroyed Tesla:", instance.Name)
                break
            end
        end
    end)

    -- Main update loop
    RunService.Heartbeat:Connect(function()
        if os.clock() - lastTick < TICK_INTERVAL then return end
        lastTick = os.clock()

        for tesla, data in pairs(activeTeslas) do
            if not tesla.Parent then
                activeTeslas[tesla] = nil -- Cleanup if instance was removed unexpectedly
                continue
            end

            local target = findTarget(tesla, data.ownerTeam)
            if target then
                local unitId = target:GetAttribute("UnitId")
                -- TODO: Add a visual effect (beam) from the Tesla to the target

                -- Apply damage through CombatService
                CombatService:ApplyDamage(tesla, target, 1, "Tesla")
            end
        end
    end)

    print("[TeslaService] Initialized.")
end

function TeslaService:RegisterTesla(teslaInstance, ownerTeam)
    if not teslaInstance or not teslaInstance:IsA("Model") or not ownerTeam then
        warn("[TeslaService] Attempted to register an invalid Tesla.")
        return
    end

    -- Ensure the Tesla has a unique ID for the HeartSystem
    local unitId = teslaInstance:GetAttribute("UnitId")
    if not unitId then
        unitId = "Tesla_" .. tostring(teslaInstance:GetUniqueId())
        teslaInstance:SetAttribute("UnitId", unitId)
    end

    -- Register with the HeartSystem
    -- TODO: Get actual heart stages from GameConfig based on Tesla tier (Normal, Silver, Gold)
    HeartSystem.RegisterUnit(unitId, { stage1 = 5, normal = 5 }, teslaInstance)

    activeTeslas[teslaInstance] = {
        ownerTeam = ownerTeam,
    }
    print("[TeslaService] Registered new Tesla:", teslaInstance.Name, "for team", ownerTeam)
end

return TeslaService