# pawWatch 🐾

**Transform your spare Apple Watch into a comprehensive pet tracker**

[![Platform](https://img.shields.io/badge/platform-iOS%2026%2B%20%7C%20watchOS%2026%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-26.0.1-blue.svg)](https://developer.apple.com/xcode/)
[![Status](https://img.shields.io/badge/status-In%20Development-green.svg)](https://github.com/stonezone/PawWatch)

## 🎯 What is pawWatch?

pawWatch is a **standalone iOS/watchOS pet tracking application** that uses an Apple Watch (worn by your pet) as a GPS sensor and an iPhone (carried by you) as the display and processing unit. No external devices, no servers, no complex setup—just Watch + iPhone.

**Core Features:**
- 📍 Real-time GPS location tracking (~2Hz updates)
- 🏠 Geofencing with entry/exit alerts
- 🏃 Activity monitoring (steps, distance, calories)
- 💚 Wellness score (0-100 based on activity, rest, behavior)
- 🚨 Fall detection and emergency alerts
- 🔋 Battery monitoring for both devices

## 🚀 Current Status

**Phase:** Planning & Architecture
**Version:** Pre-release
**Target Launch:** TBD

### What Exists Now
- ✅ Project guidelines ([PAWATCH_GUIDELINES.md](PAWATCH_GUIDELINES.md))
- ✅ UI mockups and icon concepts ([screenshots/](screenshots/))
- ✅ Approved source code for GPS framework (gps-relay-framework v1.0.4)
- ⏳ Implementation (not started)

### Next Steps
1. Fork gps-relay-framework as foundation
2. Strip external relay components (WebSocket, Jetson code)
3. Build iOS pet tracker UI (Liquid Glass design)
4. Implement geofencing and activity tracking
5. Add wellness score algorithm
6. Beta testing with real pets

## 📱 Technology Stack

- **iOS 26+ / watchOS 26+** (Liquid Glass design language)
- **SwiftUI** (100% of UI)
- **Core Location** (GPS tracking)
- **WatchConnectivity** (Watch ↔ iPhone communication)
- **HealthKit** (Activity metrics, workout sessions)
- **CoreMotion** (Fall detection)
- **CoreData** (Local persistence)
- **MapKit** (Location visualization)

## 🏗️ Architecture

```
┌─────────────────────────┐
│   Apple Watch           │
│   (Worn by Pet)         │
│                         │
│   • GPS Capture (0.5s)  │
│   • Activity Tracking   │
│   • Fall Detection      │
│   • Battery Monitoring  │
└────────────┬────────────┘
             │
             │ WatchConnectivity
             │ • Bluetooth: ~1-2Hz
             │ • LTE: ~0.1-0.2Hz
             ↓
┌─────────────────────────┐
│   iPhone                │
│   (Carried by Owner)    │
│                         │
│   • Live Map Display    │
│   • Geofence Processing │
│   • Activity Analysis   │
│   • Wellness Score      │
│   • Notifications       │
└─────────────────────────┘
```

## 📂 Project Structure

```
pawWatch-app/
├── .claude/
│   ├── settings.local.json       # AI assistant configuration
│   └── commands/
│       └── start.md              # Project initialization command
├── screenshots/                   # UI mockups and icons
├── PAWATCH_GUIDELINES.md         # Single source of truth
├── README.md                     # This file
├── DEVELOPMENT.md                # Implementation roadmap
└── (iOS/watchOS project - to be created)
```

## 🎨 Design Language

**iOS 26 Liquid Glass** - Modern, fluid interface with:
- Frosted glass effects
- Fluid animations
- Depth layering
- System color harmony
- Dark mode support

See [screenshots/](screenshots/) for UI mockups.

## 📋 Requirements

### Platform
- iOS 26.0+ (iPhone) - Current: iOS 26.1
- watchOS 26.0+ (Apple Watch Series 4+) - Current: watchOS 26.1
- Xcode 26.0.1+ (Build 17A400)
- Swift 6.2 (with Inline Arrays, Span Type, enhanced concurrency)

### Device Requirements
- iPhone 11+
- Apple Watch Series 4+ (cellular recommended for LTE tracking)
- Watch must be paired to iPhone before attaching to pet

## 📚 Documentation

**Start Here:**
1. **[PAWATCH_GUIDELINES.md](PAWATCH_GUIDELINES.md)** - Complete project definition, goals, and guardrails
2. **[DEVELOPMENT.md](DEVELOPMENT.md)** - Implementation roadmap and timeline

**Reference:**
- **Approved Source:** `/Users/zackjordan/code/jetson/dev/gps-relay-framework` (v1.0.4)
- **GitHub Repo:** https://github.com/stonezone/gps-relay-framework

## 🚦 Getting Started (For AI Assistants)

If you're an AI assistant helping with this project:

1. **Activate Serena:** `mcp__serena__activate_project` with path `/Users/zackjordan/code/pawWatch-app`
2. **Read Guidelines:** PAWATCH_GUIDELINES.md (MANDATORY - contains iOS 26 proof and architecture rules)
3. **Start Command:** Use `/start` to initialize project setup
4. **Follow Roadmap:** DEVELOPMENT.md has the implementation plan

## ⚠️ Critical Rules

### Must Maintain
- ✅ **0.5s GPS throttle minimum** (real-time tracking)
- ✅ **Watch + iPhone only** (no external devices)
- ✅ **iOS 26 Liquid Glass design**
- ✅ **Single-stream architecture** (Watch GPS → iPhone)

### Must Avoid
- ❌ **NO GPS throttle >0.5s** (performance regression)
- ❌ **NO external device integration** (Jetson, servers, etc.)
- ❌ **NO dual-stream architecture** (over-engineered)
- ❌ **NO Robot Cameraman features** (wrong use case)

## 🤝 Contributing

This is a personal project in early development. Contributions will be welcome once the core framework is established.

## 📄 License

TBD (likely MIT to match gps-relay-framework)

## 🙏 Acknowledgments

- Built on the foundation of [gps-relay-framework](https://github.com/stonezone/gps-relay-framework)
- Inspired by the need for affordable, reliable pet tracking solutions
- Designed for pet owners who want peace of mind

---

**Made with ❤️ for pets and their humans**
