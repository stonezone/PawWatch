//
//  CloudKitLocationSync.swift
//  pawWatchFeature
//
//  Purpose: Syncs pet location data to CloudKit for offline recovery.
//           Enables data restoration after app reinstall or device change.
//
//  Created: 2025-11-26
//  Swift: 6.2
//  Platform: iOS 26+
//

import CloudKit
import Foundation
import OSLog

/// Syncs pet location and performance data to CloudKit for recovery scenarios.
/// - Saves latest location fix to user's private CloudKit database
/// - Saves a rolling history record for resilient trail recovery
/// - Restores data on app launch if local storage is empty
/// - Uses private database to protect user location privacy
public actor CloudKitLocationSync {
    public static let shared = CloudKitLocationSync()
    public static let locationSubscriptionID = "pawWatch.latest-pet-location.subscription"

    private let logger = Logger(subsystem: PawWatchLog.subsystem, category: "CloudKitSync")
    private let container: CKContainer
    private let database: CKDatabase

    // CloudKit record types
    private let locationRecordType = "PetLocation"
    private let locationHistoryRecordType = "PetLocationTrail"
    private let snapshotRecordType = "PerformanceSnapshot"
    private let historyRetentionInterval: TimeInterval = 14 * 24 * 60 * 60
    private let historyRecordSoftLimit = 2_500
    private let historyPruneBatchSize = 200
    private let historyPruneInterval: TimeInterval = 30 * 60

    // Single record ID for "latest" data (overwritten each time)
    private let latestLocationID = CKRecord.ID(recordName: "latest-pet-location")
    private let latestSnapshotID = CKRecord.ID(recordName: "latest-performance-snapshot")

    // CR-003 FIX: Cache account status to avoid expensive IPC calls on every save
    private var cachedAccountAvailable: Bool?
    private var lastAccountCheck: Date?
    private let accountCheckInterval: TimeInterval = 300 // Re-check every 5 minutes
    private var lastHistoryPruneDate: Date = .distantPast
    private var isPruningHistory = false

    private init() {
        container = CKContainer(identifier: "iCloud.com.stonezone.pawWatch")
        database = container.privateCloudDatabase
    }

    // MARK: - Location Sync

    /// Save a location fix to CloudKit.
    /// Writes both the latest pointer record and a history record for relay resilience.
    /// Returns true when at least one write succeeds.
    @discardableResult
    public func saveLocation(_ location: LocationFix) async -> Bool {
        // OPTIMIZATION: Check account status first to prevent error spam
        guard await checkAccountStatus() else { return false }

        // Track battery impact of CloudKit upload
        await BatteryProfiler.shared.startActivity(.cloudKitUpload)
        defer {
            Task {
                await BatteryProfiler.shared.endActivity(.cloudKitUpload)
            }
        }

        let latestSaved = await saveLatestLocation(location)
        let historySaved = await saveLocationHistory(location)
        let didSave = latestSaved || historySaved

        if didSave {
            logger.info("Location synced to CloudKit: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            Task(priority: .utility) {
                await self.pruneLocationHistoryIfNeeded()
            }
        } else {
            logger.error("CloudKit location save failed for seq=\(location.sequence, privacy: .public)")
        }
        return didSave
    }

    private func saveLatestLocation(_ location: LocationFix) async -> Bool {
        let record = CKRecord(recordType: locationRecordType, recordID: latestLocationID)
        do {
            try applyLocationFields(to: record, from: location)
            _ = try await database.save(record)
            return true
        } catch let error as CKError where error.code == .serverRecordChanged {
            return await updateExistingLocation(location)
        } catch {
            logger.error("CloudKit latest location save failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func saveLocationHistory(_ location: LocationFix) async -> Bool {
        let milliseconds = Int64(location.timestamp.timeIntervalSince1970 * 1000)
        let recordID = CKRecord.ID(recordName: "pet-location-\(milliseconds)-\(location.sequence)")
        let record = CKRecord(recordType: locationHistoryRecordType, recordID: recordID)

        do {
            try applyLocationFields(to: record, from: location)
            _ = try await database.save(record)
            return true
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Duplicate write for the same sequence/timestamp; treat as successful.
            return true
        } catch {
            logger.error("CloudKit location history save failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func updateExistingLocation(_ location: LocationFix) async -> Bool {
        do {
            let existingRecord = try await database.record(for: latestLocationID)
            try applyLocationFields(to: existingRecord, from: location)
            _ = try await database.save(existingRecord)
            logger.info("Location updated in CloudKit")
            return true
        } catch {
            logger.error("CloudKit location update failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func applyLocationFields(to record: CKRecord, from location: LocationFix) throws {
        let data = try JSONEncoder().encode(location)
        record["locationData"] = data as CKRecordValue
        record["timestamp"] = location.timestamp as CKRecordValue
        record["latitude"] = location.coordinate.latitude as CKRecordValue
        record["longitude"] = location.coordinate.longitude as CKRecordValue
        record["sequence"] = location.sequence as CKRecordValue
        record["horizontalAccuracyMeters"] = location.horizontalAccuracyMeters as CKRecordValue
    }

    private func pruneLocationHistoryIfNeeded() async {
        let now = Date()
        guard !isPruningHistory else { return }
        guard now.timeIntervalSince(lastHistoryPruneDate) >= historyPruneInterval else { return }

        isPruningHistory = true
        lastHistoryPruneDate = now
        defer { isPruningHistory = false }

        await pruneExpiredHistoryRecords(cutoff: now.addingTimeInterval(-historyRetentionInterval))
        await enforceHistorySoftLimit()
    }

    private func pruneExpiredHistoryRecords(cutoff: Date) async {
        let predicate = NSPredicate(format: "timestamp < %@", cutoff as NSDate)
        do {
            let candidates = try await fetchHistoryRecordIDs(
                predicate: predicate,
                sortAscending: true,
                limit: historyPruneBatchSize
            )
            guard !candidates.isEmpty else { return }
            let deleted = await deleteHistoryRecords(candidates)
            logger.notice("Pruned \(deleted, privacy: .public) CloudKit history records older than retention window")
        } catch {
            logger.error("CloudKit history age prune failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func enforceHistorySoftLimit() async {
        let fetchLimit = historyRecordSoftLimit + historyPruneBatchSize
        do {
            let oldestRecords = try await fetchHistoryRecordIDs(
                predicate: NSPredicate(value: true),
                sortAscending: true,
                limit: fetchLimit
            )
            let overflow = oldestRecords.count - historyRecordSoftLimit
            guard overflow > 0 else { return }

            let recordsToDelete = Array(oldestRecords.prefix(min(overflow, historyPruneBatchSize)))
            let deleted = await deleteHistoryRecords(recordsToDelete)
            logger.notice("Pruned \(deleted, privacy: .public) CloudKit history records to enforce size cap")
        } catch {
            logger.error("CloudKit history cap prune failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fetchHistoryRecordIDs(
        predicate: NSPredicate,
        sortAscending: Bool,
        limit: Int
    ) async throws -> [CKRecord.ID] {
        let query = CKQuery(recordType: locationHistoryRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: sortAscending)]

        let (matches, _) = try await database.records(
            matching: query,
            desiredKeys: [],
            resultsLimit: limit
        )

        var recordIDs: [CKRecord.ID] = []
        for (recordID, result) in matches {
            switch result {
            case .success:
                recordIDs.append(recordID)
            case .failure(let error):
                logger.warning("CloudKit history query returned partial failure for record \(recordID.recordName, privacy: .private): \(error.localizedDescription, privacy: .public)")
            }
        }
        return recordIDs
    }

    private func deleteHistoryRecords(_ recordIDs: [CKRecord.ID]) async -> Int {
        guard !recordIDs.isEmpty else { return 0 }
        do {
            let (_, deleteResults) = try await database.modifyRecords(
                saving: [],
                deleting: recordIDs,
                savePolicy: .ifServerRecordUnchanged,
                atomically: false
            )
            return deleteResults.values.reduce(into: 0) { count, result in
                switch result {
                case .success:
                    count += 1
                case .failure(let error as CKError) where error.code == .unknownItem:
                    count += 1
                case .failure:
                    break
                }
            }
        } catch {
            logger.error("CloudKit history delete failed: \(error.localizedDescription, privacy: .public)")
            return 0
        }
    }

    /// Load the latest location from CloudKit (for recovery).
    public func loadLocation() async -> LocationFix? {
        do {
            let record = try await database.record(for: latestLocationID)
            guard let data = record["locationData"] as? Data else {
                logger.notice("CloudKit location record missing data field")
                return nil
            }

            let location = try JSONDecoder().decode(LocationFix.self, from: data)
            logger.info("Location restored from CloudKit: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            return location
        } catch let error as CKError where error.code == .unknownItem {
            logger.notice("No location data in CloudKit yet")
            return nil
        } catch {
            logger.error("CloudKit location load failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Push Subscriptions

    /// Ensures a CloudKit subscription exists for location updates.
    ///
    /// Used by the iPhone app in Emergency mode to receive silent pushes when the watch writes a new fix.
    public func ensureLocationSubscription() async -> Bool {
        guard await checkAccountStatus() else { return false }

        do {
            _ = try await fetchSubscription(withID: Self.locationSubscriptionID)
            return true
        } catch let error as CKError where error.code == .unknownItem {
            // Not found: create it below.
        } catch {
            logger.error("CloudKit subscription fetch failed: \(error.localizedDescription, privacy: .public)")
        }

        let predicate = NSPredicate(value: true)
        let options: CKQuerySubscription.Options = [.firesOnRecordCreation, .firesOnRecordUpdate]
        let subscription = CKQuerySubscription(
            recordType: locationRecordType,
            predicate: predicate,
            subscriptionID: Self.locationSubscriptionID,
            options: options
        )

        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info

        do {
            _ = try await saveSubscription(subscription)
            logger.info("CloudKit location subscription ensured")
            return true
        } catch {
            logger.error("CloudKit subscription save failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Best-effort removal of the location subscription to avoid background wakeups when Emergency mode is off.
    public func deleteLocationSubscription() async {
        do {
            _ = try await deleteSubscription(withID: Self.locationSubscriptionID)
        } catch let error as CKError where error.code == .unknownItem {
            return
        } catch {
            logger.error("CloudKit subscription delete failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Performance Snapshot Sync

    /// Save the latest performance snapshot to CloudKit.
    /// Silently returns if iCloud is unavailable to prevent error log spam.
    public func saveSnapshot(_ snapshot: PerformanceSnapshot) async {
        // OPTIMIZATION: Check account status first to prevent error spam
        guard await checkAccountStatus() else { return }

        let record = CKRecord(recordType: snapshotRecordType, recordID: latestSnapshotID)

        do {
            let data = try JSONEncoder().encode(snapshot)
            record["snapshotData"] = data as CKRecordValue
            record["timestamp"] = snapshot.timestamp as CKRecordValue
            record["reachable"] = (snapshot.reachable ? 1 : 0) as CKRecordValue

            try await database.save(record)
            logger.info("Snapshot synced to CloudKit")
        } catch let error as CKError where error.code == .serverRecordChanged {
            await updateExistingSnapshot(snapshot)
        } catch {
            logger.error("CloudKit snapshot save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func updateExistingSnapshot(_ snapshot: PerformanceSnapshot) async {
        do {
            let existingRecord = try await database.record(for: latestSnapshotID)
            let data = try JSONEncoder().encode(snapshot)
            existingRecord["snapshotData"] = data as CKRecordValue
            existingRecord["timestamp"] = snapshot.timestamp as CKRecordValue
            existingRecord["reachable"] = (snapshot.reachable ? 1 : 0) as CKRecordValue

            try await database.save(existingRecord)
            logger.info("Snapshot updated in CloudKit")
        } catch {
            logger.error("CloudKit snapshot update failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Load the latest performance snapshot from CloudKit (for recovery).
    public func loadSnapshot() async -> PerformanceSnapshot? {
        do {
            let record = try await database.record(for: latestSnapshotID)
            guard let data = record["snapshotData"] as? Data else {
                logger.notice("CloudKit snapshot record missing data field")
                return nil
            }

            let snapshot = try JSONDecoder().decode(PerformanceSnapshot.self, from: data)
            logger.info("Snapshot restored from CloudKit")
            return snapshot
        } catch let error as CKError where error.code == .unknownItem {
            logger.notice("No snapshot data in CloudKit yet")
            return nil
        } catch {
            logger.error("CloudKit snapshot load failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Account Status

    /// Check if iCloud is available for the user.
    /// CR-003 FIX: Uses cached status to avoid expensive IPC calls on every operation.
    /// Re-checks every 5 minutes or on explicit request.
    public func checkAccountStatus(forceRefresh: Bool = false) async -> Bool {
        // Return cached value if recent and not forcing refresh
        let now = Date()
        if !forceRefresh,
           let cached = cachedAccountAvailable,
           let lastCheck = lastAccountCheck,
           now.timeIntervalSince(lastCheck) < accountCheckInterval {
            return cached
        }

        // Perform actual check and cache result
        do {
            let status = try await container.accountStatus()
            lastAccountCheck = now
            switch status {
            case .available:
                cachedAccountAvailable = true
                return true
            case .noAccount:
                logger.notice("No iCloud account configured")
            case .restricted:
                logger.notice("iCloud access restricted")
            case .couldNotDetermine:
                logger.notice("Could not determine iCloud status")
            case .temporarilyUnavailable:
                logger.notice("iCloud temporarily unavailable")
            @unknown default:
                logger.notice("Unknown iCloud status")
            }
            cachedAccountAvailable = false
            return false
        } catch {
            logger.error("iCloud status check failed: \(error.localizedDescription, privacy: .public)")
            cachedAccountAvailable = false
            return false
        }
    }

    /// Invalidate cached account status (call on CKAccountChangedNotification)
    public func invalidateAccountCache() {
        cachedAccountAvailable = nil
        lastAccountCheck = nil
    }
}

private extension CloudKitLocationSync {
    func fetchSubscription(withID id: String) async throws -> CKSubscription {
        try await withCheckedThrowingContinuation { continuation in
            database.fetch(withSubscriptionID: id) { subscription, error in
                if let subscription {
                    continuation.resume(returning: subscription)
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(throwing: CKError(.unknownItem))
            }
        }
    }

    func saveSubscription(_ subscription: CKSubscription) async throws -> CKSubscription {
        try await withCheckedThrowingContinuation { continuation in
            database.save(subscription) { saved, error in
                if let saved {
                    continuation.resume(returning: saved)
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(throwing: CKError(.internalError))
            }
        }
    }

    func deleteSubscription(withID id: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            database.delete(withSubscriptionID: id) { deletedID, error in
                if let deletedID {
                    continuation.resume(returning: deletedID)
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(throwing: CKError(.internalError))
            }
        }
    }
}
