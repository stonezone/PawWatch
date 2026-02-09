//
//  WatchCloudKitRelay.swift
//  pawWatch
//
//  Purpose: Manages emergency CloudKit uploads when iPhone is unreachable during
//           emergency tracking mode.
//
//  Extracted from WatchLocationProvider.swift as part of architectural refactoring.
//  Author: Refactored for modular architecture
//  Created: 2025-02-09
//  Swift: 6.2
//  Platform: watchOS 26.1+
//

import Foundation
#if os(watchOS)
import OSLog

// MARK: - CloudKit Relay Delegate

@MainActor
protocol WatchCloudKitRelayDelegate: AnyObject, Sendable {
    /// Called when emergency upload completes successfully
    func cloudKitRelay(_ relay: WatchCloudKitRelay, didUploadFix fix: LocationFix)

    /// Called when emergency upload fails
    func cloudKitRelay(_ relay: WatchCloudKitRelay, didFailUpload error: Error)
}

// MARK: - Watch CloudKit Relay

/// Manages emergency CloudKit uploads when iPhone is unreachable.
///
/// Responsibilities:
/// - Upload location fixes to CloudKit during emergency mode
/// - Throttle uploads to respect CloudKit rate limits (5 min interval)
/// - Only upload when iPhone is confirmed unreachable
/// - Coordinate with CloudKitLocationSync service
@MainActor
final class WatchCloudKitRelay {

    // MARK: - Properties

    weak var delegate: WatchCloudKitRelayDelegate?

    private let logger = Logger(subsystem: PawWatchLog.subsystem, category: "WatchCloudKitRelay")

    /// Throttle CloudKit writes to avoid rate limiting (5 minutes)
    private let emergencyCloudRelayInterval: TimeInterval = 300.0

    /// Last time we uploaded to CloudKit
    private var lastEmergencyCloudRelayDate: Date = .distantPast

    /// Whether emergency mode is currently active
    private var isEmergencyMode = false

    // MARK: - Public Methods

    /// Sets emergency mode state
    func setEmergencyMode(_ enabled: Bool) {
        isEmergencyMode = enabled
        if enabled {
            // Reset throttle timer when entering emergency mode
            lastEmergencyCloudRelayDate = .distantPast
            logger.notice("Emergency CloudKit relay enabled")
        } else {
            logger.notice("Emergency CloudKit relay disabled")
        }
    }

    /// Attempts to upload fix to CloudKit if conditions are met
    func uploadFixIfNeeded(_ fix: LocationFix, phoneReachable: Bool) {
        // Only upload in emergency mode
        guard isEmergencyMode else { return }

        // Only upload when phone is unreachable
        guard !phoneReachable else { return }

        // Check throttle interval
        let now = Date()
        guard now.timeIntervalSince(lastEmergencyCloudRelayDate) >= emergencyCloudRelayInterval else {
            return
        }

        lastEmergencyCloudRelayDate = now
        logger.notice("Emergency relay: uploading fix seq=\(fix.sequence) to CloudKit")

        // Upload in background with low priority
        Task.detached(priority: .utility) {
            await CloudKitLocationSync.shared.saveLocation(fix)
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.delegate?.cloudKitRelay(self, didUploadFix: fix)
            }
        }
    }

    /// Resets throttle timer (call when entering emergency mode or phone becomes reachable)
    func resetThrottle() {
        lastEmergencyCloudRelayDate = .distantPast
        logger.log("CloudKit throttle timer reset")
    }

    /// Returns time until next allowed upload
    var timeUntilNextUpload: TimeInterval {
        let elapsed = Date().timeIntervalSince(lastEmergencyCloudRelayDate)
        return max(0, emergencyCloudRelayInterval - elapsed)
    }

    /// Returns whether an upload would be allowed now
    var canUploadNow: Bool {
        Date().timeIntervalSince(lastEmergencyCloudRelayDate) >= emergencyCloudRelayInterval
    }
}

#endif
