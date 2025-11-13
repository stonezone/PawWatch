#if canImport(ActivityKit)
import ActivityKit
import Foundation

public struct PawActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var latencyMs: Int
        public var batteryDrainPerHour: Double
        public var reachable: Bool
        public var timestamp: Date
        public var alert: AlertState?

        public init(
            latencyMs: Int,
            batteryDrainPerHour: Double,
            reachable: Bool,
            timestamp: Date = .now,
            alert: AlertState? = nil
        ) {
            self.latencyMs = latencyMs
            self.batteryDrainPerHour = batteryDrainPerHour
            self.reachable = reachable
            self.timestamp = timestamp
            self.alert = alert
        }
    }

    public init() { }

    public enum AlertState: String, Codable, Hashable, Sendable {
        case highDrain
        case unreachable
    }
}
#endif
