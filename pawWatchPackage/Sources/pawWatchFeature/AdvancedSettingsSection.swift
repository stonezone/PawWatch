#if os(iOS)
import SwiftUI

/// Advanced settings section with session stats, developer options, and about info
@MainActor
struct AdvancedSettingsSection: View {
    @Environment(PetLocationManager.self) private var locationManager

    @Binding var showAdvanced: Bool
    @Binding var showDeveloperSheet: Bool

    var body: some View {
        if #available(iOS 26, *) {
            modernAdvancedSection
        } else {
            legacyAdvancedSection
        }
    }

    @available(iOS 26, *)
    private var modernAdvancedSection: some View {
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(spacing: 14) {
                sessionStatsSection
                developerSection
                aboutSection
            }
            .padding(.top, Spacing.sm)
        } label: {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .foregroundStyle(.secondary)
                    .symbolEffect(.rotate, value: showAdvanced)
                Text("Developer & Diagnostics")
                    .font(.headline)
            }
        }
        .padding(Spacing.Component.cardPadding)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: CornerRadius.lg))
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
    }

    private var legacyAdvancedSection: some View {
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(spacing: 14) {
                sessionStatsSection
                developerSection
                aboutSection
            }
            .padding(.top, Spacing.sm)
        } label: {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .foregroundStyle(.secondary)
                Text("Developer & Diagnostics")
                    .font(.headline)
            }
        }
        .padding(Spacing.Component.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Session Stats Section
    @ViewBuilder
    private var sessionStatsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Session Stats")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            let summary = locationManager.sessionSummary
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                StatCell(title: "Fixes", value: "\(summary.fixCount)")
                StatCell(title: "Avg Interval", value: formatSeconds(summary.averageIntervalSec))
                StatCell(title: "Median Acc", value: formatMeters(summary.medianAccuracy))
                StatCell(title: "Duration", value: formatDuration(summary.durationSec))
            }

            HStack {
                if let exportURL = locationManager.sessionShareURL() {
                    ShareLink(item: exportURL) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                Button("Reset", role: .destructive) {
                    locationManager.resetSessionStats()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(Spacing.md)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    // MARK: - Developer Section
    @ViewBuilder
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Developer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack {
                Text("Extended Runtime")
                    .font(.caption)
                Spacer()
                Text(locationManager.runtimeOptimizationsEnabled ? "Enabled" : "Disabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Open Developer Settings") {
                showDeveloperSheet = true
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    // MARK: - About Section
    @ViewBuilder
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("About")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack {
                Text("Version")
                    .font(.caption)
                Spacer()
                Text(appVersion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    // MARK: - Helper Functions
    private func formatSeconds(_ value: Double) -> String {
        guard value > 0 else { return "-" }
        return String(format: "%.1f s", value)
    }

    private func formatMeters(_ value: Double) -> String {
        guard value > 0 else { return "-" }
        return String(format: "%.1f m", value)
    }

    private func formatDuration(_ value: Double) -> String {
        guard value > 0 else { return "-" }
        let minutes = Int(value / 60)
        let seconds = Int(value.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}

#endif
