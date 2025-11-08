//
//  LocationFix.swift
//  pawWatch
//
//  Purpose: Core location data model for GPS fixes with comprehensive metadata.
//           Supports encoding/decoding for Watch-to-iPhone communication.
//
//  Author: Adapted from gps-relay-framework for pawWatch
//  Created: 2025-11-05
//  Swift: 6.2
//  Platform: iOS 26.1+, watchOS 26.1+
//

import Foundation

/// Represents a complete GPS location fix with metadata.
///
/// Contains:
/// - Geographic coordinates (lat/lon)
/// - Accuracy metrics (horizontal/vertical)
/// - Motion data (speed, course, heading)
/// - Device metadata (battery, source platform)
/// - Temporal data (timestamp, sequence number)
///
/// Fully Sendable and Codable for safe cross-platform transfer.
public struct LocationFix: Codable, Equatable, Sendable {
    
    // MARK: - Nested Types
    
    /// Platform source of the GPS fix.
    public enum Source: String, Codable, Sendable {
        case watchOS = "watchOS"
        case iOS = "iOS"
    }
    
    /// Geographic coordinate pair.
    public struct Coordinate: Codable, Equatable, Sendable {
        public let latitude: Double
        public let longitude: Double
        
        public init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }
    }
    
    // MARK: - Properties
    
    /// Timestamp when GPS fix was captured
    public let timestamp: Date
    
    /// Platform that captured the GPS fix (watchOS or iOS)
    public let source: Source
    
    /// Geographic coordinates (latitude, longitude)
    public let coordinate: Coordinate
    
    /// Altitude in meters above sea level (nil if unavailable)
    public let altitudeMeters: Double?
    
    /// Horizontal accuracy radius in meters (smaller = more accurate)
    public let horizontalAccuracyMeters: Double
    
    /// Vertical accuracy in meters (smaller = more accurate)
    public let verticalAccuracyMeters: Double
    
    /// Speed over ground in meters per second
    public let speedMetersPerSecond: Double
    
    /// Course over ground in degrees (0-360, 0 = true north)
    public let courseDegrees: Double
    
    /// Magnetic heading in degrees (compass direction device is pointing, nil if unavailable)
    /// Note: Apple Watch doesn't have compass hardware, so this is nil for watchOS source
    public let headingDegrees: Double?
    
    /// Battery level as fraction (0.0-1.0, where 1.0 = 100%)
    public let batteryFraction: Double
    
    /// Monotonic sequence number for ordering and deduplication
    /// Generated from milliseconds since reference date modulo Int.max
    public let sequence: Int

    /// Optional tracking preset (e.g., Aggressive/Balanced/Saver) supplied by watch.
    public let trackingPreset: String?
    
    // MARK: - Initialization
    
    public init(
        timestamp: Date,
        source: Source,
        coordinate: Coordinate,
        altitudeMeters: Double?,
        horizontalAccuracyMeters: Double,
        verticalAccuracyMeters: Double,
        speedMetersPerSecond: Double,
        courseDegrees: Double,
        headingDegrees: Double?,
        batteryFraction: Double,
        sequence: Int,
        trackingPreset: String? = nil
    ) {
        self.timestamp = timestamp
        self.source = source
        self.coordinate = coordinate
        self.altitudeMeters = altitudeMeters
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.verticalAccuracyMeters = verticalAccuracyMeters
        self.speedMetersPerSecond = speedMetersPerSecond
        self.courseDegrees = courseDegrees
        self.headingDegrees = headingDegrees
        self.batteryFraction = batteryFraction
        self.sequence = sequence
        self.trackingPreset = trackingPreset
    }
    
    // MARK: - Codable Implementation
    
    /// Coding keys for JSON serialization with compact field names.
    private enum CodingKeys: String, CodingKey {
        case timestamp = "ts_unix_ms"
        case source
        case latitude = "lat"
        case longitude = "lon"
        case altitudeMeters = "alt_m"
        case horizontalAccuracyMeters = "h_accuracy_m"
        case verticalAccuracyMeters = "v_accuracy_m"
        case speedMetersPerSecond = "speed_mps"
        case courseDegrees = "course_deg"
        case headingDegrees = "heading_deg"
        case batteryFraction = "battery_pct"
        case sequence = "seq"
        case trackingPreset = "preset"
    }
    
    /// Custom decoder to convert Unix milliseconds to Date.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Convert Unix milliseconds to Date
        let timestampMilliseconds = try container.decode(Int64.self, forKey: .timestamp)
        self.timestamp = Date(timeIntervalSince1970: Double(timestampMilliseconds) / 1_000)
        
        self.source = try container.decode(Source.self, forKey: .source)
        
        // Decode coordinate components
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.coordinate = Coordinate(latitude: latitude, longitude: longitude)
        
        self.altitudeMeters = try container.decodeIfPresent(Double.self, forKey: .altitudeMeters)
        self.horizontalAccuracyMeters = try container.decode(Double.self, forKey: .horizontalAccuracyMeters)
        self.verticalAccuracyMeters = try container.decode(Double.self, forKey: .verticalAccuracyMeters)
        self.speedMetersPerSecond = try container.decode(Double.self, forKey: .speedMetersPerSecond)
        self.courseDegrees = try container.decode(Double.self, forKey: .courseDegrees)
        self.headingDegrees = try container.decodeIfPresent(Double.self, forKey: .headingDegrees)
        self.batteryFraction = try container.decode(Double.self, forKey: .batteryFraction)
        self.sequence = try container.decode(Int.self, forKey: .sequence)
        self.trackingPreset = try container.decodeIfPresent(String.self, forKey: .trackingPreset)
    }
    
    /// Custom encoder to convert Date to Unix milliseconds.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Convert Date to Unix milliseconds
        let milliseconds = Int64(timestamp.timeIntervalSince1970 * 1_000)
        try container.encode(milliseconds, forKey: .timestamp)
        
        try container.encode(source, forKey: .source)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encodeIfPresent(altitudeMeters, forKey: .altitudeMeters)
        try container.encode(horizontalAccuracyMeters, forKey: .horizontalAccuracyMeters)
        try container.encode(verticalAccuracyMeters, forKey: .verticalAccuracyMeters)
        try container.encode(speedMetersPerSecond, forKey: .speedMetersPerSecond)
        try container.encode(courseDegrees, forKey: .courseDegrees)
        try container.encodeIfPresent(headingDegrees, forKey: .headingDegrees)
        try container.encode(batteryFraction, forKey: .batteryFraction)
        try container.encode(sequence, forKey: .sequence)
        try container.encodeIfPresent(trackingPreset, forKey: .trackingPreset)
    }
}
