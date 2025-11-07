# pawWatch

pawWatch is a paired iOS + watchOS experience that keeps tabs on your pet’s location in real time. The iPhone app focuses on rich visualization (Liquid Glass UI, MapKit trail overlays, connection health), while the watchOS companion captures GPS fixes at 1 Hz, streams them through WatchConnectivity, and mirrors key stats directly on the wrist.

## Highlights
- **Live trail tracking** – Pet status card, battery estimates, and a MapKit overlay fed by Apple Watch telemetry.
- **Swift Package core** – All production code lives in `pawWatchFeature`, keeping the app target lean.
- **Modern Swift stack** – Swift 6.2, @Observable state, async/await, watchOS 11 workout-driven GPS.
- **Companion-ready build** – The iOS target embeds `pawWatch Watch App.app`, so installing the phone app also deploys the watch app.

## Architecture
```
pawWatch/
├── pawWatch.xcworkspace          # Open this in Xcode 16.3+
├── pawWatch.xcodeproj            # App + watch targets
├── pawWatch/                     # Minimal iOS shell (Assets, entry point)
├── pawWatch Watch App/           # Native watchOS UI backed by WatchLocationProvider
├── pawWatchPackage/
│   ├── Package.swift
│   ├── Sources/pawWatchFeature/  # ContentView, PetLocationManager, WatchLocationProvider, etc.
│   └── Tests/pawWatchFeatureTests/
├── pawWatchUITests/              # XCUITests
└── Config/                       # Shared/Debug/Release/Test xcconfigs + entitlements
```
Key decisions:
- **Workspace-first** so the package and app share a single entry point.
- **SPM buildable folders** let you drop files in `Sources/` or `Tests/` without touching the `.xcodeproj`.
- **Config-driven build settings** keep bundle IDs, versions, and entitlements in one place.

## Requirements
- Xcode 16.3+
- iOS 18.4 (deployment target) and watchOS 11.0 for the companion
- Apple Developer account for codesigning (see `Config/pawWatch.entitlements` and provisioning profile notes)

## Getting Started
1. Clone the repo and install submodules if your workflow uses them:
   ```bash
   git clone https://github.com/stonezone/PawWatch.git
   cd PawWatch
   ```
2. Open `pawWatch.xcworkspace` in Xcode.
3. Select the **pawWatch** scheme and your iPhone device.
4. Ensure the Apple Watch paired with that iPhone is unlocked; Xcode will push the embedded companion automatically.
5. Hit **Run**. The first launch prompts for Location, Health, and WatchConnectivity permissions.

### Command-line builds
```bash
# iOS app with embedded watch app
xcodebuild -workspace pawWatch.xcworkspace \
           -scheme pawWatch \
           -configuration Release \
           -destination 'generic/platform=iOS' build

# Standalone watchOS target (useful for diagnostics)
xcodebuild -workspace pawWatch.xcworkspace \
           -scheme "pawWatch Watch App" \
           -configuration Release \
           -destination 'generic/platform=watchOS' build

# Tests (Swift Testing + XCUITest via plan)
xcodebuild -workspace pawWatch.xcworkspace \
           -scheme pawWatch \
           -testPlan pawWatch \
           test
```

## Swift Package: `pawWatchFeature`
The `pawWatchFeature` target contains all presentation, state, and connectivity logic shared by the phone and watch targets.

| File | Purpose |
|------|---------|
| `ContentView.swift` | Liquid Glass dashboard combining `PetStatusCard`, `PetMapView`, pull-to-refresh, and toolbar actions. |
| `PetLocationManager.swift` | @Observable bridge between WatchConnectivity, CoreLocation, and SwiftUI state (stores last 100 fixes, distance, battery, errors). |
| `WatchLocationProvider.swift` | watchOS-only manager that starts HKWorkout sessions, streams CLLocation updates at ~1 Hz, and relays data via context/messages/files. |
| `LocationFix.swift` | Codable payload shared by both platforms. |
| `PetStatusCard.swift`, `PetMapView.swift` | UI components for status/battery/accuracy and MapKit trail rendering. |

Add new capabilities by editing `pawWatchPackage/Package.swift`; Package resources (images, JSON, etc.) can be added via `.process("Resources")` blocks.

## Apple Watch Companion
- Lives in `pawWatch Watch App/` and imports `pawWatchFeature` to reuse `WatchLocationProvider` APIs.
- Uses HealthKit workouts to keep GPS active and grants background execution for pet tracking.
- Communicates with the phone through WatchConnectivity’s messaging, application context (0.5 s throttle), and file transfer for reliability.
- The Xcode project includes an **Embed Watch Content** build phase so the watch app is bundled under `pawWatch.app/Watch/`.

## Configuration & Entitlements
- `Config/Shared.xcconfig` shares deployment targets, bundle prefixes, marketing/build versions.
- `Config/Debug.xcconfig`, `Config/Release.xcconfig`, `Config/Tests.xcconfig` customize compiler flags per flavor.
- `Config/pawWatch.entitlements` and `Config/pawWatch_Watch_App.entitlements` declare capabilities (Location, HealthKit, WatchConnectivity). Update these when enabling new services.

## Testing
- **Unit / feature tests** live in `pawWatchPackage/Tests/pawWatchFeatureTests/` and can use Swift Testing snapshots or async expectations.
- **UI automation** is in `pawWatchUITests/` with `pawWatch.xctestplan` orchestrating suites across devices.
- For watchOS-specific validation, use Xcode’s Watch simulator and run the `pawWatch Watch App` scheme.

## Troubleshooting
- **“Unable to find module dependency: 'pawWatchFeature'”** – Make sure you open the workspace (not just the project) so the Swift package is resolved.
- **Companion not installing** – Verify the phone build succeeds and that `pawWatch.app/Watch/` contains `pawWatch Watch App.app`. Rebuild the iOS target if needed.
- **Provisioning profile warnings** – Regenerate automatic profiles from Xcode’s Signing & Capabilities pane after updating entitlements.

## Contributing
1. Fork the repository and create a feature branch.
2. Make your changes (Swift code lives under `pawWatchPackage/Sources`).
3. Run the tests (`xcodebuild test` or from Xcode) and ensure watch + phone builds succeed.
4. Submit a pull request that describes the change and any user-facing impact.

## License
This project is released under the [MIT License](LICENSE).
