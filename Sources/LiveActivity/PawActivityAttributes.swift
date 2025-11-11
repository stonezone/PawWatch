#if canImport(ActivityKit)
import ActivityKit
import Foundation

public struct PawActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var latencyMs: Int
        public var batteryDrainPerHour: Double
        public var reachable: Bool
        public var timestamp: Date

        public init(latencyMs: Int, batteryDrainPerHour: Double, reachable: Bool, timestamp: Date = .now) {
            self.latencyMs = latencyMs
            self.batteryDrainPerHour = batteryDrainPerHour
            self.reachable = reachable
            self.timestamp = timestamp
        }
    }

    public init() { }
}
#endif
