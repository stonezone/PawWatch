# pawWatch: Product & Architecture Roadmap

**Last Updated**: 2025-11-07
**Status**: Early MVP - Post Architecture Conversion
**Version**: 1.0.4

---

## Executive Summary

pawWatch is pioneering a novel approach to pet tracking: repurposing Apple Watch as a professional-grade GPS tracker. This plan prioritizes **validating the core concept on real hardware** before investing in architectural perfection.

**Success means**: Proving a spare Apple Watch can reliably track a pet for 4+ hours with acceptable GPS accuracy and connection stability.

**If successful**, this becomes a no-subscription alternative to $100+ dedicated pet trackers. **If unsuccessful**, clean architecture won't matter—we pivot or abandon.

---

## Phase 1: Hardware Validation (CRITICAL PATH)
**Status**: 🔴 Not Started
**Priority**: Highest
**Estimated Time**: 3-5 days
**Risk**: High (concept may fail here)

### Objectives
Prove the Apple Watch + iPhone combination can reliably track a pet in real-world conditions.

### Tasks

#### 1.1 Physical Device Deployment
- [ ] Deploy Watch app to actual Apple Watch (any model available)
- [ ] Deploy iPhone app to physical iPhone
- [ ] Verify Xcode 26.1 error 143 fix works on device (not just simulator)
- [ ] Confirm app launches and establishes WatchConnectivity

**Acceptance**: Both apps install, launch, and connect successfully.

#### 1.2 Battery Life Baseline
- [ ] Start Watch app with full battery
- [ ] Run continuous GPS tracking for 1 hour outdoors
- [ ] Measure battery drain percentage
- [ ] Extrapolate to full-day usage
- [ ] Document findings with device model and conditions

**Acceptance**: Understand actual battery consumption (target: 4+ hours minimum).

#### 1.3 GPS Accuracy Testing
- [ ] Walk known trail with Watch on test subject (backpack, dog)
- [ ] Record GPS trail on iPhone app
- [ ] Compare to ground truth (satellite imagery, known landmarks)
- [ ] Measure horizontal accuracy in various environments:
  - Open field
  - Urban area (buildings)
  - Dense woods
  - Indoors (should fail gracefully)

**Acceptance**: GPS accuracy within ±10m in open areas, ±30m in challenging conditions.

#### 1.4 WatchConnectivity Range & Reliability
- [ ] Test connection stability at various distances:
  - 10 feet (same room)
  - 50 feet (different rooms)
  - 100 feet (different building floors)
  - 300+ feet (outdoor separation)
- [ ] Measure reconnection time after signal loss
- [ ] Test with iPhone locked vs active
- [ ] Test with Watch on wrist vs stationary

**Acceptance**: Connection remains stable for typical pet separation distances (50-100ft).

#### 1.5 Document Findings
- [ ] Create `docs/HARDWARE_VALIDATION.md` with all test results
- [ ] Include battery graphs, GPS accuracy plots, connection reliability data
- [ ] Decision point: **GO/NO-GO for Phase 2**

**Success Criteria**:
- ✅ Battery lasts 3+ hours with continuous GPS
- ✅ GPS accuracy ±20m in typical conditions
- ✅ WatchConnectivity stable for 50ft+ separation
- ✅ No critical crashes or data loss

**Failure Indicators**:
- ❌ Battery dies in <90 minutes
- ❌ GPS drift >100m frequently
- ❌ Connection drops constantly beyond 20ft
- ❌ Watch app crashes repeatedly

**If Phase 1 fails**: Pivot to alternative approaches (cellular-only tracking, AirTag integration, abandon concept).

---

## Phase 2: Battery Optimization (ENABLE REAL USE)
**Status**: ⚪ Blocked (depends on Phase 1 GO)
**Priority**: High
**Estimated Time**: 4-7 days
**Risk**: Medium

### Objectives
Extend battery life to enable all-day pet tracking for typical use cases (4-8 hours).

### Tasks

#### 2.1 Implement WKExtendedRuntimeSession
- [ ] Research `WKExtendedRuntimeSession` API (watchOS extended background runtime)
- [ ] Integrate alongside existing `HKWorkoutSession`
- [ ] Test if it extends battery life beyond workout-only approach
- [ ] Document battery improvement percentage
- [ ] Handle session invalidation gracefully

**Rationale**: TODO.md mentions this. It keeps Watch app alive even when wrist is down, potentially critical for pet use.

**Acceptance**: Measurable battery life improvement (target: +20-30% runtime).

#### 2.2 Smart Polling Strategy
- [ ] Implement motion detection (if pet is stationary, reduce GPS frequency)
- [ ] Add configurable update intervals:
  - Aggressive: Every 10 seconds (high accuracy, short battery)
  - Balanced: Every 30 seconds (default)
  - Battery Saver: Every 2 minutes (max battery)
- [ ] Only send GPS updates to iPhone on significant movement (>10m)
- [ ] Cache fixes locally on Watch, sync in batches

**Acceptance**: Battery life doubles in "stationary pet" scenarios.

#### 2.3 Low Battery Warnings
- [ ] Monitor Watch battery level on both devices
- [ ] Show iPhone alert at 30%, 20%, 10% Watch battery
- [ ] Add Watch app notification to owner (haptic + visual)
- [ ] Suggest recharge or reduced tracking mode

**Acceptance**: Owner has 15+ minutes warning before Watch dies.

#### 2.4 Cellular Watch Support
- [ ] Test if GPS+Cellular Watch model works without iPhone relay
- [ ] Document setup differences (cellular vs GPS-only)
- [ ] Add UI indication of connection method (Bluetooth, WiFi, Cellular)

**Acceptance**: Cellular Watch maintains tracking even when iPhone is out of range.

#### 2.5 Battery Benchmarking
- [ ] Re-run all Phase 1 battery tests with optimizations
- [ ] Create comparison table: Baseline vs Optimized
- [ ] Target: 5+ hours continuous tracking on GPS-only Watch, 8+ on Cellular Watch

**Success Criteria**:
- ✅ 5+ hours battery on GPS-only Watch (enough for long hike)
- ✅ 8+ hours on Cellular Watch (full work day)
- ✅ Owner gets proactive low-battery warnings
- ✅ Stationary pets drain battery slowly

---

## Phase 3: Reliability & Error Handling (POLISH FOR USERS)
**Status**: ⚪ Blocked (depends on Phase 2)
**Priority**: High
**Estimated Time**: 3-5 days
**Risk**: Low

### Objectives
Handle edge cases gracefully and improve user experience when things go wrong.

### Tasks

#### 3.1 HealthKit Authorization Errors
- [ ] Surface HealthKit auth failures to user (currently silent)
- [ ] Add Watch app alert: "Workout tracking denied - GPS will be limited"
- [ ] Provide deep link to Settings for permission changes
- [ ] Document in user guide that HealthKit is required for background GPS

**Acceptance**: User understands why tracking isn't working if permissions denied.

#### 3.2 WatchConnectivity Error Recovery
- [ ] Handle connection loss gracefully (queue updates, retry)
- [ ] Show connection status indicator on both devices
- [ ] Auto-reconnect when devices back in range
- [ ] Persist queued GPS fixes locally, sync when reconnected

**Acceptance**: App recovers from connection drops without data loss.

#### 3.3 GPS Signal Loss Handling
- [ ] Detect when GPS accuracy degrades (indoors, urban canyons)
- [ ] Show "Weak GPS" indicator to owner
- [ ] Don't spam fixes with poor accuracy (>100m)
- [ ] Resume normal tracking when signal improves

**Acceptance**: App doesn't flood UI with bad data during GPS blackouts.

#### 3.4 Watch App UX Improvements
- [ ] Add large "STOP TRACKING" button (easy to tap even with pet movement)
- [ ] Show elapsed tracking time
- [ ] Display current battery percentage prominently
- [ ] Implement Digital Crown water lock (document in user guide)

**Acceptance**: Watch app is simple and reliable to operate in field.

#### 3.5 iPhone App Edge Cases
- [ ] Handle "No GPS data yet" state gracefully
- [ ] Show helpful message if Watch not connected
- [ ] Add troubleshooting guide in Settings tab
- [ ] Implement app backgrounding behavior (keep receiving updates)

**Acceptance**: iPhone app guides user through common problems.

**Success Criteria**:
- ✅ All error states have clear user messaging
- ✅ App recovers automatically from transient failures
- ✅ User can troubleshoot issues without developer help

---

## Phase 4: Code Quality & Architecture (ENABLE SAFE ITERATION)
**Status**: ⚪ Blocked (depends on Phase 3)
**Priority**: Medium
**Estimated Time**: 5-10 days
**Risk**: Low (concept already proven)

### Objectives
Establish test coverage and clean architecture to enable future feature development without breaking core functionality.

### Tasks

#### 4.1 Critical Path Testing
- [ ] Add Swift Testing tests for `WatchLocationProvider`:
  - GPS fix generation
  - HealthKit workout session lifecycle
  - Battery monitoring
  - Mock CoreLocation and HealthKit
- [ ] Add tests for `PetLocationManager`:
  - WatchConnectivity message handling
  - Location history management
  - Distance calculations
- [ ] Add tests for `MeasurementDisplay`:
  - Metric/imperial conversions
  - Edge cases (zero, negative, huge values)

**Target**: 70% coverage for GPS and Connectivity modules.

#### 4.2 Resolve Duplicate WatchLocationProvider
- [ ] Identify which `WatchLocationProvider.swift` is canonical:
  - Check `pawWatch Watch App/WatchLocationProvider.swift`
  - Check `pawWatchPackage/Sources/pawWatchFeature/WatchLocationProvider.swift`
- [ ] Determine which is compiled into each target (check target membership)
- [ ] Make Package version canonical, delete Watch App copy
- [ ] Update Watch App to import from Package
- [ ] Verify build succeeds on both simulator and device

**Acceptance**: Single source of truth for location provider logic.

#### 4.3 Documentation Consolidation
- [ ] Merge `TODO.md` into this `BACKTRACK_TODO.md`
- [ ] Keep `CLAUDE.md` (architecture & AI guidelines)
- [ ] Keep `DEVELOPMENT.md` (setup & workflows)
- [ ] Keep `README.md` (user-facing description)
- [ ] Keep `docs/VERSIONING.md` (version automation)
- [ ] Add `docs/HARDWARE_VALIDATION.md` (from Phase 1)
- [ ] Add `docs/BATTERY_OPTIMIZATION.md` (from Phase 2)
- [ ] Add `docs/USER_GUIDE.md` (setup instructions for end users)

**Acceptance**: Documentation is organized by audience and purpose.

#### 4.4 Package Modularization (OPTIONAL)
**Note**: Only do this if app grows beyond current scope. Current single-module structure is fine for MVP.

If needed later:
```
pawWatchPackage/
  Sources/
    GPSTracking/           # WatchLocationProvider, CoreLocation, HealthKit
    Connectivity/          # WatchConnectivity, message protocols
    SharedModels/          # GPSFix, Sendable data types
    UIComponents/          # Reusable SwiftUI views (PetMarkerView, etc.)
    DashboardFeature/      # Dashboard tab
    HistoryFeature/        # History tab
    SettingsFeature/       # Settings tab
```

**Defer unless**: Adding multi-pet support, family sharing, or other major features.

#### 4.5 Asset Catalog Cleanup
- [ ] Fix missing Accent Color (add to both iOS and watchOS assets)
- [ ] Generate proper 1024x1024 App Store icons for Watch app
- [ ] Assign all unassigned icon sizes
- [ ] Test icon rendering at all sizes (complications, home screen, App Store)

**Acceptance**: Zero asset catalog warnings.

**Success Criteria**:
- ✅ 70%+ test coverage for critical modules
- ✅ No duplicate code files
- ✅ Documentation is organized and up-to-date
- ✅ Build produces zero warnings (except acceptable)

---

## Phase 5: Advanced Features (IF CONCEPT SUCCEEDS)
**Status**: ⚪ Future Work
**Priority**: Low (Nice-to-have)
**Estimated Time**: Varies by feature
**Risk**: Low

These features differentiate pawWatch from competitors and add value beyond basic tracking.

### 5.1 Activity Insights
- [ ] Display pet's activity metrics (distance, steps, calories)
- [ ] Show heart rate if Watch supports it
- [ ] Create activity trends graph (daily, weekly)
- [ ] Export to HealthKit or CSV

**Value**: Turns pet tracker into pet health monitor.

### 5.2 Geofencing Alerts
- [ ] Define "safe zone" on map
- [ ] Alert owner if pet leaves zone
- [ ] Push notification to iPhone
- [ ] Log geofence events in history

**Value**: Proactive lost pet prevention.

### 5.3 Historical Heatmaps
- [ ] Aggregate GPS trail data over days/weeks
- [ ] Show heatmap of where pet spends time
- [ ] Identify favorite spots, common routes

**Value**: Understand pet behavior patterns.

### 5.4 Multiple Pet Support
- [ ] Track multiple Watches simultaneously
- [ ] Pet profiles (name, breed, photo)
- [ ] Per-pet history and settings
- [ ] Switch between pets in UI

**Value**: Multi-pet households can track all animals.

### 5.5 Family Sharing
- [ ] Share tracking with other family members
- [ ] Each person's iPhone can view same Watch
- [ ] Permissions (view-only, can control tracking)

**Value**: Whole family can monitor pet.

### 5.6 Offline Mode & Trail Export
- [ ] Save trails locally even without iPhone connection
- [ ] Sync when reconnected
- [ ] Export GPX/KML files for use in other apps
- [ ] Share trail with friends

**Value**: Works in cellular dead zones, integrates with hiking apps.

---

## Technical Debt Inventory

**Items We're Carrying (and why it's okay for now)**:

| Issue | Impact | Priority | Rationale |
|-------|--------|----------|-----------|
| Duplicate WatchLocationProvider.swift | Confusion, merge conflicts | Medium | Not blocking functionality, fix in Phase 4 |
| Zero test coverage | Risky refactoring | Medium | Need to prove concept first, tests come after |
| Single module structure | Harder to navigate | Low | App is small, premature to modularize |
| Asset catalog warnings | Visual polish | Low | Cosmetic only, not affecting functionality |
| No CI/CD pipeline | Manual testing only | Low | Team of one, automate when scaling |
| Scattered documentation | Onboarding friction | Low | Consolidate in Phase 4 |

**Items We've Fixed**:
- ✅ Xcode 26.1 error 143 (single-target Watch app)
- ✅ Swift 6 threading issues (@MainActor isolation)
- ✅ Tab-based navigation (Dashboard, History, Settings)
- ✅ Metric/imperial unit support
- ✅ Version automation system

---

## Success Metrics

### Product Success (End-User Value)
- [ ] **Battery Life**: Watch lasts 5+ hours of continuous tracking
- [ ] **GPS Accuracy**: ±20m in typical conditions
- [ ] **Connection Stability**: <5% packet loss at 50ft separation
- [ ] **User Testimonials**: "Found my lost dog using pawWatch"
- [ ] **Daily Usage**: Users run tracking 3+ times per week

### Technical Success (Developer Velocity)
- [ ] **Test Coverage**: 70%+ for critical paths
- [ ] **Build Time**: <60 seconds clean build
- [ ] **Zero Crashes**: No crashes in 100+ test runs
- [ ] **Documentation**: New developer can contribute in <1 day
- [ ] **CI/CD**: Automated testing on every commit

### Business Success (Viability)
- [ ] **User Acquisition**: 100+ beta testers
- [ ] **Retention**: 70%+ weekly active users
- [ ] **Referrals**: 30%+ invite friends organically
- [ ] **Market Validation**: Positive Reddit/forum feedback
- [ ] **Monetization**: (TBD - premium features? one-time purchase?)

---

## Risk Assessment & Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Battery life insufficient (<3hrs) | Medium | Critical | Implement WKExtendedRuntimeSession, smart polling, battery saver mode |
| WatchConnectivity unreliable | Medium | High | Test cellular Watch model, improve reconnection logic, queue data |
| GPS accuracy poor in real world | Low | High | Set user expectations, show accuracy indicator, filter bad fixes |
| Watch falls off pet collar | Medium | Medium | Document secure attachment methods, consider 3rd party accessories |
| Cost barrier ($250+ Watch) | High | Medium | Target users with spare Watch, position as premium solution |
| Apple changes watchOS APIs | Low | High | Stay on latest iOS/watchOS, abstract platform APIs |
| Competitor launches similar app | Medium | Low | Speed to market, focus on Apple ecosystem integration |

---

## Decision Log

### 2025-11-07: Architecture Conversion Complete
**Decision**: Convert from WatchKit extension to single-target Watch app
**Rationale**: Xcode 26.1 has unfixable bug (error 143) with watchapp2 product type
**Outcome**: Build succeeds, threading issues fixed, ready for device testing

### 2025-11-07: Prioritize Hardware Validation Over Code Quality
**Decision**: Test on real devices before architectural refactoring
**Rationale**: Clean code doesn't matter if concept fails on hardware
**Outcome**: This roadmap focuses on proving concept first

### 2025-11-07: Defer Package Modularization
**Decision**: Keep single pawWatchFeature module for now
**Rationale**: App is small (<2000 LOC), premature optimization
**Re-evaluate**: When adding multi-pet or family sharing features

---

## Timeline Estimates

| Phase | Duration | Start After |
|-------|----------|-------------|
| Phase 1: Hardware Validation | 3-5 days | Immediate |
| Phase 2: Battery Optimization | 4-7 days | Phase 1 GO decision |
| Phase 3: Reliability & UX | 3-5 days | Phase 2 complete |
| Phase 4: Code Quality | 5-10 days | Phase 3 complete |
| Phase 5: Advanced Features | Ongoing | Phase 4 complete |

**Total to MVP**: ~15-27 days (3-6 weeks)
**MVP Definition**: Reliable 5+ hour pet tracking with good UX

---

## Next Actions (Immediate)

1. **Deploy to Physical Devices** (Phase 1.1)
   - Connect Apple Watch to Mac
   - Build and install Watch app
   - Build and install iPhone app
   - Verify apps connect and communicate

2. **First Battery Test** (Phase 1.2)
   - Start tracking with full Watch battery
   - Go for 1-hour outdoor walk
   - Record battery drain
   - Document device model and conditions

3. **GPS Accuracy Baseline** (Phase 1.3)
   - Walk known trail
   - Compare recorded trail to ground truth
   - Measure accuracy in meters

4. **GO/NO-GO Decision** (Phase 1.5)
   - If battery/GPS/connectivity acceptable → Phase 2
   - If not → Analyze root causes, pivot or abandon

---

## Open Questions

1. **Battery Life**: Will WKExtendedRuntimeSession provide sufficient improvement?
2. **Cellular Watch**: Do we require GPS+Cellular model or support GPS-only?
3. **Target Audience**: Pet owners with spare Watch, or convince owners to buy dedicated Watch?
4. **Pricing**: Free app? One-time purchase? Freemium with premium features?
5. **Ruggedization**: Do we recommend 3rd party Watch cases/bands, or rely on Watch durability?
6. **Multi-Platform**: Do we ever support Android? (Probably not - Apple ecosystem only)
7. **Data Privacy**: Do we store GPS trails in cloud? Local only? User choice?

---

## Appendix: Competitor Analysis

| Product | Price | Subscription | Battery | GPS | Pros | Cons |
|---------|-------|--------------|---------|-----|------|------|
| Whistle GO | $100 device | $10/month | 20 days | Cellular | Purpose-built, rugged | Monthly fee, lower accuracy |
| Fi Series 3 | $150 device | $10/month | 30 days | Cellular+WiFi | Long battery, escape alerts | Expensive, subscription |
| Apple AirTag | $30 | None | 1 year | Crowd-sourced | Cheap, no subscription | Not real-time GPS, needs other iPhones nearby |
| **pawWatch** | $0 (spare Watch) | None | 5+ hours* | Watch GPS | No subscription, high accuracy, health data | Requires $250+ Watch, short battery |

*With optimizations in Phase 2

**Unique Value Proposition**: pawWatch is the only **no-subscription, high-accuracy GPS pet tracker** that leverages existing Apple hardware and provides health insights.

---

## Conclusion

This roadmap balances **product validation** (prove it works) with **engineering quality** (make it maintainable). We prioritize user value over architectural purity in early phases, then clean up once the concept is proven.

**Key Philosophy**:
- Ship working features over perfect code
- Test on real hardware before optimizing
- Validate assumptions early
- Iterate based on user feedback

**Next Milestone**: Complete Phase 1 hardware validation and make GO/NO-GO decision.

---

*This document supersedes `TODO.md` and becomes the single source of truth for pawWatch development priorities.*
