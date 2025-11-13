# pawWatch TODO

## Current Status (Phase 9 — v1.0.41)
- iOS→watch stop bridge delivered via WCSession (Live Activity stop action now ends watch tracking)
- Release-only App Group entitlements wired for iOS app + widget; Debug builds remain entitlement-free
- Documentation updated (TODO_UI + HANDOFF_STATUS) and Config/version bumped to 1.0.41
- iOS + watch schemes build cleanly via raw `xcodebuild`

## Remaining Phases Before Test Readiness

### Phase 10 — Push-Enabled Live Activity Updates
- Add Release-only APS entitlements for iOS app + widget; keep Debug builds bare
- Register and store APNs push tokens (App Group storage) and upload to backend
- Handle push payloads to update `PawActivityAttributes` while the app is suspended
- Schedule BackgroundTasks for token refresh + data sync; document payload schema
- Refresh screenshots/test notes:
  - Lock Screen Live Activity showing remote alert badge
  - Dynamic Island compact + expanded layout with alert state
  - Watch radial history view showing live sync status
  - Include test notes covering APNs delivery (device suspended, watch confirmation)
- Validation: Release `xcodebuild`, device push tests, watch stop-bridge regression

### Phase 11 — Alert Routing & History Polish
- Add push-confirmed alert routing (bi-directional acknowledgements between phone/watch)
- Improve radial history persistence via App Group shared store
- Expand stop actions with phone↔watch confirmations and UI badges
- Capture updated documentation assets + QA cases

### Phase 12 — Pre-Flight Testing & Packaging
- Run end-to-end device walks (battery, GPS accuracy, connectivity) and log metrics
- Finalize TestFlight provisioning profiles + CI secrets for push/App Group
- Compile final screenshots, release notes, and HANDOFF package
- Tag release (v1.0.42+), archive builds, and prep submission checklist

## Tracking
- Keep `Config/version.json` staged with every code commit (per repo hook)
- Update `documentation_archive/PawWatch_UI_Package/TODO_UI.md` and `docs/HANDOFF_STATUS.md` after each phase
