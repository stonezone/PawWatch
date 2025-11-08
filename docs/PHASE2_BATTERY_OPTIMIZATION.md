# Phase 2 – Battery Optimization Notes

_Updated: November 8, 2025_

This document summarizes the runtime guard + smart polling work now live in 1.0.9 and outlines how QA should validate it on real hardware.

## Architecture Snapshot

| Component | File(s) | Purpose |
| --- | --- | --- |
| `ExtendedRuntimeCoordinator` | `pawWatch Watch App/WatchLocationProvider.swift` | Wraps `WKExtendedRuntimeSession`, restarts it after invalidation (~5 s backoff), and emits OSLog signposts for start/stop/expiry. |
| `TrackingPreset` enum | same | Encapsulates Aggressive/Balanced/Saver desiredAccuracy, distanceFilter, and activityType values so we can pivot quickly without scattering magic numbers. |
| Adaptive tuning | same | Each published `LocationFix` feeds `updateAdaptiveTuning` which promotes/demotes presets based on battery (<20 % → Saver) and speed (<0.5 m/s → Balanced). |
| Watch toggle (`WatchSettingsView`) | `pawWatch Watch App/ContentView.swift` | Persists “Runtime Guard & Smart Polling” in `@AppStorage`; flipping it dynamically calls `WatchLocationProvider.setBatteryOptimizationsEnabled`. |
| OSLog instrumentation | watch + iOS | `Logger` + `OSSignposter` emit events for ExtendedRuntime, TrackingSession, preset changes, WC activation, fix receipt, and HealthKit auth requests (see `com.stonezone.pawwatch`). |
| HealthKit surfacing | `PetLocationManager`, `SettingsView` | Tracks workout + heart-rate authorization states, exposes CTA to re-request access, and logs failures. |

### Behavior Overview
- **Default state**: Runtime guard enabled. Starting tracking kicks off HKWorkoutSession + WKExtendedRuntimeSession, applies Aggressive preset, and records the interval via signposts.
- **Preset switching**: Saver engages automatically when watch battery <20 %. Balanced is used whenever speed <0.5 m/s (stationary/slow walk). Aggressive returns when moving faster _and_ battery ≥20 %.
- **Toggle off**: Immediately stops the extended runtime guard and locks location manager back to Aggressive settings. Toggle can be changed mid-session; WatchLocationManager forwards the new state down to the provider.
- **Error handling**: Any runtime invalidation or WC error is logged via OSLog so QA can correlate with Console.app captures.

## QA & Metrics

| Scenario | Steps | Metrics to Capture |
| --- | --- | --- |
| Runtime guard soak | Enable toggle, run 60–90 min outdoor session. Confirm ExtendedRuntime signposts show continuous coverage (no large gaps) and collect battery start/end + preset transitions. | `battery_start`, `battery_end`, preset timeline, count of `ExtendedRuntime.Invalidated` events. |
| Toggle regression | Start tracking → disable toggle → wait 5 min → re-enable. | Verify location frequency drops to Aggressive-only when disabled and resumes adaptive behavior on enable; confirm no crashes when flipping mid-session. |
| Motion sweeps | With toggle on, perform stationary (10 min), slow walk (10 min), jog (10 min). | Log preset chosen, update interval, WC message rate, GPS accuracy jitter per segment. |
| Low battery guard | Drain watch to ~25 %, resume session, continue until ≤15 %. | Ensure Saver preset holds, no repeated WKExtendedRuntime invalidations, and OSLog marks battery thresholds. |
| HealthKit permissions | Deny workout/heart rate on iPhone, then grant via Settings CTA. Repeat on watch. | Confirm Settings tab reflects statuses and CTA triggers HK auth sheet; logs should record success/failure. |

### Data Logging Tips
- Run `log stream --predicate 'subsystem == "com.stonezone.pawwatch"' --style json` on both watch + phone to capture signposts.
- Export watch battery stats from the pawWatch iOS Settings screen after each run, plus WC reachability toggles.
- Store aggregated runs in `docs/HARDWARE_VALIDATION.md` tables once measurements are captured.

### Open Risks / Follow-ups
- Low-battery alerts (30/20/10 %) and haptic prompts remain TODO (Phase 2, item 3).
- No automated GPX comparison yet; manual overlays still required to confirm accuracy impact of Saver preset.
- Need at least two hardware devices to confirm ExtendedRuntime behavior on watchOS 11.x vs 10.x if we expand support.
