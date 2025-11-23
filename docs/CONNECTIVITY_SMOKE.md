# Connectivity Smoke Checklist

1) Fresh install (sim or device)
   - Delete existing pawWatch on iPhone + Watch.
   - Build `pawWatch` for the chosen destination (sim: `xcodebuild -workspace pawWatch.xcworkspace -scheme pawWatch -destination 'platform=iOS Simulator,name=iPhone 17' build`).
   - Ensure the watch companion is built at least once (`xcodebuild -workspace pawWatch.xcworkspace -scheme "pawWatch Watch App" -destination 'generic/platform=watchOS Simulator' build`) if using simulators.

2) Initial launch
   - Open pawWatch on iPhone; verify WCSession activates (logs from `PhoneWatchConnectivityManager` should show `Activation State: ✅` and `isWatchAppInstalled` true after pairing).
   - On Watch, open pawWatch and run “Start Tracking”; verify WCSession activation logs and `watch_activated` diagnostic is sent.

3) Round-trip messaging
   - From Watch: start tracking, confirm fixes appear in the iOS debug log (`📍 Received location`).
   - From iPhone: trigger stop (`pawWatch` deep link `pawwatch://stop-tracking` or UI), confirm Watch receives `stop-tracking` and stops.

4) Triple-path verification
   - Put iPhone app backgrounded: confirm context/file transfers still deliver (check iOS logs for `Received application context` or file receipts).
   - Airplane-mode iPhone (keep Bluetooth/Wi‑Fi off briefly), then restore; confirm queued transfers arrive (check `outstandingFileTransfers` goes to 0).

5) Diagnostic script (optional, real devices)
   - Run `scripts/diagnose_connectivity.sh` while reproducing any disconnect; capture the log bundle and note `identityservicesd`/`WatchConnectivity` sections.

Pass criteria
   - `isWatchAppInstalled` and `isCompanionAppInstalled` become true within 5s of launch.
   - At least one fix delivered to iPhone within 10s of starting tracking.
   - No repeated `sessionNotActivated`/`watch app not detected` after retries.
