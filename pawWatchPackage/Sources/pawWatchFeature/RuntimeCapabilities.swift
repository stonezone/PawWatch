import Foundation
#if os(watchOS)
import WatchKit
#endif

public enum RuntimePreferenceKey {
    /// Shared key used by watchOS + iOS to persist the extended-runtime toggle.
    public static let runtimeOptimizationsEnabled = "watchBatteryOptimizationsEnabled"
}

enum RuntimeCapabilities {
    #if os(watchOS)
    static var supportsExtendedRuntime: Bool {
        guard #available(watchOS 6.0, *) else { return false }
        guard let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "WKBackgroundModes") as? [String] else {
            return false
        }
        return backgroundModes.contains("workout-processing")
            || backgroundModes.contains("extendedRuntimeSession")
    }
    #else
    static var supportsExtendedRuntime: Bool { false }
    #endif
}
