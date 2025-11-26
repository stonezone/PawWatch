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
    @State private var showAdvanced = false

    init(useMetricUnits: Binding<Bool>) {
        self._useMetricUnits = useMetricUnits
    }

    var body: some View {
        GlassScroll(spacing: 18, maxWidth: 340, enableParallax: false) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Customize your experience")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)

            // MARK: - Connection Status Card (Visual)
            ConnectionStatusCard()

            // MARK: - Quick Settings
            settingsCard(title: "Quick Settings") {
                Toggle("Notifications", isOn: $notificationsEnabled)
                Toggle("Metric Units", isOn: $useMetricUnits)
            }

            // MARK: - Tracking
            settingsCard(title: "Tracking") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mode")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

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
                }

                Divider().opacity(0.3)

                Stepper(
                    value: Binding(
                        get: { locationManager.trailHistoryLimit },
                        set: { locationManager.updateTrailHistoryLimit(to: $0) }
                    ),
                    in: PetLocationManager.trailHistoryLimitRange,
                    step: PetLocationManager.trailHistoryStep
                ) {
                    HStack {
                        Text("Trail History")
                        Spacer()
                        Text("\(locationManager.trailHistoryLimit)")
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    locationManager.requestUpdate(force: true)
                } label: {
                    Label("Request Fresh Location", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!locationManager.isWatchReachable)
            }

            // MARK: - Permissions (Simplified)
            if locationManager.needsLocationPermissionAction || locationManager.needsHealthPermissionAction {
                settingsCard(title: "Permissions Needed") {
                    if locationManager.needsLocationPermissionAction {
                        HStack {
                            Image(systemName: "location.slash.fill")
                                .foregroundStyle(.orange)
                            Text("Location access required")
                                .font(.callout)
                            Spacer()
                            Button("Fix") { locationManager.openLocationSettings() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }

                    if locationManager.needsHealthPermissionAction {
                        HStack {
                            Image(systemName: "heart.slash.fill")
                                .foregroundStyle(.orange)
                            Text("HealthKit access needed")
                                .font(.callout)
                            Spacer()
                            Button("Fix") { locationManager.requestHealthAuthorization() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(!locationManager.canRequestHealthAuthorization)
                        }
                    }
                }
            }

            // MARK: - Error Alert
            if let error = locationManager.errorMessage {
                GlassCard(cornerRadius: 16, padding: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                }
            }

            // MARK: - Advanced Section (Collapsible)
            DisclosureGroup(isExpanded: $showAdvanced) {
                VStack(spacing: 14) {
                    // Session Stats
                    sessionStatsSection

                    // HealthKit Details
                    healthKitSection

                    // Developer Tools
                    developerSection

                    // About
                    aboutSection
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Image(systemName: "gearshape.2.fill")
                        .foregroundStyle(.secondary)
                    Text("Advanced")
                        .font(.headline)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            )

            Spacer(minLength: 32)
        }
        .sheet(isPresented: $showDeveloperSheet) {
            DeveloperSettingsSheet()
                .environmentObject(locationManager)
        }
    }

    // MARK: - Connection Status Card
    @ViewBuilder
    private func ConnectionStatusCard() -> some View {
        GlassCard(cornerRadius: 24, padding: 20) {
            HStack(spacing: 16) {
                // Watch icon with status
                ZStack {
                    Circle()
                        .fill(connectionColor.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: "applewatch")
                        .font(.title)
                        .foregroundStyle(connectionColor.gradient)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(connectionTitle)
                        .font(.headline)

                    Text(connectionSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let battery = locationManager.watchBatteryFraction {
                        HStack(spacing: 4) {
                            Image(systemName: batteryIcon(for: battery))
                                .font(.caption2)
                                .foregroundStyle(batteryColor(for: battery))
                            Text(String(format: "%.0f%%", battery * 100))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Status indicator
                Circle()
                    .fill(connectionColor.gradient)
                    .frame(width: 12, height: 12)
                    .shadow(color: connectionColor.opacity(0.5), radius: 4)
            }
        }
    }

    private var connectionColor: Color {
        if !locationManager.isWatchConnected { return .red }
        if !locationManager.isWatchReachable { return .orange }
        return .green
    }

    private var connectionTitle: String {
        if !locationManager.isWatchConnected { return "Watch Disconnected" }
        if !locationManager.isWatchReachable { return "Watch Paired" }
        return "Watch Connected"
    }

    private var connectionSubtitle: String {
        if !locationManager.isWatchConnected { return "Open Watch app to connect" }
        if !locationManager.isWatchReachable { return "Waiting for active session" }
        if locationManager.isWatchLocked { return "Tracker locked on watch" }
        return "Tracking active"
    }

    private func batteryIcon(for level: Double) -> String {
        if level > 0.75 { return "battery.100" }
        if level > 0.5 { return "battery.75" }
        if level > 0.25 { return "battery.50" }
        return "battery.25"
    }

    private func batteryColor(for level: Double) -> Color {
        if level > 0.5 { return .green }
        if level > 0.2 { return .yellow }
        return .red
    }

    // MARK: - Session Stats Section
    @ViewBuilder
    private var sessionStatsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Stats")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            let summary = locationManager.sessionSummary
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                StatCell(title: "Fixes", value: "\(summary.fixCount)")
                StatCell(title: "Avg Interval", value: formatSeconds(summary.averageIntervalSec))
                StatCell(title: "Median Acc", value: formatMeters(summary.medianAccuracy))
                StatCell(title: "Duration", value: formatDuration(summary.durationSec))
            }

            HStack {
                if let exportURL = locationManager.sessionShareURL() {
                    ShareLink(item: exportURL) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                Button("Reset", role: .destructive) {
                    locationManager.resetSessionStats()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - HealthKit Section
    @ViewBuilder
    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HealthKit")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "figure.run")
                    .foregroundStyle(.pink)
                Text("Workout: \(locationManager.workoutPermissionDescription)")
                    .font(.caption)
            }

            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("Heart Rate: \(locationManager.heartPermissionDescription)")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Developer Section
    @ViewBuilder
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Developer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack {
                Text("Extended Runtime")
                    .font(.caption)
                Spacer()
                Text(locationManager.runtimeOptimizationsEnabled ? "Enabled" : "Disabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Open Developer Settings") {
                showDeveloperSheet = true
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - About Section
    @ViewBuilder
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack {
                Text("Version")
                    .font(.caption)
                Spacer()
                Text(appVersion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Stat Cell
private struct StatCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.weight(.semibold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - SettingsView Helpers
private extension SettingsView {

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
