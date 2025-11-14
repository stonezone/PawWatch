# pawWatch Execution Plan — November 13, 2025

This plan folds in every open item from `CURRENT_TODO.md` plus the outstanding connectivity/ingestion work we identified earlier. Nothing below removes or diminishes the UI you approved; visual changes will be limited to copy updates that clarify behavior.

## 1. Source integrity & export hygiene
1. Add a lint script that scans Swift sources for standalone `...` tokens (or any placeholder markers) and fails CI if found.
2. Verify `LocationFix.swift`, `PetLocationManager.swift`, `WatchLocationProvider.swift`, `MeasurementDisplay.swift`, etc., contain full definitions with no placeholders; restore from git history if needed.
3. Update the package export helper (`pawWatchFeatureSources.zip`) to always pull from the working tree so reviewers never see truncated files again.

## 2. Watch → iPhone ingestion hardening
1. Introduce sequence-based deduplication in `PetLocationManager` using a small LRU of recent `LocationFix.sequence` values; drop duplicates across all transport paths.
2. Enforce ordering by timestamp when appending to `locationHistory` (newest-first insert that respects actual capture time, not arrival order).
3. Add basic quality gating: ignore fixes with horizontal accuracy worse than a configurable threshold or with implausible jumps relative to the previous fix.
4. Cover the ingestion pipeline with unit tests (duplicates, out-of-order delivery, low-quality fixes) and keep the UI logic unchanged aside from cleaner data.

## 3. Error observability for fix decoding & connectivity
1. Replace silent `nil` returns in `decodeLocationFix(from:)` with structured logging + signposts; bubble repeated failures to the user-facing status pill.
2. When interactive sends or file transfers fail, emit categorized errors (`communicationDegraded`, `phoneUnreachable`) via `WatchLocationProviderDelegate` so the UI can react without guesswork.
3. Track decode/connectivity error counts in `PerformanceMonitor` for future diagnostics.

## 4. Battery drain metric semantics
1. In `PerformanceMonitor.recordBattery(level:)` (watch) and `PetLocationManager.persistPerformanceSnapshot` (phone), clamp readings to `[0, 1]` and treat rising battery levels as “no data” rather than negative drain.
2. Smooth the per-hour estimate with an exponential moving average and expose both the instantaneous and smoothed values so the UI can distinguish “estimating” vs “stable”.
3. Update any copy/tooltips referencing battery drain to reflect the new semantics (without altering layout/design).

Status: ✅ Completed Nov 13 — snapshots now carry both smoothed + instantaneous drain, the phone/watch ingestion paths normalize/clamp values, and Live Activity/widgets/watch UI copy displays the dual metrics with updated alerts.

## 5. Trail history flexibility
1. Promote `maxHistoryCount` to a user-configurable (or at least config-driven) value with a sensible ceiling to protect memory.
2. Persist the chosen limit alongside other watch settings so advanced users can opt into longer trails without needing a rebuild.

Status: ✅ Completed Nov 13 — history retention now uses a user-adjustable limit (50–500 fixes) stored in the shared defaults, surfaced in Settings with a Stepper, and enforced/pruned in `PetLocationManager`.

## 6. Location permission clarity
1. Decide (and document) whether phone-side distance tracking is foreground-only. If so, update the status text to state that clearly when the app is backgrounded.
2. If background distance alerts are desired, add the “Always” authorization path and background mode handling; otherwise, ensure we never imply a capability we don’t support.

Status: ✅ Completed Nov 13 — explicitly messaging that distance updates require the iPhone app to stay open (PetStatusCard + Settings blurb), dialing location accuracy to `kCLLocationAccuracyNearestTenMeters`, and keeping permissions foreground-only until a background mode is implemented.

## 7. Performance monitoring alignment
1. Make `PerformanceMonitor` the single abstraction for latency/battery metrics across watch and phone, eliminating the stub implementation and redundant logic inside `PetLocationManager`.
2. Expose a read-only API for the phone UI to display the same metrics the watch is already tracking.

Status: ✅ Completed Nov 13 — `PerformanceMonitor` now owns the smoothing + snapshot generation on iOS via `recordRemoteFix`, the old `PetLocationManager` battery math is gone, and both platforms read the same `latestSnapshot`/computed metrics for UI + Live Activity consumption.

## 8. Extended runtime configuration
1. Replace the `PAWWATCH_ENABLE_EXTENDED_RUNTIME` environment flag with a capability check plus a persisted user/config toggle.
2. Surface the toggle in the developer settings sheet so QA can verify extended runtime without editing schemes.

Status: ✅ Completed Nov 13 — capability detection now keys off the watch Info.plist `WKBackgroundModes` entry, the watch/provider persist the runtime guard preference, WC sync keeps iOS + watch aligned, and a developer sheet exposes the toggle for QA.

## 9. Source completeness regression tests
1. Add a unit test target that instantiates `LocationFix` ↔ `PetLocationManager` using the zipped package to ensure future exports remain compile-ready.
2. Hook the lint/test steps into CI (and `make surf`) so regressions are caught automatically.

Status: ✅ Completed Nov 13 — the `exportedSourcesStayInSyncWithWorkingTree` test unzips `pawWatchFeatureSources.zip` and verifies every Swift file (including `LocationFix`/`PetLocationManager`) matches the working tree, and `scripts/surf_build.sh` now runs the export bundle + `swift test` before Simulator installs so CI catches drift immediately.

## 10. Documentation & comms
1. Once the above changes land, refresh `CURRENT_TODO.md` / reviewer notes so external reviewers know placeholders are gone and ingestion is hardened.
2. Update README/hand-off docs to mention the new history limit setting, battery metric semantics, and extended runtime toggle.

## Execution Notes
- Version bump with every commit (per repo hook).
- Keep UI visuals the same; only copy/tooltips/status text may change where explicitly noted.
- After each major cluster (e.g., ingestion hardening, battery semantics), run `make surf` and capture logs under `logs/` for traceability.
- When zipping sources for reviewers, attach the output of the new lint job to prove files are complete.
