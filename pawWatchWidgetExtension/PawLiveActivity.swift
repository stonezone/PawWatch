import ActivityKit
import SwiftUI
import WidgetKit

private enum LiveActivityLinks {
    static let openApp = URL(string: "pawwatch://open-app")!
    static let stopTracking = URL(string: "pawwatch://stop-tracking")!
}

@main
struct PawLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PawActivityAttributes.self) { context in
            LiveActivityLockView(state: context.state)
                .widgetURL(LiveActivityLinks.openApp)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    MetricLabel(title: "Latency", value: "\(context.state.latencyMs) ms")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    MetricLabel(title: "Drain", value: String(format: "%.1f%%/h", context.state.batteryDrainPerHour))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        if let alert = context.state.alert {
                            AlertBadge(alert: alert)
                        } else {
                            ReachabilityLabel(reachable: context.state.reachable)
                        }
                        Spacer(minLength: 0)
                        LiveActivityActions()
                    }
                }
            } compactLeading: {
                Text("\(min(999, context.state.latencyMs))")
                    .monospacedDigit()
            } compactTrailing: {
                if let alert = context.state.alert {
                    Image(systemName: alert == .unreachable ? "wifi.exclamationmark" : "bolt.fill")
                } else {
                    Image(systemName: context.state.reachable ? "antenna.radiowaves.left.and.right" : "wifi.exclamationmark")
                }
            } minimal: {
                if let alert = context.state.alert {
                    Image(systemName: alert == .unreachable ? "wifi.exclamationmark" : "bolt.fill")
                } else {
                    Image(systemName: context.state.reachable ? "checkmark.circle" : "xmark.circle")
                }
            }
        }
    }
}

// MARK: - Views

private struct LiveActivityLockView: View {
    let state: PawActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            if let alert = state.alert {
                AlertBadge(alert: alert)
            } else {
                ReachabilityLabel(reachable: state.reachable)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                MetricLabel(title: "Latency", value: "\(state.latencyMs) ms")
                MetricLabel(title: "Drain", value: String(format: "%.1f%% per hr", state.batteryDrainPerHour))
            }
            .font(.subheadline)

            Spacer()

            LiveActivityActions()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .activityBackgroundTint(Color(.sRGBLinear, white: 1, opacity: 0.12))
        .activitySystemActionForegroundColor(.primary)
    }
}

private struct LiveActivityActions: View {
    var body: some View {
        HStack(spacing: 8) {
            Link(destination: LiveActivityLinks.stopTracking) {
                Label("Stop", systemImage: "stop.fill")
            }
            .tint(.red)
            .buttonStyle(.borderedProminent)
            .font(.caption)

            Link(destination: LiveActivityLinks.openApp) {
                Label("Open", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
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

private struct AlertBadge: View {
    let alert: PawActivityAttributes.AlertState

    var body: some View {
        switch alert {
        case .unreachable:
            Label("Offline", systemImage: "wifi.exclamationmark")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.15), in: Capsule())
                .foregroundStyle(.red)
        case .highDrain:
            Label("High Drain", systemImage: "bolt.fill")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15), in: Capsule())
                .foregroundStyle(.orange)
        }
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

@available(iOS 18.0, *)
#Preview("Lock Screen — High Drain") {
    LiveActivityLockView(
        state: .init(latencyMs: 95, batteryDrainPerHour: 5.4, reachable: true, alert: .highDrain)
    )
}

@available(iOS 18.0, *)
#Preview("Lock Screen — Offline") {
    LiveActivityLockView(
        state: .init(latencyMs: 0, batteryDrainPerHour: 1.1, reachable: false, alert: .unreachable)
    )
}
#endif
