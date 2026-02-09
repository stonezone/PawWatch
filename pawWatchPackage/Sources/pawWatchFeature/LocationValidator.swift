//
//  LocationValidator.swift
//  pawWatch
//
//  Purpose: Validates location data to prevent corrupt data from crashing the app.
//           Checks coordinates, speed, timestamps, and accuracy metrics.
//
//  Created: 2026-02-09
//  Swift: 6.2
//  Platform: iOS 26.1+
//

import Foundation

/// Validation result for a location fix.
public enum LocationValidationResult: Sendable {
    case valid
    case invalid(reason: String)
}

/// Actor responsible for validating location data to prevent corrupt data from causing crashes.
///
/// Validates:
/// - Geographic coordinates (latitude/longitude bounds)
/// - Speed limits (< 180 km/h for pet tracking)
/// - Timestamp validity (not in future, not too old)
/// - Accuracy metrics (positive values, reasonable bounds)
/// - Battery level (0.0-1.0 range)
public actor LocationValidator {

    // MARK: - Constants

    /// Maximum realistic speed for a pet in meters per second (180 km/h = 50 m/s)
    /// This accounts for very fast running dogs or pets in vehicles
    private static let maxSpeedMetersPerSecond: Double = 50.0

    /// Maximum acceptable horizontal accuracy in meters (1000m = 1km)
    /// Fixes with worse accuracy are considered unreliable
    private static let maxHorizontalAccuracyMeters: Double = 1000.0

    /// Maximum acceptable vertical accuracy in meters
    private static let maxVerticalAccuracyMeters: Double = 1000.0

    /// Maximum age of a location fix in seconds (24 hours)
    /// Older fixes are rejected as stale
    private static let maxLocationAgeSeconds: TimeInterval = 24 * 60 * 60

    /// Future timestamp tolerance in seconds (allow 60 seconds for clock skew)
    private static let futureToleranceSeconds: TimeInterval = 60

    // MARK: - Validation Statistics

    private var totalValidated: Int = 0
    private var totalValid: Int = 0
    private var totalInvalid: Int = 0
    private var invalidReasons: [String: Int] = [:]

    // MARK: - Initialization

    public init() {}

    // MARK: - Validation Methods

    /// Validates a location fix and returns the validation result.
    ///
    /// - Parameter fix: The location fix to validate
    /// - Returns: ValidationResult indicating if the fix is valid or why it's invalid
    public func validate(_ fix: LocationFix) -> LocationValidationResult {
        totalValidated += 1

        // Validate coordinates
        if let coordinateError = validateCoordinates(fix.coordinate) {
            recordInvalid(reason: coordinateError)
            return .invalid(reason: coordinateError)
        }

        // Validate timestamp
        if let timestampError = validateTimestamp(fix.timestamp) {
            recordInvalid(reason: timestampError)
            return .invalid(reason: timestampError)
        }

        // Validate speed
        if let speedError = validateSpeed(fix.speedMetersPerSecond) {
            recordInvalid(reason: speedError)
            return .invalid(reason: speedError)
        }

        // Validate accuracy
        if let accuracyError = validateAccuracy(
            horizontal: fix.horizontalAccuracyMeters,
            vertical: fix.verticalAccuracyMeters
        ) {
            recordInvalid(reason: accuracyError)
            return .invalid(reason: accuracyError)
        }

        // Validate course
        if let courseError = validateCourse(fix.courseDegrees) {
            recordInvalid(reason: courseError)
            return .invalid(reason: courseError)
        }

        // Validate heading (if present)
        if let heading = fix.headingDegrees {
            if let headingError = validateHeading(heading) {
                recordInvalid(reason: headingError)
                return .invalid(reason: headingError)
            }
        }

        // Validate battery
        if let batteryError = validateBattery(fix.batteryFraction) {
            recordInvalid(reason: batteryError)
            return .invalid(reason: batteryError)
        }

        // Validate altitude (if present)
        if let altitude = fix.altitudeMeters {
            if let altitudeError = validateAltitude(altitude) {
                recordInvalid(reason: altitudeError)
                return .invalid(reason: altitudeError)
            }
        }

        totalValid += 1
        return .valid
    }

    // MARK: - Individual Validation Functions

    private func validateCoordinates(_ coordinate: LocationFix.Coordinate) -> String? {
        // Latitude must be between -90 and 90
        guard coordinate.latitude >= -90.0 && coordinate.latitude <= 90.0 else {
            return "Invalid latitude: \(coordinate.latitude) (must be -90 to 90)"
        }

        // Longitude must be between -180 and 180
        guard coordinate.longitude >= -180.0 && coordinate.longitude <= 180.0 else {
            return "Invalid longitude: \(coordinate.longitude) (must be -180 to 180)"
        }

        // Check for exactly 0,0 which is often a sign of corrupt data
        if coordinate.latitude == 0.0 && coordinate.longitude == 0.0 {
            return "Suspicious coordinates: 0,0 (likely corrupt data)"
        }

        return nil
    }

    private func validateTimestamp(_ timestamp: Date) -> String? {
        let now = Date()

        // Check if timestamp is too far in the future (allowing for clock skew)
        let futureLimit = now.addingTimeInterval(Self.futureToleranceSeconds)
        guard timestamp <= futureLimit else {
            return "Timestamp is in the future: \(timestamp)"
        }

        // Check if timestamp is too old
        let oldestAllowed = now.addingTimeInterval(-Self.maxLocationAgeSeconds)
        guard timestamp >= oldestAllowed else {
            return "Timestamp is too old: \(timestamp)"
        }

        return nil
    }

    private func validateSpeed(_ speed: Double) -> String? {
        // Speed must be non-negative
        guard speed >= 0.0 else {
            return "Speed cannot be negative: \(speed)"
        }

        // Speed must not exceed maximum realistic speed
        guard speed <= Self.maxSpeedMetersPerSecond else {
            let speedKmh = speed * 3.6
            return "Speed exceeds maximum: \(speedKmh) km/h (max: 180 km/h)"
        }

        return nil
    }

    private func validateAccuracy(horizontal: Double, vertical: Double) -> String? {
        // Horizontal accuracy must be positive
        guard horizontal > 0.0 else {
            return "Horizontal accuracy must be positive: \(horizontal)"
        }

        // Vertical accuracy must be positive
        guard vertical > 0.0 else {
            return "Vertical accuracy must be positive: \(vertical)"
        }

        // Horizontal accuracy must not exceed maximum
        guard horizontal <= Self.maxHorizontalAccuracyMeters else {
            return "Horizontal accuracy too poor: \(horizontal)m (max: 1000m)"
        }

        // Vertical accuracy must not exceed maximum
        guard vertical <= Self.maxVerticalAccuracyMeters else {
            return "Vertical accuracy too poor: \(vertical)m (max: 1000m)"
        }

        return nil
    }

    private func validateCourse(_ course: Double) -> String? {
        // Course must be between 0 and 360 degrees
        guard course >= 0.0 && course <= 360.0 else {
            return "Course out of range: \(course) (must be 0-360)"
        }

        return nil
    }

    private func validateHeading(_ heading: Double) -> String? {
        // Heading must be between 0 and 360 degrees
        guard heading >= 0.0 && heading <= 360.0 else {
            return "Heading out of range: \(heading) (must be 0-360)"
        }

        return nil
    }

    private func validateBattery(_ battery: Double) -> String? {
        // Battery must be between 0.0 and 1.0
        guard battery >= 0.0 && battery <= 1.0 else {
            return "Battery out of range: \(battery) (must be 0.0-1.0)"
        }

        return nil
    }

    private func validateAltitude(_ altitude: Double) -> String? {
        // Altitude must be reasonable (Dead Sea to Everest + margin)
        // -500m to 9000m covers all realistic scenarios
        guard altitude >= -500.0 && altitude <= 9000.0 else {
            return "Altitude out of range: \(altitude)m (must be -500 to 9000)"
        }

        return nil
    }

    // MARK: - Statistics

    private func recordInvalid(reason: String) {
        totalInvalid += 1
        invalidReasons[reason, default: 0] += 1
    }

    /// Returns validation statistics.
    public func getStatistics() -> ValidationStatistics {
        ValidationStatistics(
            totalValidated: totalValidated,
            totalValid: totalValid,
            totalInvalid: totalInvalid,
            invalidReasons: invalidReasons
        )
    }

    /// Resets validation statistics.
    public func resetStatistics() {
        totalValidated = 0
        totalValid = 0
        totalInvalid = 0
        invalidReasons = [:]
    }
}

// MARK: - Supporting Types

/// Statistics about validation operations.
public struct ValidationStatistics: Sendable {
    public let totalValidated: Int
    public let totalValid: Int
    public let totalInvalid: Int
    public let invalidReasons: [String: Int]

    public var validationRate: Double {
        guard totalValidated > 0 else { return 0.0 }
        return Double(totalValid) / Double(totalValidated)
    }
}
