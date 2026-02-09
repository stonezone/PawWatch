//
//  WatchSettingsView.swift
//  pawWatch Watch App
//
//  Purpose: Watch-specific settings view for battery optimizations and auto-lock
//  Created: 2025-12-15
//

import SwiftUI
import pawWatchFeature

// MARK: - Watch Settings View

struct WatchSettingsView: View {
    @Binding var optimizationsEnabled: Bool
    @Binding var autoLockEnabled: Bool
    @State private var hasScrolled = false

    var body: some View {
        List {
            Section("Battery") {
                Toggle("Runtime Guard & Smart Polling", isOn: $optimizationsEnabled)
                    .accessibilityLabel("Enable runtime guard and smart polling")
                    .accessibilityHint("Keeps workout alive with extended runtime session and reduces GPS frequency when stationary or low battery")
                Text("Keeps the workout alive with WKExtendedRuntimeSession and slows GPS when stationary or low battery.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if !hasScrolled {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                        Text("Scroll for more")
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
            }

            Section("Water Lock") {
                Toggle("Auto-Lock on Start", isOn: $autoLockEnabled)
                    .accessibilityLabel("Enable auto-lock on start")
                    .accessibilityHint("Automatically locks the tracker when tracking starts. Rotate Digital Crown to unlock")
                Text("Automatically locks the tracker when you start tracking. Rotate the Digital Crown to unlock.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .onAppear {
                hasScrolled = true
            }

            // P1-01: Version number moved from main ContentView
            Section {
                HStack {
                    Text("Version")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(AppVersion.displayString)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.carousel)
        .navigationTitle("Settings")
    }
}
