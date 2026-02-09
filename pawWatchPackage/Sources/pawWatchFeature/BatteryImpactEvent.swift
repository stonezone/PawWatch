//
//  BatteryImpactEvent.swift
//  pawWatch
//
//  Purpose: Battery impact event types and measurement structures for profiling
//           which features consume battery power.
//
//  Author: Created for pawWatch
//  Created: 2026-02-09
//  Swift: 6.2
//  Platform: iOS 26.1+, watchOS 11.0+
//

import Foundation

/// Represents a specific activity or feature that impacts battery consumption
public enum BatteryActivity: String, CaseIterable, Codable, Sendable {
    case gpsActive = "gps_active"
    case connectivityRelay = "connectivity_relay"
    case cloudKitUpload = "cloudkit_upload"
    case cloudKitDownload = "cloudkit_download"
    case idle = "idle"
    case geofenceMonitoring = "geofence_monitoring"
    case backgroundRefresh = "background_refresh"
    case motionProcessing = "motion_processing"
    case watchCommunication = "watch_communication"

    public var displayName: String {
        switch self {
        case .gpsActive:
            return "GPS Active"
        case .connectivityRelay:
            return "Watch Connectivity"
        case .cloudKitUpload:
            return "CloudKit Upload"
        case .cloudKitDownload:
            return "CloudKit Download"
        case .idle:
            return "Idle/Sleep"
        case .geofenceMonitoring:
            return "Geofence Monitoring"
        case .backgroundRefresh:
            return "Background Refresh"
        case .motionProcessing:
            return "Motion Processing"
        case .watchCommunication:
            return "Watch Communication"
        }
    }

    public var systemIcon: String {
        switch self {
        case .gpsActive:
            return "location.fill"
        case .connectivityRelay:
            return "antenna.radiowaves.left.and.right"
        case .cloudKitUpload:
            return "icloud.and.arrow.up"
        case .cloudKitDownload:
            return "icloud.and.arrow.down"
        case .idle:
            return "moon.fill"
        case .geofenceMonitoring:
            return "mappin.circle"
        case .backgroundRefresh:
            return "arrow.clockwise"
        case .motionProcessing:
            return "figure.walk"
        case .watchCommunication:
            return "applewatch"
        }
    }
}

/// Records a battery impact measurement for a specific activity
public struct BatteryImpactEvent: Codable, Identifiable, Sendable {
    public let id: UUID
    public let activity: BatteryActivity
    public let startTime: Date
    public let endTime: Date
    public let batteryDelta: Double // Battery percentage consumed (0.0 to 100.0)
    public let batteryLevelStart: Double // Battery level at start (0.0 to 1.0)
    public let batteryLevelEnd: Double // Battery level at end (0.0 to 1.0)
    public let metadata: [String: String]? // Additional context

    public init(
        id: UUID = UUID(),
        activity: BatteryActivity,
        startTime: Date,
        endTime: Date,
        batteryDelta: Double,
        batteryLevelStart: Double,
        batteryLevelEnd: Double,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.activity = activity
        self.startTime = startTime
        self.endTime = endTime
        self.batteryDelta = batteryDelta
        self.batteryLevelStart = batteryLevelStart
        self.batteryLevelEnd = batteryLevelEnd
        self.metadata = metadata
    }

    /// Duration of the activity in seconds
    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    /// Battery drain rate in percentage per hour
    public var drainRatePerHour: Double {
        guard duration > 0 else { return 0 }
        let hours = duration / 3600
        return batteryDelta / hours
    }
}

/// Aggregated battery statistics for a specific activity
public struct BatteryActivityStats: Identifiable, Sendable {
    public let activity: BatteryActivity
    public let totalEvents: Int
    public let totalDuration: TimeInterval
    public let totalBatteryConsumed: Double // Total percentage consumed
    public let averageDrainRate: Double // Average drain rate in % per hour
    public let peakDrainRate: Double // Maximum drain rate observed
    public let lastEventTime: Date?

    public var id: String { activity.rawValue }

    public init(
        activity: BatteryActivity,
        totalEvents: Int,
        totalDuration: TimeInterval,
        totalBatteryConsumed: Double,
        averageDrainRate: Double,
        peakDrainRate: Double,
        lastEventTime: Date?
    ) {
        self.activity = activity
        self.totalEvents = totalEvents
        self.totalDuration = totalDuration
        self.totalBatteryConsumed = totalBatteryConsumed
        self.averageDrainRate = averageDrainRate
        self.peakDrainRate = peakDrainRate
        self.lastEventTime = lastEventTime
    }

    /// Average event duration in seconds
    public var averageDuration: TimeInterval {
        guard totalEvents > 0 else { return 0 }
        return totalDuration / Double(totalEvents)
    }

    /// Battery consumed per event (average)
    public var averageBatteryPerEvent: Double {
        guard totalEvents > 0 else { return 0 }
        return totalBatteryConsumed / Double(totalEvents)
    }
}

/// Time period for filtering battery reports
public enum BatteryReportPeriod: String, CaseIterable, Identifiable, Sendable {
    case last24Hours = "24h"
    case last7Days = "7d"
    case last30Days = "30d"
    case allTime = "all"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .last24Hours:
            return "Last 24 Hours"
        case .last7Days:
            return "Last 7 Days"
        case .last30Days:
            return "Last 30 Days"
        case .allTime:
            return "All Time"
        }
    }

    public var startDate: Date? {
        let now = Date()
        switch self {
        case .last24Hours:
            return Calendar.current.date(byAdding: .hour, value: -24, to: now)
        case .last7Days:
            return Calendar.current.date(byAdding: .day, value: -7, to: now)
        case .last30Days:
            return Calendar.current.date(byAdding: .day, value: -30, to: now)
        case .allTime:
            return nil
        }
    }
}

/// Comprehensive battery impact report
public struct BatteryImpactReport: Sendable {
    public let period: BatteryReportPeriod
    public let activityStats: [BatteryActivityStats]
    public let totalBatteryConsumed: Double
    public let reportGeneratedAt: Date

    public init(
        period: BatteryReportPeriod,
        activityStats: [BatteryActivityStats],
        totalBatteryConsumed: Double,
        reportGeneratedAt: Date = Date()
    ) {
        self.period = period
        self.activityStats = activityStats
        self.totalBatteryConsumed = totalBatteryConsumed
        self.reportGeneratedAt = reportGeneratedAt
    }

    /// Activity stats sorted by total battery consumed (descending)
    public var sortedByImpact: [BatteryActivityStats] {
        activityStats.sorted { $0.totalBatteryConsumed > $1.totalBatteryConsumed }
    }

    /// Activity stats sorted by average drain rate (descending)
    public var sortedByDrainRate: [BatteryActivityStats] {
        activityStats.sorted { $0.averageDrainRate > $1.averageDrainRate }
    }

    /// Most battery-intensive activity
    public var topConsumer: BatteryActivityStats? {
        sortedByImpact.first
    }
}
