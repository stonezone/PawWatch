# TODO — Code Review Findings (2025‑12‑12)

This file consolidates issues found in the current `pawWatchFeature` code and gives concrete steps to address them. Items are ordered by impact.

## 1. High‑priority production fixes

- [x] **Remove unguarded debug `print` usage in watch code**
  - **Why:** `print()` in release builds is noisy, can hurt performance, and some messages include internal diagnostics that shouldn’t ship.
  - **Where:** watchOS targets (`pawWatch Watch App/*`).
  - **How:**
    1. Replace all `print(...)` calls with `ConnectivityLog.verbose/notice/error` or `logger` equivalents.
    2. If you still want the extra diagnostics for QA, wrap them in `#if DEBUG … #endif` so they compile out of Release.
    3. Verify with a Release build that no `print` output appears in Console.

- [x] **Stop clobbering application context with diagnostics**
  - **Why:** `updateApplicationContext` is latest‑only; sending diagnostics overwrites any heartbeat/lock/runtime context currently in flight and can lead to confusing UI state on iPhone.
  - **Where:** `WatchLocationProvider.session(_:activationDidCompleteWith:error:)`.
  - **How:**
    1. Gate the diagnostic context send behind `#if DEBUG`.
    2. If diagnostics are needed in Release, send them via `sendMessage` when reachable, or `transferUserInfo` with a dedicated `diagnostic` payload.
    3. Ensure the normal heartbeat/lock/runtime context path remains the only Release `updateApplicationContext` usage.
    4. Validate: pair iPhone+Watch, background phone, confirm battery/lock/runtime fields still update after activation.

- [x] **Fix infinite/random animation trigger in map marker**
  - **Why:** `.animation(..., value: UUID())` re‑triggers on every render and can cause constant animation + extra GPU work.
  - **Where:** `pawWatchPackage/Sources/pawWatchFeature/PetMapView.swift` → `PetMarkerView`.
  - **How:**
    1. Remove the `value: UUID()` binding.
    2. Tie the animation to meaningful state (e.g., `locationManager.latestLocation?.sequence` passed down, or `hasValidSize`).
    3. Verify: marker animates on new fixes only, and stays stable otherwise.

- [x] **Make HealthKit read‑permission detection correct**
  - **Why:** `refreshHealthAuthorizationState()` treats “no samples returned” as “not authorized,” which is false when the user is authorized but has zero HR samples. This can mislead settings UI.
  - **Where:** `pawWatchPackage/Sources/pawWatchFeature/PetLocationManager.swift` → `refreshHealthAuthorizationState()`.
  - **How:**
    1. Change the heart‑rate check to interpret *absence of error* as authorized, even if samples are empty/nil.
    2. Prefer a more direct API where available:
       - Use `HKHealthStore.getRequestStatusForAuthorization` to determine if authorization should be requested.
       - Consider tracking an explicit “unknown vs denied vs authorized” tri‑state for read types.
    3. Validate on device:
       - Fresh install with no HR samples → should show “Authorized” after granting.
       - Deny HR permission → should show “Denied.”

- [x] **Remove redundant observation plumbing**
  - **Why:** `PetLocationManager` is both `@Observable` and `ObservableObject` and still imports Combine. This is extra surface area and can cause double‑notification patterns.
  - **Where:** `pawWatchPackage/Sources/pawWatchFeature/PetLocationManager.swift`.
  - **How:**
    1. Decide on one observation system for iOS UI (recommended: keep `@Observable` and drop `ObservableObject` + Combine import).
    2. Update any views still relying on Combine publishers (if any) to use observation directly.
    3. Build/run iOS target; verify UI still updates on fixes and reachability changes.

## 2. Medium‑priority improvements

- [x] **Make filter thresholds configurable / mode‑aware**
  - **Why:** `maxHorizontalAccuracyMeters`, `maxJumpDistanceMeters`, and `maxFixStaleness` are hard‑coded. Emergency vs saver modes likely want different tolerances.
  - **Where:** `PetLocationManager.shouldAccept(_:)`.
  - **How:**
    1. Promote thresholds into a struct keyed by `TrackingMode`.
    2. Store defaults in shared defaults for QA tuning.
    3. Add logs showing which thresholds are active.

- [x] **Standardize logger subsystem strings**
  - **Why:** Mixed casing (`com.stonezone.pawWatch` vs `com.stonezone.pawwatch`) makes filtering logs harder.
  - **Where:** `CloudKitLocationSync.swift`, `PetLocationManager.swift`, `WatchLocationProvider.swift`, `PerformanceMonitor.swift`.
  - **How:** pick one canonical subsystem and update all `Logger(...)`/`OSSignposter(...)` initializers.

- [x] **Review thermal recovery restart path**
  - **Why:** Restart after `.critical` recovery manually re‑creates workout + location updates; ensure no duplicated sessions or missed delegate wiring.
  - **Where:** `WatchLocationProvider.locationManager(_:didUpdateLocations:)` thermal recovery block.
  - **How:**
    1. Confirm `startWorkoutSession` handles “already running” safely.
    2. Add a guard or state check to prevent double workout sessions.
    3. Test by forcing thermal states (or simulating via injected provider).

## 3. Tests / validation

- [ ] **Add Swift Testing coverage for core models**
  - **Where:** `pawWatchPackage/Tests/pawWatchFeatureTests/`.
  - **What to add:**
    1. `LocationFix` round‑trip encode/decode test with sample JSON payload.
    2. `PetLocationManager.shouldAccept(_:)` tests for:
       - duplicate sequence drop
       - low accuracy drop
       - implausible jump drop
       - acceptance of historical fixes
    3. Battery drain smoothing tests in `PerformanceMonitor` (iOS path) using synthetic fixes.
  - **Note:** Use `#expect` / `#require` per Swift Testing docs.

- [ ] **Run full device + simulator sanity passes**
  - iOS: `xcodebuild -workspace pawWatch.xcworkspace -scheme pawWatch test`
  - watchOS: build + run `pawWatch Watch App` on simulator and one physical watch.
  - Confirm no warnings about missing assets, Info.plist keys, or entitlements.

## 4. Existing “Critical Fix WS Plan” (carry‑over)

- [x] Replace LocationFix transport to avoid ApplicationContext loss: queue every fix via `transferUserInfo` (FIFO), attempt `sendMessage` when reachable, and fall back to `transferFile`; add iOS `didReceiveUserInfo` handler.
- [x] Add thermal guard on watch: if `ProcessInfo.processInfo.thermalState` is `.serious`/`.critical`, stop GPS, workout, heartbeat, and extended runtime to protect hardware.
- [ ] On-device validation: clean-install on paired iPhone + Watch, confirm WCSession diagnostics report `isWatchAppInstalled`/`isCompanionAppInstalled` true, verify fixes flow while phone backgrounded, and collect logs via `scripts/diagnose_connectivity.sh`.
- [ ] HealthKit/HKWorkout review: verify prompts on device (ensuring `NSHealthUpdateUsageDescription` is honored), and reframe App Store copy as “Dog Walking Companion” to align with workout usage.
- [ ] Simulator sanity pass with XcodeBuildMCP: build + run iOS and watch targets, ensure no missing resources/plist warnings, and keep exported feature sources in sync.
