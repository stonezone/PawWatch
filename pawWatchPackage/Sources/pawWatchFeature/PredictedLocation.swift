//
//  PredictedLocation.swift
//  pawWatch
//
//  Purpose: Model for predicted GPS locations when real GPS signal is lost.
//           Uses dead reckoning based on last known velocity and position.
//
//  Author: Created for pawWatch
//  Created: 2026-02-09
//  Swift: 6.2
//  Platform: iOS 26.1+, watchOS 26.1+
//

import Foundation

/// Represents a predicted location when GPS is unavailable.
///
/// Uses dead reckoning algorithms to estimate position based on:
/// - Last known position
/// - Last known velocity (speed and course)
/// - Time elapsed since last GPS fix
///
/// Prediction quality degrades over time, reflected in growing confidence radius.
public struct PredictedLocation: Equatable, Sendable {

    // MARK: - Nested Types

    /// Method used to derive the predicted location.
    public enum PredictionMethod: String, Sendable {
        /// Using last known position unchanged (0-15 seconds)
        case lastKnown

        /// Velocity-based extrapolation (15-60 seconds)
        case velocityExtrapolation

        /// Expanding uncertainty circle (>60 seconds)
        case expandingUncertainty
    }

    // MARK: - Properties

    /// Predicted geographic coordinate
    public let coordinate: LocationFix.Coordinate

    /// Confidence radius in meters (larger = less confident)
    /// Grows with time since last fix
    public let confidenceRadius: Double

    /// Time elapsed since last real GPS fix (in seconds)
    public let secondsSinceLastFix: TimeInterval

    /// Method used to compute this prediction
    public let predictionMethod: PredictionMethod

    /// Timestamp when this prediction was generated
    public let timestamp: Date

    /// Original fix used as basis for prediction
    public let baseFix: LocationFix

    // MARK: - Initialization

    public init(
        coordinate: LocationFix.Coordinate,
        confidenceRadius: Double,
        secondsSinceLastFix: TimeInterval,
        predictionMethod: PredictionMethod,
        timestamp: Date = Date(),
        baseFix: LocationFix
    ) {
        self.coordinate = coordinate
        self.confidenceRadius = confidenceRadius
        self.secondsSinceLastFix = secondsSinceLastFix
        self.predictionMethod = predictionMethod
        self.timestamp = timestamp
        self.baseFix = baseFix
    }

    // MARK: - Prediction Logic

    /// Generate a predicted location based on a GPS fix and time elapsed.
    ///
    /// Prediction strategy:
    /// - 0-15s: Use last known position with small confidence radius
    /// - 15-60s: Extrapolate based on velocity (speed + course)
    /// - >60s: Expand uncertainty circle, velocity becomes unreliable
    ///
    /// - Parameters:
    ///   - baseFix: Last known GPS fix
    ///   - currentTime: Current timestamp (defaults to now)
    /// - Returns: Predicted location, or nil if prediction not possible
    public static func predict(
        from baseFix: LocationFix,
        at currentTime: Date = Date()
    ) -> PredictedLocation? {
        let elapsed = currentTime.timeIntervalSince(baseFix.timestamp)

        // Don't predict if we have recent data (within 5 seconds)
        guard elapsed >= 5 else {
            return nil
        }

        // Choose prediction method based on elapsed time
        if elapsed < 15 {
            // Last known position - minimal drift
            return predictLastKnown(baseFix: baseFix, elapsed: elapsed, currentTime: currentTime)
        } else if elapsed < 60 {
            // Velocity extrapolation - linear prediction
            return predictVelocityExtrapolation(baseFix: baseFix, elapsed: elapsed, currentTime: currentTime)
        } else {
            // Expanding uncertainty - too old for reliable prediction
            return predictExpandingUncertainty(baseFix: baseFix, elapsed: elapsed, currentTime: currentTime)
        }
    }

    // MARK: - Private Prediction Methods

    /// Use last known position with minimal uncertainty growth.
    private static func predictLastKnown(
        baseFix: LocationFix,
        elapsed: TimeInterval,
        currentTime: Date
    ) -> PredictedLocation {
        // Confidence grows slowly: base accuracy + 2m per second
        let confidenceRadius = baseFix.horizontalAccuracyMeters + (elapsed * 2.0)

        return PredictedLocation(
            coordinate: baseFix.coordinate,
            confidenceRadius: confidenceRadius,
            secondsSinceLastFix: elapsed,
            predictionMethod: .lastKnown,
            timestamp: currentTime,
            baseFix: baseFix
        )
    }

    /// Extrapolate position based on last known velocity.
    private static func predictVelocityExtrapolation(
        baseFix: LocationFix,
        elapsed: TimeInterval,
        currentTime: Date
    ) -> PredictedLocation {
        // Only extrapolate if moving (speed > 0.5 m/s = 1.8 km/h)
        guard baseFix.speedMetersPerSecond > 0.5 else {
            // Not moving - use last known position
            return predictLastKnown(baseFix: baseFix, elapsed: elapsed, currentTime: currentTime)
        }

        // Calculate distance traveled at last known speed
        let distanceMeters = baseFix.speedMetersPerSecond * elapsed

        // Calculate new position using spherical geometry
        let newCoordinate = extrapolateCoordinate(
            from: baseFix.coordinate,
            bearing: baseFix.courseDegrees,
            distanceMeters: distanceMeters
        )

        // Confidence grows faster: base accuracy + 5m per second + 10% of distance
        let confidenceRadius = baseFix.horizontalAccuracyMeters
            + (elapsed * 5.0)
            + (distanceMeters * 0.1)

        return PredictedLocation(
            coordinate: newCoordinate,
            confidenceRadius: confidenceRadius,
            secondsSinceLastFix: elapsed,
            predictionMethod: .velocityExtrapolation,
            timestamp: currentTime,
            baseFix: baseFix
        )
    }

    /// Expanding uncertainty circle when data is too old for reliable prediction.
    private static func predictExpandingUncertainty(
        baseFix: LocationFix,
        elapsed: TimeInterval,
        currentTime: Date
    ) -> PredictedLocation {
        // Use last known position but with rapidly growing uncertainty
        // Confidence grows exponentially: base + 10m per second after 60s
        let confidenceRadius = baseFix.horizontalAccuracyMeters + ((elapsed - 60) * 10.0) + 300.0

        return PredictedLocation(
            coordinate: baseFix.coordinate,
            confidenceRadius: min(confidenceRadius, 5000.0), // Cap at 5km
            secondsSinceLastFix: elapsed,
            predictionMethod: .expandingUncertainty,
            timestamp: currentTime,
            baseFix: baseFix
        )
    }

    /// Extrapolate a coordinate along a bearing for a given distance.
    ///
    /// Uses Haversine formula for spherical geometry.
    ///
    /// - Parameters:
    ///   - coordinate: Starting coordinate
    ///   - bearing: Direction in degrees (0 = north, clockwise)
    ///   - distanceMeters: Distance to travel in meters
    /// - Returns: New coordinate after traveling distance along bearing
    private static func extrapolateCoordinate(
        from coordinate: LocationFix.Coordinate,
        bearing bearingDegrees: Double,
        distanceMeters: Double
    ) -> LocationFix.Coordinate {
        let earthRadiusMeters = 6_371_000.0
        let lat1 = coordinate.latitude * .pi / 180.0
        let lon1 = coordinate.longitude * .pi / 180.0
        let bearing = bearingDegrees * .pi / 180.0
        let angularDistance = distanceMeters / earthRadiusMeters

        // Calculate new latitude
        let lat2 = asin(
            sin(lat1) * cos(angularDistance) +
            cos(lat1) * sin(angularDistance) * cos(bearing)
        )

        // Calculate new longitude
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )

        return LocationFix.Coordinate(
            latitude: lat2 * 180.0 / .pi,
            longitude: lon2 * 180.0 / .pi
        )
    }
}

// MARK: - Display Helpers

extension PredictedLocation {
    /// Human-readable description of time since last fix.
    public var timeAgoDescription: String {
        let seconds = Int(secondsSinceLastFix)
        if seconds < 60 {
            return "\(seconds)s ago"
        } else {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        }
    }

    /// User-facing label for prediction method.
    public var methodDescription: String {
        switch predictionMethod {
        case .lastKnown:
            return "Last known position"
        case .velocityExtrapolation:
            return "Predicted from velocity"
        case .expandingUncertainty:
            return "Location uncertain"
        }
    }
}
