//
//  BatteryProfiler.swift
//  pawWatch
//
//  Purpose: Tracks battery impact by feature/activity to identify which components
//           consume the most power. Provides analytics and reporting capabilities.
//
//  Author: Created for pawWatch
//  Created: 2026-02-09
//  Swift: 6.2
//  Platform: iOS 26.1+, watchOS 11.0+
//

import Foundation
#if os(watchOS)
import WatchKit
#elseif os(iOS)
import UIKit
#endif

/// Actor that profiles battery consumption by tracking activity sessions and measuring battery drain
public actor BatteryProfiler {
    private static let defaultSuiteName = "group.com.stonezone.pawWatch"
    public static let shared = BatteryProfiler()

    // MARK: - Storage

    private var events: [BatteryImpactEvent] = []
    private var activeSessionsStorage: [BatteryActivity: ActiveSession] = [:]
    private let maxStoredEvents = 10000 // Limit memory footprint
    private let storageKey = "BatteryProfiler.events"
    private let suiteName: String
    private var hasLoadedStoredEvents = false

    // MARK: - Active Session Tracking

    private struct ActiveSession: Sendable {
        let activity: BatteryActivity
        let startTime: Date
        let batteryLevelAtStart: Double
        let metadata: [String: String]?
    }

    // MARK: - Initialization

    init(suiteName: String = BatteryProfiler.defaultSuiteName) {
        self.suiteName = suiteName
        // Lazy-load persisted events on first API use to avoid init races.
    }

    // MARK: - Session Management

    /// Begin tracking battery consumption for a specific activity
    public func startActivity(
        _ activity: BatteryActivity,
        metadata: [String: String]? = nil
    ) async {
        await ensureEventsLoaded()
        let batteryLevel = await getCurrentBatteryLevel()
        let session = ActiveSession(
            activity: activity,
            startTime: Date(),
            batteryLevelAtStart: batteryLevel,
            metadata: metadata
        )
        activeSessionsStorage[activity] = session
    }

    /// End tracking for a specific activity and record the battery impact
    public func endActivity(_ activity: BatteryActivity) async {
        await ensureEventsLoaded()
        guard let session = activeSessionsStorage.removeValue(forKey: activity) else {
            return
        }

        let endTime = Date()
        let batteryLevelEnd = await getCurrentBatteryLevel()

        // Only record if battery actually decreased
        let batteryDelta = (session.batteryLevelAtStart - batteryLevelEnd) * 100
        guard batteryDelta >= 0 else {
            // Battery increased (charging) or no change - don't record
            return
        }

        let event = BatteryImpactEvent(
            activity: activity,
            startTime: session.startTime,
            endTime: endTime,
            batteryDelta: batteryDelta,
            batteryLevelStart: session.batteryLevelAtStart,
            batteryLevelEnd: batteryLevelEnd,
            metadata: session.metadata
        )

        recordEvent(event)
    }

    /// Record a one-off battery impact event (for activities that don't need start/end tracking)
    public func recordInstantActivity(
        _ activity: BatteryActivity,
        duration: TimeInterval,
        batteryDelta: Double,
        metadata: [String: String]? = nil
    ) async {
        await ensureEventsLoaded()
        let now = Date()
        let startTime = now.addingTimeInterval(-duration)
        let batteryLevel = await getCurrentBatteryLevel()

        let event = BatteryImpactEvent(
            activity: activity,
            startTime: startTime,
            endTime: now,
            batteryDelta: batteryDelta,
            batteryLevelStart: batteryLevel + (batteryDelta / 100),
            batteryLevelEnd: batteryLevel,
            metadata: metadata
        )

        recordEvent(event)
    }

    // MARK: - Event Recording

    private func recordEvent(_ event: BatteryImpactEvent) {
        events.append(event)

        // Trim old events if exceeding limit
        if events.count > maxStoredEvents {
            let excess = events.count - maxStoredEvents
            events.removeFirst(excess)
        }

        saveEvents()
    }

    // MARK: - Analytics & Reporting

    /// Generate a battery impact report for a specific time period
    public func generateReport(for period: BatteryReportPeriod) async -> BatteryImpactReport {
        await ensureEventsLoaded()
        let filteredEvents = filterEvents(for: period)
        let activityStats = calculateActivityStats(from: filteredEvents)
        let totalBatteryConsumed = filteredEvents.reduce(0) { $0 + $1.batteryDelta }

        return BatteryImpactReport(
            period: period,
            activityStats: activityStats,
            totalBatteryConsumed: totalBatteryConsumed
        )
    }

    /// Get statistics for a specific activity
    public func getStats(for activity: BatteryActivity, period: BatteryReportPeriod) async -> BatteryActivityStats? {
        await ensureEventsLoaded()
        let report = await generateReport(for: period)
        return report.activityStats.first { $0.activity == activity }
    }

    /// Get all recorded events (for debugging/detailed analysis)
    public func getAllEvents() async -> [BatteryImpactEvent] {
        await ensureEventsLoaded()
        return events
    }

    /// Get events within a specific time period
    public func getEvents(for period: BatteryReportPeriod) async -> [BatteryImpactEvent] {
        await ensureEventsLoaded()
        return filterEvents(for: period)
    }

    /// Clear all stored events (useful for testing or resetting analytics)
    public func clearAllEvents() async {
        await ensureEventsLoaded()
        events.removeAll()
        activeSessionsStorage.removeAll()
        saveEvents()
    }

    /// Get currently active sessions
    public func getActiveSessions() async -> [BatteryActivity] {
        await ensureEventsLoaded()
        return Array(activeSessionsStorage.keys)
    }

    // MARK: - Private Helpers

    private func filterEvents(for period: BatteryReportPeriod) -> [BatteryImpactEvent] {
        guard let startDate = period.startDate else {
            return events // All time
        }

        return events.filter { $0.startTime >= startDate }
    }

    private func calculateActivityStats(from events: [BatteryImpactEvent]) -> [BatteryActivityStats] {
        var statsDict: [BatteryActivity: (
            events: [BatteryImpactEvent],
            totalDuration: TimeInterval,
            totalBattery: Double,
            peakRate: Double
        )] = [:]

        // Group events by activity
        for event in events {
            var current = statsDict[event.activity] ?? ([], 0, 0, 0)
            current.events.append(event)
            current.totalDuration += event.duration
            current.totalBattery += event.batteryDelta
            current.peakRate = max(current.peakRate, event.drainRatePerHour)
            statsDict[event.activity] = current
        }

        // Convert to BatteryActivityStats
        return statsDict.map { activity, data in
            let averageRate = data.totalDuration > 0
                ? (data.totalBattery / (data.totalDuration / 3600))
                : 0

            return BatteryActivityStats(
                activity: activity,
                totalEvents: data.events.count,
                totalDuration: data.totalDuration,
                totalBatteryConsumed: data.totalBattery,
                averageDrainRate: averageRate,
                peakDrainRate: data.peakRate,
                lastEventTime: data.events.last?.endTime
            )
        }.sorted { $0.totalBatteryConsumed > $1.totalBatteryConsumed }
    }

    private func getCurrentBatteryLevel() async -> Double {
        #if os(watchOS)
        return await MainActor.run {
            let device = WKInterfaceDevice.current()
            device.isBatteryMonitoringEnabled = true
            let level = device.batteryLevel
            return Double(level)
        }
        #elseif os(iOS)
        return await MainActor.run {
            UIDevice.current.isBatteryMonitoringEnabled = true
            let level = UIDevice.current.batteryLevel
            return Double(level)
        }
        #else
        return 1.0 // macOS/simulator fallback
        #endif
    }

    // MARK: - Persistence

    private func saveEvents() {
        let defaults = makeDefaults()

        do {
            let encoded = try JSONEncoder().encode(events)
            defaults.set(encoded, forKey: storageKey)
        } catch {
            print("Failed to save battery events: \(error)")
        }
    }

    private func loadStoredEvents() {
        let defaults = makeDefaults()
        guard let data = defaults.data(forKey: storageKey) else {
            return
        }

        do {
            events = try JSONDecoder().decode([BatteryImpactEvent].self, from: data)
        } catch {
            print("Failed to load battery events: \(error)")
        }
    }

    private func ensureEventsLoaded() async {
        guard !hasLoadedStoredEvents else { return }
        loadStoredEvents()
        hasLoadedStoredEvents = true
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}

// MARK: - Convenience Extensions

extension BatteryProfiler {
    /// Track a GPS session with automatic start/end
    public func trackGPSSession<T>(
        _ operation: () async throws -> T
    ) async rethrows -> T {
        await startActivity(.gpsActive)
        do {
            let result = try await operation()
            await endActivity(.gpsActive)
            return result
        } catch {
            await endActivity(.gpsActive)
            throw error
        }
    }

    /// Track a CloudKit operation
    public func trackCloudKitUpload<T>(
        _ operation: () async throws -> T
    ) async rethrows -> T {
        await startActivity(.cloudKitUpload)
        do {
            let result = try await operation()
            await endActivity(.cloudKitUpload)
            return result
        } catch {
            await endActivity(.cloudKitUpload)
            throw error
        }
    }

    /// Track a watch communication session
    public func trackWatchCommunication<T>(
        _ operation: () async throws -> T
    ) async rethrows -> T {
        await startActivity(.watchCommunication)
        do {
            let result = try await operation()
            await endActivity(.watchCommunication)
            return result
        } catch {
            await endActivity(.watchCommunication)
            throw error
        }
    }
}
