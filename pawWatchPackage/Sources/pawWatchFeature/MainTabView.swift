#if os(iOS)
import SwiftUI

/// Root tab controller for the iOS app.
public struct MainTabView: View {
    enum Tab {
        case dashboard, history, settings
    }
    
    @StateObject private var locationManager = PetLocationManager()
    @AppStorage("useMetricUnits") private var useMetricUnits = true
    @State private var selectedTab: Tab = .dashboard

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    DashboardView(useMetricUnits: useMetricUnits)
                }
                .tag(Tab.dashboard)
                
                NavigationStack {
                    HistoryView(useMetricUnits: useMetricUnits)
                }
                .tag(Tab.history)
                
                NavigationStack {
                    SettingsView(useMetricUnits: $useMetricUnits)
                }
                .tag(Tab.settings)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .environmentObject(locationManager)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 65)
            }
            
            // Custom tab bar
            HStack(spacing: 0) {
                TabBarButton(
                    icon: "house.fill",
                    title: "Dashboard",
                    isSelected: selectedTab == .dashboard
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = .dashboard
                    }
                }
                
                TabBarButton(
                    icon: "clock.arrow.circlepath",
                    title: "History",
                    isSelected: selectedTab == .history
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = .history
                    }
                }
                
                TabBarButton(
                    icon: "gearshape.fill",
                    title: "Settings",
                    isSelected: selectedTab == .settings
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = .settings
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Tab Bar Button

private struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .symbolVariant(isSelected ? .fill : .none)
                
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? .blue : .secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @EnvironmentObject private var locationManager: PetLocationManager
    let useMetricUnits: Bool
    @State private var isRefreshing = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.1), .purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    PetStatusCard(useMetricUnits: useMetricUnits)
                        .padding(.top, 8)

                    PetMapView()
                        .frame(height: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                        .padding(.horizontal, 20)

                    if !locationManager.locationHistory.isEmpty {
                        HistoryCountView(count: locationManager.locationHistory.count)
                    }

                    Spacer(minLength: 40)
                }
            }
            .refreshable { await performRefresh() }
        }
        .navigationTitle("pawWatch")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                RefreshButton(isRefreshing: $isRefreshing) {
                    Task { await performRefresh() }
                }
            }
        }
    }

    @MainActor
    private func performRefresh() async {
        guard !isRefreshing else { return }
        withAnimation(.spring(response: 0.3)) { isRefreshing = true }
        locationManager.requestUpdate(force: true)
        try? await Task.sleep(for: .milliseconds(800))
        withAnimation(.spring(response: 0.3)) { isRefreshing = false }
    }
}

private struct RefreshButton: View {
    @Binding var isRefreshing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.blue.gradient)
                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                .animation(
                    isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .spring(response: 0.3),
                    value: isRefreshing
                )
        }
        .disabled(isRefreshing)
    }
}

private struct HistoryCountView: View {
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Trail: \(count) location\(count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - History

struct HistoryView: View {
    @EnvironmentObject private var locationManager: PetLocationManager
    let useMetricUnits: Bool

    var body: some View {
        List {
            ForEach(Array(locationManager.locationHistory.enumerated()), id: \.offset) { index, fix in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Fix #\(locationManager.locationHistory.count - index)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(dateFormatter.string(from: fix.timestamp))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(String(format: "Lat: %.5f", fix.coordinate.latitude))
                            .font(.caption)
                        Spacer()
                        Text(String(format: "Lon: %.5f", fix.coordinate.longitude))
                            .font(.caption)
                    }
                    HStack {
                        Text("Accuracy: " + MeasurementDisplay.accuracy(fix.horizontalAccuracyMeters, useMetric: useMetricUnits))
                            .font(.caption)
                        Spacer()
                        Text(String(format: "Battery: %.0f%%", fix.batteryFraction * 100))
                            .font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var locationManager: PetLocationManager
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("trackingMode") private var trackingModeRaw = TrackingMode.auto.rawValue
    @Binding private var useMetricUnits: Bool

    init(useMetricUnits: Binding<Bool>) {
        self._useMetricUnits = useMetricUnits
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                Toggle("Use Metric Units", isOn: $useMetricUnits)
                Text(useMetricUnits ? "Kilometers & meters" : "Miles & feet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Tracking Mode") {
                Picker("Mode", selection: Binding(
                    get: { TrackingMode(rawValue: trackingModeRaw) ?? .auto },
                    set: { trackingModeRaw = $0.rawValue }
                )) {
                    ForEach(TrackingMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: trackingModeRaw) { _, newRaw in
                    if let mode = TrackingMode(rawValue: newRaw) {
                        locationManager.setTrackingMode(mode)
                    }
                }

                Button("Request Fresh Location") {
                    locationManager.requestUpdate(force: true)
                }
                .disabled(!locationManager.isWatchReachable)

                if let battery = locationManager.watchBatteryFraction {
                    SettingRow(title: "Watch Battery", value: String(format: "%.0f%%", battery * 100))
                }
            }

            Section("Permissions") {
                SettingRow(title: "iPhone Location", value: locationManager.locationPermissionDescription)
                if locationManager.needsLocationPermissionAction {
                    Button("Open Settings") { locationManager.openLocationSettings() }
                        .font(.caption)
                }

                SettingRow(
                    title: "Watch Status",
                    value: locationManager.isWatchConnected ? (locationManager.isWatchReachable ? "Connected" : "Paired") : "Disconnected"
                )

                if locationManager.isWatchConnected {
                    SettingRow(
                        title: "Tracker Lock",
                        value: locationManager.isWatchLocked ? "Locked" : "Unlocked"
                    )
                    if locationManager.isWatchLocked {
                        Text("Unlock on the watch by rotating the Digital Crown.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("HealthKit") {
                SettingRow(title: "Workout Access", value: locationManager.workoutPermissionDescription)
                SettingRow(title: "Heart Rate", value: locationManager.heartPermissionDescription)
                Button("Request Health Access") {
                    locationManager.requestHealthAuthorization()
                }
                .disabled(!locationManager.canRequestHealthAuthorization)
                if locationManager.needsHealthPermissionAction {
                    Text("Grant Health permissions to keep background tracking alive.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Session Summary") {
                let summary = locationManager.sessionSummary
                SettingRow(title: "Fixes", value: "\(summary.fixCount)")
                SettingRow(title: "Avg Interval", value: formatSeconds(summary.averageIntervalSec))
                SettingRow(title: "Median Accuracy", value: formatMeters(summary.medianAccuracy))
                SettingRow(title: "P90 Accuracy", value: formatMeters(summary.p90Accuracy))
                SettingRow(title: "Max Accuracy", value: formatMeters(summary.maxAccuracy))
                SettingRow(title: "Reachability Flips", value: "\(summary.reachabilityChanges)")
                if summary.durationSec > 0 {
                    SettingRow(title: "Duration", value: formatDuration(summary.durationSec))
                }
                if !summary.presetCounts.isEmpty {
                    ForEach(summary.presetCounts.sorted(by: { $0.key < $1.key }), id: \.key) { preset, count in
                        SettingRow(title: "Preset \(preset.capitalized)", value: "\(count)")
                    }
                }

                if let exportURL = locationManager.sessionShareURL() {
                    ShareLink(item: exportURL) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Text("No samples captured yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Reset Session Stats", role: .destructive) {
                    locationManager.resetSessionStats()
                }
            }

            Section("About") {
                SettingRow(title: "Version", value: appVersion)
                SettingRow(title: "Build Date", value: buildDate)
            }

            if let error = locationManager.errorMessage {
                Section("Alerts") {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func SettingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func formatSeconds(_ value: Double) -> String {
        guard value > 0 else { return "-" }
        return String(format: "%.1f s", value)
    }

    private func formatMeters(_ value: Double) -> String {
        guard value > 0 else { return "-" }
        return String(format: "%.1f m", value)
    }

    private func formatDuration(_ value: Double) -> String {
        guard value > 0 else { return "-" }
        let minutes = Int(value / 60)
        let seconds = Int(value.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private var buildDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }
}

#endif
