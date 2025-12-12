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
    }

    private var mainContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {

                    // MARK: - App Title

                    if #available(watchOS 26, *) {
                        VStack(spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: "pawprint.fill")
                                    .font(.title3)
                                    .foregroundStyle(.cyan.gradient)
                                    .symbolEffect(.breathe.pulse.byLayer, options: .repeating, value: locationManager.isTracking)
                                Text("pawWatch")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }

                            Text(AppVersion.displayString)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(spacing: 2) {
                            Text("pawWatch")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text(AppVersion.displayString)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }

                    // MARK: - GPS Status Icon

                    if #available(watchOS 26, *) {
                        ZStack {
                            Circle()
                                .fill(locationManager.isTracking ? Color.green.opacity(0.2) : Color.secondary.opacity(0.1))
                                .frame(width: 70, height: 70)
                            Image(systemName: locationManager.isTracking ? "location.fill" : "location.slash")
                                .font(.system(size: 36))
                                .foregroundStyle(locationManager.isTracking ? AnyShapeStyle(.green.gradient) : AnyShapeStyle(.secondary))
                                .symbolEffect(.bounce.byLayer, value: locationManager.isTracking)
                        }
                        .glassEffect(.regular, in: .circle)
                    } else {
                        Image(systemName: locationManager.isTracking ? "location.fill" : "location.slash")
                            .font(.system(size: 50))
                            .foregroundStyle(locationManager.isTracking ? .green : .secondary)
                            .symbolEffect(.pulse, isActive: locationManager.isTracking)
                    }

                    // MARK: - Status Message

                    GlassPill {
                        Text(locationManager.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                    } else {
                        GlassSkeleton(height: 60)
                            .padding(.vertical, 8)
                    }

                    metricsSection

                    reachabilityPill
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
                        WatchSettingsView(
                            optimizationsEnabled: $batteryOptimizationsEnabled,
                            autoLockEnabled: $autoLockEnabled
                        )
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.bordered)

                    NavigationLink {
                        RadialHistoryGlanceView(manager: locationManager)
                    } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.bordered)
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
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    GlassPill {
                        MetricTile(
                            icon: "waveform.path", 
                            title: "GPS Latency",
                            value: formattedLatency(locationManager.gpsLatencyAverageMS),
                            subtitle: "p95 \(formattedLatency(locationManager.gpsLatencyP95MS))",
                            tint: .mint
                        )
                    }
                    .frame(maxWidth: .infinity)

                    GlassPill {
                        MetricTile(
                            icon: "bolt.fill",
                            title: "Drain / hr",
                            value: formattedDrain(locationManager.batteryDrainPerHour),
                            subtitle: "Inst " + formattedDrain(locationManager.batteryDrainPerHourInstant) +
                                " · " + (batteryOptimizationsEnabled ? "Optimized" : "Performance"),
                            tint: batteryOptimizationsEnabled ? .green : .orange
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .transition(.opacity.combined(with: .scale))
        }
    }

    private var reachabilityPill: some View {
        GlassPill {
            MetricTile(
                icon: locationManager.isPhoneReachable ? "iphone.radiowaves.left.and.right" : "iphone.slash",
                title: "Reachability",
                value: locationManager.isPhoneReachable ? "Reachable" : "Offline",
                subtitle: locationManager.connectionStatus,
                tint: locationManager.isPhoneReachable ? .green : .orange
            )
        }
    }

    private var smartStackHint: some View {
        GlassPill {
            SmartStackHintView(
                latency: formattedLatency(locationManager.gpsLatencyAverageMS),
                drain: formattedDrain(locationManager.batteryDrainPerHour)
            )
        }
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

// MARK: - Glass Helpers

// MARK: - Radial History Glance

private struct RadialHistoryGlanceView: View {
    @Bindable var manager: WatchLocationManager
    private let maxItems = 8

    var body: some View {
        List {
            if manager.recentFixes.isEmpty {
                RadialHistoryEmptyState()
                    .listRowBackground(Color.clear)
            } else {
                ForEach(manager.recentFixes.prefix(maxItems), id: \.sequence) { fix in
                    GlassPill {
                        RadialFixRow(fix: fix)
                    }
                    .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                }
            }
        }
        .listStyle(.carousel)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .background(WatchGlassBackground())
    }
}

private struct RadialHistoryEmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No recent fixes")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Start tracking to populate the glance.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 32)
    }
}

private struct RadialFixRow: View {
    let fix: LocationFix
    private let maxAge: TimeInterval = 15 * 60

    var body: some View {
        HStack(spacing: 10) {
            RadialRing(
                progress: progress(for: fix.timestamp),
                color: accuracyColor(for: fix.horizontalAccuracyMeters),
                size: 30,
                lineWidth: 4
            ) {
                Text(timeAgoShort(since: fix.timestamp))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(timeAgoLong(since: fix.timestamp))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .monospacedDigit()

                    HStack(spacing: 2) {
                        Image(systemName: batteryIcon(for: fix.batteryFraction))
                            .font(.caption2)
                        Text("\(Int((fix.batteryFraction * 100).rounded()))%")
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.secondary)
                }

                Text("±\(fix.horizontalAccuracyMeters, specifier: "%.0f") m")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private func progress(for timestamp: Date) -> CGFloat {
        let age = max(0, Date().timeIntervalSince(timestamp))
        let clamped = max(0.2, 1 - age / maxAge)
        return CGFloat(min(1, clamped))
    }

    private func timeAgoShort(since date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h"
    }

    private func timeAgoLong(since date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
    }

    private func accuracyColor(for accuracy: Double) -> Color {
        switch accuracy {
        case 0..<10: return .green
        case 10..<25: return .yellow
        default: return .orange
        }
    }

    private func batteryIcon(for batteryLevel: Double) -> String {
        let percentage = batteryLevel * 100
        switch percentage {
        case 75...100: return "battery.100"
        case 50..<75: return "battery.75"
        case 25..<50: return "battery.50"
        case 10..<25: return "battery.25"
        default: return "battery.0"
        }
    }
}

private struct RadialRing<Content: View>: View {
    let progress: CGFloat
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            content
        }
        .frame(width: size, height: size)
    }
}

private struct GlassPill<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(watchOS 26, *) {
            content
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .capsule)
        } else {
            content
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
        }
    }
}

private struct GlassSkeleton: View {
    let height: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.3))
            .frame(height: height)
    }
}

private struct MetricTile: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String?
    var tint: Color = .cyan

    init(icon: String, title: String, value: String, subtitle: String? = nil, tint: Color = .cyan) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.tint = tint
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(tint)
                .imageScale(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SmartStackHintView: View {
    let latency: String
    let drain: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "rectangle.stack.badge.play.fill")
                .font(.caption2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Smart Stack preview")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("WidgetKit card will mirror \(latency) + \(drain) snapshot when Phase 6 lands.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Lock Overlay

private extension ContentView {
    var lockOverlay: some View {
        VStack(spacing: 10) {
            if #available(watchOS 26, *) {
                ZStack {
                    Circle()
                        .fill(.cyan.opacity(0.2))
                        .frame(width: 50, height: 50)
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.cyan.gradient)
                        .symbolEffect(.pulse.byLayer, options: .repeating)
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

// MARK: - Lock Overlay Background

private struct LockOverlayBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(watchOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView(locationManager: WatchLocationManager.shared)
}

// MARK: - Settings View

private struct WatchSettingsView: View {
    @Binding var optimizationsEnabled: Bool
    @Binding var autoLockEnabled: Bool

    var body: some View {
        List {
            Section("Battery") {
                Toggle("Runtime Guard & Smart Polling", isOn: $optimizationsEnabled)
                Text("Keeps the workout alive with WKExtendedRuntimeSession and slows GPS when stationary or low battery.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section("Water Lock") {
                Toggle("Auto-Lock on Start", isOn: $autoLockEnabled)
                Text("Automatically locks the tracker when you start tracking. Rotate the Digital Crown to unlock.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.carousel)
        .navigationTitle("Settings")
    }
}
