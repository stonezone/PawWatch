#if os(iOS)
import SwiftUI

/// Distance alerts configuration section
@MainActor
struct DistanceAlertsSection: View {
    @Environment(PetLocationManager.self) private var locationManager

    @Binding var useMetricUnits: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Toggle("Enable Background Alerts", isOn: Binding(
                get: { locationManager.distanceAlertsEnabled },
                set: { locationManager.setDistanceAlertsEnabled($0) }
            ))

            if locationManager.distanceAlertsEnabled {
                Divider().opacity(0.3)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Alert Distance")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    let currentMeters = locationManager.distanceAlertThreshold
                    let currentFeet = currentMeters * 3.28084

                    HStack {
                        Text(useMetricUnits ? "\(Int(currentMeters))m" : "\(Int(currentFeet))ft")
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                        Spacer()
                    }

                    Slider(
                        value: Binding(
                            get: { locationManager.distanceAlertThreshold },
                            set: { locationManager.setDistanceAlertThreshold($0) }
                        ),
                        in: PetLocationManager.distanceAlertThresholdRange,
                        step: 10
                    )

                    // Min/Max labels
                    HStack {
                        Text(useMetricUnits ? "\(Int(PetLocationManager.distanceAlertThresholdRange.lowerBound))m" : "\(Int(PetLocationManager.distanceAlertThresholdRange.lowerBound * 3.28084))ft")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(useMetricUnits ? "\(Int(PetLocationManager.distanceAlertThresholdRange.upperBound))m" : "\(Int(PetLocationManager.distanceAlertThresholdRange.upperBound * 3.28084))ft")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    // Contextual description
                    Text(distanceContextDescription(for: currentMeters))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            } else {
                Text("Enable alerts to get notified when your pet moves too far away")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func distanceContextDescription(for meters: Double) -> String {
        switch meters {
        case ..<50:
            return "Very close — for indoor or small yard"
        case 50..<100:
            return "Neighborhood walk distance"
        case 100..<300:
            return "Park or open area"
        default:
            return "Wide area — large property or hiking"
        }
    }
}

#endif
