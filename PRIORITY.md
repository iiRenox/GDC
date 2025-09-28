-- File: PRIORITY.md
-- Summary: Prioritized roadmap with coarse time estimates per acceptance §11.

## High (2–5 hrs)
- BuildManager purchase validation (Bits, proximity, occupancy, max-per-core)
- RemoteHandler hardening (per-remote schemas, proximity checks, better logging)
- Radial build open/response payload and minimal client hook
- Shield/Tesla baseline (toggle prompt + Tesla aura already in; add shield bubble block)
- Torpedo pickup/fire UX polish and core targeting feedback

## Medium (4–12 hrs)
- BarracksService + UnitAIService (spawn timing, wander threshold, follow player)
- Vehicle drop-off pipeline from buildings; respawn loop for unique vehicles
- CombatService integration for building tiers and unit resistances end-to-end
- RF_GetCoreStatus enrichment (shieldsActive, owner ring color)

## Low (12+ hrs)
- Client UI: full HUD, minimap overlay, radial menu visuals and controller nav
- Procedural walkers AI glue and player takeover flow (RequestUnitControl)
- Visual polish: effects, sounds pass, hit indicators

Notes
- Keep GameConfig as source of truth; log any deviations in CHANGELOG.
- Balance review: BitWell cost (current 30000 vs spec 50000).

