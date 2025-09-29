-- File: ServerScriptService/TestMatches/Test_HeartSystem.lua
-- Summary: Automated test for the HeartSystem module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeartSystem = require(ReplicatedStorage.Modules.HeartSystem)

local function runTests()
    print("[TEST][HeartSystem] Starting tests...")

    -- Listen to events to verify outcomes
    HeartSystem.On("StageTransition", function(unitId, from, to)
        print(string.format("[TEST][HeartSystem] EVENT: Unit '%s' transitioned from stage '%s' to '%s'", unitId, from, to))
    end)
    HeartSystem.On("Stunned", function(unitId, isStunned)
        print(string.format("[TEST][HeartSystem] EVENT: Unit '%s' stun status is now: %s", unitId, tostring(isStunned)))
    end)
    HeartSystem.On("Destroyed", function(unitId, attacker)
        print(string.format("[TEST][HeartSystem] EVENT: Unit '%s' was destroyed by %s", unitId, tostring(attacker)))
    end)

    -- Test 1: Standard Troop (Stage2 -> Stage1 -> Normal -> Destroyed)
    print("\n--- Test 1: Standard Troop ---")
    local troopId = "TestTroop_01"
    HeartSystem.RegisterUnit(troopId, { stage2 = 2, stage1 = 2, normal = 1 })

    print("Hitting troop twice...")
    HeartSystem.TakeHit(troopId, "Laser")
    HeartSystem.TakeHit(troopId, "Laser") -- Should transition to stage1 and be stunned

    task.wait(3) -- Wait for stun to wear off

    print("Hitting troop two more times...")
    HeartSystem.TakeHit(troopId, "Laser")
    HeartSystem.TakeHit(troopId, "Laser") -- Should transition to normal and be stunned

    task.wait(3)

    print("Final hit on troop...")
    HeartSystem.TakeHit(troopId, "Laser") -- Should be destroyed

    -- Test 2: AT-TE vs. Torpedoes (Purple -> Stun -> Stage2)
    print("\n--- Test 2: AT-TE vs. Torpedoes ---")
    local atteId = "TestATTE_01"
    HeartSystem.RegisterUnit(atteId, { purple = 2, stage2 = 3 })

    print("Hitting AT-TE with a laser (should do nothing)...")
    HeartSystem.TakeHit(atteId, "Laser") -- Should be ignored

    print("Hitting AT-TE with two torpedoes...")
    HeartSystem.TakeHit(atteId, "Torpedo")
    HeartSystem.TakeHit(atteId, "Torpedo") -- Should transition to stage2 and be stunned

    -- Test 3: AT-TE vs. Tesla (Purple -> No Stun -> Destroyed)
    print("\n--- Test 3: AT-TE vs. Tesla ---")
    local atteTeslaId = "TestATTETesla_01"
    HeartSystem.RegisterUnit(atteTeslaId, { purple = 1, stage2 = 1 })

    print("Hitting AT-TE with Tesla damage...")
    HeartSystem.TakeHit(atteTeslaId, "Tesla") -- Should destroy purple heart
    HeartSystem.TakeHit(atteTeslaId, "Tesla") -- Should destroy stage2 heart and the unit

    if not HeartSystem.IsAlive(atteId) then
        print("[TEST][HeartSystem] FAILED: AT-TE should still be alive.")
    else
        print("[TEST][HeartSystem] PASSED: AT-TE is correctly alive.")
    end

    if HeartSystem.IsAlive(troopId) or HeartSystem.IsAlive(atteTeslaId) then
        print("[TEST][HeartSystem] FAILED: A unit that should be destroyed is still alive.")
    else
        print("[TEST][HeartSystem] PASSED: All destroyed units are correctly marked as not alive.")
    end

    print("\n[TEST][HeartSystem] All tests complete.")
end

-- To run this test, you would typically call this function from a central test runner
-- or temporarily from a script in ServerScriptService.
-- For now, we can just call it directly after a short delay.
task.wait(2)
runTests()