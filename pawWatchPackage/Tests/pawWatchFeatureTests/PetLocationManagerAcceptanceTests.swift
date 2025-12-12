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
