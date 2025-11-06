# Complete watchOS 26.0 Target Setup Guide

## Summary

All necessary files for the watchOS app have been created. The final step requires adding the target through Xcode's UI, which is the safest and most reliable method for modern Xcode 16 projects.

## Files Created ✅

### 1. Watch App Source Files
- **Location**: `/Users/zackjordan/code/pawWatch-app/pawWatch Watch App/`
  
- **pawWatchApp.swift** (62 lines)
  - SwiftUI app entry point using `@main`
  - Lifecycle management with ScenePhase
  - Proper state handling (active/inactive/background)
  - Ready for WatchLocationProvider integration

- **ContentView.swift** (96 lines)
  - Main UI with `@MainActor` annotation
  - Location tracking toggle button
  - Status display with SF Symbols
  - NavigationStack with proper styling
  - TODO markers for WatchLocationProvider integration

### 2. Assets and Resources
- **Assets.xcassets/** - Complete asset catalog
  - `Contents.json` - Asset catalog configuration
  - `AppIcon.appiconset/Contents.json` - All Watch icon sizes:
    - 38mm, 40mm, 41mm, 42mm, 44mm, 45mm, 49mm watches
    - Notification Center icons
    - Companion Settings icons
    - 1024x1024 Marketing icon

### 3. Configuration Files
- **Info.plist** (50 lines)
  - WatchKit configuration (`WKApplication`, `WKWatchOnly`)
  - Location permissions (Always, WhenInUse, Always+WhenInUse)
  - HealthKit permissions (Share, Update)
  - Background modes (location, processing)
  - Required device capabilities (watch-companion, location-services, gps)
  - App category: Lifestyle

- **Config/pawWatch_Watch_App.entitlements** (28 lines)
  - Location services capability
  - HealthKit with health-records access
  - App Groups: `group.com.stonezone.pawWatch`
  - Associated domains (empty array for future use)

## Adding the Watch Target in Xcode

### Prerequisites
- Xcode 16.3 or later
- watchOS 26.0 SDK installed
- pawWatch.xcworkspace open

### Step-by-Step Instructions

#### 1. Open the Workspace
```bash
cd /Users/zackjordan/code/pawWatch-app
open pawWatch.xcworkspace
```

#### 2. Add Watch App Target

**In Xcode:**
1. Select **pawWatch** project (top of Project Navigator)
2. In the project editor, click **+** button under TARGETS list
3. Choose template:
   - Platform: **watchOS**
   - Template: **Watch App**
   - Click **Next**

4. Configure target:
   - Product Name: **pawWatch Watch App**
   - Team: Select your development team
   - Organization Identifier: **com.stonezone**
   - Bundle Identifier: **com.stonezone.pawWatch.watchkitapp**
   - Language: **Swift**
   - Include Notification Scene: **No** (we'll add if needed)
   - Click **Finish**

5. When prompted "Activate scheme?":
   - Click **Activate** to use the new Watch scheme

#### 3. Replace Generated Files

Xcode will create default files. Replace them with our prepared files:

1. **Delete Xcode's generated files:**
   - In Project Navigator, select the new `pawWatch Watch App` group
   - Delete: `pawWatch_Watch_AppApp.swift`, `ContentView.swift`, `Assets.xcassets`
   - Choose "Move to Trash"

2. **Add our prepared files:**
   - Right-click `pawWatch Watch App` target group
   - Select "Add Files to 'pawWatch Watch App'..."
   - Navigate to: `/Users/zackjordan/code/pawWatch-app/pawWatch Watch App/`
   - Select: `pawWatchApp.swift`, `ContentView.swift`, `Assets.xcassets`
   - Ensure "Copy items if needed" is **UNCHECKED** (files already in place)
   - Target membership: **pawWatch Watch App** only
   - Click **Add**

#### 4. Configure Info.plist

1. In Project Navigator, select `pawWatch Watch App` target
2. Go to **Build Settings** tab
3. Search for "Info.plist File"
4. Set value to: `pawWatch Watch App/Info.plist`

Or replace the generated Info.plist:
```bash
# Delete generated Info.plist if Xcode created one
rm -f "/Users/zackjordan/code/pawWatch-app/pawWatch Watch App/pawWatch_Watch_App-Info.plist"
```

#### 5. Configure Code Signing & Entitlements

1. Select `pawWatch Watch App` target
2. Go to **Signing & Capabilities** tab
3. Set:
   - **Team**: Your development team
   - **Signing Certificate**: Apple Development
   - **Code Signing Entitlements**: `Config/pawWatch_Watch_App.entitlements`

4. Add capabilities by clicking **+ Capability**:
   - **Location** → Enable "Always" and "When In Use"
   - **HealthKit** → Enable
   - **App Groups** → Add `group.com.stonezone.pawWatch`
   - **Background Modes** → Enable "Location updates" and "Background processing"

#### 6. Configure Build Settings

Select `pawWatch Watch App` target → **Build Settings**:

Search and set:
- **Product Name**: `pawWatch Watch App`
- **Product Bundle Identifier**: `com.stonezone.pawWatch.watchkitapp`
- **watchOS Deployment Target**: `26.0`
- **Swift Language Version**: `6.2`
- **Targeted Device Families**: `4` (Watch)
- **Skip Install**: `NO`
- **Install Path**: `$(LOCAL_APPS_DIR)`

#### 7. Link WatchLocationProvider and Shared Sources

1. In Project Navigator, locate `Sources/WatchLocationProvider/`
2. Select `WatchLocationProvider.swift`
3. In File Inspector (right panel), under **Target Membership**:
   - Check ☑️ **pawWatch Watch App**

4. Repeat for `Sources/Shared/Models/LocationFix.swift`:
   - Check ☑️ **pawWatch Watch App**

#### 8. Add Framework Dependencies

If using the pawWatchPackage:

1. Select `pawWatch Watch App` target
2. Go to **General** tab
3. Under **Frameworks, Libraries, and Embedded Content**:
   - Click **+**
   - Add **pawWatchFeature** (if applicable)

#### 9. Update ContentView.swift to Use WatchLocationProvider

Once the target builds, update the TODO markers in `ContentView.swift`:

```swift
// In startLocationTracking()
private func startLocationTracking() {
    currentLocation = "Acquiring location..."
    
    // Initialize WatchLocationProvider
    let provider = WatchLocationProvider()
    provider.delegate = self
    provider.start()
    
    print("Starting location tracking")
}
```

Implement `WatchLocationProviderDelegate`:
```swift
extension ContentView: WatchLocationProviderDelegate {
    func didProduce(_ fix: LocationFix) {
        currentLocation = "Lat: \(fix.coordinate.latitude), Lon: \(fix.coordinate.longitude)"
    }
    
    func didFail(_ error: Error) {
        currentLocation = "Error: \(error.localizedDescription)"
    }
}
```

### 10. Build and Test

#### Build for Simulator:
```bash
xcodebuild -workspace pawWatch.xcworkspace \
  -scheme "pawWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (45mm)' \
  clean build
```

#### Run on Simulator:
1. In Xcode, select **pawWatch Watch App** scheme
2. Choose a Watch simulator (Series 10, Ultra, etc.)
3. Click **Run** (⌘R)

#### Expected Result:
- Watch app launches showing "pawWatch" title
- Location status shows "Waiting for location..."
- "Start Tracking" button is green and functional
- Tapping button toggles to "Stop Tracking" (red)

## Verification Checklist

After completing the steps above:

- [ ] `pawWatch Watch App` target appears in target list
- [ ] Target is set for watchOS 26.0 minimum deployment
- [ ] Swift version is 6.2
- [ ] Info.plist is correctly linked
- [ ] Entitlements file is set
- [ ] Location, HealthKit, and App Groups capabilities are enabled
- [ ] `WatchLocationProvider.swift` is in target membership
- [ ] `LocationFix.swift` is in target membership
- [ ] App builds without errors
- [ ] App runs on Watch simulator
- [ ] UI displays correctly on Watch screen

## Troubleshooting

### Build Error: "No such module 'WatchLocationProvider'"
**Solution**: Check Target Membership for `WatchLocationProvider.swift`
1. Select the file in Project Navigator
2. File Inspector → Target Membership
3. Ensure `pawWatch Watch App` is checked

### Build Error: "Cannot find type 'LocationFix'"
**Solution**: Add `LocationFix.swift` to target membership
1. Select `Sources/Shared/Models/LocationFix.swift`
2. File Inspector → Target Membership
3. Check `pawWatch Watch App`

### Runtime Error: Location permission denied
**Solution**: Info.plist location keys are set correctly
- Verify `NSLocationAlwaysAndWhenInUseUsageDescription` exists
- Verify `NSLocationWhenInUseUsageDescription` exists
- In simulator: Settings → Privacy → Location → pawWatch → Allow While Using

### Code Signing Error
**Solution**: Configure development team
1. Select target → Signing & Capabilities
2. Choose your Team from dropdown
3. Xcode will auto-generate provisioning profile

## Next Steps

Once the Watch target is building successfully:

1. **Implement Location Tracking**:
   - Remove TODO markers in `ContentView.swift`
   - Add WatchLocationProvider initialization
   - Implement delegate methods
   - Test location tracking on simulator/device

2. **Add Watch Complications** (optional):
   - Add complication configurations to Info.plist
   - Create ComplicationController
   - Design complications for different Watch faces

3. **Implement WatchConnectivity**:
   - Add WCSession management
   - Send location fixes to iPhone
   - Handle background transfers

4. **Add HealthKit Integration**:
   - Request HealthKit permissions
   - Log pet tracking as workouts
   - Sync with iOS app

5. **Testing**:
   - Test on multiple Watch sizes
   - Test background location tracking
   - Test WatchConnectivity reliability
   - Test battery impact

## Files Reference

All files are located at:
- Base: `/Users/zackjordan/code/pawWatch-app/`
- Watch App: `pawWatch Watch App/`
- Shared Code: `Sources/WatchLocationProvider/`, `Sources/Shared/`
- Config: `Config/pawWatch_Watch_App.entitlements`

## Support

If you encounter issues:
1. Check Xcode console for specific error messages
2. Verify all file paths are correct
3. Clean build folder: Product → Clean Build Folder (⇧⌘K)
4. Reset simulator: Device → Erase All Content and Settings
5. Restart Xcode if project navigator isn't updating

---

**Created**: 2025-02-05  
**Xcode Version**: 16.3  
**watchOS Version**: 26.0  
**Swift Version**: 6.2
