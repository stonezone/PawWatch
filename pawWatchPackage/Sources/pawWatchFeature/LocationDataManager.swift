//
//  LocationDataManager.swift
//  pawWatch
//
//  Purpose: Integrates LocationValidator and LocationPersistence for safe location handling.
//           Validates incoming location data and persists valid fixes to the database.
//
//  Created: 2026-02-09
//  Swift: 6.2
//  Platform: iOS 26.1+
//

import Foundation
import SwiftData

/// Manager that coordinates location validation and persistence.
///
/// This actor provides a unified interface for:
/// - Validating incoming location fixes
/// - Persisting valid fixes to SwiftData
/// - Rejecting and logging invalid location data
/// - Loading location history on startup
@MainActor
public final class LocationDataManager {

    // MARK: - Properties

    private let validator: LocationValidator
    private let persistence: LocationPersistence

    // MARK: - Statistics

    private var totalReceived: Int = 0
    private var totalValidated: Int = 0
    private var totalPersisted: Int = 0
    private var totalRejected: Int = 0

    // MARK: - Initialization

    /// Initializes the location data manager with a SwiftData model context.
    ///
    /// - Parameter modelContext: The SwiftData model context for persistence
    public init(modelContext: ModelContext) {
        self.validator = LocationValidator()
        self.persistence = LocationPersistence(modelContext: modelContext)
    }

    // MARK: - Location Handling

    /// Processes an incoming location fix, validating and persisting it if valid.
    ///
    /// - Parameter fix: The location fix to process
    /// - Returns: True if the fix was valid and persisted, false otherwise
    /// - Throws: SwiftData errors if persistence fails
    @discardableResult
    public func processLocationFix(_ fix: LocationFix) async throws -> Bool {
        totalReceived += 1

        // Validate the fix
        let validationResult = await validator.validate(fix)

        switch validationResult {
        case .valid:
            totalValidated += 1

            // Persist the valid fix
            try persistence.save(fix)
            totalPersisted += 1
            return true

        case .invalid(let reason):
            totalRejected += 1
            // Log rejection for debugging
            print("Location fix rejected: \(reason) (seq: \(fix.sequence), source: \(fix.source.rawValue))")
            return false
        }
    }

    /// Processes multiple location fixes in a batch.
    ///
    /// - Parameter fixes: Array of location fixes to process
    /// - Returns: Number of fixes that were valid and persisted
    /// - Throws: SwiftData errors if persistence fails
    @discardableResult
    public func processLocationBatch(_ fixes: [LocationFix]) async throws -> Int {
        var validFixes: [LocationFix] = []

        for fix in fixes {
            totalReceived += 1

            let validationResult = await validator.validate(fix)

            switch validationResult {
            case .valid:
                totalValidated += 1
                validFixes.append(fix)

            case .invalid(let reason):
                totalRejected += 1
                // Log rejection for debugging
                print("Location fix rejected in batch: \(reason) (seq: \(fix.sequence))")
            }
        }

        if !validFixes.isEmpty {
            try persistence.saveBatch(validFixes)
            totalPersisted += validFixes.count
        }

        return validFixes.count
    }

    // MARK: - Loading Location History

    /// Loads recent location fixes from persistent storage.
    ///
    /// - Parameter count: Maximum number of recent fixes to load
    /// - Returns: Array of location fixes sorted by timestamp (newest first)
    /// - Throws: SwiftData errors if load fails
    public func loadRecentHistory(count: Int = 100) throws -> [LocationFix] {
        try persistence.loadRecentFixes(count: count)
    }

    /// Loads location fixes within a specific time range.
    ///
    /// - Parameters:
    ///   - startDate: Start of the time range
    ///   - endDate: End of the time range
    /// - Returns: Array of location fixes in the time range
    /// - Throws: SwiftData errors if load fails
    public func loadHistory(from startDate: Date, to endDate: Date) throws -> [LocationFix] {
        try persistence.loadFixes(from: startDate, to: endDate)
    }

    // MARK: - Statistics

    /// Returns combined statistics about validation and persistence operations.
    public func getStatistics() async -> LocationDataStatistics {
        let validationStats = await validator.getStatistics()
        let storedCount = (try? persistence.getTotalCount()) ?? 0

        return LocationDataStatistics(
            totalReceived: totalReceived,
            totalValidated: totalValidated,
            totalPersisted: totalPersisted,
            totalRejected: totalRejected,
            validationRate: validationStats.validationRate,
            invalidReasons: validationStats.invalidReasons,
            totalStoredFixes: storedCount
        )
    }

    /// Returns the date range of stored location fixes.
    public func getHistoryDateRange() throws -> (oldest: Date, newest: Date)? {
        try persistence.getDateRange()
    }

    // MARK: - Maintenance

    /// Manually triggers cleanup of old location data.
    public func cleanupOldData() throws {
        try persistence.cleanup()
    }
}

// MARK: - Supporting Types

/// Combined statistics about location data management.
public struct LocationDataStatistics: Sendable {
    /// Total number of location fixes received
    public let totalReceived: Int

    /// Total number of location fixes that passed validation
    public let totalValidated: Int

    /// Total number of location fixes persisted to database
    public let totalPersisted: Int

    /// Total number of location fixes rejected due to validation failure
    public let totalRejected: Int

    /// Validation success rate (0.0 to 1.0)
    public let validationRate: Double

    /// Dictionary of rejection reasons and their counts
    public let invalidReasons: [String: Int]

    /// Total number of location fixes currently stored in database
    public let totalStoredFixes: Int

    /// Computed rejection rate
    public var rejectionRate: Double {
        guard totalReceived > 0 else { return 0.0 }
        return Double(totalRejected) / Double(totalReceived)
    }

    /// Computed persistence rate
    public var persistenceRate: Double {
        guard totalReceived > 0 else { return 0.0 }
        return Double(totalPersisted) / Double(totalReceived)
    }
}
