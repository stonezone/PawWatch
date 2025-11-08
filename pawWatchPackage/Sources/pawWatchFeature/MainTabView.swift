#if os(iOS)
import SwiftUI

/// Root tab controller for the iOS app.
public struct MainTabView: View {
    @StateObject private var locationManager = PetLocationManager()
    @AppStorage("useMetricUnits") private var useMetricUnits = true

    public init() {}

    public var body: some View {
        TabView {
            NavigationStack {
                DashboardView(useMetricUnits: useMetricUnits)
            }
            .tabItem { Label("Dashboard", systemImage: "house.fill") }

            NavigationStack {
                HistoryView(useMetricUnits: useMetricUnits)
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            NavigationStack {
                SettingsView(useMetricUnits: $useMetricUnits)
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .environmentObject(locationManager)
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
        .navigationBarTitleDisplayMode(.large)
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
        locationManager.requestUpdate()
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

                Button("Request Fresh Location") {
                    locationManager.requestUpdate()
                }
                .disabled(!locationManager.isWatchReachable)
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
    }

    private func SettingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
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
