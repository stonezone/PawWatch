///
/// PhoneWatchConnectivityManager.swift
/// pawWatch
///
/// Manages WatchConnectivity on the iPhone side to receive location data from Apple Watch.
///

import Foundation
import WatchConnectivity
import OSLog
import pawWatchFeature

final class PhoneWatchConnectivityManager: NSObject, ObservableObject, @unchecked Sendable {
    nonisolated(unsafe) static let shared = PhoneWatchConnectivityManager()

    @MainActor @Published var isWatchReachable = false
    @MainActor @Published var lastReceivedFix: Date?

    private let logger = Logger(subsystem: "com.stonezone.pawWatch", category: "PhoneWatchConnectivity")
    private var session: WCSession?

    private override init() {
        super.init()
        setupWatchConnectivity()
    }

    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            logger.notice("WatchConnectivity not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
        logger.notice("WatchConnectivity session activating...")

        // 🔍 DIAGNOSTIC: Schedule pairing check after activation completes
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            self.diagnosePairingState()
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneWatchConnectivityManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let reachable = session.isReachable
        let activationStateValue = activationState.rawValue
        let errorDescription = error?.localizedDescription
        let isPaired = session.isPaired
        let isWatchAppInstalled = session.isWatchAppInstalled

        Task { @MainActor [weak self] in
            guard let self else { return }
            if let errorDescription {
                self.logger.error("WCSession activation failed: \(errorDescription, privacy: .public)")
            } else {
                self.logger.notice("WCSession activated with state: \(activationStateValue)")
                self.logger.notice("  isPaired: \(isPaired)")
                self.logger.notice("  isWatchAppInstalled: \(isWatchAppInstalled)")
                self.logger.notice("  isReachable: \(reachable)")
                self.isWatchReachable = reachable

                // Log critical issues
                if !isPaired {
                    self.logger.error("❌ CRITICAL: Watch not paired to iPhone")
                }
                if !isWatchAppInstalled {
                    self.logger.error("❌ CRITICAL: Watch app not detected by WatchConnectivity")
                }
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.logger.notice("WCSession became inactive")
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        Task { @MainActor [weak self] in
            self?.logger.notice("WCSession deactivated")
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isWatchReachable = reachable
            self.logger.notice("Watch reachability changed: \(reachable)")
        }
    }

    // MARK: - Receiving Location Data

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        let payload = Self.preparePayload(from: message)
        Task { @MainActor [weak self] in
            self?.handleReceivedPayload(payload)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        let payload = Self.preparePayload(from: message)
        replyHandler(["status": "received"])
        Task { @MainActor [weak self] in
            self?.handleReceivedPayload(payload)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        let payload = Self.preparePayload(from: applicationContext)
        Task { @MainActor [weak self] in
            guard let self else { return }
            if payload.locationFix == nil {
                self.logger.notice("Received application context with \(payload.keys.count) keys but no fix payload")
            } else {
                self.logger.notice("Received application context with \(payload.keys.count) keys")
            }
            self.handleReceivedPayload(payload)
        }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let fileName = file.fileURL.lastPathComponent
        var decodedFix: LocationFix?
        var errorDescription: String?

        do {
            let data = try Data(contentsOf: file.fileURL)
            decodedFix = try Self.decodeLocationFix(from: data)
        } catch {
            errorDescription = error.localizedDescription
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.logger.notice("Received file: \(fileName)")

            if let decodedFix {
                self.handleLocationFix(decodedFix)
            } else if let errorDescription {
                self.logger.error("Failed to process file \(fileName): \(errorDescription, privacy: .public)")
            }
        }
    }

    private func handleReceivedPayload(_ payload: WatchMessagePayload) {
        logger.notice("Received message with \(payload.keys.joined(separator: ", "))")

        if let decodeErrorDescription = payload.decodeErrorDescription {
            logger.error("Failed to decode location fix: \(decodeErrorDescription, privacy: .public)")
        }

        if let fix = payload.locationFix {
            handleLocationFix(fix)
        }

        if let snapshotData = payload.performanceSnapshot {
            logger.notice("Received performance snapshot (\(snapshotData.count) bytes)")
            // Hook into PerformanceMonitor if needed
        }
    }

    private func handleLocationFix(_ fix: LocationFix) {
        Task { @MainActor in
            lastReceivedFix = Date()
        }
        logger.notice("📍 Received location: lat=\(fix.coordinate.latitude), lon=\(fix.coordinate.longitude), acc=\(fix.horizontalAccuracyMeters)m")

        NotificationCenter.default.post(
            name: NSNotification.Name("LocationFixReceived"),
            object: nil,
            userInfo: ["fix": fix]
        )
    }

    /// 🔍 DIAGNOSTIC: Comprehensive WCSession state diagnosis for iOS
    private func diagnosePairingState() {
        guard let session = session else {
            logger.error("🔍 DIAGNOSTIC: WCSession is nil")
            return
        }

        let separator = String(repeating: "=", count: 60)
        logger.notice("\n\(separator, privacy: .public)")
        logger.notice("🔍 iPhone: WatchConnectivity Diagnostic Report")
        logger.notice("\(separator, privacy: .public)")

        // Activation State
        let activationStateString: String
        switch session.activationState {
        case .notActivated:
            activationStateString = "⚠️  NOT ACTIVATED"
        case .inactive:
            activationStateString = "⚠️  INACTIVE"
        case .activated:
            activationStateString = "✅ ACTIVATED"
        @unknown default:
            activationStateString = "❓ UNKNOWN"
        }

        logger.notice("📱 Activation State: \(activationStateString)")
        logger.notice("   Raw Value: \(session.activationState.rawValue)")

        if session.activationState == .activated {
            logger.notice("\n🔗 Pairing Status:")
            logger.notice("   isPaired: \(session.isPaired ? "✅ YES" : "❌ NO")")
            logger.notice("   isWatchAppInstalled: \(session.isWatchAppInstalled ? "✅ YES" : "❌ NO - Watch app NOT detected")")
            logger.notice("   isReachable: \(session.isReachable ? "✅ YES" : "⚠️  NO")")

            logger.notice("\n📊 Session Properties:")
            logger.notice("   hasContentPending: \(session.hasContentPending)")
            logger.notice("   outstandingFileTransfers: \(session.outstandingFileTransfers.count)")
            logger.notice("   outstandingUserInfoTransfers: \(session.outstandingUserInfoTransfers.count)")
            logger.notice("   receivedApplicationContext keys: \(session.receivedApplicationContext.keys.joined(separator: ", "))")
            logger.notice("   applicationContext keys: \(session.applicationContext.keys.joined(separator: ", "))")

            // Critical error conditions
            if !session.isPaired {
                logger.error("\n❌ CRITICAL: Watch not paired in Settings")
            }

            if !session.isWatchAppInstalled {
                logger.error("\n❌ CRITICAL: Watch app NOT detected")
                logger.error("   → Most common cause of connectivity failure")
                logger.error("   → Solution: Delete both apps, clean build, reinstall Watch app FIRST")
            }

            if !session.isReachable && session.isWatchAppInstalled {
                logger.notice("\n⚠️  Watch app installed but unreachable")
                logger.notice("   → Watch might be sleeping or app not running")
            }
        }

        logger.notice("\(separator, privacy: .public)")
        logger.notice("End Diagnostic Report\n")
    }
}

private extension PhoneWatchConnectivityManager {

    struct WatchMessagePayload: Sendable {
        let keys: [String]
        let locationFix: LocationFix?
        let performanceSnapshot: Data?
        let decodeErrorDescription: String?
    }

    nonisolated static func preparePayload(from message: [String: Any]) -> WatchMessagePayload {
        let keys = Array(message.keys)
        let snapshotData = message["performanceSnapshot"] as? Data

        var decodedFix: LocationFix?
        var decodeError: String?

        if let fixData = message["latestFix"] as? Data {
            do {
                decodedFix = try decodeLocationFix(from: fixData)
            } catch {
                decodeError = error.localizedDescription
            }
        }

        return WatchMessagePayload(
            keys: keys.sorted(),
            locationFix: decodedFix,
            performanceSnapshot: snapshotData,
            decodeErrorDescription: decodeError
        )
    }

    nonisolated static func decodeLocationFix(from data: Data) throws -> LocationFix {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LocationFix.self, from: data)
    }
}
