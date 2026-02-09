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
import Observation
import WatchKit
import CoreLocation
import ImageIO
import pawWatchFeature

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
    /// Passed in from the App level to ensure immediate WatchConnectivity initialization
    let locationManager: WatchLocationManager
    @AppStorage(RuntimePreferenceKey.runtimeOptimizationsEnabled) private var batteryOptimizationsEnabled = true
    @AppStorage("watchAutoLockEnabled") private var autoLockEnabled = true
    @State private var isTrackerLocked = false
    @State private var crownRotation: Double = 0
    @State private var crownRotationAccumulator: Double = 0
    @State private var lockEngagedAt: Date?
    @State private var showSettings = false
    @FocusState private var lockOverlayFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PetProfileStore.self) private var petProfileStore
    @State private var showEmergencyStopConfirmation = false
    @State private var showTelemetry = false
    @State private var hasEverHadFix = false
    @State private var previousAccuracyLevel: AccuracyLevel = .unknown

    private let unlockRotationThreshold = 1.25  // P2-08: reduced from 1.75 to match Apple's Water Lock

    // P1-04: GPS accuracy levels for degradation alerts
    enum AccuracyLevel: Comparable {
        case unknown
        case excellent    // <20m
        case good         // 20-50m
        case fair         // 50-100m
        case poor         // 100-200m
        case critical     // >200m

        init(accuracy: Double) {
            switch accuracy {
            case 0..<20: self = .excellent
            case 20..<50: self = .good
            case 50..<100: self = .fair
            case 100..<200: self = .poor
            default: self = .critical
            }
        }

        var warningText: String? {
            switch self {
            case .poor: return "GPS signal poor — location may be inaccurate"
            case .critical: return "GPS signal critical — location unreliable"
            default: return nil
            }
        }

        var warningColor: Color {
            switch self {
            case .poor: return .orange
            case .critical: return .red
            default: return .secondary
            }
        }
    }

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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isTrackerLocked)
        .onAppear {
            locationManager.setBatteryOptimizationsEnabled(batteryOptimizationsEnabled)
            locationManager.restoreState()
            locationManager.updateConnectionStatus()
        }
        .onChange(of: batteryOptimizationsEnabled) { _, newValue in
            locationManager.setBatteryOptimizationsEnabled(newValue)
        }
        .onChange(of: locationManager.isTracking) { _, newValue in
            if !newValue {
                disengageLock()
            }
        }
        .onChange(of: isTrackerLocked) { _, locked in
            if locked {
                resetCrownTracking()
                lockOverlayFocused = true
            } else {
                lockOverlayFocused = false
                resetCrownTracking()
            }
        }
        .onChange(of: locationManager.currentFix) { _, newFix in
            // P1-05: Track if we've ever had a fix to differentiate "acquiring" vs "lost"
            if newFix != nil {
                hasEverHadFix = true
            }

            // P1-04: Monitor GPS accuracy degradation
            if let fix = newFix {
                let newLevel = AccuracyLevel(accuracy: fix.horizontalAccuracyMeters)
                if newLevel >= .poor && previousAccuracyLevel < .poor {
                    // Transitioned to poor or critical accuracy
                    WKInterfaceDevice.current().play(.notification)
                }
                previousAccuracyLevel = newLevel
            }
        }
    }

    private var mainContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {

                    // MARK: - P1-01: Compact Pet Header (Critical Info First)

                    if shouldShowPetHeader {
                        HStack(spacing: Spacing.sm) {
                            if let avatar = petAvatarCGImage {
                                Image(decorative: avatar, scale: 1.0)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "pawprint.fill")
                                    .font(.caption)
                                    .foregroundStyle(.cyan)
                            }

                            Text(petDisplayName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)

                            Spacer(minLength: 0)
                        }
                    }

                    // MARK: - P1-01: GPS Details FIRST (Critical for Pet Safety)

                    if locationManager.isTracking, let fix = locationManager.currentFix {
                        VStack(spacing: Spacing.sm) {

                            // P1-04: GPS Accuracy Warning Banner (Critical)
                            let accuracyLevel = AccuracyLevel(accuracy: fix.horizontalAccuracyMeters)
                            if let warningText = accuracyLevel.warningText {
                                HStack(spacing: Spacing.xxs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                    Text(warningText)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(accuracyLevel.warningColor)
                                .padding(.vertical, Spacing.xxs)
                                .padding(.horizontal, Spacing.xs)
                                .background(accuracyLevel.warningColor.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            HStack(spacing: Spacing.xxs) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text("Updated: \(timeSinceFix(fix.timestamp))")
                                    .font(.caption2)
                                Spacer()
                                Text("±\(fix.horizontalAccuracyMeters, specifier: "%.1f")m")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(accuracyColor(for: fix.horizontalAccuracyMeters))
                            }
                            .foregroundStyle(.secondary)

                            HStack(spacing: Spacing.xxs) {
                                Image(systemName: batteryIcon(for: fix.batteryFraction))
                                    .font(.caption2)
                                Text("Battery: \(fix.batteryFraction * 100, specifier: "%.0f")%")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showTelemetry.toggle()
                                }
                            } label: {
                                Label(showTelemetry ? "Hide Telemetry" : "Show Telemetry", systemImage: "waveform.path.ecg")
                                    .font(.caption2)
                            }
                            .buttonStyle(.bordered)

                            if showTelemetry {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text("Lat: \(fix.coordinate.latitude, specifier: "%.6f")")
                                        .font(.caption2.monospaced())
                                    Text("Lon: \(fix.coordinate.longitude, specifier: "%.6f")")
                                        .font(.caption2.monospaced())
                                    Text("Speed: \(fix.speedMetersPerSecond * 3.6, specifier: "%.1f") km/h")
                                        .font(.caption2)
                                    if let altitude = fix.altitudeMeters {
                                        Text("Altitude: \(altitude, specifier: "%.0f")m")
                                            .font(.caption2)
                                    }
                                    Text("Update: \(locationManager.updateFrequency, specifier: "%.2f") Hz")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, Spacing.xxxs)
                            }
                        }
                        .padding(.vertical, Spacing.sm)
                    } else if locationManager.isTracking {
                        // P1-05: Enhanced GPS Loss State
                        VStack(spacing: Spacing.xs) {
                            if hasEverHadFix {
                                // GPS was working but is now lost
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.orange)

                                Text("GPS signal lost")
                                    .font(.caption)
                                    .fontWeight(.semibold)

                                Text("Move to an open area for better signal")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            } else {
                                // Still acquiring initial GPS lock
                                ProgressView()
                                    .tint(.cyan)

                                Text("Acquiring GPS signal...")
                                    .font(.caption)
                                    .fontWeight(.semibold)

                                Text("Move to an open area for better signal")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.vertical, Spacing.md)
                    }

                    // MARK: - P2-07: History Link (Moved Up for Accessibility)

                    if locationManager.isTracking || locationManager.gpsLatencyAverageMS > 0 {
                        NavigationLink {
                            RadialHistoryGlanceView(manager: locationManager)
                        } label: {
                            Label("History", systemImage: "clock.arrow.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("History")
                        .accessibilityHint("View recent GPS location fixes")
                    }

                    // MARK: - P1-01: GPS Status Icon (Moved Below Critical Data)
                    // P3-08: Removed glass effect from decorative icon to reduce visual noise

                    if #available(watchOS 26, *) {
                        ZStack {
                            Circle()
                                .fill(locationManager.isTracking ? Color.green.opacity(Opacity.xlow) : Color.secondary.opacity(0.1))
                                .frame(width: 50, height: 50)

                            if reduceMotion {
                                Image(systemName: locationManager.isTracking ? "location.fill" : "location.slash")
                                    .font(.system(size: 24))
                                    .foregroundStyle(locationManager.isTracking ? AnyShapeStyle(.green.gradient) : AnyShapeStyle(.secondary))
                            } else {
                                Image(systemName: locationManager.isTracking ? "location.fill" : "location.slash")
                                    .font(.system(size: 24))
                                    .foregroundStyle(locationManager.isTracking ? AnyShapeStyle(.green.gradient) : AnyShapeStyle(.secondary))
                                    .symbolEffect(.bounce.byLayer, value: locationManager.isTracking)
                            }
                        }
                    } else {
                        Image(systemName: locationManager.isTracking ? "location.fill" : "location.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(locationManager.isTracking ? .green : .secondary)
                            .symbolEffect(.pulse, isActive: locationManager.isTracking && !reduceMotion)
                    }

                    // MARK: - Status Message
                    // P3-08: Primary glass effect for main status pill
                    GlassPill {
                        Text(locationManager.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.primary)  // P3-08: Increased contrast
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }

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
                        .accessibilityLabel("Restart workout")
                        .accessibilityHint("Restart the tracking workout session to recover from an error")
                    }

                    metricsSection

                    reachabilityPill
                        .padding(.top, Spacing.xxs)

                    // MARK: - Tracking Control Button

                    Button(action: toggleTracking) {
                        Label(
                            locationManager.isTracking ? "Stop Tracking" : "Start Tracking",
                            systemImage: locationManager.isTracking ? "stop.fill" : "play.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(locationManager.isTracking ? .red : .green)
                    .padding(.top, Spacing.sm)
                    .accessibilityLabel(locationManager.isTracking ? "Stop tracking" : "Start tracking")
                    .accessibilityHint(locationManager.isTracking ? "Stop GPS tracking and end workout session" : "Begin GPS tracking with workout session")

                    if locationManager.isTracking, !isTrackerLocked {
                        Button {
                            engageLockMode()
                        } label: {
                            Label("Lock Tracker", systemImage: "lock.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        .accessibilityLabel("Lock tracker")
                        .accessibilityHint("Lock the tracker to prevent accidental screen interactions during tracking")
                    }

                    NavigationLink {
                        WatchSettingsView(
                            optimizationsEnabled: $batteryOptimizationsEnabled,
                            autoLockEnabled: $autoLockEnabled
                        )
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Open watch app settings")
                }
                .padding(.vertical)
            }
            .navigationTitle("Pet Tracker")
            .navigationBarTitleDisplayMode(.inline)
        }
        .background(WatchGlassBackground())
    }

    // MARK: - Derived Views

    @ViewBuilder
    private var metricsSection: some View {
        if locationManager.isTracking || locationManager.gpsLatencyAverageMS > 0 {
            VStack(spacing: Spacing.xs) {
                // P3-08: Removed glass effects from secondary metric tiles to reduce visual noise
                HStack(spacing: Spacing.xs) {
                    MetricTile(
                        icon: "waveform.path",
                        title: "GPS Latency",
                        value: formattedLatency(locationManager.gpsLatencyAverageMS),
                        subtitle: "p95 \(formattedLatency(locationManager.gpsLatencyP95MS))",
                        tint: .mint
                    )
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.sm))
                    .frame(maxWidth: .infinity)

                    MetricTile(
                        icon: "bolt.fill",
                        title: "Drain / hr",
                        value: formattedDrain(locationManager.batteryDrainPerHour),
                        subtitle: "Inst " + formattedDrain(locationManager.batteryDrainPerHourInstant) +
                            " · " + (batteryOptimizationsEnabled ? "Optimized" : "Performance"),
                        tint: batteryOptimizationsEnabled ? .green : .orange
                    )
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.sm))
                    .frame(maxWidth: .infinity)
                }
            }
            .transition(.opacity.combined(with: .scale))
        }
    }

    // P3-08: Removed glass effect from reachability to reduce visual noise
    private var reachabilityPill: some View {
        MetricTile(
            icon: locationManager.isPhoneReachable ? "iphone.radiowaves.left.and.right" : "iphone.slash",
            title: "Reachability",
            value: locationManager.isPhoneReachable ? "Reachable" : "Offline",
            subtitle: locationManager.connectionStatus,
            tint: locationManager.isPhoneReachable ? .green : .orange
        )
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.sm))
    }

    // P3-08: Removed glass effect from Smart Stack hint to reduce visual noise
    private var smartStackHint: some View {
        SmartStackHintView(
            latency: formattedLatency(locationManager.gpsLatencyAverageMS),
            drain: formattedDrain(locationManager.batteryDrainPerHour)
        )
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.sm))
    }

    // MARK: - Actions

    private func formattedLatency(_ value: Double) -> String {
        guard value.isFinite, value > 1 else { return "—" }
        return String(format: "%.0f ms", value)
    }

    private func formattedDrain(_ value: Double) -> String {
        guard value.isFinite, abs(value) > 0.05 else { return "—" }
        let clamped = max(-25, min(25, value))
        return String(format: "%.1f%%/h", clamped)
    }

    private func timeSinceFix(_ timestamp: Date) -> String {
        let elapsed = Date().timeIntervalSince(timestamp)
        if elapsed < 5 {
            return "just now"
        } else if elapsed < 60 {
            return "\(Int(elapsed))s ago"
        } else if elapsed < 3600 {
            let minutes = Int(elapsed) / 60
            return "\(minutes)m ago"
        } else {
            let hours = Int(elapsed) / 3600
            let minutes = (Int(elapsed) % 3600) / 60
            return "\(hours)h \(minutes)m ago"
        }
    }

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
            // P1-03: Haptic feedback on stop
            WKInterfaceDevice.current().play(.stop)
            disengageLock()
        } else {
            // P1-03: Haptic feedback on start
            WKInterfaceDevice.current().play(.start)
            locationManager.startTracking()
            // Auto-engage lock mode when tracking starts (like water lock) if enabled
            if autoLockEnabled {
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    await MainActor.run {
                        engageLockMode()
                    }
                }
            }
        }
    }

    private func engageLockMode() {
        guard locationManager.isTracking else { return }
        isTrackerLocked = true
        lockEngagedAt = Date()
        crownRotation = 0
        crownRotationAccumulator = 0
        WKInterfaceDevice.current().play(.click)
        locationManager.updateLockState(true)
    }

    private func disengageLock() {
        if isTrackerLocked {
            WKInterfaceDevice.current().play(.success)
        }
        isTrackerLocked = false
        lockEngagedAt = nil
        crownRotation = 0
        crownRotationAccumulator = 0
        locationManager.updateLockState(false)
    }

    // MARK: - Helper Methods
    private var shouldShowPetHeader: Bool {
        petAvatarCGImage != nil
            || !petProfileStore.profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !petProfileStore.profile.type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var petDisplayName: String {
        let trimmed = petProfileStore.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Pet" : trimmed
    }

    private var petAvatarCGImage: CGImage? {
        guard let data = petProfileStore.profile.avatarPNGData else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

}

// MARK: - Lock Overlay

private extension ContentView {
    var lockOverlay: some View {
        VStack(spacing: Spacing.sm) {
            if #available(watchOS 26, *) {
                ZStack {
                    Circle()
                        .fill(.cyan.opacity(Opacity.xlow))
                        .frame(width: 50, height: 50)
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.cyan.gradient)
                        .symbolEffect(.pulse.byLayer, options: .repeating, isActive: !reduceMotion)
                }
                .glassEffect(.regular, in: .circle)
            } else {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
            }

            Text("Tracker Locked")
                .font(.headline)

            Text("Rotate the Digital Crown to unlock. Tracking stays active while locked.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let lockEngagedAt {
                // P2-09: Reduced update frequency from 1s to 60s to save battery
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    Text("Locked for \(formattedLockDuration(since: lockEngagedAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // P1-02: Emergency Stop with confirmation dialog
            Button(role: .destructive) {
                showEmergencyStopConfirmation = true
            } label: {
                Label("Emergency Stop", systemImage: "exclamationmark.triangle")
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .accessibilityLabel("Emergency stop")
            .accessibilityHint("Stop tracking immediately and unlock the tracker")
            .confirmationDialog(
                "Stop tracking? You will lose real-time pet location.",
                isPresented: $showEmergencyStopConfirmation,
                titleVisibility: .visible
            ) {
                Button("Stop Tracking", role: .destructive) {
                    locationManager.stopTracking()
                    disengageLock()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(LockOverlayBackgroundModifier())
        .padding()
        .focusable(true)
        .focused($lockOverlayFocused)
        .digitalCrownRotation(
            $crownRotation,
            from: -10,
            through: 10,
            by: 0.1,
            sensitivity: .medium,
            isContinuous: true,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownRotation) { oldValue, newValue in
            guard isTrackerLocked else { return }
            let delta = newValue - oldValue
            crownRotationAccumulator += delta

            if abs(crownRotationAccumulator) >= unlockRotationThreshold {
                disengageLock()
            }
        }
        .onAppear {
            resetCrownTracking()
            lockOverlayFocused = true
        }
        .onDisappear {
            lockOverlayFocused = false
            resetCrownTracking()
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

    func resetCrownTracking() {
        crownRotation = 0
        crownRotationAccumulator = 0
    }
}

// MARK: - Preview

#Preview {
    ContentView(locationManager: WatchLocationManager.shared)
}
