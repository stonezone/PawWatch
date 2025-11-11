# Handoff — Ready for Claude

- **Timestamp:** 2025-11-11 01:45 HST
- **Current Version:** 1.0.40
- **Latest Commits:**
  - (pending) Phase 8 — live activity alerts + watch radial history (this change)
  - b9f3e2a — feat: phase 7 glass polish + live activity actions
  - 280a6f5 — feat: phase 6 widget + live activity
  - 1733e88 — feat: phase 5 watch metrics + smart stack prep
  - 01d658b — chore: phase 4 validation and docs

## Done
- Rebuilt iOS History + Settings tabs with stacked `GlassCard` layouts (better contrast, adaptive spacing) and tightened watch settings with carousel spacing for small faces
- Added deep-link-driven Live Activity actions (Stop/Open) plus the `pawwatch://` URL scheme so Lock Screen/Dynamic Island surfaces can open the app or end the activity without new entitlements
- Added an alert-capable `PawActivityAttributes` state + badge treatments in the Live Activity, plus a compact Radial History glance in the watch app that surfaces the latest fixes inside existing glass pills; validated raw `xcodebuild` runs for both schemes and bumped MARKETING_VERSION / Config/version.json to 1.0.40

## Pending
1. Re-enable App Group entitlements for the iOS widget extension (Release-only) so shared snapshots work on device/TestFlight builds; follow the gating plan before shipping
2. Implement push-enabled Live Activity updates (Release-only entitlements, server payloads, CI checks) so alert badges refresh even when the phone app is suspended
3. Wire the stop deep link into the watch tracking flow and capture refreshed screenshots/test notes covering the Phase 8 alert + radial history changes before kicking off the next phase

## Next Owner
1. Execute the App Group re-enable checklist (Release entitlements, Dev Portal wiring, CI gating) and keep `Config/version.json` staged with future commits
2. Follow the push Live Activity plan (token upload, APNs server, BG cleanup) so alert states stay up to date even when the app is backgrounded
3. Extend the stop deep-link to end the watch workout session, and collect QA screenshots/tests for the new alert badge + radial history glance before starting the next phase

## Notes
- documentation_archive/ is tracked; stage TODO updates directly
- Pre-commit hook enforces staging `Config/version.json` with other files (set `SKIP_VERSION_CHECK=1` only for doc-only commits)
