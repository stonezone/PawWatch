#if os(iOS)
import SwiftUI

/// Dashboard view showing live tracking status, map, and quick stats
@MainActor
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

#endif
