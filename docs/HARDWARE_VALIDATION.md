# Phase 1 Hardware Validation Plan

_Updated: November 8, 2025_

This plan translates the Phase 1 checklist from [`TODO.md`](../TODO.md) into executable steps covering battery life, GPS accuracy, and WatchConnectivity (WC) range. Current build/deployment constraints are summarized in [`CURRENT_STATE.md`](../CURRENT_STATE.md); common failure modes and fixes live in [`TROUBLESHOOTING.md`](../TROUBLESHOOTING.md).

## 1. Test Matrix & Prerequisites

| Item | Details |
| --- | --- |
| Hardware | ≥1 iPhone (iOS 18.x), ≥1 Apple Watch (watchOS 11.x) paired to same Apple ID. Have at least one spare watch for comparison. |
| Software | `main` @ 1.0.8, built from `/Users/zackjordan/code/pawWatch-app`. Install iOS app first, then watch app directly (see `CURRENT_STATE.md`). |
| Permissions | Enable iPhone Location (`While Using`), Motion & Fitness, Bluetooth, Background App Refresh. On watch, approve Workout + Location permission when launching pawWatch. |
| Accounts | iCloud sync enabled, FaceTime/Apple ID signed in on both devices. |
| Logging | Xcode Devices window open for both phone + watch. Enable `log stream --predicate '(subsystem == "com.stonezone.pawwatch")'` if you need raw OSLog captures. |
| Environment | Outdoor test areas that cover (a) open field, (b) urban canyon, (c) wooded trail. Measure approximate loop distance ahead of time. |
| Batteries | Start each run ≥95 % battery on both devices; bring chargers / battery packs so you can reset between scenarios. |

### 1.1 Device Prep Checklist
1. Build `pawWatch` (iPhone) → real device; leave app in foreground.
2. Build `pawWatch Watch App` directly to the watch (Xcode → Product ▸ Run) to bypass Xcode 26.1 embed bug.
3. On watch, open Settings ▸ Workouts ▸ ensure Power Saving Mode is **off** so GPS stays active.
4. Reset any previous WC transfers: delete the iOS app, reboot both devices if `WCSession` fails to reach `.activated` (see `TROUBLESHOOTING.md`).
5. In iOS Settings tab (new UI), verify Reachability = `Reachable` and Location Authorization = `AuthorizedWhenInUse` before starting.

## 2. Battery Baseline Procedure

**Goal**: confirm ≥3 h projected runtime during a continuous outdoor session.

| Step | Action | Notes / Instrumentation |
| --- | --- | --- |
| 1 | Start iPhone + watch screen recordings (optional) and note ambient temperature. | Temperature swings affect battery. |
| 2 | Launch watch app → tap `Start Tracking`. Keep display active via Water Lock / Digital Crown. | Ensures consistent screen-on load. |
| 3 | Begin 60-minute outdoor walk/jog loop with normal dog-walking pace. | Avoid pausing workout. |
| 4 | Every 10 minutes, capture watch battery %, GPS horizontal accuracy (from debug overlay), and WC reachability log snippet. | Use the Settings tab or Xcode console. |
| 5 | At 60m mark, stop tracking, note final battery %, save workout summary screenshot. | Upload to shared drive if needed. |
| 6 | Calculate projected runtime = `60m / (start% - end%) * start%`. | Accept if ≥180 minutes. |

**Acceptance**: `projected_runtime_minutes ≥ 180`. If <180, flag for Phase 2 battery work and annotate external factors (temperature, screen time, cellular usage).

**Battery Result Log Template**

| Run # | Watch Model / OS | Start % | End % | Δ% | Projected Runtime (min) | Ambient °C | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | | | | | | | |
| 2 | | | | | | | |

## 3. GPS Accuracy Study

**Goal**: confirm median horizontal error ≤20 m, 90th percentile ≤40 m across terrains.

1. **Ground Truth Prep**
   - Load a reference GPX/Apple Maps path for each terrain (open field, urban canyon, wooded trail). Measure actual distances via a reliable tracker (e.g., iPhone held in hand with native Workout app recording baseline).
2. **Run Procedure (per terrain)**
   1. Start simultaneous recordings: pawWatch on the watch + baseline tracker.
   2. Walk the course at steady pace, pausing for 10 s at each waypoint so we can match timestamps.
   3. After finishing, export pawWatch trail (`pawWatch` iOS → share GPX/log) and baseline GPX.
   4. Use `scripts/compare_gpx.py` (todo) or a GIS tool to compute point-by-point deltas; log median / p90 horizontal error.
3. **Data Capture**

| Terrain | Distance (km) | Median Error (m) | P90 Error (m) | Max Error (m) | Notes |
| --- | --- | --- | --- | --- | --- |
| Open Field | | | | | |
| Urban Canyon | | | | | |
| Woods / Cover | | | | | |

**Acceptance**: `median ≤ 20 m` and `p90 ≤ 40 m`. If not met, document suspected causes (multipath, canopy) and mitigation ideas (longer averaging, motion filters) for Phase 2.

## 4. WatchConnectivity Range & Recovery

**Goal**: ensure WCSession reconnects within 30 s when devices re-enter ≤50 ft range and maintains data at ≥50 ft typical.

1. **Baseline Check**: With devices side-by-side, confirm `reachable == true` and the iOS Settings panel shows live accuracy updates every ≤5 s.
2. **Separation Scenarios**

| Scenario | Distance | Phone State | Procedure | Metrics |
| --- | --- | --- | --- | --- |
| A | 10 ft | Unlocked | Walk watch 10 ft away for 2 min, keep phone screen on. | Should remain `reachable`. Log message frequency. |
| B | 50 ft | Locked | Lock phone, place indoors; walk 50 ft outside. Stay 3 min. | Expect fallback to application context only; no WC errors. |
| C | 100 ft | Locked | Same as B, extend to 100 ft for 5 min. | Measure time until `reachable` false + time to recover when returning. |
| D | 300 ft | Locked | Leave phone in car, walk 300 ft. After 5 min return quickly. | Record downtime and reconnection time from `[WatchLocationProvider] Reachability changed` logs. |

3. **Logging Instructions**
   - Enable `OS_ACTIVITY_MODE=disable` to keep logs clean if necessary.
   - Annotate each distance + phone state combination in a shared note so we can align with console timestamps.
   - Record `reachability` flips, `WCErrorCodeDeliveryFailed`, and queued message counts.

4. **Acceptance**: `reachable` must remain true for Scenario A; for Scenarios B–D, reconnection time after re-entering ≤50 ft should be `< 30 s` and application-context updates must continue (no data gaps >2 min). Any violation should be logged with reproducer steps in `TROUBLESHOOTING.md`.

## 5. Reporting & GO/NO-GO Gate

After executing all scenarios:
1. Populate the result tables above and attach supporting screenshots/log exports.
2. Summarize findings in the `Outcome` table:

| Metric | Result | Status |
| --- | --- | --- |
| Battery projected runtime ≥3h | | ✅/⚠️/❌ |
| GPS accuracy within spec | | ✅/⚠️/❌ |
| WC range & recovery | | ✅/⚠️/❌ |
| Overall Phase 1 Decision | GO / CONDITIONAL / NO-GO | Justify below |

3. File any bugs discovered and link their IDs here. Update [`CURRENT_STATE.md`](../CURRENT_STATE.md) with the final verdict and [`TROUBLESHOOTING.md`](../TROUBLESHOOTING.md) with new fixes.

## 6. Troubleshooting Notes
- **Install/Pairing issues**: follow the Watch install workaround in `TROUBLESHOOTING.md` before debugging WC logs.
- **WCSession stuck at `.inactive`**: reboot the watch, reopen the iOS app, and confirm Bluetooth is enabled. Check for background refresh disablement.
- **GPS spikes**: verify the watch has sky view; if not, repeat the run. Consider toggling Airplane Mode on iPhone to avoid LTE-assisted corrections during tests.
- **Battery anomalies**: log ambient temp; cold weather can reduce runtime. Re-run in a controlled indoor loop if numbers look off.

## 7. Open Questions / Follow-ups
- Need automation for GPX comparison (`scripts/compare_gpx.py`). Until then, use external GIS tooling (GPXSee, QGIS).
- Investigate capturing WC diagnostics via `log collect --syslog` for deeper analysis during long-range tests.
- Determine whether to block Phase 2 work on any unmet acceptance criteria or allow parallel experimentation (see TODO backlog).

Fill in the result tables as tests complete, then commit this doc alongside log artifacts (if small) or links to shared storage.

