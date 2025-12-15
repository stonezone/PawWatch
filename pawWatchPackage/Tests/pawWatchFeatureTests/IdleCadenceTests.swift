#if os(iOS)
import Foundation
import Testing
@testable import pawWatchFeature

/// Tests for IdleCadence preset switching and configuration
@Suite("IdleCadence Presets")
struct IdleCadenceTests {
    
    // MARK: - Preset Initialization Tests
    
    @Test("Default idle cadence preset is balanced")
    func defaultPresetIsBalanced() async {
        let manager = PetLocationManager()
        
        #expect(manager.idleCadencePreset == .balanced)
    }
    
    // MARK: - Preset Properties Tests
    
    @Test("Balanced preset has correct intervals")
    func balancedPresetIntervals() async {
        let preset = IdleCadencePreset.balanced
        
        #expect(preset.heartbeatInterval == 30)
        #expect(preset.fullFixInterval == 180)
        #expect(preset.displayName == "Balanced")
    }
    
    @Test("Live preset has correct intervals")
    func livePresetIntervals() async {
        let preset = IdleCadencePreset.live
        
        #expect(preset.heartbeatInterval == 15)
        #expect(preset.fullFixInterval == 90)
        #expect(preset.displayName == "Lab / Live")
    }
    
    @Test("Conservative preset has correct intervals")
    func conservativePresetIntervals() async {
        let preset = IdleCadencePreset.conservative
        
        #expect(preset.heartbeatInterval == 60)
        #expect(preset.fullFixInterval == 300)
        #expect(preset.displayName == "Battery Saver")
    }
    
    @Test("All presets have unique identifiers")
    func presetsHaveUniqueIds() async {
        let presets = IdleCadencePreset.allCases
        let ids = Set(presets.map { $0.id })
        
        #expect(ids.count == presets.count)
    }
    
    @Test("All presets have non-empty display names")
    func presetsHaveDisplayNames() async {
        for preset in IdleCadencePreset.allCases {
            #expect(!preset.displayName.isEmpty)
        }
    }
    
    @Test("All presets have footnotes")
    func presetsHaveFootnotes() async {
        for preset in IdleCadencePreset.allCases {
            #expect(!preset.footnote.isEmpty)
        }
    }
    
    // MARK: - Preset Switching Tests
    
    @Test("Switch from balanced to live preset")
    func switchToLivePreset() async {
        let manager = PetLocationManager()
        
        #expect(manager.idleCadencePreset == .balanced)
        
        manager.setIdleCadencePreset(.live)
        
        #expect(manager.idleCadencePreset == .live)
    }
    
    @Test("Switch from balanced to conservative preset")
    func switchToConservativePreset() async {
        let manager = PetLocationManager()
        
        #expect(manager.idleCadencePreset == .balanced)
        
        manager.setIdleCadencePreset(.conservative)
        
        #expect(manager.idleCadencePreset == .conservative)
    }
    
    @Test("Switch back to balanced from live")
    func switchBackToBalanced() async {
        let manager = PetLocationManager()
        
        manager.setIdleCadencePreset(.live)
        #expect(manager.idleCadencePreset == .live)
        
        manager.setIdleCadencePreset(.balanced)
        #expect(manager.idleCadencePreset == .balanced)
    }
    
    @Test("Cycle through all presets")
    func cycleAllPresets() async {
        let manager = PetLocationManager()
        
        for preset in IdleCadencePreset.allCases {
            manager.setIdleCadencePreset(preset)
            #expect(manager.idleCadencePreset == preset)
        }
    }
    
    @Test("Setting same preset twice is idempotent")
    func idempotentPresetChange() async {
        let manager = PetLocationManager()
        
        manager.setIdleCadencePreset(.live)
        #expect(manager.idleCadencePreset == .live)
        
        // Set again
        manager.setIdleCadencePreset(.live)
        #expect(manager.idleCadencePreset == .live)
    }
    
    // MARK: - Interval Validation Tests
    
    @Test("Live preset has shortest intervals")
    func livePresetIsFastest() async {
        let live = IdleCadencePreset.live
        let balanced = IdleCadencePreset.balanced
        let conservative = IdleCadencePreset.conservative
        
        #expect(live.heartbeatInterval < balanced.heartbeatInterval)
        #expect(live.heartbeatInterval < conservative.heartbeatInterval)
        #expect(live.fullFixInterval < balanced.fullFixInterval)
        #expect(live.fullFixInterval < conservative.fullFixInterval)
    }
    
    @Test("Conservative preset has longest intervals")
    func conservativePresetIsSlowest() async {
        let live = IdleCadencePreset.live
        let balanced = IdleCadencePreset.balanced
        let conservative = IdleCadencePreset.conservative
        
        #expect(conservative.heartbeatInterval > balanced.heartbeatInterval)
        #expect(conservative.heartbeatInterval > live.heartbeatInterval)
        #expect(conservative.fullFixInterval > balanced.fullFixInterval)
        #expect(conservative.fullFixInterval > live.fullFixInterval)
    }
    
    @Test("Balanced preset is between live and conservative")
    func balancedPresetIsMiddle() async {
        let live = IdleCadencePreset.live
        let balanced = IdleCadencePreset.balanced
        let conservative = IdleCadencePreset.conservative
        
        #expect(balanced.heartbeatInterval > live.heartbeatInterval)
        #expect(balanced.heartbeatInterval < conservative.heartbeatInterval)
        #expect(balanced.fullFixInterval > live.fullFixInterval)
        #expect(balanced.fullFixInterval < conservative.fullFixInterval)
    }
    
    @Test("All heartbeat intervals are positive")
    func heartbeatIntervalsPositive() async {
        for preset in IdleCadencePreset.allCases {
            #expect(preset.heartbeatInterval > 0)
        }
    }
    
    @Test("All full fix intervals are positive")
    func fullFixIntervalsPositive() async {
        for preset in IdleCadencePreset.allCases {
            #expect(preset.fullFixInterval > 0)
        }
    }
    
    @Test("Full fix interval is always greater than heartbeat interval")
    func fullFixGreaterThanHeartbeat() async {
        for preset in IdleCadencePreset.allCases {
            #expect(preset.fullFixInterval > preset.heartbeatInterval)
        }
    }
    
    // MARK: - Watch Interval Tracking Tests
    
    @Test("Watch idle intervals start as nil")
    func watchIntervalsStartNil() async {
        let manager = PetLocationManager()
        
        #expect(manager.watchIdleHeartbeatInterval == nil)
        #expect(manager.watchIdleFullFixInterval == nil)
    }
    
    // MARK: - Rapid Preset Changes
    
    @Test("Rapid preset changes do not crash")
    func rapidPresetChanges() async {
        let manager = PetLocationManager()
        
        // Rapidly cycle through presets
        for _ in 0..<10 {
            manager.setIdleCadencePreset(.live)
            manager.setIdleCadencePreset(.balanced)
            manager.setIdleCadencePreset(.conservative)
        }
        
        #expect(manager.idleCadencePreset == .conservative)
    }
    
    @Test("Preset change during location updates")
    func presetChangeDuringUpdates() async {
        let manager = PetLocationManager()
        
        // Simulate location update
        let fix = makeTestFix(sequence: 1)
        manager._testSetLatestLocation(fix)
        
        // Change preset
        manager.setIdleCadencePreset(.live)
        
        #expect(manager.idleCadencePreset == .live)
        #expect(manager.latestLocation != nil)
    }
    
    // MARK: - Preset Persistence Tests
    
    @Test("Preset changes persist across multiple operations")
    func presetPersistence() async {
        let manager = PetLocationManager()
        
        // Change preset multiple times
        manager.setIdleCadencePreset(.live)
        #expect(manager.idleCadencePreset == .live)
        
        // Do some other operations
        let fix = makeTestFix(sequence: 1)
        manager._testSetLatestLocation(fix)
        
        // Preset should still be live
        #expect(manager.idleCadencePreset == .live)
        
        // Change to conservative
        manager.setIdleCadencePreset(.conservative)
        #expect(manager.idleCadencePreset == .conservative)
    }
}

// MARK: - Test Helpers

private func makeTestFix(sequence: Int, timestamp: Date = Date()) -> LocationFix {
    LocationFix(
        timestamp: timestamp,
        source: .watchOS,
        coordinate: .init(latitude: 37.7749, longitude: -122.4194),
        altitudeMeters: 10,
        horizontalAccuracyMeters: 5,
        verticalAccuracyMeters: 7,
        speedMetersPerSecond: 0.5,
        courseDegrees: 90,
        headingDegrees: nil,
        batteryFraction: 0.85,
        sequence: sequence,
        trackingPreset: "balanced"
    )
}
#endif
