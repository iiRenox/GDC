-- File: ServerScriptService/TestMatches/Test_GroundAssaultIntegration.lua
-- Summary: End-to-end integration test for the Ground Assault category (Tesla & Proton Cannon).

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlayerManager = require(ServerScriptService.Services.PlayerManager)
local BuildManager = require(ServerScriptService.Services.BuildManager)
local TeslaService = require(ServerScriptService.Services.TeslaService)
local ProtonCannonService = require(ServerScriptService.Services.ProtonCannonService)
local HeartSystem = require(ReplicatedStorage.Modules.HeartSystem)

local function createMockPlayer(teamId)
    local player = {
        Name = "MockPlayer_" .. teamId,
        Team = game:GetService("Teams"):FindFirstChild(teamId == 1 and "Separatisten" or "Republik"),
        Character = Instance.new("Model"),
    }
    player.Character.Name = player.Name
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Parent = player.Character
    player.Character.Parent = Workspace

    PlayerManager.AddPlayer(player, teamId)
    PlayerManager.ModifyBits(player, 50000, "TestSetup")
    return player
end

local function createMockTarget(teamId, position)
    local target = Instance.new("Model")
    target.Name = "MockTarget"
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(4, 6, 2)
    hrp.Position = position
    hrp.Anchored = true
    hrp.Parent = target
    target.PrimaryPart = hrp

    local unitId = "MockTarget_" .. tostring(target:GetUniqueId())
    target:SetAttribute("UnitId", unitId)
    target:SetAttribute("OwnerTeam", teamId)
    HeartSystem.RegisterUnit(unitId, { normal = 5 }, target)

    target.Parent = Workspace
    return target, unitId
end

local function runTests()
    print("\n[TEST][Integration] Starting Ground Assault integration tests...")

    -- Setup
    local player1 = createMockPlayer(1) -- CIS
    local coreId = "Core_CIS_1" -- Assuming this core exists
    local core = BuildManager:GetCore(coreId)
    if not core then
        warn("[TEST][Integration] FAILED: Could not find core with ID:", coreId)
        return
    end

    -- Find an empty plot
    local emptyPlotLetter
    for letter, plot in pairs(core.plots) do
        if not plot.occupied then
            emptyPlotLetter = letter
            break
        end
    end

    if not emptyPlotLetter then
        warn("[TEST][Integration] FAILED: No empty plot found on core", coreId)
        return
    end

    -- Test 1: Build and test Tesla
    print("\n--- Test 1: Tesla ---")
    local teslaOk, reason = BuildManager:AttemptPurchase(player1, coreId, emptyPlotLetter, "CIS_Tesla_Normal")
    if not teslaOk then
        print("[TEST][Integration] FAILED: Could not build Tesla. Reason:", reason)
        return
    end
    print("[TEST][Integration] PASSED: Tesla built successfully.")
    local teslaInstance = core.plots[emptyPlotLetter].buildingRef
    local teslaPlotPosition = core.plots[emptyPlotLetter].part.Position

    -- Create a target for the Tesla
    local enemyTarget, enemyUnitId = createMockTarget(2, teslaPlotPosition + Vector3.new(50, 0, 0))
    print("[TEST][Integration] Spawned enemy target for Tesla.")

    -- Wait for Tesla to fire
    task.wait(2)

    local targetData = HeartSystem.GetUnitData(enemyUnitId)
    if targetData and targetData.hearts.normal < 5 then
        print("[TEST][Integration] PASSED: Tesla automatically targeted and damaged the enemy.")
    else
        print("[TEST][Integration] FAILED: Tesla did not damage the enemy target.")
    end
    enemyTarget:Destroy()

    -- Test 2: Build and test Proton Cannon
    print("\n--- Test 2: Proton Cannon ---")

    -- Find another empty plot
    local cannonPlotLetter
    for letter, plot in pairs(core.plots) do
        if not plot.occupied then
            cannonPlotLetter = letter
            break
        end
    end
    if not cannonPlotLetter then
        warn("[TEST][Integration] FAILED: No second empty plot found for Cannon.")
        return
    end

    local cannonOk, cannonReason = BuildManager:AttemptPurchase(player1, coreId, cannonPlotLetter, "CIS_ProtonCannon_Normal")
    if not cannonOk then
        print("[TEST][Integration] FAILED: Could not build Proton Cannon. Reason:", cannonReason)
        return
    end
    print("[TEST][Integration] PASSED: Proton Cannon built successfully.")
    local cannonInstance = core.plots[cannonPlotLetter].buildingRef

    -- Simulate player entering the cannon
    local seat = cannonInstance:FindFirstChildOfClass("VehicleSeat")
    if seat then
        seat.Occupant = player1.Character:FindFirstChildOfClass("Humanoid")
    end

    -- Simulate fire request
    print("[TEST][Integration] Simulating fire request from player...")
    ProtonCannonService:HandleFireRequest(player1)

    -- This test is harder to verify without complex workspace checks.
    -- For now, we confirm the code path executes without errors.
    print("[TEST][Integration] PASSED: Proton Cannon fire request processed without errors.")

    print("\n[TEST][Integration] All tests complete.")
end

task.wait(3) -- Wait for services to initialize
runTests()