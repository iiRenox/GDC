-- File: ServerScriptService/Services/ProtonCannonService.lua
-- Summary: Manages all Proton Cannon instances, including player control, firing, and capture mechanics.

local ProtonCannonService = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local CombatService = require(ServerScriptService.Services:WaitForChild("CombatService"))
local PlayerManager = require(ServerScriptService.Services:WaitForChild("PlayerManager"))
local HeartSystem = require(ReplicatedStorage.Modules.HeartSystem)

local activeCannons = {} -- { [instance] = { ownerTeam, isStunned, turretMotor, barrelMotor, firePoint, seat, ... } }
local playerInputs = {} -- { [player] = { yaw, pitch } }

local AI_TICK_INTERVAL = 2.0
local lastAITick = 0

-- Function to find a valid AI target (troops or vehicles)
local function findAITarget(cannonInstance, ownerTeam)
    local position = cannonInstance.PrimaryPart.Position
    local radius = 300 -- Cannons have long range

    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = {cannonInstance}

    local partsInRadius = workspace:GetPartBoundsInRadius(position, radius, overlapParams)
    local potentialTargets = {}

    for _, part in ipairs(partsInRadius) do
        local model = part:FindFirstAncestorWhichIsA("Model")
        if not model or model:GetAttribute("IsBuilding") then continue end -- AI does not target buildings

        local targetTeam
        local attrTeam = model:GetAttribute("OwnerTeam")
        if attrTeam then
            targetTeam = attrTeam
        else
            local player = game.Players:GetPlayerFromCharacter(model)
            if player then targetTeam = PlayerManager.GetTeamId(player) end
        end

        if targetTeam and targetTeam ~= ownerTeam then
            local unitId = model:GetAttribute("UnitId")
            if unitId and HeartSystem.IsAlive(unitId) then
                table.insert(potentialTargets, model)
            end
        end
    end

    if #potentialTargets > 0 then
        return potentialTargets[math.random(#potentialTargets)]
    end
    return nil
end

function ProtonCannonService:Init()
    print("[ProtonCannonService] Initializing...")

    HeartSystem.On("Stunned", function(unitId, isStunned)
        for cannon, data in pairs(activeCannons) do
            if cannon:GetAttribute("UnitId") == unitId then
                data.isStunned = isStunned
                if isStunned and data.seat.Occupant then
                    data.seat.Occupant:ChangeState(Enum.HumanoidStateType.Jumping)
                end
                -- The prompt on the seat will now be usable by enemies
                break
            end
        end
    end)

    HeartSystem.On("Destroyed", function(unitId)
         for cannon, data in pairs(activeCannons) do
            if cannon:GetAttribute("UnitId") == unitId then
                activeCannons[cannon] = nil
                break
            end
        end
    end)

    RunService.Heartbeat:Connect(function(dt)
        -- Player control loop
        for cannon, data in pairs(activeCannons) do
            if not cannon.Parent then
                activeCannons[cannon] = nil
                continue
            end

            local seat = data.seat
            if seat and seat.Occupant then
                local player = Players:GetPlayerFromCharacter(seat.Occupant.Parent)
                local input = player and playerInputs[player]
                if input and data.turretMotor and data.barrelMotor then
                    -- Rotate turret and barrel based on input
                    local currentYaw = data.turretMotor.CurrentAngle
                    local currentPitch = data.barrelMotor.CurrentAngle

                    local newYaw = currentYaw + input.yaw * dt * 2 -- Adjust speed as needed
                    local newPitch = math.clamp(currentPitch + input.pitch * dt * 2, -0.5, 0.5) -- Clamp pitch

                    data.turretMotor.DesiredAngle = newYaw
                    data.barrelMotor.DesiredAngle = newPitch
                end
            end
        end

        -- AI control loop
        if os.clock() - lastAITick < AI_TICK_INTERVAL then return end
        lastAITick = os.clock()

        for cannon, data in pairs(activeCannons) do
             if data.seat and not data.seat.Occupant and not data.isStunned then
                local target = findAITarget(cannon, data.ownerTeam)
                if target and target.PrimaryPart then
                    local direction = (target.PrimaryPart.Position - data.firePoint.WorldPosition).Unit
                    local cframe = CFrame.lookAt(data.turretMotor.Part0.Position, data.turretMotor.Part0.Position + direction)
                    local _, yaw, _ = cframe:ToOrientation()

                    -- NOTE: This AI aiming is simplified. A real implementation would need more advanced CFrame math.
                    -- For now, it just fires in the general direction.
                    data.turretMotor.DesiredAngle = yaw
                    self:HandleFireRequest(nil, cannon) -- Fire as AI
                end
            end
        end
    end)

    print("[ProtonCannonService] Initialized.")
end

function ProtonCannonService:RegisterCannon(cannonInstance, ownerTeam)
    if not cannonInstance or not ownerTeam then
        warn("[ProtonCannonService] Invalid registration attempt.")
        return
    end

    local unitId = "Cannon_" .. cannonInstance:GetUniqueId()
    cannonInstance:SetAttribute("UnitId", unitId)

    local seat = cannonInstance:FindFirstChildOfClass("VehicleSeat")
    if not seat then
        warn("[ProtonCannonService] Cannon model is missing a VehicleSeat:", cannonInstance.Name)
        return
    end

    -- Assuming Motor6D setup for rotation
    local turretMotor = cannonInstance:FindFirstChild("TurretMotor", true)
    local barrelMotor = cannonInstance:FindFirstChild("BarrelMotor", true)
    local firePoint = cannonInstance:FindFirstChild("FirePoint", true)

    if not (turretMotor and barrelMotor and firePoint) then
        warn("[ProtonCannonService] Cannon is missing required motor or firepoint parts:", cannonInstance.Name)
        return
    end

    HeartSystem.RegisterUnit(unitId, { stage1 = 3, normal = 3 }, cannonInstance)

    activeCannons[cannonInstance] = {
        ownerTeam = ownerTeam,
        isStunned = false,
        seat = seat,
        turretMotor = turretMotor,
        barrelMotor = barrelMotor,
        firePoint = firePoint,
    }
    cannonInstance:SetAttribute("OwnerTeam", ownerTeam)

    local prompt = seat:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt", seat)
    prompt.ActionText = "Enter Cannon"
    prompt.ObjectText = "Proton Cannon"
    prompt.Enabled = true

    -- Handle entering/exiting
    seat:GetPropertyChangedSignal("Occupant"):Connect(function()
        if seat.Occupant then
            local player = Players:GetPlayerFromCharacter(seat.Occupant.Parent)
            if player then
                local playerTeam = PlayerManager.GetTeamId(player)
                -- Allow entry if not stunned, OR if stunned and player is an enemy
                if (not activeCannons[cannonInstance].isStunned and playerTeam == ownerTeam) or (activeCannons[cannonInstance].isStunned) then
                    -- Player successfully entered. If they were an enemy, capture the cannon.
                    if playerTeam ~= ownerTeam then
                        activeCannons[cannonInstance].ownerTeam = playerTeam
                        cannonInstance:SetAttribute("OwnerTeam", playerTeam)
                        -- Potentially reset health stages here if needed
                    end
                else
                    -- Eject if not allowed
                    seat.Occupant:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        else
            -- Player exited, clear their input
            for p, _ in pairs(playerInputs) do
                if not p.Character or not p.Character:FindFirstChildOfClass("Humanoid") or p.Character.Humanoid.SeatPart ~= seat then
                    playerInputs[p] = nil
                end
            end
        end
    end)

    print("[ProtonCannonService] Registered new cannon:", cannonInstance.Name)
end

function ProtonCannonService:HandleInput(player, input)
    playerInputs[player] = input
end

function ProtonCannonService:HandleFireRequest(player, cannonOverride)
    local cannon
    if cannonOverride then
        cannon = cannonOverride
    else
        local char = player and player.Character
        local seat = char and char:FindFirstChildOfClass("Humanoid") and char.Humanoid.SeatPart
        if seat and seat:IsA("VehicleSeat") and activeCannons[seat.Parent] then
            cannon = seat.Parent
        end
    end

    if not cannon or not activeCannons[cannon] then return end

    local data = activeCannons[cannon]
    local firePoint = data.firePoint

    local projectile = Instance.new("Part")
    projectile.Size = Vector3.new(4, 4, 10)
    projectile.Shape = Enum.PartType.Ball
    projectile.Color = Color3.fromRGB(255, 100, 0)
    projectile.Material = Enum.Material.Neon
    projectile.CanCollide = false
    projectile.CFrame = firePoint.WorldCFrame
    projectile.Parent = workspace

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = firePoint.WorldCFrame.LookVector * 150 -- Slow but powerful
    bv.Parent = projectile

    Debris:AddItem(projectile, 5)

    projectile.Touched:Connect(function(hit)
        local hitModel = hit:FindFirstAncestorWhichIsA("Model")
        if hitModel == cannon then return end -- Don't hit self

        -- Create explosion effect
        local explosion = Instance.new("Explosion")
        explosion.Position = projectile.Position
        explosion.BlastRadius = 25
        explosion.BlastPressure = 500000
        explosion.Parent = workspace

        CombatService:ApplyDamage(cannon, hit, 1, "HighImpact")
        projectile:Destroy()
    end)
end

return ProtonCannonService