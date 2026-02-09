#if os(iOS)
import SwiftUI

/// Tracking mode configuration section with emergency cadence and trail history
@MainActor
struct TrackingModeSection: View {
    @Environment(PetLocationManager.self) private var locationManager

    @Binding var trackingModeRaw: String
    @State private var modeChangeTask: Task<Void, Never>?

    private var emergencyCadenceBinding: Binding<EmergencyCadencePreset> {
        Binding(
            get: { locationManager.emergencyCadencePreset },
            set: { locationManager.setEmergencyCadencePreset($0) }
        )
    }

    var body: some View {
        let selectedMode = TrackingMode(rawValue: trackingModeRaw) ?? .auto

        VStack(alignment: .leading, spacing: Spacing.md) {
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

            VStack(alignment: .leading, spacing: Spacing.md) {
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
            _ = locationManager.requestUpdateWithFallback(force: true)
        } label: {
            Label("Request Fresh Location", systemImage: "location.fill")
                .frame(maxWidth: .infinity)
        }
        .glassButtonStyle()
    }
}

#endif
