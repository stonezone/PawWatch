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

    /// Single shared PetLocationManager instance for the entire app lifetime.
    /// This guarantees that WCSession.delegate is configured as soon as the
    /// app launches, including background activations for queued transfers.
    @StateObject private var locationManager: PetLocationManager

    init() {
        // Create and register the shared location manager
        let manager = PetLocationManager()
        _locationManager = StateObject(wrappedValue: manager)
        PetLocationManager.setShared(manager)

#if canImport(ActivityKit)
        LiveActivityBootstrapper.shared.startIfNeeded()
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .onOpenURL { url in
                    guard url.scheme == "pawwatch" else { return }
                    switch url.host?.lowercased() {
                    case ConnectivityConstants.stopTracking:
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
        Task { @MainActor in
            PetLocationManager.sharedSync?.sendStopCommand()
        }
    }
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
        // Handle location request push (silent push for watch location update)
        if BackgroundLocationPushHandler.handle(userInfo: userInfo) {
            backgroundScheduler.schedule()
            completionHandler(.newData)
            return
        }

        // Handle Live Activity push
        if LiveActivityPushHandler.handle(userInfo: userInfo) {
            backgroundScheduler.schedule()
            completionHandler(.newData)
            return
        }

        completionHandler(.noData)
    }
}

final class BackgroundRefreshScheduler: @unchecked Sendable {
    private let identifier = "com.stonezone.pawWatch.activity-refresh"
    private let logger = Logger(subsystem: "com.stonezone.pawWatch", category: "BackgroundRefresh")

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { [self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refreshTask)
        }
    }

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background refresh scheduled for ~15 minutes")
        } catch {
            logger.error("Failed to schedule background refresh: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func handle(_ task: BGAppRefreshTask) {
        logger.info("Background refresh task started")

        // Schedule next refresh immediately
        schedule()

        task.expirationHandler = { [logger] in
            logger.warning("Background refresh expired before completion")
        }

        // CR-003 FIX: Use async task to properly track success
        Task { @MainActor in
            var success = false

            // Request location from watch
            if let manager = PetLocationManager.sharedSync {
                manager.requestBackgroundUpdate()
                success = true
            }

            // Sync Live Activity if available
            if let snapshot = PerformanceSnapshotStore.load() {
                PerformanceLiveActivityManager.syncLiveActivity(with: snapshot)
                success = true
            }

            self.logger.info("Background refresh completed: \(success, privacy: .public)")
            task.setTaskCompleted(success: success)
        }
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

// MARK: - Silent Push Location Request Handler

/// Handles silent push notifications requesting location updates from watch.
/// Push payload format: { "aps": { "content-available": 1 }, "action": "request-location" }
enum BackgroundLocationPushHandler {
    private static let logger = Logger(subsystem: "com.stonezone.pawWatch", category: "LocationPush")

    /// Handle incoming push notification, returns true if this was a location request.
    static func handle(userInfo: [AnyHashable: Any]) -> Bool {
        guard let action = userInfo["action"] as? String,
              action == ConnectivityConstants.pushRequestLocation else {
            return false
        }

        logger.info("Silent push received: requesting watch location")

        // CR-003 FIX: Request location and return true to indicate we handled this push
        // The actual request happens async on MainActor
        Task { @MainActor in
            if let manager = PetLocationManager.sharedSync {
                manager.requestBackgroundUpdate()
                logger.info("Watch location request issued via push")
            } else {
                logger.warning("PetLocationManager not available for push request")
            }
        }
        return true  // We handled this push type, even if manager wasn't ready
    }
}
