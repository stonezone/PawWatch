#if canImport(ActivityKit)
import ActivityKit
import Foundation
import os
import pawWatchFeature

fileprivate struct ActivityPushTokenStream: @unchecked Sendable {
    let stream: Activity<PawActivityAttributes>.PushTokenUpdates
}

enum PerformanceLiveActivityManager {
    private static let logger = Logger(subsystem: "com.stonezone.pawwatch", category: "LiveActivity")
    private static let sustainedDrainThreshold: Double = 5.0
    private static let instantDrainThreshold: Double = 8.0

    static func syncLiveActivity(with snapshot: PerformanceSnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let alert: PawActivityAttributes.AlertState? = {
            if snapshot.reachable == false { return .unreachable }
            if snapshot.batteryDrainPerHour >= sustainedDrainThreshold ||
                snapshot.instantBatteryDrainPerHour >= instantDrainThreshold {
                return .highDrain
            }
            return nil
        }()

        let contentState = PawActivityAttributes.ContentState(
            latencyMs: snapshot.latencyMs,
            batteryDrainPerHour: snapshot.batteryDrainPerHour,
            instantBatteryDrainPerHour: snapshot.instantBatteryDrainPerHour,
            reachable: snapshot.reachable,
            timestamp: snapshot.timestamp,
            alert: alert
        )

        Task {
            if let activity = Activity<PawActivityAttributes>.activities.first {
                await observePushTokens(for: activity)
                await activity.update(using: contentState)
            } else {
                do {
                    let activity = try Activity<PawActivityAttributes>.request(
                        attributes: PawActivityAttributes(),
                        contentState: contentState,
                        pushType: .token
                    )
                    await observePushTokens(for: activity)
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
            await LiveActivityPushCoordinator.shared.stopObservingTokens()
        }
    }

    static func applyRemote(contentState: PawActivityAttributes.ContentState) {
        Task {
            guard let activity = Activity<PawActivityAttributes>.activities.first else { return }
            await observePushTokens(for: activity)
            await activity.update(using: contentState)
        }
    }

    private static func observePushTokens(for activity: Activity<PawActivityAttributes>) async {
        let stream = ActivityPushTokenStream(stream: activity.pushTokenUpdates)
        await LiveActivityPushCoordinator.shared.observeTokens(stream: stream, activityID: activity.id)
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
    private let lastUploadKey = "LiveActivity.PushTokens.LastUpload"
    private let logger = Logger(subsystem: "com.stonezone.pawwatch", category: "LiveActivityPush")
    private lazy var isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private var pushTokenTask: Task<Void, Never>?
    private var uploadTask: Task<Void, Never>?
    private let uploader = PushTokenUploader()
    private var retryAttempt = 0

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
        scheduleUpload()
    }

    func storeDeviceToken(_ data: Data) {
        let token = hexString(from: data)
        defaults.set(token, forKey: apnsTokenKey)
        logger.log("Stored APNs device token (length: \(token.count, privacy: .public) chars)")
        scheduleUpload(immediate: true)
    }

    fileprivate func observeTokens(stream: ActivityPushTokenStream, activityID: Activity<PawActivityAttributes>.ID) {
        pushTokenTask?.cancel()
        let actor = self
        pushTokenTask = Task(priority: .background) { [stream, activityID] in
            for await tokenData in stream.stream {
                await actor.store(tokenData, activityID: activityID)
            }
        }
    }

    fileprivate func stopObservingTokens() {
        pushTokenTask?.cancel()
        pushTokenTask = nil
    }

    private func scheduleUpload(immediate: Bool = false) {
        guard uploader.isEnabled else {
            logger.notice("Push uploads disabled; skipping network call")
            return
        }
        uploadTask?.cancel()
        let delayNanoseconds = immediate ? 0 : Self.delayNanoseconds(for: retryAttempt)
        uploadTask = Task(priority: .background) { [weak self, delayNanoseconds] in
            guard let self else { return }
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            await self.uploadTokensIfPossible()
        }
    }

    private func uploadTokensIfPossible() async {
        guard uploader.isEnabled else { return }

        guard let deviceToken = defaults.string(forKey: apnsTokenKey), !deviceToken.isEmpty else {
            logger.notice("Skipping push upload: missing device token")
            return
        }

        let tokens = currentActivityTokens()
        guard !tokens.isEmpty else {
            logger.notice("Skipping push upload: no live activity tokens yet")
            return
        }

        do {
            try await uploader.upload(deviceToken: deviceToken, activityTokens: tokens)
            retryAttempt = 0
            defaults.set(Date().timeIntervalSince1970, forKey: lastUploadKey)
            logger.log("Uploaded \(tokens.count, privacy: .public) live activity token(s) to backend")
        } catch is CancellationError {
            logger.notice("Push token upload cancelled before completion")
        } catch let error as PushTokenUploader.UploadError {
            retryAttempt = min(retryAttempt + 1, Self.maxRetryAttempts)
            switch error {
            case let .serverRejected(status, body):
                logger.error("Push token upload rejected (status: \(status, privacy: .public)) body: \(body ?? "<empty>", privacy: .public)")
            default:
                logger.error("Push token upload failed: \(error.localizedDescription, privacy: .public)")
            }
            scheduleUpload()
        } catch {
            retryAttempt = min(retryAttempt + 1, Self.maxRetryAttempts)
            logger.error("Push token upload failed with unexpected error: \(error.localizedDescription, privacy: .public)")
            scheduleUpload()
        }
    }

    private func currentActivityTokens() -> [PushTokenUploadRequest.ActivityToken] {
        guard let entries = defaults.array(forKey: activityTokenKey) as? [[String: Any]] else { return [] }
        return entries.compactMap { entry in
            guard let id = entry["activityId"] as? String,
                  let token = entry["token"] as? String,
                  let updatedAt = entry["updatedAt"] as? String else { return nil }
            return PushTokenUploadRequest.ActivityToken(activityId: id, pushToken: token, updatedAt: updatedAt)
        }
    }

    private static func delayNanoseconds(for attempt: Int) -> UInt64 {
        let seconds: Double
        if attempt <= 0 {
            seconds = 2
        } else {
            let exponential = pow(2.0, Double(attempt)) * 2.0
            seconds = min(exponential, 60)
        }
        return UInt64(seconds * 1_000_000_000)
    }

    private static let maxRetryAttempts = 6

    private func hexString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

struct LiveActivityRemotePayload: Codable {
    struct State: Codable {
        var latencyMs: Int
        var batteryDrainPerHour: Double
        var instantBatteryDrainPerHour: Double?
        var reachable: Bool
        var timestamp: Date
        var alert: PawActivityAttributes.AlertState?

        func contentState() -> PawActivityAttributes.ContentState {
            PawActivityAttributes.ContentState(
                latencyMs: latencyMs,
                batteryDrainPerHour: batteryDrainPerHour,
                instantBatteryDrainPerHour: instantBatteryDrainPerHour,
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
            instantBatteryDrainPerHour: payload.state.instantBatteryDrainPerHour ?? payload.state.batteryDrainPerHour,
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
