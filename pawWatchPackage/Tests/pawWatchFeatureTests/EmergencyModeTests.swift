#if os(iOS)
import Foundation
import Testing
@testable import pawWatchFeature

/// Tests for Emergency mode activation, deactivation, and behavior
@Suite("Emergency Mode")
struct EmergencyModeTests {
    
    // MARK: - Mode Activation Tests
    
    @Test("Emergency mode activates correctly")
    func emergencyModeActivation() async {
        let manager = PetLocationManager()
        
        #expect(manager.trackingMode == .auto)
        
        manager.setTrackingMode(.emergency)
        
        #expect(manager.trackingMode == .emergency)
    }
    
    @Test("Emergency mode deactivates correctly")
    func emergencyModeDeactivation() async {
        let manager = PetLocationManager()
        
        manager.setTrackingMode(.emergency)
        #expect(manager.trackingMode == .emergency)
        
        manager.setTrackingMode(.balanced)
        #expect(manager.trackingMode == .balanced)
    }
    
    @Test("Switching from emergency to balanced mode")
    func emergencyToBalancedMode() async {
        let manager = PetLocationManager()
        
        // Start in emergency
        manager.setTrackingMode(.emergency)
        #expect(manager.trackingMode == .emergency)
        
        // Switch to balanced
        manager.setTrackingMode(.balanced)
        #expect(manager.trackingMode == .balanced)
        
        // Verify it stayed in balanced
        try? await Task.sleep(for: .milliseconds(100))
        #expect(manager.trackingMode == .balanced)
    }
    
    @Test("Switching from emergency to saver mode")
    func emergencyToSaverMode() async {
        let manager = PetLocationManager()
        
        manager.setTrackingMode(.emergency)
        #expect(manager.trackingMode == .emergency)
        
        manager.setTrackingMode(.saver)
        #expect(manager.trackingMode == .saver)
    }
    
    @Test("Multiple mode switches do not crash")
    func multipleModeSwitch() async {
        let manager = PetLocationManager()
        
        // Rapidly switch modes
        manager.setTrackingMode(.emergency)
        manager.setTrackingMode(.balanced)
        manager.setTrackingMode(.emergency)
        manager.setTrackingMode(.saver)
        manager.setTrackingMode(.auto)
        
        #expect(manager.trackingMode == .auto)
    }
    
    // MARK: - Emergency Cadence Preset Tests
    
    @Test("Emergency cadence preset defaults to standard")
    func emergencyCadenceDefaultsToStandard() async {
        let manager = PetLocationManager()
        
        #expect(manager.emergencyCadencePreset == .standard)
    }
    
    @Test("Set emergency cadence to fast preset")
    func setEmergencyCadenceToFast() async {
        let manager = PetLocationManager()
        
        manager.setEmergencyCadencePreset(.fast)
        
        #expect(manager.emergencyCadencePreset == .fast)
    }
    
    @Test("Emergency cadence only has standard and fast presets")
    func emergencyCadenceAllCases() async {
        let allCases = EmergencyCadencePreset.allCases
        
        #expect(allCases.count == 2)
        #expect(allCases.contains(.standard))
        #expect(allCases.contains(.fast))
    }
    
    @Test("Emergency cadence persists across preset changes")
    func emergencyCadencePersists() async {
        let manager = PetLocationManager()
        
        // Set to fast
        manager.setEmergencyCadencePreset(.fast)
        #expect(manager.emergencyCadencePreset == .fast)
        
        // Back to standard
        manager.setEmergencyCadencePreset(.standard)
        #expect(manager.emergencyCadencePreset == .standard)
        
        // Back to fast
        manager.setEmergencyCadencePreset(.fast)
        #expect(manager.emergencyCadencePreset == .fast)
    }
    
    @Test("Setting same emergency cadence twice is idempotent")
    func emergencyCadenceIdempotent() async {
        let manager = PetLocationManager()
        
        manager.setEmergencyCadencePreset(.fast)
        #expect(manager.emergencyCadencePreset == .fast)
        
        // Set again - should not cause issues
        manager.setEmergencyCadencePreset(.fast)
        #expect(manager.emergencyCadencePreset == .fast)
    }
    
    // MARK: - Fix Acceptance Policy Tests
    
    @Test("Emergency mode uses relaxed acceptance policy")
    func emergencyModeRelaxedAcceptance() async {
        let manager = PetLocationManager()
        
        manager.setTrackingMode(.emergency)
        
        // Emergency mode should accept fixes with lower accuracy (up to 150m)
        let lowAccuracyFix = makeFixWithAccuracy(120, sequence: 1)
        
        #expect(manager.shouldAccept(lowAccuracyFix) == true)
    }
    
    @Test("Balanced mode rejects low accuracy fixes")
    func balancedModeRejectsLowAccuracy() async {
        let manager = PetLocationManager()
        
        manager.setTrackingMode(.balanced)
        
        // Balanced mode should reject fixes over 75m accuracy
        let lowAccuracyFix = makeFixWithAccuracy(120, sequence: 1)
        
        #expect(manager.shouldAccept(lowAccuracyFix) == false)
    }
    
    @Test("Emergency mode accepts larger jumps")
    func emergencyModeAcceptsLargerJumps() async {
        let manager = PetLocationManager()
        
        manager.setTrackingMode(.emergency)
        
        // Set baseline location
        let baseline = makeFixAtCoordinate(37.0, -122.0, sequence: 1)
        manager._testSetLatestLocation(baseline)
        
        // Large jump (8km away) - emergency should accept up to 10km
        let jumped = makeFixAtCoordinate(37.072, -122.0, sequence: 2, timestamp: baseline.timestamp.addingTimeInterval(10))
        
        #expect(manager.shouldAccept(jumped) == true)
    }
    
    @Test("Balanced mode rejects large jumps")
    func balancedModeRejectsLargeJumps() async {
        let manager = PetLocationManager()
        
        manager.setTrackingMode(.balanced)
        
        // Set baseline
        let baseline = makeFixAtCoordinate(37.0, -122.0, sequence: 1)
        manager._testSetLatestLocation(baseline)
        
        // Large jump (8km) - balanced only allows 5km
        let jumped = makeFixAtCoordinate(37.072, -122.0, sequence: 2, timestamp: baseline.timestamp.addingTimeInterval(10))
        
        #expect(manager.shouldAccept(jumped) == false)
    }
    
    // MARK: - Edge Cases
    
    @Test("Emergency mode with nil location history")
    func emergencyModeWithNilHistory() async {
        let manager = PetLocationManager()
        
        manager.setTrackingMode(.emergency)
        
        // Should accept first fix even with no history
        let firstFix = makeFixAtCoordinate(37.0, -122.0, sequence: 1)
        
        #expect(manager.shouldAccept(firstFix) == true)
    }
    
    @Test("Mode change does not clear location history")
    func modeChangePreservesHistory() async {
        let manager = PetLocationManager()
        
        let fix = makeFixAtCoordinate(37.0, -122.0, sequence: 1)
        manager._testSetLatestLocation(fix)
        
        #expect(manager.latestLocation != nil)
        
        // Change mode
        manager.setTrackingMode(.emergency)
        
        // Location should still be there
        #expect(manager.latestLocation != nil)
        #expect(manager.latestLocation?.sequence == 1)
    }
}

// MARK: - Test Helpers

private func makeFixWithAccuracy(_ accuracy: Double, sequence: Int, timestamp: Date = Date()) -> LocationFix {
    LocationFix(
        timestamp: timestamp,
        source: .watchOS,
        coordinate: .init(latitude: 37.0, longitude: -122.0),
        altitudeMeters: nil,
        horizontalAccuracyMeters: accuracy,
        verticalAccuracyMeters: accuracy,
        speedMetersPerSecond: 0,
        courseDegrees: 0,
        headingDegrees: nil,
        batteryFraction: 1.0,
        sequence: sequence,
        trackingPreset: "balanced"
    )
}

private func makeFixAtCoordinate(_ latitude: Double, _ longitude: Double, sequence: Int, timestamp: Date = Date()) -> LocationFix {
    LocationFix(
        timestamp: timestamp,
        source: .watchOS,
        coordinate: .init(latitude: latitude, longitude: longitude),
        altitudeMeters: nil,
        horizontalAccuracyMeters: 5,
        verticalAccuracyMeters: 5,
        speedMetersPerSecond: 0,
        courseDegrees: 0,
        headingDegrees: nil,
        batteryFraction: 1.0,
        sequence: sequence,
        trackingPreset: "balanced"
    )
}
#endif
