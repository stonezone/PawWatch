 pawWatch Pet Tracker Implementation Plan

 Recommendation: Fork Project 1 (gps-relay-framework)

 Timeline: 4-5 weeks to v1.0 launch

 ---
 Phase 1: Repository Setup (Day 1)

 1. Fork /Users/zackjordan/code/jetson/dev/gps-relay-framework
 2. Create new repo: pawWatch-pet-tracker
 3. Create development branch: feature/pet-tracker-core
 4. Update version to v0.1.0 (pet tracker MVP)

 ---
 Phase 2: Strip External Relay Components (Week 1)

 Remove:

 - Sources/WebSocketTransport/ - No external device
 - Sources/BlePeripheralTransport/ - No external device
 - Sources/LocationRelayService/ - Over-engineered for pet tracker
 - jetson/ directory - No Jetson integration
 - Dual-stream RelayUpdate architecture - Only need dog GPS

 Keep:

 - Sources/WatchLocationProvider/ - 0.5s throttle GPS (CRITICAL)
 - Sources/LocationCore/LocationFix.swift - Data model
 - WatchConnectivity patterns - Reliability layer
 - Test infrastructure - 81 unit tests

 Simplify:

 - Convert dual-stream to single-stream (dog GPS only)
 - Remove "base" iPhone GPS collection
 - Keep Watch GPS at 0.5s throttle

 ---
 Phase 3: Build iOS Pet Tracker UI (Weeks 2-3)

 Create New iOS App Module:

 Technology Stack:
 - SwiftUI (iOS 26+ target)
 - Liquid Glass design language
 - MapKit for real-time visualization
 - CoreData for local storage
 - UserNotifications for alerts

 Views to Build:

 1. DashboardView (Primary screen)
 - Pet profile card (photo, name, breed, age)
 - Current location status ("Home", "Park", etc.)
 - Wellness score (0-100)
 - Battery levels (watch + phone)
 - Quick command buttons
 - Recent alerts feed

 2. MapView
 - Real-time pet location marker
 - Movement trail (last 100 fixes)
 - Geofence zones (circles on map)
 - "Follow" mode toggle
 - Add/edit geofence interface

 3. ActivityView
 - Today's stats (steps, distance, calories)
 - Weekly chart
 - Goal progress bars
 - Historical trends

 4. HealthView
 - Wellness score breakdown
 - Fall detection alerts
 - Behavior patterns
 - Sleep quality metrics

 5. SettingsView
 - Pet profile editor
 - Notification preferences
 - Geofence management
 - Activity goal customization

 ---
 Phase 4: Implement Pet-Specific Features (Week 3-4)

 1. Geofencing Service

 class GeofenceService: ObservableObject {
     @Published var zones: [SafeZone] = []

     func checkViolation(_ fix: LocationFix) -> Bool
     func distanceToZone(_ fix: LocationFix, _ zone: SafeZone) -> Double
     func sendAlert(for violation: GeofenceViolation)
 }

 2. Activity Tracker

 class ActivityService: ObservableObject {
     func calculateSteps(from fixes: [LocationFix]) -> Int
     func calculateDistance(from trail: [LocationFix]) -> Double
     func estimateCalories(weight: Double, steps: Int, breed: String) -> Double
     func updateGoals()
 }

 3. Wellness Calculator

 struct WellnessCalculator {
     func calculate(
         activity: ActivityMetrics,
         rest: SleepMetrics,
         behavior: BehaviorMetrics
     ) -> Double // 0-100 score
 }

 4. Fall Detection

 class FallDetector {
     func analyzeMotion(_ data: CMAccelerometerData)
     func detectAnomalies() -> [FallEvent]
     func triggerEmergencyAlert()
 }

 5. Local Data Persistence

 - CoreData models for:
   - Pet profiles
   - Geofence zones
   - Location history
   - Activity records
   - Health events

 ---
 Phase 5: Polish & Testing (Week 4-5)

 Testing:

 - Unit tests for geofencing logic
 - Activity calculation accuracy
 - WatchConnectivity reliability
 - Background task testing
 - Battery impact testing
 - Real pet field testing

 UI/UX Polish:

 - iOS 26 Liquid Glass design implementation
 - Smooth animations
 - Dark mode support
 - Accessibility features
 - Haptic feedback

 Performance:

 - Optimize map rendering
 - Efficient location trail storage
 - Background update optimization
 - Battery consumption tuning

 ---
 Success Metrics

 MVP (End of Week 2):
 - ✅ Watch sends GPS every 0.5s
 - ✅ iPhone displays real-time on map
 - ✅ Basic dashboard functional
 - ✅ Battery monitoring working

 v1.0 (End of Week 5):
 - ✅ Geofencing with alerts
 - ✅ Activity tracking (steps, distance, calories)
 - ✅ Wellness score
 - ✅ iOS 26 Liquid Glass UI
 - ✅ Fall detection
 - ✅ Beta tested with real pets
 - ✅ Ready for TestFlight

 ---
 Risk Mitigation

 Low Risk: Stripping relay code breaks tests
 - Mitigation: Run test suite after each removal, fix incrementally

 Medium Risk: iOS UI takes longer than estimated
 - Mitigation: Use SwiftUI templates, prototype early in Week 2

 Low Risk: Battery drain from real-time GPS
 - Mitigation: Project 1 already optimized, proven in field

 ---
 Post-Launch Roadmap

 v1.5 (Month 2):
 - Multiple pet support
 - Family sharing
 - Cloud sync (iCloud)

 v2.0 (Month 3-4):
 - Apple Watch complications
 - Widget support
 - Haptic command training
 - Vet report generation

 ---
 Why This Approach Wins

 1. Fastest: 4-5 weeks vs 5-6 weeks (Project 2) vs 8-10 weeks (fresh)
 2. Lowest Risk: 81 unit tests, proven WatchConnectivity
 3. Best Foundation: 0.5s GPS throttle = real-time tracking
 4. Most Reusable: 65% code reuse from Project 1
 5. Production Ready: Tested, reliable, scalable