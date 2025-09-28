Instructions and Infos :



MASTER PROMPT — DETAILED VERSION
For Cursor GPT-5 (Senior Roblox Scripting Engineer)

Use the Cursor snapshot provided by the user (Gemini scripts + placeholders). Your job: refine existing code, extend/implement missing systems, and deliver a working 1v1 RTS/Action hybrid on Ryloth. Use Luau only and Roblox Studio APIs. Be rigorous: server-authoritative, validated remotes, performance conscious, modular, and controller friendly. Prefer Part 2 instructions where conflicts arise; merge Part 1 extras where helpful.

1 — Project scan & first deliverables (strict order)
1. Scan everything now. Produce CHANGELOG.md at project root. For every file, list:
   - Path
   - Action: REFINE / EXTEND / REPLACE
   - Reason (short)
   - Any missing assets referenced by that file (list exact asset name/path)
2. Create or validate ReplicatedStorage/GameConfig with canonical defaults (see §3).
3. Create ReplicatedStorage/Remotes and add the remotes described in §6 (exact names).
4. Commit a minimal ReplicatedStorage/Docs/ARCHITECTURE.md describing components and data flows.
5. Only after those four items exist, begin the service-by-service implementation sequence in §8.

Return a short progress update after each of the four items (files created/modified + 1-line verification test).

2 — Overall architecture & design principles (non-negotiable)
- Server authoritative: server ultimately decides all state changes (spawns, health, Bits, building placement, projectiles). Clients can only request.
- RemoteHandler: single server module that validates and routes remote calls. No service should directly trust a client remote.
- GameConfig centralization: all balance values and constants in GameConfig. Services read from it; no hardcoded magic numbers elsewhere.
- Modularity: each service in ServerScriptService/Services/ must expose a clear API (function list) and only manage its domain.
- Performance budget:
  - Max units active across server: 300 (aim lower; scale down group sizes if needed).
  - Pathfinding: concurrency limit 6 simultaneous paths; prefer waypoint/no-path mode for infantry groups when > 30 units.
  - Server tick: use 4 ticks/s for non-critical updates (e.g., building regen), and event-driven for critical events.
- Security:
  - Rate limit inputs per player. Default per-event = 5 calls/sec; speeder inputs = 20 calls/sec.
  - Always check player ownership / proximity / resource balance before applying changes.

3 — Canonical GameConfig (explicit)
Create ReplicatedStorage/GameConfig ModuleScript returning this exact table (agent should expand if more items needed):
return {
  STARTING_BITS = 15000,
  MAX_PLAYERS = 2,

  MATCH = {
    RESPAWN_TIME = 3,               -- seconds
    DEATH_BITS_PENALTY = 0.10,      -- fraction
  },

  TEAM = { REP = 1, CIS = 2, REP_NAME = "Republic", CIS_NAME = "Separatists" },

  CORE = {
    PER_SIDE = 6,
    PLOTS_PER_CORE = 8,
    MAX_BUILDINGS_PER_CORE = 3,
    MAX_PLOT_PROXIMITY = 12, -- studs for player actions
  },

  BARRACKS = {
    SPAWN_INTERVAL = 2,   -- seconds
    SPAWN_AMOUNT = 2,
    MAX_PER_BARRACK = 25,
    AUTO_WANDER_THRESHOLD = 16, -- troops before wander
  },

  SPEEDER = {
    INPUT_RATE_LIMIT = 20, -- Hz
    HOVER_HEIGHT = 4.5,
    RESPAWN_DELAY = 10,   -- seconds until speeder respawn at player if destroyed/too far
    MAX_DISTANCE_TO_PLAYER = 200, -- studs
  },

  REMOTE_RATE_LIMITS = {
    DEFAULT = 5, SPEEDER_INPUT = 20
  },

  HEARTS = {
    PLAYER = 4,
    TROOP = { stage = 2, count = 2 },
    VEHICLES = {
      Speeder = { stage = 1, count = 4 },
      Hellfire = { stage = 1, count = 4 },
      SmallAir = { stage = 2, count = 2 },
      MidTier = { stage = 2, count = 5 },
      Large = { purple = 5 },
    }
  },

  UI = {
    RADIAL_RADIUS = 150,
    HINT_FADE_TIME = 0.25,
  },

  COSTS = {
    ProtonNormal = 5000,
    ProtonSilver = 10000,
    TeslaNormal = 20000,
    TeslaSilver = 40000,
    TeslaGold = 60000,
    ATST = 2000,
    DwarfSpider = 2000,
    Barracks_NormalPack = 4000,
    Barracks_RocketPack = 7500,
    ATAP = 12000,
    RX200 = 20000,
    ATTE = 50000,
    Hellfire = 12000,
    AAT = 12000,
    HomingSpider = 20000,
    Supertank = 50000,
    Shield_Normal = 10000,
    Shield_Silver = 20000,
    Shield_Gold = 30000,
    RayShield_Normal = 15000,
    RayShield_Silver = 30000,
    Torpedo_Normal = 20000,
    Torpedo_Silver = 40000,
    Torpedo_Gold = 60000,
    BitWell = 50000,
  },

  DEFAULTS = {
    STUN_DURATION = 2, -- seconds (for stage transitions)
    BUILDING_REGEN_RATE = 0.5, -- % per minute baseline
  }
}

Note: If a GameConfig file already exists in the snapshot, prefer its values and add a diff entry in CHANGELOG.md.

4 — Data models & in-memory state (how each service should store its state)
Core data shapes (use tables / Maps keyed by unique IDs):
Core:
{
  id = "Core_Rep_3",
  ownerTeam = nil | TEAM.REP | TEAM.CIS,
  plots = { plotIndex = { occupied = true/false, buildingRef = Instance or nil } },
  colorRing = Instance,
  commandCenter = Instance -- building object
}
Building:
{
  id = "Building_<GUID>",
  model = Instance,
  ownerTeam = TEAM,
  coreId = "Core_Rep_3",
  plotIndex = 2,
  categoryId = 1..8,
  tier = "Normal|Silver|Gold",
  hpPercent = number, -- 0..100
  shieldActive = bool,
  rayShieldTarget = Instance | nil,
  regenRate = number,
}
Barrack:
{
  id,
  buildingRef,
  spawnedCount = int,
  activeUnits = { unitRef1, unitRef2, ... }
}
Unit:
{
  id,
  instance = Instance,
  team = TEAM,
  heartStages = { stage2=2, stage1=0, normal=0 } -- dynamic
  aiState = "Idle|Wander|Follow|Attack|Dead",
  ownerBarrack = id | nil
}
Vehicle:
{
  id,
  type = "Speeder|ATTE|RX200|HomingSpider|Supertank|...",
  instance,
  heartStages = {...} -- as above
  dropSource = buildingId | nil
  controlledBy = player | nil
  isAnchored = true|false
}

5 — Exact Remote payload schemas & validation rules
All remote handler methods must:
- Validate player object exists, player.Character valid (unless action allowed without character), and timestamp/rate limits.
- Validate proximity to relevant instance ((player.Character.PrimaryPart.Position - target.Position).Magnitude <= GameConfig.CORE.MAX_PLOT_PROXIMITY).
- Validate HasBits(player, cost) server-side before purchase.
- Log any invalid/malicious attempts under DEV_MODE.

Remote Event formats:
1. RE_Speeder_UpdateInput
   - Payload (client → server):
     {
       timestamp = number,
       forward = -1..1,
       right = -1..1,
       boost = bool,
       yaw = number -- optional camera yaw
     }
   - Server validation: rate limit 20Hz, clamp forward/right to [-1,1], ensure player actually sits in speeder instance they claim (check SpeederManager:PlayerVehicle(player)).

2. RE_Speeder_Fire
   - Payload:
     { timestamp = number, weaponId = "primary|secondary", aimVector = Vector3 or nil }
   - Server action: spawn server projectile, tag owner, set velocity.

3. RE_Build_RequestOpen
   - Payload:
     { coreId = string, plotIndex = integer }
   - Server: check plot exists and player within MAX_PLOT_PROXIMITY and send radial payload with locked/unlocked booleans.

4. RE_Build_RequestPurchase
   - Payload:
     { coreId = string, plotIndex = int, categoryId = int, buildingId = string, clientNonce = string }
   - Server: validate cost, category unlock rules (fresh core logic), occupancy, max buildings on core; deduct Bits & place building.

5. RE_CallTroops
   - Payload:
     { toggle = true|false } -- server toggles nearby lurable troops
   - Server: find friendly units within radius (configurable CALL_RADIUS e.g., 60 studs) and set their AI to FollowPlayer.

6. RE_Torpedo_PickupRequest
   - Payload:
     { torpedoId = string } -- optional
   - Server: check player in speeder, check proximity to torpedo spawn, give torpedo to speeder if present.

7. RE_RequestUnitControl
   - Payload:
     { unitId = string }
   - Server: check unit ownership, if vehicle/walker is free and player in proximity, toggle control (assign controlledBy = player), disable AI.

8. RE_PlayEffect
   - Server emits standardized events to clients: { effectName = "explosion", position = Vector3, params = {...} } — clients display locally.

9. RF_GetGameConfig
   - Returns sanitized subset of GameConfig (only UI/costs/heart values), not internal server-only values.

10. RF_GetCoreStatus
    - Input: { coreId = string }
    - Output: { ownerTeam, totalHPPercent, shieldsActive = bool }.

6 — HeartSystem state machine (explicit)
Representation per unit:
heartState = {
  stage2 = nStage2,  -- integer
  stage1 = nStage1,  -- integer
  normal = nNormal,  -- integer
  purple = nPurple,  -- integer (for Large vehicles)
  currentStage = "stage2" | "stage1" | "normal" | "purple"
}
Rules:
- TakeHit(unit, damageType) reduces currentStage counter by 1 (one hit = 1 heart). If currentStage counter <= 0:
  - If currentStage == "stage2" → set stun timer = GameConfig.DEFAULTS.STUN_DURATION, then convert stage2 → stage1 (copy stage1 count). Fire OnStageTransition(unit, "stage1").
  - If currentStage == "stage1" → set stun timer, then convert stage1 → normal. Fire event.
  - If currentStage == "normal" → call OnDestroyed.
  - If currentStage == "purple" → OnDestroyed immediately.
- Stun behavior: disable movement and weapons for STUN_DURATION seconds; play a stun animation or set HumanoidRootPart.Anchored = true for small time for vehicles (visual polish: ragdoll or screen shake).
- Player death: OnDestroyed for a player calls GameManager:HandlePlayerDeath(player) which applies 10% Bits penalty then performs respawn sequence after 3s.
API for HeartSystem module:
HeartSystem:RegisterUnit(unitId, initialStagesTable)
HeartSystem:TakeHit(unitId, damageType, attacker)
HeartSystem:GetHealthPercent(unitId) -> number
HeartSystem:IsAlive(unitId) -> bool
HeartSystem:ForceTransition(unitId, newStage) -- for special cases (Tesla effect etc.)
HeartSystem:On(eventName, callback) -- supports "StageTransition", "Destroyed"

7 — Build & category unlock logic (detailed step by step)
Category IDs
1 = Ground Assault
2 = Small Air Support
3 = Barracks
4 = Air Support
5 = Shields
6 = Ray Shields
7 = Torpedo
8 = Extras

State to track per Team:
teamUnlockedCategories = { [team] = {1=true, 2=false, ...} }
teamBuiltCores = { [team] = { coreId1=true, coreId2=true } } -- track cores where they've built

Unlock algorithm
1. Initially teamUnlockedCategories[team] = { [1] = true }.
2. To unlock category K+1:
   - Player must build a building from the CURRENT highest unlocked category (K) on a fresh core (one where teamBuiltCores[team][coreId] == nil).
   - On successful placement on fresh core: set teamUnlockedCategories[team][K+1] = true and append coreId to teamBuiltCores[team].
3. Losing a category:
   - If COUNT(buildings of category K for team) == 0 then teamUnlockedCategories[team][K] = false and any dependent higher categories should remain locked unless separately unlocked again later.
4. Building on an enemy core:
   - Allowed only when the opponent has no remaining buildings on that core. (i.e., core is empty).
Server validation:
BuildManager:CanBuild(player, coreId, categoryId) runs these checks and returns {ok=true|false, reason="..."}.

8 — Implementation sequence (stepwise, with sub-steps and exact APIs)
Work in this order. After each major step, commit and produce ReplicatedStorage/Docs/PROGRESS_<ServiceName>.md with tests and open issues.

Step A — RemoteHandler + Remotes
- Create all remotes listed in §6.
- Implement RemoteHandler.server.lua with:
  - RemoteHandler:RegisterEvent(name, handlerFunc, rateLimit) — registers handlers with rate-limiting.
  - RemoteHandler:BindAll() — binds all remotes to handler table.
  - Logging: on invalid request call RemoteHandler:Flag(player, reason).
- Test: send simulated remote calls (TestMatches) and ensure invalid ones are rejected and valid ones forwarded.

Step B — GameManager
- API:
  - GameManager:StartMatch() — sets state, assigns teams (first two connected players), sets leaderstats Bits.
  - GameManager:EndMatch(winnerTeam)
  - GameManager:HandlePlayerDeath(player, deathPos)
  - GameManager:ResetMatch()
- Responsibilities: spawn/assign command centers, setup core ownership data, call ResourceManager to populate plants.
- Tests: two-player join → check leaderstats Bits = 15000, team assignment logged.

Step C — PlayerManager
- API:
  - PlayerManager:SpawnCharacterForPlayer(player, optionalCFrame)
  - PlayerManager:ReplaceCharacterModel(player, modelName) — uses ServerStorage/Models/Rep_General etc.
  - PlayerManager:HasBits(player, cost) → boolean
  - PlayerManager:ModifyBits(player, delta, reasonString) — negative or positive
- Implement leaderstats and bind to PlayerAdded/Removing.
- Tests: Spawn player, check custom model spawned, Bits change on ModifyBits.

Step D — CombatService + HeartSystem
- Create ReplicatedStorage/Modules/HeartSystem.lua (contract in §6).
- Create CombatService.server.lua exposing:
  - CombatService:ApplyDamage(targetUnitId, damageType, attackerPlayer) — calls HeartSystem:TakeHit
  - CombatService:RegisterBuilding(buildingId, buildingRef, attributes) — store resistances and shield state
- Implement building HP percent calculation and RF_GetCoreStatus hook for HUD.
- Tests: apply damage to dummy units and assert stage transitions and stun durations.

Step E — BuildManager
- Implement BuildPlot registry (detect Cores in Workspace/Map_Ryloth/Cores/).
- API:
  - BuildManager:GetAvailableCategoriesForPlayer(player, coreId) -> list with locked/unlocked flags
  - BuildManager:AttemptPurchase(player, coreId, plotIndex, categoryId, buildingType) -> success/fail + reason
  - BuildManager:PlaceBuilding(buildingDef, coreId, plotIndex, player)
- Add server-side ghost finalization: client ghost preview allowed but server places final.
- Tests: open radial, attempting to buy without Bits -> fail with reason; buy with Bits -> building placed; category unlock flow tested.

Step F — ResourceManager
- Implement plant spawns: each plant spawn point is a folder with N plants. On destroy, call ResourceManager:SpawnStuds(position, amount, lifetime).
- Implement Bit Well income ticks (e.g., add small Bits every 3s).
- Tests: destroy plant → studs spawn → player pick up → Bits added.

Step G — SpeederManager
- API:
  - SpeederManager:SpawnSpeederForPlayer(player)
  - SpeederManager:HandleInput(player, inputPayload) — called from RemoteHandler
  - SpeederManager:Fire(player, weaponId) — spawns projectile and passes damage to CombatService
- Implement server-driven movement using AssemblyLinearVelocity + AlignOrientation to follow input vector and yaw. Use smoothing interpolation on server if needed.
- Speeder should auto-respawn after SPEEDER.RESPAWN_DELAY when destroyed or too far.
- Tests: enter speeder, send input (simulated), confirm server moves speeder object, fire projectile and apply damage.

Step H — BarracksService + UnitAIService
- BarracksService:
  - Track per-barrack spawn timer.
  - Spawn troop instances (pool) and register to UnitAIService.
- UnitAIService:
  - Implement group leader-follower movement.
  - Provide FollowPlayer method which binds unit to player and sets unit to follow leader position offset pattern.
  - Implement AttackTarget(unit, targetInstance) which commands nearest weapons to shoot at target (server creates projectiles or damage events).
- Tests: spawn barrack, wait for spawn cycles, reach 16 spawn threshold -> units start wandering. Press G->units follow player. Player fires while units following -> units attack same target.

Step I — Vehicle drop-offs & walker AI
- When a vehicle building is placed, schedule an air-dropship spawn (server) that teleports or spawns the vehicle at the building after a delay (e.g., 5s). If more than one of that vehicle exists, do not spawn duplicate.
- If vehicle destroyed, respawn after 10s at building spawn point.
- Walker integration: walker uses procedural animations (provided by user). Add AI glue to set movement targets and attack logic; when player takes control, disable AI and set controlledBy = player.
- Tests: place AT-TE building -> dropship spawns vehicle -> vehicle AI patrols -> player requests control -> player gets control.

Step J — Torpedo & homing logic
- Torpedo pickup: RE_Torpedo_PickupRequest validated by RemoteHandler; server adds torpedo item to speeder inventory (simple flag).
- Torpedo firing: server creates a homing projectile with logic:
  - Acquire valid target (AT-TE, Supertank, Core) within lock range. If no valid target, abort.
  - Use a server coroutine to update projectile velocity each tick: velocity = (target.Position - projectile.Position).Unit * speed, and apply a slight steering max turn per tick.
  - On impact, call CombatService:ApplyDamage(target, "Torpedo", attacker).
- Tests: spawn torpedo pickup -> pickup -> fire at Core -> target destroyed or hp reduced per rules.

Step K — Shields & Tesla mechanics
- Shield objects: attach ShieldComponent module to buildings; store shieldActive bool.
- Shields block or absorb projectiles: CombatService when resolving damage checks target.shieldActive and if true, ignore or reduce damage based on building level.
- RayShield: implement a RayShieldManager in CombatService that maps rayShieldId -> targetBuildingId. When RayShield active, target building is invulnerable to normal damage (but torpedo/Tesla or ray break logic overrides).
- Tesla: implement TeslaAura that on placement registers a circular aura. While active it increases shieldResistance value on nearby shield components and periodically fires bolts at nearest vehicle/unit. Tesla destruction removes aura.
- Tests: build shield, try to shoot core with speeder -> blocked; build Tesla near shield -> shield harder to toggle; RayShield redirect test.

9 — UI implementation details (precise UI hierarchy, data flow & input)
Create CLIENT components:

InputController.client.lua
- Central input mapping file with table:
  local InputMap = {
    PC = { Move = {"W","A","S","D"}, Jump = "Space", Sprint = "LeftShift", Interact = "E", CallTroops = "G", Fire = "Mouse1", Aim = "Mouse2" },
    XBOX = { A = "A", B = "B", X = "X", Y = "Y", RT = "RT", LT = "LT" }
  }
- Expose API InputController:Bind(actionName, callback) for other client modules.

UIController.client.lua
- Build HUD elements as ScreenGui with Frames:
  - TopLeft Frame → BitsLabel, HeartsContainer (4 heart icons).
  - TopRight Frame → MiniMapFrame (render simple icons, not a full minimap system — use static overlay with core icons; advanced: update positions via ReplicatedStorage events).
  - BottomCenter Frame → EnemyCoreStatusLabel (percentage), RespawnTimerLabel.
  - RadialBuildMenu as separate Frame that is toggled by RE_Build_RequestOpen response.
- UIController listens to server via remotes or GetCoreStatus RF for continuous updates (not more than 1 update/sec for HUD to reduce network).

RadialBuildMenu.client.lua
- Build radial using ImageButtons arranged in circular layout. Sector selection via left stick or mouse.
- When a sector is selected, populate sub-panel with buildings and costs.
- On confirm: send RE_Build_RequestPurchase with chosen buildingId & server will validate and respond success/fail.

Hint/Proximity UI
- Client polls (every 0.25s) for nearest interactable via ProximityPrompt (use Roblox native ProximityPrompt). Also show textual hotkeys overlay for the user mappings (E/X or Y/G).

Controller navigation
- When radial open, capture gamepad input and route DPad/LeftStick to sector selection. Support A to confirm, B to cancel.

10 — Testing, logging & debug utilities (what to produce)
- ReplicatedStorage/Docs/TESTS.md listing test steps & expected outcomes (detailed earlier).
- Add DEV_MODE boolean in GameConfig to enable verbose logs.
- Event logging format:
  - [GameManager][INFO] MatchStart time=...
  - [RemoteHandler][WARN] RejectedRequest player=User123 event=RE_Build_RequestPurchase reason=InsufficientBits
  - [CombatService][DEBUG] UnitHit unitId=... stage_before=stage2 stage_after=stage1
- Provide automated test scripts in ServerScriptService/TestMatches/:
  - Test_SmokeStart.lua → spawn a server + 2 players, assert team assignment.
  - Test_BuildFlow.lua → simulate purchase flow (use RunService:BindToRenderStep for local test)
- For each failing test include screenshot or console log snippet describing the failure.

11 — Deliverables & commit expectations (exact)
For final integration, produce and commit these exact files/paths (if already exist, update):

- CHANGELOG.md (root)
- ReplicatedStorage/GameConfig (ModuleScript)
- ReplicatedStorage/Remotes/* (RemoteEvent & RemoteFunctions)
- ReplicatedStorage/Docs/ARCHITECTURE.md
- ReplicatedStorage/Docs/TESTS.md
- ReplicatedStorage/Docs/PROGRESS_<Service>.md after each major service implemented
- ServerScriptService/Services/ all service scripts (GameManager, PlayerManager, SpeederManager, BuildManager, ResourceManager, BarracksService, UnitAIService, CombatService, RemoteHandler)
- StarterPlayer/StarterPlayerScripts/ client scripts (ClientController, UIController, InputController, SpeederClient, UnitControlClient)
- ServerScriptService/TestMatches/ test scripts
- ReplicatedStorage/Modules/HeartSystem.lua and helper modules (PathUtils, PoolManager)
- PRIORITY.md with high/medium/low remaining items and approximate dev time estimates (small numbers: e.g., High=2–5hrs, Med=4–12hrs, Low=12+hrs)

Each file must have a header comment:
-- File: <path>
-- Summary: one-line summary of purpose & changes

12 — Edge cases, ambiguous rules and how to handle them (agent must follow these decisions, do not proceed without asking the user only for truly missing assets)
- If multiple conflicting cost values appear in repo: prefer ReplicatedStorage/GameConfig if present; otherwise use the values from the design doc above. Log conflict in CHANGELOG.md.
- If a model name in the doc is missing in ServerStorage: create a placeholder model named exactly as the missing model and mark TODO.
- If performance limit hits: automatically lower troop wander group sizes and pathfinding concurrency; report change and reason in progress notes.
- If procedural walker animator exists: integrate – do not rewrite it. Add glue code for AI and control switching. If animator conflicts with AI (e.g., movement code), adapt AI to feed high-level targets and let procedural animator move the legs.

13 — Acceptance criteria (final pass)
Before saying a major subsystem is "done" ensure:
- Unit tests & manual steps in TESTS.md pass for that subsystem (at least smoke tests).
- All remotes used by that subsystem run through RemoteHandler and validate inputs with plausible rejection messages if invalid.
- No print spam in non-DEV_MODE. Use warn or logging module when DEV_MODE.
- The UI is functional: radial menu opens on plot interaction, categories show locked/unlocked, purchase sends remote and building appears in correct plot with owner ring color.
- Heart system transitions are visible (hit reduces heart visually or logs stage transition).
- Speeder moves responsively with server authoritative updates and projectiles apply damage server-side.
- Document any missing assets and mark them clearly.

14 — Example log & test messages (copyable)
- [PROGRESS][GameManager] Assigned players: Alice->REP, Bob->CIS, Bits initialized 15000 each
- [TEST][BuildManager] AttemptPurchase failed: player=Alice reason=InsufficientBits (cost=20000, has=15000)
- [DEBUG][HeartSystem] unitId=U_012 HitType=Normal StageBefore=stage2 StageAfter=stage1 StunApplied=true
- [ALERT][RemoteHandler] Repeated invalid remote call: player=EvilUser event=RE_Build_RequestPurchase ip=... (note: do NOT log IP in production; use only in dev mod)

15 — Final behavioral instructions to the agent
- Work iteratively (A→K). After each service complete: commit files, run smoke tests, and create PROGRESS doc with required manual instructions for the developer to verify in Roblox Studio.
- Stop and ask the user immediately if any critical model or folder is missing (e.g., Workspace/Map_Ryloth/Cores or ServerStorage/Models/Rep_General) or if the user wants a different starting Bits value than GameConfig.STARTING_BITS.
- When uncertain about any design choice, prefer conservative defaults that preserve game balance and performance.
- Keep every change logged in CHANGELOG.md with line references to the original files.





Infos :

GENERAL BUILDING SYSTEM
-----------------------
- Each building is made up of multiple parts.
- Health bar system:
    - Hidden when full health.
    - Appears when building takes damage.
- Regeneration:
    - All buildings regenerate health slowly.
    - Command Center regenerates very fast (only destroyable by many troops/vehicles, not speeders).
- On destruction:
    - Building unanchors.
    - Explodes into flying parts that despawn shortly.
    - Drops 70% of the bits required to build it.
- Applies the same way to plants and rocks.

RESOURCE SYSTEM
---------------
- Folder: MiscPrefabs (contains smaller models like Stud model).
- Studs/bits drop from:
    - Destroyed plants/rocks.
    - Destroyed buildings.
    - BitWell generator.
- Rocks/plants spawn around the map:
    - Explode when approached/shot by vehicles.
    - Drop studs that can be collected for money.

AUDIO SYSTEM
------------
- Sounds added into a folder.
- Can be requested for specific needs.

BUILDING DURABILITY TYPES
-------------------------
1. Normal:
    - Takes damage from everything.
2. Silver:
    - Immune to lasers.
    - Vulnerable to proton cannons, rockets (Hailfire, AAT, walkers except Droid_Spider and AT-RT), rocket troops, CIS Supertank.
    - No damage from LaserTank or HomingSpider.
3. Gold:
    - Immune to high-damage weapons (proton cannon, tanks, walkers).
    - Vulnerable if:
        - Shot by 16+ laser troops repeatedly (melts over time).
        - Attacked by HomingSpider or Republic LaserTank beams (explodes after ~6 seconds of firing).

BUILDING CATEGORIES
-------------------

1. PROTON CANNONS & TESLAS
    - Tesla:
        - Damage radius: 135.
        - Constant damage to everything in range.
    - Proton Cannon:
        - AI-controlled by default:
            - Attacks troops/vehicles only.
            - Does not attack buildings.
        - Can be controlled by friendly player.
        - Enemy can take control if health < 50%.
        - Close-range defense: fires small blaster shots.
        - Extremely powerful, damages everything (even AT-TE and Supertank).
        - Can destroy Command Center.
    - Units in category:
        - 3 Teslas (Normal, Silver, Gold).
        - 3 Normal Proton Cannons.
        - 2 Silver Proton Cannons.

2. SMALL AIR SUPPORT
    - Republic:
        - 3 AT-RT (fast walker, stronger than speeder).
    - Total: 8 buildings.

3. TROOP BARRACKS
    - 6 Normal Barracks (troopers).
    - 2 Rocket Troop Barracks.
    - Same for Republic and CIS.

4. HEAVY AIR SUPPORT
    - Republic:
        - 3 AT-ST
        - 3 LaserTank
        - 2 AT-TE
    - CIS:
        - 2 HailFire
        - 2 AAT
        - 2 HomingSpider
        - 2 Supertank

5. SHIELD GENERATORS
    - 2 Normal, 2 Silver, 2 Gold, 2 empty slots (both factions).
    - Creates large shield bubble around core.
    - Properties:
        - Blocks all projectiles and vehicles.
        - Troops and players on foot can enter.
        - Vehicles/walkers stay outside, players eject automatically.
    - Deactivation:
        - Each shield generator has a proximity prompt.
        - Any player can deactivate it (shield disappears).
        - Can also be destroyed by enemy units.
    - Strategy: can protect Teslas and other defenses.

6. REY SHIELDS
    - 2 Normal, 2 Silver, 4 empty slots (both factions).
    - Function:
        - Projects protective ray onto building/core.
        - Operated by player (enter and rotate like vehicle).
        - Targeted building becomes indestructible while ray is active.
        - Cannot be disabled, only destroyed.
        - If under 50% health: enemy can rotate ray away or destroy it.
    - Special: Can target Core Ball (gives special effect).

7. TORPEDO LAUNCHER
    - High-damage structure.
    - Function:
        - Inactive alone.
        - Speeders can collect torpedo balls by flying above it.
    - Torpedo Ball mechanics:
        - Works like homing rocket.
        - Auto-targets cores, AT-TE, Supertank.
        - Removes 1 purple heart (out of 5) per torpedo.
        - Can randomly destroy core buildings (Normal, Silver, Gold, ReyShielded).
    - Balance:
        - Only Flyingp Vehicles can pick them up.
        - Must be heavily protected (enemies can steal and use against you).

8. SPECIAL – BITWELL
    - One per faction.
    - Produces large amounts of studs/bits.
    - Both players can collect.
    - Generates bits every 100 ms.

VEHICLE HEALTH SYSTEM
---------------------
- Vehicles have hearts with multiple stages.
- Example: AT-TE
    - Starts with 4 purple hearts.
    - To capture:
        - Must be hit with 4 torpedoes (1 per heart).
        - Becomes stunned for 5 seconds.
        - Enemy can enter during stun.
        - Owner can enter at any time.
- Supertank has same system.
- Full vehicle heart stats are provided in external spreadsheet.

EXTRA NOTES
-----------
- More sounds will be added later.
- Spreadsheet includes details about vehicles and heart stats.

Important Notes:
what is ready : 
Speeder systems are  functional.
Game Initiaziation is functional.
Ressource System is functional.

The Rest isnt ready yet.
If u want something look trough the code and see what is ready aswell as the folders.