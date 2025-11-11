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
    @EnvironmentObject private var locationManager: PetLocationManager
    let useMetricUnits: Bool

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "location.fill")
                    .font(.title2)
                    .foregroundStyle(.blue.gradient)

                Text("Pet Location")
                    .font(.title2.bold())

                Spacer()

                // Connection status indicator
                ConnectionStatusView(
                    isConnected: locationManager.isWatchConnected,
                    isReachable: locationManager.isWatchReachable
                )
            }

            // Coordinates
            if let location = locationManager.latestLocation {
                CoordinatesRow(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            } else {
                NoDataView()
            }

            Divider()

            // Metadata grid
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

            // Error message
            if let error = locationManager.errorMessage {
                ErrorBanner(message: error)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: locationManager.latestLocation)
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

            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .animation(.spring(response: 0.3), value: isConnected)
        .animation(.spring(response: 0.3), value: isReachable)
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

/// Displays latitude/longitude with copy-to-clipboard functionality.
struct CoordinatesRow: View {
    let latitude: Double
    let longitude: Double

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Latitude")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.6f°", latitude))
                    .font(.system(.body, design: .monospaced).weight(.medium))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Longitude")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.6f°", longitude))
                    .font(.system(.body, design: .monospaced).weight(.medium))
            }
        }
        .padding(.vertical, 8)
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

            Text("Waiting for GPS data...")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Make sure Apple Watch app is running")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Metadata Grid

/// Grid showing accuracy, battery, time, and distance metrics.
struct MetadataGrid: View {
    let accuracy: Double
    let battery: Double
    let secondsSinceUpdate: TimeInterval?
    let distanceFromOwner: Double?
    let useMetricUnits: Bool

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            // GPS Accuracy
            MetadataItem(
                icon: "scope",
                title: "Accuracy",
                value: MeasurementDisplay.accuracy(accuracy, useMetric: useMetricUnits),
                color: accuracyColor
            )

            // Battery Level
            MetadataItem(
                icon: "battery.100",
                title: "Battery",
                value: String(format: "%.0f%%", battery * 100),
                color: batteryColor
            )

            // Time Since Update
            MetadataItem(
                icon: "clock.fill",
                title: "Updated",
                value: timeAgoText,
                color: .blue
            )

            // Distance from Owner
            MetadataItem(
                icon: "ruler.fill",
                title: "Distance",
                value: distanceText,
                color: .purple
            )
        }
    }

    // MARK: - Helpers

    /// Accuracy color: green (<10m), yellow (<50m), red (>=50m)
    private var accuracyColor: Color {
        if accuracy < 10 { return .green }
        if accuracy < 50 { return .yellow }
        return .red
    }

    /// Battery color: green (>50%), yellow (20-50%), red (<20%)
    private var batteryColor: Color {
        if battery > 0.5 { return .green }
        if battery > 0.2 { return .yellow }
        return .red
    }

    /// Relative time string (e.g., "5s ago", "2m ago")
    private var timeAgoText: String {
        guard let seconds = secondsSinceUpdate else { return "Unknown" }

        if seconds < 60 {
            return String(format: "%.0fs ago", seconds)
        } else if seconds < 3600 {
            return String(format: "%.0fm ago", seconds / 60)
        } else {
            return String(format: "%.1fh ago", seconds / 3600)
        }
    }

    /// Distance text (e.g., "15.2 m", "1.2 km", "Unknown")
    private var distanceText: String {
        guard let distance = distanceFromOwner else { return "Unknown" }
        return MeasurementDisplay.distance(distance, useMetric: useMetricUnits)
    }
}

// MARK: - Metadata Item

/// Individual metadata cell with icon, title, and value.
struct MetadataItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color.gradient)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.spring(response: 0.3), value: value) // Liquid animation on value change
    }
}

// MARK: - Error Banner

/// Error message banner with Liquid Glass effect.
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange.gradient)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer()
        }
        .padding(12)
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .transition(.scale.combined(with: .opacity))
    }
}
#endif
