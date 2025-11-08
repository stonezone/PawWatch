# FOR_CODE.md – Hand-off Notes for Auto Agent

Latest commit on `main`: `7713052` – Adopt shared `PetLocationManager` and clean status card.
Recent uncommitted changes include:
- WatchConnectivity throttling/file-transfer toggle (`pawWatch Watch App/WatchLocationProvider.swift`)
- Restart button on watch (`pawWatch Watch App/ContentView.swift`)
- Settings permissions helpers and `PetLocationManager` authorization tracking (`pawWatchPackage/...`)
- Docs: `CURRENT_STATE.md`, `TROUBLESHOOTING.md`
- Version bumped to 1.0.8 (run `scripts/bump_version.py` before committing).

## Immediate Actions for Auto Agent
1. **Stage & Commit Pending Work**
   - Run `git add Config/version.json pawWatch.xcodeproj/project.pbxproj "pawWatch Watch App/ContentView.swift" "pawWatch Watch App/WatchLocationProvider.swift" pawWatchPackage/Sources/pawWatchFeature/MainTabView.swift pawWatchPackage/Sources/pawWatchFeature/PetLocationManager.swift CURRENT_STATE.md TROUBLESHOOTING.md`
   - Commit (e.g., `"Throttle WCSession, surface permissions, add state snapshot"`).
   - Push to origin (`git push`).

2. **Continue TODO.md** (in repo root):
   - Phase 1 hardware validation tests (if simulators suffice, at least prepare harness/docs; note: actual hardware validation deferred until morning but capture scripts/checklists).
   - Battery optimization tasks (WKExtendedRuntimeSession, motion-aware throttling) – start with simulator proof-of-concept if possible.
   - Documentation updates (HARDWARE_VALIDATION.md once data is ready).
   - Keep `scripts/bump_version.py` + commit/push cycle per change.

3. **Testing**
   - Use Xcode MCP server (already installed) for iOS/watch simulator builds/tests.
   - Ensure at least simulator builds run clean before pushing.

4. **Communication**
   - Update `CURRENT_STATE.md` / `TROUBLESHOOTING.md` if the status changes
   - Leave a summary in `FOR_CODE.md` or commit messages when moving to next phase.

## Misc
- Orientation stays portrait/iPhone-only.
- Watch app must be run directly (Xcode 26.1 embed bug). Document any additional steps discovered.
- Keep `documentation_archive/` intact (don’t delete).
