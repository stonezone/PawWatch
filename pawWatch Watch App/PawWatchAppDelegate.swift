import WatchKit
import WatchConnectivity
import OSLog

private let appDelegateLogger = Logger(subsystem: "com.stonezone.pawWatch", category: "WatchAppDelegate")

/// Watch app delegate for background tasks and WCSession setup (single-target app).
class PawWatchAppDelegate: NSObject, WKApplicationDelegate {

    func applicationDidFinishLaunching() {
        // Initialize connectivity or other services as needed.
        appDelegateLogger.notice("App delegate finished launching")
    }

    /// Called by the system when recovering an active workout after a crash or reboot.
    func handleActiveWorkoutRecovery() {
        Task { @MainActor in
            appDelegateLogger.notice("Handling active workout recovery")
            WatchLocationManager.shared.restoreState()
        }
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                backgroundTask.setTaskCompletedWithSnapshot(false)

            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                snapshotTask.setTaskCompleted(
                    restoredDefaultState: true,
                    estimatedSnapshotExpiration: .distantFuture,
                    userInfo: nil
                )

            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                connectivityTask.setTaskCompletedWithSnapshot(false)

            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                urlSessionTask.setTaskCompleted()

            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
