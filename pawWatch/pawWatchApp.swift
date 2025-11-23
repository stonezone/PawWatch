import SwiftUI
import pawWatchFeature
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
import BackgroundTasks
import OSLog
import UIKit
import UserNotifications

@main
struct pawWatchApp: App {
    @UIApplicationDelegateAdaptor(PawWatchAppDelegate.self) private var appDelegate

    init() {
#if canImport(ActivityKit)
        LiveActivityBootstrapper.shared.startIfNeeded()
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(PetLocationManager())
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

// MARK: - App Delegate & Background Work

final class PawWatchAppDelegate: NSObject, UIApplicationDelegate {
    private let backgroundScheduler = BackgroundRefreshScheduler()
    private let logger = Logger(subsystem: "com.stonezone.pawWatch", category: "AppDelegate")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        backgroundScheduler.register()
        backgroundScheduler.schedule()
#if !DEBUG
        PushRegistrationController.registerForRemoteNotifications()
#endif
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        backgroundScheduler.schedule()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { await LiveActivityPushCoordinator.shared.storeDeviceToken(deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error("APNs registration failed: \(error.localizedDescription, privacy: .public)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if LiveActivityPushHandler.handle(userInfo: userInfo) {
            backgroundScheduler.schedule()
            completionHandler(.newData)
        } else {
            completionHandler(.noData)
        }
    }
}

final class BackgroundRefreshScheduler {
    private let identifier = "com.stonezone.pawWatch.activity-refresh"
    private let logger = Logger(subsystem: "com.stonezone.pawWatch", category: "BackgroundRefresh")

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handle(refreshTask)
        }
    }

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("Failed to schedule background refresh: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func handle(_ task: BGAppRefreshTask) {
        schedule()
        task.expirationHandler = { [logger] in
            logger.error("Background refresh expired before completion")
            task.setTaskCompleted(success: false)
        }

        if let snapshot = PerformanceSnapshotStore.load() {
            PerformanceLiveActivityManager.syncLiveActivity(with: snapshot)
        }
        task.setTaskCompleted(success: true)
    }
}

enum PushRegistrationController {
    private static let logger = Logger(subsystem: "com.stonezone.pawWatch", category: "PushRegistration")

    static func registerForRemoteNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            guard granted else {
                logger.notice("Notification authorization denied; Live Activity pushes limited")
                return
            }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}
