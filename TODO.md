# TODO

## 1. Stabilize Core State Management
- Promote `PetLocationManager` to a `@StateObject` (and share via `@EnvironmentObject`) so WCSession / CLLocation delegates survive scene transitions.
- Remove the stale MARKETING/CURRENT version overrides from `Config/Shared.xcconfig` so `Config/version.json` + `scripts/bump_version.py` remain the single source of truth.
- Clean up unused timers/state in `PetStatusCard` so we are not publishing one-second updates with no UI consumer.

## 2. WatchConnectivity Hardening
- Debounce `sendMessage` usage: only fire when reachable and either the accuracy improves or N seconds have elapsed; rely on application context/file transfer for the rest.
- Decide whether we still need file transfers. If not, remove that code path or at least drain pending transfers via `session(_:didFinish:error:)` to silence the WCFileStorage warnings.
- Add telemetry around WCSession reachability to avoid the flood of `WCErrorCodeDeliveryFailed` logs when the phone is locked.

## 3. User Feedback & Permissions
- Surface HealthKit and Location authorization status in the Settings tab (with actionable guidance) instead of a single `errorMessage` string.
- When `WatchLocationManager` hits `kCLErrorDomain` or HealthKit `Error(7)`, banner the issue on both watch and phone so testers know to re-open the workout.
- Provide a manual “Re-arm workout” action that restarts the HKWorkoutSession if the system tears it down.

## 4. Documentation Refresh
- Rebuild an authoritative `CURRENT_STATE.md` + troubleshooting doc that summarize the Xcode 26.1 watch-install bug, manual deployment steps, and the remaining gaps once we re-enable embedding.
- Capture the new architecture (iPhone-only portrait build, watch runtime assumptions, version bump workflow) so future contributors don’t need to dig through the archive.

## 5. Watch Runtime Focus
- Evaluate adding `WKExtendedRuntimeSession` in tandem with the existing workout so the watch stays foregrounded even when the wrist drops.
- Document the preferred “water lock / Digital Crown to unlock” UX so we can keep the tracking screen onscreen during walks.
- Double-check background modes/HealthKit queries once the runtime session is in place.
