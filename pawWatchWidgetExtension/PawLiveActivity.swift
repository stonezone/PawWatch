import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PawLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PawActivityAttributes.self) { context in
            LiveActivityLockView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    MetricLabel(title: "Latency", value: "\(context.state.latencyMs) ms")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    MetricLabel(title: "Drain", value: String(format: "%.1f%%/h", context.state.batteryDrainPerHour))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ReachabilityLabel(reachable: context.state.reachable)
                }
            } compactLeading: {
                Text("\(min(999, context.state.latencyMs))")
                    .monospacedDigit()
            } compactTrailing: {
                Image(systemName: context.state.reachable ? "antenna.radiowaves.left.and.right" : "wifi.exclamationmark")
            } minimal: {
                Image(systemName: context.state.reachable ? "checkmark.circle" : "xmark.circle")
            }
        }
    }
}

// MARK: - Views

private struct LiveActivityLockView: View {
    let state: PawActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            ReachabilityLabel(reachable: state.reachable)
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                MetricLabel(title: "Latency", value: "\(state.latencyMs) ms")
                MetricLabel(title: "Drain", value: String(format: "%.1f%% per hr", state.batteryDrainPerHour))
            }
            .font(.subheadline)

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .activityBackgroundTint(Color(.sRGBLinear, white: 1, opacity: 0.12))
        .activitySystemActionForegroundColor(.primary)
    }
}

private struct MetricLabel: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }
}

private struct ReachabilityLabel: View {
    let reachable: Bool

    var body: some View {
        Label(reachable ? "Reachable" : "Offline",
              systemImage: reachable ? "antenna.radiowaves.left.and.right" : "wifi.exclamationmark")
            .font(.caption)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(reachable ? .green : .orange)
    }
}

// MARK: - Preview
#if DEBUG
@available(iOS 18.0, *)
#Preview("Lock Screen") {
    LiveActivityLockView(
        state: .init(latencyMs: 137, batteryDrainPerHour: 2.6, reachable: true)
    )
}
#endif
