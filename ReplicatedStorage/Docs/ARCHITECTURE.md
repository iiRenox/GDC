-- File: ReplicatedStorage/Docs/ARCHITECTURE.md
-- Modified/Created by: GPT-5 (Cursor) — 2025-08-08
-- Based on: Gemini scripts
-- Summary: Minimal architecture overview and data flows.

## Components

- ServerScriptService/Services/*: Domain services (GameManager, PlayerManager, BuildManager, ResourceManager, BarracksService, UnitAIService, CombatService, SpeederManager). Each exposes a clear API and owns its in-memory state.
- ReplicatedStorage/GameConfig: Canonical config; read-only on clients (sanitized via RF_GetGameConfig).
- ReplicatedStorage/Remotes: Canonical remotes. All client requests go through RemoteHandler which validates and routes to services.
- Workspace/Ryloth: Map with cores and build plots discoverable by BuildManager.
- ReplicatedStorage/Modules/HeartSystem.lua: Heart-based health FSM used by units, vehicles, and buildings.

## Data Flow

- Client Input → Remotes/RE_* → RemoteHandler → Service APIs → State updated → Notifications via ServerToAllClientsUpdate or specific RE_PlayEffect/RF getters → Client UI updates.
- Periodic systems (barracks spawn, resource ticks) run on server at low-frequency ticks; critical events are event-driven.

## Security

- Server-authoritative. RemoteHandler applies rate limits and proximity/resource checks before invoking services.


