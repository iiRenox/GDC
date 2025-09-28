-- File: CHANGELOG.md
-- Modified/Created by: GPT-5 (Cursor) — 2025-08-08
-- Based on: Gemini scripts (if modified) — original filenames listed below
-- Summary: High-level change log; per-file action plan and noted missing assets. Initial deliverables for Part 1.

# Project CHANGELOG

Note: Actions are planned to keep backward compatibility while we migrate to the canonical architecture (server-authoritative, validated remotes). Values found in the existing `ReplicatedStorage/GameConfig` are preferred where conflicts arise; canonical fields are added alongside legacy ones.

Legend
- Action: REFINE (small edits), EXTEND (add features), REPLACE (rewrite/rename)

Per-file plan (scan of current snapshot)

- `ReplicatedStorage/GameConfig` — REPLACE — Align to canonical; preserve legacy keys — Missing: none (references unit models)
- `ReplicatedStorage/Remotes/ClientToServerCommand` — EXTEND — Legacy routing kept — Missing: none
- `ReplicatedStorage/Remotes/ServerToAllClientsUpdate` — EXTEND — Effects; will keep alongside `RE_PlayEffect` — Missing: none
- `ReplicatedStorage/Remotes/ServerToClientUpdate` — EXTEND — Generic client updates; will phase out — Missing: none
- `ServerScriptService/GameManager` — REFINE — Add Start/Reset/Death APIs & use canonical config — Missing: none
- `ServerScriptService/RemoteHandler` — REPLACE — Centralized validated router & rate limits — Missing: none
- `ServerScriptService/Services/CombatService` — EXTEND — HeartSystem, building shields, RF hooks — Missing: none
- `ServerScriptService/Services/PlayerManager` — EXTEND — Bits API, spawn helpers — Missing: none
- `ServerScriptService/Services/SpeederManager` — REPLACE — Server-authoritative input & fire APIs — Missing: none
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_Barracks` — EXTEND — Placeholder model — Missing: geometry
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_BitWell` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_CommandCenter` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_ProtonCannon_Normal` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_ProtonCannon_Silver` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_ReyShieldGen_Normal` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_ReyShieldGen_Silver` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_ShieldGen_Gold` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_ShieldGen_Normal` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_ShieldGen_Silver` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_Support_Air` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_Support_SmallAir` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_Tesla_Gold` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_Tesla_Normal` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_Tesla_Silver` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_Torpedo_Gold` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_Torpedo_Normal` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/CIS_Buildings/CIS_Torpedo_Silver` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_Barracks` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_BitWell` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_CommandCenter` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_ProtonCannon_Normal` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_ProtonCannon_Silver` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_ReyShieldGen_Normal` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_ReyShieldGen_Silver` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_ShieldGen_Gold` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_ShieldGen_Normal` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_ShieldGen_Silver` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_Support_Air` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_Support_SmallAir` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_Tesla_Gold` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_Tesla_Normal` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_Tesla_Silver` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_Torpedo_Gold` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_Torpedo_Normal` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/BuildingPrefabs/Rep_Buildings/Rep_Torpedo_Silver` — EXTEND — Placeholder — Missing: geometry
- `ServerStorage/TagList/Speeder` — EXTEND — Placeholder tag list — Missing: contents
- `ServerStorage/UnitPrefabs/AAT` — EXTEND — Placeholder — Missing: model contents
- `ServerStorage/UnitPrefabs/AT-RT/Script` — EXTEND — Procedural walker glue later — Missing: none
- `ServerStorage/UnitPrefabs/AT-ST/Script` — EXTEND — Procedural walker glue later — Missing: none
- `ServerStorage/UnitPrefabs/AT-TE/Script` — EXTEND — Procedural walker glue later — Missing: none
- `ServerStorage/UnitPrefabs/CIS_Droid` — EXTEND — Placeholder — Missing: model contents
- `ServerStorage/UnitPrefabs/CIS_Dropship` — EXTEND — Placeholder — Missing: model contents
- `ServerStorage/UnitPrefabs/CIS_General` — EXTEND — Placeholder model for player character — Missing: rig details
- `ServerStorage/UnitPrefabs/CIS_Rocket_Droid` — EXTEND — Placeholder — Missing: model contents
- `ServerStorage/UnitPrefabs/CIS_Speeder` — EXTEND — Placeholder — Missing: parts/setup
- `ServerStorage/UnitPrefabs/Droid_Spider/Script` — EXTEND — Procedural walker glue later — Missing: none
- `ServerStorage/UnitPrefabs/Hailfire` — EXTEND — Placeholder — Missing: model contents
- `ServerStorage/UnitPrefabs/HomingSpider/Script` — EXTEND — Procedural walker glue later — Missing: none
- `ServerStorage/UnitPrefabs/Rep_Clone` — EXTEND — Placeholder — Missing: model contents
- `ServerStorage/UnitPrefabs/Rep_Dropship` — EXTEND — Placeholder — Missing: model contents
- `ServerStorage/UnitPrefabs/Rep_General` — EXTEND — Placeholder model for player character — Missing: rig details
- `ServerStorage/UnitPrefabs/Rep_Rocket_Clone` — EXTEND — Placeholder — Missing: model contents
- `ServerStorage/UnitPrefabs/Rep_Speeder` — EXTEND — Placeholder — Missing: parts/setup
- `ServerStorage/UnitPrefabs/Supertank` — EXTEND — Placeholder — Missing: model contents
- `StarterPlayer/StarterPlayerScripts/ClientController` — REPLACE — Split into Input/UI/Speeder clients — Missing: none
- `Workspace/Ryloth/*` (Bridge, Ground, Spawns, Core folders, BuildPlots) — EXTEND — BuildManager registry — Missing: ring/metadata at runtime

New files added (this commit)

- `ReplicatedStorage/Docs/ARCHITECTURE.md`
  - Action: ADD
  - Reason: High-level components and data flow

- `ReplicatedStorage/Remotes/RE_*` and `RF_*`
  - Action: ADD
  - Reason: Canonical remotes per §6

Compatibility & diffs

- Preserved legacy fields in GameConfig: `RESPAWN_TIME`, `SPEEPER_RESPAWN_TIME`, `Teams`, `CATEGORIES`, plant bit ranges and `GetPlantBits()`
- Canonical additions: `MATCH`, `TEAM`, `CORE`, `BARRACKS`, `SPEEDER`, `REMOTE_RATE_LIMITS`, `HEARTS`, `UI`, `COSTS`, `DEFAULTS`, `DEV_MODE`

Open missing assets (tracked)

- Many building/unit prefabs are placeholders (empty models). BuildManager will create ghost/fallback placement and log TODOs until assets are provided.



Session updates — 2025-09-21

- Added PRIORITY.md (high/medium/low roadmap with estimates).
- Added ReplicatedStorage/Docs/TESTS.md (manual smoke tests).
- Added progress docs: ReplicatedStorage/Docs/PROGRESS_RemoteHandler.md and PROGRESS_GameManager.md.
- Added ServerScriptService/TestMatches/Test_SmokeStart.lua (logs team/bits on join).
- Noted config diffs to spec (kept current values for now):
  - TEAM mapping uses REP=2, CIS=1 (localized team order).
  - COSTS.BitWell = 30000 (spec lists 50000). Flagged for balance pass.