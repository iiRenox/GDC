-- File: ReplicatedStorage/Docs/PROGRESS_RemoteHandler.md
-- Summary: Status, quick tests, and open issues for RemoteHandler.

Status
- Core router online; binds RE_Speeder_UpdateInput, RE_Speeder_Fire, RE_Torpedo_* and RF_Get*.
- Per-player simple rate limiter implemented.
- RF_GetGameConfig returns sanitized subset.

Quick Test
- Call `RF_GetGameConfig` from client; expect non-nil subset.
- Fire `ClientToServerCommand` legacy commands; expect SpeederManager routed.

Open Items
- Add schema validation for build events once BuildManager purchase flow is implemented.
- Add proximity checks (plot distance) for build open/purchase.

