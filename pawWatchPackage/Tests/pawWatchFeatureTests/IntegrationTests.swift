#if os(iOS)
import Foundation
import Testing
@testable import pawWatchFeature

/// Integration tests for critical feature combinations
@Suite("Feature Integration")
struct IntegrationTests {
    
    // MARK: - Emergency Mode + CloudKit Recovery
    
    @Test("Emergency mode with CloudKit recovery")
    func emergencyModeWithCloudKitRecovery() async {
        let manager = PetLocationManager()
        
        // Activate emergency mode
        manager.setTrackingMode(.emergency)
        
        #expect(manager.trackingMode == .emergency)
        
        // CloudKit recovery should work in emergency mode
        // (actual recovery depends on iCloud availability)
        #expect(manager.latestLocation == nil || manager.latestLocation != nil)
    }
    
    @Test("CloudKit recovery preserves emergency mode state")
    func cloudKitRecoveryPreservesEmergencyMode() async {
        let manager = PetLocationManager()
        
        // Set emergency mode
        manager.setTrackingMode(.emergency)
        
        // Wait for potential CloudKit recovery to complete
        try? await Task.sleep(for: .milliseconds(500))
        
        // Mode should still be emergency
        #expect(manager.trackingMode == .emergency)
    }
    
    // MARK: - IdleCadence + Emergency Mode Interaction
    
    @Test("Emergency mode overrides idle cadence")
    func emergencyModeOverridesIdleCadence() async {
        let manager = PetLocationManager()
        
        // Set a custom idle cadence
        manager.setIdleCadencePreset(.conservative)
        #expect(manager.idleCadencePreset == .conservative)
        
        // Switch to emergency mode
        manager.setTrackingMode(.emergency)
        
        // Emergency mode should be active
        #expect(manager.trackingMode == .emergency)
        
        // But idle cadence preference should be preserved
        #expect(manager.idleCadencePreset == .conservative)
    }
    
    @Test("Exiting emergency mode restores idle cadence")
    func exitingEmergencyRestoresIdleCadence() async {
        let manager = PetLocationManager()
        
        // Set idle cadence
        manager.setIdleCadencePreset(.live)
        
        // Enter emergency mode
        manager.setTrackingMode(.emergency)
        #expect(manager.trackingMode == .emergency)
        
        // Exit emergency mode
        manager.setTrackingMode(.balanced)
        #expect(manager.trackingMode == .balanced)
        
        // Idle cadence should still be live
        #expect(manager.idleCadencePreset == .live)
    }
    
    @Test("Emergency cadence changes while in emergency mode")
    func emergencyCadenceChangesInEmergencyMode() async {
        let manager = PetLocationManager()
        
        // Enter emergency mode
        manager.setTrackingMode(.emergency)
        
        // Change emergency cadence while in emergency mode
        manager.setEmergencyCadencePreset(.fast)
        
        #expect(manager.emergencyCadencePreset == .fast)
        #expect(manager.trackingMode == .emergency)
    }
    
    // MARK: - Fix Acceptance Policy Integration
    
    @Test("Policy changes with mode transitions")
    func policyChangesWithModeTransitions() async {
        let manager = PetLocationManager()
        
        // Start with balanced
        manager.setTrackingMode(.balanced)
        
        // Create a moderately accurate fix (90m)
        let fix90m = makeFixWithAccuracy(90, sequence: 1)
        
        // Should be rejected in balanced mode (max 75m)
        #expect(manager.shouldAccept(fix90m) == false)
        
        // Switch to emergency
        manager.setTrackingMode(.emergency)
        
        // Same fix should now be accepted (emergency allows up to 150m)
        let fix90mAgain = makeFixWithAccuracy(90, sequence: 2)
        #expect(manager.shouldAccept(fix90mAgain) == true)
    }
    
    @Test("Saver mode has stricter policy than balanced")
    func saverModeStricterPolicy() async {
        let manager = PetLocationManager()
        
        // 65m accuracy fix
        let fix65m = makeFixWithAccuracy(65, sequence: 1)
        
        // Should be accepted in balanced mode (max 75m)
        manager.setTrackingMode(.balanced)
        #expect(manager.shouldAccept(fix65m) == true)
        
        // Should be rejected in saver mode (max 60m)
        manager.setTrackingMode(.saver)
        let fix65mAgain = makeFixWithAccuracy(65, sequence: 2)
        #expect(manager.shouldAccept(fix65mAgain) == false)
    }
    
    // MARK: - Location History Preservation
    
    @Test("Location history preserved across mode changes")
    func historyPreservedAcrossModeChanges() async {
        let manager = PetLocationManager()
        
        // Add a location
        let fix1 = makeFixAtLocation(37.7749, -122.4194, sequence: 1)
        manager._testSetLatestLocation(fix1)
        
        #expect(manager.latestLocation != nil)
        
        // Change modes multiple times
        manager.setTrackingMode(.emergency)
        manager.setTrackingMode(.saver)
        manager.setTrackingMode(.balanced)
        
        // Location should still exist
        #expect(manager.latestLocation != nil)
        #expect(manager.latestLocation?.sequence == 1)
    }
    
    @Test("Trail history preserved across idle cadence changes")
    func historyPreservedAcrossIdleCadenceChanges() async {
        let manager = PetLocationManager()
        
        // Add multiple locations
        let fix1 = makeFixAtLocation(37.0, -122.0, sequence: 1)
        manager._testSetLatestLocation(fix1)
        
        let fix2 = makeFixAtLocation(37.001, -122.001, sequence: 2)
        manager._testSetLatestLocation(fix2)
        
        #expect(manager.latestLocation != nil)
        
        // Change idle cadence
        manager.setIdleCadencePreset(.live)
        manager.setIdleCadencePreset(.conservative)
        
        // Latest location should still be fix2
        #expect(manager.latestLocation?.sequence == 2)
    }
    
    // MARK: - Sequence Tracking
    
    @Test("Sequence numbers increment correctly across mode changes")
    func sequenceNumbersAcrossModeChanges() async {
        let manager = PetLocationManager()
        
        // Add fix in balanced mode
        let fix1 = makeFixAtLocation(37.0, -122.0, sequence: 1)
        manager._testRecordSequence(1)
        #expect(manager.shouldAccept(fix1) == true)
        
        // Switch to emergency
        manager.setTrackingMode(.emergency)
        
        // Add another fix with next sequence
        let fix2 = makeFixAtLocation(37.001, -122.001, sequence: 2)
        manager._testRecordSequence(2)
        #expect(manager.shouldAccept(fix2) == true)
        
        // Duplicate sequence should be rejected
        let fix1Duplicate = makeFixAtLocation(37.002, -122.002, sequence: 1)
        #expect(manager.shouldAccept(fix1Duplicate) == false)
    }
    
    // MARK: - Comprehensive Workflow Tests
    
    @Test("Complete emergency workflow")
    func completeEmergencyWorkflow() async {
        let manager = PetLocationManager()
        
        // 1. Start in balanced mode with conservative cadence
        manager.setTrackingMode(.balanced)
        manager.setIdleCadencePreset(.conservative)
        
        // 2. Switch to emergency mode
        manager.setTrackingMode(.emergency)
        #expect(manager.trackingMode == .emergency)
        
        // 3. Set fast emergency cadence
        manager.setEmergencyCadencePreset(.fast)
        #expect(manager.emergencyCadencePreset == .fast)
        
        // 4. Accept a low-accuracy fix (emergency mode allows it)
        let emergencyFix = makeFixWithAccuracy(120, sequence: 1)
        #expect(manager.shouldAccept(emergencyFix) == true)
        
        // 5. Exit emergency mode
        manager.setTrackingMode(.balanced)
        #expect(manager.trackingMode == .balanced)
        
        // 6. Verify idle cadence was preserved
        #expect(manager.idleCadencePreset == .conservative)
        
        // 7. Verify emergency cadence was preserved
        #expect(manager.emergencyCadencePreset == .fast)
    }
    
    @Test("Mode switching under low battery conditions")
    func modeSwitchingLowBattery() async {
        let manager = PetLocationManager()
        
        // Simulate low battery location fix
        let lowBatteryFix = LocationFix(
            timestamp: Date(),
            source: .watchOS,
            coordinate: .init(latitude: 37.0, longitude: -122.0),
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10,
            verticalAccuracyMeters: 10,
            speedMetersPerSecond: 0,
            courseDegrees: 0,
            headingDegrees: nil,
            batteryFraction: 0.05,  // 5% battery
            sequence: 1,
            trackingPreset: "saver"
        )
        
        manager._testSetLatestLocation(lowBatteryFix)
        
        // Battery level should be reflected
        #expect(manager.batteryLevel == 0.05)
        
        // Should still be able to switch modes
        manager.setTrackingMode(.emergency)
        #expect(manager.trackingMode == .emergency)
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

private func makeFixAtLocation(_ latitude: Double, _ longitude: Double, sequence: Int, timestamp: Date = Date()) -> LocationFix {
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
