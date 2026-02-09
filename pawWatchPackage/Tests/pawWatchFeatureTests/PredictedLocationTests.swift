//
//  PredictedLocationTests.swift
//  pawWatchFeatureTests
//
//  Purpose: Tests for motion prediction and dead reckoning logic.
//           Validates prediction accuracy, confidence radius growth, and edge cases.
//
//  Author: Created for pawWatch
//  Created: 2026-02-09
//  Swift: 6.2
//  Platform: iOS 26.1+, watchOS 26.1+
//

import Testing
import Foundation
@testable import pawWatchFeature

@Suite("Predicted Location Tests")
struct PredictedLocationTests {

    // MARK: - Test Data Helpers

    /// Create a sample LocationFix for testing
    private func makeLocationFix(
        timestamp: Date = Date(),
        latitude: Double = 37.7749,
        longitude: Double = -122.4194,
        speed: Double = 0.0,
        course: Double = 0.0,
        accuracy: Double = 10.0
    ) -> LocationFix {
        LocationFix(
            timestamp: timestamp,
            source: .iOS,
            coordinate: LocationFix.Coordinate(latitude: latitude, longitude: longitude),
            altitudeMeters: nil,
            horizontalAccuracyMeters: accuracy,
            verticalAccuracyMeters: 10.0,
            speedMetersPerSecond: speed,
            courseDegrees: course,
            headingDegrees: nil,
            batteryFraction: 0.8,
            sequence: 1,
            trackingPreset: nil
        )
    }

    // MARK: - Prediction Decision Tests

    @Test("No prediction for recent data (< 5 seconds)")
    func noPredictionForRecentData() throws {
        let baseFix = makeLocationFix(timestamp: Date())
        let currentTime = Date().addingTimeInterval(3) // 3 seconds later

        let prediction = PredictedLocation.predict(from: baseFix, at: currentTime)

        #expect(prediction == nil)
    }

    @Test("Last known prediction for 5-15 seconds elapsed")
    func lastKnownPrediction() throws {
        let baseFix = makeLocationFix(timestamp: Date())
        let currentTime = Date().addingTimeInterval(10) // 10 seconds later

        let prediction = PredictedLocation.predict(from: baseFix, at: currentTime)

        #expect(prediction != nil)
        #expect(prediction?.predictionMethod == .lastKnown)
        #expect(prediction?.coordinate == baseFix.coordinate)
        #expect(abs((prediction?.secondsSinceLastFix ?? 0) - 10.0) < 0.01)
    }

    @Test("Velocity extrapolation for 15-60 seconds elapsed with movement")
    func velocityExtrapolation() throws {
        let baseFix = makeLocationFix(
            timestamp: Date(),
            latitude: 37.7749,
            longitude: -122.4194,
            speed: 2.0, // 2 m/s
            course: 0.0 // North
        )
        let currentTime = Date().addingTimeInterval(30) // 30 seconds later

        let prediction = PredictedLocation.predict(from: baseFix, at: currentTime)

        #expect(prediction != nil)
        #expect(prediction?.predictionMethod == .velocityExtrapolation)
        #expect(prediction?.coordinate != baseFix.coordinate) // Should have moved
        #expect(abs((prediction?.secondsSinceLastFix ?? 0) - 30.0) < 0.01)

        // Latitude should increase (moving north)
        if let pred = prediction {
            #expect(pred.coordinate.latitude > baseFix.coordinate.latitude)
        }
    }

    @Test("Last known for stationary object even after 15 seconds")
    func stationaryObjectUsesLastKnown() throws {
        let baseFix = makeLocationFix(
            timestamp: Date(),
            speed: 0.3 // Below 0.5 m/s threshold
        )
        let currentTime = Date().addingTimeInterval(30) // 30 seconds later

        let prediction = PredictedLocation.predict(from: baseFix, at: currentTime)

        #expect(prediction != nil)
        // Should use last known method since not moving
        #expect(prediction?.predictionMethod == .lastKnown)
        #expect(prediction?.coordinate == baseFix.coordinate)
    }

    @Test("Expanding uncertainty for old data (> 60 seconds)")
    func expandingUncertainty() throws {
        let baseFix = makeLocationFix(
            timestamp: Date(),
            speed: 2.0
        )
        let currentTime = Date().addingTimeInterval(120) // 2 minutes later

        let prediction = PredictedLocation.predict(from: baseFix, at: currentTime)

        #expect(prediction != nil)
        #expect(prediction?.predictionMethod == .expandingUncertainty)
        #expect(prediction?.coordinate == baseFix.coordinate)
        #expect(abs((prediction?.secondsSinceLastFix ?? 0) - 120.0) < 0.01)

        // Confidence should be very large
        if let pred = prediction {
            #expect(pred.confidenceRadius > 300.0)
        }
    }

    // MARK: - Confidence Radius Tests

    @Test("Confidence radius grows with time for last known method")
    func confidenceGrowthLastKnown() throws {
        let baseFix = makeLocationFix(timestamp: Date(), accuracy: 10.0)

        let prediction5s = PredictedLocation.predict(from: baseFix, at: Date().addingTimeInterval(5))
        let prediction10s = PredictedLocation.predict(from: baseFix, at: Date().addingTimeInterval(10))

        #expect(prediction5s != nil)
        #expect(prediction10s != nil)

        // Confidence should grow: base + 2m per second
        // Use approximate comparison for floating point
        let expected5s = 10.0 + (5.0 * 2.0)
        let expected10s = 10.0 + (10.0 * 2.0)
        #expect(abs(prediction5s!.confidenceRadius - expected5s) < 0.01)
        #expect(abs(prediction10s!.confidenceRadius - expected10s) < 0.01)
        #expect(prediction10s!.confidenceRadius > prediction5s!.confidenceRadius)
    }

    @Test("Confidence radius grows faster for velocity extrapolation")
    func confidenceGrowthVelocityExtrapolation() throws {
        let baseFix = makeLocationFix(
            timestamp: Date(),
            speed: 2.0,
            course: 0.0,
            accuracy: 10.0
        )

        let prediction30s = PredictedLocation.predict(from: baseFix, at: Date().addingTimeInterval(30))

        #expect(prediction30s != nil)
        #expect(prediction30s?.predictionMethod == .velocityExtrapolation)

        // Should include base + time factor + distance factor
        let expectedDistance = 2.0 * 30.0 // 60 meters
        let expectedConfidence = 10.0 + (30.0 * 5.0) + (expectedDistance * 0.1)
        #expect(prediction30s!.confidenceRadius >= expectedConfidence - 1.0) // Allow small margin
        #expect(prediction30s!.confidenceRadius <= expectedConfidence + 1.0)
    }

    @Test("Confidence radius capped at 5km for very old data")
    func confidenceRadiusCapped() throws {
        let baseFix = makeLocationFix(timestamp: Date(), accuracy: 10.0)
        let currentTime = Date().addingTimeInterval(1000) // 16+ minutes

        let prediction = PredictedLocation.predict(from: baseFix, at: currentTime)

        #expect(prediction != nil)
        #expect(prediction?.predictionMethod == .expandingUncertainty)
        #expect(prediction!.confidenceRadius <= 5000.0) // Capped at 5km
    }

    // MARK: - Coordinate Extrapolation Tests

    @Test("Northward movement increases latitude")
    func northwardMovement() throws {
        let baseFix = makeLocationFix(
            timestamp: Date(),
            latitude: 37.7749,
            longitude: -122.4194,
            speed: 1.0, // 1 m/s
            course: 0.0 // North
        )
        let currentTime = Date().addingTimeInterval(30)

        let prediction = PredictedLocation.predict(from: baseFix, at: currentTime)

        #expect(prediction != nil)
        #expect(prediction!.coordinate.latitude > baseFix.coordinate.latitude)
        // Longitude should remain roughly the same
        #expect(abs(prediction!.coordinate.longitude - baseFix.coordinate.longitude) < 0.0001)
    }

    @Test("Eastward movement increases longitude")
    func eastwardMovement() throws {
        let baseFix = makeLocationFix(
            timestamp: Date(),
            latitude: 37.7749,
            longitude: -122.4194,
            speed: 1.0, // 1 m/s
            course: 90.0 // East
        )
        let currentTime = Date().addingTimeInterval(30)

        let prediction = PredictedLocation.predict(from: baseFix, at: currentTime)

        #expect(prediction != nil)
        // Moving east increases longitude (less negative)
        #expect(prediction!.coordinate.longitude > baseFix.coordinate.longitude)
        // Latitude should remain roughly the same
        #expect(abs(prediction!.coordinate.latitude - baseFix.coordinate.latitude) < 0.0001)
    }

    @Test("Southward movement decreases latitude")
    func southwardMovement() throws {
        let baseFix = makeLocationFix(
            timestamp: Date(),
            latitude: 37.7749,
            longitude: -122.4194,
            speed: 1.0,
            course: 180.0 // South
        )
        let currentTime = Date().addingTimeInterval(30)

        let prediction = PredictedLocation.predict(from: baseFix, at: currentTime)

        #expect(prediction != nil)
        #expect(prediction!.coordinate.latitude < baseFix.coordinate.latitude)
    }

    @Test("Westward movement decreases longitude")
    func westwardMovement() throws {
        let baseFix = makeLocationFix(
            timestamp: Date(),
            latitude: 37.7749,
            longitude: -122.4194,
            speed: 1.0,
            course: 270.0 // West
        )
        let currentTime = Date().addingTimeInterval(30)

        let prediction = PredictedLocation.predict(from: baseFix, at: currentTime)

        #expect(prediction != nil)
        // Moving west decreases longitude (more negative)
        #expect(prediction!.coordinate.longitude < baseFix.coordinate.longitude)
    }

    // MARK: - Display Helper Tests

    @Test("Time ago description formats correctly")
    func timeAgoDescription() throws {
        let baseFix = makeLocationFix(timestamp: Date())

        let pred10s = PredictedLocation.predict(from: baseFix, at: Date().addingTimeInterval(10))
        let pred90s = PredictedLocation.predict(from: baseFix, at: Date().addingTimeInterval(90))

        #expect(pred10s?.timeAgoDescription == "10s ago")
        #expect(pred90s?.timeAgoDescription == "1m ago")
    }

    @Test("Method description matches prediction type")
    func methodDescription() throws {
        let baseFix = makeLocationFix(timestamp: Date(), speed: 2.0)

        let lastKnown = PredictedLocation.predict(from: baseFix, at: Date().addingTimeInterval(10))
        let velocity = PredictedLocation.predict(from: baseFix, at: Date().addingTimeInterval(30))
        let uncertain = PredictedLocation.predict(from: baseFix, at: Date().addingTimeInterval(120))

        #expect(lastKnown?.methodDescription == "Last known position")
        #expect(velocity?.methodDescription == "Predicted from velocity")
        #expect(uncertain?.methodDescription == "Location uncertain")
    }

    // MARK: - Edge Cases

    @Test("Prediction at exact threshold boundaries")
    func thresholdBoundaries() throws {
        let baseFix = makeLocationFix(timestamp: Date(), speed: 2.0)

        // Exactly 5 seconds - should predict
        let at5s = PredictedLocation.predict(from: baseFix, at: Date().addingTimeInterval(5))
        #expect(at5s != nil)

        // Exactly 15 seconds - should be velocity extrapolation (boundary)
        let at15s = PredictedLocation.predict(from: baseFix, at: Date().addingTimeInterval(15))
        #expect(at15s?.predictionMethod == .velocityExtrapolation)

        // Just under 15 seconds - should be last known
        let at14s = PredictedLocation.predict(from: baseFix, at: Date().addingTimeInterval(14))
        #expect(at14s?.predictionMethod == .lastKnown)

        // Exactly 60 seconds - should be expanding uncertainty (boundary)
        let at60s = PredictedLocation.predict(from: baseFix, at: Date().addingTimeInterval(60))
        #expect(at60s?.predictionMethod == .expandingUncertainty)

        // Just over 60 seconds - should be expanding uncertainty
        let at61s = PredictedLocation.predict(from: baseFix, at: Date().addingTimeInterval(61))
        #expect(at61s?.predictionMethod == .expandingUncertainty)
    }

    @Test("High speed extrapolation")
    func highSpeedExtrapolation() throws {
        let baseFix = makeLocationFix(
            timestamp: Date(),
            latitude: 37.7749,
            longitude: -122.4194,
            speed: 10.0, // 10 m/s = 36 km/h
            course: 0.0
        )
        let currentTime = Date().addingTimeInterval(30)

        let prediction = PredictedLocation.predict(from: baseFix, at: currentTime)

        #expect(prediction != nil)
        #expect(prediction?.predictionMethod == .velocityExtrapolation)

        // Should move significant distance (300m in 30s)
        let latDiff = abs(prediction!.coordinate.latitude - baseFix.coordinate.latitude)
        #expect(latDiff > 0.001) // Should have moved noticeably

        // Confidence should account for distance
        #expect(prediction!.confidenceRadius > 100.0)
    }

    @Test("Zero speed is treated as stationary")
    func zeroSpeedStationary() throws {
        let baseFix = makeLocationFix(
            timestamp: Date(),
            speed: 0.0,
            course: 45.0 // Course is irrelevant if not moving
        )
        let currentTime = Date().addingTimeInterval(30)

        let prediction = PredictedLocation.predict(from: baseFix, at: currentTime)

        #expect(prediction != nil)
        #expect(prediction?.predictionMethod == .lastKnown)
        #expect(prediction?.coordinate == baseFix.coordinate)
    }
}
