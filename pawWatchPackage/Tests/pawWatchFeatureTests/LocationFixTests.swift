import Foundation
import Testing
@testable import pawWatchFeature

/// Tests for LocationFix encoding, decoding, and edge cases.
@Suite("LocationFix Codable Tests")
struct LocationFixTests {

    // MARK: - Round-Trip Encoding/Decoding

    @Test("LocationFix round-trip encode/decode preserves all fields")
    func roundTripEncodeDecode() throws {
        // Arrange
        let timestamp = Date(timeIntervalSince1970: 1700000000)
        let coordinate = LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194)
        let fix = LocationFix(
            timestamp: timestamp,
            source: .watchOS,
            coordinate: coordinate,
            altitudeMeters: 15.5,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 5.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: 175.0,
            batteryFraction: 0.85,
            sequence: 12345,
            trackingPreset: "balanced"
        )

        // Act
        let encoded = try JSONEncoder().encode(fix)
        let decoded = try JSONDecoder().decode(LocationFix.self, from: encoded)

        // Assert
        #expect(decoded.timestamp.timeIntervalSince1970 == fix.timestamp.timeIntervalSince1970)
        #expect(decoded.source == fix.source)
        #expect(decoded.coordinate.latitude == fix.coordinate.latitude)
        #expect(decoded.coordinate.longitude == fix.coordinate.longitude)
        #expect(decoded.altitudeMeters == fix.altitudeMeters)
        #expect(decoded.horizontalAccuracyMeters == fix.horizontalAccuracyMeters)
        #expect(decoded.verticalAccuracyMeters == fix.verticalAccuracyMeters)
        #expect(decoded.speedMetersPerSecond == fix.speedMetersPerSecond)
        #expect(decoded.courseDegrees == fix.courseDegrees)
        #expect(decoded.headingDegrees == fix.headingDegrees)
        #expect(decoded.batteryFraction == fix.batteryFraction)
        #expect(decoded.sequence == fix.sequence)
        #expect(decoded.trackingPreset == fix.trackingPreset)
    }

    @Test("LocationFix round-trip with nil optional fields")
    func roundTripWithNilOptionals() throws {
        // Arrange
        let timestamp = Date(timeIntervalSince1970: 1700000000)
        let coordinate = LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194)
        let fix = LocationFix(
            timestamp: timestamp,
            source: .iOS,
            coordinate: coordinate,
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 5.0,
            speedMetersPerSecond: 0.0,
            courseDegrees: 0.0,
            headingDegrees: nil,
            batteryFraction: 1.0,
            sequence: 99999,
            trackingPreset: nil
        )

        // Act
        let encoded = try JSONEncoder().encode(fix)
        let decoded = try JSONDecoder().decode(LocationFix.self, from: encoded)

        // Assert
        #expect(decoded.altitudeMeters == nil)
        #expect(decoded.headingDegrees == nil)
        #expect(decoded.trackingPreset == nil)
        #expect(decoded.source == .iOS)
    }

    // MARK: - Edge Case Values

    @Test("LocationFix handles zero coordinates")
    func zeroCoordinates() throws {
        // Arrange
        let coordinate = LocationFix.Coordinate(latitude: 0.0, longitude: 0.0)
        let fix = LocationFix(
            timestamp: Date(),
            source: .watchOS,
            coordinate: coordinate,
            altitudeMeters: 0.0,
            horizontalAccuracyMeters: 1.0,
            verticalAccuracyMeters: 1.0,
            speedMetersPerSecond: 0.0,
            courseDegrees: 0.0,
            headingDegrees: 0.0,
            batteryFraction: 0.5,
            sequence: 1
        )

        // Act
        let encoded = try JSONEncoder().encode(fix)
        let decoded = try JSONDecoder().decode(LocationFix.self, from: encoded)

        // Assert
        #expect(decoded.coordinate.latitude == 0.0)
        #expect(decoded.coordinate.longitude == 0.0)
        #expect(decoded.altitudeMeters == 0.0)
    }

    @Test("LocationFix handles maximum accuracy values")
    func maximumAccuracyValues() throws {
        // Arrange
        let coordinate = LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194)
        let fix = LocationFix(
            timestamp: Date(),
            source: .watchOS,
            coordinate: coordinate,
            altitudeMeters: nil,
            horizontalAccuracyMeters: 999.99,
            verticalAccuracyMeters: 999.99,
            speedMetersPerSecond: 50.0,
            courseDegrees: 359.99,
            headingDegrees: nil,
            batteryFraction: 1.0,
            sequence: Int.max
        )

        // Act
        let encoded = try JSONEncoder().encode(fix)
        let decoded = try JSONDecoder().decode(LocationFix.self, from: encoded)

        // Assert
        #expect(decoded.horizontalAccuracyMeters == 999.99)
        #expect(decoded.verticalAccuracyMeters == 999.99)
        #expect(decoded.sequence == Int.max)
    }

    @Test("LocationFix handles boundary battery fractions")
    func boundaryBatteryFractions() throws {
        // Test 0.0 battery
        let coordinate = LocationFix.Coordinate(latitude: 37.0, longitude: -122.0)
        let fixEmpty = LocationFix(
            timestamp: Date(),
            source: .watchOS,
            coordinate: coordinate,
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 10.0,
            speedMetersPerSecond: 0.0,
            courseDegrees: 0.0,
            headingDegrees: nil,
            batteryFraction: 0.0,
            sequence: 1
        )

        let encodedEmpty = try JSONEncoder().encode(fixEmpty)
        let decodedEmpty = try JSONDecoder().decode(LocationFix.self, from: encodedEmpty)
        #expect(decodedEmpty.batteryFraction == 0.0)

        // Test 1.0 battery
        let fixFull = LocationFix(
            timestamp: Date(),
            source: .watchOS,
            coordinate: coordinate,
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 10.0,
            speedMetersPerSecond: 0.0,
            courseDegrees: 0.0,
            headingDegrees: nil,
            batteryFraction: 1.0,
            sequence: 2
        )

        let encodedFull = try JSONEncoder().encode(fixFull)
        let decodedFull = try JSONDecoder().decode(LocationFix.self, from: encodedFull)
        #expect(decodedFull.batteryFraction == 1.0)
    }

    // MARK: - Known JSON Format (Regression Test)

    @Test("LocationFix decodes from known JSON string")
    func decodeFromKnownJSON() throws {
        // Arrange - JSON matching the compact field names defined in CodingKeys
        let json = """
        {
            "ts_unix_ms": 1700000000000,
            "source": "watchOS",
            "lat": 37.7749,
            "lon": -122.4194,
            "alt_m": 15.5,
            "h_accuracy_m": 10.0,
            "v_accuracy_m": 5.0,
            "speed_mps": 2.5,
            "course_deg": 180.0,
            "heading_deg": 175.0,
            "battery_pct": 0.85,
            "seq": 12345,
            "preset": "balanced"
        }
        """

        let data = json.data(using: .utf8)!

        // Act
        let decoded = try JSONDecoder().decode(LocationFix.self, from: data)

        // Assert
        #expect(decoded.timestamp.timeIntervalSince1970 == 1700000000.0)
        #expect(decoded.source == .watchOS)
        #expect(decoded.coordinate.latitude == 37.7749)
        #expect(decoded.coordinate.longitude == -122.4194)
        #expect(decoded.altitudeMeters == 15.5)
        #expect(decoded.horizontalAccuracyMeters == 10.0)
        #expect(decoded.verticalAccuracyMeters == 5.0)
        #expect(decoded.speedMetersPerSecond == 2.5)
        #expect(decoded.courseDegrees == 180.0)
        #expect(decoded.headingDegrees == 175.0)
        #expect(decoded.batteryFraction == 0.85)
        #expect(decoded.sequence == 12345)
        #expect(decoded.trackingPreset == "balanced")
    }

    @Test("LocationFix decodes from JSON with missing optional fields")
    func decodeFromJSONWithMissingOptionals() throws {
        // Arrange
        let json = """
        {
            "ts_unix_ms": 1700000000000,
            "source": "iOS",
            "lat": 37.7749,
            "lon": -122.4194,
            "h_accuracy_m": 10.0,
            "v_accuracy_m": 5.0,
            "speed_mps": 0.0,
            "course_deg": 0.0,
            "battery_pct": 1.0,
            "seq": 99999
        }
        """

        let data = json.data(using: .utf8)!

        // Act
        let decoded = try JSONDecoder().decode(LocationFix.self, from: data)

        // Assert
        #expect(decoded.altitudeMeters == nil)
        #expect(decoded.headingDegrees == nil)
        #expect(decoded.trackingPreset == nil)
        #expect(decoded.source == .iOS)
        #expect(decoded.sequence == 99999)
    }

    @Test("LocationFix timestamp conversion accuracy")
    func timestampConversionAccuracy() throws {
        // Arrange - Test that millisecond precision is preserved
        let expectedTimestamp = Date(timeIntervalSince1970: 1700000000.123)
        let milliseconds = Int64(expectedTimestamp.timeIntervalSince1970 * 1_000)

        let json = """
        {
            "ts_unix_ms": \(milliseconds),
            "source": "watchOS",
            "lat": 37.0,
            "lon": -122.0,
            "h_accuracy_m": 10.0,
            "v_accuracy_m": 10.0,
            "speed_mps": 0.0,
            "course_deg": 0.0,
            "battery_pct": 1.0,
            "seq": 1
        }
        """

        let data = json.data(using: .utf8)!

        // Act
        let decoded = try JSONDecoder().decode(LocationFix.self, from: data)

        // Assert - Check timestamp is within 1ms of expected
        let diff = abs(decoded.timestamp.timeIntervalSince1970 - expectedTimestamp.timeIntervalSince1970)
        #expect(diff < 0.001)
    }

    // MARK: - Equatable Tests

    @Test("LocationFix Equatable compares all fields")
    func equatableComparison() {
        // Arrange
        let timestamp = Date(timeIntervalSince1970: 1700000000)
        let coordinate = LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194)

        let fix1 = LocationFix(
            timestamp: timestamp,
            source: .watchOS,
            coordinate: coordinate,
            altitudeMeters: 15.5,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 5.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: 175.0,
            batteryFraction: 0.85,
            sequence: 12345,
            trackingPreset: "balanced"
        )

        let fix2 = LocationFix(
            timestamp: timestamp,
            source: .watchOS,
            coordinate: coordinate,
            altitudeMeters: 15.5,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 5.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: 175.0,
            batteryFraction: 0.85,
            sequence: 12345,
            trackingPreset: "balanced"
        )

        // Assert
        #expect(fix1 == fix2)
    }

    @Test("LocationFix Equatable detects differences")
    func equatableDetectsDifferences() {
        // Arrange
        let timestamp = Date(timeIntervalSince1970: 1700000000)
        let coordinate = LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194)

        let fix1 = LocationFix(
            timestamp: timestamp,
            source: .watchOS,
            coordinate: coordinate,
            altitudeMeters: 15.5,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 5.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: 175.0,
            batteryFraction: 0.85,
            sequence: 12345,
            trackingPreset: "balanced"
        )

        let fix2 = LocationFix(
            timestamp: timestamp,
            source: .watchOS,
            coordinate: coordinate,
            altitudeMeters: 15.5,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 5.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: 175.0,
            batteryFraction: 0.85,
            sequence: 99999, // Different sequence
            trackingPreset: "balanced"
        )

        // Assert
        #expect(fix1 != fix2)
    }
}
