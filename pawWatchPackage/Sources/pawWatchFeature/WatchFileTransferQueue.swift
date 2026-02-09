//
//  WatchFileTransferQueue.swift
//  pawWatch
//
//  Purpose: Manages file-based location transfers with batching, queuing, and retry logic
//           for guaranteed delivery when interactive messaging is unavailable.
//
//  Extracted from WatchLocationProvider.swift as part of architectural refactoring.
//  Author: Refactored for modular architecture
//  Created: 2025-02-09
//  Swift: 6.2
//  Platform: watchOS 26.1+
//

import Foundation
#if os(watchOS)
@preconcurrency import WatchConnectivity
import OSLog

// MARK: - File Transfer Delegate

@MainActor
protocol WatchFileTransferQueueDelegate: AnyObject, Sendable {
    /// Called when batched fixes are flushed successfully
    func fileQueue(_ queue: WatchFileTransferQueue, didFlushBatch count: Int, seqRange: ClosedRange<Int>)

    /// Called when a file transfer completes successfully
    func fileQueue(_ queue: WatchFileTransferQueue, didCompleteTransfer fix: LocationFix)

    /// Called when a file transfer fails and will be retried
    func fileQueue(_ queue: WatchFileTransferQueue, didFailTransfer fix: LocationFix, error: Error)

    /// Called when encoding fails
    func fileQueue(_ queue: WatchFileTransferQueue, didFailEncoding error: Error)
}

// MARK: - Watch File Transfer Queue

/// Manages file-based location transfers with batching and retry logic.
///
/// Responsibilities:
/// - Buffer location fixes when phone is unreachable
/// - Batch fixes to prevent queue flooding
/// - Transfer files via WatchConnectivity
/// - Retry failed transfers
/// - Clean up temporary files
/// - Prevent overwhelming WCSession with thousands of queued transfers
@MainActor
final class WatchFileTransferQueue: NSObject {

    // MARK: - Properties

    weak var delegate: WatchFileTransferQueueDelegate?

    private var wcSession: WCSession { WCSession.default }
    private let encoder = JSONEncoder()
    private let fileManager = FileManager.default

    private let logger = Logger(subsystem: PawWatchLog.subsystem, category: "WatchFileTransferQueue")

    /// Controls whether file transfers are enabled
    private let fileTransfersEnabled = true

    // MARK: - Batching Properties

    /// Buffer to accumulate fixes when phone is unreachable
    private var pendingFixes: [LocationFix] = []

    /// Maximum fixes to batch before flushing
    private let batchThreshold = 60

    /// Maximum time before flushing batch
    private let batchFlushInterval: TimeInterval = 60.0

    /// Last time we flushed the batch buffer
    private var lastBatchFlushDate: Date = .distantPast

    // MARK: - Active Transfer Tracking

    /// Tracks active file transfers for retry and cleanup
    private var activeFileTransfers: [WCSessionFileTransfer: (url: URL, fix: LocationFix)] = [:]

    // MARK: - Initialization

    override init() {
        super.init()
        encoder.outputFormatting = [.withoutEscapingSlashes]
    }

    // MARK: - Public Methods

    /// Enqueues a fix for batched delivery
    func enqueueFix(_ fix: LocationFix) {
        guard wcSession.activationState == .activated else {
            logger.warning("Session not activated, dropping fix seq=\(fix.sequence)")
            return
        }

        pendingFixes.append(fix)
        ConnectivityLog.verbose("Buffered fix seq=\(fix.sequence) (buffer count: \(self.pendingFixes.count))")

        // Check if we should flush
        let shouldFlush = pendingFixes.count >= batchThreshold ||
            Date().timeIntervalSince(lastBatchFlushDate) >= batchFlushInterval

        if shouldFlush {
            flushPendingFixes()
        }
    }

    /// Flushes all pending fixes as a single batched transfer
    func flushPendingFixes() {
        guard !pendingFixes.isEmpty else { return }
        guard wcSession.activationState == .activated else {
            logger.warning("Cannot flush: session not activated")
            return
        }

        let fixesToFlush = pendingFixes
        pendingFixes.removeAll()
        lastBatchFlushDate = Date()

        do {
            let data = try encoder.encode(fixesToFlush)
            let firstSeq = fixesToFlush.first?.sequence ?? -1
            let lastSeq = fixesToFlush.last?.sequence ?? -1

            let userInfo: [String: Any] = [
                ConnectivityConstants.batchedFixes: data,
                ConnectivityConstants.timestamp: Date().timeIntervalSince1970,
                ConnectivityConstants.isBatched: true
            ]

            wcSession.transferUserInfo(userInfo)
            ConnectivityLog.notice("Flushed \(fixesToFlush.count) fixes in batched transfer (seqs: \(firstSeq)-\(lastSeq))")

            if firstSeq >= 0, lastSeq >= 0 {
                delegate?.fileQueue(self, didFlushBatch: fixesToFlush.count, seqRange: firstSeq...lastSeq)
            }
        } catch {
            ConnectivityLog.error("Failed to encode batched fixes: \(error.localizedDescription)")
            delegate?.fileQueue(self, didFailEncoding: error)
        }
    }

    /// Queues a single fix for file transfer
    func queueFileTransfer(for fix: LocationFix) {
        guard fileTransfersEnabled else { return }
        guard wcSession.activationState == .activated else {
            logger.warning("Session not activated, cannot queue file transfer")
            return
        }

        do {
            let data = try encoder.encode(fix)
            let url = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try data.write(to: url)

            let transfer = wcSession.transferFile(url, metadata: [ConnectivityConstants.sequence: fix.sequence])
            activeFileTransfers[transfer] = (url, fix)

            ConnectivityLog.verbose("Queued file transfer for seq=\(fix.sequence)")
        } catch {
            ConnectivityLog.error("Failed to encode fix for file transfer: \(error.localizedDescription)")
            delegate?.fileQueue(self, didFailEncoding: error)
        }
    }

    /// Returns count of pending fixes in buffer
    var pendingFixCount: Int {
        pendingFixes.count
    }

    /// Returns count of active file transfers
    var activeTransferCount: Int {
        activeFileTransfers.count
    }

    /// Clears all pending fixes and active transfers
    func clearAll() {
        pendingFixes.removeAll()

        // Clean up temp files for active transfers
        for (_, record) in activeFileTransfers {
            try? fileManager.removeItem(at: record.url)
        }

        activeFileTransfers.removeAll()
        logger.log("Cleared all pending fixes and active transfers")
    }

    // MARK: - WCSessionDelegate File Transfer Handling

    /// Call this from WCSessionDelegate to handle transfer completion
    func handleTransferCompletion(
        _ fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        guard let record = activeFileTransfers.removeValue(forKey: fileTransfer) else {
            return
        }

        // Always clean up temp file
        defer { try? fileManager.removeItem(at: record.url) }

        if let error {
            ConnectivityLog.error("File transfer failed: \(error.localizedDescription). Retrying…")
            delegate?.fileQueue(self, didFailTransfer: record.fix, error: error)
            queueFileTransfer(for: record.fix) // Retry
        } else {
            ConnectivityLog.verbose("File transfer completed successfully for seq=\(record.fix.sequence)")
            delegate?.fileQueue(self, didCompleteTransfer: record.fix)
        }
    }
}

#endif
