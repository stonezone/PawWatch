# watchOS Target Setup Guide for pawWatch

## Status: Files Created, Manual Target Addition Required

### What's Already Done ✅

1. **Watch App Directory Structure Created**
   - `/Users/zackjordan/code/pawWatch-app/pawWatch Watch App/`
   
2. **Source Files Created**
   - `pawWatchApp.swift` - SwiftUI app entry point with lifecycle management
   - `ContentView.swift` - Main UI with location tracking toggle
   
3. **Assets Created**
   - `Assets.xcassets/` - Asset catalog with Watch app icon placeholders
   - `Assets.xcassets/AppIcon.appiconset/Contents.json` - Configured for all Watch sizes
   
4. **Configuration Files Created**
   - `Info.plist` - WatchKit configuration with permissions
   - `Config/pawWatch_Watch_App.entitlements` - Capabilities configuration

### Manual Steps to Add Watch Target in Xcode

Since programmatic project file modification is complex, follow these steps to add the Watch target through Xcode:

#### Step 1: Open Project in Xcode
```bash
open pawWatch.xcworkspace
```

#### Step 2: Add Watch App Target
1. In Xcode, select the `pawWatch` project in the Project Navigator
2. Click the `+` button at the bottom of the targets list
3. In the template chooser:
   - Select **watchOS** tab
   - Choose **Watch App** template
