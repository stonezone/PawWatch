import Foundation
#if os(watchOS)
import WatchKit
#endif

@MainActor
public final class PerformanceMonitor: NSObject {
    public static let shared = PerformanceMonitor()

    public private(set) var latestSnapshot: PerformanceSnapshot?

    #if os(watchOS)
    private var gpsLatencies: [TimeInterval] = []
    private var pendingMessages: [String: Date] = [:]
    private var lastBatteryLevel: Double = 1.0
    private var lastBatteryTimestamp: Date = Date()
    private let smoothingFactor: Double = 0.2
    public private(set) var batteryDrainPerHourInstant: Double = 0
    public private(set) var batteryDrainPerHourSmoothed: Double = 0
    public var batteryDrainPerHour: Double { batteryDrainPerHourSmoothed }
    #else
    private var lastBatterySample: (value: Double, timestamp: Date)?
    private var smoothedBatteryDrainPerHour: Double = 0
    private let batteryDrainSmoothingFactor: Double = 0.2
    private let minBatterySampleInterval: TimeInterval = 60
    private let maxInstantDrainPerHour: Double = 30
    public var batteryDrainPerHourInstant: Double { latestSnapshot?.instantBatteryDrainPerHour ?? 0 }
    public var batteryDrainPerHourSmoothed: Double { latestSnapshot?.batteryDrainPerHour ?? 0 }
    public var batteryDrainPerHour: Double { latestSnapshot?.batteryDrainPerHour ?? 0 }
    #endif

    private override init() {
        latestSnapshot = PerformanceSnapshotStore.load()
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSnapshotNotification(_:)),
            name: PerformanceSnapshotStore.didChangeNotification,
            object: nil
        )

        #if os(watchOS)
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        #endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc
    private func handleSnapshotNotification(_ notification: Notification) {
        if let snapshot = notification.userInfo?["snapshot"] as? PerformanceSnapshot {
            latestSnapshot = snapshot
        } else {
            latestSnapshot = PerformanceSnapshotStore.load()
        }
    }

    private func saveSnapshot(_ snapshot: PerformanceSnapshot) {
        latestSnapshot = snapshot
        PerformanceSnapshotStore.save(snapshot)

        #if os(iOS) || os(watchOS)
        // Sync to CloudKit for offline recovery (not needed on macOS test host).
        Task.detached {
            await CloudKitLocationSync.shared.saveSnapshot(snapshot)
        }
        #endif
    }

    #if os(watchOS)
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

    public func recordBattery(level rawLevel: Double) {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastBatteryTimestamp)
        guard elapsed > 60 else { return }
        var sanitizedLevel = rawLevel
        if !sanitizedLevel.isFinite { sanitizedLevel = lastBatteryLevel }
        sanitizedLevel = sanitizedLevel.clamped(to: 0...1)

        let delta = lastBatteryLevel - sanitizedLevel
        if delta <= 0 {
            lastBatteryLevel = sanitizedLevel
            lastBatteryTimestamp = now
            batteryDrainPerHourInstant = 0
            return
        }

        let hours = max(elapsed / 3600, 0.01)
        let instant = (delta / hours) * 100
        batteryDrainPerHourInstant = instant
        let smoothed = smoothingFactor * instant + (1 - smoothingFactor) * batteryDrainPerHourSmoothed
        batteryDrainPerHourSmoothed = smoothed.isFinite ? smoothed : batteryDrainPerHourSmoothed

        lastBatteryLevel = sanitizedLevel
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
    #else
    public func recordGPSLatency(_ latency: TimeInterval) {}
    public func recordMessageSent(id: String) {}
    public func recordMessageReceived(id: String) {}
    public func recordBattery(level: Double) {}

    public var gpsAverage: TimeInterval {
        guard let snapshot = latestSnapshot else { return 0 }
        return Double(snapshot.latencyMs) / 1000
    }

    public var gpsP95: TimeInterval {
        guard let snapshot = latestSnapshot else { return 0 }
        return Double(snapshot.latencyMs) / 1000
    }

    public func recordRemoteFix(_ fix: LocationFix, watchReachable: Bool) {
        let now = Date()
        let latencyMs = max(1, Int(now.timeIntervalSince(fix.timestamp) * 1000))
        let normalizedBattery = sanitizedBatteryFraction(fix.batteryFraction)
        var instantDrainPerHour: Double = 0

        if let lastSample = lastBatterySample {
            let elapsed = fix.timestamp.timeIntervalSince(lastSample.timestamp)
            if elapsed >= minBatterySampleInterval {
                let delta = lastSample.value - normalizedBattery
                lastBatterySample = (normalizedBattery, fix.timestamp)

                if delta > 0 {
                    let hours = max(elapsed / 3600, 0.001)
                    let instantaneous = (delta / hours) * 100
                    instantDrainPerHour = min(max(0, instantaneous), maxInstantDrainPerHour)
                }
            }
        } else {
            lastBatterySample = (normalizedBattery, fix.timestamp)
        }

        if instantDrainPerHour > 0 {
            let smoothed = batteryDrainSmoothingFactor * instantDrainPerHour +
                (1 - batteryDrainSmoothingFactor) * smoothedBatteryDrainPerHour
            if smoothed.isFinite {
                smoothedBatteryDrainPerHour = smoothed
            }
        }

        let snapshot = PerformanceSnapshot(
            latencyMs: latencyMs,
            batteryDrainPerHour: max(0, smoothedBatteryDrainPerHour),
            instantBatteryDrainPerHour: max(0, instantDrainPerHour),
            reachable: watchReachable,
            timestamp: now
        )

        saveSnapshot(snapshot)
    }

    private func sanitizedBatteryFraction(_ rawValue: Double) -> Double {
        guard rawValue.isFinite else { return lastBatterySample?.value ?? 1 }
        return min(max(rawValue, 0), 1)
    }
    #endif
}

#if os(watchOS)
private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(range.upperBound, max(range.lowerBound, self))
    }
}
#endif
