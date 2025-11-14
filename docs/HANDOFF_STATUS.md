# Handoff — Ready for Claude

- **Timestamp:** 2025-11-13 16:05 PT
- **Current Version:** 1.0.54
- **Latest Commits:**
  - ce6630c — Surface connectivity errors and reachability status
  - 52e0cc6 — Harden iOS fix ingestion pipeline
  - 59a81a0 — Add placeholder lint and export scripts
  - 4bec3eb — Refresh TODO plan
  - 330e2ca — Expose reachability hooks and monitor data

## Done
- Section 9/10 follow-up (Nov 13, 2025 – v1.0.54): `exportedSourcesStayInSyncWithWorkingTree` enforces parity between the Swift package and `pawWatchFeatureSources.zip`, ingestion dedupe/order/quality gates now guard `PetLocationManager`, the trail history limit is configurable (50–500 fixes) and persisted across watch/phone, battery drain copy reflects instantaneous vs EMA-smoothed readings, extended runtime is controlled by a persisted developer toggle instead of `PAWWATCH_ENABLE_EXTENDED_RUNTIME`, and README/CURRENT_TODO/HANDOFF were refreshed so reviewers immediately see those semantics.
- Idle cadence + heartbeat control: iOS developer settings now push a selectable preset (Lab, Balanced, Battery Saver) that maps to watch-side stationary full-fix intervals (90–300s) plus a heartbeat keep-alive (15–60s). Watch heartbeats now include the applied intervals so the phone mirrors reality, and the watch respects the configured cadence even after reconnection or reboot.
- Rebuilt iOS History + Settings tabs with stacked `GlassCard` layouts (better contrast, adaptive spacing) and tightened watch settings with carousel spacing for small faces
- Added deep-link-driven Live Activity actions (Stop/Open) plus the `pawwatch://` URL scheme so Lock Screen/Dynamic Island surfaces can open the app or end the activity without new entitlements, then extended Phase 8 with alert badges + Radial History glance (v1.0.40)
- Phase 9: wired the stop deep link through WCSession so iOS asks the watch to end tracking (with app-context fallback) and added Release-only App Group/push entitlements for the iOS app + widget extension (Debug remains capability-free); validated raw `xcodebuild` runs for pawWatch and pawWatch Watch App at v1.0.41
- Phase 10: enabled push-driven Live Activity updates by gating APS entitlements to Release builds, introducing a UIKit app delegate with BackgroundTasks scheduling + APNs registration, and adding a push-token coordinator/remote payload handler so Live Activities refresh while the phone app is suspended; raw `xcodebuild` passes for pawWatch (iOS) and pawWatch Watch App at v1.0.42

## Pending
1. Capture refreshed screenshots/test notes covering the Live Activity (Lock Screen + Dynamic Island) and watch radial history view once hardware QA passes; archive them under `screenshots/Phase10`.
2. Refresh provisioning/CI/TestFlight profiles with the new push capability so Release builds install without manual tweaks, then proceed to Phase 11 (alert routing + history persistence).
3. Backend push integration is deferred: keep `PAWWATCH_PUSH_UPLOADS_ENABLED=NO` until a server/API key/HMAC are available, then flip the flag, inject secrets, and record a device push log.

## Next Owner
1. Collect the outstanding screenshots/test notes (Lock Screen, Dynamic Island, watch radial) after on-device validation and attach them to the docs archive for QA.
2. Regenerate provisioning/TestFlight profiles with APS + App Group, update CI secrets, and document the Dev Portal steps.
3. When backend work kicks off, provision the API key + signature, flip `PAWWATCH_PUSH_UPLOADS_ENABLED` to YES, and run a device push validation before moving into Phase 11 alert routing/history polish.

## Notes
- documentation_archive/ is tracked; stage TODO updates directly
- Pre-commit hook enforces staging `Config/version.json` with other files (set `SKIP_VERSION_CHECK=1` only for doc-only commits)
