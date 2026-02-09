//
//  BatteryAnalyticsView.swift
//  pawWatch
//
//  Purpose: Visualizes battery impact data showing which features consume the most power.
//           Provides insights and recommendations for optimizing battery life.
//
//  Author: Created for pawWatch
//  Created: 2026-02-09
//  Swift: 6.2
//  Platform: iOS 26.1+
//

import SwiftUI

#if os(iOS)
@MainActor
public struct BatteryAnalyticsView: View {
    @State private var selectedPeriod: BatteryReportPeriod = .last24Hours
    @State private var report: BatteryImpactReport?
    @State private var isLoading = false
    @State private var activeSessions: [BatteryActivity] = []

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period Selector
                periodPicker

                if isLoading {
                    ProgressView("Analyzing battery impact...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let report = report {
                    // Summary Card
                    summaryCard(for: report)

                    // Active Sessions
                    if !activeSessions.isEmpty {
                        activeSessionsCard
                    }

                    // Activity Breakdown
                    activityBreakdownSection(for: report)

                    // Recommendations
                    recommendationsSection(for: report)
                } else {
                    emptyStateView
                }
            }
            .padding()
        }
        .navigationTitle("Battery Analytics")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task {
            await loadReport()
            await loadActiveSessions()
        }
        .refreshable {
            await loadReport()
            await loadActiveSessions()
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Time Period", selection: $selectedPeriod) {
            ForEach(BatteryReportPeriod.allCases) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedPeriod) { _, _ in
            Task {
                await loadReport()
            }
        }
    }

    // MARK: - Summary Card

    private func summaryCard(for report: BatteryImpactReport) -> some View {
        VStack(spacing: 16) {
            // Total battery consumed
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "applewatch.radiowaves.left.and.right")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text("Apple Watch Battery Impact")
                        .font(.headline)
                    Spacer()
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.1f%%", report.totalBatteryConsumed))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("used over " + selectedPeriod.displayName.lowercased())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                    Spacer()
                }
            }

            Divider()

            // Top consumer
            if let topConsumer = report.topConsumer {
                HStack {
                    Image(systemName: topConsumer.activity.systemIcon)
                        .font(.title3)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading) {
                        Text("Top Consumer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(topConsumer.activity.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(String(format: "%.1f%%", topConsumer.totalBatteryConsumed))
                            .font(.headline)
                        Text("\(topConsumer.totalEvents) events")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        #if os(iOS) || os(watchOS)
        .background(Color(.systemBackground))
        #else
        .background(Color(white: 0.95))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Active Sessions

    private var activeSessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Active Now", systemImage: "waveform.path.ecg")
                .font(.headline)
                .foregroundStyle(.green)

            ForEach(activeSessions, id: \.rawValue) { activity in
                HStack {
                    Image(systemName: activity.systemIcon)
                        .foregroundStyle(.green)
                    Text(activity.displayName)
                        .font(.subheadline)
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Activity Breakdown

    private func activityBreakdownSection(for report: BatteryImpactReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Battery Impact by Feature")
                .font(.headline)
                .padding(.horizontal)

            ForEach(report.sortedByImpact) { stats in
                activityRow(for: stats, totalBattery: report.totalBatteryConsumed)
            }
        }
        .padding(.vertical)
        #if os(iOS) || os(watchOS)
        .background(Color(.systemBackground))
        #else
        .background(Color(white: 0.95))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private func activityRow(for stats: BatteryActivityStats, totalBattery: Double) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: stats.activity.systemIcon)
                    .font(.title3)
                    .foregroundStyle(colorForActivity(stats.activity))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stats.activity.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(stats.totalEvents) events • \(formatDuration(stats.totalDuration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f%%", stats.totalBatteryConsumed))
                        .font(.headline)
                    Text(String(format: "%.1f%%/hr", stats.averageDrainRate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Battery consumption bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorForActivity(stats.activity))
                        .frame(
                            width: max(0, geometry.size.width * CGFloat(stats.totalBatteryConsumed / max(totalBattery, 0.1))),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Recommendations

    private func recommendationsSection(for report: BatteryImpactReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optimization Tips")
                .font(.headline)

            let recommendations = generateRecommendations(from: report)

            ForEach(recommendations.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(recommendations[index].title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(recommendations[index].description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    if let action = recommendations[index].action {
                        actionButton(for: action)
                            .padding(.leading, 32)
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        #if os(iOS) || os(watchOS)
        .background(Color(.systemBackground))
        #else
        .background(Color(white: 0.95))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    @ViewBuilder
    private func actionButton(for action: RecommendationAction) -> some View {
        switch action {
        case .switchToBatterySaver:
            Button {
                handleBatterySaverAction()
            } label: {
                Label("Switch to Battery Saver", systemImage: "leaf.fill")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

        case .openSettings:
            Button {
                handleOpenSettingsAction()
            } label: {
                Label("Open Settings", systemImage: "gear")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func handleBatterySaverAction() {
        // Switch to battery saver mode via AppStorage
        // "saver" is the raw value for TrackingMode.saver
        UserDefaults.standard.set("saver", forKey: "trackingMode")
    }

    private func handleOpenSettingsAction() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Battery Data Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Battery impact data will appear here as you use the app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Helper Functions

    private func colorForActivity(_ activity: BatteryActivity) -> Color {
        switch activity {
        case .gpsActive:
            return .blue
        case .connectivityRelay:
            return .purple
        case .cloudKitUpload, .cloudKitDownload:
            return .cyan
        case .idle:
            return .green
        case .geofenceMonitoring:
            return .orange
        case .backgroundRefresh:
            return .pink
        case .motionProcessing:
            return .indigo
        case .watchCommunication:
            return .teal
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private struct Recommendation {
        let title: String
        let description: String
        let action: RecommendationAction?

        init(title: String, description: String, action: RecommendationAction? = nil) {
            self.title = title
            self.description = description
            self.action = action
        }
    }

    private enum RecommendationAction {
        case switchToBatterySaver
        case openSettings
    }

    private func generateRecommendations(from report: BatteryImpactReport) -> [Recommendation] {
        var recommendations: [Recommendation] = []

        // GPS optimization
        if let gpsStats = report.activityStats.first(where: { $0.activity == .gpsActive }),
           gpsStats.averageDrainRate > 10 {
            recommendations.append(Recommendation(
                title: "Optimize GPS Usage",
                description: "GPS is consuming \(String(format: "%.1f%%", gpsStats.averageDrainRate))/hr. Consider using Battery Saver mode when high precision isn't needed.",
                action: .switchToBatterySaver
            ))
        }

        // CloudKit optimization
        if let cloudKitUploadStats = report.activityStats.first(where: { $0.activity == .cloudKitUpload }),
           cloudKitUploadStats.totalEvents > 100 {
            recommendations.append(Recommendation(
                title: "Reduce CloudKit Syncs",
                description: "\(cloudKitUploadStats.totalEvents) sync operations recorded. Consider increasing sync intervals for better battery life."
            ))
        }

        // Connectivity optimization
        if let connectivityStats = report.activityStats.first(where: { $0.activity == .connectivityRelay }),
           connectivityStats.averageDrainRate > 8 {
            recommendations.append(Recommendation(
                title: "Watch Connectivity Impact",
                description: "Watch communication is consuming significant battery. Ensure watch is nearby to reduce transmission power."
            ))
        }

        // Background refresh optimization
        if let backgroundStats = report.activityStats.first(where: { $0.activity == .backgroundRefresh }),
           backgroundStats.totalEvents > 50 {
            recommendations.append(Recommendation(
                title: "Background Activity",
                description: "Frequent background refreshes detected. Check Settings > General > Background App Refresh if battery life is critical.",
                action: .openSettings
            ))
        }

        // If no specific recommendations, provide general tip
        if recommendations.isEmpty {
            recommendations.append(Recommendation(
                title: "Battery Usage Looks Good",
                description: "Your battery consumption is well-optimized. Continue using balanced settings for best results."
            ))
        }

        return recommendations
    }

    // MARK: - Data Loading

    private func loadReport() async {
        isLoading = true
        defer { isLoading = false }

        report = await BatteryProfiler.shared.generateReport(for: selectedPeriod)
    }

    private func loadActiveSessions() async {
        activeSessions = await BatteryProfiler.shared.getActiveSessions()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BatteryAnalyticsView()
    }
}
#endif
