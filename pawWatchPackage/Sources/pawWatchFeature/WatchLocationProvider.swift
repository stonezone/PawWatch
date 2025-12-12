//
//  WatchLocationProvider.swift
//  pawWatch
//
//  Purpose: Manages workout-driven GPS capture on Apple Watch with triple-path
//           WatchConnectivity messaging (interactive, context, file transfer).
//           Provides maximum-frequency location updates (~1Hz native Watch GPS)
//           with 0.5s application context throttle for efficient phone relay.
//
//  Author: Adapted from gps-relay-framework for pawWatch
//  Created: 2025-11-05
//  Swift: 6.2
//  Platform: watchOS 26.1+
//

import Foundation
#if os(watchOS)
@preconcurrency import CoreLocation
@preconcurrency import HealthKit
@preconcurrency import WatchConnectivity
@preconcurrency import WatchKit
import OSLog

// MARK: - Adaptive Tracking Preset

private enum TrackingPreset: String {
    case aggressive
    case balanced
    case saver

    var desiredAccuracy: CLLocationAccuracy {
        switch self {
        case .aggressive:
            return kCLLocationAccuracyBest
        case .balanced:
            return 15.0
        case .saver:
            return 50.0
        }
    }

    var distanceFilter: CLLocationDistance {
        switch self {
        case .aggressive:
            return kCLDistanceFilterNone
        case .balanced:
            return 25.0
        case .saver:
            return 75.0
        }
    }

    var activityType: CLActivityType {
        switch self {
        case .aggressive:
            return .other
        case .balanced:
            return .fitness
        case .saver:
            return .other
        }
    }
}

private enum TrackingMode: String {
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

private enum ConnectivityLog {
    private static let logger = Logger(subsystem: "com.stonezone.pawWatch", category: "WatchConnectivity")
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

// MARK: - Extended Runtime Coordinator

@MainActor
private final class ExtendedRuntimeCoordinator: NSObject, WKExtendedRuntimeSessionDelegate {
    private let logger = Logger(subsystem: "com.stonezone.pawWatch", category: "ExtendedRuntime")
    private let signposter = OSSignposter(subsystem: "com.stonezone.pawWatch", category: "ExtendedRuntime")
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

// MARK: - Delegate Protocol

/// Delegate protocol for receiving location fixes and error notifications.
/// All callbacks occur on arbitrary threads - implement thread-safe handling.
@MainActor
public protocol WatchLocationProviderDelegate: AnyObject, Sendable {
    /// Called when a new location fix is produced.
    /// - Parameter fix: The location fix containing GPS data and metadata
    func didProduce(_ fix: LocationFix)
    
    /// Called when an error occurs during location capture or relay.
    /// - Parameter error: The error that occurred
    func didFail(_ error: Error)

    /// Called when the paired iPhone requests the watch to stop tracking.
    func didReceiveRemoteStop()

    /// Called whenever WatchConnectivity reachability changes.
    /// - Parameter isReachable: True when the paired iPhone is reachable for interactive messaging.
    func didUpdateReachability(_ isReachable: Bool)
}

public extension WatchLocationProviderDelegate {
    func didReceiveRemoteStop() {}
    func didUpdateReachability(_ isReachable: Bool) {}
}

// MARK: - Main Provider Class

/// Manages workout-driven location capture on watchOS and relays fixes to iPhone.
///
/// Key Features:
/// - Uses HealthKit workout session for extended runtime and background GPS
/// - Triple-path WatchConnectivity messaging for reliability:
///   1. Interactive messages (foreground, immediate, requires reachability)
///   2. Application context (background, latest-only, 0.5s throttle)
///   3. File transfer (background, queued, guaranteed delivery)
/// - 0.5s application context throttle: Allows ~2Hz max update rate to phone
///   while capturing all Watch GPS fixes at native ~1Hz rate
/// - Accuracy bypass: Immediate context update when horizontal accuracy changes >5m
///
/// GPS Configuration:
/// - activityType: .other (provides most frequent updates)
/// - desiredAccuracy: kCLLocationAccuracyBest (best available GPS precision)
/// - distanceFilter: kCLDistanceFilterNone (no distance-based throttling)
/// - Update frequency: ~1Hz native Apple Watch GPS rate
///
@MainActor
public final class WatchLocationProvider: NSObject {
    
    // MARK: - Public Properties
    
    public weak var delegate: (any WatchLocationProviderDelegate)?

    /// Proxy for WCSession reachability (thread-safe access to session)
    public var isReachable: Bool {
        wcSession.isReachable
    }

    /// Proxy for WCSession companion app installation state
    public var isCompanionAppInstalled: Bool {
        wcSession.isCompanionAppInstalled
    }
    
    // MARK: - Private Properties
    
    private let workoutStore = HKHealthStore()
    private let locationManager = CLLocationManager()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var wcSession: WCSession { WCSession.default }
    private let encoder = JSONEncoder()
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.stonezone.pawWatch", category: "WatchLocationProvider")
    private let signposter = OSSignposter(subsystem: "com.stonezone.pawWatch", category: "WatchLocationProvider")
    private var trackingIntervalState: OSSignpostIntervalState?
    private let runtimeCoordinator = ExtendedRuntimeCoordinator()
    private static let runtimePreferenceKey = RuntimePreferenceKey.runtimeOptimizationsEnabled
    private lazy var supportsExtendedRuntime: Bool = {
        RuntimeCapabilities.supportsExtendedRuntime
    }()
    
    /// Tracks last sequence number sent via application context to prevent duplicates
    private var lastContextSequence: Int?

    /// Timestamp of last application context push for throttling
    private var lastContextPushDate: Date?
    
    /// Last horizontal accuracy sent via application context for bypass logic
    private var lastContextAccuracy: Double?
    
    /// Application context throttle: 0.5s allows ~2Hz max (within Apple's 1-2Hz recommendation)
    /// while capturing all Watch GPS fixes (~1Hz). This ensures the phone receives updates
    /// at a reasonable rate without overwhelming the WatchConnectivity context mechanism.
    /// Original value: 10.0s - reduced to 0.5s for real-time pet tracking needs.
    private let contextPushInterval: TimeInterval = 0.5

    /// When stationary, send updates at reduced but still frequent rate for pet tracking.
    /// 180s ensures owner gets periodic confirmations without burning battery.
    private var stationaryUpdateInterval: TimeInterval = 180.0

    /// Maximum time between any location updates, regardless of movement state.
    /// Used by the throttling stack to guarantee a periodic fix even if the pet is stationary.
    private var maxUpdateInterval: TimeInterval = 180.0

    /// Interval between battery-only heartbeat contexts when idle.
    /// 30s provides periodic connectivity confirmation without excessive churn.
    private var idleHeartbeatInterval: TimeInterval = 30.0

    private static let idleHeartbeatDefaultsKey = "watchIdleHeartbeatInterval"
    private static let idleFullFixDefaultsKey = "watchIdleFullFixInterval"

    // MARK: - Crash Recovery Persistence Keys
    private static let isWorkoutRunningKey = "watchIsWorkoutRunningPersisted"
    private static let isIntentionallyStoppedKey = "watchIntentionallyStoppedPersisted"

    // MARK: - Batching Properties (Queue Flooding Prevention)
    /// Buffer to accumulate GPS fixes when phone is unreachable.
    private var pendingFixes: [LocationFix] = []
    /// Maximum fixes to batch before flushing (prevents queue flooding).
    private let batchThreshold = 60
    /// Maximum time before flushing batch regardless of count.
    private let batchFlushInterval: TimeInterval = 60.0
    /// Last time we flushed the batch buffer.
    private var lastBatchFlushDate: Date = .distantPast

    // MARK: - Emergency Cloud Relay

    /// Throttle CloudKit writes during emergency relay to avoid rate limiting and excess battery usage.
    private var lastEmergencyCloudRelayDate: Date = .distantPast
    private let emergencyCloudRelayInterval: TimeInterval = 60.0

    /// Accuracy bypass threshold: When horizontal accuracy changes by more than 5 meters,
    /// immediately push application context regardless of time throttle. This ensures
    /// critical accuracy improvements (e.g., GPS lock acquisition) are delivered promptly.
    private let contextAccuracyDelta: Double = 5.0  // meters

    /// Minimum interval between interactive sendMessage attempts.
    private let interactiveSendInterval: TimeInterval = 2.0

    /// Required accuracy delta to bypass the interactive throttle (meters).
    private let interactiveAccuracyDelta: Double = 10.0

    /// Last time we attempted an interactive send.
    private var lastInteractiveSendDate: Date?

    /// Accuracy value from the last interactive send.
    private var lastInteractiveAccuracy: Double?

    /// Controls whether file transfers are used as a fallback path.
    private let fileTransfersEnabled = true
    
    /// Tracks active file transfers to retry on failure and clean up temp files
    private var activeFileTransfers: [WCSessionFileTransfer: (url: URL, fix: LocationFix)] = [:]

    /// Most recent fix, used to satisfy manual refresh requests from the phone.
    private let performanceMonitor = PerformanceMonitor.shared
    private var latestFix: LocationFix?
    private var batteryOptimizationsEnabled = WatchLocationProvider.loadRuntimePreference()
    private var currentPreset: TrackingPreset = .aggressive
    private var isWorkoutRunning = false
    private var latestBatteryLevel: Double = 1.0
    private var manualTrackingMode: TrackingMode = .auto
    private var forceImmediateSend = false

    /// Exposes the current tracking mode for persistence on the Watch side.
    public var currentTrackingModeRaw: String {
        manualTrackingMode.rawValue
    }

    /// Restores the tracking mode from a persisted raw value, if valid.
    public func restoreTrackingMode(from rawValue: String) {
        guard let mode = TrackingMode(rawValue: rawValue) else { return }
        manualTrackingMode = mode
    }
    private var batteryHeartbeatTask: Task<Void, Never>?
    private var minUpdateWatchdogTask: Task<Void, Never>?
    private var isTrackerLocked = false
    private var activationRetryTask: Task<Void, Never>?

    /// Tracks consecutive activation retry attempts
    private var activationRetryCount = 0

    /// Maximum activation retry attempts before giving up temporarily
    private let maxActivationRetries = 10

    // MARK: - Resilience Properties

    /// Task for debouncing reachability changes (prevents UI churn from Bluetooth flapping)
    private var reachabilityDebounceTask: Task<Void, Never>?

    /// Last known reachability state for debounce comparison
    private var lastReportedReachability: Bool?

    /// Debounce interval for reachability changes (seconds)
    private let reachabilityDebounceInterval: TimeInterval = 2.5

    /// Task for auto-restarting workout session after unexpected termination
    private var workoutRestartTask: Task<Void, Never>?

    /// Tracks whether tracking was intentionally stopped (vs unexpected termination)
    private var isIntentionallyStopped = false

    /// CR-001 FIX: Tracks consecutive restart attempts to prevent infinite loops
    private var restartAttemptCount = 0

    /// CR-001 FIX: Maximum restart attempts before giving up (prevents infinite loop)
    private let maxRestartAttempts = 5

    /// Current thermal degradation level (0 = normal, 1 = degraded, 2 = stopped)
    private var thermalDegradationLevel = 0

    // MARK: - Adaptive throttling state

    private var lastKnownLocation: CLLocation?
    private var lastMovementTime: Date = .distantPast
    private let stationaryThresholdMeters: CLLocationDistance = 5.0
    private let stationaryTimeThreshold: TimeInterval = 30
    private var lastTransmittedFixDate: Date = .distantPast
    private var lastThrottleAccuracy: Double = .infinity

    private static func loadRuntimePreference() -> Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: runtimePreferenceKey) == nil {
            defaults.set(true, forKey: runtimePreferenceKey)
            // MODERATE FIX: Removed deprecated synchronize() - UserDefaults auto-syncs
            return true
        }
        return defaults.bool(forKey: runtimePreferenceKey)
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
            // Default cadence (non-emergency): battery-friendly, "every few minutes" stationary updates.
            idleHeartbeatInterval = 30.0
            stationaryUpdateInterval = 180.0
            maxUpdateInterval = 180.0
        }
    }
    
    // MARK: - Initialization

    public override init() {
        super.init()
        loadIdleCadenceDefaults()
        loadTrackingStatePersistence()  // CRASH RECOVERY: Load persisted state
        locationManager.delegate = self
        encoder.outputFormatting = [.withoutEscapingSlashes]
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        runtimeCoordinator.isEnabled = supportsExtendedRuntime && batteryOptimizationsEnabled
        if !supportsExtendedRuntime {
            logger.log("Extended runtime disabled (capability unavailable)")
        }

        // Initialize WatchConnectivity immediately on app launch
        // This ensures the iPhone can detect the Watch app without waiting for user interaction
        Task { @MainActor in
            self.configureWatchConnectivity()
        }

        // CRASH RECOVERY: Check if tracking was active before crash/reboot
        if isWorkoutRunning && !isIntentionallyStopped {
            logger.notice("Detected crash recovery: tracking was active before termination")
            // Notify delegate of crash recovery state - actual restart handled by delegate
        }
    }

    // MARK: - Tracking State Persistence (Crash Recovery)

    /// Load persisted tracking state for crash recovery
    private func loadTrackingStatePersistence() {
        let defaults = UserDefaults.standard
        isWorkoutRunning = defaults.bool(forKey: Self.isWorkoutRunningKey)
        isIntentionallyStopped = defaults.bool(forKey: Self.isIntentionallyStoppedKey)
        if isWorkoutRunning {
            logger.log("Loaded persisted state: isWorkoutRunning=\(self.isWorkoutRunning), isIntentionallyStopped=\(self.isIntentionallyStopped)")
        }
    }

    /// Persist tracking state immediately for crash recovery
    private func persistTrackingState() {
        let defaults = UserDefaults.standard
        defaults.set(isWorkoutRunning, forKey: Self.isWorkoutRunningKey)
        defaults.set(isIntentionallyStopped, forKey: Self.isIntentionallyStoppedKey)
        // Note: UserDefaults auto-syncs, no synchronize() needed
    }
    
    // MARK: - Public Methods
    
    /// Starts a HealthKit workout session and begins streaming GPS locations.
    ///
    /// This method:
    /// 1. Requests HealthKit and location permissions
    /// 2. Starts a workout session for extended runtime
    /// 3. Configures WatchConnectivity for phone relay
    /// 4. Starts high-frequency GPS updates
    ///
    /// - Parameter activity: The workout activity type (default: .other for max update frequency)
    public func startWorkoutAndStreaming(activity: HKWorkoutActivityType = .other) {
        // Reset intentional stop flag for new tracking session
        isIntentionallyStopped = false
        thermalDegradationLevel = 0
        resetRestartCounter()  // CR-001 FIX: Reset counter for fresh tracking session
        requestAuthorizationsIfNeeded()
        startWorkoutSession(activity: activity)
        Task { @MainActor in
            self.configureWatchConnectivity()
        }

        applyPreset(.aggressive, force: true)
        // CRITICAL FIX: Don't start updating until authorization is granted
        // startUpdatingLocation() will be called in locationManagerDidChangeAuthorization

        isWorkoutRunning = true
        persistTrackingState()  // CRASH RECOVERY: Persist state immediately
        if supportsExtendedRuntime {
            runtimeCoordinator.updateTrackingState(isRunning: true)
        }
        startBatteryHeartbeat()
        startMinUpdateWatchdog()

        trackingIntervalState = signposter.beginInterval("TrackingSession")
        logger.log("Workout tracking started with optimizations=\(self.batteryOptimizationsEnabled, privacy: .public)")
    }

    /// Enables or disables the extended runtime + adaptive throttling stack.
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
            applyPreset(.aggressive)
        }

        sendBatteryHeartbeat()
    }

    private func persistRuntimePreference(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.runtimePreferenceKey)
    }

    private func runtimeContextMetadata() -> [String: Any] {
        [
            ConnectivityConstants.runtimeOptimizationsEnabled: batteryOptimizationsEnabled,
            ConnectivityConstants.supportsExtendedRuntime: supportsExtendedRuntime,
            ConnectivityConstants.idleHeartbeatInterval: idleHeartbeatInterval,
            ConnectivityConstants.idleFullFixInterval: stationaryUpdateInterval
        ]
    }
    
    /// Stops location updates and ends the workout session.
    ///
    /// Cleans up:
    /// - Location manager updates
    /// - Active workout session
    /// - Workout builder collection
    /// - Application context throttle state
    /// - Active file transfers
    public func stop() {
        // Mark as intentional stop to prevent auto-restart
        isIntentionallyStopped = true
        isWorkoutRunning = false
        persistTrackingState()  // CRASH RECOVERY: Persist state immediately
        workoutRestartTask?.cancel()
        workoutRestartTask = nil
        reachabilityDebounceTask?.cancel()
        reachabilityDebounceTask = nil
        activationRetryTask?.cancel()
        thermalDegradationLevel = 0
        locationManager.stopUpdatingLocation()

        // Capture builder and session locally to avoid self reference issues
        let builder = self.workoutBuilder
        let session = self.workoutSession
        
        // Clear references immediately
        self.workoutSession = nil
        self.workoutBuilder = nil
        self.lastContextSequence = nil
        self.lastContextPushDate = nil
        self.lastContextAccuracy = nil
        self.activeFileTransfers.removeAll()
        
        // Clean up HealthKit objects asynchronously
        // endCollection and finishWorkout can be called after references are cleared
        if let builder {
            builder.endCollection(withEnd: Date()) { [weak delegate = self.delegate] _, error in
                if let error {
                    Task { @MainActor in
                        delegate?.didFail(error)
                    }
                }
                builder.finishWorkout { _, finishError in
                    if let finishError {
                        Task { @MainActor in
                            delegate?.didFail(finishError)
                        }
                    }
                }
            }
        }
        
        // End workout session if still active
        if let session, session.state == .running || session.state == .prepared {
            session.end()
        }

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

    /// Stops tracking due to a thermal critical event.
    ///
    /// Mirrors `stop()` cleanup but preserves `thermalDegradationLevel` so the
    /// thermal recovery path can restart tracking safely.
    @MainActor
    private func stopTrackingForThermalCritical() {
        isIntentionallyStopped = true
        isWorkoutRunning = false
        persistTrackingState()

        workoutRestartTask?.cancel()
        workoutRestartTask = nil
        reachabilityDebounceTask?.cancel()
        reachabilityDebounceTask = nil
        activationRetryTask?.cancel()
        activationRetryTask = nil

        locationManager.stopUpdatingLocation()

        let builder = workoutBuilder
        let session = workoutSession

        workoutSession = nil
        workoutBuilder = nil
        lastContextSequence = nil
        lastContextPushDate = nil
        lastContextAccuracy = nil
        activeFileTransfers.removeAll()

        if let builder {
            builder.endCollection(withEnd: Date()) { [weak delegate = self.delegate] _, error in
                if let error {
                    Task { @MainActor in
                        delegate?.didFail(error)
                    }
                }
                builder.finishWorkout { _, finishError in
                    if let finishError {
                        Task { @MainActor in
                            delegate?.didFail(finishError)
                        }
                    }
                }
            }
        }

        if let session, session.state == .running || session.state == .prepared {
            session.end()
        }

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
    }
    
    // MARK: - Private Methods - Authorization
    
    /// Requests HealthKit and location permissions if not already granted.
    private func requestAuthorizationsIfNeeded() {
        // Request HealthKit permissions for workout sessions and heart rate.
        var readTypes: Set<HKObjectType> = []
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(heartRate)
        }

        var shareTypes: Set<HKSampleType> = []
        shareTypes.insert(HKObjectType.workoutType())

        workoutStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
            if let error, success == false {
                Task { @MainActor [weak self] in
                    self?.delegate?.didFail(error)
                }
            }
        }

        // Request location permission for GPS during workout
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Private Methods - Workout Session
    
    /// Starts a HealthKit workout session for extended runtime and background GPS.
    ///
    /// The workout session:
    /// - Keeps the app active in background
    /// - Enables continuous GPS updates
    /// - Provides workout metadata (duration, calories, etc.)
    ///
    /// - Parameter activity: The workout activity type
    private func startWorkoutSession(activity: HKWorkoutActivityType) {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activity
        configuration.locationType = .outdoor

        if let existingSession = workoutSession,
           existingSession.state == .running || existingSession.state == .prepared {
            logger.log("Workout session already active; skipping start")
            return
        }
        
        do {
            let session = try HKWorkoutSession(healthStore: workoutStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: workoutStore,
                workoutConfiguration: configuration
            )
            
            session.delegate = self
            builder.delegate = self
            
            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { [weak delegate = self.delegate] _, error in
                if let error {
                    Task { @MainActor in
                        delegate?.didFail(error)
                    }
                }
            }
            
            workoutSession = session
            workoutBuilder = builder
        } catch {
            Task { @MainActor in
                delegate?.didFail(error)
            }
        }
    }
    
    // MARK: - Private Methods - WatchConnectivity
    
    /// Configures and activates WatchConnectivity session for phone relay.
    @MainActor
    private func configureWatchConnectivity() {
        ConnectivityLog.verbose("Configuring WCSession")

        // Prevent duplicate initialization when already activated.
        if wcSession.delegate != nil, wcSession.activationState == .activated {
            ConnectivityLog.verbose("WCSession already configured and active; skipping")
            return
        }

        guard WCSession.isSupported() else {
            ConnectivityLog.error("WatchConnectivity not supported on this device")
            return
        }

        wcSession.delegate = self
        wcSession.activate()
        ConnectivityLog.notice("WCSession.activate() called")
        scheduleActivationRetry(reason: "initial-activation")
    }
    
    @MainActor
    private func scheduleActivationRetry(reason: String, delay: TimeInterval = 2.0) {
        activationRetryTask?.cancel()
        activationRetryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self else { return }

            // Persistent activation monitor - keeps trying until activated or max retries
            while !Task.isCancelled && self.wcSession.activationState != .activated {
                self.activationRetryCount += 1

                if self.activationRetryCount <= self.maxActivationRetries {
                    ConnectivityLog.notice("Retrying WCSession.activate() attempt \(self.activationRetryCount)/\(self.maxActivationRetries) (\(reason))")
                    self.wcSession.activate()
                } else {
                    ConnectivityLog.notice("Max activation retries reached (\(self.maxActivationRetries)), waiting before next batch")
                    // Wait longer before next retry batch
                    try? await Task.sleep(for: .seconds(30))
                    self.activationRetryCount = 0  // Reset for next batch
                    continue
                }

                // Wait 5 seconds between attempts
                try? await Task.sleep(for: .seconds(5))
            }

            // Reset counter on successful activation
            if self.wcSession.activationState == .activated {
                self.activationRetryCount = 0
                ConnectivityLog.notice("WCSession activation succeeded after retries")
            }
        }
    }
    
    /// Publishes a location fix using a lossless path:
    /// 1. `sendMessage` when reachable (fast path)
    /// 2. Batched `transferUserInfo` when unreachable (survives background)
    /// 3. `transferFile` as a background fallback when reachability is false or sendMessage fails
    /// ApplicationContext is **not** used for full fixes (latest-only would drop history).
    ///
    /// - Parameter fix: The location fix to publish
    private func publishFix(_ fix: LocationFix) {
        latestFix = fix
        if batteryOptimizationsEnabled {
            updateAdaptiveTuning(with: fix)
        }
        signposter.emitEvent("FixPublished")

        // Log whether this is a stationary heartbeat or movement update
        let timeSinceLast = Date().timeIntervalSince(lastTransmittedFixDate)
        let isHeartbeat = timeSinceLast >= stationaryUpdateInterval
        let updateType = isHeartbeat ? "heartbeat" : "update"
        logger.debug("Publishing fix seq=\(fix.sequence) accuracy=\(fix.horizontalAccuracyMeters, privacy: .public) [\(updateType)]")

        transmitFix(fix, notifyDelegate: true)
    }

    /// Sends the provided fix to the paired iPhone and enqueues background delivery.
    private func transmitFix(
        _ fix: LocationFix,
        notifyDelegate: Bool
    ) {
        if notifyDelegate {
            Task { @MainActor in
                delegate?.didProduce(fix)
            }
        }

        ConnectivityLog.verbose("WCSession state=\(self.wcSession.activationState.rawValue) reachable=\(self.wcSession.isReachable)")

        maybeUploadEmergencyFixToCloud(fix)

        guard wcSession.activationState == .activated else {
            ConnectivityLog.verbose("WCSession not activated; skipping transmit")
            notifyConnectivityError(.sessionNotActivated)
            return
        }

        let enqueueBackground: () -> Void = { [weak self] in
            self?.enqueueForBatch(fix)
        }

        if wcSession.isReachable, shouldSendInteractive(for: fix) {
            // Interactive path: send immediately via sendMessage and fall back to batched queue on failure.
            guard let data = try? encoder.encode(fix) else {
                ConnectivityLog.error("Failed to encode fix for interactive send")
                Task { @MainActor in
                    delegate?.didFail(WatchConnectivityIssue.fileEncodingFailed(underlying: CocoaError(.coderInvalidValue)))
                }
                return
            }

            ConnectivityLog.verbose("Sending interactive message (\(data.count) bytes)")
            let payload: [String: Any] = [ConnectivityConstants.latestFix: data]
            wcSession.sendMessage(payload, replyHandler: nil) { [weak self] error in
                ConnectivityLog.notice("Interactive send failed: \(error.localizedDescription)")
                self?.notifyConnectivityError(.interactiveSendFailed(underlying: error))
                enqueueBackground()
            }

            // If we just regained connectivity, flush any offline backlog immediately.
            if !pendingFixes.isEmpty {
                flushPendingFixes()
            }
        } else {
            ConnectivityLog.verbose("Phone unreachable or debounced; queuing batched transfer")
            enqueueBackground()
        }
    }

    private func maybeUploadEmergencyFixToCloud(_ fix: LocationFix) {
        guard manualTrackingMode == .emergency else { return }

        let canReachPhone = wcSession.activationState == .activated && wcSession.isReachable
        guard !canReachPhone else { return }

        let now = Date()
        guard now.timeIntervalSince(lastEmergencyCloudRelayDate) >= emergencyCloudRelayInterval else { return }
        lastEmergencyCloudRelayDate = now

        logger.notice("Emergency relay: uploading fix seq=\(fix.sequence)")
        Task.detached(priority: .utility) {
            await CloudKitLocationSync.shared.saveLocation(fix)
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
        applyPreset(effective)
    }

    private func applyPreset(_ preset: TrackingPreset, force: Bool = false) {
        guard force || preset != currentPreset else { return }

        currentPreset = preset
        locationManager.activityType = preset.activityType
        locationManager.desiredAccuracy = preset.desiredAccuracy
        locationManager.distanceFilter = preset.distanceFilter

        logger.log("Applied preset=\(preset.rawValue, privacy: .public)")
        signposter.emitEvent("PresetChange")
    }

    /// Determines if an interactive `sendMessage` should be attempted.
    private func shouldSendInteractive(for fix: LocationFix) -> Bool {
        let now = Date()

        if let lastAccuracy = lastInteractiveAccuracy,
           abs(lastAccuracy - fix.horizontalAccuracyMeters) >= interactiveAccuracyDelta {
            lastInteractiveSendDate = now
            lastInteractiveAccuracy = fix.horizontalAccuracyMeters
            return true
        }

        if let lastSend = lastInteractiveSendDate,
           now.timeIntervalSince(lastSend) < interactiveSendInterval {
            return false
        }

        lastInteractiveSendDate = now
        lastInteractiveAccuracy = fix.horizontalAccuracyMeters
        return true
    }

    // MARK: - Lock state broadcast

    @MainActor
    public func setTrackerLocked(_ locked: Bool) {
        guard locked != isTrackerLocked else { return }
        isTrackerLocked = locked
        broadcastLockState()
    }

    @MainActor
    private func broadcastLockState() {
        guard wcSession.activationState == .activated else { return }
        do {
            try wcSession.updateApplicationContext([
                ConnectivityConstants.lockState: isTrackerLocked
            ])
            logger.log("Lock state context sent (locked=\(self.isTrackerLocked))")
        } catch {
            logger.error("Failed to send lock state: \(error.localizedDescription)")
        }
    }
    
    /// Enqueues a fix for batched background delivery using `transferUserInfo`.
    ///
    /// QUEUE FLOODING FIX: Instead of transferring each fix individually when unreachable,
    /// we buffer fixes and flush them in batches. This prevents overwhelming WCSession when
    /// the phone has been unreachable for extended periods (e.g., 1 hour = 3,600 fixes).
    private func enqueueForBatch(_ fix: LocationFix) {
        guard wcSession.activationState == .activated else { return }

        pendingFixes.append(fix)
        ConnectivityLog.verbose("Buffered fix seq=\(fix.sequence) (buffer count: \(self.pendingFixes.count))")

        let shouldFlush = pendingFixes.count >= batchThreshold ||
            Date().timeIntervalSince(lastBatchFlushDate) >= batchFlushInterval

        if shouldFlush {
            flushPendingFixes()
        }
    }

    /// Flushes buffered fixes as a single batched transfer.
    ///
    /// Sends all pending fixes in one `transferUserInfo` call using an encoded array of
    /// `LocationFix` values, dramatically reducing WCSession overhead versus per-fix calls.
    private func flushPendingFixes() {
        guard !pendingFixes.isEmpty else { return }
        guard wcSession.activationState == .activated else { return }

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
        } catch {
            ConnectivityLog.error("Failed to encode batched fixes: \(error.localizedDescription)")
        }
    }
    
    /// Queues a location fix for background file transfer to the phone.
    ///
    /// File transfer is used when:
    /// - Phone is not reachable (background)
    /// - Interactive message fails
    ///
    /// Provides guaranteed delivery with automatic retry on failure.
    ///
    /// - Parameter fix: The location fix to transfer
    private func queueBackgroundTransfer(for fix: LocationFix) {
        guard wcSession.activationState == .activated else { return }

        do {
            let data = try encoder.encode(fix)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try data.write(to: url)
            
            let transfer = wcSession.transferFile(url, metadata: [ConnectivityConstants.sequence: fix.sequence])
            activeFileTransfers[transfer] = (url, fix)
            
            ConnectivityLog.verbose("Queued file transfer for seq=\(fix.sequence)")
        } catch {
            notifyConnectivityError(.fileEncodingFailed(underlying: error))
        }
    }

    private func notifyConnectivityError(_ issue: WatchConnectivityIssue) {
        Task { @MainActor in
            delegate?.didFail(issue)
        }
    }

    // MARK: - Heartbeat + manual mode helpers

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

    // MARK: - Minimum Update Watchdog

    /// Starts a watchdog to guarantee periodic updates even if the normal flow stalls.
    /// Uses `maxUpdateInterval` in normal mode and a tighter threshold in emergency mode.
    private func startMinUpdateWatchdog() {
        minUpdateWatchdogTask?.cancel()
        minUpdateWatchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                // Check every 30 seconds
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

    /// If no update has been sent within the configured maximum interval, force a location request.
    @MainActor
    private func checkAndForceUpdateIfStale() {
        guard isWorkoutRunning else { return }

        let timeSinceLast = Date().timeIntervalSince(lastTransmittedFixDate)
        let threshold: TimeInterval = max(10.0, maxUpdateInterval)

        if timeSinceLast >= threshold {
            logger.notice("Watchdog triggered: \(Int(timeSinceLast))s since last update, forcing refresh")

            // If we have a recent fix, transmit it
            if let fix = latestFix, Date().timeIntervalSince(fix.timestamp) < 120 {
                transmitFix(fix, notifyDelegate: false)
            } else {
                // Request fresh location
                locationManager.requestLocation()
            }
        }
    }

    @MainActor
    private func sendBatteryHeartbeat() {
        guard wcSession.activationState == .activated else { return }
        do {
            var context = runtimeContextMetadata()
            context[ConnectivityConstants.batteryOnly] = latestBatteryLevel
            context[ConnectivityConstants.trackingMode] = manualTrackingMode.rawValue
            context[ConnectivityConstants.lockState] = isTrackerLocked
            try wcSession.updateApplicationContext(context)
            let avg = Int(self.performanceMonitor.gpsAverage * 1000)
            let drainAvg = String(format: "%.1f", self.performanceMonitor.batteryDrainPerHour)
            let drainInstant = String(format: "%.1f", self.performanceMonitor.batteryDrainPerHourInstant)
            logger.log("Heartbeat sent (battery=\(Int(self.latestBatteryLevel * 100))%, gpsAvg=\(avg)ms, drainAvg=\(drainAvg)%/h, drainInst=\(drainInstant)%/h)")
        } catch {
            logger.error("Heartbeat update failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func applyIdleCadence(heartbeat rawHeartbeat: TimeInterval, fullFix rawFullFix: TimeInterval, persist: Bool = true) {
        // Clamp heartbeat between 5s (emergency) and 300s
        // Allow 5s for emergency mode aggressive cadence
        let heartbeat = max(5, min(300, rawHeartbeat))
        // Clamp fullFix between 10s (emergency) and 600s for stationary interval
        let fullFix = max(10, min(600, rawFullFix))
        idleHeartbeatInterval = heartbeat
        stationaryUpdateInterval = fullFix
        // Keep a periodic fix cadence while stationary (in normal mode this can be minutes).
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

    // MARK: - Adaptive throttling helpers

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

        // Priority 0: EMERGENCY MODE - fixed cadence, regardless of movement/battery heuristics
        if manualTrackingMode == .emergency {
            let emergencyInterval = max(10.0, maxUpdateInterval)
            if timeSinceLast >= emergencyInterval {
                lastTransmittedFixDate = now
                lastThrottleAccuracy = location.horizontalAccuracy
                return false
            }
            return true
        }

        // Priority 1: Always send if we've exceeded the configured max interval
        if timeSinceLast >= maxUpdateInterval {
            lastTransmittedFixDate = now
            lastThrottleAccuracy = location.horizontalAccuracy
            return false
        }

        // CR-004 FIX: Priority 2 - Critical battery check BEFORE accuracy bypass
        // When battery is critically low, we must throttle aggressively to prevent
        // total battery depletion. Jittery GPS causing frequent accuracy changes
        // should NOT bypass this critical protection.
        if batteryLevel <= 0.10 {
            let criticalThrottle: TimeInterval = 5.0  // 5 seconds at critical battery
            if timeSinceLast < criticalThrottle {
                return true  // Throttle - battery protection takes priority
            }
            lastTransmittedFixDate = now
            lastThrottleAccuracy = location.horizontalAccuracy
            return false
        }

        // Priority 3: Send if accuracy significantly improved (only when battery is OK)
        let accuracyChange = abs(location.horizontalAccuracy - lastThrottleAccuracy)
        if accuracyChange > contextAccuracyDelta {
            lastTransmittedFixDate = now
            lastThrottleAccuracy = location.horizontalAccuracy
            return false
        }

        // Priority 4: Apply throttle interval based on battery and movement state
        let throttleInterval: TimeInterval
        if batteryLevel <= 0.20 {
            // Low battery: 3 seconds when moving, 5 seconds when stationary
            throttleInterval = isStationary ? 5.0 : 3.0
        } else if isStationary {
            // Normal battery, stationary: use stationary interval (180s default)
            throttleInterval = stationaryUpdateInterval
        } else {
            // Normal battery, moving: high frequency (0.5s)
            throttleInterval = contextPushInterval
        }

        if timeSinceLast < throttleInterval {
            return true
        }

        lastTransmittedFixDate = now
        lastThrottleAccuracy = location.horizontalAccuracy
        return false
    }
}

// MARK: - CLLocationManagerDelegate

extension WatchLocationProvider: CLLocationManagerDelegate {

    /// CRITICAL FIX: Handle authorization changes before starting location updates
    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        Task { @MainActor [weak self] in
            guard let self else { return }

            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                // Only start updating if we're actively tracking
                if self.isWorkoutRunning {
                    self.logger.log("Location authorized - starting updates")
                    self.locationManager.startUpdatingLocation()
                }
            case .denied, .restricted:
                self.logger.error("Location permission denied")
                self.delegate?.didFail(WatchConnectivityIssue.locationAuthorizationDenied)
            case .notDetermined:
                self.locationManager.requestWhenInUseAuthorization()
            @unknown default:
                break
            }
        }
    }

    /// Handles new GPS location updates from CoreLocation.
    ///
    /// Converts CLLocation to LocationFix format and publishes via triple-path messaging.
    /// Called at ~1Hz native Apple Watch GPS rate (no artificial throttling applied).
    ///
    /// - Parameters:
    ///   - manager: The location manager
    ///   - locations: Array of new location updates (uses last/most recent)
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            guard
                let self,
                let latest = locations.last
            else { return }
            
            // Thermal guard: graceful degradation before hard stop
            let thermalState = ProcessInfo.processInfo.thermalState
            if thermalState == .critical {
                // Critical: must stop to protect hardware
                if self.thermalDegradationLevel < 2 {
                    self.thermalDegradationLevel = 2
                    self.logger.error("Thermal CRITICAL - stopping tracking to protect hardware")
                    self.stopTrackingForThermalCritical()
                }
                return
            } else if thermalState == .serious {
                // Serious: degrade to saver mode (reduced frequency/accuracy)
                if self.thermalDegradationLevel < 1 {
                    self.thermalDegradationLevel = 1
                    self.logger.warning("Thermal SERIOUS - degrading to saver mode")
                    self.applyPreset(.saver, force: true)
                }
                // Continue processing but at reduced rate
            } else if self.thermalDegradationLevel > 0 {
                // Thermal recovered - restore normal operation
                let wasFullyStopped = self.thermalDegradationLevel == 2
                self.logger.log("Thermal recovered from level \(self.thermalDegradationLevel) - restoring normal operation")
                self.thermalDegradationLevel = 0
                self.isIntentionallyStopped = false

                // Restore preset based on current battery level
                if self.batteryOptimizationsEnabled {
                    let battery = self.latestBatteryLevel
                    if battery < 0.1 {
                        self.applyPreset(.saver)
                    } else if battery < 0.2 {
                        self.applyPreset(.balanced)
                    } else {
                        self.applyPreset(.aggressive)
                    }
                } else {
                    self.applyPreset(.aggressive)
                }

                // CR-002 FIX: If tracking was fully stopped due to thermal critical,
                // we must restart location updates and workout session
                if wasFullyStopped {
                    self.logger.log("CR-002: Restarting tracking after thermal recovery from critical state")
                    self.resetRestartCounter()  // Fresh start, reset retry counter
                    self.isWorkoutRunning = true
                    self.locationManager.startUpdatingLocation()
                    self.startWorkoutSession(activity: .other)
                    self.startBatteryHeartbeat()
                    if self.supportsExtendedRuntime {
                        self.runtimeCoordinator.updateTrackingState(isRunning: true)
                    }
                }
            }
            
            let device = WKInterfaceDevice.current()
            let batteryLevel = device.batteryLevel >= 0 ? Double(device.batteryLevel) : latestBatteryLevel
            latestBatteryLevel = batteryLevel
            performanceMonitor.recordBattery(level: batteryLevel)

            if batteryOptimizationsEnabled {
                let stationary = isDeviceStationary(latest)
                if shouldThrottleUpdate(location: latest, isStationary: stationary, batteryLevel: batteryLevel) {
                    let timeSinceLast = Date().timeIntervalSince(lastTransmittedFixDate)
                    let nextInterval = stationary ? stationaryUpdateInterval : contextPushInterval
                    let timeUntilNext = max(0, nextInterval - timeSinceLast)
                    logger.debug("Throttling fix (stationary=\(stationary), battery=\(Int(batteryLevel * 100))%, next in \(Int(timeUntilNext))s)")
                    return
                }
                lastKnownLocation = latest
            }
            
            // Convert CLLocation to LocationFix with Watch-specific metadata
            let fix = LocationFix(
                timestamp: latest.timestamp,
                source: .watchOS,
                coordinate: .init(
                    latitude: latest.coordinate.latitude,
                    longitude: latest.coordinate.longitude
                ),
                altitudeMeters: latest.verticalAccuracy >= 0 ? latest.altitude : nil,
                horizontalAccuracyMeters: latest.horizontalAccuracy,
                verticalAccuracyMeters: max(latest.verticalAccuracy, 0),
                speedMetersPerSecond: max(latest.speed, 0),
                courseDegrees: latest.course >= 0 ? latest.course : 0,
                headingDegrees: nil,  // Apple Watch doesn't have compass hardware
                batteryFraction: batteryLevel,
                sequence: Int(Int64(Date().timeIntervalSinceReferenceDate * 1000) % Int64(Int.max)),
                trackingPreset: batteryOptimizationsEnabled ? currentPreset.rawValue : nil
            )
            performanceMonitor.recordGPSLatency(Date().timeIntervalSince(latest.timestamp))
            self.publishFix(fix)
        }
    }
    
    /// Handles location manager errors.
    ///
    /// - Parameters:
    ///   - manager: The location manager
    ///   - error: The error that occurred
    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.delegate?.didFail(error)
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchLocationProvider: WCSessionDelegate {
    
    /// Handles WatchConnectivity session activation completion.
    ///
    /// - Parameters:
    ///   - session: The WatchConnectivity session
    ///   - activationState: The final activation state
    ///   - error: Optional error if activation failed
    nonisolated public func session(
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
                self.delegate?.didFail(error)
                self.scheduleActivationRetry(reason: "activation-error")
            } else if !isCompanionInstalled {
                self.scheduleActivationRetry(reason: "companion-missing")
            }
        }
    }
    
    /// Handles changes in phone reachability status with debouncing.
    ///
    /// Uses a 2.5-second debounce to prevent UI churn from Bluetooth flapping.
    /// Only propagates changes when reachability stabilizes.
    ///
    /// - Parameter session: The WatchConnectivity session
    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        let newReachability = session.isReachable
        ConnectivityLog.verbose("Reachability changed → reachable: \(newReachability)")
        Task { @MainActor [weak self] in
            self?.handleReachabilityChange(newReachability)
        }
    }

    /// Debounces reachability changes to prevent rapid state flipping.
    @MainActor
    private func handleReachabilityChange(_ isReachable: Bool) {
        // Cancel any pending debounce
        reachabilityDebounceTask?.cancel()

        // If this is the same as last reported, ignore
        if let lastReported = lastReportedReachability, lastReported == isReachable {
            return
        }

        // Schedule debounced update
        reachabilityDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.reachabilityDebounceInterval ?? 2.5))
            guard let self, !Task.isCancelled else { return }

            // Verify reachability hasn't changed during debounce period
            let currentReachability = self.wcSession.isReachable
            if currentReachability == isReachable {
                self.lastReportedReachability = isReachable
                self.logger.log("Reachability stabilized: \(isReachable ? "reachable" : "unreachable")")
                self.delegate?.didUpdateReachability(isReachable)
            } else {
                // Reachability flipped during debounce - restart debounce with new value
                self.handleReachabilityChange(currentReachability)
            }
        }
    }

    @MainActor
    private func applyTrackingModeChange(to newMode: TrackingMode, heartbeat: Double?, fullFix: Double?) {
        let previousMode = manualTrackingMode
        manualTrackingMode = newMode
        forceImmediateSend = true  // Always force immediate on mode change
        logger.log("Tracking mode changed: \(previousMode.rawValue) → \(newMode.rawValue)")

        if newMode == .emergency {
            lastEmergencyCloudRelayDate = .distantPast

            let resolvedHeartbeat = max(5.0, min(300.0, heartbeat ?? 30.0))
            let resolvedFullFix = max(10.0, min(600.0, fullFix ?? 60.0))

            applyIdleCadence(heartbeat: resolvedHeartbeat, fullFix: resolvedFullFix, persist: false)
            applyPreset(.aggressive, force: true)  // Force high-accuracy GPS regardless of battery
            logger.notice("Emergency mode enabled (heartbeat=\(resolvedHeartbeat)s, fullFix=\(resolvedFullFix)s)")
        } else if previousMode == .emergency {
            // Exiting emergency: restore user's persisted cadence and let adaptive tuning resume.
            loadIdleCadenceDefaults()
            logger.notice("Emergency mode disabled; restored persisted idle cadence defaults")
        }

        // Immediately transmit current location or request fresh one
        if let fix = latestFix, Date().timeIntervalSince(fix.timestamp) < 30 {
            transmitFix(fix, notifyDelegate: false)
        } else {
            locationManager.requestLocation()
        }

        sendBatteryHeartbeat()
    }
    
    nonisolated private func handleIncomingMessage(_ message: [String: Any]) -> [String: Any] {
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
                    self.locationManager.requestLocation()
                }
            }
            return ["status": "refreshing"]
        case ConnectivityConstants.setMode:
            if let modeRaw = message[ConnectivityConstants.mode] as? String,
               let newMode = TrackingMode(rawValue: modeRaw) {
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
                self.logger.log("Runtime optimizations toggled → \(enabled ? "enabled" : "disabled")")
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
            scheduleRemoteStop()
            return ["status": "stop-requested"]
        default:
            return ["status": "unknown-action"]
        }
    }

    nonisolated private func scheduleRemoteStop() {
        Task { @MainActor in
            self.delegate?.didReceiveRemoteStop()
            self.stop()
        }
    }

    /// Handles incoming message dictionaries from the phone (e.g., manual refresh requests).
    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        _ = handleIncomingMessage(message)
    }

    /// Handles incoming messages requiring a reply handler.
    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let response = handleIncomingMessage(message)
        replyHandler(response)
    }
    
    /// Handles incoming message data (not currently used).
    nonisolated public func session(_ session: WCSession, didReceiveMessageData messageData: Data) {}

    /// Handles updated application contexts when the phone queues commands while unreachable.
    nonisolated public func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String : Any]
    ) {
        guard let action = applicationContext[ConnectivityConstants.action] as? String else { return }
        if action == ConnectivityConstants.stopTracking {
            scheduleRemoteStop()
        } else if action == ConnectivityConstants.setMode,
                  let modeRaw = applicationContext[ConnectivityConstants.mode] as? String,
                  let newMode = TrackingMode(rawValue: modeRaw) {
            let heartbeat = applicationContext[ConnectivityConstants.heartbeatInterval] as? Double
            let fullFix = applicationContext[ConnectivityConstants.fullFixInterval] as? Double
            Task { @MainActor in
                self.applyTrackingModeChange(to: newMode, heartbeat: heartbeat, fullFix: fullFix)
            }
        } else if action == ConnectivityConstants.setRuntimeOptimizations, let enabled = applicationContext[ConnectivityConstants.enabled] as? Bool {
            Task { @MainActor in
                self.setBatteryOptimizationsEnabled(enabled)
                self.logger.log("Runtime optimizations context applied (enabled=\(enabled))")
            }
        } else if action == ConnectivityConstants.setIdleCadence,
                  let heartbeat = applicationContext[ConnectivityConstants.heartbeatInterval] as? Double,
                  let fullFix = applicationContext[ConnectivityConstants.fullFixInterval] as? Double {
            Task { @MainActor in
                self.applyIdleCadence(heartbeat: heartbeat, fullFix: fullFix)
                self.logger.log("Idle cadence context applied (heartbeat=\(heartbeat)s, fullFix=\(fullFix)s)")
            }
        }
    }
    
    /// Handles incoming file transfers from the phone (not used in Watch-to-phone flow).
    ///
    /// - Parameters:
    ///   - session: The WatchConnectivity session
    ///   - file: The received file
    nonisolated public func session(_ session: WCSession, didReceive file: WCSessionFile) {}
    
    /// Handles file transfer completion or failure.
    ///
    /// On success: Cleans up temporary file
    /// On failure: Retries the transfer with same fix data
    ///
    /// - Parameters:
    ///   - session: The WatchConnectivity session
    ///   - fileTransfer: The completed file transfer
    ///   - error: Optional error if transfer failed
    nonisolated public func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard
                let self,
                let record = self.activeFileTransfers.removeValue(forKey: fileTransfer)
            else { return }
            
            // Always clean up temp file
            defer { try? self.fileManager.removeItem(at: record.url) }
            
            if let error {
                ConnectivityLog.error("File transfer failed: \(error.localizedDescription). Retrying…")
                self.notifyConnectivityError(.fileTransferFailed(underlying: error))
                self.queueBackgroundTransfer(for: record.fix)
            } else {
                ConnectivityLog.verbose("File transfer completed successfully")
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchLocationProvider: HKWorkoutSessionDelegate {
    
    /// Handles workout session state changes.
    ///
    /// When workout ends or stops, finalizes the workout data collection.
    ///
    /// - Parameters:
    ///   - workoutSession: The workout session
    ///   - toState: The new state
    ///   - fromState: The previous state
    ///   - date: The transition date
    nonisolated public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            self.logger.log("Workout session state: \(fromState.rawValue) → \(toState.rawValue)")

            guard toState == .ended || toState == .stopped else { return }

            if let builder = self.workoutBuilder {
                builder.endCollection(withEnd: date) { [weak self] _, error in
                    if let error {
                        Task { @MainActor in
                            self?.delegate?.didFail(error)
                        }
                        return
                    }
                    builder.finishWorkout { [weak self] _, finishError in
                        if let finishError {
                            Task { @MainActor in
                                self?.delegate?.didFail(finishError)
                            }
                        }
                    }
                }
            }

            // Auto-restart workout session if not intentionally stopped
            // This handles unexpected session termination (timeout, system interruption)
            if !self.isIntentionallyStopped && self.isWorkoutRunning {
                self.logger.log("Workout session ended unexpectedly - scheduling auto-restart")
                self.scheduleWorkoutRestart()
            }
        }
    }

    /// Schedules an automatic restart of the workout session after unexpected termination.
    /// CR-001 FIX: Uses exponential backoff (3s base, doubling each attempt) with max 5 retries
    /// to prevent infinite restart loops that could drain battery or cause system instability.
    @MainActor
    private func scheduleWorkoutRestart() {
        workoutRestartTask?.cancel()

        // CR-001 FIX: Check if we've exceeded max restart attempts
        if restartAttemptCount >= maxRestartAttempts {
            logger.error("Auto-restart aborted: exceeded max attempts (\(self.maxRestartAttempts)). Manual restart required.")
            isIntentionallyStopped = true  // Mark as stopped to prevent further attempts
            isWorkoutRunning = false
            delegate?.didFail(WatchConnectivityIssue.sessionNotActivated)
            return
        }

        // CR-001 FIX: Exponential backoff: 3s, 6s, 12s, 24s, 48s
        let backoffSeconds = 3.0 * pow(2.0, Double(restartAttemptCount))
        restartAttemptCount += 1

        logger.log("Scheduling workout restart attempt \(self.restartAttemptCount)/\(self.maxRestartAttempts) in \(Int(backoffSeconds))s")

        workoutRestartTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(backoffSeconds))
            guard let self, !Task.isCancelled else { return }
            guard !self.isIntentionallyStopped else {
                self.logger.log("Auto-restart cancelled - tracking was intentionally stopped")
                self.restartAttemptCount = 0  // Reset counter for next tracking session
                return
            }

            self.logger.log("Auto-restarting workout session (attempt \(self.restartAttemptCount))")

            // Clear old session references
            self.workoutSession = nil
            self.workoutBuilder = nil

            // Restart the workout session
            self.startWorkoutSession(activity: .other)
            self.locationManager.startUpdatingLocation()

            // CR-001 FIX: Reset counter on successful restart
            // (If it fails again, workoutSession delegate will call scheduleWorkoutRestart)
            self.logger.log("Workout session auto-restart complete")
        }
    }

    /// CR-001 FIX: Reset restart counter when tracking starts intentionally
    private func resetRestartCounter() {
        restartAttemptCount = 0
    }
    
    /// Handles workout session errors.
    ///
    /// - Parameters:
    ///   - workoutSession: The workout session
    ///   - error: The error that occurred
    nonisolated public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.delegate?.didFail(error)
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchLocationProvider: HKLiveWorkoutBuilderDelegate {
    
    /// Handles workout data collection events (not used for GPS tracking).
    ///
    /// - Parameters:
    ///   - workoutBuilder: The workout builder
    ///   - collectedTypes: The types of data collected
    nonisolated public func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        // Data collection events not needed for GPS tracking
    }
    
    /// Handles workout event collection (not used for GPS tracking).
    ///
    /// - Parameter workoutBuilder: The workout builder
    nonisolated public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Event collection not needed for GPS tracking
    }
}

#else

// MARK: - Non-watchOS Stub Implementation

/// Stub protocol for non-watchOS platforms.
@MainActor
public protocol WatchLocationProviderDelegate: AnyObject, Sendable {
    func didProduce(_ fix: LocationFix)
    func didFail(_ error: Error)
}

/// Stub implementation for non-watchOS platforms.
/// WatchLocationProvider is only functional on watchOS.
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
