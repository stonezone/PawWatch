//
//  PetStatusCard.swift
//  pawWatch
//
//  Purpose: Liquid Glass status card displaying pet GPS metadata.
//           Shows location, accuracy, battery, connection, and distance.
//
//  Author: Created for pawWatch
//  Created: 2025-11-05
//  Swift: 6.2
//  Platform: iOS 26.1+
//

#if os(iOS)
import SwiftUI

/// Liquid Glass status card showing pet GPS metadata.
///
/// Displays:
/// - Last known coordinates (lat/lon)
/// - Time since last update
/// - GPS accuracy in meters
/// - Watch battery level
/// - Connection status
/// - Distance from owner
///
/// Design: iOS 26 Liquid Glass with frosted background and spring animations.
public struct PetStatusCard: View {

    // MARK: - Dependencies

    /// Location manager providing pet GPS data
    @Environment(PetLocationManager.self) private var locationManager
    let useMetricUnits: Bool
    private let theme = LiquidGlassTheme.current

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 24) {
            // Header with enhanced visual hierarchy
            HStack(alignment: .center) {
                ZStack {
                    Circle()
                        .fill(theme.accentPrimary.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "location.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.accentPrimary.gradient)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pet Location")
                        .font(.title3.bold())

                    if let seconds = locationManager.secondsSinceLastUpdate {
                        Text(SharedUtilities.timeAgoText(seconds))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if locationManager.latestLocation != nil {
                        Text(locationManager.latestUpdateSource.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Connection status indicator
                ConnectionStatusView(
                    isConnected: locationManager.isWatchConnected,
                    isReachable: locationManager.isWatchReachable
                )
            }

            // Coordinates with improved layout
            if let location = locationManager.latestLocation {
                CoordinatesRow(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            } else {
                NoDataView()
            }

            // Enhanced metadata grid
            if let location = locationManager.latestLocation {
                let batteryValue = locationManager.watchBatteryFraction ?? location.batteryFraction
                MetadataGrid(
                    accuracy: location.horizontalAccuracyMeters,
                    battery: batteryValue,
                    secondsSinceUpdate: locationManager.secondsSinceLastUpdate,
                    distanceFromOwner: locationManager.distanceFromOwner,
                    useMetricUnits: useMetricUnits
                )
            }

            ForegroundDistanceNotice(message: locationManager.distanceUsageBlurb)

            // Error message
            if let error = locationManager.errorMessage {
                ErrorBanner(message: error)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: locationManager.latestLocation)
    }

}

private struct ForegroundDistanceNotice: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Connection Status View

/// Connection status indicator with Liquid Glass effect.
struct ConnectionStatusView: View {
    let isConnected: Bool
    let isReachable: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor.gradient)
                .frame(width: 10, height: 10)
                .shadow(color: statusColor.opacity(0.6), radius: 4)
                .overlay(
                    Circle()
                        .strokeBorder(statusColor.opacity(0.3), lineWidth: 2)
                        .blur(radius: 1)
                )

            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.1))
        .clipShape(Capsule())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isConnected)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isReachable)
    }

    private var statusColor: Color {
        if !isConnected { return .red }
        if !isReachable { return .orange }
        return .green
    }

    private var statusText: String {
        if !isConnected { return "Disconnected" }
        if !isReachable { return "Paired" }
        return "Connected"
    }
}

// MARK: - Coordinates Row

/// Displays latitude/longitude with improved visual hierarchy.
struct CoordinatesRow: View {
    let latitude: Double
    let longitude: Double

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Latitude")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(String(format: "%.6f°", latitude))
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Divider()
                .frame(height: 40)
                .opacity(0.3)

            VStack(alignment: .trailing, spacing: 6) {
                Text("Longitude")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(String(format: "%.6f°", longitude))
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

// MARK: - No Data View

/// Placeholder when no GPS data received yet.
struct NoDataView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 48))
                .foregroundStyle(.gray.gradient)
                .symbolEffect(.pulse)

            Text("Waiting for GPS data...")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Make sure Apple Watch app is running")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Metadata Grid

/// Grid showing accuracy, battery, time, and distance metrics with improved layout.
struct MetadataGrid: View {
    let accuracy: Double
    let battery: Double
    let secondsSinceUpdate: TimeInterval?
    let distanceFromOwner: Double?
    let useMetricUnits: Bool

    private let theme = LiquidGlassTheme.current

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            // GPS Accuracy
            MetadataItem(
                icon: "scope",
                title: "Accuracy",
                value: MeasurementDisplay.accuracy(accuracy, useMetric: useMetricUnits),
                color: accuracyColor,
                isHighlighted: accuracy < 10
            )

            // Battery Level
            MetadataItem(
                icon: batteryIcon,
                title: "Battery",
                value: String(format: "%.0f%%", battery * 100),
                color: batteryColor,
                isHighlighted: battery > 0.5
            )

            // Time Since Update
            MetadataItem(
                icon: "clock.fill",
                title: "Updated",
                value: timeAgoText,
                color: theme.accentPrimary,
                isHighlighted: false
            )

            // Distance from Owner
            MetadataItem(
                icon: "ruler.fill",
                title: "Distance",
                value: distanceText,
                color: theme.accentSecondary,
                isHighlighted: false
            )
        }
    }

    // MARK: - Helpers

    /// Accuracy color: green (<10m), yellow (<50m), red (>=50m)
    private var accuracyColor: Color {
        SharedUtilities.accuracyColor(for: accuracy)
    }

    /// Battery color: green (>50%), yellow (20-50%), red (<20%)
    private var batteryColor: Color {
        SharedUtilities.batteryColor(for: battery)
    }

    /// Dynamic battery icon based on level
    private var batteryIcon: String {
        SharedUtilities.batteryIcon(for: battery)
    }

    /// Relative time string (e.g., "5s ago", "2m ago")
    private var timeAgoText: String {
        guard let seconds = secondsSinceUpdate else { return "Unknown" }
        return SharedUtilities.timeAgoText(seconds)
    }

    /// Distance text (e.g., "15.2 m", "1.2 km", "Unknown")
    private var distanceText: String {
        guard let distance = distanceFromOwner else { return "Unknown" }
        return MeasurementDisplay.distance(distance, useMetric: useMetricUnits)
    }
}

// MARK: - Metadata Item

/// Individual metadata cell with enhanced glass styling.
struct MetadataItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 10) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(color.opacity(isHighlighted ? 0.2 : 0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color.gradient)
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(value)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(isHighlighted ? 0.08 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            color.opacity(isHighlighted ? 0.3 : 0.15),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: color.opacity(isHighlighted ? 0.15 : 0.05),
            radius: 8,
            x: 0,
            y: 4
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: value)
    }
}

// MARK: - Error Banner

/// Error message banner with enhanced Liquid Glass effect.
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange.gradient)

            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }
}
#endif
