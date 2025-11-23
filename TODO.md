# Critical Fix WS Plan

- [x] Replace LocationFix transport to avoid ApplicationContext loss: queue every fix via `transferUserInfo` (FIFO), attempt `sendMessage` when reachable, and fall back to `transferFile`; add iOS `didReceiveUserInfo` handler.
- [x] Add thermal guard on watch: if `ProcessInfo.processInfo.thermalState` is `.serious`/`.critical`, stop GPS, workout, heartbeat, and extended runtime to protect hardware.
- [ ] On-device validation: clean-install on paired iPhone + Watch, confirm WCSession diagnostics report `isWatchAppInstalled`/`isCompanionAppInstalled` true, verify fixes flow while phone backgrounded, and collect logs via `scripts/diagnose_connectivity.sh`.
- [ ] HealthKit/HKWorkout review: verify prompts on device (ensuring `NSHealthUpdateUsageDescription` is honored), and reframe App Store copy as “Dog Walking Companion” to align with workout usage.
- [ ] Simulator sanity pass with XcodeBuildMCP: build + run iOS and watch targets, ensure no missing resources/plist warnings, and keep exported feature sources in sync.
