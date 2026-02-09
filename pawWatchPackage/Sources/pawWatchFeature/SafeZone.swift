//
//  SafeZone.swift
//  pawWatch
//
//  Purpose: Model representing a geographic safe zone with geofence boundary detection.
//           Used for alerting when pet exits designated safe areas.
//
//  Created: 2025-02-09
//  Swift: 6.2
//  Platform: iOS 26.1+
//

import Foundation
import CoreLocation

/// Represents a geographic safe zone for pet monitoring.
///
/// A safe zone defines a circular region where the pet is expected to stay.
/// When the pet's location exits this zone, alerts can be triggered.
public struct SafeZone: Codable, Identifiable, Equatable, Sendable {

    // MARK: - Properties

    /// Unique identifier for the safe zone
    public let id: UUID

    /// User-defined name for the zone (e.g., "Home", "Dog Park")
    public var name: String

    /// Center coordinate of the safe zone
    public var coordinate: LocationFix.Coordinate

    /// Radius of the safe zone in meters
    public var radiusMeters: Double

    /// Whether this safe zone is currently active for monitoring
    public var isEnabled: Bool

    /// When this safe zone was created
    public let createdAt: Date

    /// When this safe zone was last modified
    public var modifiedAt: Date

    // MARK: - Computed Properties

    /// CoreLocation region for this safe zone
    public var clRegion: CLCircularRegion {
        let center = CLLocationCoordinate2D(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        let region = CLCircularRegion(
            center: center,
            radius: radiusMeters,
            identifier: id.uuidString
        )
        region.notifyOnEntry = false
        region.notifyOnExit = true
        return region
    }

    // MARK: - Constants

    /// Minimum radius for a safe zone (10 meters)
    public static let minimumRadius: Double = 10.0

    /// Maximum radius for a safe zone (5 kilometers)
    public static let maximumRadius: Double = 5000.0

    /// Default radius for new safe zones (100 meters)
    public static let defaultRadius: Double = 100.0

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        name: String,
        coordinate: LocationFix.Coordinate,
        radiusMeters: Double = SafeZone.defaultRadius,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.radiusMeters = min(max(radiusMeters, SafeZone.minimumRadius), SafeZone.maximumRadius)
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    // MARK: - Methods

    /// Check if a given location is inside this safe zone
    public func contains(_ location: LocationFix) -> Bool {
        let distance = distanceTo(location)
        return distance <= radiusMeters
    }

    /// Calculate distance from zone center to a location in meters
    public func distanceTo(_ location: LocationFix) -> Double {
        let zoneLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        let targetLocation = CLLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        return zoneLocation.distance(from: targetLocation)
    }

    /// Update the zone's modified timestamp
    public mutating func touch() {
        modifiedAt = Date()
    }
}

// MARK: - Safe Zone Event

/// Represents a geofence crossing event
public struct SafeZoneEvent: Codable, Identifiable, Sendable {

    public enum EventType: String, Codable, Sendable {
        case entered
        case exited
    }

    /// Unique identifier for the event
    public let id: UUID

    /// Which safe zone triggered this event
    public let zoneId: UUID

    /// Type of event (entered or exited)
    public let type: EventType

    /// Location fix that triggered the event
    public let location: LocationFix

    /// When the event occurred
    public let timestamp: Date

    /// Whether a notification was sent for this event
    public var notificationSent: Bool

    public init(
        id: UUID = UUID(),
        zoneId: UUID,
        type: EventType,
        location: LocationFix,
        timestamp: Date = Date(),
        notificationSent: Bool = false
    ) {
        self.id = id
        self.zoneId = zoneId
        self.type = type
        self.location = location
        self.timestamp = timestamp
        self.notificationSent = notificationSent
    }
}
