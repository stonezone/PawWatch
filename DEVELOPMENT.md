# pawWatch Development Roadmap

**Version:** 1.0 (Planning Phase)
**Target:** v1.0 Launch in 7 weeks
**Approach:** Fork gps-relay-framework, strip external relay, build pet tracker UI

---

## Versioning (1.0.x stream)

- Run `./scripts/bump_version.py` before committing a new change. It increments `Config/version.json` and keeps the Xcode project in sync so both apps share the same semantic version and build number.
- Install the enforcement hook once with `./scripts/install-git-hooks.sh`; the hook blocks commits that forget to stage the version file.
- See `docs/VERSIONING.md` for the full workflow and advanced options (minor/major bumps, bypass flags, etc.).

---

## Form Factors & Orientation

- iPhone-only build for now (`TARGETED_DEVICE_FAMILY = 1`). iPad layouts are out-of-scope until we nail the watch → phone pipeline.
- The iOS app is locked to `UIInterfaceOrientationPortrait`. It keeps the dashboard/map layout predictable during this test phase; we can revisit landscape once we design a wider layout.
- watchOS target is unchanged; it keeps the existing workout-driven background execution model.

---

## 🎯 Development Strategy

### Why Fork gps-relay-framework?

**Project 1 (gps-relay-framework) - 65% Reusable:**
- ✅ 0.5s GPS throttle (real-time tracking)
- ✅ WatchConnectivity triple-path messaging
- ✅ HealthKit workout sessions
- ✅ 81+ unit tests
- ✅ Proven battery optimization
- ✅ Mature codebase (v1.0.4)

**What to Strip:**
- ❌ WebSocket transport (no external relay)
- ❌ BLE peripheral transport (no external devices)
- ❌ Dual-stream RelayUpdate (only need Watch GPS)
- ❌ Jetson server code
- ❌ Base station GPS (iPhone GPS not needed for pet tracking)

**What to Keep:**
- ✅ WatchLocationProvider (Watch GPS capture)
- ✅ LocationFix data model
- ✅ WatchConnectivity patterns
- ✅ Battery monitoring
- ✅ Test infrastructure

---

## 📅 7-Week Timeline

### Week 1: Foundation Setup
**Goal:** Create pawWatch project structure

**Tasks:**
1. Fork gps-relay-framework to pawWatch-app
2. Remove external relay components:
   - Delete `Sources/WebSocketTransport/`
   - Delete `Sources/BlePeripheralTransport/`
   - Delete `Sources/LocationRelayService/` (replace with simpler coordinator)
   - Delete `jetson/` directory
3. Rename modules:
   - Keep `WatchLocationProvider` (minimal changes)
   - Keep `LocationCore` (may rename to `PawWatchCore`)
4. Create new Xcode workspace: `pawWatch.xcworkspace`
5. Create iOS app target: `pawWatch`
6. Create Watch app target: `pawWatch Watch App`
7. Configure Info.plist files:
   - iOS 26.0 minimum deployment
   - watchOS 26.0 minimum deployment
   - Location permissions ("Track your pet's location")
   - HealthKit permissions ("Monitor pet activity")

**Deliverables:**
- ✅ Clean project structure
- ✅ Builds successfully on iOS 26 / watchOS 26
- ✅ WatchLocationProvider integrated

**Time:** 3-4 days

---

### Week 2: Core GPS Streaming
**Goal:** Watch → iPhone GPS data flow working

**Tasks:**
1. **Watch App:**
   - Integrate WatchLocationProvider (already functional from gps-relay-framework)
   - Simple UI: Start/Stop tracking button
   - Display current GPS fix, battery level
   - Test 0.5s throttle performance

2. **iPhone App:**
   - Create `PetLocationManager` (simplified relay service)
   - Receive GPS fixes via WatchConnectivity
   - Store fixes in memory (last 100 for trail)
   - Display connection status

3. **Testing:**
   - Bluetooth mode: Verify ~1-2Hz updates
   - LTE mode: Verify updates work (even if slower)
   - Sequence gap detection
   - Battery monitoring

**Deliverables:**
- ✅ Real-time GPS streaming (0.5s throttle)
- ✅ Bluetooth + LTE modes working
- ✅ Basic iPhone display of Watch location

**Time:** 5-6 days

---

### Week 3: iOS 26 Liquid Glass UI (Part 1)
**Goal:** Implement core navigation and DashboardView

**Design System:**
- **Frosted Glass Backgrounds:** `.background(.ultraThinMaterial)`
- **Fluid Animations:** `.animation(.spring(response: 0.3))`
- **Depth Layers:** Shadow and blur for layering
- **System Colors:** `.blue`, `.green`, `.orange` with dynamic support
- **Dark Mode:** Automatic with `@Environment(\.colorScheme)`

**Tasks:**
1. **Navigation Structure:**
   - TabView with 5 tabs: Dashboard, Map, Activity, Health, Settings
   - SF Symbols icons: house, map, figure.run, heart, gearshape
   - iOS 26 frosted glass tab bar

2. **DashboardView:**
   - Pet status card (name, photo, wellness score)
   - Quick stats: Last seen, battery level, activity today
   - Quick actions: Geofence alerts, emergency button
   - Real-time connection status
   - Liquid Glass card design with depth

3. **Pet Profile Setup:**
   - Add pet: Name, breed, age, weight, photo
   - Store in CoreData
   - Single pet for v1.0 (multi-pet in v1.5)

**Deliverables:**
- ✅ iOS 26 Liquid Glass navigation
- ✅ DashboardView with pet status
- ✅ Pet profile CRUD

**Time:** 5-6 days

---

### Week 4: iOS 26 Liquid Glass UI (Part 2)
**Goal:** Implement MapView and ActivityView

**Tasks:**
1. **MapView:**
   - MapKit integration with pet location marker
   - Movement trail (last 100 GPS fixes)
   - Real-time updates with smooth animations
   - Zoom controls, center on pet button
   - Accuracy visualization (circle around marker)
   - Distance from owner display

2. **ActivityView:**
   - Daily steps (calculated from GPS movement)
   - Distance traveled (km/mi toggle)
   - Calories burned (breed/weight adjusted)
   - Active time vs rest time
   - Goal progress rings (iOS 26 style)
   - Weekly/monthly trends chart

3. **Liquid Glass Polish:**
   - Frosted glass overlays for map controls
   - Smooth transitions between views
   - Spring animations on card taps
   - Haptic feedback for interactions

**Deliverables:**
- ✅ Real-time map with pet location
- ✅ Activity tracking dashboard
- ✅ iOS 26 design consistency

**Time:** 5-6 days

---

### Week 5: Geofencing & Wellness
**Goal:** Core safety features

**Tasks:**
1. **Geofencing System:**
   - Create circular geofences on map (drag to create)
   - Multiple geofences support
   - Entry/exit detection logic
   - Push notifications when pet leaves/enters
   - Distance to nearest geofence display
   - Geofence management UI (list, edit, delete)

2. **Wellness Score Algorithm:**
   - 0-100 score calculation:
     - Activity level (40%): Steps vs breed average
     - Rest quality (30%): Sleep patterns, stillness time
     - Behavior patterns (20%): Routine consistency
     - Health alerts (10%): Fall detection, anomalies
   - Daily/weekly/monthly trend charts
   - Breed-specific benchmarks (research common breeds)

3. **HealthView:**
   - Wellness score display (large circular gauge)
   - Score breakdown by category
   - Trend chart (7 days, 30 days)
   - Health alerts list
   - Recommendations for improvement

**Deliverables:**
- ✅ Geofencing with notifications
- ✅ Wellness score algorithm
- ✅ HealthView with insights

**Time:** 5-6 days

---

### Week 6: Fall Detection & Notifications
**Goal:** Safety alerts and monitoring

**Tasks:**
1. **Fall Detection:**
   - CoreMotion accelerometer on Watch
   - Detect sudden impacts (high G-force)
   - Detect abnormal movement patterns
   - 30-second countdown to cancel false alert
   - Emergency notification to owner
   - Manual emergency button on Watch

2. **Notification System:**
   - Geofence violations (critical)
   - Fall detection (critical)
   - Low battery warnings (Watch <20%)
   - Activity goal achieved (info)
   - Daily wellness report (info)
   - Notification settings (enable/disable types)

3. **SettingsView:**
   - Pet profile management
   - Notification preferences
   - Activity goal customization
   - Distance units (km/mi)
   - Battery optimization tips
   - About/help/privacy policy

**Deliverables:**
- ✅ Fall detection with emergency alerts
- ✅ Comprehensive notification system
- ✅ SettingsView complete

**Time:** 5-6 days

---

### Week 7: Testing, Polish & Launch Prep
**Goal:** Production-ready v1.0

**Tasks:**
1. **Testing:**
   - Real-world testing with actual pets (at least 3 test pets)
   - Battery life validation (8+ hours Watch, 12+ hours iPhone)
   - GPS accuracy testing (urban, suburban, rural)
   - Geofence reliability testing
   - LTE mode testing (Watch away from iPhone)
   - Fall detection false positive rate

2. **Performance Optimization:**
   - Map rendering optimization
   - GPS trail memory management (limit to 100 fixes)
   - Battery profiling with Instruments
   - Network efficiency (WatchConnectivity)
   - App launch time (<2 seconds)

3. **UI Polish:**
   - Animations smoothness
   - Dark mode consistency
   - Accessibility labels (VoiceOver)
   - Error state handling (GPS unavailable, Watch disconnected)
   - Empty states (no pet added, no GPS fixes yet)
   - Loading states with skeleton screens

4. **Documentation:**
   - User guide (setup, features, troubleshooting)
   - Privacy policy (location data handling)
   - App Store screenshots (iPhone + Watch)
   - App Store description
   - Release notes

5. **Launch Preparation:**
   - App Store Connect setup
   - TestFlight beta (friends/family)
   - App review guidelines compliance
   - Pricing strategy (free with optional premium?)
   - Marketing materials

**Deliverables:**
- ✅ Fully tested with real pets
- ✅ Performance optimized
- ✅ App Store submission ready

**Time:** 6-7 days

---

## 🧪 Testing Strategy

### Unit Tests
- **Target:** 80%+ coverage
- Reuse 81 tests from gps-relay-framework
- Add tests for:
  - Geofencing logic
  - Wellness score calculation
  - Activity tracking algorithms
  - Fall detection algorithm

### Integration Tests
- Watch → iPhone GPS streaming
- CoreData persistence
- Notification delivery
- MapKit integration

### Manual Testing
- Real pets wearing Watch (dogs, cats)
- Different breeds/sizes
- Urban vs rural environments
- Bluetooth vs LTE modes
- Battery drain over 8+ hours

### Beta Testing
- TestFlight with 10-20 pet owners
- Feedback survey
- Crash reporting (Crashlytics or similar)
- Analytics (usage patterns, popular features)

---

## 📊 Success Metrics (v1.0 Launch)

| Metric | Target | Measurement |
|--------|--------|-------------|
| **GPS Update Rate** | ~2Hz (0.5s) | LocationFix frequency |
| **GPS Latency (LTE)** | <1 second | Timestamp delta |
| **Battery Life (Watch)** | 8+ hours | Continuous tracking runtime |
| **Battery Life (iPhone)** | 12+ hours | Background GPS reception |
| **Geofence Accuracy** | ±10 meters | Violation detection precision |
| **App Size** | <50MB | Downloaded bundle size |
| **Memory Usage** | <200MB | Peak iPhone RAM |
| **Crash Rate** | <0.1% | Analytics |
| **Test Coverage** | >80% | Unit + integration tests |
| **App Store Rating** | >4.5 stars | Reviews (post-launch) |

---

## 🔄 Future Roadmap (Post-v1.0)

### v1.5 (3-4 weeks after v1.0)
- 🐕 Multiple pet support
- 👨‍👩‍👧‍👦 Family sharing (multiple iPhone users)
- 📊 Enhanced analytics (behavior trends, health insights)
- 🎯 Custom activity goals per pet

### v2.0 (2-3 months after v1.0)
- ☁️ Cloud sync (iCloud)
- 📸 Photo timeline (pet memories)
- 🏥 Vet integration (appointment reminders, health records)
- 📍 Points of interest (favorite parks, vet locations)
- 🔔 Smart notifications (AI-powered behavior alerts)

### v3.0 (6+ months after v1.0)
- 🤖 Machine learning for behavior prediction
- 🌍 Community features (nearby pet owners, play dates)
- 🏆 Gamification (achievements, challenges)
- 📱 iPad app with larger map view
- 🌐 Web dashboard (view from desktop)

---

## 🛠️ Development Tools

### Required
- Xcode 17.0+ (iOS 26 / watchOS 26 support)
- Swift 6.0+
- Physical iPhone 11+ (for testing)
- Physical Apple Watch Series 4+ (for testing)
- Apple Developer Account ($99/year)

### Recommended
- SF Symbols app (icon library)
- Figma/Sketch (UI design refinement)
- Instruments (performance profiling)
- TestFlight (beta distribution)
- Git/GitHub (version control)

### Optional
- SwiftLint (code style enforcement)
- Crashlytics (crash reporting)
- Firebase Analytics (usage tracking)
- Fastlane (CI/CD automation)

---

## 📝 Code Reuse Checklist

From **gps-relay-framework v1.0.4:**

- ✅ **WatchLocationProvider** (95% reusable)
  - 0.5s GPS throttle ✅
  - HealthKit workout session ✅
  - WatchConnectivity triple-path messaging ✅
  - Battery monitoring ✅
  - Sequence number tracking ✅

- ✅ **LocationFix.swift** (100% reusable)
  - GPS data model ✅
  - JSON serialization ✅
  - Source differentiation ✅
  - Battery/accuracy fields ✅

- ✅ **WatchConnectivity Patterns** (90% reusable)
  - Retry logic with exponential backoff ✅
  - Queue management ✅
  - Duplicate detection ✅
  - Connection state monitoring ✅

- ✅ **Test Infrastructure** (80% reusable)
  - 81 unit tests ✅
  - WatchConnectivity mocking ✅
  - GPS simulation utilities ✅

- ❌ **Strip These Components:**
  - WebSocketTransport ❌
  - BlePeripheralTransport ❌
  - LocationRelayService (replace with PetLocationManager) ❌
  - Dual-stream RelayUpdate ❌
  - Jetson server code ❌

---

## 🚨 Critical Reminders

### Non-Negotiable Requirements
1. **0.5s GPS throttle** - Real-time tracking is the #1 priority
2. **iOS 26+ / watchOS 26+** - Liquid Glass design mandate
3. **Watch + iPhone only** - No external devices
4. **Single-stream architecture** - Only Watch GPS needed
5. **Battery optimization** - 8+ hours Watch, 12+ hours iPhone

### Common Pitfalls to Avoid
- ❌ **Throttle regression** - Never increase GPS throttle beyond 0.5s
- ❌ **Scope creep** - Stick to v1.0 features, defer v1.5/v2.0
- ❌ **Over-engineering** - Keep it simple (pet tracker, not relay framework)
- ❌ **Wrong source code** - Use gps-relay-framework, NOT iosTracker_class
- ❌ **External relay** - No WebSocket, no Jetson, no servers

---

## ✅ Ready to Start?

**Next Steps:**
1. Read PAWATCH_GUIDELINES.md (if not already done)
2. Verify gps-relay-framework is accessible
3. Use `/start` command to initialize development
4. Begin Week 1: Foundation Setup

**Questions to Answer:**
- Do you want to start with Week 1 immediately?
- Any adjustments to the timeline?
- Which features are highest priority?

---

**Document Version:** 1.0
**Last Updated:** 2025-01-05
**Status:** Ready for implementation
