#if os(iOS)
import SwiftUI

/// History view displaying recent location fixes in a list
@MainActor
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

#endif
