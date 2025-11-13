#if canImport(ActivityKit)
import ActivityKit
import Foundation
import os
import pawWatchFeature

private struct ActivityPushTokenStream: @unchecked Sendable {
    let stream: Activity<PawActivityAttributes>.PushTokenUpdates
}

enum PerformanceLiveActivityManager {
    private static let logger = Logger(subsystem: "com.stonezone.pawwatch", category: "LiveActivity")
    private static let highDrainThreshold: Double = 5.0
    @MainActor private static var pushTokenTask: Task<Void, Never>?

    static func syncLiveActivity(with snapshot: PerformanceSnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let alert: PawActivityAttributes.AlertState? = {
            if snapshot.reachable == false { return .unreachable }
            if snapshot.batteryDrainPerHour >= highDrainThreshold { return .highDrain }
            return nil
        }()

        let contentState = PawActivityAttributes.ContentState(
            latencyMs: snapshot.latencyMs,
            batteryDrainPerHour: snapshot.batteryDrainPerHour,
            reachable: snapshot.reachable,
            timestamp: snapshot.timestamp,
            alert: alert
        )

        Task {
            if let activity = Activity<PawActivityAttributes>.activities.first {
                observePushTokens(for: activity)
                await activity.update(using: contentState)
            } else {
                do {
                    let activity = try Activity<PawActivityAttributes>.request(
                        attributes: PawActivityAttributes(),
                        contentState: contentState,
                        pushType: .token
                    )
                    observePushTokens(for: activity)
                } catch {
                    logger.error("Failed to start live activity: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    static func endAllActivities() {
        Task {
            await MainActor.run {
                pushTokenTask?.cancel()
                pushTokenTask = nil
            }
            for activity in Activity<PawActivityAttributes>.activities {
                await activity.end(using: activity.contentState, dismissalPolicy: .immediate)
            }
        }
    }

    static func applyRemote(contentState: PawActivityAttributes.ContentState) {
        Task {
            guard let activity = Activity<PawActivityAttributes>.activities.first else { return }
            observePushTokens(for: activity)
            await activity.update(using: contentState)
        }
    }

    private static func observePushTokens(for activity: Activity<PawActivityAttributes>) {
        let stream = ActivityPushTokenStream(stream: activity.pushTokenUpdates)
        let activityID = activity.id
        Task {
            await MainActor.run {
                pushTokenTask?.cancel()
                pushTokenTask = nil
            }

            let observer = Task.detached(priority: .background) {
                for await tokenData in stream.stream {
                    await LiveActivityPushCoordinator.shared.store(tokenData, activityID: activityID)
                }
            }

            await MainActor.run {
                pushTokenTask = observer
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

// MARK: - Push Coordination

actor LiveActivityPushCoordinator {
    static let shared = LiveActivityPushCoordinator()

    private let defaults = UserDefaults(suiteName: PerformanceSnapshotStore.suiteName) ?? .standard
    private let activityTokenKey = "LiveActivity.PushTokens"
    private let apnsTokenKey = "LiveActivity.APNSToken"
    private let logger = Logger(subsystem: "com.stonezone.pawwatch", category: "LiveActivityPush")
    private lazy var isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func store(_ tokenData: Data, activityID: Activity<PawActivityAttributes>.ID) {
        let token = hexString(from: tokenData)
        var tokens = defaults.array(forKey: activityTokenKey) as? [[String: Any]] ?? []
        tokens.removeAll { $0["activityId"] as? String == activityID }
        tokens.append([
            "activityId": activityID,
            "token": token,
            "updatedAt": isoFormatter.string(from: Date())
        ])
        defaults.set(tokens, forKey: activityTokenKey)
        logger.log("Stored Live Activity push token for activity \(activityID, privacy: .public)")
    }

    func storeDeviceToken(_ data: Data) {
        let token = hexString(from: data)
        defaults.set(token, forKey: apnsTokenKey)
        logger.log("Stored APNs device token (length: \(token.count, privacy: .public) chars)")
    }

    private func hexString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

struct LiveActivityRemotePayload: Codable {
    struct State: Codable {
        var latencyMs: Int
        var batteryDrainPerHour: Double
        var reachable: Bool
        var timestamp: Date
        var alert: PawActivityAttributes.AlertState?

        func contentState() -> PawActivityAttributes.ContentState {
            PawActivityAttributes.ContentState(
                latencyMs: latencyMs,
                batteryDrainPerHour: batteryDrainPerHour,
                reachable: reachable,
                timestamp: timestamp,
                alert: alert
            )
        }
    }

    var activityId: String?
    var state: State
}

enum LiveActivityPushHandler {
    private static let logger = Logger(subsystem: "com.stonezone.pawwatch", category: "LiveActivityPush")

    static func handle(userInfo: [AnyHashable: Any]) -> Bool {
        guard let payloadDict = userInfo["pawwatch"] as? [String: Any],
              let data = try? JSONSerialization.data(withJSONObject: payloadDict),
              let payload = try? JSONDecoder().decode(LiveActivityRemotePayload.self, from: data) else {
            return false
        }

        let snapshot = PerformanceSnapshot(
            latencyMs: payload.state.latencyMs,
            batteryDrainPerHour: payload.state.batteryDrainPerHour,
            reachable: payload.state.reachable,
            timestamp: payload.state.timestamp
        )
        PerformanceSnapshotStore.save(snapshot)
        PerformanceLiveActivityManager.applyRemote(contentState: payload.state.contentState())
        logger.log("Applied remote Live Activity payload at \(payload.state.timestamp, privacy: .public)")
        return true
    }
}
#endif
