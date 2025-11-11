#if canImport(ActivityKit)
import ActivityKit
import Foundation
import os
import pawWatchFeature

enum PerformanceLiveActivityManager {
    private static let logger = Logger(subsystem: "com.stonezone.pawwatch", category: "LiveActivity")

    static func syncLiveActivity(with snapshot: PerformanceSnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let contentState = PawActivityAttributes.ContentState(
            latencyMs: snapshot.latencyMs,
            batteryDrainPerHour: snapshot.batteryDrainPerHour,
            reachable: snapshot.reachable,
            timestamp: snapshot.timestamp
        )

        Task {
            if let activity = Activity<PawActivityAttributes>.activities.first {
                await activity.update(using: contentState)
            } else {
                do {
                    _ = try Activity<PawActivityAttributes>.request(
                        attributes: PawActivityAttributes(),
                        contentState: contentState,
                        pushType: nil
                    )
                } catch {
                    logger.error("Failed to start live activity: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    static func endAllActivities() {
        Task {
            for activity in Activity<PawActivityAttributes>.activities {
                await activity.end(using: activity.contentState, dismissalPolicy: .immediate)
            }
        }
    }
}

@MainActor
final class LiveActivityBootstrapper {
    static let shared = LiveActivityBootstrapper()
    private var observation: NSObjectProtocol?

    func startIfNeeded() {
        guard observation == nil else { return }
        observation = NotificationCenter.default.addObserver(
            forName: PerformanceSnapshotStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let snapshot = notification.userInfo?["snapshot"] as? PerformanceSnapshot else { return }
            PerformanceLiveActivityManager.syncLiveActivity(with: snapshot)
        }

        if let current = PerformanceSnapshotStore.load() {
            PerformanceLiveActivityManager.syncLiveActivity(with: current)
        }
    }
}
#endif
