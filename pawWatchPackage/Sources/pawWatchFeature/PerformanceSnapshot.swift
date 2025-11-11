import Foundation

public struct PerformanceSnapshot: Codable, Equatable, Sendable {
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

    public static let placeholder = PerformanceSnapshot(latencyMs: 120, batteryDrainPerHour: 2.3, reachable: true)
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
