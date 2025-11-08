# TROUBLESHOOTING

## Install / Build
- **Error 143 (WatchKitExtensionlessApp)**: Xcode 26.1 bug. Solution: run the watch target directly (no embedding). Clean both targets, delete from Watch app list on iPhone, reinstall.
- **`WCFileStorage … could not load file data`**: file-transfer path is now disabled; if you still see stale logs, delete the iOS app to clear WatchConnectivity's cache.

## Connectivity
| Symptom | Fix |
| --- | --- |
| `WCSession counterpart app not installed` | Launch the watch app manually once; ensure both devices are on the same Wi‑Fi/Bluetooth and logged into the same Apple ID. |
| `WCErrorCodeDeliveryFailed / NotReachable` | Phone is locked or out of range. The watch now throttles interactive sends; reopen the iOS app to resume immediate updates. |
| Phone Settings row shows “Disconnected” | Open the watch app, confirm the tracking screen is active, then tap “Request Fresh Location” in iOS Settings. |

## Permissions
- **iPhone Location denied**: Settings ▸ Privacy ▸ Location ▸ pawWatch → enable *While Using*. You can open this from Settings ▸ Permissions inside the app.
- **Watch Workout/Location denied**: On the watch, re-open pawWatch, go to Settings → Privacy → Reset Fitness Calibration Data if needed, then tap “Restart Workout” when prompted.

## GPS Accuracy / Battery
- Ensure the watch has clear sky view. Indoors or under dense cover accuracy will degrade past 50 m.
- Battery falls quickly if the watch display sleeps. Use Water Lock / Digital Crown to keep the tracking screen active during tests.

## Logging
- iOS runtime logs can be pulled via Xcode ▸ Devices & Simulators ▸ View Device Logs.
- WatchConnectivity state changes now print as `[WatchLocationProvider] Reachability changed → …`.
