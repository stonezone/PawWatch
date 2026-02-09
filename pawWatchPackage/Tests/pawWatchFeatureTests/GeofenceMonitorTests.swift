//
//  GeofenceMonitorTests.swift
//  pawWatchFeatureTests
//
//  Purpose: Test suite for GeofenceMonitor actor verifying safe zone boundary detection,
//           event tracking, and notification logic.
//
//  Created: 2025-02-09
//  Swift: 6.2
//  Platform: iOS 26.1+
//

#if os(iOS)
import Testing
import Foundation
@testable import pawWatchFeature

/// Test suite for GeofenceMonitor functionality
@Suite("GeofenceMonitor Tests")
struct GeofenceMonitorTests {

    // MARK: - Safe Zone Management Tests

    @Test("Add safe zone stores zone correctly")
    func addSafeZone() async throws {
        let monitor = GeofenceMonitor(userDefaults: .ephemeral)

        let zone = SafeZone(
            name: "Home",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 100
        )

        await monitor.addSafeZone(zone)

        let zones = await monitor.getAllSafeZones()
        #expect(zones.count == 1)
        #expect(zones[0].name == "Home")
        #expect(zones[0].radiusMeters == 100)
    }

    @Test("Update safe zone modifies existing zone")
    func updateSafeZone() async throws {
        let monitor = GeofenceMonitor(userDefaults: .ephemeral)

        var zone = SafeZone(
            name: "Original",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 100
        )

        await monitor.addSafeZone(zone)

        zone.name = "Updated"
        zone.radiusMeters = 200

        await monitor.updateSafeZone(zone)

        let zones = await monitor.getAllSafeZones()
        #expect(zones.count == 1)
        #expect(zones[0].name == "Updated")
        #expect(zones[0].radiusMeters == 200)
    }

    @Test("Delete safe zone removes zone")
    func deleteSafeZone() async throws {
        let monitor = GeofenceMonitor(userDefaults: .ephemeral)

        let zone = SafeZone(
            name: "Test",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 100
        )

        await monitor.addSafeZone(zone)
        #expect(await monitor.getAllSafeZones().count == 1)

        await monitor.deleteSafeZone(id: zone.id)
        #expect(await monitor.getAllSafeZones().isEmpty)
    }

    @Test("Enable and disable safe zone toggles state")
    func toggleSafeZone() async throws {
        let monitor = GeofenceMonitor(userDefaults: .ephemeral)

        let zone = SafeZone(
            name: "Test",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 100,
            isEnabled: true
        )

        await monitor.addSafeZone(zone)

        await monitor.setSafeZoneEnabled(zone.id, enabled: false)
        var zones = await monitor.getAllSafeZones()
        #expect(zones[0].isEnabled == false)

        await monitor.setSafeZoneEnabled(zone.id, enabled: true)
        zones = await monitor.getAllSafeZones()
        #expect(zones[0].isEnabled == true)
    }

    // MARK: - Geofence Detection Tests

    @Test("Location inside zone does not trigger exit event")
    func locationInsideZone() async throws {
        let monitor = GeofenceMonitor(userDefaults: .ephemeral)

        let zone = SafeZone(
            name: "Home",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 100
        )

        await monitor.addSafeZone(zone)

        // Create location inside zone (same as center)
        let insideLocation = createTestFix(
            latitude: 37.7749,
            longitude: -122.4194
        )

        await monitor.processLocation(insideLocation)

        // First location establishes baseline - no event
        let events = await monitor.getRecentEvents()
        #expect(events.isEmpty)
    }

    @Test("Location exiting zone triggers exit event")
    func locationExitingZone() async throws {
        let monitor = GeofenceMonitor(userDefaults: .ephemeral)

        let zone = SafeZone(
            name: "Home",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 50 // 50 meter radius
        )

        await monitor.addSafeZone(zone)

        // First location: inside zone (at center)
        let insideLocation = createTestFix(
            latitude: 37.7749,
            longitude: -122.4194
        )
        await monitor.processLocation(insideLocation)

        // Second location: outside zone (roughly 100m away)
        let outsideLocation = createTestFix(
            latitude: 37.7758, // ~0.0009 degrees ≈ 100m north
            longitude: -122.4194,
            sequence: 2
        )
        await monitor.processLocation(outsideLocation)

        let events = await monitor.getRecentEvents()
        #expect(events.count == 1)
        #expect(events[0].type == .exited)
        #expect(events[0].zoneId == zone.id)
    }

    @Test("Location entering zone triggers entry event")
    func locationEnteringZone() async throws {
        let monitor = GeofenceMonitor(userDefaults: .ephemeral)

        let zone = SafeZone(
            name: "Home",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 50
        )

        await monitor.addSafeZone(zone)

        // First location: outside zone
        let outsideLocation = createTestFix(
            latitude: 37.7758, // ~100m away
            longitude: -122.4194
        )
        await monitor.processLocation(outsideLocation)

        // Second location: inside zone
        let insideLocation = createTestFix(
            latitude: 37.7749,
            longitude: -122.4194,
            sequence: 2
        )
        await monitor.processLocation(insideLocation)

        let events = await monitor.getRecentEvents()
        #expect(events.count == 1)
        #expect(events[0].type == .entered)
        #expect(events[0].zoneId == zone.id)
    }

    @Test("Disabled zone does not trigger events")
    func disabledZoneNoEvents() async throws {
        let monitor = GeofenceMonitor(userDefaults: .ephemeral)

        let zone = SafeZone(
            name: "Home",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 50,
            isEnabled: false // Disabled
        )

        await monitor.addSafeZone(zone)

        // Inside location
        let insideLocation = createTestFix(
            latitude: 37.7749,
            longitude: -122.4194
        )
        await monitor.processLocation(insideLocation)

        // Outside location
        let outsideLocation = createTestFix(
            latitude: 37.7758,
            longitude: -122.4194,
            sequence: 2
        )
        await monitor.processLocation(outsideLocation)

        let events = await monitor.getRecentEvents()
        #expect(events.isEmpty) // No events because zone is disabled
    }

    @Test("Multiple zones tracked independently")
    func multipleZones() async throws {
        let monitor = GeofenceMonitor(userDefaults: .ephemeral)

        let homeZone = SafeZone(
            name: "Home",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 50
        )

        let parkZone = SafeZone(
            name: "Park",
            coordinate: LocationFix.Coordinate(latitude: 37.7700, longitude: -122.4100),
            radiusMeters: 100
        )

        await monitor.addSafeZone(homeZone)
        await monitor.addSafeZone(parkZone)

        // Start inside home zone
        let atHome = createTestFix(latitude: 37.7749, longitude: -122.4194)
        await monitor.processLocation(atHome)

        // Move outside both zones
        let elsewhere = createTestFix(latitude: 37.8000, longitude: -122.5000, sequence: 2)
        await monitor.processLocation(elsewhere)

        let events = await monitor.getRecentEvents()
        // Should have one exit event for home (park was never entered)
        #expect(events.count == 1)
        #expect(events[0].type == .exited)
        #expect(events[0].zoneId == homeZone.id)
    }

    // MARK: - Event History Tests

    @Test("Recent events limited to max count")
    func eventHistoryLimit() async throws {
        let monitor = GeofenceMonitor(userDefaults: .ephemeral)

        let zone = SafeZone(
            name: "Test",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 50
        )

        await monitor.addSafeZone(zone)

        // Generate many events by alternating inside/outside
        for i in 0..<150 {
            let isInside = i % 2 == 0
            let lat = isInside ? 37.7749 : 37.7758
            let fix = createTestFix(latitude: lat, longitude: -122.4194, sequence: i)
            await monitor.processLocation(fix)
        }

        let events = await monitor.getRecentEvents(limit: 200)
        // Should be capped at 100 (maxEventsToKeep)
        #expect(events.count == 100)
    }

    @Test("Clear all removes zones and events")
    func clearAll() async throws {
        let monitor = GeofenceMonitor(userDefaults: .ephemeral)

        let zone = SafeZone(
            name: "Test",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 50
        )

        await monitor.addSafeZone(zone)

        // Generate some events
        let inside = createTestFix(latitude: 37.7749, longitude: -122.4194)
        await monitor.processLocation(inside)
        let outside = createTestFix(latitude: 37.7758, longitude: -122.4194, sequence: 2)
        await monitor.processLocation(outside)

        #expect(await !monitor.getAllSafeZones().isEmpty)
        #expect(await !monitor.getRecentEvents().isEmpty)

        await monitor.clearAll()

        #expect(await monitor.getAllSafeZones().isEmpty)
        #expect(await monitor.getRecentEvents().isEmpty)
    }

    // MARK: - Persistence Tests

    @Test("Safe zones persist across instances")
    func zonesPersist() async throws {
        let defaults = UserDefaults.ephemeral

        // Create first monitor and add zone
        let monitor1 = GeofenceMonitor(userDefaults: defaults)
        let zone = SafeZone(
            name: "Persistent",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 100
        )
        await monitor1.addSafeZone(zone)

        // Create new monitor with same defaults
        let monitor2 = GeofenceMonitor(userDefaults: defaults)
        let zones = await monitor2.getAllSafeZones()

        #expect(zones.count == 1)
        #expect(zones[0].name == "Persistent")
        #expect(zones[0].radiusMeters == 100)
    }

    // MARK: - Helper Methods

    private func createTestFix(
        latitude: Double,
        longitude: Double,
        sequence: Int = 1,
        timestamp: Date = Date()
    ) -> LocationFix {
        return LocationFix(
            timestamp: timestamp,
            source: .iOS,
            coordinate: LocationFix.Coordinate(latitude: latitude, longitude: longitude),
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 10.0,
            speedMetersPerSecond: 0.0,
            courseDegrees: 0.0,
            headingDegrees: nil,
            batteryFraction: 1.0,
            sequence: sequence,
            trackingPreset: "test"
        )
    }
}

// MARK: - Safe Zone Model Tests

@Suite("SafeZone Model Tests")
struct SafeZoneModelTests {

    @Test("SafeZone contains location correctly")
    func containsLocation() throws {
        let zone = SafeZone(
            name: "Test",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 100
        )

        // Location at center (inside)
        let centerFix = createFix(latitude: 37.7749, longitude: -122.4194)
        #expect(zone.contains(centerFix))

        // Location far away (outside)
        let farFix = createFix(latitude: 37.8000, longitude: -122.5000)
        #expect(!zone.contains(farFix))
    }

    @Test("SafeZone distance calculation accurate")
    func distanceCalculation() throws {
        let zone = SafeZone(
            name: "Test",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 100
        )

        // Location at center
        let centerFix = createFix(latitude: 37.7749, longitude: -122.4194)
        let centerDistance = zone.distanceTo(centerFix)
        #expect(centerDistance < 1.0) // Should be ~0

        // Location ~100m north (0.0009 degrees latitude ≈ 100m)
        let northFix = createFix(latitude: 37.7758, longitude: -122.4194)
        let northDistance = zone.distanceTo(northFix)
        #expect(northDistance > 90 && northDistance < 110) // Allow some margin
    }

    @Test("SafeZone clamps radius to valid range")
    func radiusClamping() throws {
        // Too small
        let tooSmall = SafeZone(
            name: "Test",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 5.0 // Below minimum
        )
        #expect(tooSmall.radiusMeters == SafeZone.minimumRadius)

        // Too large
        let tooLarge = SafeZone(
            name: "Test",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 10000.0 // Above maximum
        )
        #expect(tooLarge.radiusMeters == SafeZone.maximumRadius)

        // Just right
        let justRight = SafeZone(
            name: "Test",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 100.0
        )
        #expect(justRight.radiusMeters == 100.0)
    }

    @Test("SafeZone touch updates modified timestamp")
    func touchUpdatesTimestamp() throws {
        var zone = SafeZone(
            name: "Test",
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            radiusMeters: 100
        )

        let originalModified = zone.modifiedAt
        Thread.sleep(forTimeInterval: 0.1) // Small delay
        zone.touch()

        #expect(zone.modifiedAt > originalModified)
    }

    private func createFix(latitude: Double, longitude: Double) -> LocationFix {
        return LocationFix(
            timestamp: Date(),
            source: .iOS,
            coordinate: LocationFix.Coordinate(latitude: latitude, longitude: longitude),
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 10.0,
            speedMetersPerSecond: 0.0,
            courseDegrees: 0.0,
            headingDegrees: nil,
            batteryFraction: 1.0,
            sequence: 1,
            trackingPreset: nil
        )
    }
}

// MARK: - Test Helpers

extension UserDefaults {
    /// Create ephemeral UserDefaults for testing
    static var ephemeral: UserDefaults {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
#endif
