<-- File: ReplicatedStorage/Docs/PROGRESS_GameManager.md
-- Summary: Status, tests, and open issues for GameManager.

Status
- Rebuilds Teams from GameConfig and assigns players to balanced team.
- Spawns character from ServerStorage.UnitPrefabs/<Team>_General.
- Spawns speeder per player via SpeederManager.
- Initializes BuildManager and ResourceManager (scatter clusters).

Quick Test
- Join solo; expect Bits = 15000, character spawn at team spawn, speeder nearby.

Open Items
- Add StartMatch/EndMatch/ResetMatch APIs (stubs exist conceptually; implement when needed).
- Add death penalty flow per MATCH.DEATH_BITS_PENALTY and respawn time.

