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
import OSLog
import pawWatchFeature

private let lifecycleLogger = Logger(subsystem: PawWatchLog.subsystem, category: "WatchLifecycle")

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
    /// Managed by SwiftUI @State to ensure a single instance per app lifecycle.
    @State private var locationManager = WatchLocationManager.shared

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
    /// - We proactively restore state on activation for maximum resilience
    ///
    /// - Parameters:
    ///   - oldPhase: Previous scene phase
    ///   - newPhase: New scene phase
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active (foreground)
            // CRITICAL: Refresh connection status and restore tracking if needed
            lifecycleLogger.notice("App became active; refreshing state")

            // Immediately update connection status to re-establish interactive messaging
            locationManager.updateConnectionStatus()

            // Restore tracking if it was running before (crash recovery / background restart)
            locationManager.restoreTrackingIfNeeded()

        case .inactive:
            // App became inactive (temporary transition state)
            // Example: Control Center overlay, incoming call UI
            // GPS tracking continues via workout session - DO NOT stop
            lifecycleLogger.info("App became inactive; tracking continues")

        case .background:
            // App moved to background
            // CRITICAL: Do NOT stop tracking - HealthKit workout keeps GPS alive
            // WatchConnectivity automatically switches to:
            //   1. Application context (0.5s throttle, latest-only)
            //   2. File transfer (queued delivery, guaranteed)
            // Heartbeat task continues running in background
            lifecycleLogger.info("App moved to background; heartbeat continues")

            // Final connection status update before backgrounding
            locationManager.updateConnectionStatus()

        @unknown default:
            // Future scene phase states
            lifecycleLogger.error("Unknown scene phase: \(String(describing: newPhase), privacy: .public)")
            break
        }
    }
}
