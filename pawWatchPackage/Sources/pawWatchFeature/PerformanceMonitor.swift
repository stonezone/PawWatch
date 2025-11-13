import Foundation
import OSLog

#if os(watchOS)
import WatchKit

@MainActor
public final class PerformanceMonitor {
    public static let shared = PerformanceMonitor()
    private var gpsLatencies: [TimeInterval] = []
    private var pendingMessages: [String: Date] = [:]
    private var lastBatteryLevel: Double = 1.0
    private var lastBatteryTimestamp: Date = Date()
    public private(set) var batteryDrainPerHour: Double = 0

    private init() {
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
    }

    public func recordGPSLatency(_ latency: TimeInterval) {
        gpsLatencies.append(latency)
        if gpsLatencies.count > 100 { gpsLatencies.removeFirst() }
    }

    public func recordMessageSent(id: String) {
        pendingMessages[id] = Date()
    }

    public func recordMessageReceived(id: String) {
        guard let start = pendingMessages.removeValue(forKey: id) else { return }
        recordGPSLatency(Date().timeIntervalSince(start))
    }

    public func recordBattery(level: Double) {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastBatteryTimestamp)
        guard elapsed > 60 else { return }
        let delta = lastBatteryLevel - level
        batteryDrainPerHour = (delta / max(elapsed / 3600, 0.01)) * 100
        lastBatteryLevel = level
        lastBatteryTimestamp = now
    }

    public var gpsAverage: TimeInterval {
        guard !gpsLatencies.isEmpty else { return 0 }
        return gpsLatencies.reduce(0, +) / Double(gpsLatencies.count)
    }

    public var gpsP95: TimeInterval {
        guard !gpsLatencies.isEmpty else { return 0 }
        let sorted = gpsLatencies.sorted()
        return sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
    }
}

private extension Array where Element == TimeInterval {
    var median: TimeInterval {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        return sorted[count / 2]
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(range.upperBound, max(range.lowerBound, self))
    }
}

#else

@MainActor
public final class PerformanceMonitor {
    public static let shared = PerformanceMonitor()
    private init() {}

    public func recordGPSLatency(_ latency: TimeInterval) {}
    public func recordMessageSent(id: String) {}
    public func recordMessageReceived(id: String) {}
    public func recordBattery(level: Double) {}

    public var gpsAverage: TimeInterval { 0 }
    public var gpsP95: TimeInterval { 0 }
    public var batteryDrainPerHour: Double { 0 }
}

#endif
