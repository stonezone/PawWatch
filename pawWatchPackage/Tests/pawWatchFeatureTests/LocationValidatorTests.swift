//
//  LocationValidatorTests.swift
//  pawWatchFeatureTests
//
//  Purpose: Tests for LocationValidator to ensure proper validation of location data.
//
//  Created: 2026-02-09
//  Swift: 6.2
//  Platform: iOS 26.1+
//

import Testing
import Foundation
@testable import pawWatchFeature

@Suite("LocationValidator Tests")
struct LocationValidatorTests {

    // MARK: - Test Helpers

    func makeValidFix() -> LocationFix {
        LocationFix(
            timestamp: Date(),
            source: .watchOS,
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            altitudeMeters: 50.0,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 15.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: 180.0,
            batteryFraction: 0.75,
            sequence: 12345
        )
    }

    // MARK: - Valid Location Tests

    @Test("Valid location passes validation")
    func testValidLocation() async {
        let validator = LocationValidator()
        let fix = makeValidFix()

        let result = await validator.validate(fix)

        if case .invalid(let reason) = result {
            Issue.record("Expected valid but got invalid: \(reason)")
        }
    }

    // MARK: - Coordinate Validation Tests

    @Test("Invalid latitude is rejected")
    func testInvalidLatitude() async {
        let validator = LocationValidator()
        let fix = LocationFix(
            timestamp: Date(),
            source: .watchOS,
            coordinate: LocationFix.Coordinate(latitude: 95.0, longitude: -122.4194),
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 15.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: nil,
            batteryFraction: 0.75,
            sequence: 1
        )

        let result = await validator.validate(fix)

        guard case .invalid(let reason) = result else {
            Issue.record("Expected invalid result")
            return
        }

        #expect(reason.contains("latitude"))
    }

    @Test("Invalid longitude is rejected")
    func testInvalidLongitude() async {
        let validator = LocationValidator()
        let fix = LocationFix(
            timestamp: Date(),
            source: .watchOS,
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -185.0),
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 15.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: nil,
            batteryFraction: 0.75,
            sequence: 1
        )

        let result = await validator.validate(fix)

        guard case .invalid(let reason) = result else {
            Issue.record("Expected invalid result")
            return
        }

        #expect(reason.contains("longitude"))
    }

    @Test("Zero coordinates are rejected as suspicious")
    func testZeroCoordinates() async {
        let validator = LocationValidator()
        let fix = LocationFix(
            timestamp: Date(),
            source: .watchOS,
            coordinate: LocationFix.Coordinate(latitude: 0.0, longitude: 0.0),
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 15.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: nil,
            batteryFraction: 0.75,
            sequence: 1
        )

        let result = await validator.validate(fix)

        guard case .invalid(let reason) = result else {
            Issue.record("Expected invalid result")
            return
        }

        #expect(reason.contains("0,0"))
    }

    // MARK: - Timestamp Validation Tests

    @Test("Future timestamp is rejected")
    func testFutureTimestamp() async {
        let validator = LocationValidator()
        let futureDate = Date().addingTimeInterval(3600) // 1 hour in future

        let fix = LocationFix(
            timestamp: futureDate,
            source: .watchOS,
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 15.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: nil,
            batteryFraction: 0.75,
            sequence: 1
        )

        let result = await validator.validate(fix)

        guard case .invalid(let reason) = result else {
            Issue.record("Expected invalid result")
            return
        }

        #expect(reason.contains("future"))
    }

    @Test("Old timestamp is rejected")
    func testOldTimestamp() async {
        let validator = LocationValidator()
        let oldDate = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago

        let fix = LocationFix(
            timestamp: oldDate,
            source: .watchOS,
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 15.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: nil,
            batteryFraction: 0.75,
            sequence: 1
        )

        let result = await validator.validate(fix)

        guard case .invalid(let reason) = result else {
            Issue.record("Expected invalid result")
            return
        }

        #expect(reason.contains("old"))
    }

    // MARK: - Speed Validation Tests

    @Test("Excessive speed is rejected")
    func testExcessiveSpeed() async {
        let validator = LocationValidator()
        let fix = LocationFix(
            timestamp: Date(),
            source: .watchOS,
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 15.0,
            speedMetersPerSecond: 60.0, // 216 km/h - too fast!
            courseDegrees: 180.0,
            headingDegrees: nil,
            batteryFraction: 0.75,
            sequence: 1
        )

        let result = await validator.validate(fix)

        guard case .invalid(let reason) = result else {
            Issue.record("Expected invalid result")
            return
        }

        #expect(reason.contains("Speed exceeds"))
    }

    @Test("Negative speed is rejected")
    func testNegativeSpeed() async {
        let validator = LocationValidator()
        let fix = LocationFix(
            timestamp: Date(),
            source: .watchOS,
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 15.0,
            speedMetersPerSecond: -5.0,
            courseDegrees: 180.0,
            headingDegrees: nil,
            batteryFraction: 0.75,
            sequence: 1
        )

        let result = await validator.validate(fix)

        guard case .invalid(let reason) = result else {
            Issue.record("Expected invalid result")
            return
        }

        #expect(reason.contains("negative"))
    }

    // MARK: - Accuracy Validation Tests

    @Test("Negative horizontal accuracy is rejected")
    func testNegativeHorizontalAccuracy() async {
        let validator = LocationValidator()
        let fix = LocationFix(
            timestamp: Date(),
            source: .watchOS,
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            altitudeMeters: nil,
            horizontalAccuracyMeters: -10.0,
            verticalAccuracyMeters: 15.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: nil,
            batteryFraction: 0.75,
            sequence: 1
        )

        let result = await validator.validate(fix)

        guard case .invalid(let reason) = result else {
            Issue.record("Expected invalid result")
            return
        }

        #expect(reason.contains("Horizontal accuracy"))
    }

    @Test("Excessive horizontal accuracy is rejected")
    func testExcessiveHorizontalAccuracy() async {
        let validator = LocationValidator()
        let fix = LocationFix(
            timestamp: Date(),
            source: .watchOS,
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            altitudeMeters: nil,
            horizontalAccuracyMeters: 1500.0, // > 1km
            verticalAccuracyMeters: 15.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: nil,
            batteryFraction: 0.75,
            sequence: 1
        )

        let result = await validator.validate(fix)

        guard case .invalid(let reason) = result else {
            Issue.record("Expected invalid result")
            return
        }

        #expect(reason.contains("too poor"))
    }

    // MARK: - Course and Heading Tests

    @Test("Invalid course is rejected")
    func testInvalidCourse() async {
        let validator = LocationValidator()
        let fix = LocationFix(
            timestamp: Date(),
            source: .watchOS,
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 15.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 400.0, // > 360
            headingDegrees: nil,
            batteryFraction: 0.75,
            sequence: 1
        )

        let result = await validator.validate(fix)

        guard case .invalid(let reason) = result else {
            Issue.record("Expected invalid result")
            return
        }

        #expect(reason.contains("Course"))
    }

    @Test("Invalid heading is rejected")
    func testInvalidHeading() async {
        let validator = LocationValidator()
        let fix = LocationFix(
            timestamp: Date(),
            source: .watchOS,
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 15.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: -45.0, // Negative
            batteryFraction: 0.75,
            sequence: 1
        )

        let result = await validator.validate(fix)

        guard case .invalid(let reason) = result else {
            Issue.record("Expected invalid result")
            return
        }

        #expect(reason.contains("Heading"))
    }

    // MARK: - Battery Validation Tests

    @Test("Invalid battery level is rejected")
    func testInvalidBattery() async {
        let validator = LocationValidator()
        let fix = LocationFix(
            timestamp: Date(),
            source: .watchOS,
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 15.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: nil,
            batteryFraction: 1.5, // > 1.0
            sequence: 1
        )

        let result = await validator.validate(fix)

        guard case .invalid(let reason) = result else {
            Issue.record("Expected invalid result")
            return
        }

        #expect(reason.contains("Battery"))
    }

    // MARK: - Statistics Tests

    @Test("Statistics track validation results")
    func testStatistics() async {
        let validator = LocationValidator()

        // Validate some good fixes
        let validFix = makeValidFix()
        _ = await validator.validate(validFix)
        _ = await validator.validate(validFix)

        // Validate a bad fix
        let invalidFix = LocationFix(
            timestamp: Date(),
            source: .watchOS,
            coordinate: LocationFix.Coordinate(latitude: 95.0, longitude: -122.4194),
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 15.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: nil,
            batteryFraction: 0.75,
            sequence: 1
        )
        _ = await validator.validate(invalidFix)

        let stats = await validator.getStatistics()

        #expect(stats.totalValidated == 3)
        #expect(stats.totalValid == 2)
        #expect(stats.totalInvalid == 1)
        #expect(stats.validationRate == 2.0 / 3.0)
    }
}
