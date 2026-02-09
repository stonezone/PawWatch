//
//  LocationPersistenceTests.swift
//  pawWatchFeatureTests
//
//  Purpose: Tests for LocationPersistence and SwiftData integration.
//
//  Created: 2026-02-09
//  Swift: 6.2
//  Platform: iOS 26.1+
//

import Testing
import Foundation
import SwiftData
@testable import pawWatchFeature

@Suite("LocationPersistence Tests")
@MainActor
struct LocationPersistenceTests {

    // MARK: - Test Helpers

    func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([PersistedLocationFix.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    func makeValidFix(sequence: Int = 1, timestamp: Date = Date()) -> LocationFix {
        LocationFix(
            timestamp: timestamp,
            source: .watchOS,
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            altitudeMeters: 50.0,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 15.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: 180.0,
            batteryFraction: 0.75,
            sequence: sequence
        )
    }

    // MARK: - Save Tests

    @Test("Save single location fix")
    func testSaveSingleFix() throws {
        let context = try makeInMemoryContext()
        let persistence = LocationPersistence(modelContext: context)
        let fix = makeValidFix()

        try persistence.save(fix)

        let count = try persistence.getTotalCount()
        #expect(count == 1)

        let stats = persistence.getStatistics()
        #expect(stats.totalSaved == 1)
    }

    @Test("Save multiple fixes in batch")
    func testSaveBatch() throws {
        let context = try makeInMemoryContext()
        let persistence = LocationPersistence(modelContext: context)

        let fixes = (1...5).map { makeValidFix(sequence: $0) }
        try persistence.saveBatch(fixes)

        let count = try persistence.getTotalCount()
        #expect(count == 5)

        let stats = persistence.getStatistics()
        #expect(stats.totalSaved == 5)
    }

    // MARK: - Load Tests

    @Test("Load recent fixes")
    func testLoadRecentFixes() throws {
        let context = try makeInMemoryContext()
        let persistence = LocationPersistence(modelContext: context)

        // Save 10 fixes with different timestamps
        let now = Date()
        let fixes = (0..<10).map { i in
            makeValidFix(
                sequence: i,
                timestamp: now.addingTimeInterval(TimeInterval(-i * 60))
            )
        }
        try persistence.saveBatch(fixes)

        // Load recent fixes
        let loaded = try persistence.loadRecentFixes(count: 5)

        #expect(loaded.count == 5)
        // Should be sorted newest first
        #expect(loaded[0].sequence == 0)
        #expect(loaded[4].sequence == 4)
    }

    @Test("Load fixes by date range")
    func testLoadFixesByDateRange() throws {
        let context = try makeInMemoryContext()
        let persistence = LocationPersistence(modelContext: context)

        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let twoHoursAgo = now.addingTimeInterval(-7200)

        // Save fixes at different times
        let fixes = [
            makeValidFix(sequence: 1, timestamp: twoHoursAgo),
            makeValidFix(sequence: 2, timestamp: oneHourAgo),
            makeValidFix(sequence: 3, timestamp: now)
        ]
        try persistence.saveBatch(fixes)

        // Load only middle fix
        let loaded = try persistence.loadFixes(
            from: oneHourAgo.addingTimeInterval(-60),
            to: oneHourAgo.addingTimeInterval(60)
        )

        #expect(loaded.count == 1)
        #expect(loaded[0].sequence == 2)
    }

    @Test("Load fixes by source")
    func testLoadFixesBySource() throws {
        let context = try makeInMemoryContext()
        let persistence = LocationPersistence(modelContext: context)

        // Create fixes from different sources
        let watchFix = LocationFix(
            timestamp: Date(),
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

        let iosFix = LocationFix(
            timestamp: Date(),
            source: .iOS,
            coordinate: LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194),
            altitudeMeters: nil,
            horizontalAccuracyMeters: 10.0,
            verticalAccuracyMeters: 15.0,
            speedMetersPerSecond: 2.5,
            courseDegrees: 180.0,
            headingDegrees: nil,
            batteryFraction: 0.75,
            sequence: 2
        )

        try persistence.saveBatch([watchFix, iosFix])

        // Load only watchOS fixes
        let watchFixes = try persistence.loadFixes(fromSource: .watchOS)
        #expect(watchFixes.count == 1)
        #expect(watchFixes[0].source == .watchOS)

        // Load only iOS fixes
        let iosFixes = try persistence.loadFixes(fromSource: .iOS)
        #expect(iosFixes.count == 1)
        #expect(iosFixes[0].source == .iOS)
    }

    // MARK: - Conversion Tests

    @Test("LocationFix converts to PersistedLocationFix and back")
    func testConversion() throws {
        let original = makeValidFix()
        let persisted = PersistedLocationFix(from: original)

        #expect(persisted.timestamp == original.timestamp)
        #expect(persisted.source == original.source.rawValue)
        #expect(persisted.latitude == original.coordinate.latitude)
        #expect(persisted.longitude == original.coordinate.longitude)
        #expect(persisted.speedMetersPerSecond == original.speedMetersPerSecond)

        let converted = persisted.toLocationFix()
        #expect(converted != nil)
        #expect(converted?.timestamp == original.timestamp)
        #expect(converted?.source == original.source)
        #expect(converted?.coordinate.latitude == original.coordinate.latitude)
        #expect(converted?.coordinate.longitude == original.coordinate.longitude)
    }

    // MARK: - Statistics Tests

    @Test("Get total count")
    func testGetTotalCount() throws {
        let context = try makeInMemoryContext()
        let persistence = LocationPersistence(modelContext: context)

        #expect(try persistence.getTotalCount() == 0)

        let fixes = (1...5).map { makeValidFix(sequence: $0) }
        try persistence.saveBatch(fixes)

        #expect(try persistence.getTotalCount() == 5)
    }

    @Test("Get date range")
    func testGetDateRange() throws {
        let context = try makeInMemoryContext()
        let persistence = LocationPersistence(modelContext: context)

        // Empty database returns nil
        let emptyRange = try persistence.getDateRange()
        #expect(emptyRange == nil)

        // Add fixes with known timestamps
        let oldest = Date().addingTimeInterval(-3600)
        let newest = Date()

        let fixes = [
            makeValidFix(sequence: 1, timestamp: oldest),
            makeValidFix(sequence: 2, timestamp: oldest.addingTimeInterval(1800)),
            makeValidFix(sequence: 3, timestamp: newest)
        ]
        try persistence.saveBatch(fixes)

        let range = try persistence.getDateRange()
        #expect(range != nil)
        #expect(range?.oldest == oldest)
        #expect(range?.newest == newest)
    }

    // MARK: - Cleanup Tests

    @Test("Delete all fixes")
    func testDeleteAll() throws {
        let context = try makeInMemoryContext()
        let persistence = LocationPersistence(modelContext: context)

        // Add some fixes
        let fixes = (1...5).map { makeValidFix(sequence: $0) }
        try persistence.saveBatch(fixes)

        #expect(try persistence.getTotalCount() == 5)

        // Delete all
        try persistence.deleteAll()

        #expect(try persistence.getTotalCount() == 0)

        let stats = persistence.getStatistics()
        #expect(stats.totalDeleted == 5)
    }

    @Test("Cleanup old fixes")
    func testCleanupOldFixes() throws {
        let context = try makeInMemoryContext()
        let persistence = LocationPersistence(modelContext: context)

        // First, save some recent fixes to establish a baseline
        let recentFixes = (1...3).map { makeValidFix(sequence: $0, timestamp: Date()) }
        try persistence.saveBatch(recentFixes)

        // This should trigger the first cleanup, so mark it as done
        // Now save some old fixes manually to bypass automatic cleanup
        let veryOld = Date().addingTimeInterval(-40 * 24 * 60 * 60)
        for i in 4...6 {
            let oldFix = makeValidFix(sequence: i, timestamp: veryOld)
            let persistedFix = PersistedLocationFix(from: oldFix)
            context.insert(persistedFix)
        }
        try context.save()

        let initialCount = try persistence.getTotalCount()
        #expect(initialCount == 6, "Should have 6 total fixes before cleanup, got \(initialCount)")

        // Manually trigger cleanup
        try persistence.cleanup()

        // Only recent fixes should remain (old ones should be deleted)
        let finalCount = try persistence.getTotalCount()
        #expect(finalCount == 3, "Should have 3 fixes after cleanup, got \(finalCount)")
    }

    // MARK: - Edge Cases

    @Test("Empty database load returns empty array")
    func testEmptyDatabaseLoad() throws {
        let context = try makeInMemoryContext()
        let persistence = LocationPersistence(modelContext: context)

        let fixes = try persistence.loadRecentFixes()
        #expect(fixes.isEmpty)
    }

    @Test("Load more than available returns all fixes")
    func testLoadMoreThanAvailable() throws {
        let context = try makeInMemoryContext()
        let persistence = LocationPersistence(modelContext: context)

        let fixes = (1...3).map { makeValidFix(sequence: $0) }
        try persistence.saveBatch(fixes)

        // Request 100 but only 3 exist
        let loaded = try persistence.loadRecentFixes(count: 100)
        #expect(loaded.count == 3)
    }
}
