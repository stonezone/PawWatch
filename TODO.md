# TODO

## Immediate (development/testing)
1. **Document current workaround in CLAUDE.md**
   - Add "WatchKit 2.0 architecture" overview.
   - Note Xcode 26.1 bug (real executable + stub) and manual install procedure (run watch targets directly).
   - Add troubleshooting steps for MIInstallerErrorDomain 143.
2. **Create TROUBLESHOOTING.md** summarizing verification workflow (check project.pbxproj, Info.plists, bundle structure) and common error codes.
3. **Add project comment in `pawWatch.xcodeproj/project.pbxproj`** above the disabled "Embed Watch Content" phase explaining it is intentionally off until Apple ships the fix.
4. **Watch runtime focus**
   - Evaluate adding a `WKExtendedRuntimeSession` (alongside the existing `HKWorkoutSession`) so the watch app keeps running even when the user lowers their wrist.
   - Document the Digital Crown water-lock UX vs. simply relying on workout background execution; ensure HealthKit authorization errors are surfaced to the user when denied.

## Medium Term
4. **Automation**: write a small script (or build phase) that inspects the built watch bundle to ensure it contains only the WK stub + PlugIns/ folder (detects future regressions once we re-enable embedding).
5. **Xcode version tracking**: create `XCODE_VERSIONS.md` to log which versions have been tested, including known issues (26.1 bug) and future retests (26.2+, 25.x fallback).
6. **Re-enable watch embedding** once Apple releases a fixed Xcode:
   - Set the Embed Watch Content build phase mask back to `2147483647`.
   - Confirm `pawWatch.app/Watch/` is populated and installation succeeds on device.
   - Update documentation to remove manual-install workaround.

## Validation
7. **Regression test on future Xcode**:
   - Build + install on physical phone/watch.
   - Verify WCSession immediately reports counterpart installed and GPS data flows without manual steps.
8. **Optional compatibility test on Xcode 25.x** (if we need a near-term bundleable build while 26.x is broken).
