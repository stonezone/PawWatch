# pawWatch Project Overview

## Purpose
pawWatch is a pet tracking application that consists of:
- An iOS app for pet owners to track their pets' location
- A watchOS app that runs on an Apple Watch worn by the pet
- Real-time GPS tracking using Watch's native GPS
- Location relay from Watch to iPhone via WatchConnectivity

## Tech Stack
- **Language**: Swift 6.2
- **UI Framework**: SwiftUI (modern @Observable macro pattern)
- **Target Platforms**: iOS 18.4 (attempting to move to 26.0), watchOS 11.0
- **Architecture**: Workspace + SPM Package structure
- **Package Manager**: Swift Package Manager (SPM)
- **Build Tool**: XcodeGen (project.yml)
- **Configuration**: XCConfig files for build settings

## Key Components
1. **Main iOS App** (`pawWatch/`): Minimal app shell with entry point
2. **Watch App** (`pawWatch Watch App/`): Standalone watchOS application
3. **Shared Feature Module** (`pawWatchPackage/`): SPM package with shared code
4. **Configuration** (`Config/`): XCConfig files and entitlements

## Features
- Real-time GPS tracking via Apple Watch
- HealthKit workout session for background GPS
- WatchConnectivity for Watch-to-iPhone data relay
- Location visualization with MapKit
- Battery and accuracy monitoring
- Background tracking support

## Development Tools
- Xcode 16.3
- Swift 6.2
- iOS 26.0 deployment target (attempted)
- watchOS 11.0 deployment target