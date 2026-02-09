//
//  WatchConnectivityRelay.swift
//  pawWatch
//
//  Purpose: Manages interactive WatchConnectivity messaging and reachability monitoring
//           for real-time location updates between Apple Watch and iPhone.
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

// MARK: - Sendable Wrapper for Dictionary

/// Wraps [String: Any] to make it Sendable for cross-concurrency boundaries.
/// Safe because WatchConnectivity framework guarantees thread-safe delivery.
private struct SendableDictionary: @unchecked Sendable {
    let dictionary: [String: Any]

    init(_ dictionary: [String: Any]) {
        self.dictionary = dictionary
    }
}

// MARK: - Connectivity Log Helper

enum ConnectivityLog {
    private static let logger = Logger(subsystem: PawWatchLog.subsystem, category: "WatchConnectivity")
#if DEBUG
    private static let isVerbose = ProcessInfo.processInfo.environment["PAWWATCH_VERBOSE_WC_LOGS"] == "1"
#else
    private static let isVerbose = false
#endif

    static func verbose(_ message: @autoclosure @escaping () -> String) {
        guard isVerbose else { return }
        logger.log("\(message())")
    }

    static func notice(_ message: @autoclosure @escaping () -> String) {
        logger.notice("\(message())")
    }

    static func error(_ message: @autoclosure @escaping () -> String) {
        logger.error("\(message())")
    }
}

// MARK: - Connectivity Relay Delegate

@MainActor
protocol WatchConnectivityRelayDelegate: AnyObject, Sendable {
    /// Called when session activation completes
    func relayDidActivateSession(_ relay: WatchConnectivityRelay)

    /// Called when session activation fails
    func relay(_ relay: WatchConnectivityRelay, didFailActivationWith error: Error)

    /// Called when reachability changes (debounced)
    func relay(_ relay: WatchConnectivityRelay, didUpdateReachability isReachable: Bool)

    /// Called when interactive message send succeeds
    func relay(_ relay: WatchConnectivityRelay, didSendInteractiveMessage message: [String: Any])

    /// Called when interactive message send fails
    func relay(_ relay: WatchConnectivityRelay, didFailInteractiveMessage error: Error)

    /// Called when application context update succeeds
    func relayDidUpdateApplicationContext(_ relay: WatchConnectivityRelay)

    /// Called when incoming message is received from iPhone
    func relay(_ relay: WatchConnectivityRelay, didReceiveMessage message: [String: Any]) -> [String: Any]

    /// Called when file transfer completes (success or failure)
    func relay(_ relay: WatchConnectivityRelay, didFinishFileTransfer transfer: WCSessionFileTransfer, error: Error?)
}

// MARK: - Watch Connectivity Relay

/// Manages WatchConnectivity session for interactive messaging and reachability.
///
/// Responsibilities:
/// - Activate and monitor WCSession
/// - Send interactive messages when reachable
/// - Update application context with throttling
/// - Debounce reachability changes
/// - Handle incoming messages from iPhone
/// - Retry activation on failure
@MainActor
final class WatchConnectivityRelay: NSObject {

    // MARK: - Properties

    weak var delegate: WatchConnectivityRelayDelegate?

    private var wcSession: WCSession { WCSession.default }
    private let encoder = JSONEncoder()

    private let logger = Logger(subsystem: PawWatchLog.subsystem, category: "WatchConnectivityRelay")

    /// Application context throttle: 0.5s allows ~2Hz max
    private let contextPushInterval: TimeInterval = 0.5

    /// Timestamp of last application context push
    private var lastContextPushDate: Date?

    /// Last horizontal accuracy sent via context for bypass logic
    private var lastContextAccuracy: Double?

    /// Accuracy bypass threshold: 5 meters
    private let contextAccuracyDelta: Double = 5.0

    /// Minimum interval between interactive sends
    private let interactiveSendInterval: TimeInterval = 2.0

    /// Last time we attempted an interactive send
    private var lastInteractiveSendDate: Date?

    /// Accuracy from last interactive send
    private var lastInteractiveAccuracy: Double?

    /// Required accuracy delta to bypass interactive throttle
    private let interactiveAccuracyDelta: Double = 10.0

    // MARK: - Reachability Debouncing

    /// Task for debouncing reachability changes
    private var reachabilityDebounceTask: Task<Void, Never>?

    /// Last reported reachability state
    private var lastReportedReachability: Bool?

    /// Debounce interval for reachability changes
    private let reachabilityDebounceInterval: TimeInterval = 2.5

    // MARK: - Activation Retry

    /// Task for retrying session activation
    private var activationRetryTask: Task<Void, Never>?

    /// Tracks consecutive activation retry attempts
    private var activationRetryCount = 0

    /// Maximum activation retry attempts
    private let maxActivationRetries = 10

    // MARK: - Public Properties

    var isReachable: Bool {
        wcSession.isReachable
    }

    var isCompanionAppInstalled: Bool {
        wcSession.isCompanionAppInstalled
    }

    var activationState: WCSessionActivationState {
        wcSession.activationState
    }

    // MARK: - Initialization

    override init() {
        super.init()
        encoder.outputFormatting = [.withoutEscapingSlashes]
    }

    // MARK: - Session Management

    /// Activates WatchConnectivity session
    func activate() {
        guard WCSession.isSupported() else {
            ConnectivityLog.error("WatchConnectivity not supported")
            return
        }

        // Prevent duplicate initialization
        if wcSession.delegate != nil, wcSession.activationState == .activated {
            ConnectivityLog.verbose("WCSession already configured and active")
            return
        }

        wcSession.delegate = self
        wcSession.activate()
        ConnectivityLog.notice("WCSession.activate() called")
        scheduleActivationRetry(reason: "initial-activation")
    }

    /// Schedules activation retry with exponential backoff
    private func scheduleActivationRetry(reason: String, delay: TimeInterval = 2.0) {
        activationRetryTask?.cancel()
        activationRetryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self else { return }

            // Persistent activation monitor
            while !Task.isCancelled && self.wcSession.activationState != .activated {
                self.activationRetryCount += 1

                if self.activationRetryCount <= self.maxActivationRetries {
                    ConnectivityLog.notice("Retrying WCSession.activate() attempt \(self.activationRetryCount)/\(self.maxActivationRetries) (\(reason))")
                    self.wcSession.activate()
                } else {
                    ConnectivityLog.notice("Max activation retries reached, waiting before next batch")
                    try? await Task.sleep(for: .seconds(30))
                    self.activationRetryCount = 0
                    continue
                }

                try? await Task.sleep(for: .seconds(5))
            }

            if self.wcSession.activationState == .activated {
                self.activationRetryCount = 0
                ConnectivityLog.notice("WCSession activation succeeded after retries")
            }
        }
    }

    /// Cancels activation retry task
    func cancelActivationRetry() {
        activationRetryTask?.cancel()
        activationRetryTask = nil
    }

    // MARK: - Interactive Messaging

    /// Sends interactive message when reachable
    func sendInteractiveMessage(_ message: [String: Any]) {
        guard wcSession.activationState == .activated else {
            ConnectivityLog.verbose("Session not activated, skipping interactive send")
            return
        }

        guard wcSession.isReachable else {
            ConnectivityLog.verbose("Phone not reachable, skipping interactive send")
            return
        }

        ConnectivityLog.verbose("Sending interactive message")
        wcSession.sendMessage(message, replyHandler: nil) { [weak self] error in
            guard let self else { return }
            ConnectivityLog.notice("Interactive send failed: \(error.localizedDescription)")
            Task { @MainActor in
                self.delegate?.relay(self, didFailInteractiveMessage: error)
            }
        }

        Task { @MainActor in
            self.delegate?.relay(self, didSendInteractiveMessage: message)
        }
    }

    /// Determines if interactive send should be attempted based on throttling
    func shouldSendInteractive(horizontalAccuracy: Double) -> Bool {
        let now = Date()

        // Bypass throttle if accuracy changed significantly
        if let lastAccuracy = lastInteractiveAccuracy,
           abs(lastAccuracy - horizontalAccuracy) >= interactiveAccuracyDelta {
            lastInteractiveSendDate = now
            lastInteractiveAccuracy = horizontalAccuracy
            return true
        }

        // Check time-based throttle
        if let lastSend = lastInteractiveSendDate,
           now.timeIntervalSince(lastSend) < interactiveSendInterval {
            return false
        }

        lastInteractiveSendDate = now
        lastInteractiveAccuracy = horizontalAccuracy
        return true
    }

    // MARK: - Application Context

    /// Updates application context with throttling and accuracy bypass
    func updateApplicationContext(_ context: [String: Any], accuracy: Double? = nil) throws {
        guard wcSession.activationState == .activated else {
            ConnectivityLog.verbose("Session not activated, skipping context update")
            return
        }

        let now = Date()

        // Check accuracy bypass if provided
        if let accuracy, let lastAccuracy = lastContextAccuracy {
            if abs(accuracy - lastAccuracy) >= contextAccuracyDelta {
                // Accuracy changed significantly, bypass throttle
                try wcSession.updateApplicationContext(context)
                lastContextPushDate = now
                lastContextAccuracy = accuracy
                ConnectivityLog.verbose("Context updated (accuracy bypass)")
                return
            }
        }

        // Check time-based throttle
        if let lastPush = lastContextPushDate,
           now.timeIntervalSince(lastPush) < contextPushInterval {
            ConnectivityLog.verbose("Context update throttled")
            return
        }

        try wcSession.updateApplicationContext(context)
        lastContextPushDate = now
        if let accuracy {
            lastContextAccuracy = accuracy
        }

        ConnectivityLog.verbose("Context updated")
        delegate?.relayDidUpdateApplicationContext(self)
    }

    // MARK: - Reachability Debouncing

    /// Handles reachability change with debouncing
    private func handleReachabilityChange(_ isReachable: Bool) {
        reachabilityDebounceTask?.cancel()

        // If same as last reported, ignore
        if let lastReported = lastReportedReachability, lastReported == isReachable {
            return
        }

        reachabilityDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.reachabilityDebounceInterval ?? 2.5))
            guard let self, !Task.isCancelled else { return }

            // Verify reachability hasn't changed during debounce
            let currentReachability = self.wcSession.isReachable
            if currentReachability == isReachable {
                self.lastReportedReachability = isReachable
                self.logger.log("Reachability stabilized: \(isReachable ? "reachable" : "unreachable")")
                self.delegate?.relay(self, didUpdateReachability: isReachable)
            } else {
                // Reachability flipped during debounce - restart
                self.handleReachabilityChange(currentReachability)
            }
        }
    }

    /// Cancels reachability debounce task
    func cancelReachabilityDebounce() {
        reachabilityDebounceTask?.cancel()
        reachabilityDebounceTask = nil
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityRelay: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let stateValue = activationState.rawValue
        let errorDesc = error?.localizedDescription
        let isCompanionInstalled = session.isCompanionAppInstalled

        Task { @MainActor [weak self] in
            guard let self else { return }

            ConnectivityLog.verbose("WCSession activation completed with state=\(stateValue) error=\(errorDesc ?? "none") companionInstalled=\(isCompanionInstalled)")

            #if DEBUG
            let diagnostic: [String: Any] = [
                ConnectivityConstants.diagnostic: "watch_activated",
                ConnectivityConstants.activationState: stateValue,
                ConnectivityConstants.isCompanionAppInstalled: isCompanionInstalled,
                ConnectivityConstants.timestamp: Date().timeIntervalSince1970,
                ConnectivityConstants.error: errorDesc ?? "none"
            ]

            if session.isReachable {
                session.sendMessage(diagnostic, replyHandler: nil) { error in
                    ConnectivityLog.verbose("Failed to send activation diagnostic: \(error.localizedDescription)")
                }
            } else {
                _ = session.transferUserInfo(diagnostic)
            }
            #endif

            if let error {
                self.delegate?.relay(self, didFailActivationWith: error)
                self.scheduleActivationRetry(reason: "activation-error")
            } else if !isCompanionInstalled {
                self.scheduleActivationRetry(reason: "companion-missing")
            } else {
                self.delegate?.relayDidActivateSession(self)
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let newReachability = session.isReachable
        ConnectivityLog.verbose("Reachability changed → \(newReachability)")

        Task { @MainActor [weak self] in
            self?.handleReachabilityChange(newReachability)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let wrapped = SendableDictionary(message)
        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = self.delegate?.relay(self, didReceiveMessage: wrapped.dictionary)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping @Sendable ([String: Any]) -> Void
    ) {
        let wrapped = SendableDictionary(message)
        Task { @MainActor [weak self] in
            guard let self else {
                replyHandler(["status": "error"])
                return
            }
            let response = self.delegate?.relay(self, didReceiveMessage: wrapped.dictionary) ?? ["status": "no-delegate"]
            replyHandler(response)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        // Not used in current implementation
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        let wrapped = SendableDictionary(userInfo)
        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = self.delegate?.relay(self, didReceiveMessage: wrapped.dictionary)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String : Any]
    ) {
        let wrapped = SendableDictionary(applicationContext)
        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = self.delegate?.relay(self, didReceiveMessage: wrapped.dictionary)
        }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // Not used for Watch → iPhone flow
    }

    nonisolated func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.delegate?.relay(self, didFinishFileTransfer: fileTransfer, error: error)
        }
    }
}

#endif
