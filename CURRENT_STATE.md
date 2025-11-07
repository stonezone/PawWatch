# CURRENT_STATE

## What changed (already pushed)
1. **Watch app metadata tweaks**
   - Added `WKCompanionAppBundleIdentifier = com.stonezone.pawWatch` and set `WKWatchOnly = false` in `pawWatch Watch App/Info.plist`.
   - Switched the watch target product type to `com.apple.product-type.application.watchapp2` so it can embed a WatchKit extension.
2. **WCSession data fixes**
   - iOS now decodes `Data` payloads directly (`PetLocationManager.swift` at ~190–314) and marks the watch reachable whenever any message/context/file arrives.
   - Watch-side `WatchLocationProvider` keeps the latest fix, responds to refresh requests, and sets up battery monitoring.
3. **Project restructuring in progress**
   - Created `pawWatch Watch App Extension/` folder with the watch Swift files and Info.plist intended for an `.appex`.
   - Added placeholder PBX groups/targets (`pawWatch Watch App Extension` target, embed phases, shared scheme skeleton). Changes are in `pawWatch.xcodeproj/project.pbxproj` and the new `pawWatch.xcodeproj/xcshareddata/xcschemes/pawWatch.xcscheme` (also copied under the workspace).

## Current problem
- The watch companion still does **not** install. Console keeps printing `WCSession counterpart app not installed` and `Application context data is nil`.
- The iOS bundle `pawWatch.app` contains an empty `Watch/` directory because the watch container target isn’t being built or embedded; the new extension target isn’t fully wired. `xcodebuild` only builds the iOS app and the shared Swift package.
- Xcode doesn’t know to build/install the watch targets because the shared scheme doesn’t include them (and the workspace-level scheme is missing). As a result, Watch app on iOS never lists pawWatch for installation.

## What’s left to do (for Claude)
1. **Finish watch target wiring**
   - Ensure `pawWatch Watch App` target has the correct sources (probably just the asset catalog + Info) and embeds `pawWatch Watch App Extension.appex` via `Embed App Extensions` phase.
   - `pawWatch Watch App Extension` should own all watch Swift files, reference the Swift package, and have Info.plist + entitlements set correctly.
2. **Scheme + build graph**
   - Update the shared scheme so `pawWatch` depends on `pawWatch Watch App`, which in turn depends on `pawWatch Watch App Extension`. Make sure the scheme file lives in `pawWatch.xcworkspace/xcshareddata/xcschemes/` so `xcodebuild` picks it up.
   - Verify that `xcodebuild -scheme pawWatch` builds the watch container + extension (look for `Embed Watch Content` and `Embed App Extensions` steps in the log).
3. **Deployment sanity check**
   - After the above, a new build should produce `pawWatch.app/Watch/pawWatch Watch App.app` that contains `PlugIns/pawWatch Watch App Extension.appex`. Install on device and confirm the watch app appears in the iOS Watch app.
4. **Remove duplicates**
   - Once the extension layout is working, delete the duplicate watch Swift files sitting directly under `pawWatch Watch App/`—they’re only placeholders right now.

Once that wiring is complete, WCSession should finally see the companion app and start delivering fixes. Use this doc as context for Claude so it knows what’s already been tried and where to pick up.
