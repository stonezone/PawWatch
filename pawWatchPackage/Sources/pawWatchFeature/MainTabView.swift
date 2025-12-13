#if os(iOS)
import SwiftUI
import PhotosUI
import UIKit

/// Root tab controller for the iOS app with custom Liquid Glass tab bar.
public struct MainTabView: View {
    /// Tab selection options
    enum TabSelection: Hashable {
        case dashboard, history, settings
    }

    @Environment(PetLocationManager.self) private var locationManager
    @AppStorage("useMetricUnits") private var useMetricUnits = true
    @State private var selectedTab: TabSelection = .dashboard

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Tab content - manual switching to avoid native TabView artifacts
            // Using .id() to force view recreation on tab change, preventing observation leaks
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView(useMetricUnits: useMetricUnits)
                        .id("dashboard-\(selectedTab)")
                case .history:
                    HistoryView(useMetricUnits: useMetricUnits)
                        .id("history-\(selectedTab)")
                case .settings:
                    SettingsView(useMetricUnits: $useMetricUnits)
                        .id("settings-\(selectedTab)")
                }
            }

            // Custom Liquid Glass tab bar at bottom
            LiquidGlassTabBar(
                selection: $selectedTab,
                items: tabItems
            ) { tab in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    selectedTab = tab
                }
            }
            .padding(.bottom, 4)
        }
        .background {
            GlassSurface { Color.clear }
                .ignoresSafeArea()
        }
    }
}

private extension MainTabView {
    var tabItems: [(icon: String, title: String, tag: TabSelection)] {
        [
            ("house.fill", "Dashboard", .dashboard),
            ("clock.arrow.circlepath", "History", .history),
            ("gearshape.fill", "Settings", .settings)
        ]
    }
}

/// Centers scrollable content and constrains width for large devices so cards never overflow portrait.
/// iOS 26+: Uses native scroll edge effects for modern glass blur at edges.
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
            .modifier(ScrollEdgeEffectModifier())
        }
        .environment(\.scrollOffset, scrollOffset)
    }
}

/// iOS 26 scroll edge effect modifier
private struct ScrollEdgeEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .scrollEdgeEffectStyle(.soft, for: .top)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            content
        }
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
    @Environment(PetLocationManager.self) private var locationManager
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
                        secondsAgo: locationManager.secondsSinceLastUpdate,
                        updateSource: locationManager.latestUpdateSource
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
            HStack(spacing: Spacing.md) {
                // App icon with modern glass effect
                appIcon

                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text("pawWatch")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Live Tracking")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(AppVersion.displayString)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            refreshButton
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if #available(iOS 26, *) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.accentPrimary, theme.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                Image(systemName: "pawprint.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.breathe.pulse.byLayer, options: .repeating)
            }
            .glassEffect(.regular, in: .circle)
        } else {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: theme.accentGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: IconSize.xxl, height: IconSize.xxl)

                Image(systemName: "pawprint.fill")
                    .font(.system(size: IconSize.lg, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private var refreshButton: some View {
        if #available(iOS 26, *) {
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.accentPrimary)
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(
                        isRefreshing
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : theme.springStandard,
                        value: isRefreshing
                    )
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .disabled(isRefreshing)
            .accessibilityLabel("Refresh location")
            .accessibilityHint(isRefreshing ? "Currently refreshing" : "Double tap to request fresh location data")
        } else {
            Button(action: onRefresh) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                        .overlay(
                            Circle()
                                .strokeBorder(theme.chromeStrokeSubtle, lineWidth: 1)
                        )

                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: IconSize.button, weight: .semibold))
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
            .accessibilityLabel("Refresh location")
            .accessibilityHint(isRefreshing ? "Currently refreshing" : "Double tap to request fresh location data")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Watch not connected")
        .accessibilityHint("Open the pawWatch app on your Apple Watch, then tap Start to begin tracking")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Watch connected, waiting for GPS data")
        .accessibilityValue("Loading location information from your Apple Watch")
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
        HStack(spacing: 10) {
            QuickStatItem(
                icon: "scope",
                value: accuracy.map { MeasurementDisplay.accuracy($0, useMetric: useMetric) } ?? "-",
                color: accuracyColor,
                accessibilityLabel: "GPS accuracy"
            )

            QuickStatItem(
                icon: batteryIcon,
                value: battery.map { String(format: "%.0f%%", $0 * 100) } ?? "-",
                color: batteryColor,
                accessibilityLabel: "Watch battery"
            )

            QuickStatItem(
                icon: "ruler",
                value: distance.map { MeasurementDisplay.distance($0, useMetric: useMetric) } ?? "-",
                color: .cyan,
                accessibilityLabel: "Distance from you"
            )

            QuickStatItem(
                icon: "clock",
                value: timeAgoText,
                color: .purple,
                accessibilityLabel: "Time since last update"
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
    let accessibilityLabel: String
    private let theme = LiquidGlassTheme.current

    var body: some View {
        if #available(iOS 26, *) {
            modernStatItem
        } else {
            legacyStatItem
        }
    }

    @available(iOS 26, *)
    private var modernStatItem: some View {
        VStack(spacing: 6) {
            // Clean icon with subtle color - no animation unless this is accuracy
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(value)
    }

    private var legacyStatItem: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(value)
    }
}

// MARK: - Live Status Badge

private struct LiveStatusBadge: View {
    let isReachable: Bool
    let secondsAgo: TimeInterval?
    let updateSource: LocationUpdateSource

    private var statusColor: Color {
        if updateSource == .cloudKit { return .blue }
        return isReachable ? .green : .orange
    }

    var body: some View {
        if #available(iOS 26, *) {
            modernBadge
        } else {
            legacyBadge
        }
    }

    @available(iOS 26, *)
    private var modernBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor.gradient)
                .frame(width: 10, height: 10)
                .shadow(color: statusColor.opacity(0.8), radius: 6)
                .symbolEffect(.pulse, options: isReachable ? .repeating : .default, value: isReachable)

            Text(statusText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection status")
        .accessibilityValue(accessibilityStatus)
    }

    private var legacyBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.6), radius: 4)

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection status")
        .accessibilityValue(accessibilityStatus)
    }

    private var statusText: String {
        let base: String
        if updateSource == .cloudKit {
            base = "iCloud Relay"
        } else {
            base = isReachable ? "Direct" : "Paired"
        }

        guard let seconds = secondsAgo else { return base }
        if seconds < 10 { return base }
        if seconds < 60 { return "\(base) • \(Int(seconds))s" }
        return "\(base) • \(Int(seconds / 60))m"
    }

    private var accessibilityStatus: String {
        let base: String
        if updateSource == .cloudKit {
            base = "Receiving iCloud relay updates"
        } else if isReachable {
            base = "Receiving direct WatchConnectivity updates"
        } else {
            base = "Watch paired but not actively streaming"
        }

        guard let seconds = secondsAgo else { return base }
        if seconds < 10 { return base }
        if seconds < 60 { return "\(base). Last update \(Int(seconds)) seconds ago" }
        return "\(base). Last update \(Int(seconds / 60)) minutes ago"
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pet coordinates")
        .accessibilityValue("Latitude \(String(format: "%.4f", latitude)) degrees, Longitude \(String(format: "%.4f", longitude)) degrees")
    }
}

// MARK: - Trail Summary Card

private struct TrailSummaryCard: View {
    let count: Int
    let limit: Int
    private let theme = LiquidGlassTheme.current

    private var percentage: Int {
        Int(Double(count) / Double(limit) * 100)
    }

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

                    Text("\(percentage)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trail history")
        .accessibilityValue("\(count) of \(limit) locations recorded, \(percentage) percent capacity")
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
    @Environment(PetLocationManager.self) private var locationManager
    let useMetricUnits: Bool

    var body: some View {
        GlassScroll(spacing: Spacing.lg, maxWidth: 340, enableParallax: false) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("History")
                    .font(Typography.pageTitle)
                Text("Recent location fixes")
                    .font(Typography.pageSubtitle)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, Spacing.xxxl)

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
    @Environment(PetLocationManager.self) private var locationManager
    @Environment(PetProfileStore.self) private var petProfileStore
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("trackingMode") private var trackingModeRaw = TrackingMode.auto.rawValue
    @Binding private var useMetricUnits: Bool
    @State private var showDeveloperSheet = false
    @State private var showAdvanced = false
    @State private var selectedPetPhotoItem: PhotosPickerItem?
    @State private var petPhotoLoadTask: Task<Void, Never>?
    @State private var petPhotoError: String?
    /// Debounce task to prevent rapid mode change race conditions
    @State private var modeChangeTask: Task<Void, Never>?

    init(useMetricUnits: Binding<Bool>) {
        self._useMetricUnits = useMetricUnits
    }

    private var emergencyCadenceBinding: Binding<EmergencyCadencePreset> {
        Binding(
            get: { locationManager.emergencyCadencePreset },
            set: { locationManager.setEmergencyCadencePreset($0) }
        )
    }

    var body: some View {
        GlassScroll(spacing: Spacing.Component.listItemSpacing + Spacing.xs, maxWidth: 340, enableParallax: false) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Settings")
                    .font(Typography.pageTitle)
                Text("Customize your experience")
                    .font(Typography.pageSubtitle)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, Spacing.xxxl)

            // MARK: - Connection Status Card (Visual)
            ConnectionStatusCard()

            // MARK: - Quick Settings
            settingsCard(title: "Quick Settings") {
                Toggle("Notifications", isOn: $notificationsEnabled)
                Toggle("Metric Units", isOn: $useMetricUnits)
            }

            // MARK: - Pet
            settingsCard(title: "Pet") {
                petProfileCardContent
            }

            // MARK: - Tracking
            settingsCard(title: "Tracking") {
                let selectedMode = TrackingMode(rawValue: trackingModeRaw) ?? .auto
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
                        // Debounce mode changes to prevent race conditions and crashes
                        modeChangeTask?.cancel()
                        modeChangeTask = Task { @MainActor in
                            // 300ms debounce delay
                            try? await Task.sleep(for: .milliseconds(300))
                            guard !Task.isCancelled else { return }

                            if let mode = TrackingMode(rawValue: newRaw) {
                                locationManager.setTrackingMode(mode)
                            }
                        }
                    }
                }

                if selectedMode == .emergency {
                    Divider().opacity(0.3)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Emergency cadence")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        Picker("Emergency cadence", selection: emergencyCadenceBinding) {
                            ForEach(EmergencyCadencePreset.allCases) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(locationManager.emergencyCadencePreset.footnote)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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
            advancedSection

            Spacer(minLength: 32)
        }
        .sheet(isPresented: $showDeveloperSheet) {
            DeveloperSettingsSheet()
                .environment(locationManager)
        }
    }

    // MARK: - Connection Status Card
    @ViewBuilder
    private func ConnectionStatusCard() -> some View {
        if #available(iOS 26, *) {
            modernConnectionStatusCard
        } else {
            legacyConnectionStatusCard
        }
    }

    @available(iOS 26, *)
    private var modernConnectionStatusCard: some View {
        HStack(spacing: 16) {
            // Watch icon with glass circle and pulse effect
            ZStack {
                Circle()
                    .fill(connectionColor.opacity(0.2))
                    .frame(width: 56, height: 56)

                Image(systemName: "applewatch")
                    .font(.title)
                    .foregroundStyle(connectionColor.gradient)
                    .symbolEffect(.pulse.byLayer, options: locationManager.isWatchReachable ? .repeating : .default, value: locationManager.isWatchReachable)
            }
            .glassEffect(.regular, in: .circle)

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

            // Status indicator with glow
            Circle()
                .fill(connectionColor.gradient)
                .frame(width: 14, height: 14)
                .shadow(color: connectionColor.opacity(0.6), radius: 6)
        }
        .padding(20)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }

    private var legacyConnectionStatusCard: some View {
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

    // MARK: - Advanced Section
    @ViewBuilder
    private var advancedSection: some View {
        if #available(iOS 26, *) {
            modernAdvancedSection
        } else {
            legacyAdvancedSection
        }
    }

    @available(iOS 26, *)
    private var modernAdvancedSection: some View {
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(spacing: 14) {
                sessionStatsSection
                healthKitSection
                developerSection
                aboutSection
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .foregroundStyle(.secondary)
                    .symbolEffect(.rotate, value: showAdvanced)
                Text("Advanced")
                    .font(.headline)
            }
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
    }

    private var legacyAdvancedSection: some View {
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(spacing: 14) {
                sessionStatsSection
                healthKitSection
                developerSection
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
        if #available(iOS 26, *) {
            modernStatCell
        } else {
            legacyStatCell
        }
    }

    @available(iOS 26, *)
    private var modernStatCell: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.weight(.semibold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
    }

    private var legacyStatCell: some View {
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

    @ViewBuilder
    private var petProfileCardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 56, height: 56)

                    if let avatarImage = petAvatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "pawprint.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    TextField(
                        "Pet name",
                        text: Binding(
                            get: { petProfileStore.profile.name },
                            set: { petProfileStore.profile.name = $0 }
                        )
                    )
                    .textInputAutocapitalization(.words)

                    TextField(
                        "Pet type (Dog, Cat, etc.)",
                        text: Binding(
                            get: { petProfileStore.profile.type },
                            set: { petProfileStore.profile.type = $0 }
                        )
                    )
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(.secondary)
                }
            }

            PhotosPicker(selection: $selectedPetPhotoItem, matching: .images) {
                Label("Choose pet photo", systemImage: "photo.on.rectangle.angled")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.bordered)
            .onChange(of: selectedPetPhotoItem) { _, newItem in
                petPhotoLoadTask?.cancel()
                petPhotoError = nil

                guard let newItem else { return }
                petPhotoLoadTask = Task { @MainActor in
                    do {
                        guard let imageData = try await newItem.loadTransferable(type: Data.self) else {
                            petPhotoError = "Unable to load photo."
                            return
                        }
                        guard let image = UIImage(data: imageData) else {
                            petPhotoError = "Unsupported image format."
                            return
                        }
                        guard let avatarData = renderAvatarPNG(from: image, side: 128) else {
                            petPhotoError = "Unable to process photo."
                            return
                        }
                        petProfileStore.profile.avatarPNGData = avatarData
                    } catch {
                        petPhotoError = "Photo error: \(error.localizedDescription)"
                    }
                }
            }

            Button {
                locationManager.pingWatch()
            } label: {
                Label("Ping watch", systemImage: "bell")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.bordered)
            .disabled(!locationManager.isWatchReachable)

            if petProfileStore.profile.avatarPNGData != nil {
                Button(role: .destructive) {
                    petProfileStore.clearAvatar()
                } label: {
                    Label("Remove photo", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
            }

            if let petPhotoError {
                Text(petPhotoError)
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else {
                Text("Pet profile syncs to your watch when it’s reachable, otherwise it queues for delivery.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var petAvatarImage: UIImage? {
        guard let data = petProfileStore.profile.avatarPNGData else { return nil }
        return UIImage(data: data)
    }

    private func renderAvatarPNG(from image: UIImage, side: CGFloat) -> Data? {
        let targetSize = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            let scale = max(side / max(image.size.width, 1), side / max(image.size.height, 1))
            let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(x: (side - scaledSize.width) / 2, y: (side - scaledSize.height) / 2)
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
        return rendered.pngData()
    }

    @ViewBuilder
    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26, *) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
        } else {
            GlassCard(cornerRadius: 20, padding: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    content()
                }
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
        @Environment(PetLocationManager.self) private var locationManager
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
