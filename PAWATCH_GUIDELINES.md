# pawWatch Project Guidelines

**Version:** 1.0
**Date:** 2025-01-05
**Status:** Active Development

---

## 🎯 Project Identity

**Official Name:** pawWatch
**Tagline:** "Transform your spare Apple Watch into a comprehensive pet tracker"
**Category:** Consumer Pet Technology
**Platform:** iOS 26+ / watchOS 26+
**Design Language:** Liquid Glass

---

## 📋 Executive Summary

pawWatch is a **standalone iOS/watchOS pet tracking application** that uses an Apple Watch (worn by pet) as a GPS sensor and an iPhone (carried by owner) as the display and processing unit. The app provides real-time location tracking, geofencing, activity monitoring, and health alerts for pets.

**Critical Distinction:** pawWatch is NOT a GPS relay framework, NOT a multi-device coordination system, and NOT connected to external hardware. It is a self-contained pet tracker using only Apple Watch + iPhone.

---

## 🌟 Core Vision Statement

pawWatch transforms a spare Apple Watch into a comprehensive pet health and safety monitor. The Watch, worn on the pet's collar or harness, captures GPS location, activity metrics, and motion data. The iPhone app displays this information in real-time with an iOS 26 Liquid Glass interface, providing pet owners with live location tracking, virtual geofences, activity goals, wellness scores, and emergency alerts. No external devices, no servers, no complex setup—just Watch + iPhone.

---

## 📱 Platform & Technology Requirements

### iOS 26+ Mandate

**iOS 26 EXISTS** - Stop questioning this in every conversation:
- **Announced:** WWDC June 2025
- **Released:** September 2025
- **Version Jump:** Apple skipped iOS 19-25, adopted year-based numbering (26 = 2026 cycle)
- **Design Language:** Liquid Glass (frosted glass effects, fluid animations, depth layers)
- **API Changes:** No improvements to Core Location, GPS, or WatchConnectivity relevant to this project
- **Why iOS 26+:** Design language mandate ONLY—no technical GPS advantages

**Required Versions:**
- iOS 26.0+ (iPhone)
- watchOS 26.0+ (Apple Watch)
- Xcode 26.0+ (unified version numbering with iOS)
- Swift 6.2.1+

**Technology Stack:**
- SwiftUI (100% of UI—no UIKit)
- MapKit (location visualization)
- CoreData (local persistence)
- UserNotifications (alerts)
- HealthKit (activity metrics)
- CoreMotion (fall detection)
- WatchConnectivity (Watch ↔ iPhone communication)

**Device Requirements:**
- Apple Watch Series 4+ (cellular model recommended)
- iPhone 11+
- Watch must be paired to iPhone before pet attachment

---

## 🏗️ Architecture Principles

### Critical Performance Requirements

1. **Real-Time GPS: NON-NEGOTIABLE**
   - Maximum throttle: 0.5 seconds
   - Target update rate: ~2Hz (2 updates per second)
   - LTE mode latency: <1 second
   - NO regressions to 10-second throttling

2. **Single-Stream Architecture**
   - Watch GPS → iPhone display
   - NO dual-stream (no iPhone base GPS)
   - NO external device relay (no Jetson, no servers)
   - iPhone processes data locally (geofencing, activity, alerts)

3. **WatchConnectivity Reliability**
   - Triple-path messaging:
     - `sendMessageData()` when reachable (immediate)
     - `updateApplicationContext()` for background (latest)
     - `transferFile()` as fallback (guaranteed delivery)
   - Exponential backoff on failures
   - Queue management for offline periods
   - Duplicate detection via sequence numbers

4. **Battery Optimization**
   - GPS is primary drain (unavoidable for real-time tracking)
   - HealthKit workout session keeps app active
   - Background app refresh for iPhone
   - Minimize WatchConnectivity overhead

---

## ✅ Core Features (Required for v1.0)

### 1. Real-Time Location Tracking
- Live map view with pet location marker
- Movement trail (last 100 GPS fixes)
- Update frequency display
- Accuracy visualization
- Last known location when offline

### 2. Geofencing
- Create custom safe zones (circular regions)
- Entry/exit alerts with notifications
- Multiple geofence support
- Visual representation on map
- Distance to nearest geofence

### 3. Activity Tracking
- Daily steps (estimated from GPS movement)
- Distance traveled (kilometers/miles)
- Calories burned (breed/weight/age adjusted)
- Active time vs rest time
- Goal progress (customizable targets)

### 4. Wellness Score
- 0-100 score based on:
  - Activity level (40%)
  - Rest quality (30%)
  - Behavior patterns (20%)
  - Health alerts (10%)
- Daily/weekly/monthly trends
- Breed-specific benchmarks

### 5. Fall Detection
- CoreMotion accelerometer analysis
- Sudden impact detection
- Abnormal movement patterns
- Emergency notifications
- Manual emergency button

### 6. Health Monitoring
- Battery levels (Watch + iPhone)
- GPS accuracy tracking
- WatchConnectivity status
- Sleep/rest pattern analysis
- Behavior anomaly detection

### 7. User Interface (iOS 26 Liquid Glass)
- **DashboardView:** Pet status, wellness, quick actions
- **MapView:** Real-time location, geofences, trail
- **ActivityView:** Steps, distance, calories, goals
- **HealthView:** Wellness breakdown, alerts, trends
- **SettingsView:** Pet profile, notifications, preferences

---

## 🚫 Explicitly OUT OF SCOPE

### Prohibited Features (Do NOT Implement)

1. **External Device Integration**
   - ❌ Jetson Orin Nano relay
   - ❌ USB tethering to computers
   - ❌ WebSocket/BLE transports to external systems
   - ❌ Server-side processing
   - ❌ Cloud-based GPS fusion

2. **Multi-Device GPS Coordination**
   - ❌ Dual-stream architecture (iPhone base + Watch remote)
   - ❌ RelayUpdate{base, remote, fused} structure
   - ❌ Coordinate frame transformations (WGS84→ECEF→ENU)
   - ❌ Relative pose estimation
   - ❌ Multi-device time synchronization

3. **Robot/Hardware Control**
   - ❌ Gimbal pan/tilt calculations
   - ❌ PTZ camera control
   - ❌ Robot Cameraman features
   - ❌ Servo/motor control
   - ❌ External sensor integration

4. **Enterprise/Complex Features (v1.0)**
   - ❌ Multiple pet support (defer to v1.5)
   - ❌ Family sharing (defer to v1.5)
   - ❌ Cloud sync/backup (defer to v2.0)
   - ❌ Vet integration (defer to v2.0)
   - ❌ Treat dispenser hardware (defer to future)

---

## 📦 Code Reuse Guidelines

### ✅ APPROVED Source Code

**Primary Source:** `/Users/zackjordan/code/jetson/dev/gps-relay-framework` (Project 1)

**What to Reuse:**
1. **`Sources/WatchLocationProvider/`** (95% reusable)
   - 0.5s GPS throttle ✅
   - HealthKit workout session ✅
   - WatchConnectivity triple-path messaging ✅
   - Battery monitoring ✅
   - Sequence number tracking ✅

2. **`Sources/LocationCore/LocationFix.swift`** (100% reusable)
   - Complete data model ✅
   - JSON serialization ✅
   - Source differentiation (iOS/watchOS) ✅
   - Battery/accuracy fields ✅

3. **WatchConnectivity Patterns** (90% reusable)
   - Retry logic with exponential backoff ✅
   - Queue management ✅
   - Duplicate detection ✅
   - Connection state monitoring ✅

4. **Test Infrastructure** (80% reusable)
   - 81 unit tests from Project 1 ✅
   - WatchConnectivity mocking patterns ✅
   - GPS simulation utilities ✅

**What to Strip:**
- ❌ `WebSocketTransport` module
- ❌ `BlePeripheralTransport` module
- ❌ `LocationRelayService` (dual-stream coordinator)
- ❌ Dual-stream `RelayUpdate` architecture
- ❌ Jetson server code (`jetson/` directory)
- ❌ USB tethering logic
- ❌ External relay coordinator

### ❌ FORBIDDEN Source Code

**DO NOT USE:** `/Users/zackjordan/code/jetson/orin/iosTracker_class` (Project 2)

**Reasons:**
1. **10-second GPS throttle** - NOT real-time (0.1Hz vs 2Hz) ❌
2. **Robot Cameraman focus** - Wrong use case (gimbal control) ❌
3. **On-device gimbal calculations** - Irrelevant for pet tracking ❌
4. **Less mature** - v1.0.0 vs Project 1's v1.0.4 ❌
5. **Fewer tests** - 97 tests vs Project 1's 135 tests ❌

**Exceptions (ONLY if needed):**
- May reference authentication token pattern (security feature)
- May review distance/bearing calculations (for "dog is X meters away" display)
- **But:** Do NOT copy throttling code, do NOT copy gimbal logic

---

## 🛡️ Development Guardrails

### Must Maintain

1. **GPS Performance**
   - 0.5s throttle minimum (no regressions to 10s)
   - <1s latency in LTE mode
   - ~2Hz update rate on map
   - Sequence gaps ≤1 (95%+ consecutive)

2. **WatchConnectivity Reliability**
   - Triple-path messaging (interactive + context + file)
   - Exponential backoff on failures
   - Queue management for offline periods
   - Zero data loss in Bluetooth range
   - Minimal data loss in LTE range

3. **Battery Efficiency**
   - Watch lasts 8+ hours continuous tracking
   - GPS accuracy vs battery tradeoff
   - Background app refresh on iPhone
   - Workout session management

4. **iOS 26 Design Compliance**
   - Liquid Glass visual language
   - Frosted glass effects
   - Fluid animations
   - Depth layering
   - System color harmony
   - Dark mode support

### Must Avoid

1. **Throttling Regressions**
   - NEVER increase GPS throttle beyond 0.5s
   - NEVER add distance filters >10m
   - NEVER disable accuracy monitoring

2. **Architecture Drift**
   - NEVER add external device relay
   - NEVER add dual-stream GPS
   - NEVER add server-side processing
   - NEVER add gimbal/robot control

3. **Scope Creep**
   - NEVER add features not in Core Features list without approval
   - NEVER implement v2.0 features in v1.0
   - NEVER add complex enterprise features early

---

## 📊 Success Metrics

### Technical Performance (v1.0 Launch)

| Metric | Target | Measurement |
|--------|--------|-------------|
| GPS Latency (LTE) | <1 second | Average timestamp delta |
| GPS Update Rate | ~2Hz (0.5s) | LocationFix frequency |
| Sequence Gaps | ≤1 (95%+) | Consecutive sequence numbers |
| Battery Life (Watch) | 8+ hours | Continuous tracking runtime |
| Battery Life (iPhone) | 12+ hours | Background GPS reception |
| Geofence Accuracy | ±10 meters | Violation detection precision |
| UI Responsiveness | <100ms | Tap-to-action latency |
| App Size | <50MB | Downloaded bundle size |
| Memory Usage | <200MB | Peak iPhone RAM |
| Test Coverage | >80% | Unit + integration tests |

### User Experience (Post-Launch)

| Metric | Target | Measurement |
|--------|--------|-------------|
| App Store Rating | >4.5 stars | Reviews |
| Crash Rate | <0.1% | Analytics |
| Daily Active Users | >60% | Engagement |
| Feature Adoption | >80% | Geofencing usage |
| Support Tickets | <5% users | Customer service |
| Retention (30-day) | >70% | Cohort analysis |

---

## 🎯 Decision-Making Framework

When evaluating new features or architecture changes, ask:

### The Four Questions

1. **Does this help pet owners track their pets in real-time?**
   - YES → Consider adding
   - NO → Reject

2. **Does this require iOS 26 Liquid Glass UI?**
   - YES → Use Liquid Glass patterns
   - NO → Still use Liquid Glass (mandate)

3. **Does this work with ONLY Watch + iPhone (no external devices)?**
   - YES → Architecturally sound
   - NO → Reject (out of scope)

4. **Does this maintain 0.5s GPS real-time performance?**
   - YES → Performance acceptable
   - NO → Reject (performance regression)

**If NO to questions 1, 3, or 4: Feature is OUT OF SCOPE**

### Examples

**✅ APPROVE:** "Add activity goal reminders"
- Q1: YES (helps owners monitor pet health)
- Q2: YES (uses Liquid Glass notifications)
- Q3: YES (Watch + iPhone only)
- Q4: YES (doesn't affect GPS)
- **Verdict:** APPROVED

**❌ REJECT:** "Relay GPS to Jetson for processing"
- Q1: NO (external device, not pet tracking)
- Q2: N/A
- Q3: NO (requires external device)
- Q4: UNKNOWN (might affect GPS)
- **Verdict:** REJECTED (violates Q1 and Q3)

**❌ REJECT:** "Increase GPS throttle to 5s for battery"
- Q1: YES (still tracks pet)
- Q2: YES (no UI impact)
- Q3: YES (Watch + iPhone)
- Q4: NO (violates 0.5s requirement)
- **Verdict:** REJECTED (violates Q4)

---

## 📚 Reference Projects

### Approved Source

**Location:** `/Users/zackjordan/code/jetson/dev/gps-relay-framework`
**Version:** v1.0.4
**Purpose:** GPS relay framework (Jetson integration)
**Alignment:** 65% reusable for pet tracker

**Reuse:**
- ✅ `WatchLocationProvider.swift` - 0.5s throttle GPS
- ✅ `LocationFix.swift` - Data model
- ✅ WatchConnectivity patterns - Triple-path messaging
- ✅ Test suite - 81 unit tests

**Strip:**
- ❌ Dual-stream `RelayUpdate` - Only need single Watch GPS stream
- ❌ `WebSocketTransport` - No external device
- ❌ `LocationRelayService` - Over-engineered coordinator
- ❌ Jetson server code - No server integration

### Forbidden Source

**Location:** `/Users/zackjordan/code/jetson/orin/iosTracker_class`
**Version:** v1.0.0
**Purpose:** Robot Cameraman gimbal control
**Alignment:** 30% reusable (LOW - wrong use case)

**Why Forbidden:**
- ❌ 10s GPS throttle - NOT real-time (10x slower than needed)
- ❌ Robot focus - Gimbal calculations irrelevant
- ❌ Less mature - v1.0.0 vs Project 1's v1.0.4
- ❌ Fewer tests - 97 tests vs 135 tests

**Exception:**
- May reference auth token pattern (if adding security)
- May review distance calculations (for "dog is X meters away")
- **But:** NEVER copy throttling code, NEVER copy gimbal logic

---

## 🤖 AI Assistant Instructions

### When an AI assistant reads this document:

**ALWAYS:**
- ✅ Acknowledge iOS 26 exists (released September 2025)
- ✅ Acknowledge watchOS 26 exists (released September 2025)
- ✅ Maintain 0.5s GPS throttle minimum
- ✅ Prioritize real-time location updates
- ✅ Use Liquid Glass design patterns
- ✅ Reference Project 1 as approved source
- ✅ Keep architecture simple (Watch → iPhone only)
- ✅ Focus on pet tracking use case

**NEVER:**
- ❌ Question iOS 26 existence (it's real, stop asking)
- ❌ Suggest external device integration (no Jetson, no servers)
- ❌ Recommend dual-stream architecture (single stream only)
- ❌ Suggest increasing GPS throttle beyond 0.5s
- ❌ Reference Project 2 code (forbidden except auth tokens)
- ❌ Propose Robot Cameraman features (wrong use case)
- ❌ Add complexity without justification

### Standard Response to iOS 26 Questions

"iOS 26 was announced at WWDC in June 2025 and released in September 2025. Apple adopted year-based numbering (skipping iOS 19-25) where 26 represents the 2026 cycle. The Liquid Glass design language is the primary reason for requiring iOS 26+, as Core Location and WatchConnectivity APIs have no relevant improvements for GPS tracking applications."

### Architecture Review Checklist

Before recommending any architectural change:
1. ☐ Does it maintain 0.5s GPS throttle?
2. ☐ Does it avoid external device dependencies?
3. ☐ Does it use only Watch + iPhone?
4. ☐ Does it keep WatchConnectivity triple-path messaging?
5. ☐ Does it align with pet tracking use case?
6. ☐ Does it follow iOS 26 Liquid Glass design?

**If ANY checkbox is NO: Recommend AGAINST the change**

---

## 📅 Version History

### v1.0 (2025-01-05) - Initial Release
- Established project identity and vision
- Defined platform requirements (iOS 26+)
- Set architecture principles (0.5s GPS, single-stream)
- Listed core features for v1.0 launch
- Specified approved/forbidden source code
- Created decision-making framework
- Documented AI assistant instructions

---

## 🔄 Document Maintenance

This document is the **single source of truth** for pawWatch development.

**Update Frequency:**
- Review every sprint (2 weeks)
- Update when architecture decisions made
- Update when scope changes approved
- Update when new iOS versions released

**Change Control:**
- All changes require explicit approval
- Document version number increments with each update
- Major changes (architecture, scope) require v2.0, v3.0, etc.
- Minor changes (clarifications, metrics) require v1.1, v1.2, etc.

**Contact:**
- Project Owner: [Your name/contact]
- Review this document at project start
- Reference when in doubt about scope
- Share with new AI assistants at conversation start

---

## ✨ Core Principles Summary

1. **Real-Time GPS is Non-Negotiable** - 0.5s throttle minimum
2. **Watch + iPhone Only** - No external devices
3. **iOS 26 Liquid Glass** - Design language mandate
4. **Pet Tracking Focus** - Not a relay framework
5. **Single-Stream Architecture** - Watch GPS → iPhone display
6. **Project 1 as Foundation** - Reuse proven code
7. **Avoid Project 2** - Wrong architecture (10s throttle)

**When in doubt, re-read this document. It will keep pawWatch on track.**

---

**End of pawWatch Project Guidelines v1.0**
