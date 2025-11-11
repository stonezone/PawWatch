import SwiftUI
import pawWatchFeature
#if canImport(ActivityKit)
import ActivityKit
#endif

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
#if canImport(ActivityKit)
                        PerformanceLiveActivityManager.endAllActivities()
#endif
                    case "open-app":
                        break
                    default:
                        break
                    }
                }
        }
    }
}
