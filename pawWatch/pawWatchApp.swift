import SwiftUI
import pawWatchFeature

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
        }
    }
}
