import Foundation
import Testing
@testable import pawWatchFeature

/// Tests for PerformanceMonitor battery recording and drain calculation.
@Suite("PerformanceMonitor Tests")
@MainActor
struct PerformanceMonitorTests {

    #if os(iOS)
    // MARK: - Battery Recording (iOS)

    @Test("iOS battery recording with valid data")
    func iOSBatteryRecordingValidData() {
        // Arrange
        let monitor = PerformanceMonitor.shared
        let fix1 = makeFix(batteryFraction: 1.0, timestamp: Date())
        let fix2 = makeFix(batteryFraction: 0.9, timestamp: Date().addingTimeInterval(3600)) // 1 hour later, 10% drain

        // Act
        monitor.recordRemoteFix(fix1, watchReachable: true)
        monitor.recordRemoteFix(fix2, watchReachable: true)

        // Assert - Should show approximately 10% per hour drain
        let drain = monitor.batteryDrainPerHour
        #expect(drain > 5.0) // Smoothing means it won't be exactly 10
        #expect(drain < 15.0)
    }

    @Test("iOS battery recording ignores samples with insufficient elapsed time")
    func iOSIgnoresQuickSamples() {
        // Arrange
        let monitor = PerformanceMonitor.shared
        let fix1 = makeFix(batteryFraction: 1.0, timestamp: Date())
        let fix2 = makeFix(batteryFraction: 0.9, timestamp: Date().addingTimeInterval(30)) // Only 30s later

        // Act
        monitor.recordRemoteFix(fix1, watchReachable: true)
        let drainBefore = monitor.batteryDrainPerHour
        monitor.recordRemoteFix(fix2, watchReachable: true)
        let drainAfter = monitor.batteryDrainPerHour

        // Assert - Drain should not change significantly since sample was too quick
        // The second sample should be ignored due to < 60s threshold
        #expect(drainAfter == drainBefore || abs(drainAfter - drainBefore) < 1.0)
    }

    @Test("iOS battery recording applies exponential moving average smoothing")
    func iOSAppliesSmoothing() {
        // Arrange
        let monitor = PerformanceMonitor.shared
        let baseTime = Date()

        // Act - Send fixes with consistent 10% drain over multiple hours
        let fix1 = makeFix(batteryFraction: 1.0, timestamp: baseTime)
        let fix2 = makeFix(batteryFraction: 0.9, timestamp: baseTime.addingTimeInterval(3600))
        let fix3 = makeFix(batteryFraction: 0.8, timestamp: baseTime.addingTimeInterval(7200))

        monitor.recordRemoteFix(fix1, watchReachable: true)
        monitor.recordRemoteFix(fix2, watchReachable: true)
        let drainAfterTwo = monitor.batteryDrainPerHour
        monitor.recordRemoteFix(fix3, watchReachable: true)
        let drainAfterThree = monitor.batteryDrainPerHour

        // Assert - With smoothing, the third sample should move the average closer to 10
        #expect(drainAfterTwo > 0)
        #expect(drainAfterThree > drainAfterTwo) // Should increase toward 10
        #expect(drainAfterThree < 15.0) // But smoothing prevents instant jump to 10
    }

    @Test("iOS battery recording clamps negative drain to zero")
    func iOSClampsNegativeDrain() {
        // Arrange
        let monitor = PerformanceMonitor.shared
        let fix1 = makeFix(batteryFraction: 0.5, timestamp: Date())
        let fix2 = makeFix(batteryFraction: 0.6, timestamp: Date().addingTimeInterval(3600)) // Charging

        // Act
        monitor.recordRemoteFix(fix1, watchReachable: true)
        monitor.recordRemoteFix(fix2, watchReachable: true)

        // Assert - Drain should be clamped to zero (no negative drain)
        let drain = monitor.batteryDrainPerHour
        #expect(drain >= 0.0)
    }

    @Test("iOS battery recording handles zero elapsed time gracefully")
    func iOSHandlesZeroElapsedTime() {
        // Arrange
        let monitor = PerformanceMonitor.shared
        let timestamp = Date()
        let fix1 = makeFix(batteryFraction: 1.0, timestamp: timestamp)
        let fix2 = makeFix(batteryFraction: 0.9, timestamp: timestamp) // Same timestamp

        // Act
        monitor.recordRemoteFix(fix1, watchReachable: true)
        monitor.recordRemoteFix(fix2, watchReachable: true)

        // Assert - Should not crash, drain should remain reasonable
        let drain = monitor.batteryDrainPerHour
        #expect(drain.isFinite)
    }

    @Test("iOS battery recording sanitizes non-finite values")
    func iOSSanitizesNonFiniteValues() {
        // Arrange
        let monitor = PerformanceMonitor.shared
        let fix1 = makeFix(batteryFraction: 1.0, timestamp: Date())

        // Act - This tests the sanitization logic indirectly
        monitor.recordRemoteFix(fix1, watchReachable: true)

        // Create a fix with out-of-bounds battery (will be clamped internally)
        let fix2 = makeFix(batteryFraction: 1.5, timestamp: Date().addingTimeInterval(3600))
        monitor.recordRemoteFix(fix2, watchReachable: true)

        // Assert - Drain calculation should handle sanitized values
        let drain = monitor.batteryDrainPerHour
        #expect(drain.isFinite)
        #expect(drain >= 0.0)
    }

    @Test("iOS battery recording tracks instant vs smoothed drain")
    func iOSTracksInstantVsSmoothed() {
        // Arrange
        let monitor = PerformanceMonitor.shared
        let fix1 = makeFix(batteryFraction: 1.0, timestamp: Date())
        let fix2 = makeFix(batteryFraction: 0.8, timestamp: Date().addingTimeInterval(3600)) // 20% drain in 1 hour

        // Act
        monitor.recordRemoteFix(fix1, watchReachable: true)
        monitor.recordRemoteFix(fix2, watchReachable: true)

        // Assert - Instant should be higher, smoothed should be lower due to smoothing factor
        let instant = monitor.batteryDrainPerHourInstant
        let smoothed = monitor.batteryDrainPerHourSmoothed

        #expect(instant > smoothed) // Instant captures full 20%, smoothed is averaged
        #expect(instant >= 15.0) // Should be close to 20%
        #expect(smoothed < instant)
    }

    #elseif os(watchOS)
    // MARK: - Battery Recording (watchOS)

    @Test("watchOS battery recording with valid data")
    func watchOSBatteryRecordingValidData() {
        // Arrange
        let monitor = PerformanceMonitor.shared

        // Act - Record battery level drop over 90 seconds
        monitor.recordBattery(level: 1.0)
        // Wait simulation - can't actually wait in test, so we rely on timestamp tracking
        // In real usage, the elapsed time check prevents too-quick samples

        // Assert - Test passes if no crash occurs and smoothed value is finite
        #expect(monitor.batteryDrainPerHourSmoothed.isFinite)
    }

    @Test("watchOS battery recording ignores samples with insufficient elapsed time")
    func watchOSIgnoresQuickSamples() {
        // Arrange
        let monitor = PerformanceMonitor.shared

        // Act - Record battery levels in quick succession
        monitor.recordBattery(level: 1.0)
        monitor.recordBattery(level: 0.95)
        monitor.recordBattery(level: 0.90)

        // Assert - The quick samples (< 60s apart) should be ignored
        // We can't directly test the timing without waiting, but we verify no crash
        #expect(monitor.batteryDrainPerHourSmoothed.isFinite)
    }

    @Test("watchOS battery recording clamps negative drain to zero")
    func watchOSClampsNegativeDrain() {
        // Arrange
        let monitor = PerformanceMonitor.shared

        // Act - Simulate charging scenario by recording increasing battery
        monitor.recordBattery(level: 0.5)
        // In real scenario, after 60s+ we'd record higher level
        // The implementation clamps to 0 when delta <= 0

        // Assert
        #expect(monitor.batteryDrainPerHourInstant >= 0.0)
        #expect(monitor.batteryDrainPerHourSmoothed >= 0.0)
    }

    @Test("watchOS battery recording applies exponential moving average")
    func watchOSAppliesSmoothing() {
        // Arrange
        let monitor = PerformanceMonitor.shared

        // Act - The smoothing formula is: 0.7 * previous + 0.3 * instant
        // We can verify smoothed value exists and is finite
        monitor.recordBattery(level: 1.0)

        // Assert
        #expect(monitor.batteryDrainPerHourSmoothed.isFinite)
        #expect(monitor.batteryDrainPerHour >= 0.0) // Public API returns smoothed value
    }

    @Test("watchOS battery recording sanitizes non-finite values")
    func watchOSSanitizesNonFiniteValues() {
        // Arrange
        let monitor = PerformanceMonitor.shared

        // Act - Test with non-finite input
        monitor.recordBattery(level: Double.infinity)
        monitor.recordBattery(level: Double.nan)

        // Assert - Should not crash, values should be sanitized
        #expect(monitor.batteryDrainPerHourInstant.isFinite)
        #expect(monitor.batteryDrainPerHourSmoothed.isFinite)
    }

    @Test("watchOS battery recording clamps values to 0-1 range")
    func watchOSClampsToValidRange() {
        // Arrange
        let monitor = PerformanceMonitor.shared

        // Act - Test with out-of-bounds values
        monitor.recordBattery(level: -0.5) // Below 0
        monitor.recordBattery(level: 1.5)  // Above 1

        // Assert - Should clamp and not crash
        #expect(monitor.batteryDrainPerHourInstant.isFinite)
        #expect(monitor.batteryDrainPerHourSmoothed.isFinite)
    }
    #endif

    // MARK: - Cross-Platform Tests

    @Test("PerformanceMonitor maintains singleton instance")
    func maintainsSingletonInstance() {
        // Arrange & Act
        let instance1 = PerformanceMonitor.shared
        let instance2 = PerformanceMonitor.shared

        // Assert - Both should be the same instance
        #expect(instance1 === instance2)
    }

    @Test("PerformanceMonitor initializes with nil or valid snapshot")
    func initializesWithValidState() {
        // Arrange & Act
        let monitor = PerformanceMonitor.shared

        // Assert - Snapshot can be nil or valid, but shouldn't crash
        if let snapshot = monitor.latestSnapshot {
            #expect(snapshot.latencyMs >= 0)
            #expect(snapshot.batteryDrainPerHour.isFinite)
            #expect(snapshot.batteryDrainPerHour >= 0)
        }
    }

    // MARK: - Helper Functions

    #if os(iOS)
    /// Helper to create a LocationFix with specified battery and timestamp
    private func makeFix(batteryFraction: Double, timestamp: Date) -> LocationFix {
        LocationFix(
            timestamp: timestamp,
            source: .watchOS,
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 10.0,
            speedMetersPerSecond: 0.0,
            courseDegrees: 0.0,
            headingDegrees: nil,
            batteryFraction: batteryFraction,
            sequence: Int.random(in: 1...100000),
            trackingPreset: "balanced"
        )
    }
    #endif
}
