# Handoff — Ready for Claude

- **Timestamp:** 2025-11-11 03:40 HST
- **Current Version:** 1.0.42
- **Latest Commits:**
  - (pending) Phase 10 — push-enabled live activity plumbing (this change)
  - d69e574 — feat: phase 9 stop bridge + release entitlements (v1.0.41)
  - 02b9081 — feat: phase 8 alerts + radial history
  - b9f3e2a — feat: phase 7 glass polish + live activity actions
  - 280a6f5 — feat: phase 6 widget + live activity
  - 1733e88 — feat: phase 5 watch metrics + smart stack prep
  - 01d658b — chore: phase 4 validation and docs

## Done
- Rebuilt iOS History + Settings tabs with stacked `GlassCard` layouts (better contrast, adaptive spacing) and tightened watch settings with carousel spacing for small faces
- Added deep-link-driven Live Activity actions (Stop/Open) plus the `pawwatch://` URL scheme so Lock Screen/Dynamic Island surfaces can open the app or end the activity without new entitlements, then extended Phase 8 with alert badges + Radial History glance (v1.0.40)
- Phase 9: wired the stop deep link through WCSession so iOS asks the watch to end tracking (with app-context fallback) and added Release-only App Group/push entitlements for the iOS app + widget extension (Debug remains capability-free); validated raw `xcodebuild` runs for pawWatch and pawWatch Watch App at v1.0.41
- Phase 10: enabled push-driven Live Activity updates by gating APS entitlements to Release builds, introducing a UIKit app delegate with BackgroundTasks scheduling + APNs registration, and adding a push-token coordinator/remote payload handler so Live Activities refresh while the phone app is suspended; raw `xcodebuild` passes for pawWatch (iOS) and pawWatch Watch App at v1.0.42

## Pending
1. Wire backend/token upload + payload signing so stored APNs/device tokens sync to the service, then validate push delivery on device (Lock Screen/Dynamic Island while app is suspended)
2. Capture refreshed screenshots/test notes covering the push-enabled Live Activity (Lock Screen + Dynamic Island) and watch radial history view, and archive them under `screenshots/Phase10`
3. Refresh provisioning/CI/TestFlight profiles with the new push capability so Release builds install without manual tweaks, then proceed to Phase 11 (alert routing + history persistence)

## Next Owner
1. Finish the push delivery path: upload tokens to the backend, document the payload schema/signature, and secure the APNs key in CI/TestFlight pipelines
2. Collect the outstanding screenshots/test notes (Lock Screen, Dynamic Island, watch radial) and attach them to the docs archive for QA
3. Keep `Config/version.json` staged with every commit and move into Phase 11 alert routing/history polish once push validation + assets are complete

## Notes
- documentation_archive/ is tracked; stage TODO updates directly
- Pre-commit hook enforces staging `Config/version.json` with other files (set `SKIP_VERSION_CHECK=1` only for doc-only commits)
