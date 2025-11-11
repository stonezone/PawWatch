# Phase 1 Readiness Checklist

_Created: 2025-11-10_

This document captures the pre-flight tasks required before executing the hardware validation plan in `docs/HARDWARE_VALIDATION.md`. Finish every item below so whoever runs the field tests can focus entirely on collecting data.

## 1. Instrumentation Smoke Tests

### 1.1 Session CSV Export
- [ ] Build to simulator (iPhone 17) and start a mock tracking session (use Developer ▸ Simulate Location).
- [ ] In the iOS app, open **Settings ▸ Session Summary ▸ Export CSV** and confirm the share sheet appears with a non-empty file.
- [ ] If you cannot reach the UI, call `PetLocationManager.sessionShareURL()` from the SwiftUI preview debugger and verify the generated CSV has headers `timestamp,latitude,longitude,h_accuracy_m,preset`.
- [ ] After export, delete the temp file from `/var/folders/.../T/` to avoid leaking historical data.

### 1.2 Log Capture Script
- [ ] Run `scripts/collect_logs.sh --duration 5 --out logs/validation-smoke.jsonl` while the simulator is producing fixes.
- [ ] Open the JSONL and ensure each entry contains `subsystem == "com.stonezone.pawwatch"` plus `category` fields (`Battery`, `WCSession`, `Fix`).
- [ ] Confirm the script exits cleanly with `0` (no lingering `log stream` processes).
- _Note (2025-11-10)_: `logs/phase1-smoke.jsonl` was captured on simulator to verify the script/predicate wiring after fixing the duration flag bug.

### 1.3 Lock-State Telemetry
- [ ] In the watch simulator, start tracking, tap **Lock Tracker**, rotate the crown to unlock, and export iOS logs.
- [ ] Verify console output contains `LockTracker engaged` / `LockTracker disengaged` messages inside `[WatchLocationManager]` or add them before field testing if missing.
- [ ] Ensure lock state propagates to the iOS settings screen (chip should read “Locked” within 5 s). If not yet implemented, add this to the TODO list so field testers know it is expected.

## 2. Device Prep (Day-of-Testing)
- [ ] Update both phone + watch to the latest iOS 26.x / watchOS 26.x builds.
- [ ] Install `pawWatch` iOS app (target 1.0.28) and confirm Settings ▸ Privacy ▸ Health shows **Workout + Heart Rate = Allowed**.
- [ ] Install the watch app directly (Product ▸ Run with watch selected) to bypass the embed bug noted in `docs/TROUBLESHOOTING.md`.
- [ ] Toggle **Lock Tracker** once on-device to ensure crown rotation unlocks reliably and that haptics fire; this avoids surprises mid-run.
- [ ] Capture baseline screenshots of the new Settings chips (battery, reachability, lock state) for the Phase 1 report appendix.

## 3. Data Artifacts to Collect
During field runs, make sure every scenario includes the artifacts below:

| Scenario | Required Files |
| --- | --- |
| Battery Baseline | Session CSV, watch battery screenshots (start/end), log JSONL, ambient temperature note |
| GPS Accuracy (per terrain) | pawWatch GPX/CSV, baseline GPX, `compare_gpx.py` CSV output |
| WC Range | `logs/wc-range-<distance>.jsonl`, screenshot of iOS Settings reachability, note reconnection time |

Upload large artifacts (videos, full logarchives) to the shared drive and note the link in the final report.

## 4. Outstanding Gaps
- Lock state is not yet surfaced in the iOS UI or CSV exports. Add this to the field notes so testers know lock mode is purely a watch-side safeguard for now.
- `WKExtendedRuntimeSession` remains disabled; runs longer than ~2.5 h may still end when watchOS suspends the workout. Monitor for premature termination and document timestamps.
- HealthKit access must stay authorized; if the watch re-prompts mid-run, capture the log snippet and include it with the report.

## 5. Next Actions
1. Finish the smoke tests above and attach the sample artifacts to `logs/README.md` so other contributors can validate tooling quickly.
2. Book the outdoor test windows + hardware assignments in the shared calendar.
3. Once complete, move to `docs/HARDWARE_VALIDATION.md` and execute Phase 1 per the tables there.

> **Reminder:** push updates to `comprehensive_improvement_plan-VIBED.md` after each major milestone so the GO/NO-GO table reflects the latest field data.
