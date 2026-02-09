# pawWatch Comprehensive UI/UX & Code Quality TODO
**Created**: 2026-02-09
**Version**: 1.0.107
**Sources**: Claude UI/UX Analysis (iOS + watchOS), Codex Code Review, Liquid Glass UI Audit, Previous TODO carry-over

---

## Legend
- `[ ]` = Not started
- `[~]` = In progress
- `[x]` = Complete
- **Platform**: `iOS` | `watchOS` | `Both`
- **Area**: `Safety` | `UX` | `Code` | `A11y` | `Design` | `Perf` | `Test`

---

## Phase 1: Critical Safety & Usability (MUST FIX)

### P1-01: Watch — Flip information hierarchy for glanceability
- **Platform**: watchOS | **Area**: Safety/UX | **Severity**: CRITICAL
- **File**: `pawWatch Watch App/ContentView.swift`
- **Problem**: GPS status/accuracy buried below app title, version number, and decorative icon. Users can't confirm tracking in <2 seconds on wrist raise.
- **Fix**: Reorder view to show: (1) Tracking status, (2) GPS accuracy indicator, (3) Time since last fix, (4) Battery — THEN title/decorative elements below.
- [x] Restructure ContentView body to lead with GPS status section
- [x] Move version number to Settings only
- [x] Move decorative GPS icon below critical data

### P1-02: Watch — Add confirmation dialog to Emergency Stop
- **Platform**: watchOS | **Area**: Safety | **Severity**: CRITICAL
- **File**: `pawWatch Watch App/ContentView.swift`
- **Problem**: Emergency Stop button in lock overlay has no confirmation. Accidental tap = lost pet visibility.
- **Fix**: Add `.confirmationDialog` requiring deliberate second tap. Consider requiring hold-to-stop (3 seconds) instead.
- [x] Add confirmation dialog before stopping tracking
- [x] Add haptic warning feedback on first tap

### P1-03: Watch — Add haptic feedback for tracking state changes
- **Platform**: watchOS | **Area**: Safety | **Severity**: CRITICAL
- **File**: `pawWatch Watch App/ContentView.swift`
- **Problem**: Start/stop tracking provides no haptic feedback. Users may not know if action succeeded.
- **Fix**: Add `.success` haptic on start, `.warning` haptic on stop, `.failure` on error.
- [x] Add WKInterfaceDevice.current().play(.start) on tracking start
- [x] Add WKInterfaceDevice.current().play(.stop) on tracking stop
- [x] Add WKInterfaceDevice.current().play(.failure) on error

### P1-04: Watch — Add GPS accuracy degradation alert
- **Platform**: watchOS | **Area**: Safety | **Severity**: CRITICAL
- **File**: `pawWatch Watch App/ContentView.swift`
- **Problem**: No proactive alert when accuracy degrades >50m. User thinks pet is tracked accurately.
- **Fix**: Add visual badge + haptic when accuracy exceeds threshold. Show "GPS signal poor" banner with troubleshooting hint.
- [x] Add accuracy threshold monitoring (>50m = warning, >100m = critical)
- [x] Show visual warning banner with color change
- [x] Add haptic notification on threshold breach

### P1-05: Watch — GPS loss shows no actionable guidance
- **Platform**: watchOS | **Area**: Safety | **Severity**: CRITICAL
- **File**: `pawWatch Watch App/ContentView.swift`
- **Problem**: When GPS lost, skeleton loader shows with no context. Users can't tell if initializing vs permanently lost.
- **Fix**: Differentiate states: "Acquiring GPS..." (with spinner), "GPS signal lost" (with troubleshooting), "Move outdoors for better signal".
- [x] Create distinct GPS acquisition vs GPS lost states
- [x] Add estimated acquisition time or progress indicator
- [x] Add troubleshooting hints ("Move away from buildings")

### P1-06: iOS — Add empty state to HistoryView
- **Platform**: iOS | **Area**: UX | **Severity**: CRITICAL
- **File**: `pawWatchPackage/Sources/pawWatchFeature/HistoryView.swift`
- **Problem**: Blank screen when no location history. New users see nothing.
- **Fix**: Add icon + message + CTA explaining how to start tracking.
- [x] Create EmptyHistoryView with icon, message, and guidance
- [x] Add "Start Tracking" or "Pair Watch" CTA button

### P1-07: iOS — Safe zones need urgency indicators
- **Platform**: iOS | **Area**: Safety | **Severity**: CRITICAL
- **File**: `pawWatchPackage/Sources/pawWatchFeature/SafeZonesView.swift`
- **Problem**: No visual urgency when pet is OUTSIDE a safe zone. Users can't tell at a glance.
- **Fix**: Add banner/badge showing active violations. Color-code zones by current status.
- [x] Add "Pet outside zone!" alert banner at top when violation active
- [x] Color-code zone list items (green=inside, red=outside)
- [x] Show last violation timestamp per zone

### P1-08: iOS — Map loading states and crash protection
- **Platform**: iOS | **Area**: UX | **Severity**: CRITICAL
- **File**: `pawWatchPackage/Sources/pawWatchFeature/PetMapView.swift`
- **Problem**: Gray flash during map loading. No feedback that map is loading. No offline indicator.
- **Fix**: Replace gray placeholder with branded loading state. Add offline/error banner.
- [x] Replace Color.systemBackground placeholder with proper loading view
- [x] Add "Map offline" indicator when tiles fail to load
- [x] Add retry mechanism for map loading failures

---

## Phase 2: High Priority UX Improvements

### P2-01: iOS — Dashboard loading skeleton
- **Platform**: iOS | **Area**: UX | **Severity**: HIGH
- **File**: `pawWatchPackage/Sources/pawWatchFeature/DashboardView.swift`
- **Problem**: Flash of different states as connection resolves. No loading skeleton.
- [x] Add skeleton loading state during initial connection check
- [x] Add smooth crossfade transitions between states

### P2-02: iOS — Tab bar notification badges
- **Platform**: iOS | **Area**: UX | **Severity**: HIGH
- **File**: `pawWatchPackage/Sources/pawWatchFeature/MainTabView.swift`
- **Problem**: No badges for alerts, geofence violations, or new history data.
- [x] Add badge count to tab icons for unread alerts
- [x] Show violation indicator on relevant tab

### P2-03: iOS — Battery analytics source clarity
- **Platform**: iOS | **Area**: UX | **Severity**: HIGH
- **File**: `pawWatchPackage/Sources/pawWatchFeature/BatteryAnalyticsView.swift`
- **Problem**: "Total Battery Used" doesn't clarify watch vs phone source.
- [x] Add clear label "Watch Battery" or "Phone Battery"
- [x] Show date range in summary card (not just in picker)

### P2-04: iOS — Settings pet photo larger preview
- **Platform**: iOS | **Area**: UX | **Severity**: HIGH
- **File**: `pawWatchPackage/Sources/pawWatchFeature/SettingsView.swift`
- **Problem**: 48pt avatar too small for emotional connection.
- [x] Increase avatar size to 80pt
- [x] Add tap-to-view-fullsize gesture
- [x] Add success feedback on photo upload

### P2-05: iOS — Safe zone editor validation
- **Platform**: iOS | **Area**: UX | **Severity**: HIGH
- **File**: `pawWatchPackage/Sources/pawWatchFeature/SafeZonesView.swift`
- **Problem**: No warnings for zone size, overlap, or impossible locations.
- [x] Add zone size guidance ("Recommended: 50-200m")
- [x] Warn when zone overlaps another zone
- [x] Show estimated battery impact per zone

### P2-06: iOS — Distance alert slider context
- **Platform**: iOS | **Area**: UX | **Severity**: HIGH
- **File**: `pawWatchPackage/Sources/pawWatchFeature/SettingsView.swift`
- **Problem**: No range labels, no context for what different values mean.
- [x] Add min/max labels
- [x] Add context descriptions ("50m = neighborhood walk", "200m = park visit")

### P2-07: Watch — History view accessibility
- **Platform**: watchOS | **Area**: UX | **Severity**: HIGH
- **File**: `pawWatch Watch App/ContentView.swift`
- **Problem**: History link buried at bottom, requires multiple crown scrolls.
- [x] Move History to a more accessible position (near top or as a tab)
- [x] Add crown-based quick access

### P2-08: Watch — Reduce crown unlock threshold
- **Platform**: watchOS | **Area**: UX | **Severity**: HIGH
- **File**: `pawWatch Watch App/ContentView.swift`
- **Problem**: 1.75 rotation unlock is higher than Apple's Water Lock (~1.25). Frustrating during active use.
- [x] Reduce unlock threshold to 1.25 rotations (Apple standard)
- [x] Add haptic progression feedback during unlock rotation

### P2-09: Watch — Fix lock overlay battery drain
- **Platform**: watchOS | **Area**: Perf | **Severity**: HIGH
- **File**: `pawWatch Watch App/ContentView.swift`
- **Problem**: TimelineView redraws every 1 second even when screen off.
- [x] Change to `.periodic(from: .now, by: 60)` (minute granularity)
- [x] Only update when screen is active

### P2-10: Watch — History empty state needs CTA
- **Platform**: watchOS | **Area**: UX | **Severity**: HIGH
- **File**: `pawWatch Watch App/RadialHistoryGlanceView.swift`
- **Problem**: Empty state says "Start tracking" but has no button to do it.
- [x] Add "Start Tracking" button in empty state
- [x] Navigate back to main view on tap

---

## Phase 3: Medium Priority Polish

### P3-01: Both — Standardize animation timing
- **Platform**: Both | **Area**: Design | **Severity**: MEDIUM
- **Files**: Multiple (MainTabView, DashboardView, PetMapView, etc.)
- **Problem**: 4+ different spring animation configs instead of using `theme.springStandard`.
- [x] Create single animation constant in DesignTokens
- [x] Replace all hardcoded springs with standard animation

### P3-02: Both — Standardize typography system
- **Platform**: Both | **Area**: Design | **Severity**: MEDIUM
- **Files**: Multiple
- **Problem**: Mix of Typography.pageTitle, .system(size:), and .navigationTitle.
- [x] Audit all font usage across views
- [x] Replace with consistent Typography tokens

### P3-03: iOS — Add pull-to-refresh on HistoryView
- **Platform**: iOS | **Area**: UX | **Severity**: MEDIUM
- **File**: `pawWatchPackage/Sources/pawWatchFeature/HistoryView.swift`
- [x] Add .refreshable modifier to request fresh location data

### P3-04: iOS — Battery/accuracy color labels for colorblind
- **Platform**: iOS | **Area**: A11y | **Severity**: MEDIUM
- **File**: `pawWatchPackage/Sources/pawWatchFeature/DashboardView.swift`
- **Problem**: Red/yellow/green with no text labels. Colorblind users can't distinguish.
- [x] Add text labels ("Excellent", "Good", "Poor") alongside colors
- [x] Use shape differentiation (checkmark, dash, X icons)

### P3-05: iOS — SafeZones events "Clear All" action
- **Platform**: iOS | **Area**: UX | **Severity**: MEDIUM
- **File**: `pawWatchPackage/Sources/pawWatchFeature/SafeZonesView.swift`
- [x] Add "Clear All" button for event history
- [x] Add "Mark as Reviewed" functionality

### P3-06: iOS — Surface advanced settings
- **Platform**: iOS | **Area**: UX | **Severity**: MEDIUM
- **File**: `pawWatchPackage/Sources/pawWatchFeature/SettingsView.swift`
- **Problem**: Critical features hidden in collapsed DisclosureGroup.
- [x] Promote HealthKit and session export to primary settings
- [x] Keep only true developer tools in collapsed section

### P3-07: iOS — BatteryAnalytics actionable recommendations
- **Platform**: iOS | **Area**: UX | **Severity**: MEDIUM
- **File**: `pawWatchPackage/Sources/pawWatchFeature/BatteryAnalyticsView.swift`
- **Problem**: Text-heavy tips without action buttons.
- [x] Add action buttons next to each recommendation
- [x] Deep link to relevant settings

### P3-08: Watch — Reduce Liquid Glass visual noise
- **Platform**: watchOS | **Area**: Design | **Severity**: MEDIUM
- **File**: `pawWatch Watch App/WatchGlassComponents.swift`
- **Problem**: Glass effects on every element flatten visual hierarchy on small screen.
- [x] Reduce glass effects to primary containers only
- [x] Increase contrast for text on glass backgrounds

### P3-09: Watch — Add Reduce Motion support
- **Platform**: watchOS | **Area**: A11y | **Severity**: MEDIUM
- **Files**: `pawWatch Watch App/ContentView.swift`, `pawWatch Watch App/WatchGlassComponents.swift`
- **Problem**: .breathe.pulse, .bounce, .pulse animations with no Reduce Motion checks.
- [x] Check @Environment(\.accessibilityReduceMotion)
- [x] Provide static alternatives for all symbol effects

### P3-10: Watch — Improve text contrast in GlassPill
- **Platform**: watchOS | **Area**: A11y | **Severity**: MEDIUM
- **File**: `pawWatch Watch App/GlassPill.swift`
- **Problem**: .secondary text on glass may fall below WCAG AA 4.5:1.
- [x] Add opaque background option for accessibility mode
- [x] Increase font weight for critical metrics

### P3-11: Watch — Settings carousel discoverability
- **Platform**: watchOS | **Area**: UX | **Severity**: MEDIUM
- **File**: `pawWatch Watch App/WatchSettingsView.swift`
- **Problem**: Second section hidden without visual scroll indicator.
- [x] Add scroll indicator or section count badge

### P3-12: iOS — Map controls small screen overlap
- **Platform**: iOS | **Area**: UX | **Severity**: MEDIUM
- **File**: `pawWatchPackage/Sources/pawWatchFeature/PetMapView.swift`
- **Problem**: Fixed padding may cause overlay overlap on iPhone SE.
- [x] Add safe area awareness for map controls
- [x] Test on smallest supported screen size

### P3-13: Watch — RadialFixRow VoiceOver labels
- **Platform**: watchOS | **Area**: A11y | **Severity**: MEDIUM
- **File**: `pawWatch Watch App/RadialHistoryGlanceView.swift`
- **Problem**: No compound accessibility labels. VoiceOver reads individual values out of context.
- [x] Add compound label: "GPS fix from X minutes ago, accuracy +/-Ym, battery Z%"
- [x] Add accessibility traits for navigable elements

---

## Phase 4: Code Quality (Codex Findings — Still Open)

### P4-01: Log JSON decode failures (not silent nil)
- **Platform**: iOS | **Area**: Code | **Severity**: HIGH
- **File**: `pawWatchPackage/Sources/pawWatchFeature/PetLocationManager.swift` — `decodeLocationFix(from:)`
- **Problem**: Decode failures return nil silently. No logging, no signpost, no error surfacing.
- [x] Add logger.error with error details on decode failure
- [x] Add signposter.emitEvent("FixDecodeError")
- [x] Track consecutive decode failures and surface to UI if repeated

### P4-02: Deduplicate fixes by sequence on iOS
- **Platform**: iOS | **Area**: Code | **Severity**: HIGH
- **File**: `pawWatchPackage/Sources/pawWatchFeature/PetLocationManager.swift` — `handleLocationFix(_:)`
- **Problem**: iOS never checks LocationFix.sequence for duplicates across transport paths.
- [x] Add LRU cache of recent sequence values (last 200)
- [x] Drop fixes with duplicate sequences before inserting to history
- [x] Log dropped duplicates for diagnostics

### P4-03: Order location history by timestamp
- **Platform**: iOS | **Area**: Code | **Severity**: MEDIUM
- **File**: `pawWatchPackage/Sources/pawWatchFeature/PetLocationManager.swift`
- **Problem**: History uses arrival order, not capture timestamp. Late file transfers appear as newest.
- [x] Insert by timestamp (binary search for correct position)
- [x] Document ordering contract in code comments

### P4-04: Battery drain negative value handling
- **Platform**: Both | **Area**: Code | **Severity**: MEDIUM
- **File**: `pawWatchPackage/Sources/pawWatchFeature/PetLocationManager.swift` — `persistPerformanceSnapshot`
- **Problem**: Battery charging produces negative "drain" values. Small elapsed times produce volatile readings.
- [x] Clamp drain to max(0, computed) — treat rising battery as "no data"
- [x] Add minimum elapsed time threshold (>60s) before computing drain
- [x] Apply exponential moving average smoothing

### P4-05: Connectivity error surface to UI
- **Platform**: Both | **Area**: Code | **Severity**: MEDIUM
- **Files**: WatchConnectivity send paths
- **Problem**: Send failures log but don't propagate meaningful status to delegate/UI.
- [x] Define error categories: "communicationDegraded", "phoneUnreachable"
- [x] Surface connectivity status in DashboardView status pill
- [x] Track error counts in PerformanceMonitor

---

## Phase 5: Design System Consistency

### P5-01: Replace hardcoded magic numbers with design tokens
- **Platform**: Both | **Area**: Design | **Severity**: MEDIUM
- **Files**: Multiple
- **Problem**: Map size thresholds, battery levels, padding values scattered as literals.
- [x] Create MapConstants enum in DesignTokens with named thresholds
- [x] Replace all magic numbers in PetMapView and other view files

### P5-02: Standardize icon sizes
- **Platform**: Both | **Area**: Design | **Severity**: LOW
- **Files**: Multiple
- **Problem**: Mix of .caption2, .title2, .system(size:22) for icons.
- [x] Use IconSize tokens from DesignTokens consistently

### P5-03: Use spacing variables consistently
- **Platform**: Both | **Area**: Design | **Severity**: LOW
- **Files**: Multiple
- **Problem**: Mix of Spacing.lg and hardcoded 20, 24, 16 values.
- [x] Replace all hardcoded spacing with Spacing tokens

### P5-04: Consistent Liquid Glass application
- **Platform**: iOS | **Area**: Design | **Severity**: MEDIUM
- **Files**: HistoryView, SettingsView
- **Problem**: Some views use iOS 26 .glassEffect() while others use basic cards/forms.
- [x] Apply .glassEffect consistently to all card containers (via GlassCard)
- [x] Ensure fallback to .ultraThinMaterial on older OS

---

## Phase 6: Context Menus & Missing UX Patterns

### P6-01: iOS — Add context menus to History items
- **Platform**: iOS | **Area**: UX | **Severity**: LOW
- **File**: `pawWatchPackage/Sources/pawWatchFeature/HistoryView.swift`
- [x] Long-press -> "Share location", "View on map", "Copy coordinates"

### P6-02: iOS — Add context menus to Safe Zones
- **Platform**: iOS | **Area**: UX | **Severity**: LOW
- **File**: `pawWatchPackage/Sources/pawWatchFeature/SafeZonesView.swift`
- [x] Long-press -> "Edit", "Duplicate", "Center on map"

### P6-03: iOS — Add reverse geocoding for coordinates
- **Platform**: iOS | **Area**: UX | **Severity**: LOW
- **File**: `pawWatchPackage/Sources/pawWatchFeature/DashboardView.swift`
- **Problem**: Raw lat/lon shown with 6 decimals. Most users don't understand coordinates.
- [x] Add CLGeocoder reverse lookup for human-readable address
- [x] Show address below coordinates with "Share Location" button

### P6-04: iOS — Map trail color by time/accuracy
- **Platform**: iOS | **Area**: UX | **Severity**: LOW
- **File**: `pawWatchPackage/Sources/pawWatchFeature/PetMapView.swift`
- **Problem**: Trail always solid blue.
- [x] Color by recency (bright = recent, faded = old)
- [x] Dash line when accuracy is poor

### P6-05: iOS — Search/filter in HistoryView
- **Platform**: iOS | **Area**: UX | **Severity**: LOW
- **File**: `pawWatchPackage/Sources/pawWatchFeature/HistoryView.swift`
- [x] Add date picker filter
- [x] Add accuracy threshold filter

### P6-06: iOS — Haptic feedback on destructive actions
- **Platform**: iOS | **Area**: UX | **Severity**: LOW
- **File**: `pawWatchPackage/Sources/pawWatchFeature/SafeZonesView.swift`
- [x] Add .warning haptic on swipe-to-delete
- [x] Add .success haptic on save

---

## Phase 7: Testing & Validation (Carry-over)

### P7-01: Add Swift Testing coverage for core models
- **Platform**: Both | **Area**: Test | **Severity**: HIGH
- **File**: `pawWatchPackage/Tests/pawWatchFeatureTests/`
- [x] LocationFix round-trip encode/decode test (10 tests, all passing)
- [x] PetLocationManager.shouldAccept tests (duplicate drop, low accuracy, implausible jump) (15 tests)
- [x] Battery drain smoothing tests with synthetic data (14 tests)

### P7-02: Run full simulator sanity pass
- **Platform**: Both | **Area**: Test | **Severity**: HIGH
- [x] Build and run iOS target on simulator (iPhone 17 Pro — BUILD SUCCEEDED)
- [ ] Build and run watchOS target on simulator
- [ ] Verify no missing assets, Info.plist warnings, or entitlement issues

### P7-03: On-device validation
- **Platform**: Both | **Area**: Test | **Severity**: MEDIUM
- [ ] Clean install on paired iPhone + Watch
- [ ] Verify WCSession diagnostics
- [ ] Confirm fixes flow while phone backgrounded

### P7-04: HealthKit/HKWorkout review
- **Platform**: watchOS | **Area**: Test | **Severity**: MEDIUM
- [ ] Verify prompts on device with NSHealthUpdateUsageDescription
- [ ] Review App Store copy alignment with workout usage

---

## Phase 8: Remaining Liquid Glass Improvements (Real APIs Only)

### P8-01: Apply .glassEffect() to iOS tab bar
- **Platform**: iOS | **Area**: Design | **Severity**: MEDIUM
- **File**: `pawWatchPackage/Sources/pawWatchFeature/MainTabView.swift`
- [x] Replace .ultraThinMaterial with .glassEffect(.regular) on iOS 26+
- [x] Add tabBarMinimizeBehavior for scroll-responsive tab bar

### P8-02: Apply .buttonStyle(.glass) to primary actions
- **Platform**: Both | **Area**: Design | **Severity**: LOW
- **Files**: Various buttons across views
- [x] Apply .buttonStyle(.glass) on iOS 26+ with availability check

### P8-03: Add scrollEdgeEffectStyle to scrollable views
- **Platform**: Both | **Area**: Design | **Severity**: LOW
- **Files**: HistoryView, DashboardView, watch ContentView
- [x] Apply .scrollEdgeEffectStyle(.soft) for smooth edge transitions

### P8-04: Watch — Remove SmartStackHintView "Phase 6" dev text
- **Platform**: watchOS | **Area**: Design | **Severity**: LOW
- **File**: `pawWatch Watch App/SmartStackHintView.swift:27`
- **Problem**: User-visible text references "Phase 6 WidgetKit implementation"
- [x] Replace with user-friendly message or remove placeholder entirely

### P8-05: Watch — Clean up unused WatchGlassTheme gradients
- **Platform**: watchOS | **Area**: Perf | **Severity**: LOW
- **File**: `pawWatch Watch App/WatchGlassComponents.swift:18-26`
- **Problem**: backgroundGradient array defined but never used.
- [x] Remove dead code or wire it up

---

## Phase 9: SettingsView Refactor (Anti-pattern Fix)

### P9-01: Split SettingsView into focused files
- **Platform**: iOS | **Area**: Code | **Severity**: MEDIUM
- **File**: `pawWatchPackage/Sources/pawWatchFeature/SettingsView.swift` (900 lines)
- **Problem**: Massive view file with inline subviews.
- [x] Extract PetProfileCard to separate file (174 lines)
- [x] Extract DeveloperSettingsSheet to separate file (89 lines)
- [x] Extract TrackingModeSection to separate file (102 lines)
- [x] Extract ConnectionStatusCard, StatCell, DistanceAlertsSection, AdvancedSettingsSection
- [x] SettingsView reduced from 1027 to 296 lines

### P9-02: Fix DateFormatter allocation in HistoryView
- **Platform**: iOS | **Area**: Perf | **Severity**: LOW
- **File**: `pawWatchPackage/Sources/pawWatchFeature/HistoryView.swift`
- **Problem**: Creates new DateFormatter on every computed property access.
- [x] Make DateFormatter static constant
- [x] Add locale awareness

---

## Summary

| Phase | Total | Done | Remaining | Priority |
|-------|-------|------|-----------|----------|
| **P1: Critical Safety** | 8 | 8 | 0 | CRITICAL |
| **P2: High Priority UX** | 10 | 10 | 0 | HIGH |
| **P3: Medium Polish** | 13 | 13 | 0 | MEDIUM |
| **P4: Code Quality** | 5 | 5 | 0 | HIGH-MED |
| **P5: Design System** | 4 | 4 | 0 | MEDIUM-LOW |
| **P6: Context Menus & UX** | 6 | 6 | 0 | LOW |
| **P7: Testing** | 4 | 1 | 3 | HIGH-MED |
| **P8: Liquid Glass** | 5 | 5 | 0 | MEDIUM-LOW |
| **P9: Refactor** | 2 | 2 | 0 | MEDIUM-LOW |
| **TOTAL** | **57** | **55** | **2** | |

**Remaining**: P7-02 sub-items (watchOS simulator build, asset/plist verification), P7-03 (on-device), P7-04 (HealthKit review) — require manual/device testing
