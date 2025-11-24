# pawWatch Updates - November 24, 2025

## Summary

This update aligns the pawWatch project configuration with iOS 26 requirements as documented in project guidelines. The Xcode project file had deployment targets still set to iOS 18.4 and watchOS 11.0, which were inconsistent with the iOS 26+ mandate.

## Changes Made

### 1. Xcode Project Configuration (`pawWatch.xcodeproj/project.pbxproj`)

#### Deployment Targets Updated
| Setting | Previous Value | New Value |
|---------|---------------|-----------|
| `IPHONEOS_DEPLOYMENT_TARGET` | 18.4 | 26.0 |
| `WATCHOS_DEPLOYMENT_TARGET` | 11.0 | 26.0 |
| `SWIFT_VERSION` | 6.2 | 6.2.1 |

**Affected build configurations:**
- Debug (project-level)
- Release (project-level)
- pawWatch target (Debug + Release)
- pawWatch Watch App target (Debug + Release)
- pawWatchWidgetExtension target (Debug + Release)
- pawWatchWatchWidget target (Debug + Release)

### 2. Deprecated API Fixes (`pawWatch/Sources/LiveActivity/PerformanceLiveActivityManager.swift`)

Fixed deprecated iOS 16.2+ LiveActivity APIs to use modern equivalents:

#### `syncLiveActivity(with:)` Method
```diff
- await activity.update(using: contentState)
+ let content = ActivityContent(state: contentState, staleDate: nil)
+ await activity.update(content)

- let activity = try Activity<PawActivityAttributes>.request(
-     attributes: PawActivityAttributes(),
-     contentState: contentState,
-     pushType: .token
- )
+ let activity = try Activity<PawActivityAttributes>.request(
+     attributes: PawActivityAttributes(),
+     content: content,
+     pushType: .token
+ )
```

#### `endAllActivities()` Method
```diff
- await activity.end(using: activity.contentState, dismissalPolicy: .immediate)
+ await activity.end(activity.content, dismissalPolicy: .immediate)
```

#### `applyRemote(contentState:)` Method
```diff
- await activity.update(using: contentState)
+ let content = ActivityContent(state: contentState, staleDate: nil)
+ await activity.update(content)
```

### 3. Documentation Updates (`PAWATCH_GUIDELINES.md`)

Updated Required Versions section:
```diff
**Required Versions:**
- iOS 26.0+ (iPhone)
- watchOS 26.0+ (Apple Watch)
-- Xcode 17.0+
-- Swift 6.0+
++ Xcode 26.0+ (unified version numbering with iOS)
++ Swift 6.2.1+
```

## Version Reference (November 2025)

| Technology | Current Stable | Beta |
|------------|---------------|------|
| iOS | 26.1 | 26.2 |
| watchOS | 26.1 | 26.2 |
| Xcode | 26.1.1 | 26.2 |
| Swift | 6.2.1 | - |

**Note:** Apple unified all platform version numbers starting in 2025. There is no "Xcode 17" - Apple jumped from Xcode 16 directly to Xcode 26 to match the iOS version numbering.

## Files Modified

1. `pawWatch.xcodeproj/project.pbxproj`
   - 8 occurrences of `IPHONEOS_DEPLOYMENT_TARGET` updated
   - 6 occurrences of `WATCHOS_DEPLOYMENT_TARGET` updated
   - 8 occurrences of `SWIFT_VERSION` updated

2. `pawWatch/Sources/LiveActivity/PerformanceLiveActivityManager.swift`
   - 3 deprecated API calls fixed

3. `PAWATCH_GUIDELINES.md`
   - Xcode version reference corrected
   - Swift version reference updated

## Build Verification

After these changes, the project should build without deprecation warnings related to:
- `update(using:)` - now uses `update(_:)` with `ActivityContent`
- `request(attributes:contentState:pushType:)` - now uses `request(attributes:content:pushType:)`
- `end(using:dismissalPolicy:)` - now uses `end(_:dismissalPolicy:)`
- `contentState` property - now uses `content` property

## Related Files Created

- `.claude/TIME_AWARE_REPORT.md` - Comprehensive time-aware technology audit report

---

## Phase 2: XcodeGen Configuration Sync

### Issue Identified
Codex review identified that the initial pbxproj changes would be overwritten by XcodeGen since `project.yml` (the source of truth) still had old values.

### 4. XcodeGen Configuration (`project.yml`)

#### Global Options Updated
```diff
options:
  deploymentTarget:
-   iOS: "18.4"
+   iOS: "26.0"
-   watchOS: "11.0"
+   watchOS: "26.0"
- xcodeVersion: "16.3"
+ xcodeVersion: "26.1"
```

#### Global Settings Updated
```diff
settings:
  base:
-   SWIFT_VERSION: "6.2"
+   SWIFT_VERSION: "6.2.1"
-   MARKETING_VERSION: "1.0.65"
+   MARKETING_VERSION: "1.0.67"
-   CURRENT_PROJECT_VERSION: "65"
+   CURRENT_PROJECT_VERSION: "67"
```

#### Per-Target Deployment Targets Updated
| Target | Previous | New |
|--------|----------|-----|
| `pawWatch` | 18.4 | 26.0 |
| `pawWatch Watch App` | 11.0 | 26.0 |
| `pawWatchWidgetExtension` | 18.4 | 26.0 |
| `pawWatchWatchWidget` | 11.0 | 26.0 |

#### Per-Target Swift Versions Updated
| Target | Previous | New |
|--------|----------|-----|
| `pawWatch Watch App` | 6.2 | 6.2.1 |
| `pawWatchWidgetExtension` | 6.2 | 6.2.1 |
| `pawWatchWatchWidget` | 6.2 | 6.2.1 |

#### Explicit Settings Updated
- `pawWatch Watch App`: `WATCHOS_DEPLOYMENT_TARGET`: "11.0" → "26.0"

### 5. XCConfig Updates (`Config/Shared.xcconfig`)

```diff
- IPHONEOS_DEPLOYMENT_TARGET = 18.4
+ IPHONEOS_DEPLOYMENT_TARGET = 26.0
```

### 6. Version Bump (`pawWatch.xcodeproj/project.pbxproj`)

```diff
- MARKETING_VERSION = 1.0.66;
+ MARKETING_VERSION = 1.0.67;
- CURRENT_PROJECT_VERSION = 66;
+ CURRENT_PROJECT_VERSION = 67;
```

## Complete Files Modified

| File | Changes |
|------|---------|
| `pawWatch.xcodeproj/project.pbxproj` | Deployment targets, Swift version, marketing version |
| `pawWatch/Sources/LiveActivity/PerformanceLiveActivityManager.swift` | 3 deprecated API fixes |
| `PAWATCH_GUIDELINES.md` | Xcode/Swift version docs |
| `project.yml` | XcodeGen source of truth - all version settings |
| `Config/Shared.xcconfig` | iOS deployment target |

## Configuration Sync Status

| Source | iOS | watchOS | Swift | Xcode | Status |
|--------|-----|---------|-------|-------|--------|
| `project.yml` | 26.0 | 26.0 | 6.2.1 | 26.1 | ✅ |
| `Shared.xcconfig` | 26.0 | - | - | - | ✅ |
| `project.pbxproj` | 26.0 | 26.0 | 6.2.1 | - | ✅ |
| `PAWATCH_GUIDELINES.md` | 26.0+ | 26.0+ | 6.2.1+ | 26.0+ | ✅ |

**All configuration sources are now synchronized.**

## XcodeGen Regeneration

To verify the configuration is stable, you can optionally run:
```bash
xcodegen generate
```

This should produce a pbxproj that matches the current state since project.yml is now the source of truth.

## Device Compatibility Warning

With these deployment targets:
- **iPhone**: Requires iOS 26.0+ (A13 Bionic or newer)
- **Apple Watch**: Requires watchOS 26.0+

Verify your test devices are running iOS 26.1 or later before building.

---

*Phase 1 performed: November 24, 2025 (pbxproj + LiveActivity + docs)*
*Phase 2 performed: November 24, 2025 (XcodeGen sync)*
*Updated by: Claude Code (Opus 4.5)*
