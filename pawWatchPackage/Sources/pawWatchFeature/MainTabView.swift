#if os(iOS)
import SwiftUI

/// Root tab controller for the iOS app.
public struct MainTabView: View {
    enum Tab {
        case dashboard, history, settings
    }

    @EnvironmentObject private var locationManager: PetLocationManager
    @AppStorage("useMetricUnits") private var useMetricUnits = true
    @State private var selectedTab: Tab = .dashboard

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            GlassSurface { Color.clear }
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                DashboardView(useMetricUnits: useMetricUnits)
                    .tag(Tab.dashboard)

                HistoryView(useMetricUnits: useMetricUnits)
                    .tag(Tab.history)

                SettingsView(useMetricUnits: $useMetricUnits)
                    .tag(Tab.settings)
            }
            .tabViewStyle(.automatic)
            .toolbar(.hidden, for: .tabBar)
            .environmentObject(locationManager)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 90)
            }

            LiquidGlassTabBar(
                selection: $selectedTab,
                items: tabItems
            ) { tab in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    selectedTab = tab
                }
            }
            .padding(.bottom, 8)
        }
    }
}

private extension MainTabView {
    var tabItems: [(icon: String, title: String, tag: Tab)] {
        [
            ("house.fill", "Dashboard", .dashboard),
            ("clock.arrow.circlepath", "History", .history),
            ("gearshape.fill", "Settings", .settings)
        ]
    }
}

/// Centers scrollable content and constrains width for large devices so cards never overflow portrait.
/// Now with parallax support for depth effects.
private struct GlassScroll<Content: View>: View {
    private let spacing: CGFloat
    private let maximumWidth: CGFloat
    private let horizontalPadding: CGFloat
    private let enableParallax: Bool
    @ViewBuilder private let content: Content

    @State private var scrollOffset: CGFloat = 0

    init(
        spacing: CGFloat = 24,
        maxWidth: CGFloat = 420,
        horizontalPadding: CGFloat = 18,
        enableParallax: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.maximumWidth = maxWidth
        self.horizontalPadding = horizontalPadding
        self.enableParallax = enableParallax
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let clampedWidth = max(0, min(maximumWidth, proxy.size.width - horizontalPadding * 2))
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: spacing) {
                    content
                }
                .frame(maxWidth: clampedWidth, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(
                    GeometryReader { scrollProxy in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: scrollProxy.frame(in: .named("scroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                if enableParallax {
                    scrollOffset = value
                }
            }
        }
        .environment(\.scrollOffset, scrollOffset)
    }
}

// MARK: - Scroll Offset Environment

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollOffsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var scrollOffset: CGFloat {
        get { self[ScrollOffsetKey.self] }
        set { self[ScrollOffsetKey.self] = newValue }
    }
}

// MARK: - Parallax Card Modifier

private struct ParallaxCardModifier: ViewModifier {
    let index: Int
    @Environment(\.scrollOffset) private var scrollOffset

    func body(content: Content) -> some View {
        content
            .offset(y: parallaxOffset)
    }

    private var parallaxOffset: CGFloat {
        // Subtle parallax: cards further down move slightly slower
        let baseOffset = scrollOffset * 0.05
        let indexMultiplier = CGFloat(index) * 0.02
        return baseOffset * (1 - indexMultiplier)
    }
}

extension View {
    fileprivate func parallaxCard(index: Int) -> some View {
        modifier(ParallaxCardModifier(index: index))
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @EnvironmentObject private var locationManager: PetLocationManager
    let useMetricUnits: Bool
    @State private var isRefreshing = false

    var body: some View {
        GlassScroll(spacing: 20, maxWidth: 340) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("pawWatch")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Live pet telemetry")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                RefreshButton(isRefreshing: $isRefreshing) {
                    Task { await performRefresh() }
                }
            }
            .padding(.top, 32)

            GlassCard {
                PetStatusCard(useMetricUnits: useMetricUnits)
            }
            .parallaxCard(index: 0)
            .transition(.scale(scale: 0.95).combined(with: .opacity))

            GlassCard(cornerRadius: 28, padding: 0) {
                PetMapView()
                    .frame(height: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        // Enhanced gradient overlay with better depth
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.25),
                                Color.black.opacity(0.08),
                                Color.clear,
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    )
            }
            .parallaxCard(index: 1)
            .transition(.scale(scale: 0.95).combined(with: .opacity))

            if !locationManager.locationHistory.isEmpty {
                GlassCard(cornerRadius: 20, padding: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trail Summary")
                            .font(.headline)
                        HistoryCountView(count: locationManager.locationHistory.count)
                    }
                }
                .parallaxCard(index: 2)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            Spacer(minLength: 60)
        }
        .refreshable { await performRefresh() }
    }

    @MainActor
    private func performRefresh() async {
        guard !isRefreshing else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isRefreshing = true
        }
        locationManager.requestUpdate(force: true)
        try? await Task.sleep(for: .milliseconds(800))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isRefreshing = false
        }
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
                    isRefreshing
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .spring(response: 0.35, dampingFraction: 0.8),
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
        .padding(.horizontal, 4)
    }
}

// MARK: - History

struct HistoryView: View {
    @EnvironmentObject private var locationManager: PetLocationManager
    let useMetricUnits: Bool

    var body: some View {
        GlassScroll(spacing: 16, maxWidth: 340, enableParallax: false) {
            VStack(alignment: .leading, spacing: 4) {
                Text("History")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Recent location fixes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)

            ForEach(Array(locationManager.locationHistory.enumerated()), id: \.offset) { index, fix in
                GlassCard(cornerRadius: 20, padding: 16) {
                    VStack(alignment: .leading, spacing: 6) {
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
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "Lon: %.5f", fix.coordinate.longitude))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Accuracy: " + MeasurementDisplay.accuracy(fix.horizontalAccuracyMeters, useMetric: useMetricUnits))
                                .font(.caption)
                            Spacer()
                            Text(String(format: "Battery: %.0f%%", fix.batteryFraction * 100))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .transition(.scale(scale: 0.98).combined(with: .opacity))
            }

            Spacer(minLength: 40)
        }
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
    @State private var showDeveloperSheet = false

    init(useMetricUnits: Binding<Bool>) {
        self._useMetricUnits = useMetricUnits
    }

    var body: some View {
        GlassScroll(spacing: 18, maxWidth: 340, enableParallax: false) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Fine-tune alerts & tracking")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)

            settingsCard(title: "General") {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                Toggle("Use Metric Units", isOn: $useMetricUnits)
                Text(useMetricUnits ? "Kilometers & meters" : "Miles & feet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                settingsCard(title: "Tracking Mode") {
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

                settingsCard(title: "Trail History") {
                    Stepper(
                        value: Binding(
                            get: { locationManager.trailHistoryLimit },
                            set: { locationManager.updateTrailHistoryLimit(to: $0) }
                        ),
                        in: PetLocationManager.trailHistoryLimitRange,
                        step: PetLocationManager.trailHistoryStep
                    ) {
                        HStack {
                            Text("Stored Fixes")
                            Spacer()
                            Text("\(locationManager.trailHistoryLimit)")
                                .font(.system(.body, design: .monospaced).weight(.semibold))
                        }
                    }

                    Text("Higher limits draw more memory but keep longer breadcrumb trails.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                settingsCard(title: "Permissions") {
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

                    Text(locationManager.distanceUsageBlurb)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                settingsCard(title: "HealthKit") {
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

                settingsCard(title: "Session Summary") {
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

                settingsCard(title: "About") {
                    SettingRow(title: "Version", value: appVersion)
                    SettingRow(title: "Build Date", value: buildDate)
                }

                settingsCard(title: "Developer Tools") {
                    SettingRow(
                        title: "Extended Runtime",
                        value: locationManager.runtimeOptimizationsEnabled ? "Enabled" : "Disabled"
                    )

                    if !locationManager.watchSupportsExtendedRuntime {
                        Text("Waiting for watch handshake to confirm extended runtime availability.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Button("Open Developer Settings") {
                        showDeveloperSheet = true
                    }
                    .buttonStyle(.bordered)
                }

                if let error = locationManager.errorMessage {
                    settingsCard(title: "Alerts") {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

            Spacer(minLength: 32)
        }
        .sheet(isPresented: $showDeveloperSheet) {
            DeveloperSettingsSheet()
                .environmentObject(locationManager)
        }
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        GlassCard(cornerRadius: 20, padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                content()
            }
        }
    }

    private func SettingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private struct DeveloperSettingsSheet: View {
        @EnvironmentObject private var locationManager: PetLocationManager
        @Environment(\.dismiss) private var dismiss

        private var runtimeBinding: Binding<Bool> {
            Binding(
                get: { locationManager.runtimeOptimizationsEnabled },
                set: { locationManager.setRuntimeOptimizationsEnabled($0) }
            )
        }

        private var idleCadenceBinding: Binding<IdleCadencePreset> {
            Binding(
                get: { locationManager.idleCadencePreset },
                set: { locationManager.setIdleCadencePreset($0) }
            )
        }

        var body: some View {
            NavigationStack {
                List {
                    Section("Extended Runtime Guard") {
                        Toggle("Keep workout alive longer", isOn: runtimeBinding)
                            .disabled(!locationManager.watchSupportsExtendedRuntime && !locationManager.runtimeOptimizationsEnabled)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: locationManager.watchSupportsExtendedRuntime ? "bolt.badge.clock" : "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(locationManager.watchSupportsExtendedRuntime ? .green : .orange)
                            Text(capabilityCopy)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text("Enabling requests WKExtendedRuntimeSession on the watch and keeps adaptive GPS throttling active even while the display sleeps. Disable to reproduce baseline battery drain or to test OS energy heuristics.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }

                    Section("Idle Cadence") {
                        Picker("Stationary cadence", selection: idleCadenceBinding) {
                            ForEach(IdleCadencePreset.allCases) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                        .pickerStyle(.inline)

                        Text(idleCadenceBinding.wrappedValue.footnote)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if let heartbeat = locationManager.watchIdleHeartbeatInterval,
                           let fullFix = locationManager.watchIdleFullFixInterval {
                            Text("Watch applied: heartbeat \(formatSeconds(heartbeat)), fix \(formatSeconds(fullFix)).")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Section("Debug") {
                        Button("Close") { dismiss() }
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .navigationTitle("Developer")
                .navigationBarTitleDisplayMode(.inline)
            }
        }

        private func formatSeconds(_ value: TimeInterval) -> String {
            String(format: "%.0fs", value)
        }

        private var capabilityCopy: String {
            if locationManager.watchSupportsExtendedRuntime {
                return "Watch hardware reports extended runtime support."
            } else {
                return "Awaiting confirmation from the watch. Open the watch app to refresh."
            }
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
