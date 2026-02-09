#if os(iOS)
import SwiftUI

/// Connection status card showing watch connectivity and battery
@MainActor
struct ConnectionStatusCard: View {
    @Environment(PetLocationManager.self) private var locationManager

    var body: some View {
        if #available(iOS 26, *) {
            modernConnectionStatusCard
        } else {
            legacyConnectionStatusCard
        }
    }

    @available(iOS 26, *)
    private var modernConnectionStatusCard: some View {
        HStack(spacing: Spacing.md) {
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

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(connectionTitle)
                    .font(.headline)

                Text(connectionSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let battery = locationManager.watchBatteryFraction {
                    HStack(spacing: 4) {
                        Image(systemName: SharedUtilities.batteryIcon(for: battery))
                            .font(.caption2)
                            .foregroundStyle(SharedUtilities.batteryColor(for: battery))
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
        .padding(Spacing.Component.cardPadding)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: CornerRadius.lg))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }

    private var legacyConnectionStatusCard: some View {
        GlassCard(cornerRadius: CornerRadius.lg, padding: Spacing.Component.cardPadding) {
            HStack(spacing: Spacing.md) {
                // Watch icon with status
                ZStack {
                    Circle()
                        .fill(connectionColor.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: "applewatch")
                        .font(.title)
                        .foregroundStyle(connectionColor.gradient)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(connectionTitle)
                        .font(.headline)

                    Text(connectionSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let battery = locationManager.watchBatteryFraction {
                        HStack(spacing: 4) {
                            Image(systemName: SharedUtilities.batteryIcon(for: battery))
                                .font(.caption2)
                                .foregroundStyle(SharedUtilities.batteryColor(for: battery))
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
}

#endif
