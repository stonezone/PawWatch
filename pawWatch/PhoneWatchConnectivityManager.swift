///
/// PhoneWatchConnectivityManager.swift
/// pawWatch
///
/// Manages WatchConnectivity on the iPhone side to receive location data from Apple Watch.
///

import Foundation
import WatchConnectivity
import OSLog
import UIKit
import pawWatchFeature

final class PhoneWatchConnectivityManager: NSObject, ObservableObject, @unchecked Sendable {
    nonisolated(unsafe) static let shared = PhoneWatchConnectivityManager()

    @MainActor @Published var isWatchReachable = false
    @MainActor @Published var lastReceivedFix: Date?

    private let logger = Logger(subsystem: "com.stonezone.pawWatch", category: "PhoneWatchConnectivity")
    private var session: WCSession?
    private var appInstallationObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private var activationRetryTask: Task<Void, Never>?

    private override init() {
        super.init()
        Task { @MainActor in
            setupWatchConnectivity()
            observeWatchAppInstallation()
            observeAppLifecycle()
        }
    }

    @MainActor
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
            self.retryActivationIfNeeded(reason: "post-activation")
        }
    }

    /// Observes system notifications for Watch app installation/updates
    @MainActor
    private func observeWatchAppInstallation() {
        // Start polling for Watch app installation
        Task { @MainActor in
            var previousState = session?.isWatchAppInstalled ?? false
            var retryCount = 0
            let maxRetries = 60 // Poll for up to 5 minutes (60 * 5 seconds)

            while retryCount < maxRetries {
                try? await Task.sleep(for: .seconds(5))

                guard let session = self.session else { continue }

                let currentState = session.isWatchAppInstalled

                // Detect state change from NO -> YES
                if !previousState && currentState {
                    self.logger.notice("✅ Watch app installation detected! (polling)")
                    self.logger.notice("🔄 Re-checking WCSession state...")
                    self.logger.notice("   isPaired: \(session.isPaired)")
                    self.logger.notice("   isWatchAppInstalled: \(session.isWatchAppInstalled)")
                    self.logger.notice("   isReachable: \(session.isReachable)")

                    self.diagnosePairingState()
                    break // Stop polling once detected
                }

                // Log periodic status
                if retryCount % 6 == 0 { // Every 30 seconds
                    self.logger.notice("⏱️  Polling for Watch app... (attempt \(retryCount + 1)/\(maxRetries))")
                    self.logger.notice("   isWatchAppInstalled: \(currentState)")
                }

                previousState = currentState
                retryCount += 1
            }

            if retryCount >= maxRetries {
                self.logger.notice("⚠️  Stopped polling for Watch app after \(maxRetries) attempts")
            }
        }

        // Also try listening for Darwin notifications (system-level)
        // This notification is posted by appconduitd when apps are installed
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let manager = Unmanaged<PhoneWatchConnectivityManager>.fromOpaque(observer).takeUnretainedValue()

                Task { @MainActor in
                    manager.logger.notice("📱 Received Darwin notification for app update")
                    manager.handleWatchAppPotentiallyInstalled()
                }
            },
            "com.apple.appconduit.remote_applications_updated" as CFString,
            nil,
            .deliverImmediately
        )
    }

    @MainActor
    private func handleWatchAppPotentiallyInstalled() {
        guard let session = self.session else { return }

        logger.notice("🔄 Checking if Watch app is now installed...")
        logger.notice("   isPaired: \(session.isPaired)")
        logger.notice("   isWatchAppInstalled: \(session.isWatchAppInstalled)")
        logger.notice("   isReachable: \(session.isReachable)")

        if session.isWatchAppInstalled {
            logger.notice("✅ Watch app confirmed installed!")
            diagnosePairingState()
        }
    }

    @MainActor
    private func observeAppLifecycle() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.logger.notice("App became active; re-evaluating WatchConnectivity state")
            self.diagnosePairingState()
            self.retryActivationIfNeeded(reason: "app-active")
        }
    }

    @MainActor
    private func retryActivationIfNeeded(reason: String, delay: TimeInterval = 2.0) {
        activationRetryTask?.cancel()
        activationRetryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, let session = self.session else { return }
            if session.activationState != .activated || !session.isWatchAppInstalled {
                self.logger.notice("Re-attempting WCSession.activate() (reason: \(reason))")
                session.activate()
            }
        }
    }

    deinit {
        if let observer = appInstallationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        // Remove Darwin notification observer
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
        foregroundObserver.map(NotificationCenter.default.removeObserver(_:))
        activationRetryTask?.cancel()
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
                self.retryActivationIfNeeded(reason: "activation-error")
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
                    self.retryActivationIfNeeded(reason: "watch-app-missing")
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
            self?.retryActivationIfNeeded(reason: "session-deactivated")
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.logger.notice("WCSession watch state changed; rechecking pairing")
            self.diagnosePairingState()
            self.retryActivationIfNeeded(reason: "watch-state-change")
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
        // 🔍 DIAGNOSTIC: Check for Watch diagnostic messages first
        if let diagnostic = applicationContext["diagnostic"] as? String {
            // Capture values before entering async context
            let state = applicationContext["activationState"] as? Int ?? -1
            let isCompanionInstalled = applicationContext["isCompanionAppInstalled"] as? Bool ?? false
            let error = applicationContext["error"] as? String ?? "none"

            Task { @MainActor [weak self] in
                self?.logger.notice("📱 Received Watch diagnostic: \(diagnostic)")

                if diagnostic == "watch_activated" {
                    self?.logger.notice("   activationState: \(state)")
                    self?.logger.notice("   isCompanionAppInstalled: \(isCompanionInstalled)")
                    self?.logger.notice("   error: \(error)")

                    // Re-check pairing state after Watch activation
                    try? await Task.sleep(for: .seconds(1))
                    self?.diagnosePairingState()
                } else if diagnostic == "watch_not_supported" {
                    self?.logger.error("❌ Watch reports WCSession.isSupported() = FALSE")
                }
            }
            return
        }

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

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        let payload = Self.preparePayload(from: userInfo)
        Task { @MainActor [weak self] in
            self?.handleReceivedPayload(payload)
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
