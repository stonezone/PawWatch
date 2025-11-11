import SwiftUI
import pawWatchFeature
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
import OSLog

@main
struct pawWatchApp: App {
    init() {
#if canImport(ActivityKit)
        LiveActivityBootstrapper.shared.startIfNeeded()
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    guard url.scheme == "pawwatch" else { return }
                    switch url.host?.lowercased() {
                    case "stop-tracking":
                        handleStopRequest()
                    case "open-app":
                        break
                    default:
                        break
                    }
                }
        }
    }

    private func handleStopRequest() {
#if canImport(ActivityKit)
        PerformanceLiveActivityManager.endAllActivities()
#endif
#if canImport(WatchConnectivity)
        forwardStopToWatch()
#endif
    }

#if canImport(WatchConnectivity)
    private func forwardStopToWatch() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.activationState == .notActivated {
            session.activate()
        }

        guard session.isPaired, session.isWatchAppInstalled else {
            logger.notice("Stop request ignored: watch not paired or app missing")
            return
        }

        let payload: [String: Any] = ["action": "stop-tracking"]
        if session.activationState == .activated, session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                logger.error("Stop message failed: \(error.localizedDescription, privacy: .public)")
            }
        } else if session.activationState == .activated {
            do {
                try session.updateApplicationContext(payload)
                logger.notice("Stop request queued via application context; watch unreachable")
            } catch {
                logger.error("Failed to queue stop request: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            logger.notice("Stop request pending until WCSession activates")
        }
    }

    private let logger = Logger(subsystem: "com.stonezone.pawWatch", category: "StopBridge")
#endif
}
