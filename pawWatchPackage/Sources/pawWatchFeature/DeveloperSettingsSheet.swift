#if os(iOS)
import SwiftUI

/// Developer settings sheet for advanced tracking configuration
@MainActor
struct DeveloperSettingsSheet: View {
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

#endif
