//
//  PersistedLocationFix.swift
//  pawWatch
//
//  Purpose: SwiftData model for persisting location fixes across app restarts.
//           Stores location history and enables offline access.
//
//  Created: 2026-02-09
//  Swift: 6.2
//  Platform: iOS 26.1+
//

import Foundation
import SwiftData

/// SwiftData model representing a persisted GPS location fix.
///
/// This model stores location data in the local database for:
/// - Location history and playback
/// - Offline access to recent locations
/// - Analytics and statistics
/// - Reducing network requests by caching data
///
/// The model mirrors the structure of LocationFix but uses SwiftData persistence.
@Model
public final class PersistedLocationFix {

    // MARK: - Properties

    /// Unique identifier for the persisted fix
    @Attribute(.unique) public var id: UUID

    /// Timestamp when GPS fix was captured
    public var timestamp: Date

    /// Platform that captured the GPS fix (watchOS or iOS)
    public var source: String

    /// Latitude in degrees
    public var latitude: Double

    /// Longitude in degrees
    public var longitude: Double

    /// Altitude in meters above sea level (nil if unavailable)
    public var altitudeMeters: Double?

    /// Horizontal accuracy radius in meters
    public var horizontalAccuracyMeters: Double

    /// Vertical accuracy in meters
    public var verticalAccuracyMeters: Double

    /// Speed over ground in meters per second
    public var speedMetersPerSecond: Double

    /// Course over ground in degrees (0-360)
    public var courseDegrees: Double

    /// Magnetic heading in degrees (nil if unavailable)
    public var headingDegrees: Double?

    /// Battery level as fraction (0.0-1.0)
    public var batteryFraction: Double

    /// Monotonic sequence number for ordering
    public var sequence: Int

    /// Optional tracking preset name
    public var trackingPreset: String?

    /// Date when this fix was persisted to the database
    public var persistedAt: Date

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        source: String,
        latitude: Double,
        longitude: Double,
        altitudeMeters: Double? = nil,
        horizontalAccuracyMeters: Double,
        verticalAccuracyMeters: Double,
        speedMetersPerSecond: Double,
        courseDegrees: Double,
        headingDegrees: Double? = nil,
        batteryFraction: Double,
        sequence: Int,
        trackingPreset: String? = nil,
        persistedAt: Date = Date()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.latitude = latitude
        self.longitude = longitude
        self.altitudeMeters = altitudeMeters
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.verticalAccuracyMeters = verticalAccuracyMeters
        self.speedMetersPerSecond = speedMetersPerSecond
        self.courseDegrees = courseDegrees
        self.headingDegrees = headingDegrees
        self.batteryFraction = batteryFraction
        self.sequence = sequence
        self.trackingPreset = trackingPreset
        self.persistedAt = persistedAt
    }

    // MARK: - Conversion Methods

    /// Creates a PersistedLocationFix from a LocationFix.
    public convenience init(from locationFix: LocationFix) {
        self.init(
            timestamp: locationFix.timestamp,
            source: locationFix.source.rawValue,
            latitude: locationFix.coordinate.latitude,
            longitude: locationFix.coordinate.longitude,
            altitudeMeters: locationFix.altitudeMeters,
            horizontalAccuracyMeters: locationFix.horizontalAccuracyMeters,
            verticalAccuracyMeters: locationFix.verticalAccuracyMeters,
            speedMetersPerSecond: locationFix.speedMetersPerSecond,
            courseDegrees: locationFix.courseDegrees,
            headingDegrees: locationFix.headingDegrees,
            batteryFraction: locationFix.batteryFraction,
            sequence: locationFix.sequence,
            trackingPreset: locationFix.trackingPreset
        )
    }

    /// Converts this persisted fix back to a LocationFix.
    public func toLocationFix() -> LocationFix? {
        guard let source = LocationFix.Source(rawValue: source) else {
            return nil
        }

        return LocationFix(
            timestamp: timestamp,
            source: source,
            coordinate: LocationFix.Coordinate(
                latitude: latitude,
                longitude: longitude
            ),
            altitudeMeters: altitudeMeters,
            horizontalAccuracyMeters: horizontalAccuracyMeters,
            verticalAccuracyMeters: verticalAccuracyMeters,
            speedMetersPerSecond: speedMetersPerSecond,
            courseDegrees: courseDegrees,
            headingDegrees: headingDegrees,
            batteryFraction: batteryFraction,
            sequence: sequence,
            trackingPreset: trackingPreset
        )
    }
}
