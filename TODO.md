# TODO

## Phase 1 – Hardware Validation (Critical Path)
1. **Physical Deployment**
   - [ ] Install the iOS app + watch app on physical devices and confirm WCSession reaches `.activated` with `reachable == true`.
   - [ ] Verify we can work around Xcode 26.1 error 143 by running the watch target directly.
2. **Battery Baseline**
   - [ ] Run a one-hour continuous outdoor session and log watch battery drop.
   - [ ] Extrapolate expected runtime; capture device model + watchOS build.
3. **GPS Accuracy Study**
   - [ ] Walk a known route (open field, urban, woods) and compare pet trail against ground truth.
   - [ ] Document horizontal accuracy distribution (median, p90).
4. **WatchConnectivity Range**
   - [ ] Test separation scenarios (10ft / 50ft / 100ft / 300ft) with the iPhone locked vs unlocked.
   - [ ] Measure reconnection time after leaving/returning to range.
5. **Report**
   - [ ] Create `docs/HARDWARE_VALIDATION.md` with battery, accuracy, and connectivity findings.
   - [ ] Decide GO / NO-GO for Phase 2 based on success criteria (battery ≥3h, accuracy ±20 m typical, stable connection ≥50 ft).

## Phase 2 – Battery Optimization (unblocks production)
1. **WKExtendedRuntimeSession**
   - [ ] Prototype running `WKExtendedRuntimeSession` alongside `HKWorkoutSession` and compare runtime.
   - [ ] Handle invalidation callbacks + re-entry to workout.
2. **Smart Polling**
   - [ ] Add motion-aware throttling (skip updates when stationary).
   - [ ] Expose update interval presets (Aggressive 10 s, Balanced 30 s, Saver 120 s).
   - [ ] Batch fixes locally and send deltas only.
3. **Low Battery UX**
   - [ ] Surface Watch battery state on both devices with alerts at 30 / 20 / 10 %.
   - [ ] Add haptics/notifications on watch when the owner needs to recharge.

## Engineering Foundations (current sprint)
1. **State Management & Versioning**
   - [ ] Convert `PetLocationManager` to `@StateObject` + share via `@EnvironmentObject`.
   - [ ] Remove redundant MARKETING/CURRENT overrides from `Config/Shared.xcconfig` (source of truth = `Config/version.json`).
   - [ ] Clean up the unused timer in `PetStatusCard` so we only publish when values change.
2. **WatchConnectivity Hardening**
   - [ ] Debounce `session.sendMessage` (only fire when reachable and accuracy improves or N seconds elapsed).
   - [ ] Decide if file transfers are needed; otherwise disable or drain them via `session(_:didFinish:error:)` to stop WCFileStorage warnings.
   - [ ] Log reachability state changes so we can correlate `WCErrorCodeDeliveryFailed` with UI state.
3. **User Feedback & Permissions**
   - [ ] Surface HealthKit + Location authorization status in Settings with CTA buttons to re-enable permissions.
   - [ ] When `WatchLocationManager` hits `kCLErrorDomain`/HealthKit errors, show banners on both watch + phone and offer a “Restart workout” action.
4. **Documentation Refresh**
   - [ ] Rebuild `CURRENT_STATE.md` and a troubleshooting guide summarizing the Xcode 26.1 watch-install bug and manual deployment steps.
   - [ ] Capture the portrait-only/iPhone-only stance + version bump workflow for new contributors.
5. **Watch Runtime UX**
   - [ ] Prototype locking the tracking UI (water-lock/Digital Crown flow) once tracking starts.
   - [ ] Audit background modes after the runtime session changes.

## Backlog / Phase 3 – UX & Productization
- [ ] Implement map enhancements from pet-owner testing (multi-pet, geofence editor, richer history filters).
- [ ] Add low-signal / no-GPS indicators on both devices.
- [ ] Plan beta rollout metrics: crash-free sessions, average tracking duration, owner satisfaction.
