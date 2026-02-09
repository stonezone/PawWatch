#if os(iOS)
import Foundation
import Testing
@testable import pawWatchFeature

@Test func shouldAcceptDropsDuplicateSequences() async {
    let manager = PetLocationManager()
    let fix = makeFix(sequence: 42, timestamp: Date(), accuracy: 5, coordinate: .init(latitude: 37.0, longitude: -122.0))
    manager._testRecordSequence(42)
    #expect(manager.shouldAccept(fix) == false)
}

@Test func shouldAcceptDropsLowAccuracyFixes() async {
    let manager = PetLocationManager()
    let fix = makeFix(sequence: 1, timestamp: Date(), accuracy: 200, coordinate: .init(latitude: 37.0, longitude: -122.0))
    #expect(manager.shouldAccept(fix) == false)
}

@Test func shouldAcceptDropsImplausibleJumps() async {
    let manager = PetLocationManager()
    let now = Date()
    let baseline = makeFix(sequence: 10, timestamp: now, accuracy: 5, coordinate: .init(latitude: 37.0, longitude: -122.0))
    manager._testSetLatestLocation(baseline)

    let jumped = makeFix(sequence: 11, timestamp: now.addingTimeInterval(1), accuracy: 5, coordinate: .init(latitude: 37.1, longitude: -122.0))
    #expect(manager.shouldAccept(jumped) == false)
}

@Test func shouldAcceptAllowsHistoricalFixesForTrail() async {
    let manager = PetLocationManager()
    let old = makeFix(sequence: 2, timestamp: Date().addingTimeInterval(-300), accuracy: 5, coordinate: .init(latitude: 37.0, longitude: -122.0))
    #expect(manager.shouldAccept(old) == true)
}

// MARK: - Emergency Mode Policy Tests

@Test("Emergency mode accepts fixes at 150m accuracy threshold")
func emergencyModeAcceptsFixAtThreshold() async {
    let manager = PetLocationManager()
    manager.setTrackingMode(.emergency)

    // Fix at exactly 150m should be accepted
    let fix = makeFix(sequence: 100, timestamp: Date(), accuracy: 150.0, coordinate: .init(latitude: 37.0, longitude: -122.0))
    #expect(manager.shouldAccept(fix) == true)
}

@Test("Emergency mode rejects fixes above 150m accuracy threshold")
func emergencyModeRejectsFixAboveThreshold() async {
    let manager = PetLocationManager()
    manager.setTrackingMode(.emergency)

    // Fix at 150.1m should be rejected
    let fix = makeFix(sequence: 101, timestamp: Date(), accuracy: 150.1, coordinate: .init(latitude: 37.0, longitude: -122.0))
    #expect(manager.shouldAccept(fix) == false)
}

@Test("Emergency mode accepts fixes below 150m accuracy threshold")
func emergencyModeAcceptsFixBelowThreshold() async {
    let manager = PetLocationManager()
    manager.setTrackingMode(.emergency)

    // Fix at 120m should be accepted
    let fix = makeFix(sequence: 102, timestamp: Date(), accuracy: 120.0, coordinate: .init(latitude: 37.0, longitude: -122.0))
    #expect(manager.shouldAccept(fix) == true)
}

@Test("Emergency mode rejects jumps over 10km within 5 seconds")
func emergencyModeRejectsLargeJump() async {
    let manager = PetLocationManager()
    manager.setTrackingMode(.emergency)

    let now = Date()
    let baseline = makeFix(sequence: 200, timestamp: now, accuracy: 10.0, coordinate: .init(latitude: 37.0, longitude: -122.0))
    manager._testSetLatestLocation(baseline)

    // Jump of ~11km should be rejected
    let jumped = makeFix(sequence: 201, timestamp: now.addingTimeInterval(1), accuracy: 10.0, coordinate: .init(latitude: 37.1, longitude: -122.0))
    #expect(manager.shouldAccept(jumped) == false)
}

@Test("Emergency mode accepts jumps under 10km within 5 seconds")
func emergencyModeAcceptsSmallJump() async {
    let manager = PetLocationManager()
    manager.setTrackingMode(.emergency)

    let now = Date()
    let baseline = makeFix(sequence: 210, timestamp: now, accuracy: 10.0, coordinate: .init(latitude: 37.0, longitude: -122.0))
    manager._testSetLatestLocation(baseline)

    // Jump of ~8km should be accepted
    let jumped = makeFix(sequence: 211, timestamp: now.addingTimeInterval(1), accuracy: 10.0, coordinate: .init(latitude: 37.072, longitude: -122.0))
    #expect(manager.shouldAccept(jumped) == true)
}

@Test("Emergency mode accepts stale fixes within 60 seconds")
func emergencyModeAcceptsStaleFix() async {
    let manager = PetLocationManager()
    manager.setTrackingMode(.emergency)

    // Fix that is 59 seconds old should be accepted
    let fix = makeFix(sequence: 300, timestamp: Date().addingTimeInterval(-59), accuracy: 10.0, coordinate: .init(latitude: 37.0, longitude: -122.0))
    #expect(manager.shouldAccept(fix) == true)
}

@Test("Emergency mode allows very stale fixes for historical trail")
func emergencyModeAllowsVeryStaleFixForTrail() async {
    let manager = PetLocationManager()
    manager.setTrackingMode(.emergency)

    // Fix that is 120 seconds old should still be accepted for trail history
    let fix = makeFix(sequence: 301, timestamp: Date().addingTimeInterval(-120), accuracy: 10.0, coordinate: .init(latitude: 37.0, longitude: -122.0))
    #expect(manager.shouldAccept(fix) == true)
}

private func makeFix(sequence: Int, timestamp: Date, accuracy: Double, coordinate: LocationFix.Coordinate) -> LocationFix {
    LocationFix(
        timestamp: timestamp,
        source: .watchOS,
        coordinate: coordinate,
        altitudeMeters: nil,
        horizontalAccuracyMeters: accuracy,
        verticalAccuracyMeters: accuracy,
        speedMetersPerSecond: 0,
        courseDegrees: 0,
        headingDegrees: nil,
        batteryFraction: 1,
        sequence: sequence,
        trackingPreset: "balanced"
    )
}
#endif
