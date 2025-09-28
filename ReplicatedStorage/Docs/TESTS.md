-- File: ReplicatedStorage/Docs/TESTS.md
-- Summary: Manual smoke tests and expected outcomes for current systems.

## Smoke: Startup and Teams
- Start solo in Studio.
- Expect teams rebuilt, player assigned to smaller team, leaderstats Bits = 15000.
- A speeder spawns near your character with an entry prompt.

## Speeder: Move and Fire
- Enter speeder (E). Move WASD; expect server-driven motion and engine sound.
- Fire primary (Mouse1). Expect impacts spawn and damage Humanoids or Health IntValues.

## Resources: Plants/Rocks
- Fly near a plant/rock or shoot it. Expect it to unanchor, explode lightly, drop 32 studs.
- Collect studs; Bits increases and pickup sound plays. Clusters respawn after delay.

## Build Prompts
- In `Workspace/Ryloth/Core_*` walk to a `BuildPlot_*` and press the Build Prompt.
- Expect a client event (RE_Build_RequestOpen) with `{ coreId, plotLetter }` to be fired to you.

## Tesla/Torpedo (if placed)
- Tesla models apply periodic damage to units/vehicles in radius, not buildings.
- Torpedo pickup prompt grants a torpedo; firing homes to the core ball and destroys one random building on that core.

Notes
- Enable DEV_MODE in GameConfig for verbose logs.

