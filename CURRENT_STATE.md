# CURRENT STATE – November 8, 2025

| Item | Status |
| --- | --- |
| iOS App | ✅ Builds & runs on physical iPhone (portrait-only, iPhone-only target) |
| Watch App | ✅ Run from Xcode directly (embedding disabled due to Xcode 26.1 bug) |
| Version | 1.0.9 (runtime guard + HealthKit surfacing) |
| Connectivity | WCSession throttled, file transfers disabled, application-context updates every 0.5 s; extended runtime guard auto-restarts sessions |
| GPS Flow | Watch captures ~1 Hz fixes, adaptive presets modulate accuracy/filtering; iPhone shares `PetLocationManager` state across tabs | 

## Deployment Notes
1. **Phone build**: `pawWatch` scheme → real device. Portrait-only, no iPad.
2. **Watch build**: run `pawWatch Watch App` directly to the watch. Do *not* rely on Embed Watch Content (Xcode 26.1 error 143). Keep the phone app running/foregrounded for fastest WCSession delivery.
3. **Version discipline**: before every commit, run `./scripts/bump_version.py`. The pre-commit hook enforces this.

## Known Issues & Risks
- **Xcode 26.1**: Embedding the watch app fails with `MIInstallerErrorDomain 143`. Workaround is manual install by running the watch target.
- **Reachability**: Phone must stay reasonably close/awake; otherwise interactive messages are throttled and we rely on application context.
- **Permissions**: If the watch denies HealthKit/location, tracking stalls. Settings now shows HealthKit + Location state with CTAs, but users still must grant on-device.
- **Phase 2 validation gap**: ExtendedRuntime + smart polling are implemented but unverified on physical hardware. Need battery + accuracy runs before GO decision.

## Next Steps (from TODO.md)
1. Complete Phase 1 hardware validation (battery, GPS accuracy, WC range) and populate `docs/HARDWARE_VALIDATION.md` tables.
2. Execute Phase 2 validation/tuning runs (runtime guard soak, preset sweeps, toggle QA) and capture findings in `docs/PHASE2_BATTERY_OPTIMIZATION.md`.
3. Continue documentation refresh + watch install troubleshooting once Apple ships an embed fix.
