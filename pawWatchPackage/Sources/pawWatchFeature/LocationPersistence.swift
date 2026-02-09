//
//  LocationPersistence.swift
//  pawWatch
//
//  Purpose: Actor responsible for persisting location fixes to SwiftData.
//           Manages location history, loading recent fixes, and database operations.
//
//  Created: 2026-02-09
//  Swift: 6.2
//  Platform: iOS 26.1+
//

import Foundation
import SwiftData

/// Actor responsible for persisting location data to SwiftData and managing location history.
///
/// Features:
/// - Saves validated location fixes to persistent storage
/// - Loads recent location history on startup
/// - Automatically cleans up old data to prevent database bloat
/// - Provides query capabilities for location history
@MainActor
public final class LocationPersistence {

    // MARK: - Constants

    /// Maximum number of location fixes to keep in the database
    /// Older fixes are automatically deleted
    private static let maxStoredFixes: Int = 10_000

    /// Maximum age of location fixes to keep (30 days)
    /// Older fixes are automatically deleted
    private static let maxFixAgeSeconds: TimeInterval = 30 * 24 * 60 * 60

    /// Number of recent fixes to load on startup
    public static let recentFixCount: Int = 100

    // MARK: - Properties

    private let modelContext: ModelContext
    private var lastCleanupDate: Date = .distantPast

    // MARK: - Statistics

    private var totalSaved: Int = 0
    private var totalLoaded: Int = 0
    private var totalDeleted: Int = 0

    // MARK: - Initialization

    /// Initializes the persistence layer with a model context.
    ///
    /// - Parameter modelContext: The SwiftData model context to use for persistence
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Save Operations

    /// Saves a validated location fix to persistent storage.
    ///
    /// - Parameter fix: The location fix to save
    /// - Throws: SwiftData errors if save fails
    public func save(_ fix: LocationFix) throws {
        let persistedFix = PersistedLocationFix(from: fix)
        modelContext.insert(persistedFix)

        try modelContext.save()
        totalSaved += 1

        // Periodically clean up old data
        try cleanupIfNeeded()
    }

    /// Saves multiple location fixes in a batch operation.
    ///
    /// - Parameter fixes: Array of location fixes to save
    /// - Throws: SwiftData errors if save fails
    public func saveBatch(_ fixes: [LocationFix]) throws {
        for fix in fixes {
            let persistedFix = PersistedLocationFix(from: fix)
            modelContext.insert(persistedFix)
        }

        try modelContext.save()
        totalSaved += fixes.count

        // Periodically clean up old data
        try cleanupIfNeeded()
    }

    // MARK: - Load Operations

    /// Loads the most recent location fixes from storage.
    ///
    /// - Parameter count: Maximum number of fixes to load (default: 100)
    /// - Returns: Array of location fixes sorted by timestamp (newest first)
    /// - Throws: SwiftData errors if fetch fails
    public func loadRecentFixes(count: Int = recentFixCount) throws -> [LocationFix] {
        let descriptor = FetchDescriptor<PersistedLocationFix>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        let persistedFixes = try modelContext.fetch(descriptor)
        let recentFixes = Array(persistedFixes.prefix(count))

        totalLoaded += recentFixes.count

        // Convert to LocationFix, filtering out any invalid conversions
        return recentFixes.compactMap { $0.toLocationFix() }
    }

    /// Loads location fixes within a specific time range.
    ///
    /// - Parameters:
    ///   - startDate: Start of the time range
    ///   - endDate: End of the time range
    /// - Returns: Array of location fixes in the time range
    /// - Throws: SwiftData errors if fetch fails
    public func loadFixes(from startDate: Date, to endDate: Date) throws -> [LocationFix] {
        let predicate = #Predicate<PersistedLocationFix> { fix in
            fix.timestamp >= startDate && fix.timestamp <= endDate
        }

        let descriptor = FetchDescriptor<PersistedLocationFix>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        let persistedFixes = try modelContext.fetch(descriptor)
        totalLoaded += persistedFixes.count

        return persistedFixes.compactMap { $0.toLocationFix() }
    }

    /// Loads all location fixes for a specific source (watchOS or iOS).
    ///
    /// - Parameter source: The source platform to filter by
    /// - Returns: Array of location fixes from the specified source
    /// - Throws: SwiftData errors if fetch fails
    public func loadFixes(fromSource source: LocationFix.Source) throws -> [LocationFix] {
        let sourceString = source.rawValue

        let predicate = #Predicate<PersistedLocationFix> { fix in
            fix.source == sourceString
        }

        let descriptor = FetchDescriptor<PersistedLocationFix>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        let persistedFixes = try modelContext.fetch(descriptor)
        totalLoaded += persistedFixes.count

        return persistedFixes.compactMap { $0.toLocationFix() }
    }

    // MARK: - Statistics

    /// Returns the total number of persisted location fixes in the database.
    ///
    /// - Returns: Count of all stored fixes
    /// - Throws: SwiftData errors if fetch fails
    public func getTotalCount() throws -> Int {
        let descriptor = FetchDescriptor<PersistedLocationFix>()
        return try modelContext.fetchCount(descriptor)
    }

    /// Returns the oldest and newest timestamps in the database.
    ///
    /// - Returns: Tuple of (oldest, newest) dates, or nil if no data
    /// - Throws: SwiftData errors if fetch fails
    public func getDateRange() throws -> (oldest: Date, newest: Date)? {
        // Fetch oldest
        let oldestDescriptor = FetchDescriptor<PersistedLocationFix>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        let oldestFix = try modelContext.fetch(oldestDescriptor).first

        // Fetch newest
        let newestDescriptor = FetchDescriptor<PersistedLocationFix>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let newestFix = try modelContext.fetch(newestDescriptor).first

        guard let oldest = oldestFix?.timestamp, let newest = newestFix?.timestamp else {
            return nil
        }

        return (oldest, newest)
    }

    /// Returns persistence statistics.
    public func getStatistics() -> PersistenceStatistics {
        PersistenceStatistics(
            totalSaved: totalSaved,
            totalLoaded: totalLoaded,
            totalDeleted: totalDeleted
        )
    }

    // MARK: - Cleanup Operations

    /// Cleans up old location fixes to prevent database bloat.
    ///
    /// Removes:
    /// - Fixes older than maxFixAgeSeconds
    /// - Excess fixes beyond maxStoredFixes (keeps newest)
    ///
    /// - Throws: SwiftData errors if delete fails
    private func cleanupIfNeeded() throws {
        let now = Date()

        // Only cleanup once per hour
        guard now.timeIntervalSince(lastCleanupDate) > 3600 else {
            return
        }

        lastCleanupDate = now

        // Delete old fixes
        try deleteOldFixes()

        // Delete excess fixes if we exceed the maximum count
        try deleteExcessFixes()
    }

    /// Deletes location fixes older than the maximum allowed age.
    private func deleteOldFixes() throws {
        let cutoffDate = Date().addingTimeInterval(-Self.maxFixAgeSeconds)

        let predicate = #Predicate<PersistedLocationFix> { fix in
            fix.timestamp < cutoffDate
        }

        let descriptor = FetchDescriptor<PersistedLocationFix>(predicate: predicate)
        let oldFixes = try modelContext.fetch(descriptor)

        for fix in oldFixes {
            modelContext.delete(fix)
        }

        if !oldFixes.isEmpty {
            try modelContext.save()
            totalDeleted += oldFixes.count
        }
    }

    /// Deletes excess location fixes beyond the maximum count, keeping the newest.
    private func deleteExcessFixes() throws {
        let totalCount = try getTotalCount()

        guard totalCount > Self.maxStoredFixes else {
            return
        }

        let excessCount = totalCount - Self.maxStoredFixes

        // Fetch oldest fixes to delete
        let descriptor = FetchDescriptor<PersistedLocationFix>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        let oldestFixes = try modelContext.fetch(descriptor)
        let fixesToDelete = Array(oldestFixes.prefix(excessCount))

        for fix in fixesToDelete {
            modelContext.delete(fix)
        }

        if !fixesToDelete.isEmpty {
            try modelContext.save()
            totalDeleted += fixesToDelete.count
        }
    }

    /// Manually triggers cleanup of old data.
    ///
    /// - Throws: SwiftData errors if cleanup fails
    public func cleanup() throws {
        lastCleanupDate = .distantPast // Force cleanup
        try cleanupIfNeeded()
    }

    /// Deletes all location fixes from the database.
    ///
    /// - Throws: SwiftData errors if delete fails
    public func deleteAll() throws {
        let descriptor = FetchDescriptor<PersistedLocationFix>()
        let allFixes = try modelContext.fetch(descriptor)

        for fix in allFixes {
            modelContext.delete(fix)
        }

        try modelContext.save()
        totalDeleted += allFixes.count
    }
}

// MARK: - Supporting Types

/// Statistics about persistence operations.
public struct PersistenceStatistics: Sendable {
    public let totalSaved: Int
    public let totalLoaded: Int
    public let totalDeleted: Int
}
