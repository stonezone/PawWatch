# pawWatch

A paired iOS + watchOS experience for real-time pet tracking. The iPhone app renders a Liquid Glass dashboard with MapKit trail overlays, while the Apple Watch companion captures 1 Hz GPS fixes, keeps a HealthKit workout alive for background execution, and streams telemetry back through WatchConnectivity.

## Table of Contents
1. [Highlights](#highlights)
2. [Architecture](#architecture)
3. [Data Flow](#data-flow)
4. [Requirements](#requirements)
5. [Getting Started](#getting-started)
6. [Build Targets & Commands](#build-targets--commands)
7. [Swift Package: `pawWatchFeature`](#swift-package-pawwatchfeature)
8. [Apple Watch Companion](#apple-watch-companion)
9. [Configuration & Entitlements](#configuration--entitlements)
10. [Testing](#testing)
11. [Troubleshooting](#troubleshooting)
12. [Contributing](#contributing)
13. [License](#license)

## Highlights
- **Live trail visualization** – `PetStatusCard`, `PetMapView`, and MapKit overlays show the latest fix, accuracy, and a user-configurable (50–500) breadcrumb trail persisted in shared defaults.
- **Battery diagnostics** – `PerformanceMonitor` clamps readings to `[0, 1]`, exposes instantaneous vs EMA-smoothed drain metrics, and updates copy across the dashboard, widgets, and watch pills when values are still “estimating.”
- **Extended runtime guard** – The watch app auto-detects `WKBackgroundModes` support and mirrors a persisted developer toggle so QA can enable extended runtime without editing schemes or environment variables.
- **Stationary cadence control** – Developer settings tune idle heartbeats (30–60s) and full-fix bursts (90–300s) so the watch still proves liveness while stretching battery during bench tests.
- **Watch-powered telemetry** – `WatchLocationProvider` keeps an HKWorkout alive, requests best accuracy GPS, and relays data via context, interactive messages, and file transfers.
- **SPM-centric codebase** – All production Swift code lives in the `pawWatchFeature` Swift Package, so the app targets remain thin wrappers.
- **Companion-first install** – The iOS build embeds `pawWatch Watch App.app` so sideloading the phone app automatically deploys the Watch app (ideal when Xcode cannot pair directly with a watch).
- **Modern Swift** – Swift 6.2, `@Observable` state, async/await, Liquid transitions, and buildable folders for conflict-free development.

## Architecture
```
pawWatch/
├── pawWatch.xcworkspace          # Open this file in Xcode 16.3+
├── pawWatch.xcodeproj            # App + watch targets + Embed Watch phase
├── pawWatch/                     # Minimal iOS shell (Assets, App entry, Info)
├── pawWatch Watch App/           # Native watchOS UI that imports pawWatchFeature
├── pawWatchPackage/
│   ├── Package.swift
│   ├── Sources/pawWatchFeature/  # Shared presentation, state, connectivity
│   └── Tests/pawWatchFeatureTests/
├── pawWatchUITests/              # XCUITests orchestrated by pawWatch.xctestplan
└── Config/                       # Shared/Debug/Release/Test xcconfigs + entitlements
```
**Key decisions**
- Workspace-first layout keeps the app target, package target, and watch target in sync.
- Buildable folders mean dropping Swift files inside `Sources/` automatically registers them in Xcode 16.
- Config files (`Config/*.xcconfig`) own bundle IDs, deployment targets, and signing toggles so environment changes do not touch the project file.

## Data Flow
1. **Watch** – `WatchLocationProvider` starts a workout session, configures `CLLocationManager` for 1 Hz updates, and encodes each `LocationFix`.
2. **Transport** – The fix is broadcast via:
   - Interactive messages when the phone is reachable.
   - Application context with a 0.5 s throttle (latest-only background delivery).
   - File transfer as a guaranteed fallback.
3. **Phone** – `PetLocationManager` (in the Swift package) receives fixes, appends them to `locationHistory`, and updates SwiftUI state while tracking reachability/battery.
4. **UI** – `ContentView`, `PetStatusCard`, and `PetMapView` react to the state, draw the map trail, and expose manual refresh + Watch status.

## Requirements
- Xcode 16.3 or newer
- iOS 18.4+ device (MapKit trail rendering uses the latest APIs)
- watchOS 11.0+ Apple Watch for telemetry
- Apple Developer account with automatic signing enabled for both targets

## Getting Started
1. **Clone**
   ```bash
   git clone https://github.com/stonezone/PawWatch.git
   cd PawWatch
   ```
2. **Open the workspace** – `open pawWatch.xcworkspace`
3. **Select the `pawWatch` scheme** and choose your iPhone device.
4. **Ensure the paired Apple Watch is unlocked** so Xcode can deploy the embedded app.
5. **Hit Run**. Grant Health, Location, and Motion permissions the first time.

### Quick smoke test
If your Watch is unavailable, you can simulate fixes by modifying `PetLocationManager` inside a Preview environment or by stubbing `WatchConnectivity` payloads.

## Build Targets & Commands
| Scheme | Description |
|--------|-------------|
| `pawWatch` | iOS app that embeds the watchOS companion via the **Embed Watch Content** phase. |
| `pawWatch Watch App` | Standalone watchOS app target for direct deployment or debugging. |
| `pawWatchFeature` | Swift Package target used by both apps. |

Command-line equivalents:
```bash
# iOS app + embedded watch content
xcodebuild -workspace pawWatch.xcworkspace \
           -scheme pawWatch \
           -configuration Release \
           -destination 'generic/platform=iOS' build

# watchOS target only
xcodebuild -workspace pawWatch.xcworkspace \
           -scheme "pawWatch Watch App" \
           -configuration Release \
           -destination 'generic/platform=watchOS' build

# Entire test plan
xcodebuild -workspace pawWatch.xcworkspace \
           -scheme pawWatch \
           -testPlan pawWatch \
           test
```

## Swift Package: `pawWatchFeature`
The Swift Package contains everything that is shared between the phone and watch experiences.

| Component | Summary |
|-----------|---------|
| `ContentView` | Liquid Glass dashboard with pull-to-refresh and toolbar animations. |
| `PetStatusCard` | Shows latest fix metadata, accuracy, battery, reachability state. |
| `PetMapView` | MapKit 3D trail renderer honoring the user-configurable 50–500 breadcrumb limit. |
| `PetLocationManager` | `@Observable` bridge between WatchConnectivity, CoreLocation, and the UI that dedupes/out-of-order filters fixes and enforces the saved trail limit. |
| `PerformanceMonitor` | Shared metrics engine that clamps battery readings, tracks instantaneous + EMA-smoothed drain, and feeds the dashboard/watch/widgets. |
| `LocationFix` | Codable payload delivered over WatchConnectivity/file transfers. |
| `WatchLocationProvider` | watchOS-only manager that starts HKWorkout sessions and pushes fixes upstream. |

Add dependencies by editing `pawWatchPackage/Package.swift`. Resources can be included via `.process("Resources")` declarations.

## Apple Watch Companion
- Lives in `pawWatch Watch App/` and imports `pawWatchFeature` to access `WatchLocationProvider`, models, and shared UI.
- Extended runtime support is gated by Info.plist `WKBackgroundModes` detection plus a persisted developer toggle surfaced in the QA/dev settings sheet so you can enable/disable the capability without editing schemes.
- Handles GPS capture, HealthKit workout life cycle, and WatchConnectivity state.
- Because the iOS target embeds the watch app (`pawWatch.app/Watch/pawWatch Watch App.app`), you can install the phone app via Xcode, Apple Configurator, or TestFlight and the Watch companion follows automatically.
- When Xcode cannot talk to your physical watch, install the iOS build onto your phone first, then open the Watch app on iOS to finish deployment.

## Configuration & Entitlements
- `Config/Shared.xcconfig`, `Debug.xcconfig`, `Release.xcconfig`, `Tests.xcconfig` control bundle IDs, deployment targets, compiler flags, and versioning.
- `Config/pawWatch.entitlements` and `Config/pawWatch_Watch_App.entitlements` declare capabilities (Location, HealthKit, WatchConnectivity). Update them whenever adding HealthKit types, push notifications, etc.
- `Config/pawWatchWidgetExtension.entitlements` is applied only to Release builds of the widget extension so App Group/push access stays gated until distribution-ready.
- The iOS app similarly applies `Config/pawWatch.entitlements` only in Release, keeping Debug builds entitlement-free to avoid provisioning churn.
- To change signing teams or bundle IDs, edit the xcconfigs instead of the project file.

## Testing
- **Unit / feature tests** – `pawWatchPackage/Tests/pawWatchFeatureTests/` (Swift Testing). Extend here to cover new models or connectivity helpers.
- **UI tests** – `pawWatchUITests/` run through `pawWatch.xctestplan`. Useful for verifying the Liquid Glass layout and connection status pill.
- **Manual watch tests** – Launch the `pawWatch Watch App` scheme on a simulator or device to validate workout + GPS behavior before embedding back into the phone target.

## Troubleshooting
- **“Unable to find module dependency: 'pawWatchFeature'”** – Open the workspace (not just the project) so Xcode resolves the local Swift Package.
- **Watch app not installing** – Confirm the `Embed Watch Content` build phase still lists `pawWatch Watch App.app`. Rebuild the `pawWatch` scheme and redeploy to the phone; the Watch app will appear inside the iOS bundle.
- **Provisioning errors** – Delete derived data, run `xcodebuild -resolvePackageDependencies`, and let Xcode regenerate automatic provisioning profiles for both targets.
- **No GPS fixes coming in** – Ensure the Watch app’s workout session has HealthKit permission and that Bluetooth is enabled on the phone.

## Contributing
1. Fork the repo and create a feature branch off `main`.
2. Make changes in `pawWatchPackage/Sources` (or the relevant target) and keep README/docs updated.
3. Run `xcodebuild test` or the Xcode test plan, plus a physical-device build if your change touches WatchConnectivity.
4. Open a pull request describing user impact and any testing performed.

## License
Released under the [MIT License](LICENSE).
