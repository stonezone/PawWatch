# Handoff — Ready for Claude

- **Timestamp:** 2025-11-11 02:35 HST
- **Current Version:** 1.0.41
- **Latest Commits:**
  - (pending) Phase 9 — stop bridge + release entitlements (this change)
  - 02b9081 — feat: phase 8 alerts + radial history
  - b9f3e2a — feat: phase 7 glass polish + live activity actions
  - 280a6f5 — feat: phase 6 widget + live activity
  - 1733e88 — feat: phase 5 watch metrics + smart stack prep
  - 01d658b — chore: phase 4 validation and docs

## Done
- Rebuilt iOS History + Settings tabs with stacked `GlassCard` layouts (better contrast, adaptive spacing) and tightened watch settings with carousel spacing for small faces
- Added deep-link-driven Live Activity actions (Stop/Open) plus the `pawwatch://` URL scheme so Lock Screen/Dynamic Island surfaces can open the app or end the activity without new entitlements, then extended Phase 8 with alert badges + Radial History glance (v1.0.40)
- Phase 9: wired the stop deep link through WCSession so iOS asks the watch to end tracking (with app-context fallback) and added Release-only App Group/push entitlements for the iOS app + widget extension (Debug remains capability-free); validated raw `xcodebuild` runs for pawWatch and pawWatch Watch App at v1.0.41

## Pending
1. Deliver push-enabled Live Activity updates (Release-only entitlements, server payloads, CI gating) so alert badges refresh even when the phone app is suspended
2. Capture refreshed screenshots/test notes for the new stop bridge + Phase 8 visuals, then move into the Live Activity alert routing work
3. Refresh provisioning/CI profiles so the new Release-only App Group/push entitlements flow through TestFlight without manual tweaks

## Next Owner
1. Execute the App Group re-enable checklist (Release entitlements, Dev Portal wiring, CI gating) and keep `Config/version.json` staged with future commits
2. Follow the push Live Activity plan (token upload, APNs server, BG cleanup) so alert states stay up to date even when the app is backgrounded
3. Extend the stop deep-link to end the watch workout session, and collect QA screenshots/tests for the new alert badge + radial history glance before starting the next phase

## Notes
- documentation_archive/ is tracked; stage TODO updates directly
- Pre-commit hook enforces staging `Config/version.json` with other files (set `SKIP_VERSION_CHECK=1` only for doc-only commits)
