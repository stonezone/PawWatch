import SwiftUI
import WidgetKit
import pawWatchFeature

struct WatchWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: PerformanceSnapshot
}

struct WatchWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchWidgetEntry {
        WatchWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchWidgetEntry) -> Void) {
        completion(WatchWidgetEntry(date: .now, snapshot: PerformanceSnapshotStore.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchWidgetEntry>) -> Void) {
        let snapshot = PerformanceSnapshotStore.load() ?? .placeholder
        let entry = WatchWidgetEntry(date: .now, snapshot: snapshot)
        let next = Date().addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct WatchWidgetRectangularView: View {
    let snapshot: PerformanceSnapshot

    var body: some View {
        HStack(spacing: 8) {
            statusIndicator
            VStack(alignment: .leading, spacing: 2) {
                Text("Latency")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(snapshot.latencyMs) ms")
                    .font(.caption.monospacedDigit())
                Text(String(format: "Drain %.1f%%/h", snapshot.batteryDrainPerHour))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var statusIndicator: some View {
        Circle()
            .fill(snapshot.reachable ? Color.green : Color.orange)
            .frame(width: 10, height: 10)
            .accessibilityLabel(snapshot.reachable ? "Reachable" : "Offline")
    }
}

struct WatchWidgetInlineView: View {
    let snapshot: PerformanceSnapshot

    var body: some View {
        Text("\(snapshot.latencyMs)ms · \(String(format: "%.1f%%/h", snapshot.batteryDrainPerHour))")
    }
}

@main
struct PawWatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.stonezone.pawwatch.widget", provider: WatchWidgetProvider()) { entry in
            WatchWidgetRectangularView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("PawWatch Snapshot")
        .description("Latency, drain per hour, and reachability straight from the watch.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

#if DEBUG
@available(watchOS 10.0, *)
#Preview("Rectangular") {
    WatchWidgetRectangularView(snapshot: .init(latencyMs: 132, batteryDrainPerHour: 2.2, reachable: true))
        .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
}

@available(watchOS 10.0, *)
#Preview("Inline") {
    WatchWidgetInlineView(snapshot: .init(latencyMs: 132, batteryDrainPerHour: 2.2, reachable: true))
        .previewContext(WidgetPreviewContext(family: .accessoryInline))
}
#endif
