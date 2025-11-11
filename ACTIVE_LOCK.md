# ACTIVE LOCK PLAN

## Goals
- Keep the watchOS tracking app actively sampling GPS + sending updates even when the display is off or the user has locked the watch.
- Allow the human/owner to intentionally “lock” the tracker so accidental taps cannot stop tracking while the device is on a pet.
- Preserve the ability to deliver haptics/voice/tone feedback in the future.

## Current Status (Nov 10 2025)
- ✅ **Digital Crown lock overlay shipped.** When tracking is active, the user can tap **Lock Tracker** to show a full-screen overlay that ignores taps. Rotating the Digital Crown ~1.75 turns (in either direction) unlocks the UI and plays a success haptic.
- ✅ **Emergency stop path.** The overlay exposes a destructive button that immediately ends the workout and unlocks the interface.
- ✅ **Workout session continuity.** The lock mode keeps the existing `HKWorkoutSession` + `HKLiveWorkoutBuilder` running, so GPS + heartbeats continue even if the watch display sleeps.
- ✅ **Phone status indicator.** The iPhone Settings screen now mirrors the lock state so owners instantly know when controls are disabled remotely.
- ⚠️ **`WKExtendedRuntimeSession` still disabled.** We continue to run in workout-only mode until Apple approves the entitlement.

## User Flow (implemented)
1. **Start Tracking** → the workout & GPS stream spin up as before.
2. **Lock Tracker button** appears once tracking is live. Tapping it:
   - Captures Digital Crown focus via `WKCrownSequencer`.
   - Shows a blurred overlay with instructions, the elapsed lock time, and an emergency stop button.
   - Plays a confirmation haptic.
3. **Unlock** by rotating the Digital Crown roughly one and a half turns. The overlay disappears, the main UI becomes interactive again, and we play a success haptic.

## Technical Notes
- Overlay uses `digitalCrownRotation` with an accumulator threshold so partial rotations still count after wrist bumps.
- While locked, the underlying view hierarchy stays live (no view teardown), so telemetry charts and heartbeats continue updating once the watch wakes.
- If tracking stops for any reason, the lock automatically disengages to avoid orphaned UI state.
- TimelineView refreshes the “Locked for” label every second without scheduling manual timers.

## Remaining Enhancements
1. **Extended runtime integration** – Flip the existing `ExtendedRuntimeCoordinator` back on (behind a feature flag) once the entitlement lands so lock mode can optionally dim the screen + extend runtime beyond the workout defaults.
2. **Phone-side status chip** – Surface “Locked” state inside the iOS settings/monitoring UI so the owner knows why controls are disabled.
3. **Analytics hook** – Record lock/unlock events plus crown rotation failures to understand how often users need the emergency stop.
4. **Future feedback** – Reserve APIs for haptic cues or watch speaker prompts while locked (for training modes).

## Operational Checklist
- Test lock/unlock on physical hardware (watchOS 26) with gloves or motion to ensure accidental touches no longer stop tracking.
- Confirm battery heartbeats still arrive on the phone during a locked session.
- Validate crown rotation threshold for both directions; tweak `unlockRotationThreshold` if testers report accidental unlocks.

## Deferred Options
- **System Water Lock:** still a fallback instruction but not preferred because it silences the speaker.
- **Auto-lock triggers:** consider auto-locking once a workout has streamed uninterrupted for >1 min or when “Pet Mode” is enabled in phone settings.
