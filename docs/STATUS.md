# Project Status — November 13, 2025

## Completed This Session
- **Source completeness regression guard:** Added the `exportedSourcesStayInSyncWithWorkingTree` test (see `pawWatchPackage/Tests/pawWatchFeatureTests/pawWatchFeatureTests.swift`). It verifies every Swift file in `pawWatchPackage/Sources/pawWatchFeature` matches the copy embedded in `pawWatchFeatureSources.zip`, and round-trips a `LocationFix` sample through `Codable` to prove the exported types compile.
- **Surf workflow hardening:** `scripts/surf_build.sh` now runs `scripts/export_pawwatch_feature.sh` (placeholder lint + zip refresh) and `swift test` before the simulator builds/install steps. This ensures CI catches stale exports/lint failures automatically.
- **TODO.md updated:** Section 9 now reflects the completed regression work and notes the automated coverage path.
- **Versioning & artifacts:** `scripts/bump_version.py` already advanced the repo to 1.0.54 earlier today; `scripts/export_pawwatch_feature.sh` was re-run after the new test to keep `pawWatchFeatureSources.zip` current.
- **Idle cadence control:** iOS developer settings now push idle cadence presets (Lab, Balanced, Saver) that map to watch-side heartbeats (15–60 s) and stationary full fixes (90–300 s). The watch persists the selection, restarts battery heartbeats at the new interval, and surfaces the applied cadence back to the phone so reviewers can confirm liveness while bench-testing battery impact.

## Remaining Work (per TODO.md)
1. **Section 10 – Documentation & comms:** Refresh `CURRENT_TODO.md`/reviewer notes and update README/hand-off docs to mention the new trail history control, battery semantics, and runtime toggle.
2. **General housekeeping:** Large doc/assets deletions are still staged (see `git status`). We’ve been told not to touch them unless explicitly instructed.

## Active Files / Docs
- `pawWatchPackage/Tests/pawWatchFeatureTests/pawWatchFeatureTests.swift` — new regression test helpers live here.
- `scripts/surf_build.sh` — now orchestrates lint/test/export before simulator installs.
- `TODO.md` — Section 9 marked complete; Section 10 is the next focus area.
- `pawWatchPackage/Sources/pawWatchFeature/RuntimeCapabilities.swift` & friends — already up to date from earlier runtime-capability work; no open edits pending.

## Next Suggested Steps
1. Take on TODO Section 10: update documentation (`CURRENT_TODO.md`, README, hand-off notes) with the trail-history, battery, and extended-runtime info.
2. Review the staged deletions/untracked docs with the requester before committing anything, since they predate today’s work.

All build/test/export scripts were executed most recently at 15:51 PT (see `logs/surf-build-20251113-155126.log`).
