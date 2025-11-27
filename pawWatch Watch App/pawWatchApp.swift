//
//  pawWatchApp.swift
//  pawWatch Watch App
//
//  Purpose: Main entry point for the watchOS app using SwiftUI lifecycle.
//           Manages app state transitions and coordinates with WatchLocationProvider.
//  Created: 2025-02-05
//  Updated: 2025-11-05 - Added lifecycle handling for GPS tracking
//

import SwiftUI
import WatchKit

@main
struct pawWatch_Watch_App: App {
    @WKApplicationDelegateAdaptor(PawWatchAppDelegate.self) var appDelegate

    // MARK: - Properties

    /// Scene phase tracking for app lifecycle management.
    /// Monitors transitions between active, inactive, and background states.
    @Environment(\.scenePhase) private var scenePhase

    /// Shared location manager - initialized at app launch
    /// This ensures WatchConnectivity is activated immediately,
    /// allowing the iPhone to detect the Watch app
    /// CRITICAL FIX: Using lazy initialization to prevent recreation
    @State private var locationManager: WatchLocationManager

    init() {
        // Initialize once to prevent recreation during scene phase changes
        _locationManager = State(initialValue: WatchLocationManager())
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView(locationManager: locationManager)
                .task {
                    // Initialize connection status immediately on app launch
                    locationManager.updateConnectionStatus()

                    // Optional: Start tracking automatically if desired
                    // Uncomment the line below to start tracking immediately
                    // await locationManager.startTracking()
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    // MARK: - Lifecycle Methods

    /// Handles app lifecycle transitions for proper resource management.
    ///
    /// State transitions:
    /// - Active: App is in foreground and receiving events
    /// - Inactive: App is transitioning (e.g., system overlay, Siri)
    /// - Background: App is backgrounded but may continue GPS via workout session
    ///
    /// GPS Tracking Notes:
    /// - HealthKit workout session keeps GPS active in background
    /// - WatchConnectivity automatically queues background transfers
    /// - No explicit handling needed - WatchLocationProvider manages it all
    ///
    /// - Parameters:
    ///   - oldPhase: Previous scene phase
    ///   - newPhase: New scene phase
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active (foreground)
            // WatchConnectivity will resume interactive messaging if iPhone reachable
            // GPS continues uninterrupted via workout session
            print("[pawWatch] App became active")

        case .inactive:
            // App became inactive (temporary transition state)
            // Example: Control Center overlay, incoming call UI
            // GPS tracking continues via workout session
            print("[pawWatch] App became inactive")

        case .background:
            // App moved to background
            // HealthKit workout session keeps GPS active
            // WatchConnectivity automatically switches to:
            //   1. Application context (0.5s throttle, latest-only)
            //   2. File transfer (queued delivery, guaranteed)
            // No interactive messaging while backgrounded
            print("[pawWatch] App moved to background")

            // WatchLocationProvider handles all background transitions automatically
            // No manual cleanup or state changes needed here

        @unknown default:
            // Future scene phase states
            print("[pawWatch] Unknown scene phase: \(newPhase)")
            break
        }
    }
}
