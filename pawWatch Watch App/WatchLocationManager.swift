//
//  WatchLocationManager.swift
//  pawWatch Watch App
//
//  Purpose: Manages GPS tracking using WatchLocationProvider and relays location data to iPhone.
//  Created: 2025-02-05
//  Updated: 2025-11-05 - Extracted from ContentView.swift
//

import SwiftUI
import Observation
import WatchKit
import CoreLocation
import pawWatchFeature

/// Manages GPS tracking using WatchLocationProvider and relays location data to iPhone.
///
/// Responsibilities:
/// - Interface with WatchLocationProvider for GPS capture
/// - Maintain HealthKit workout session for background tracking
/// - Handle WatchConnectivity session state
/// - Update UI with real-time location data
/// - Provide user-friendly error messages
///
/// Uses Swift 6.2 @Observable macro for modern SwiftUI state management.
/// All state updates occur on MainActor for thread-safe UI updates.
@MainActor
@Observable
final class WatchLocationManager: WatchLocationProviderDelegate {

    // MARK: - Properties

    /// The underlying GPS provider managing workout and location capture
    private let locationProvider = WatchLocationProvider()

    /// Whether GPS tracking is currently active
    var isTracking: Bool = false

    /// Latest location fix received from GPS
    var currentFix: LocationFix?

    /// Rolling in-memory history of recent fixes (most recent first)
    var recentFixes: [LocationFix] = []
    private let maxRecentFixesHistory = 12

    /// User-friendly status message for display
    var statusMessage: String = "Ready to track"

    /// Current WatchConnectivity session state
    var connectionStatus: String = "Checking..."

    /// Whether the iPhone is reachable for interactive messaging
    var isPhoneReachable: Bool = false

    /// Last error message (nil if no error)
    var errorMessage: String?

    /// Tracks number of GPS fixes received (for update frequency calculation)
    private var fixCount: Int = 0

    /// Snapshot of GPS latency (average, ms)
    var gpsLatencyAverageMS: Double = 0

    /// Snapshot of GPS latency (p95, ms)
    var gpsLatencyP95MS: Double = 0

    /// Snapshot of smoothed battery drain per hour (%/hr)
    var batteryDrainPerHour: Double = 0
    /// Most recent instantaneous drain reading (%/hr)
    var batteryDrainPerHourInstant: Double = 0

    /// Cached snapshot so we can update reachability without new samples
    private var lastSavedSnapshot: PerformanceSnapshot?

    /// Whether adaptive battery optimizations are enabled.
    private var batteryOptimizationsEnabled = true

    /// Timestamp of first fix (for update frequency calculation)
    private var firstFixTime: Date?

    /// Computed update frequency in Hz (fixes per second)
    var updateFrequency: Double {
        guard let firstFixTime, fixCount > 1 else { return 0.0 }
        let elapsed = Date().timeIntervalSince(firstFixTime)
        guard elapsed > 0 else { return 0.0 }
        return Double(fixCount) / elapsed
    }

    // MARK: - Initialization

    private let performanceMonitor = PerformanceMonitor.shared

    init() {
        // Set ourselves as delegate to receive GPS fixes and errors
        locationProvider.delegate = self
        locationProvider.setBatteryOptimizationsEnabled(batteryOptimizationsEnabled)
    }

    // MARK: - Public Methods

    /// Starts GPS tracking using WatchLocationProvider.
    ///
    /// This initiates:
    /// 1. HealthKit workout session for background GPS access
    /// 2. CoreLocation high-frequency updates (~1Hz native Watch GPS)
    /// 3. WatchConnectivity session for iPhone relay
    /// 4. Triple-path messaging (interactive, context, file transfer)
    ///
    /// The 0.5s application context throttle allows ~2Hz max relay rate
    /// while capturing all 1Hz Watch GPS fixes.
    func startTracking() {
        print("[WatchLocationManager] Starting GPS tracking")

        isTracking = true
        statusMessage = "Starting workout..."
        errorMessage = nil
        fixCount = 0
        firstFixTime = nil

        // Start workout session and GPS streaming
        // Uses .other activity type for maximum update frequency
        locationProvider.startWorkoutAndStreaming(activity: .other)

        // 🔍 DIAGNOSTIC: Check WCSession state after activation
        diagnosePairingState()

        statusMessage = "Acquiring GPS..."
    }

    /// Stops GPS tracking and ends the workout session.
    ///
    /// Cleans up:
    /// - CoreLocation updates
    /// - HealthKit workout session
    /// - Application context throttle state
    /// - Active file transfers
    func stopTracking() {
        print("[WatchLocationManager] Stopping GPS tracking")

        isTracking = false
        statusMessage = "Stopping..."

        locationProvider.stop()

        statusMessage = "Tracking stopped"
        currentFix = nil
        fixCount = 0
        firstFixTime = nil
        gpsLatencyAverageMS = 0
        gpsLatencyP95MS = 0
        batteryDrainPerHour = 0
    }

    /// Convenience helper to restart the workout/session flow.
    func restartTracking() {
        stopTracking()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            startTracking()
        }
    }

    /// Updates whether runtime guard + motion throttling should be active.
    func setBatteryOptimizationsEnabled(_ enabled: Bool) {
        batteryOptimizationsEnabled = enabled
        locationProvider.setBatteryOptimizationsEnabled(enabled)
    }

    /// Broadcasts tracker lock state to the paired phone.
    func updateLockState(_ isLocked: Bool) {
        locationProvider.setTrackerLocked(isLocked)
    }

    // MARK: - WatchLocationProviderDelegate

    /// Called when a new GPS location fix is produced.
    ///
    /// This is called at ~1Hz (native Watch GPS rate) and the fix is
    /// automatically relayed to iPhone via triple-path WatchConnectivity:
    /// 1. Application context (0.5s throttle, latest-only, works in background)
    /// 2. Interactive message (if phone reachable, immediate delivery)
    /// 3. File transfer (background queue, guaranteed delivery)
    ///
    /// - Parameter fix: The location fix containing GPS data and metadata
    func didProduce(_ fix: LocationFix) {
        print("[WatchLocationManager] Received GPS fix #\(fix.sequence)")

        // Update state with latest fix
        currentFix = fix

        // Refresh history and trim to capacity
        if recentFixes.first?.sequence != fix.sequence {
            recentFixes.insert(fix, at: 0)
            if recentFixes.count > maxRecentFixesHistory {
                recentFixes.removeLast(recentFixes.count - maxRecentFixesHistory)
            }
        }

        // Track frequency metrics
        fixCount += 1
        if firstFixTime == nil {
            firstFixTime = Date()
        }

        // Update status with coordinate info
        let lat = String(format: "%.6f", fix.coordinate.latitude)
        let lon = String(format: "%.6f", fix.coordinate.longitude)
        let accuracy = String(format: "%.1f", fix.horizontalAccuracyMeters)
        statusMessage = "GPS: \(lat), \(lon) (±\(accuracy)m)"

        // Clear any previous errors on successful fix
        errorMessage = nil

        refreshPerformanceSnapshot()
    }

    private func refreshPerformanceSnapshot() {
        gpsLatencyAverageMS = performanceMonitor.gpsAverage * 1000
        gpsLatencyP95MS = performanceMonitor.gpsP95 * 1000
        batteryDrainPerHour = performanceMonitor.batteryDrainPerHourSmoothed
        batteryDrainPerHourInstant = performanceMonitor.batteryDrainPerHourInstant

        let hasMetrics = gpsLatencyAverageMS > 0 || gpsLatencyP95MS > 0 || batteryDrainPerHour != 0 || lastSavedSnapshot != nil
        guard hasMetrics else { return }

        var latency = Int(gpsLatencyAverageMS.rounded())
        if latency <= 0, let last = lastSavedSnapshot {
            latency = last.latencyMs
        }

        var drain = batteryDrainPerHour
        if abs(drain) < 0.01, let last = lastSavedSnapshot {
            drain = last.batteryDrainPerHour
        }

        var instant = batteryDrainPerHourInstant
        if instant <= 0, let last = lastSavedSnapshot {
            instant = last.instantBatteryDrainPerHour
        }

        let snapshot = PerformanceSnapshot(
            latencyMs: max(1, latency),
            batteryDrainPerHour: drain,
            instantBatteryDrainPerHour: max(0, instant),
            reachable: isPhoneReachable,
            timestamp: Date()
        )
        lastSavedSnapshot = snapshot
        _ = PerformanceSnapshotStore.save(snapshot)
    }

    /// Called when an error occurs during location capture or relay.
    ///
    /// Errors can occur from:
    /// - CoreLocation (GPS unavailable, permission denied)
    /// - HealthKit (workout session failure)
    /// - WatchConnectivity (relay failures are non-fatal)
    ///
    /// - Parameter error: The error that occurred
    func didFail(_ error: Error) {
        print("[WatchLocationManager] Error: \(error.localizedDescription)")

        // Convert error to user-friendly message
        let friendlyMessage: String
        if let connectivity = error as? WatchConnectivityIssue {
            switch connectivity {
            case .sessionNotActivated:
                friendlyMessage = "Waiting for iPhone session to activate…"
            case .interactiveSendFailed:
                friendlyMessage = "Live update failed; retrying soon."
            case .fileEncodingFailed:
                friendlyMessage = "Unable to queue update; will retry."
            case .fileTransferFailed:
                friendlyMessage = "Background transfer failed; retrying."
            case .locationAuthorizationDenied:
                friendlyMessage = "Location permission required. Enable in Settings."
            }
        } else if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                friendlyMessage = "Location access denied. Check Settings."
            case .locationUnknown:
                friendlyMessage = "Unable to determine location. Try moving to an area with clear sky view."
            default:
                friendlyMessage = "GPS error: \(clError.localizedDescription)"
            }
        } else if error.localizedDescription.contains("workout") {
            friendlyMessage = "Workout session error. Try restarting the app."
        } else {
            friendlyMessage = "Error: \(error.localizedDescription)"
        }

        errorMessage = friendlyMessage
        statusMessage = "Error occurred"
    }

    func didReceiveRemoteStop() {
        if isTracking {
            stopTracking()
        }
        WKInterfaceDevice.current().play(.success)
        statusMessage = "Tracking stopped remotely"
    }

    func didUpdateReachability(_ isReachable: Bool) {
        isPhoneReachable = isReachable
        updateConnectionStatus()
    }

    // MARK: - Private Methods

    /// Updates connection status display based on WCSession state.
    /// Only checks status after session has been activated by WatchLocationProvider.
    func updateConnectionStatus() {
        isPhoneReachable = locationProvider.isReachable
        connectionStatus = isPhoneReachable ? "iPhone Connected" : "iPhone Unreachable"

        if !locationProvider.isCompanionAppInstalled {
            statusMessage = "Install or launch pawWatch on iPhone"
        } else if isTracking, !isPhoneReachable, currentFix == nil {
            statusMessage = "Waiting for iPhone to connect…"
        }

        refreshPerformanceSnapshot()
    }

    /// 🔍 DIAGNOSTIC: Comprehensive WCSession state diagnosis
    /// Prints detailed pairing information to help troubleshoot connectivity issues
    private func diagnosePairingState() {
        print("\n" + String(repeating: "=", count: 60))
        print("🔍 WATCH: Connectivity Diagnostic Report")
        print(String(repeating: "=", count: 60))

        print("🔗 Connection Status:")
        print("   isCompanionAppInstalled: \(locationProvider.isCompanionAppInstalled ? "✅ YES - iPhone app detected" : "❌ NO - iPhone app NOT detected")")
        print("   isReachable: \(locationProvider.isReachable ? "✅ YES - Can send messages now" : "⚠️  NO - Phone sleeping or app backgrounded")")

        // Critical error conditions
        if !locationProvider.isCompanionAppInstalled {
            print("\n❌ CRITICAL ERROR: iPhone app not detected by WatchConnectivity")
            print("   → This is the most common issue!")
            print("   → Solution: Delete BOTH apps, clean build, reinstall iOS app FIRST, then Watch app")
        }

        if !locationProvider.isReachable && locationProvider.isCompanionAppInstalled {
            print("\n⚠️  WARNING: iPhone app installed but unreachable")
            print("   → iPhone might be locked or app backgrounded")
            print("   → Try: Wake iPhone → Open pawWatch app → Then start Watch tracking")
        }

        print(String(repeating: "=", count: 60))
        print("End Diagnostic Report\n")
    }
}
