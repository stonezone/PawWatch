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

    private var hasLocation: Bool { locationManager.latestLocation != nil }
    private var isConnected: Bool { locationManager.isWatchConnected }

    var body: some View {
        GlassScroll(spacing: 16, maxWidth: 380) {
            // Hero Header
            DashboardHeader(isRefreshing: $isRefreshing) {
                Task { await performRefresh() }
            }
            .padding(.top, 24)

            // Connection/Status Hero Card
            if !isConnected {
                OnboardingCard()
                    .parallaxCard(index: 0)
            } else if !hasLocation {
                WaitingForDataCard()
                    .parallaxCard(index: 0)
            } else {
                // Quick Stats Strip
                QuickStatsStrip(
                    accuracy: locationManager.latestLocation?.horizontalAccuracyMeters,
                    battery: locationManager.watchBatteryFraction ?? locationManager.latestLocation?.batteryFraction,
                    distance: locationManager.distanceFromOwner,
                    lastUpdate: locationManager.secondsSinceLastUpdate,
                    useMetric: useMetricUnits
                )
                .parallaxCard(index: 0)
            }

            // Map with overlaid status
            ZStack(alignment: .topLeading) {
                GlassCard(cornerRadius: 28, padding: 0) {
                    PetMapView()
                        .frame(height: 380)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.2),
                                    Color.clear,
                                    Color.clear,
                                    Color.black.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        )
                }

                // Floating status badge
                if isConnected {
                    LiveStatusBadge(
                        isReachable: locationManager.isWatchReachable,
                        secondsAgo: locationManager.secondsSinceLastUpdate
                    )
                    .padding(16)
                }
            }
            .parallaxCard(index: 1)

            // Coordinates Card (when data available)
            if let location = locationManager.latestLocation {
                CoordinatesCard(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                .parallaxCard(index: 2)
            }

            // Trail Summary
            if !locationManager.locationHistory.isEmpty {
                TrailSummaryCard(
                    count: locationManager.locationHistory.count,
                    limit: locationManager.trailHistoryLimit
                )
                .parallaxCard(index: 3)
            }

            // Foreground distance notice
            if hasLocation {
                ForegroundNotice(message: locationManager.distanceUsageBlurb)
            }

            // Error banner
            if let error = locationManager.errorMessage {
                DashboardErrorBanner(message: error)
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

// MARK: - Dashboard Header

private struct DashboardHeader: View {
    @Binding var isRefreshing: Bool
    let onRefresh: () -> Void
    private let theme = LiquidGlassTheme.current

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 12) {
                // App icon with theme gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: theme.accentGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: "pawprint.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("pawWatch")
                        .font(.title2.weight(.bold))
                    Text("Live Tracking")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onRefresh) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .strokeBorder(theme.chromeStrokeSubtle, lineWidth: 1)
                        )

                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.accentPrimary)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(
                            isRefreshing
                                ? .linear(duration: 1).repeatForever(autoreverses: false)
                                : theme.springStandard,
                            value: isRefreshing
                        )
                }
            }
            .disabled(isRefreshing)
        }
    }
}

// MARK: - Onboarding Card

private struct OnboardingCard: View {
    private let theme = LiquidGlassTheme.current

    var body: some View {
        GlassCard(cornerRadius: theme.cornerRadiusCard, padding: 24) {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange.opacity(0.2), .red.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "applewatch.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange.gradient)
                }

                VStack(spacing: 8) {
                    Text("Connect Your Watch")
                        .font(.headline)

                    Text("Open the pawWatch app on your Apple Watch to start tracking your pet's location.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 8) {
                    Image(systemName: "1.circle.fill")
                        .foregroundStyle(theme.accentPrimary)
                    Text("Open Watch app")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "2.circle.fill")
                        .foregroundStyle(theme.accentPrimary)
                    Text("Tap Start")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Waiting For Data Card

private struct WaitingForDataCard: View {
    private let theme = LiquidGlassTheme.current

    var body: some View {
        GlassCard(cornerRadius: theme.cornerRadiusCard, padding: 20) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.green.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title2)
                        .foregroundStyle(.green.gradient)
                        .symbolEffect(.pulse)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Watch Connected")
                        .font(.headline)

                    Text("Waiting for GPS data...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}

// MARK: - Quick Stats Strip

private struct QuickStatsStrip: View {
    let accuracy: Double?
    let battery: Double?
    let distance: Double?
    let lastUpdate: TimeInterval?
    let useMetric: Bool

    var body: some View {
        HStack(spacing: 8) {
            QuickStatItem(
                icon: "scope",
                value: accuracy.map { MeasurementDisplay.accuracy($0, useMetric: useMetric) } ?? "-",
                color: accuracyColor
            )

            QuickStatItem(
                icon: batteryIcon,
                value: battery.map { String(format: "%.0f%%", $0 * 100) } ?? "-",
                color: batteryColor
            )

            QuickStatItem(
                icon: "ruler",
                value: distance.map { MeasurementDisplay.distance($0, useMetric: useMetric) } ?? "-",
                color: .cyan
            )

            QuickStatItem(
                icon: "clock",
                value: timeAgoText,
                color: .purple
            )
        }
    }

    private var accuracyColor: Color {
        guard let acc = accuracy else { return .gray }
        if acc < 10 { return .green }
        if acc < 50 { return .yellow }
        return .red
    }

    private var batteryColor: Color {
        guard let bat = battery else { return .gray }
        if bat > 0.5 { return .green }
        if bat > 0.2 { return .yellow }
        return .red
    }

    private var batteryIcon: String {
        guard let bat = battery else { return "battery.0" }
        if bat > 0.75 { return "battery.100" }
        if bat > 0.5 { return "battery.75" }
        if bat > 0.25 { return "battery.50" }
        return "battery.25"
    }

    private var timeAgoText: String {
        guard let seconds = lastUpdate else { return "-" }
        if seconds < 60 { return String(format: "%.0fs", seconds) }
        if seconds < 3600 { return String(format: "%.0fm", seconds / 60) }
        return String(format: "%.1fh", seconds / 3600)
    }
}

private struct QuickStatItem: View {
    let icon: String
    let value: String
    let color: Color
    private let theme = LiquidGlassTheme.current

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color.gradient)

            Text(value)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Live Status Badge

private struct LiveStatusBadge: View {
    let isReachable: Bool
    let secondsAgo: TimeInterval?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isReachable ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
                .shadow(color: (isReachable ? Color.green : Color.orange).opacity(0.6), radius: 4)

            Text(statusText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
    }

    private var statusText: String {
        if !isReachable { return "Paired" }
        guard let seconds = secondsAgo else { return "Live" }
        if seconds < 10 { return "Live" }
        if seconds < 60 { return String(format: "%.0fs ago", seconds) }
        return String(format: "%.0fm ago", seconds / 60)
    }
}

// MARK: - Coordinates Card

private struct CoordinatesCard: View {
    let latitude: Double
    let longitude: Double
    private let theme = LiquidGlassTheme.current

    var body: some View {
        GlassCard(cornerRadius: theme.cornerRadiusCard - 4, padding: 16) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Latitude", systemImage: "arrow.up")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.6f°", latitude))
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                }

                Spacer()

                Divider()
                    .frame(height: 36)
                    .padding(.horizontal, 16)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Label("Longitude", systemImage: "arrow.right")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.6f°", longitude))
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                }
            }
        }
    }
}

// MARK: - Trail Summary Card

private struct TrailSummaryCard: View {
    let count: Int
    let limit: Int
    private let theme = LiquidGlassTheme.current

    var body: some View {
        GlassCard(cornerRadius: theme.cornerRadiusButton, padding: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(theme.accentPrimary.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.accentPrimary.gradient)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Trail History")
                        .font(.subheadline.weight(.semibold))

                    Text("\(count) of \(limit) locations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Progress indicator
                ZStack {
                    Circle()
                        .stroke(theme.accentPrimary.opacity(0.2), lineWidth: 3)
                        .frame(width: 32, height: 32)

                    Circle()
                        .trim(from: 0, to: min(1, Double(count) / Double(limit)))
                        .stroke(theme.accentPrimary.gradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 32, height: 32)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(Double(count) / Double(limit) * 100))")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Foreground Notice

private struct ForegroundNotice: View {
    let message: String
    private let theme = LiquidGlassTheme.current

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall - 4, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

// MARK: - Dashboard Error Banner

private struct DashboardErrorBanner: View {
    let message: String
    private let theme = LiquidGlassTheme.current

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange.gradient)

            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(3)

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall - 2, style: .continuous)
                .fill(.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall - 2, style: .continuous)
                        .strokeBorder(.orange.opacity(0.25), lineWidth: 1)
                )
        )
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
