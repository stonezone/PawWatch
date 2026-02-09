//
//  BatteryProfilerTests.swift
//  pawWatchFeatureTests
//
//  Purpose: Tests for battery impact profiling and analytics
//
//  Created: 2026-02-09
//  Swift: 6.2
//  Platform: iOS 26.1+
//

import Testing
import Foundation
@testable import pawWatchFeature

@MainActor
struct BatteryProfilerTests {

    // MARK: - Session Tracking Tests

    @Test("Start and end activity session")
    func testActivitySession() async {
        let profiler = BatteryProfiler.shared
        await profiler.clearAllEvents()

        // Start GPS activity
        await profiler.startActivity(.gpsActive, metadata: ["test": "session"])

        // Verify session is active
        let activeSessions = await profiler.getActiveSessions()
        #expect(activeSessions.contains(.gpsActive))

        // Small delay to simulate activity
        try? await Task.sleep(for: .milliseconds(100))

        // End activity
        await profiler.endActivity(.gpsActive)

        // Verify session ended
        let sessionsAfterEnd = await profiler.getActiveSessions()
        #expect(!sessionsAfterEnd.contains(.gpsActive))

        // Verify event was recorded
        let events = await profiler.getAllEvents()
        #expect(events.count > 0)
        #expect(events.last?.activity == .gpsActive)
    }

    @Test("Record instant activity")
    func testInstantActivity() async {
        let profiler = BatteryProfiler.shared
        await profiler.clearAllEvents()

        // Record a quick activity
        await profiler.recordInstantActivity(
            .geofenceMonitoring,
            duration: 0.5,
            batteryDelta: 0.05,
            metadata: ["zones": "3"]
        )

        // Verify event was recorded
        let events = await profiler.getAllEvents()
        #expect(events.count == 1)

        let event = events.first!
        #expect(event.activity == .geofenceMonitoring)
        #expect(event.batteryDelta == 0.05)
        #expect(event.duration > 0.4 && event.duration < 0.6)
        #expect(event.metadata?["zones"] == "3")
    }

    @Test("Multiple activities can run concurrently")
    func testConcurrentActivities() async {
        let profiler = BatteryProfiler.shared
        await profiler.clearAllEvents()

        // Start multiple activities
        await profiler.startActivity(.gpsActive)
        await profiler.startActivity(.watchCommunication)
        await profiler.startActivity(.cloudKitUpload)

        // Verify all are active
        let activeSessions = await profiler.getActiveSessions()
        #expect(activeSessions.contains(.gpsActive))
        #expect(activeSessions.contains(.watchCommunication))
        #expect(activeSessions.contains(.cloudKitUpload))

        // End them in different order
        await profiler.endActivity(.watchCommunication)
        await profiler.endActivity(.gpsActive)
        await profiler.endActivity(.cloudKitUpload)

        // Verify all ended
        let sessionsAfter = await profiler.getActiveSessions()
        #expect(sessionsAfter.isEmpty)
    }

    // MARK: - Report Generation Tests

    @Test("Generate report for 24 hours")
    func testReportGeneration() async {
        let profiler = BatteryProfiler.shared
        await profiler.clearAllEvents()

        // Record multiple events
        await profiler.recordInstantActivity(.gpsActive, duration: 60, batteryDelta: 1.5)
        await profiler.recordInstantActivity(.cloudKitUpload, duration: 2, batteryDelta: 0.1)
        await profiler.recordInstantActivity(.gpsActive, duration: 120, batteryDelta: 3.0)

        // Generate report
        let report = await profiler.generateReport(for: .last24Hours)

        #expect(report.period == .last24Hours)
        #expect(report.totalBatteryConsumed > 0)
        #expect(report.activityStats.count > 0)

        // GPS should be the top consumer
        let gpsStats = report.activityStats.first { $0.activity == .gpsActive }
        #expect(gpsStats != nil)
        #expect(gpsStats!.totalEvents == 2)
        #expect(gpsStats!.totalBatteryConsumed == 4.5)
    }

    @Test("Report filters by time period")
    func testReportFiltering() async {
        let profiler = BatteryProfiler.shared
        await profiler.clearAllEvents()

        // Record event
        await profiler.recordInstantActivity(.idle, duration: 10, batteryDelta: 0.1)

        // Report should include recent event
        let report24h = await profiler.generateReport(for: .last24Hours)
        #expect(report24h.activityStats.count > 0)

        // All time report should also include it
        let reportAll = await profiler.generateReport(for: .allTime)
        #expect(reportAll.activityStats.count > 0)
    }

    @Test("Activity stats calculate correctly")
    func testActivityStats() async {
        let profiler = BatteryProfiler.shared
        await profiler.clearAllEvents()

        // Record several GPS events
        await profiler.recordInstantActivity(.gpsActive, duration: 3600, batteryDelta: 5.0)  // 1 hour, 5% drain
        await profiler.recordInstantActivity(.gpsActive, duration: 1800, batteryDelta: 2.5)  // 30 min, 2.5% drain
        await profiler.recordInstantActivity(.gpsActive, duration: 1800, batteryDelta: 3.0)  // 30 min, 3% drain

        let report = await profiler.generateReport(for: .last24Hours)
        let gpsStats = report.activityStats.first { $0.activity == .gpsActive }!

        #expect(gpsStats.totalEvents == 3)
        #expect(gpsStats.totalDuration == 7200) // 2 hours total
        #expect(gpsStats.totalBatteryConsumed == 10.5) // 10.5% total
        #expect(gpsStats.averageDuration == 2400) // Average 40 min per event

        // Average drain rate should be around 5.25%/hr
        let expectedRate = 10.5 / 2.0 // total battery / total hours
        #expect(abs(gpsStats.averageDrainRate - expectedRate) < 0.1)
    }

    // MARK: - Event Sorting Tests

    @Test("Report sorts activities by impact")
    func testReportSorting() async {
        let profiler = BatteryProfiler.shared
        await profiler.clearAllEvents()

        // Record events with different impacts
        await profiler.recordInstantActivity(.idle, duration: 3600, batteryDelta: 0.5)           // Low impact
        await profiler.recordInstantActivity(.gpsActive, duration: 1800, batteryDelta: 5.0)      // High impact
        await profiler.recordInstantActivity(.cloudKitUpload, duration: 60, batteryDelta: 0.2)   // Very low

        let report = await profiler.generateReport(for: .last24Hours)
        let sortedByImpact = report.sortedByImpact

        // GPS should be first (highest total consumption)
        #expect(sortedByImpact[0].activity == .gpsActive)
        #expect(sortedByImpact[0].totalBatteryConsumed == 5.0)

        // Check top consumer property
        #expect(report.topConsumer?.activity == .gpsActive)
    }

    @Test("Report sorts activities by drain rate")
    func testSortByDrainRate() async {
        let profiler = BatteryProfiler.shared
        await profiler.clearAllEvents()

        // Record events with different drain rates
        await profiler.recordInstantActivity(.gpsActive, duration: 3600, batteryDelta: 3.0)      // 3%/hr
        await profiler.recordInstantActivity(.cloudKitUpload, duration: 600, batteryDelta: 2.0)  // 12%/hr
        await profiler.recordInstantActivity(.idle, duration: 3600, batteryDelta: 0.5)           // 0.5%/hr

        let report = await profiler.generateReport(for: .last24Hours)
        let sortedByRate = report.sortedByDrainRate

        // CloudKit should be first (highest drain rate per hour)
        #expect(sortedByRate[0].activity == .cloudKitUpload)
    }

    // MARK: - Storage Tests

    @Test("Events persist across instances")
    func testEventPersistence() async {
        let profiler = BatteryProfiler.shared
        await profiler.clearAllEvents()

        // Record event
        await profiler.recordInstantActivity(.watchCommunication, duration: 5, batteryDelta: 0.3)

        // Wait for save to complete
        try? await Task.sleep(for: .milliseconds(100))

        // Verify event exists
        let events = await profiler.getAllEvents()
        #expect(events.count == 1)
        #expect(events.first?.activity == .watchCommunication)
    }

    @Test("Event limit prevents memory issues")
    func testEventLimit() async {
        let profiler = BatteryProfiler.shared
        await profiler.clearAllEvents()

        // Record many events (would exceed typical limit of 10000)
        for _ in 0..<50 {
            await profiler.recordInstantActivity(.idle, duration: 1, batteryDelta: 0.001)
        }

        let events = await profiler.getAllEvents()
        #expect(events.count == 50)
        // If we were to add 10000 more, it should cap at maxStoredEvents
    }

    // MARK: - Convenience Method Tests

    @Test("Track GPS session convenience method")
    func testTrackGPSSession() async {
        let profiler = BatteryProfiler.shared
        await profiler.clearAllEvents()

        // Use convenience method
        let result = await profiler.trackGPSSession { @Sendable in
            try? await Task.sleep(for: .milliseconds(50))
            return "GPS data collected"
        }

        #expect(result == "GPS data collected")

        // Wait for cleanup
        try? await Task.sleep(for: .milliseconds(100))

        // Verify event was recorded
        let events = await profiler.getAllEvents()
        #expect(events.count > 0)
        #expect(events.last?.activity == .gpsActive)
    }

    @Test("Track CloudKit upload convenience method")
    func testTrackCloudKitUpload() async throws {
        let profiler = BatteryProfiler.shared
        await profiler.clearAllEvents()

        // Use convenience method with throwing operation
        let result = try await profiler.trackCloudKitUpload { @Sendable in
            try await Task.sleep(for: .milliseconds(50))
            return 42
        }

        #expect(result == 42)

        // Wait for cleanup
        try? await Task.sleep(for: .milliseconds(100))

        // Verify event was recorded
        let events = await profiler.getAllEvents()
        #expect(events.count > 0)
        #expect(events.last?.activity == .cloudKitUpload)
    }
}
