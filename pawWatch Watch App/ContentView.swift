//
//  ContentView.swift
//  pawWatch Watch App
//
//  Purpose: Main view for the watchOS app displaying pet tracking interface
//           with integrated WatchLocationProvider for GPS tracking and relay.
//  Created: 2025-02-05
//  Updated: 2025-11-05 - Integrated WatchLocationProvider
//

import SwiftUI
import WatchKit
@preconcurrency import WatchConnectivity
import CoreLocation
import pawWatchFeature

// MARK: - Watch Location Manager

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
        if let clError = error as? CLError {
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

    // MARK: - Private Methods

    /// Updates connection status display based on WCSession state.
    /// Only checks status after session has been activated by WatchLocationProvider.
    func updateConnectionStatus() {
        guard WCSession.isSupported() else {
            connectionStatus = "Not supported"
            isPhoneReachable = false
            return
        }

        let session = WCSession.default
        
        // Don't access session properties until it's been activated
        // This prevents crashes when session is accessed too early
        guard session.activationState != .notActivated else {
            connectionStatus = "Initializing..."
            isPhoneReachable = false
            return
        }
        
        let activationState: String
        switch session.activationState {
        case .notActivated:
            activationState = "Not Active"
        case .inactive:
            activationState = "Inactive"
        case .activated:
            activationState = "Active"
        @unknown default:
            activationState = "Unknown"
        }

        isPhoneReachable = session.isReachable

        if session.activationState == .activated {
            connectionStatus = isPhoneReachable ? "iPhone Connected" : "iPhone Unreachable"
        } else {
            connectionStatus = activationState
        }
    }
}

// MARK: - Content View

/// Main view for the watchOS app displaying pet tracking interface.
///
/// Features:
/// - Real-time GPS coordinate display
/// - Horizontal accuracy visualization
/// - Battery level indicator
/// - WatchConnectivity status
/// - Update frequency display (actual Hz)
/// - Start/Stop tracking controls
///
/// Uses @Observable WatchLocationManager for modern SwiftUI state management.
@MainActor
struct ContentView: View {

    // MARK: - State Properties

    /// Location manager handling GPS tracking and phone relay
    @State private var locationManager = WatchLocationManager()
    @AppStorage("watchBatteryOptimizationsEnabled") private var batteryOptimizationsEnabled = true
    @State private var isTrackerLocked = false
    @State private var crownRotation: Double = 0
    @State private var crownRotationAccumulator: Double = 0
    @State private var lockEngagedAt: Date?

    private let unlockRotationThreshold = 1.75  // roughly one and a half turns

    // MARK: - Body

    var body: some View {
        ZStack {
            mainContent
                .blur(radius: isTrackerLocked ? 4 : 0)
                .disabled(isTrackerLocked)

            if isTrackerLocked {
                lockOverlay
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isTrackerLocked)
        .onAppear {
            locationManager.setBatteryOptimizationsEnabled(batteryOptimizationsEnabled)
        }
        .onChange(of: batteryOptimizationsEnabled) { _, newValue in
            locationManager.setBatteryOptimizationsEnabled(newValue)
        }
        .onChange(of: locationManager.isTracking) { _, newValue in
            if !newValue {
                disengageLock()
            }
        }
    }

    private var mainContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {

                    // MARK: - App Title

                    Text("pawWatch")
                        .font(.title3)
                        .fontWeight(.bold)

                    // MARK: - GPS Status Icon

                    Image(systemName: locationManager.isTracking ? "location.fill" : "location.slash")
                        .font(.system(size: 50))
                        .foregroundStyle(locationManager.isTracking ? .green : .secondary)
                        .symbolEffect(.pulse, isActive: locationManager.isTracking)

                    // MARK: - Status Message

                    Text(locationManager.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)

                    // MARK: - Error Message (if present)

                    if let errorMessage = locationManager.errorMessage {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)

                        Button("Restart Workout") {
                            locationManager.restartTracking()
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }

                    // MARK: - GPS Details (when tracking)

                    if locationManager.isTracking, let fix = locationManager.currentFix {
                        VStack(spacing: 8) {

                            // Coordinates
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.caption2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Lat: \(fix.coordinate.latitude, specifier: "%.6f")")
                                        .font(.caption2)
                                        .monospaced()
                                    Text("Lon: \(fix.coordinate.longitude, specifier: "%.6f")")
                                        .font(.caption2)
                                        .monospaced()
                                }
                            }
                            .foregroundStyle(.secondary)

                            // Accuracy
                            HStack(spacing: 4) {
                                Image(systemName: "scope")
                                    .font(.caption2)
                                Text("Accuracy: ±\(fix.horizontalAccuracyMeters, specifier: "%.1f")m")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)

                            // Accuracy visualization (circle size relative to accuracy)
                            Circle()
                                .stroke(
                                    accuracyColor(for: fix.horizontalAccuracyMeters),
                                    lineWidth: 2
                                )
                                .frame(width: accuracyCircleSize(for: fix.horizontalAccuracyMeters))
                                .overlay {
                                    Circle()
                                        .fill(accuracyColor(for: fix.horizontalAccuracyMeters).opacity(0.2))
                                }

                            // Speed
                            HStack(spacing: 4) {
                                Image(systemName: "speedometer")
                                    .font(.caption2)
                                Text("Speed: \(fix.speedMetersPerSecond * 3.6, specifier: "%.1f") km/h")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)

                            // Altitude (if available)
                            if let altitude = fix.altitudeMeters {
                                HStack(spacing: 4) {
                                    Image(systemName: "mountain.2")
                                        .font(.caption2)
                                    Text("Altitude: \(altitude, specifier: "%.0f")m")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.secondary)
                            }

                            // Battery
                            HStack(spacing: 4) {
                                Image(systemName: batteryIcon(for: fix.batteryFraction))
                                    .font(.caption2)
                                Text("Battery: \(fix.batteryFraction * 100, specifier: "%.0f")%")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)

                            // Update frequency
                            HStack(spacing: 4) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.caption2)
                                Text("Update: \(locationManager.updateFrequency, specifier: "%.2f") Hz")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }

                    // MARK: - Connection Status

                    HStack(spacing: 4) {
                        Image(systemName: locationManager.isPhoneReachable ? "iphone.radiowaves.left.and.right" : "iphone.slash")
                            .font(.caption2)
                        Text(locationManager.connectionStatus)
                            .font(.caption2)
                    }
                    .foregroundStyle(locationManager.isPhoneReachable ? .green : .orange)
                    .padding(.top, 4)

                    // MARK: - Tracking Control Button

                    Button(action: toggleTracking) {
                        Label(
                            locationManager.isTracking ? "Stop Tracking" : "Start Tracking",
                            systemImage: locationManager.isTracking ? "stop.fill" : "play.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(locationManager.isTracking ? .red : .green)
                    .padding(.top, 8)

                    if locationManager.isTracking, !isTrackerLocked {
                        Button {
                            engageLockMode()
                        } label: {
                            Label("Lock Tracker", systemImage: "lock.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }

                    NavigationLink {
                        WatchSettingsView(optimizationsEnabled: $batteryOptimizationsEnabled)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical)
            }
            .navigationTitle("Pet Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Poll WatchConnectivity status periodically
                while !Task.isCancelled {
                    locationManager.updateConnectionStatus()
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        }
    }

    // MARK: - Actions

    /// Toggles GPS tracking on/off.
    ///
    /// When starting:
    /// - Initiates HealthKit workout session
    /// - Starts CoreLocation GPS updates (~1Hz)
    /// - Activates WatchConnectivity relay to iPhone
    ///
    /// When stopping:
    /// - Ends workout session
    /// - Stops GPS updates
    /// - Cleans up WatchConnectivity state
    private func toggleTracking() {
        if locationManager.isTracking {
            locationManager.stopTracking()
            disengageLock()
        } else {
            locationManager.startTracking()
        }
    }

    private func engageLockMode() {
        guard locationManager.isTracking else { return }
        isTrackerLocked = true
        lockEngagedAt = Date()
        crownRotation = 0
        crownRotationAccumulator = 0
        WKInterfaceDevice.current().play(.click)
    }

    private func disengageLock() {
        if isTrackerLocked {
            WKInterfaceDevice.current().play(.success)
        }
        isTrackerLocked = false
        lockEngagedAt = nil
        crownRotation = 0
        crownRotationAccumulator = 0
    }

    // MARK: - Helper Methods

    /// Determines color for accuracy visualization based on accuracy value.
    ///
    /// - Parameter accuracy: Horizontal accuracy in meters
    /// - Returns: Color indicating accuracy quality (green=good, yellow=fair, red=poor)
    private func accuracyColor(for accuracy: Double) -> Color {
        switch accuracy {
        case 0..<10:
            return .green  // Excellent accuracy (<10m)
        case 10..<25:
            return .yellow  // Good accuracy (10-25m)
        default:
            return .red  // Poor accuracy (>25m)
        }
    }

    /// Calculates circle size for accuracy visualization.
    ///
    /// Maps accuracy to visual size:
    /// - <10m: Small circle (20pt)
    /// - 10-25m: Medium circle (30pt)
    /// - >25m: Large circle (40pt)
    ///
    /// - Parameter accuracy: Horizontal accuracy in meters
    /// - Returns: Circle diameter in points
    private func accuracyCircleSize(for accuracy: Double) -> CGFloat {
        switch accuracy {
        case 0..<10:
            return 20  // Small circle for excellent accuracy
        case 10..<25:
            return 30  // Medium circle for good accuracy
        default:
            return 40  // Large circle for poor accuracy
        }
    }

    /// Selects appropriate battery icon based on battery level.
    ///
    /// - Parameter batteryLevel: Battery level as fraction (0.0-1.0)
    /// - Returns: SF Symbol name for battery icon
    private func batteryIcon(for batteryLevel: Double) -> String {
        let percentage = batteryLevel * 100
        switch percentage {
        case 75...100:
            return "battery.100"
        case 50..<75:
            return "battery.75"
        case 25..<50:
            return "battery.50"
        case 10..<25:
            return "battery.25"
        default:
            return "battery.0"
        }
    }
}

// MARK: - Lock Overlay

private extension ContentView {
    var lockOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(.cyan)

            Text("Tracker Locked")
                .font(.headline)

            Text("Rotate the Digital Crown to unlock. Tracking stays active while locked.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let lockEngagedAt {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text("Locked for \(formattedLockDuration(since: lockEngagedAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button(role: .destructive) {
                locationManager.stopTracking()
                disengageLock()
            } label: {
                Label("Emergency Stop", systemImage: "exclamationmark.triangle")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding()
        .digitalCrownRotation(
            $crownRotation,
            from: -10,
            through: 10,
            by: 0.1,
            sensitivity: .medium,
            isContinuous: true,
            isHapticFeedbackEnabled: true
        )
        .focusable(true)
        .onChange(of: crownRotation) { oldValue, newValue in
            let delta = newValue - oldValue
            crownRotationAccumulator += delta

            if abs(crownRotationAccumulator) >= unlockRotationThreshold {
                disengageLock()
            }
        }
    }

    func formattedLockDuration(since date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 {
            return "\(Int(elapsed))s"
        }
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%dm %02ds", minutes, seconds)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

// MARK: - Settings View

private struct WatchSettingsView: View {
    @Binding var optimizationsEnabled: Bool

    var body: some View {
        Form {
            Section("Battery") {
                Toggle("Runtime Guard & Smart Polling", isOn: $optimizationsEnabled)
                Text("Keeps the workout alive with WKExtendedRuntimeSession and slows GPS when stationary or low battery.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}
