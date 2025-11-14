import Foundation

public struct PerformanceSnapshot: Codable, Equatable, Sendable {
    public var latencyMs: Int
    /// Smoothed drain estimate in % per hour.
    public var batteryDrainPerHour: Double
    /// Instantaneous drain observation for the most recent interval.
    public var instantBatteryDrainPerHour: Double
    public var reachable: Bool
    public var timestamp: Date

    public init(
        latencyMs: Int,
        batteryDrainPerHour: Double,
        instantBatteryDrainPerHour: Double,
        reachable: Bool,
        timestamp: Date = Date()
    ) {
        self.latencyMs = latencyMs
        self.batteryDrainPerHour = batteryDrainPerHour
        self.instantBatteryDrainPerHour = instantBatteryDrainPerHour
        self.reachable = reachable
        self.timestamp = timestamp
    }

    private enum CodingKeys: String, CodingKey {
        case latencyMs
        case batteryDrainPerHour
        case instantBatteryDrainPerHour
        case reachable
        case timestamp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latencyMs = try container.decode(Int.self, forKey: .latencyMs)
        batteryDrainPerHour = try container.decode(Double.self, forKey: .batteryDrainPerHour)
        instantBatteryDrainPerHour = try container.decodeIfPresent(Double.self, forKey: .instantBatteryDrainPerHour) ?? batteryDrainPerHour
        reachable = try container.decode(Bool.self, forKey: .reachable)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latencyMs, forKey: .latencyMs)
        try container.encode(batteryDrainPerHour, forKey: .batteryDrainPerHour)
        try container.encode(instantBatteryDrainPerHour, forKey: .instantBatteryDrainPerHour)
        try container.encode(reachable, forKey: .reachable)
        try container.encode(timestamp, forKey: .timestamp)
    }

    public static let placeholder = PerformanceSnapshot(
        latencyMs: 120,
        batteryDrainPerHour: 2.3,
        instantBatteryDrainPerHour: 2.8,
        reachable: true
    )
}

public enum PerformanceSnapshotStore {
    public static let suiteName = "group.com.stonezone.pawWatch"
    private static let storageKey = "PerformanceSnapshot.latest"
    public static let didChangeNotification = Notification.Name("PerformanceSnapshotStoreDidChange")

    @discardableResult
    public static func save(_ snapshot: PerformanceSnapshot) -> Bool {
        guard let defaults = makeDefaults(),
              let encoded = try? JSONEncoder().encode(snapshot) else {
            return false
        }
        defaults.set(encoded, forKey: storageKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil, userInfo: ["snapshot": snapshot])
        return true
    }

    public static func load() -> PerformanceSnapshot? {
        guard let defaults = makeDefaults(),
              let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(PerformanceSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }

    private static func makeDefaults() -> UserDefaults? {
        UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
    }
}
