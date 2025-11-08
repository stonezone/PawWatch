# CURRENT STATE – November 8, 2025

| Item | Status |
| --- | --- |
| iOS App | ✅ Builds & runs on physical iPhone (portrait-only, iPhone-only target) |
| Watch App | ✅ Run from Xcode directly (embedding disabled due to Xcode 26.1 bug) |
| Version | 1.0.7 (bumped via `scripts/bump_version.py`) |
| Connectivity | WCSession throttled, file transfers disabled, application-context updates every 0.5 s |
| GPS Flow | Watch captures ~1 Hz fixes, sends context + debounced interactive messages; iPhone maps, history, and status card consume the shared `PetLocationManager` | 

## Deployment Notes
1. **Phone build**: `pawWatch` scheme → real device. Portrait-only, no iPad.
2. **Watch build**: run `pawWatch Watch App` directly to the watch. Do *not* rely on Embed Watch Content (Xcode 26.1 error 143). Keep the phone app running/foregrounded for fastest WCSession delivery.
3. **Version discipline**: before every commit, run `./scripts/bump_version.py`. The pre-commit hook enforces this.

## Known Issues
- **Xcode 26.1**: Embedding the watch app fails with `MIInstallerErrorDomain 143` because Xcode emits a real executable + stub. Workaround is manual install by running the watch target.
- **Reachability**: Phone must stay reasonably close/awake; otherwise interactive messages are throttled and we rely on application context.
- **Permissions**: If the watch denies HealthKit/location, tracking stalls. Use the new Settings section to review iPhone permissions and manually re-open Settings.

## Next Steps (from TODO.md)
1. Complete Phase 1 hardware validation (battery + accuracy baselines).
2. Add motion-aware polling + WKExtendedRuntimeSession to extend battery.
3. Build troubleshooting documentation + automate watch embedding validation once Apple ships a fix.
