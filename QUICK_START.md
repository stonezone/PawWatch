# watchOS Target - Quick Start (5 Minutes)

## All Files Ready ✅ - Just Add Target in Xcode

### Step 1: Open Project
```bash
cd /Users/zackjordan/code/pawWatch-app
open pawWatch.xcworkspace
```

### Step 2: Add Watch Target (2 minutes)
1. Select **pawWatch** project (top of navigator)
2. Click **+** under TARGETS
3. Choose: watchOS → **Watch App** → Next
4. Settings:
   - Name: `pawWatch Watch App`
   - Bundle ID: `com.stonezone.pawWatch.watchkitapp`
   - Language: Swift
   - Click **Finish**

### Step 3: Use Our Prepared Files (1 minute)
1. Delete Xcode's generated files (select & delete):
   - `pawWatch_Watch_AppApp.swift`
   - `ContentView.swift`
   - `Assets.xcassets`

2. Add our files:
   - Right-click target → "Add Files..."
   - Select all from `pawWatch Watch App/` folder
   - **Uncheck** "Copy items if needed"
   - Click **Add**

### Step 4: Configure Info.plist (30 seconds)
1. Select target → **Build Settings**
2. Search: "Info.plist File"
3. Set to: `pawWatch Watch App/Info.plist`

### Step 5: Link Shared Code (1 minute)
Select these files, check target membership:
- `Sources/WatchLocationProvider/WatchLocationProvider.swift`
- `Sources/Shared/Models/LocationFix.swift`

### Step 6: Build! (30 seconds)
```bash
xcodebuild -workspace pawWatch.xcworkspace \
  -scheme "pawWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (45mm)' \
  build
```

## Done! 🎉

Run on simulator: Select Watch scheme → Choose Watch simulator → Run (⌘R)

---

**Detailed Guide**: See `WATCH_TARGET_COMPLETE_GUIDE.md`  
**Summary Report**: See `WATCH_TARGET_SUMMARY.md`
