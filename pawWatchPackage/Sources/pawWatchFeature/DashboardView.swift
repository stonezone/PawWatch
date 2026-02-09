#if os(iOS)
import SwiftUI
import CoreLocation

/// Dashboard view showing live tracking status, map, and quick stats
@MainActor
struct DashboardView: View {
    @Environment(PetLocationManager.self) private var locationManager
    let useMetricUnits: Bool
    @State private var isRefreshing = false
    // P2-01: Track initial loading state
    @State private var isInitialLoad = true

    private var hasLocation: Bool { locationManager.latestLocation != nil }
    private var isConnected: Bool { locationManager.isWatchConnected }

    var body: some View {
        GlassScroll(spacing: 16, maxWidth: 380) {
            // Hero Header
            DashboardHeader(isRefreshing: $isRefreshing) {
                Task { await performRefresh() }
            }
            .padding(.top, 24)

            // P2-01: Show loading skeleton during initial connection resolution
            if isInitialLoad {
                LoadingSkeletonCard()
                    .parallaxCard(index: 0)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // Connection/Status Hero Card
                if !isConnected {
                    OnboardingCard()
                        .parallaxCard(index: 0)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if !hasLocation {
                    WaitingForDataCard()
                        .parallaxCard(index: 0)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
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

                VStack(alignment: .leading, spacing: 8) {
                    // Floating status badge
                    if isConnected {
                        LiveStatusBadge(
                            isReachable: locationManager.isWatchReachable,
                            secondsAgo: locationManager.secondsSinceLastUpdate,
                            updateSource: locationManager.latestUpdateSource
                        )
                    }

                    // P4-05: Connectivity health indicator (only show when degraded or worse)
                    if isConnected && (locationManager.connectivityHealth == .degraded || locationManager.connectivityHealth == .unreachable) {
                        ConnectivityHealthBadge(health: locationManager.connectivityHealth)
                    }
                }
                .padding(16)
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
        // P2-01: Clear loading state once connection is established
        .task {
            // Wait a short time to allow connection to resolve
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(Animations.standard) {
                isInitialLoad = false
            }
        }
    }

    @MainActor
    private func performRefresh() async {
        guard !isRefreshing else { return }
        withAnimation(Animations.standard) {
            isRefreshing = true
        }
        _ = locationManager.requestUpdateWithFallback(force: true)
        try? await Task.sleep(for: .milliseconds(800))
        withAnimation(Animations.standard) {
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
                        .font(Typography.pageTitle)
                    Text("Live Tracking")
                        .font(Typography.label)
                        .foregroundStyle(.secondary)
                    Text(AppVersion.displayString)
                        .font(Typography.labelUppercase)
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
                    .font(.system(size: IconSize.lg, weight: .semibold))
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
                    .font(.system(size: IconSize.button, weight: .semibold))
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

// MARK: - Loading Skeleton Card (P2-01)

private struct LoadingSkeletonCard: View {
    private let theme = LiquidGlassTheme.current
    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        GlassCard(cornerRadius: theme.cornerRadiusCard, padding: 20) {
            HStack(spacing: 16) {
                // Animated circle placeholder
                Circle()
                    .fill(shimmerGradient)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 8) {
                    // Title placeholder
                    RoundedRectangle(cornerRadius: CornerRadius.xs / 2)
                        .fill(shimmerGradient)
                        .frame(width: 150, height: Spacing.lg)

                    // Subtitle placeholder
                    RoundedRectangle(cornerRadius: CornerRadius.xs / 2)
                        .fill(shimmerGradient)
                        .frame(width: 200, height: Spacing.md)
                }

                Spacer()

                // Spinner placeholder
                ProgressView()
                    .controlSize(.small)
            }
        }
        .task {
            // Shimmer animation
            while !Task.isCancelled {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
        .accessibilityLabel("Loading connection status")
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.primary.opacity(0.05),
                Color.primary.opacity(0.12),
                Color.primary.opacity(0.05)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
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
            // P3-04: Add status label for colorblind users
            QuickStatItem(
                icon: "scope",
                value: accuracy.map { MeasurementDisplay.accuracy($0, useMetric: useMetric) } ?? "-",
                color: accuracyColor,
                statusLabel: accuracyStatusLabel,
                accessibilityLabel: "GPS accuracy"
            )

            // P3-04: Add status label for colorblind users
            QuickStatItem(
                icon: batteryIcon,
                value: battery.map { String(format: "%.0f%%", $0 * 100) } ?? "-",
                color: batteryColor,
                statusLabel: batteryStatusLabel,
                accessibilityLabel: "Watch battery"
            )

            QuickStatItem(
                icon: "ruler",
                value: distance.map { MeasurementDisplay.distance($0, useMetric: useMetric) } ?? "-",
                color: .cyan,
                statusLabel: nil,
                accessibilityLabel: "Distance from you"
            )

            QuickStatItem(
                icon: "clock",
                value: timeAgoText,
                color: .purple,
                statusLabel: nil,
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

    // P3-04: Colorblind-accessible status labels
    private var accuracyStatusLabel: String? {
        guard let acc = accuracy else { return nil }
        if acc < 10 { return "Good" }
        if acc < 50 { return "Fair" }
        return "Poor"
    }

    private var batteryStatusLabel: String? {
        guard let bat = battery else { return nil }
        if bat > 0.5 { return "Good" }
        if bat > 0.2 { return "Fair" }
        return "Low"
    }
}

private struct QuickStatItem: View {
    let icon: String
    let value: String
    let color: Color
    // P3-04: Optional status label for colorblind accessibility
    let statusLabel: String?
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
        VStack(spacing: Spacing.xxs) {
            // Clean icon with subtle color
            Image(systemName: icon)
                .font(.system(size: IconSize.sm, weight: .medium))
                .foregroundStyle(color)

            Text(value)
                .font(Typography.dataSmall)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // P3-04: Status label for colorblind users
            if let statusLabel = statusLabel {
                Text(statusLabel)
                    .font(Typography.labelUppercase)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(statusLabel != nil ? "\(value), \(statusLabel!)" : value)
    }

    private var legacyStatItem: some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: IconSize.sm, weight: .medium))
                .foregroundStyle(color)

            Text(value)
                .font(Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // P3-04: Status label for colorblind users
            if let statusLabel = statusLabel {
                Text(statusLabel)
                    .font(Typography.labelUppercase)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(statusLabel != nil ? "\(value), \(statusLabel!)" : value)
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
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(statusColor.gradient)
                .frame(width: IconSize.xs, height: IconSize.xs)
                .shadow(color: statusColor.opacity(0.8), radius: Spacing.xs)
                .symbolEffect(.pulse, options: isReachable ? .repeating : .default, value: isReachable)

            Text(statusText)
                .font(Typography.label)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection status")
        .accessibilityValue(accessibilityStatus)
    }

    private var legacyBadge: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(statusColor)
                .frame(width: Spacing.sm, height: Spacing.sm)
                .shadow(color: statusColor.opacity(0.6), radius: Spacing.xxs)

            Text(statusText)
                .font(Typography.captionSmall.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
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
    @State private var addressText: String?

    var body: some View {
        GlassCard(cornerRadius: theme.cornerRadiusCard - 4, padding: Spacing.lg) {
            VStack(spacing: Spacing.md) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Label("Latitude", systemImage: "arrow.up")
                            .font(Typography.captionSmall.weight(.medium))
                            .foregroundStyle(.secondary)

                        Text(String(format: "%.6f°", latitude))
                            .font(.system(.callout, design: .monospaced).weight(.semibold))
                    }

                    Spacer()

                    Divider()
                        .frame(height: 36)
                        .padding(.horizontal, Spacing.lg)

                    Spacer()

                    VStack(alignment: .trailing, spacing: Spacing.xxs) {
                        Label("Longitude", systemImage: "arrow.right")
                            .font(Typography.captionSmall.weight(.medium))
                            .foregroundStyle(.secondary)

                        Text(String(format: "%.6f°", longitude))
                            .font(.system(.callout, design: .monospaced).weight(.semibold))
                    }
                }

                // P6-03: Reverse geocoded address
                if let address = addressText {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "mappin.circle.fill")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)

                        Text(address)
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        Spacer()

                        ShareLink(
                            item: String(format: "%.6f, %.6f", latitude, longitude)
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pet coordinates")
        .accessibilityValue(
            (addressText.map { "\($0). " } ?? "") +
            "Latitude \(String(format: "%.4f", latitude)) degrees, Longitude \(String(format: "%.4f", longitude)) degrees"
        )
        .task(id: "\(String(format: "%.4f", latitude)),\(String(format: "%.4f", longitude))") {
            await reverseGeocode()
        }
    }

    private func reverseGeocode() async {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let parts = [placemark.name, placemark.locality, placemark.administrativeArea].compactMap { $0 }
                if !parts.isEmpty {
                    addressText = parts.joined(separator: ", ")
                }
            }
        } catch {
            // Geocoding failure is non-critical; coordinates remain visible
        }
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
        GlassCard(cornerRadius: theme.cornerRadiusButton, padding: Spacing.md) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(theme.accentPrimary.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(theme.accentPrimary.gradient)
                }

                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text("Trail History")
                        .font(Typography.sectionTitle)

                    Text("\(count) of \(limit) locations")
                        .font(Typography.caption)
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
                        .font(Typography.labelUppercase)
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
        HStack(spacing: Spacing.sm) {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(Typography.caption)
                .foregroundStyle(.secondary)

            Text(message)
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
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
        HStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange.gradient)

            Text(message)
                .font(Typography.caption)
                .foregroundStyle(.primary)
                .lineLimit(3)

            Spacer()
        }
        .padding(Spacing.md)
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

// MARK: - Connectivity Health Badge (P4-05)

private struct ConnectivityHealthBadge: View {
    let health: PetLocationManager.ConnectivityHealth

    private var statusColor: Color {
        switch health {
        case .excellent:
            return .green
        case .degraded:
            return .yellow
        case .unreachable:
            return .red
        case .unknown:
            return .gray
        }
    }

    private var statusText: String {
        switch health {
        case .excellent:
            return "Excellent"
        case .degraded:
            return "Degraded"
        case .unreachable:
            return "Unreachable"
        case .unknown:
            return "Unknown"
        }
    }

    private var statusIcon: String {
        switch health {
        case .excellent:
            return "antenna.radiowaves.left.and.right"
        case .degraded:
            return "exclamationmark.triangle.fill"
        case .unreachable:
            return "wifi.slash"
        case .unknown:
            return "questionmark.circle"
        }
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
        HStack(spacing: Spacing.sm) {
            Image(systemName: statusIcon)
                .font(.system(size: IconSize.xs, weight: .semibold))
                .foregroundStyle(statusColor.gradient)

            Text(statusText)
                .font(Typography.label)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connectivity health")
        .accessibilityValue(statusText)
    }

    private var legacyBadge: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: statusIcon)
                .font(Typography.captionSmall.weight(.semibold))
                .foregroundStyle(statusColor)

            Text(statusText)
                .font(Typography.captionSmall.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connectivity health")
        .accessibilityValue(statusText)
    }
}

#endif
