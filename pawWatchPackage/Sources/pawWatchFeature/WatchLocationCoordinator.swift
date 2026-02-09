//
//  WatchLocationCoordinator.swift
//  pawWatch
//
//  Purpose: Orchestrates GPS capture, connectivity relay, file transfers, and CloudKit
//           uploads for pet location tracking on Apple Watch.
//
//  Extracted from WatchLocationProvider.swift as part of architectural refactoring.
//  This is the main public API that coordinates all the specialized managers.
//
//  Author: Refactored for modular architecture
//  Created: 2025-02-09
//  Swift: 6.2
//  Platform: watchOS 26.1+
//

import Foundation
#if os(watchOS)
@preconcurrency import CoreLocation
@preconcurrency import WatchConnectivity
@preconcurrency import WatchKit
@preconcurrency import HealthKit
import OSLog

// MARK: - Tracking Mode

enum WatchTrackingMode: String {
    case auto
    case emergency
    case balanced
    case saver

    func preset(for automatic: TrackingPreset) -> TrackingPreset {
        switch self {
        case .auto:
            return automatic
        case .emergency:
            return .aggressive
        case .balanced:
            return .balanced
        case .saver:
            return .saver
        }
    }
}

// MARK: - Connectivity Issue Errors

public enum WatchConnectivityIssue: LocalizedError {
    case sessionNotActivated
    case interactiveSendFailed(underlying: Error)
    case fileEncodingFailed(underlying: Error)
    case fileTransferFailed(underlying: Error)
    case locationAuthorizationDenied

    public var errorDescription: String? {
        switch self {
        case .sessionNotActivated:
            return "WatchConnectivity session is not active."
        case .interactiveSendFailed(let error):
            return "Live update failed: \(error.localizedDescription)"
        case .fileEncodingFailed(let error):
            return "Unable to queue background update: \(error.localizedDescription)"
        case .fileTransferFailed(let error):
            return "Background transfer failed: \(error.localizedDescription)"
        case .locationAuthorizationDenied:
            return "Location permission denied. Please enable in Settings."
        }
    }
}

// MARK: - Extended Runtime Coordinator

@MainActor
private final class ExtendedRuntimeCoordinator: NSObject, WKExtendedRuntimeSessionDelegate {
    private let logger = Logger(subsystem: PawWatchLog.subsystem, category: "ExtendedRuntime")
    private let signposter = OSSignposter(subsystem: PawWatchLog.subsystem, category: "ExtendedRuntime")
    private var session: WKExtendedRuntimeSession?
    private var restartTask: Task<Void, Never>?
    private var intervalState: OSSignpostIntervalState?

    var isEnabled: Bool = false {
        didSet {
            if !isEnabled {
                stop()
            }
        }
    }

    private var shouldGuardTracking = false

    func updateTrackingState(isRunning: Bool) {
        shouldGuardTracking = isRunning
        if isRunning {
            beginIfNeeded(reason: "TrackingActive")
        } else {
            stop()
        }
    }

    func beginIfNeeded(reason: StaticString) {
        guard isEnabled, shouldGuardTracking, session == nil else { return }

        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        session = newSession

        intervalState = signposter.beginInterval("ExtendedRuntime")
        logger.log("Starting extended runtime session (reason: \(String(describing: reason)))")
        newSession.start()
    }

    func stop() {
        restartTask?.cancel()
        restartTask = nil
        if let state = intervalState {
            signposter.endInterval("ExtendedRuntime", state)
        }
        intervalState = nil
        session?.invalidate()
        session = nil
    }

    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in
            self.logger.log("Extended runtime session started")
            self.signposter.emitEvent("ExtendedRuntimeDidStart")
        }
    }

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in
            self.logger.log("Extended runtime session nearing expiration")
            self.signposter.emitEvent("ExtendedRuntimeWillExpire")
        }
    }

    nonisolated func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: (any Error)?) {
        Task { @MainActor in
            self.handleInvalidation(reason: reason, error: error)
        }
    }

    nonisolated func extendedRuntimeSessionDidInvalidate(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in
            self.handleInvalidation(reason: nil, error: nil)
        }
    }

    @MainActor
    private func handleInvalidation(reason: WKExtendedRuntimeSessionInvalidationReason?, error: (any Error)?) {
        if let reason {
            logger.log("Extended runtime invalidated (reason: \(reason.rawValue))")
        } else {
            logger.log("Extended runtime session invalidated")
        }

        if let error {
            logger.error("Extended runtime error: \(error.localizedDescription)")
        }

        if let state = intervalState {
            signposter.endInterval("ExtendedRuntime", state)
        }
        intervalState = nil
        session = nil

        guard isEnabled, shouldGuardTracking else { return }

        restartTask?.cancel()
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard let self else { return }
            await MainActor.run {
                self.beginIfNeeded(reason: "RearmAfterInvalidation")
            }
        }
    }
}

// MARK: - Coordinator Delegate Protocol

@MainActor
public protocol WatchLocationProviderDelegate: AnyObject, Sendable {
    func didProduce(_ fix: LocationFix)
    func didFail(_ error: Error)
    func didReceiveRemoteStop()
    func didUpdateReachability(_ isReachable: Bool)
}

public extension WatchLocationProviderDelegate {
    func didReceiveRemoteStop() {}
    func didUpdateReachability(_ isReachable: Bool) {}
}

// MARK: - Watch Location Coordinator

/// Coordinates GPS capture, WatchConnectivity relay, file transfers, and CloudKit uploads.
///
/// This is the main public API for location tracking on Apple Watch. It orchestrates
/// multiple specialized managers to provide robust, multi-path location relay.
@MainActor
public final class WatchLocationProvider: NSObject {

    // MARK: - Public Properties

    public weak var delegate: (any WatchLocationProviderDelegate)?

    public var isReachable: Bool {
        connectivityRelay.isReachable
    }

    public var isCompanionAppInstalled: Bool {
        connectivityRelay.isCompanionAppInstalled
    }

    public var currentTrackingModeRaw: String {
        manualTrackingMode.rawValue
    }

    // MARK: - Private Properties - Managers

    private let gpsManager = WatchGPSManager()
    private let connectivityRelay = WatchConnectivityRelay()
    private let fileQueue = WatchFileTransferQueue()
    private let cloudKitRelay = WatchCloudKitRelay()

    // MARK: - Private Properties - State

    private let logger = Logger(subsystem: PawWatchLog.subsystem, category: "WatchLocationProvider")
    private let signposter = OSSignposter(subsystem: PawWatchLog.subsystem, category: "WatchLocationProvider")
    private var trackingIntervalState: OSSignpostIntervalState?

    private let runtimeCoordinator = ExtendedRuntimeCoordinator()
    private static let runtimePreferenceKey = RuntimePreferenceKey.runtimeOptimizationsEnabled
    private lazy var supportsExtendedRuntime: Bool = {
        RuntimeCapabilities.supportsExtendedRuntime
    }()

    private var latestFix: LocationFix?
    private var batteryOptimizationsEnabled = WatchLocationProvider.loadRuntimePreference()
    private var isWorkoutRunning = false
    private var latestBatteryLevel: Double = 1.0
    private var manualTrackingMode: WatchTrackingMode = .auto
    private var forceImmediateSend = false

    // MARK: - Persistence Keys

    private static let isWorkoutRunningKey = "watchIsWorkoutRunningPersisted"
    private static let isIntentionallyStoppedKey = "watchIntentionallyStoppedPersisted"
    private var isIntentionallyStopped = false

    // MARK: - Heartbeat and Watchdog

    private var batteryHeartbeatTask: Task<Void, Never>?
    private var minUpdateWatchdogTask: Task<Void, Never>?

    private var idleHeartbeatInterval: TimeInterval = 30.0
    private var stationaryUpdateInterval: TimeInterval = 180.0
    private var maxUpdateInterval: TimeInterval = 180.0
    private static let idleHeartbeatDefaultsKey = "watchIdleHeartbeatInterval"
    private static let idleFullFixDefaultsKey = "watchIdleFullFixInterval"

    // MARK: - Adaptive Throttling

    private var lastKnownLocation: CLLocation?
    private var lastMovementTime: Date = .distantPast
    private let stationaryThresholdMeters: CLLocationDistance = 5.0
    private let stationaryTimeThreshold: TimeInterval = 30
    private var lastTransmittedFixDate: Date = .distantPast
    private var lastThrottleAccuracy: Double = .infinity
    private let contextPushInterval: TimeInterval = 0.5
    private let contextAccuracyDelta: Double = 5.0

    // MARK: - Performance Monitoring

    private let performanceMonitor = PerformanceMonitor.shared

    // MARK: - Thermal Management

    private var thermalDegradationLevel = 0
    private var thermalRecoveryTask: Task<Void, Never>?
    private let thermalRecoveryPollInterval: TimeInterval = 30

    // MARK: - Restart Tracking

    private var restartAttemptCount = 0
    private let maxRestartAttempts = 5
    private var workoutRestartTask: Task<Void, Never>?

    // MARK: - Lock State

    private var isTrackerLocked = false

    // MARK: - Initialization

    public override init() {
        super.init()
        setupManagers()
        loadIdleCadenceDefaults()
        loadTrackingStatePersistence()
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        runtimeCoordinator.isEnabled = supportsExtendedRuntime && batteryOptimizationsEnabled

        if !supportsExtendedRuntime {
            logger.log("Extended runtime disabled (capability unavailable)")
        }

        // Initialize WatchConnectivity immediately
        Task { @MainActor in
            self.connectivityRelay.activate()
        }

        // Check crash recovery
        if isWorkoutRunning && !isIntentionallyStopped {
            logger.notice("Detected crash recovery: tracking was active before termination")
        }
    }

    private func setupManagers() {
        gpsManager.delegate = self
        connectivityRelay.delegate = self
        fileQueue.delegate = self
        cloudKitRelay.delegate = self
    }

    // MARK: - Public Methods

    public func startWorkoutAndStreaming(activity: HKWorkoutActivityType = .other) {
        isIntentionallyStopped = false
        thermalDegradationLevel = 0
        thermalRecoveryTask?.cancel()
        thermalRecoveryTask = nil
        resetRestartCounter()

        gpsManager.requestAuthorization()

        do {
            try gpsManager.startWorkoutSession(activity: activity)
        } catch {
            delegate?.didFail(error)
        }

        Task { @MainActor in
            self.connectivityRelay.activate()
        }

        gpsManager.applyPreset(.aggressive, force: true)

        isWorkoutRunning = true
        persistTrackingState()

        if supportsExtendedRuntime {
            runtimeCoordinator.updateTrackingState(isRunning: true)
        }

        startBatteryHeartbeat()
        startMinUpdateWatchdog()

        trackingIntervalState = signposter.beginInterval("TrackingSession")
        logger.log("Workout tracking started with optimizations=\(self.batteryOptimizationsEnabled, privacy: .public)")
    }

    public func stop() {
        isIntentionallyStopped = true
        isWorkoutRunning = false
        persistTrackingState()

        workoutRestartTask?.cancel()
        workoutRestartTask = nil
        thermalRecoveryTask?.cancel()
        thermalRecoveryTask = nil
        thermalDegradationLevel = 0

        connectivityRelay.cancelReachabilityDebounce()
        connectivityRelay.cancelActivationRetry()

        gpsManager.stopUpdatingLocation()
        gpsManager.stopWorkoutSession()

        fileQueue.clearAll()

        if let state = trackingIntervalState {
            signposter.endInterval("TrackingSession", state)
        }
        trackingIntervalState = nil

        if supportsExtendedRuntime {
            runtimeCoordinator.updateTrackingState(isRunning: false)
        }

        isWorkoutRunning = false
        stopBatteryHeartbeat()
        stopMinUpdateWatchdog()

        logger.log("Workout tracking stopped")
    }

    public func setBatteryOptimizationsEnabled(_ enabled: Bool) {
        batteryOptimizationsEnabled = enabled
        runtimeCoordinator.isEnabled = supportsExtendedRuntime && enabled
        persistRuntimePreference(enabled)

        if enabled {
            if supportsExtendedRuntime, isWorkoutRunning {
                runtimeCoordinator.updateTrackingState(isRunning: true)
            }
        } else {
            if supportsExtendedRuntime {
                runtimeCoordinator.updateTrackingState(isRunning: false)
            }
            gpsManager.applyPreset(.aggressive)
        }

        sendBatteryHeartbeat()
    }

    public func restoreWatchTrackingMode(from rawValue: String) {
        guard let mode = WatchTrackingMode(rawValue: rawValue) else { return }
        manualTrackingMode = mode
    }

    @MainActor
    public func setTrackerLocked(_ locked: Bool) {
        guard locked != isTrackerLocked else { return }
        isTrackerLocked = locked
        broadcastLockState()
    }

    // MARK: - Private Methods - Persistence

    private static func loadRuntimePreference() -> Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: runtimePreferenceKey) == nil {
            defaults.set(true, forKey: runtimePreferenceKey)
            return true
        }
        return defaults.bool(forKey: runtimePreferenceKey)
    }

    private func persistRuntimePreference(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.runtimePreferenceKey)
    }

    private func loadTrackingStatePersistence() {
        let defaults = UserDefaults.standard
        isWorkoutRunning = defaults.bool(forKey: Self.isWorkoutRunningKey)
        isIntentionallyStopped = defaults.bool(forKey: Self.isIntentionallyStoppedKey)
        if isWorkoutRunning {
            logger.log("Loaded persisted state: isWorkoutRunning=\(self.isWorkoutRunning), isIntentionallyStopped=\(self.isIntentionallyStopped)")
        }
    }

    private func persistTrackingState() {
        let defaults = UserDefaults.standard
        defaults.set(isWorkoutRunning, forKey: Self.isWorkoutRunningKey)
        defaults.set(isIntentionallyStopped, forKey: Self.isIntentionallyStoppedKey)
    }

    private func loadIdleCadenceDefaults() {
        let defaults = UserDefaults.standard
        let storedHeartbeat = defaults.double(forKey: Self.idleHeartbeatDefaultsKey)
        let storedFullFix = defaults.double(forKey: Self.idleFullFixDefaultsKey)

        if storedHeartbeat > 0, storedFullFix > 0 {
            idleHeartbeatInterval = storedHeartbeat
            stationaryUpdateInterval = storedFullFix
            maxUpdateInterval = storedFullFix
        } else {
            idleHeartbeatInterval = 30.0
            stationaryUpdateInterval = 180.0
            maxUpdateInterval = 180.0
        }
    }

    // MARK: - Private Methods - Publishing

    private func publishFix(_ fix: LocationFix) {
        latestFix = fix
        if batteryOptimizationsEnabled {
            updateAdaptiveTuning(with: fix)
        }
        signposter.emitEvent("FixPublished")

        let timeSinceLast = Date().timeIntervalSince(lastTransmittedFixDate)
        let isHeartbeat = timeSinceLast >= stationaryUpdateInterval
        let updateType = isHeartbeat ? "heartbeat" : "update"
        logger.debug("Publishing fix seq=\(fix.sequence) accuracy=\(fix.horizontalAccuracyMeters, privacy: .public) [\(updateType)]")

        transmitFix(fix, notifyDelegate: true)
    }

    private func transmitFix(_ fix: LocationFix, notifyDelegate: Bool) {
        if notifyDelegate {
            Task { @MainActor in
                delegate?.didProduce(fix)
            }
        }

        cloudKitRelay.uploadFixIfNeeded(fix, phoneReachable: connectivityRelay.isReachable)

        guard connectivityRelay.activationState == .activated else {
            ConnectivityLog.verbose("WCSession not activated; skipping transmit")
            delegate?.didFail(WatchConnectivityIssue.sessionNotActivated)
            return
        }

        let enqueueBackground: () -> Void = { [weak self] in
            self?.fileQueue.enqueueFix(fix)
        }

        if connectivityRelay.isReachable, connectivityRelay.shouldSendInteractive(horizontalAccuracy: fix.horizontalAccuracyMeters) {
            guard let data = try? JSONEncoder().encode(fix) else {
                ConnectivityLog.error("Failed to encode fix for interactive send")
                delegate?.didFail(WatchConnectivityIssue.fileEncodingFailed(underlying: CocoaError(.coderInvalidValue)))
                return
            }

            let payload: [String: Any] = [ConnectivityConstants.latestFix: data]
            connectivityRelay.sendInteractiveMessage(payload)

            if fileQueue.pendingFixCount > 0 {
                fileQueue.flushPendingFixes()
            }
        } else {
            ConnectivityLog.verbose("Phone unreachable or debounced; queuing batched transfer")
            enqueueBackground()
        }
    }

    private func updateAdaptiveTuning(with fix: LocationFix) {
        guard batteryOptimizationsEnabled else { return }

        let battery = fix.batteryFraction
        let speed = fix.speedMetersPerSecond

        let preset: TrackingPreset
        if battery < 0.2 {
            preset = .saver
        } else if speed < 0.5 {
            preset = .balanced
        } else {
            preset = .aggressive
        }

        let effective = manualTrackingMode.preset(for: preset)
        gpsManager.applyPreset(effective)
    }

    // MARK: - Private Methods - Heartbeat & Watchdog

    private func startBatteryHeartbeat() {
        batteryHeartbeatTask?.cancel()
        batteryHeartbeatTask = Task { [weak self] in
            guard let self else { return }
            await MainActor.run { self.sendBatteryHeartbeat() }
            while !Task.isCancelled {
                let interval = await MainActor.run { self.idleHeartbeatInterval }
                try? await Task.sleep(for: .seconds(interval))
                await MainActor.run { self.sendBatteryHeartbeat() }
            }
        }
    }

    private func stopBatteryHeartbeat() {
        batteryHeartbeatTask?.cancel()
        batteryHeartbeatTask = nil
    }

    @MainActor
    private func sendBatteryHeartbeat() {
        guard connectivityRelay.activationState == .activated else { return }
        do {
            var context = runtimeContextMetadata()
            context[ConnectivityConstants.batteryOnly] = latestBatteryLevel
            context[ConnectivityConstants.trackingMode] = manualTrackingMode.rawValue
            context[ConnectivityConstants.lockState] = isTrackerLocked
            try connectivityRelay.updateApplicationContext(context)
            let avg = Int(self.performanceMonitor.gpsAverage * 1000)
            let drainAvg = String(format: "%.1f", self.performanceMonitor.batteryDrainPerHour)
            let drainInstant = String(format: "%.1f", self.performanceMonitor.batteryDrainPerHourInstant)
            logger.log("Heartbeat sent (battery=\(Int(self.latestBatteryLevel * 100))%, gpsAvg=\(avg)ms, drainAvg=\(drainAvg)%/h, drainInst=\(drainInstant)%/h)")
        } catch {
            logger.error("Heartbeat update failed: \(error.localizedDescription)")
        }
    }

    private func startMinUpdateWatchdog() {
        minUpdateWatchdogTask?.cancel()
        minUpdateWatchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self else { return }
                await MainActor.run {
                    self.checkAndForceUpdateIfStale()
                }
            }
        }
    }

    private func stopMinUpdateWatchdog() {
        minUpdateWatchdogTask?.cancel()
        minUpdateWatchdogTask = nil
    }

    @MainActor
    private func checkAndForceUpdateIfStale() {
        guard isWorkoutRunning else { return }

        let timeSinceLast = Date().timeIntervalSince(lastTransmittedFixDate)
        let threshold: TimeInterval = max(10.0, maxUpdateInterval)

        if timeSinceLast >= threshold {
            logger.notice("Watchdog triggered: \(Int(timeSinceLast))s since last update, forcing refresh")

            if let fix = latestFix, Date().timeIntervalSince(fix.timestamp) < 120 {
                transmitFix(fix, notifyDelegate: false)
            } else {
                gpsManager.requestLocation()
            }
        }
    }

    // MARK: - Private Methods - Helpers

    private func runtimeContextMetadata() -> [String: Any] {
        [
            ConnectivityConstants.runtimeOptimizationsEnabled: batteryOptimizationsEnabled,
            ConnectivityConstants.supportsExtendedRuntime: supportsExtendedRuntime,
            ConnectivityConstants.idleHeartbeatInterval: idleHeartbeatInterval,
            ConnectivityConstants.idleFullFixInterval: stationaryUpdateInterval
        ]
    }

    @MainActor
    private func broadcastLockState() {
        guard connectivityRelay.activationState == .activated else { return }
        do {
            try connectivityRelay.updateApplicationContext([
                ConnectivityConstants.lockState: isTrackerLocked
            ])
            logger.log("Lock state context sent (locked=\(self.isTrackerLocked))")
        } catch {
            logger.error("Failed to send lock state: \(error.localizedDescription)")
        }
    }

    private func isDeviceStationary(_ location: CLLocation) -> Bool {
        guard let lastLocation = lastKnownLocation else { return false }

        let distance = location.distance(from: lastLocation)
        if distance < stationaryThresholdMeters {
            let timeSinceMovement = Date().timeIntervalSince(lastMovementTime)
            return timeSinceMovement > stationaryTimeThreshold
        } else {
            lastMovementTime = Date()
            return false
        }
    }

    private func shouldThrottleUpdate(location: CLLocation, isStationary: Bool, batteryLevel: Double) -> Bool {
        if forceImmediateSend {
            forceImmediateSend = false
            return false
        }

        let now = Date()
        let timeSinceLast = now.timeIntervalSince(lastTransmittedFixDate)

        // Emergency mode: fixed cadence
        if manualTrackingMode == .emergency {
            let emergencyInterval = max(10.0, maxUpdateInterval)
            if timeSinceLast >= emergencyInterval {
                lastTransmittedFixDate = now
                lastThrottleAccuracy = location.horizontalAccuracy
                return false
            }
            return true
        }

        // Max interval check
        if timeSinceLast >= maxUpdateInterval {
            lastTransmittedFixDate = now
            lastThrottleAccuracy = location.horizontalAccuracy
            return false
        }

        // Critical battery protection
        if batteryLevel <= 0.10 {
            let criticalThrottle: TimeInterval = 5.0
            if timeSinceLast < criticalThrottle {
                return true
            }
            lastTransmittedFixDate = now
            lastThrottleAccuracy = location.horizontalAccuracy
            return false
        }

        // Accuracy bypass
        let accuracyChange = abs(location.horizontalAccuracy - lastThrottleAccuracy)
        if accuracyChange > contextAccuracyDelta {
            lastTransmittedFixDate = now
            lastThrottleAccuracy = location.horizontalAccuracy
            return false
        }

        // Time-based throttle
        let throttleInterval: TimeInterval
        if batteryLevel <= 0.20 {
            throttleInterval = isStationary ? 5.0 : 3.0
        } else if isStationary {
            throttleInterval = stationaryUpdateInterval
        } else {
            throttleInterval = contextPushInterval
        }

        if timeSinceLast < throttleInterval {
            return true
        }

        lastTransmittedFixDate = now
        lastThrottleAccuracy = location.horizontalAccuracy
        return false
    }

    private func resetRestartCounter() {
        restartAttemptCount = 0
    }

    @MainActor
    private func applyIdleCadence(heartbeat rawHeartbeat: TimeInterval, fullFix rawFullFix: TimeInterval, persist: Bool = true) {
        let heartbeat = max(5, min(300, rawHeartbeat))
        let fullFix = max(10, min(600, rawFullFix))
        idleHeartbeatInterval = heartbeat
        stationaryUpdateInterval = fullFix
        maxUpdateInterval = fullFix
        lastTransmittedFixDate = .distantPast

        if persist {
            persistIdleCadence(heartbeat: heartbeat, fullFix: fullFix)
        }

        if batteryHeartbeatTask != nil {
            startBatteryHeartbeat()
        }

        logger.log("Idle cadence updated (heartbeat=\(heartbeat)s, fullFix=\(fullFix)s, maxUpdate=\(self.maxUpdateInterval)s)")
    }

    private func persistIdleCadence(heartbeat: TimeInterval, fullFix: TimeInterval) {
        let defaults = UserDefaults.standard
        defaults.set(heartbeat, forKey: Self.idleHeartbeatDefaultsKey)
        defaults.set(fullFix, forKey: Self.idleFullFixDefaultsKey)
    }

    @MainActor
    private func applyTrackingModeChange(to newMode: WatchTrackingMode, heartbeat: Double?, fullFix: Double?) {
        let previousMode = manualTrackingMode
        manualTrackingMode = newMode
        forceImmediateSend = true
        logger.log("Tracking mode changed: \(previousMode.rawValue) → \(newMode.rawValue)")

        if newMode == .emergency {
            cloudKitRelay.resetThrottle()

            let resolvedHeartbeat = max(5.0, min(300.0, heartbeat ?? 30.0))
            let resolvedFullFix = max(10.0, min(600.0, fullFix ?? 60.0))

            applyIdleCadence(heartbeat: resolvedHeartbeat, fullFix: resolvedFullFix, persist: false)
            gpsManager.applyPreset(.aggressive, force: true)
            cloudKitRelay.setEmergencyMode(true)
            logger.notice("Emergency mode enabled (heartbeat=\(resolvedHeartbeat)s, fullFix=\(resolvedFullFix)s)")
        } else if previousMode == .emergency {
            loadIdleCadenceDefaults()
            cloudKitRelay.setEmergencyMode(false)
            logger.notice("Emergency mode disabled; restored persisted idle cadence defaults")
        }

        if let fix = latestFix, Date().timeIntervalSince(fix.timestamp) < 30 {
            transmitFix(fix, notifyDelegate: false)
        } else {
            gpsManager.requestLocation()
        }

        sendBatteryHeartbeat()
    }
}

// MARK: - WatchGPSManagerDelegate

extension WatchLocationProvider: WatchGPSManagerDelegate {

    func gpsManager(_ manager: WatchGPSManager, didUpdateLocation location: CLLocation) {
        // Thermal guard
        let thermalState = ProcessInfo.processInfo.thermalState
        if thermalState == .critical {
            if thermalDegradationLevel < 2 {
                thermalDegradationLevel = 2
                logger.error("Thermal CRITICAL - stopping tracking")
                stopTrackingForThermalCritical()
            }
            return
        } else if thermalState == .serious {
            if thermalDegradationLevel < 1 {
                thermalDegradationLevel = 1
                logger.warning("Thermal SERIOUS - degrading to saver mode")
                gpsManager.applyPreset(.saver, force: true)
            }
        } else if thermalDegradationLevel > 0 {
            handleThermalRecovery(reason: "location-update")
        }

        let device = WKInterfaceDevice.current()
        let batteryLevel = device.batteryLevel >= 0 ? Double(device.batteryLevel) : latestBatteryLevel
        latestBatteryLevel = batteryLevel
        performanceMonitor.recordBattery(level: batteryLevel)

        if batteryOptimizationsEnabled {
            let stationary = isDeviceStationary(location)
            if shouldThrottleUpdate(location: location, isStationary: stationary, batteryLevel: batteryLevel) {
                let timeSinceLast = Date().timeIntervalSince(lastTransmittedFixDate)
                let nextInterval = stationary ? stationaryUpdateInterval : contextPushInterval
                let timeUntilNext = max(0, nextInterval - timeSinceLast)
                logger.debug("Throttling fix (stationary=\(stationary), battery=\(Int(batteryLevel * 100))%, next in \(Int(timeUntilNext))s)")
                return
            }
            lastKnownLocation = location
        }

        let fix = LocationFix(
            timestamp: location.timestamp,
            source: .watchOS,
            coordinate: .init(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ),
            altitudeMeters: location.verticalAccuracy >= 0 ? location.altitude : nil,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            verticalAccuracyMeters: max(location.verticalAccuracy, 0),
            speedMetersPerSecond: max(location.speed, 0),
            courseDegrees: location.course >= 0 ? location.course : 0,
            headingDegrees: nil,
            batteryFraction: batteryLevel,
            sequence: Int(Int64(Date().timeIntervalSinceReferenceDate * 1000) % Int64(Int.max)),
            trackingPreset: batteryOptimizationsEnabled ? gpsManager.currentPreset.rawValue : nil
        )
        performanceMonitor.recordGPSLatency(Date().timeIntervalSince(location.timestamp))
        publishFix(fix)
    }

    func gpsManager(_ manager: WatchGPSManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            if isWorkoutRunning {
                logger.log("Location authorized - starting updates")
                gpsManager.startUpdatingLocation()
            }
        case .denied, .restricted:
            logger.error("Location permission denied")
            delegate?.didFail(WatchConnectivityIssue.locationAuthorizationDenied)
        case .notDetermined:
            gpsManager.requestAuthorization()
        @unknown default:
            break
        }
    }

    func gpsManager(_ manager: WatchGPSManager, didFailWithError error: Error) {
        delegate?.didFail(error)
    }

    func gpsManager(_ manager: WatchGPSManager, workoutDidChangeTo state: HKWorkoutSessionState) {
        logger.log("Workout session state changed to: \(state.rawValue)")

        guard state == .ended || state == .stopped else { return }

        if !isIntentionallyStopped && isWorkoutRunning {
            logger.log("Workout session ended unexpectedly - scheduling auto-restart")
            scheduleWorkoutRestart()
        }
    }

    @MainActor
    private func scheduleWorkoutRestart() {
        workoutRestartTask?.cancel()

        if restartAttemptCount >= maxRestartAttempts {
            logger.error("Auto-restart aborted: exceeded max attempts (\(self.maxRestartAttempts))")
            isIntentionallyStopped = true
            isWorkoutRunning = false
            delegate?.didFail(WatchConnectivityIssue.sessionNotActivated)
            return
        }

        let backoffSeconds = 3.0 * pow(2.0, Double(restartAttemptCount))
        restartAttemptCount += 1

        logger.log("Scheduling workout restart attempt \(self.restartAttemptCount)/\(self.maxRestartAttempts) in \(Int(backoffSeconds))s")

        workoutRestartTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(backoffSeconds))
            guard let self, !Task.isCancelled else { return }
            guard !self.isIntentionallyStopped else {
                self.logger.log("Auto-restart cancelled - tracking was intentionally stopped")
                self.restartAttemptCount = 0
                return
            }

            self.logger.log("Auto-restarting workout session (attempt \(self.restartAttemptCount))")

            do {
                try self.gpsManager.startWorkoutSession(activity: .other)
                self.gpsManager.startUpdatingLocation()
                self.logger.log("Workout session auto-restart complete")
            } catch {
                self.logger.error("Workout restart failed: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func stopTrackingForThermalCritical() {
        isIntentionallyStopped = true
        isWorkoutRunning = false
        persistTrackingState()

        workoutRestartTask?.cancel()
        workoutRestartTask = nil
        thermalRecoveryTask?.cancel()
        thermalRecoveryTask = nil

        connectivityRelay.cancelReachabilityDebounce()
        connectivityRelay.cancelActivationRetry()

        gpsManager.stopUpdatingLocation()
        gpsManager.stopWorkoutSession()

        fileQueue.clearAll()

        if let state = trackingIntervalState {
            signposter.endInterval("TrackingSession", state)
        }
        trackingIntervalState = nil

        if supportsExtendedRuntime {
            runtimeCoordinator.updateTrackingState(isRunning: false)
        }
        stopBatteryHeartbeat()
        stopMinUpdateWatchdog()

        logger.log("Workout tracking stopped (thermal critical)")
        startThermalRecoveryMonitorIfNeeded()
    }

    private func startThermalRecoveryMonitorIfNeeded() {
        guard thermalDegradationLevel == 2 else { return }
        guard thermalRecoveryTask == nil else { return }

        thermalRecoveryTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self.thermalRecoveryPollInterval))
                guard !Task.isCancelled else { break }

                let state = ProcessInfo.processInfo.thermalState
                if state != .critical && state != .serious {
                    self.handleThermalRecovery(reason: "poll")
                    break
                }
            }

            self.thermalRecoveryTask = nil
        }
    }

    private func handleThermalRecovery(reason: String) {
        guard thermalDegradationLevel > 0 else { return }

        let wasFullyStopped = thermalDegradationLevel == 2
        logger.notice("Thermal recovered (\(reason, privacy: .public)) from level \(self.thermalDegradationLevel, privacy: .public)")

        thermalDegradationLevel = 0
        isIntentionallyStopped = false
        thermalRecoveryTask?.cancel()
        thermalRecoveryTask = nil

        restorePresetAfterThermalRecovery()

        if wasFullyStopped {
            restartAfterThermalCriticalRecovery()
        }
    }

    private func restorePresetAfterThermalRecovery() {
        if batteryOptimizationsEnabled {
            let battery = latestBatteryLevel
            if battery < 0.1 {
                gpsManager.applyPreset(.saver)
            } else if battery < 0.2 {
                gpsManager.applyPreset(.balanced)
            } else {
                gpsManager.applyPreset(.aggressive)
            }
        } else {
            gpsManager.applyPreset(.aggressive)
        }
    }

    private func restartAfterThermalCriticalRecovery() {
        logger.notice("Restarting tracking after thermal recovery")

        resetRestartCounter()
        forceImmediateSend = true
        lastTransmittedFixDate = .distantPast

        do {
            try gpsManager.startWorkoutSession(activity: .other)
        } catch {
            logger.error("Failed to restart workout: \(error.localizedDescription)")
            delegate?.didFail(error)
            return
        }

        let auth = gpsManager.authorizationStatus
        switch auth {
        case .authorizedAlways, .authorizedWhenInUse:
            gpsManager.startUpdatingLocation()
        case .notDetermined:
            gpsManager.requestAuthorization()
        case .denied, .restricted:
            logger.error("Thermal recovery restart blocked: permission denied")
            delegate?.didFail(WatchConnectivityIssue.locationAuthorizationDenied)
            return
        @unknown default:
            break
        }

        isWorkoutRunning = true
        persistTrackingState()

        if supportsExtendedRuntime {
            runtimeCoordinator.updateTrackingState(isRunning: true)
        }
        startBatteryHeartbeat()
        startMinUpdateWatchdog()
        trackingIntervalState = signposter.beginInterval("TrackingSession")
    }
}

// MARK: - WatchConnectivityRelayDelegate

extension WatchLocationProvider: WatchConnectivityRelayDelegate {

    func relayDidActivateSession(_ relay: WatchConnectivityRelay) {
        logger.log("WatchConnectivity session activated")
    }

    func relay(_ relay: WatchConnectivityRelay, didFailActivationWith error: Error) {
        delegate?.didFail(error)
    }

    func relay(_ relay: WatchConnectivityRelay, didUpdateReachability isReachable: Bool) {
        delegate?.didUpdateReachability(isReachable)
    }

    func relay(_ relay: WatchConnectivityRelay, didSendInteractiveMessage message: [String: Any]) {
        ConnectivityLog.verbose("Interactive message sent successfully")
    }

    func relay(_ relay: WatchConnectivityRelay, didFailInteractiveMessage error: Error) {
        delegate?.didFail(WatchConnectivityIssue.interactiveSendFailed(underlying: error))
    }

    func relayDidUpdateApplicationContext(_ relay: WatchConnectivityRelay) {
        ConnectivityLog.verbose("Application context updated")
    }

    func relay(_ relay: WatchConnectivityRelay, didFinishFileTransfer transfer: WCSessionFileTransfer, error: Error?) {
        fileQueue.handleTransferCompletion(transfer, error: error)
    }

    func relay(_ relay: WatchConnectivityRelay, didReceiveMessage message: [String: Any]) -> [String: Any] {
        guard let action = message[ConnectivityConstants.action] as? String else {
            return ["status": "ignored"]
        }

        switch action {
        case ConnectivityConstants.requestLocation:
            let force = (message[ConnectivityConstants.force] as? Bool) == true
            Task { @MainActor in
                if force {
                    self.forceImmediateSend = true
                }
                if let fix = self.latestFix {
                    self.transmitFix(fix, notifyDelegate: false)
                } else {
                    self.gpsManager.requestLocation()
                }
            }
            return ["status": "refreshing"]

        case ConnectivityConstants.setMode:
            if let modeRaw = message[ConnectivityConstants.mode] as? String,
               let newMode = WatchTrackingMode(rawValue: modeRaw) {
                let heartbeat = message[ConnectivityConstants.heartbeatInterval] as? Double
                let fullFix = message[ConnectivityConstants.fullFixInterval] as? Double
                Task { @MainActor in
                    self.applyTrackingModeChange(to: newMode, heartbeat: heartbeat, fullFix: fullFix)
                }
                return ["status": "mode-updated"]
            }
            return ["status": "mode-invalid"]

        case ConnectivityConstants.setRuntimeOptimizations:
            guard let enabled = message[ConnectivityConstants.enabled] as? Bool else {
                return ["status": "runtime-invalid"]
            }
            Task { @MainActor in
                self.setBatteryOptimizationsEnabled(enabled)
            }
            return ["status": "runtime-updated", "enabled": enabled]

        case ConnectivityConstants.setIdleCadence:
            guard
                let heartbeat = message[ConnectivityConstants.heartbeatInterval] as? Double,
                let fullFix = message[ConnectivityConstants.fullFixInterval] as? Double
            else {
                return ["status": "idle-invalid"]
            }
            Task { @MainActor in
                self.applyIdleCadence(heartbeat: heartbeat, fullFix: fullFix)
                self.sendBatteryHeartbeat()
            }
            return ["status": "idle-updated"]

        case ConnectivityConstants.stopTracking:
            Task { @MainActor in
                self.delegate?.didReceiveRemoteStop()
                self.stop()
            }
            return ["status": "stop-requested"]

        case ConnectivityConstants.setPetProfile:
            guard let data = message[ConnectivityConstants.petProfile] as? Data else {
                return ["status": "pet-profile-invalid"]
            }
            Task { @MainActor in
                let ok = PetProfileStore.shared.applyRemoteProfileData(data)
                self.logger.log("Pet profile update received (ok=\(ok))")
            }
            return ["status": "pet-profile-updated"]

        case ConnectivityConstants.pingWatch:
            Task { @MainActor in
                WKInterfaceDevice.current().play(.notification)
            }
            return ["status": "pinged"]

        default:
            return ["status": "unknown-action"]
        }
    }
}

// MARK: - WatchFileTransferQueueDelegate

extension WatchLocationProvider: WatchFileTransferQueueDelegate {

    func fileQueue(_ queue: WatchFileTransferQueue, didFlushBatch count: Int, seqRange: ClosedRange<Int>) {
        logger.log("Batched transfer flushed: \(count) fixes (seqs: \(seqRange.lowerBound)-\(seqRange.upperBound))")
    }

    func fileQueue(_ queue: WatchFileTransferQueue, didCompleteTransfer fix: LocationFix) {
        logger.log("File transfer completed for seq=\(fix.sequence)")
    }

    func fileQueue(_ queue: WatchFileTransferQueue, didFailTransfer fix: LocationFix, error: Error) {
        delegate?.didFail(WatchConnectivityIssue.fileTransferFailed(underlying: error))
    }

    func fileQueue(_ queue: WatchFileTransferQueue, didFailEncoding error: Error) {
        delegate?.didFail(WatchConnectivityIssue.fileEncodingFailed(underlying: error))
    }
}

// MARK: - WatchCloudKitRelayDelegate

extension WatchLocationProvider: WatchCloudKitRelayDelegate {

    func cloudKitRelay(_ relay: WatchCloudKitRelay, didUploadFix fix: LocationFix) {
        logger.log("Emergency CloudKit upload completed for seq=\(fix.sequence)")
    }

    func cloudKitRelay(_ relay: WatchCloudKitRelay, didFailUpload error: Error) {
        logger.error("Emergency CloudKit upload failed: \(error.localizedDescription)")
    }
}

#else

// MARK: - Non-watchOS Stub Implementation

@MainActor
public protocol WatchLocationProviderDelegate: AnyObject, Sendable {
    func didProduce(_ fix: LocationFix)
    func didFail(_ error: Error)
}

@MainActor
public final class WatchLocationProvider {
    public weak var delegate: (any WatchLocationProviderDelegate)?

    public init() {}

    public func startWorkoutAndStreaming(activity: Int = 0) {
        assertionFailure("WatchLocationProvider is only available on watchOS")
    }

    public func stop() {}
}

#endif
