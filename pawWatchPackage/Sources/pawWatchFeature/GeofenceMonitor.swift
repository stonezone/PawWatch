//
//  GeofenceMonitor.swift
//  pawWatch
//
//  Purpose: Actor-isolated geofence monitoring for safe zones.
//           Detects when pet enters/exits safe zones and triggers notifications.
//
//  Created: 2025-02-09
//  Swift: 6.2
//  Platform: iOS 26.1+
//

#if os(iOS)
import Foundation
import CoreLocation
import OSLog
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Actor that monitors pet location against defined safe zones.
///
/// Responsibilities:
/// - Store and manage safe zone definitions
/// - Monitor location updates for zone boundary crossings
/// - Track zone entry/exit events
/// - Trigger local notifications on zone exit
/// - Persist safe zones and events to UserDefaults
///
/// Thread-safe via actor isolation.
public actor GeofenceMonitor {

    // MARK: - Published State

    /// All defined safe zones
    private var safeZones: [SafeZone] = []

    /// Recent geofence events (last 100)
    private var recentEvents: [SafeZoneEvent] = []

    /// Maximum number of events to keep in memory
    private let maxEventsToKeep = 100

    /// Last known location for each zone (zone ID -> location)
    private var lastKnownStates: [UUID: Bool] = [:] // true = inside, false = outside

    // MARK: - Constants

    private let safeZonesKey = "GeofenceMonitor.SafeZones"
    private let eventsKey = "GeofenceMonitor.Events"

    // MARK: - Dependencies

    private let logger = Logger(subsystem: PawWatchLog.subsystem, category: "GeofenceMonitor")
    private let userDefaults: UserDefaults

    /// Minimum time between notifications for the same zone (5 minutes)
    private let notificationCooldown: TimeInterval = 300

    /// Last notification time for each zone
    private var lastNotificationTime: [UUID: Date] = [:]

    // MARK: - Initialization

    public init(userDefaultsSuiteName: String? = nil) {
        self.userDefaults = UserDefaults(suiteName: userDefaultsSuiteName) ?? .standard
        // Load data in a nonisolated context
        self.safeZones = Self.loadSafeZones(from: self.userDefaults, key: safeZonesKey)
        self.recentEvents = Self.loadEvents(from: self.userDefaults, key: eventsKey)
    }

    // MARK: - Public API

    /// Get all safe zones
    public func getAllSafeZones() -> [SafeZone] {
        return safeZones
    }

    /// Add a new safe zone
    public func addSafeZone(_ zone: SafeZone) {
        safeZones.append(zone)
        saveToPersistence()
        logger.info("Added safe zone '\(zone.name)' (radius: \(zone.radiusMeters)m)")
    }

    /// Update an existing safe zone
    public func updateSafeZone(_ zone: SafeZone) {
        if let index = safeZones.firstIndex(where: { $0.id == zone.id }) {
            var updatedZone = zone
            updatedZone.touch()
            safeZones[index] = updatedZone
            saveToPersistence()
            logger.info("Updated safe zone '\(zone.name)'")
        }
    }

    /// Delete a safe zone
    public func deleteSafeZone(id: UUID) {
        if let index = safeZones.firstIndex(where: { $0.id == id }) {
            let name = safeZones[index].name
            safeZones.remove(at: index)
            lastKnownStates.removeValue(forKey: id)
            lastNotificationTime.removeValue(forKey: id)
            saveToPersistence()
            logger.info("Deleted safe zone '\(name)'")
        }
    }

    /// Enable or disable a safe zone
    public func setSafeZoneEnabled(_ id: UUID, enabled: Bool) {
        if let index = safeZones.firstIndex(where: { $0.id == id }) {
            safeZones[index].isEnabled = enabled
            safeZones[index].touch()
            saveToPersistence()
            logger.info("Safe zone '\(self.safeZones[index].name)' \(enabled ? "enabled" : "disabled")")
        }
    }

    /// Get recent geofence events
    public func getRecentEvents(limit: Int = 50) -> [SafeZoneEvent] {
        return Array(recentEvents.prefix(limit))
    }

    /// Process a new location fix and check for zone crossings
    public func processLocation(_ location: LocationFix) {
        let enabledZones = safeZones.filter { $0.isEnabled }

        // Track battery impact of geofence monitoring
        guard !enabledZones.isEmpty else { return }

        // Begin performance instrumentation
        let checkState = PerformanceInstrumentation.beginGeofenceCheck(zoneCount: enabledZones.count)
        var violationCount = 0
        defer {
            PerformanceInstrumentation.endGeofenceCheck(checkState, violations: violationCount)
        }

        Task {
            await BatteryProfiler.shared.recordInstantActivity(
                .geofenceMonitoring,
                duration: 0.1, // Minimal processing time
                batteryDelta: 0.001, // Negligible impact per check
                metadata: ["zonesChecked": "\(enabledZones.count)"]
            )
        }

        for zone in enabledZones {
            let isInside = zone.contains(location)
            let wasInside = lastKnownStates[zone.id]

            // Detect state change
            if let wasInside = wasInside {
                if wasInside && !isInside {
                    // Exit event
                    handleZoneExit(zone: zone, location: location)
                    violationCount += 1
                    PerformanceInstrumentation.recordBoundaryCrossing(zoneName: zone.name, entered: false)
                } else if !wasInside && isInside {
                    // Entry event (we log but don't notify)
                    handleZoneEntry(zone: zone, location: location)
                    PerformanceInstrumentation.recordBoundaryCrossing(zoneName: zone.name, entered: true)
                }
            }

            // Update state
            lastKnownStates[zone.id] = isInside
        }
    }

    /// Clear all safe zones and events (for testing or reset)
    public func clearAll() {
        safeZones.removeAll()
        recentEvents.removeAll()
        lastKnownStates.removeAll()
        lastNotificationTime.removeAll()
        saveToPersistence()
        logger.notice("Cleared all safe zones and events")
    }

    /// Clear all events (P3-05)
    public func clearEvents() {
        recentEvents.removeAll()
        saveEventsToPersistence()
        logger.notice("Cleared all geofence events")
    }

    // MARK: - Private Helpers

    private func handleZoneExit(zone: SafeZone, location: LocationFix) {
        logger.warning("Pet exited safe zone '\(zone.name)'")

        let event = SafeZoneEvent(
            zoneId: zone.id,
            type: .exited,
            location: location
        )

        addEvent(event)

        // Check cooldown before sending notification
        if shouldSendNotification(for: zone.id) {
            scheduleExitNotification(zone: zone, location: location, eventId: event.id)
            lastNotificationTime[zone.id] = Date()
        } else {
            logger.info("Notification for zone '\(zone.name)' suppressed (cooldown active)")
        }
    }

    private func handleZoneEntry(zone: SafeZone, location: LocationFix) {
        logger.info("Pet entered safe zone '\(zone.name)'")

        let event = SafeZoneEvent(
            zoneId: zone.id,
            type: .entered,
            location: location
        )

        addEvent(event)
    }

    private func addEvent(_ event: SafeZoneEvent) {
        recentEvents.insert(event, at: 0)

        // Trim to max size
        if recentEvents.count > maxEventsToKeep {
            recentEvents = Array(recentEvents.prefix(maxEventsToKeep))
        }

        saveEventsToPersistence()
    }

    private func shouldSendNotification(for zoneId: UUID) -> Bool {
        guard let lastTime = lastNotificationTime[zoneId] else {
            return true // No previous notification
        }

        let elapsed = Date().timeIntervalSince(lastTime)
        return elapsed >= notificationCooldown
    }

    private func scheduleExitNotification(zone: SafeZone, location: LocationFix, eventId: UUID) {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()

        content.title = "Safe Zone Alert"
        content.body = "Your pet has left '\(zone.name)' safe zone."
        content.sound = .defaultCritical
        content.categoryIdentifier = "pawwatch.geofence-alert"

        // Add distance information
        let distance = zone.distanceTo(location)
        let distanceMeters = Int(distance)
        let distanceFeet = Int(distance * 3.28084)
        content.subtitle = "\(distanceMeters)m (\(distanceFeet)ft) from zone center"

        // Store event ID for potential action handling
        content.userInfo = [
            "eventId": eventId.uuidString,
            "zoneId": zone.id.uuidString
        ]

        let request = UNNotificationRequest(
            identifier: "pawwatch.geofence.\(zone.id.uuidString)",
            content: content,
            trigger: nil // Immediate delivery
        )

        center.add(request) { [logger] error in
            if let error = error {
                logger.error("Failed to schedule geofence notification: \(error.localizedDescription, privacy: .public)")
            } else {
                logger.notice("Geofence exit notification sent for zone '\(zone.name)'")
            }
        }
        #endif
    }

    // MARK: - Persistence

    private func saveToPersistence() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(safeZones)
            userDefaults.set(data, forKey: safeZonesKey)
            logger.debug("Saved \(self.safeZones.count) safe zones to persistence")
        } catch {
            logger.error("Failed to save safe zones: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func saveEventsToPersistence() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(recentEvents)
            userDefaults.set(data, forKey: eventsKey)
        } catch {
            logger.error("Failed to save events: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadFromPersistence() {
        // Load safe zones
        if let data = userDefaults.data(forKey: safeZonesKey) {
            do {
                let decoder = JSONDecoder()
                safeZones = try decoder.decode([SafeZone].self, from: data)
                logger.info("Loaded \(self.safeZones.count) safe zones from persistence")
            } catch {
                logger.error("Failed to load safe zones: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Load events
        if let data = userDefaults.data(forKey: eventsKey) {
            do {
                let decoder = JSONDecoder()
                recentEvents = try decoder.decode([SafeZoneEvent].self, from: data)
                logger.info("Loaded \(self.recentEvents.count) events from persistence")
            } catch {
                logger.error("Failed to load events: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Static Loading Helpers

    /// Load safe zones from UserDefaults in a nonisolated context
    private static func loadSafeZones(from userDefaults: UserDefaults, key: String) -> [SafeZone] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode([SafeZone].self, from: data)
        } catch {
            return []
        }
    }

    /// Load events from UserDefaults in a nonisolated context
    private static func loadEvents(from userDefaults: UserDefaults, key: String) -> [SafeZoneEvent] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode([SafeZoneEvent].self, from: data)
        } catch {
            return []
        }
    }
}
#endif
