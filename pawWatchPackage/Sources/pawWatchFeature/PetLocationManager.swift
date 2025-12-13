//
//  PetLocationManager.swift
//  pawWatch
//
//  Purpose: Manages pet GPS location data from Apple Watch via WatchConnectivity.
//           Handles real-time location updates, historical trail data, and owner distance calculation.
//
//  Author: Created for pawWatch
//  Created: 2025-11-05
//  Swift: 6.2
//  Platform: iOS 26.1+
//

#if os(iOS)
import Foundation
import CoreLocation
import Observation
import OSLog
#if canImport(HealthKit)
import HealthKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

public enum TrackingMode: String, CaseIterable, Sendable {
    case auto
    case emergency
    case balanced
    case saver

    public var label: String {
        switch self {
        case .auto: return "Auto"
        case .emergency: return "Emergency"
        case .balanced: return "Balanced"
        case .saver: return "Saver"
        }
    }
}

public enum LocationUpdateSource: String, Sendable {
    case watchConnectivity
    case cloudKit

    public var label: String {
        switch self {
        case .watchConnectivity:
            return "Direct"
        case .cloudKit:
            return "iCloud Relay"
        }
    }
}

public enum IdleCadencePreset: String, CaseIterable, Identifiable, Sendable {
    case balanced
    case live
    case conservative

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .balanced: return "Balanced"
        case .live: return "Lab / Live"
        case .conservative: return "Battery Saver"
        }
    }

    public var heartbeatInterval: TimeInterval {
        switch self {
        case .balanced: return 30
        case .live: return 15
        case .conservative: return 60
        }
    }

    public var fullFixInterval: TimeInterval {
        switch self {
        case .balanced: return 180
        case .live: return 90
        case .conservative: return 300
        }
    }

    public var footnote: String {
        switch self {
        case .balanced:
            return "Heartbeats every 30s, stationary fixes every 3m."
        case .live:
            return "Heartbeats every 15s, stationary fixes every 90s."
        case .conservative:
            return "Heartbeats every 60s, stationary fixes every 5m."
        }
    }
}

public enum EmergencyCadencePreset: String, CaseIterable, Identifiable, Sendable {
    case standard
    case fast

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .fast: return "Fast"
        }
    }

    public var heartbeatInterval: TimeInterval {
        switch self {
        case .standard: return 30
        case .fast: return 10
        }
    }

    public var fullFixInterval: TimeInterval {
        switch self {
        case .standard: return 60
        case .fast: return 10
        }
    }

    public var footnote: String {
        switch self {
        case .standard:
            return "Sends fixes roughly every 60s when in Emergency (battery-friendly)."
        case .fast:
            return "Sends fixes roughly every 10s when in Emergency (battery-heavy)."
        }
    }
}

/// Observable manager for pet location data received from Apple Watch.
///
/// Responsibilities:
/// - Establish and maintain WCSession connection with paired Apple Watch
/// - Receive LocationFix messages via WatchConnectivity (messages, context, files)
/// - Store last 100 GPS fixes for trail visualization on map
/// - Track connection status and last update timestamp
/// - Calculate distance from owner's iPhone location to pet's Watch location
/// - Provide real-time state updates to SwiftUI views via @Observable
///
/// Usage:
/// ```swift
/// @State private var locationManager = PetLocationManager()
///
/// var body: some View {
///     Text("Battery: \(locationManager.batteryLevel * 100)%")
/// }
/// ```
@MainActor
@Observable
public final class PetLocationManager: NSObject {

    // MARK: - Shared Instance for Background Access

    /// Shared instance set by the app on launch for background task access.
    /// CRITICAL FIX: Using MainActor isolation to ensure thread safety
    /// Since PetLocationManager is @MainActor, this is safe
    @MainActor
    private static var _shared: PetLocationManager?

    /// Thread-safe access to the shared instance (async)
    public static var shared: PetLocationManager? {
        get async {
            await MainActor.run { _shared }
        }
    }

    /// Thread-safe shared instance getter for MainActor contexts (sync)
    @MainActor
    public static var sharedSync: PetLocationManager? {
        get { _shared }
    }

    /// Set the shared instance (call from app initialization)
    @MainActor
    public static func setShared(_ manager: PetLocationManager) {
        _shared = manager
    }

    // MARK: - Published State

    /// Most recent GPS fix from Apple Watch (nil if no data received)
    public private(set) var latestLocation: LocationFix?

    /// Last N GPS fixes for trail visualization (oldest first)
    public private(set) var locationHistory: [LocationFix] = []

    /// WatchConnectivity session status
    public private(set) var isWatchConnected: Bool = false

    /// Whether WCSession is reachable for immediate message delivery
    public private(set) var isWatchReachable: Bool = false

    /// Whether the Watch connection is considered stale (no updates for a while).
    public private(set) var isConnectionStale: Bool = false

    /// Timestamp of last received GPS fix
    public private(set) var lastUpdateTime: Date?

    /// Where the latest location update came from (Direct vs iCloud relay).
    public private(set) var latestUpdateSource: LocationUpdateSource = .watchConnectivity

    /// Current owner location from iPhone GPS (nil if not yet obtained)
    public private(set) var ownerLocation: CLLocation?

    /// Error message for connection issues (nil if no error)
    public private(set) var errorMessage: String?

    /// Latest battery fraction reported by the watch (via heartbeat)
    public private(set) var watchBatteryFraction: Double?

    /// Whether the watch-side tracker UI is currently locked
    public private(set) var isWatchLocked: Bool = false

    /// Current tracking mode requested by the user
    public private(set) var trackingMode: TrackingMode = .auto

    /// Current iPhone location authorization status
    public private(set) var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined

#if canImport(HealthKit)
    public private(set) var workoutAuthorizationStatus: HKAuthorizationStatus = .notDetermined
    public private(set) var heartRateAuthorizationStatus: HKAuthorizationStatus = .notDetermined
#endif

    public private(set) var sessionSummary = SessionSummary()
    public private(set) var idleCadencePreset: IdleCadencePreset
    public private(set) var watchIdleHeartbeatInterval: TimeInterval?
    public private(set) var watchIdleFullFixInterval: TimeInterval?
    public private(set) var emergencyCadencePreset: EmergencyCadencePreset

    // MARK: - Constants

    public static let trailHistoryLimitRange: ClosedRange<Int> = 50...500
    public static let trailHistoryStep = 25
    private static let defaultTrailHistoryLimit = 100

    private let trailHistoryLimitKey = "TrailHistoryLimit"
    private let runtimePreferenceKey = RuntimePreferenceKey.runtimeOptimizationsEnabled
    private let idleCadenceKey = "IdleCadencePreset"
    private let emergencyCadenceKey = "EmergencyCadencePreset"
    private let sharedDefaults: UserDefaults
    public private(set) var trailHistoryLimit: Int
    public private(set) var runtimeOptimizationsEnabled: Bool
    public private(set) var watchSupportsExtendedRuntime: Bool = false
    private let recentSequenceCapacity = 512

    private struct FixAcceptancePolicy: Sendable {
        let maxHorizontalAccuracyMeters: Double
        let maxFixStaleness: TimeInterval
        let maxJumpDistanceMeters: Double

        static let balanced = FixAcceptancePolicy(
            maxHorizontalAccuracyMeters: 75,
            maxFixStaleness: 120,
            maxJumpDistanceMeters: 5_000
        )
        static let saver = FixAcceptancePolicy(
            maxHorizontalAccuracyMeters: 60,
            maxFixStaleness: 180,
            maxJumpDistanceMeters: 3_000
        )
        static let emergency = FixAcceptancePolicy(
            maxHorizontalAccuracyMeters: 150,
            maxFixStaleness: 300,
            maxJumpDistanceMeters: 10_000
        )
    }

    private enum FixAcceptancePolicyDefaultsKey {
        enum Field: String {
            case maxHorizontalAccuracyMeters
            case maxFixStalenessSeconds
            case maxJumpDistanceMeters
        }

        static func key(mode: TrackingMode, field: Field) -> String {
            "FixAcceptancePolicy.\(mode.rawValue).\(field.rawValue)"
        }
    }

    private func registerFixAcceptancePolicyDefaults() {
        let defaults: [String: Any] = [
            FixAcceptancePolicyDefaultsKey.key(mode: .balanced, field: .maxHorizontalAccuracyMeters): FixAcceptancePolicy.balanced.maxHorizontalAccuracyMeters,
            FixAcceptancePolicyDefaultsKey.key(mode: .balanced, field: .maxFixStalenessSeconds): FixAcceptancePolicy.balanced.maxFixStaleness,
            FixAcceptancePolicyDefaultsKey.key(mode: .balanced, field: .maxJumpDistanceMeters): FixAcceptancePolicy.balanced.maxJumpDistanceMeters,
            FixAcceptancePolicyDefaultsKey.key(mode: .saver, field: .maxHorizontalAccuracyMeters): FixAcceptancePolicy.saver.maxHorizontalAccuracyMeters,
            FixAcceptancePolicyDefaultsKey.key(mode: .saver, field: .maxFixStalenessSeconds): FixAcceptancePolicy.saver.maxFixStaleness,
            FixAcceptancePolicyDefaultsKey.key(mode: .saver, field: .maxJumpDistanceMeters): FixAcceptancePolicy.saver.maxJumpDistanceMeters,
            FixAcceptancePolicyDefaultsKey.key(mode: .emergency, field: .maxHorizontalAccuracyMeters): FixAcceptancePolicy.emergency.maxHorizontalAccuracyMeters,
            FixAcceptancePolicyDefaultsKey.key(mode: .emergency, field: .maxFixStalenessSeconds): FixAcceptancePolicy.emergency.maxFixStaleness,
            FixAcceptancePolicyDefaultsKey.key(mode: .emergency, field: .maxJumpDistanceMeters): FixAcceptancePolicy.emergency.maxJumpDistanceMeters
        ]

        sharedDefaults.register(defaults: defaults)
    }

    private var fixAcceptancePolicy: FixAcceptancePolicy {
        let mode: TrackingMode = trackingMode == .auto ? .balanced : trackingMode
        let base: FixAcceptancePolicy = switch mode {
        case .emergency: .emergency
        case .saver: .saver
        case .auto, .balanced: .balanced
        }

        let accuracy = sharedDefaults.double(forKey: FixAcceptancePolicyDefaultsKey.key(mode: mode, field: .maxHorizontalAccuracyMeters))
        let staleness = sharedDefaults.double(forKey: FixAcceptancePolicyDefaultsKey.key(mode: mode, field: .maxFixStalenessSeconds))
        let jump = sharedDefaults.double(forKey: FixAcceptancePolicyDefaultsKey.key(mode: mode, field: .maxJumpDistanceMeters))

        return FixAcceptancePolicy(
            maxHorizontalAccuracyMeters: accuracy > 0 ? accuracy : base.maxHorizontalAccuracyMeters,
            maxFixStaleness: max(0, staleness),
            maxJumpDistanceMeters: jump > 0 ? jump : base.maxJumpDistanceMeters
        )
    }
    private var recentSequenceSet: Set<Int> = []
    private var recentSequenceOrder: [Int] = []

    // CloudKit sync throttling (CR-001 fix)
    private var lastCloudKitSync: Date?
    private let cloudKitSyncInterval: TimeInterval = 300 // 5 minutes

    // MARK: - Dependencies

    #if canImport(WatchConnectivity)
    private let session: WCSession
    #endif
    private let locationManager: CLLocationManager
    private let logger = Logger(subsystem: PawWatchLog.subsystem, category: "PetLocationManager")
    private let signposter = OSSignposter(subsystem: PawWatchLog.subsystem, category: "PetLocationManager")
    private let sessionSignposter = OSSignposter(subsystem: PawWatchLog.subsystem, category: "SessionExport")
    #if canImport(HealthKit)
    private let healthStore = HKHealthStore()
    private let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)
    #endif
    @ObservationIgnored private var sessionSamples: [SessionSample] = []
    @ObservationIgnored private var sessionStartDate: Date?
    @ObservationIgnored private var sessionReachabilityFlipCount: Int = 0
    private let maxSessionSamples = 10_000
    /// Task for monitoring stale connections. Marked nonisolated(unsafe) because
    /// Task.cancel() is thread-safe and we need to call it from deinit.
    nonisolated(unsafe) private var staleConnectionTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initialize PetLocationManager with WatchConnectivity and CoreLocation.
    /// Automatically activates WCSession if supported.
    public override init() {
        #if canImport(WatchConnectivity)
        self.session = WCSession.default
        #endif
        self.locationManager = CLLocationManager()
        self.sharedDefaults = UserDefaults(suiteName: PerformanceSnapshotStore.suiteName) ?? .standard
        let storedLimit = sharedDefaults.object(forKey: trailHistoryLimitKey) as? Int
        self.trailHistoryLimit = storedLimit.map(Self.clampTrailHistoryLimit) ?? Self.defaultTrailHistoryLimit
        let storedRuntime = sharedDefaults.object(forKey: runtimePreferenceKey) as? Bool
        self.runtimeOptimizationsEnabled = storedRuntime ?? true

        let storedPresetRaw = sharedDefaults.string(forKey: idleCadenceKey)
        if let storedPresetRaw,
           let storedPreset = IdleCadencePreset(rawValue: storedPresetRaw) {
            self.idleCadencePreset = storedPreset
        } else {
            self.idleCadencePreset = .balanced
        }
        let needsDefaultIdlePreset = storedPresetRaw == nil

        let storedEmergencyCadenceRaw = sharedDefaults.string(forKey: emergencyCadenceKey)
        if let storedEmergencyCadenceRaw,
           let storedEmergencyCadence = EmergencyCadencePreset(rawValue: storedEmergencyCadenceRaw) {
            self.emergencyCadencePreset = storedEmergencyCadence
        } else {
            self.emergencyCadencePreset = .standard
        }
        let needsDefaultEmergencyCadence = storedEmergencyCadenceRaw == nil

        super.init()

        registerFixAcceptancePolicyDefaults()

        // Set initial authorization status using instance property (iOS 14+)
        self.locationAuthorizationStatus = locationManager.authorizationStatus

        // Setup WatchConnectivity
        // CRITICAL FIX: Defer activation until after super.init() completes
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            session.delegate = self
            // Activation moved to end of init
        } else {
            errorMessage = "WatchConnectivity not supported on this device"
        }
        #else
        errorMessage = "WatchConnectivity not available in this build"
        #endif

        // Setup CoreLocation for owner position
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.requestWhenInUseAuthorization()
        // CRITICAL FIX: Don't start updating until authorization is granted
        // startUpdatingLocation() will be called in locationManagerDidChangeAuthorization

        if storedLimit == nil {
            persistTrailHistoryLimit(trailHistoryLimit)
        }
        if storedRuntime == nil {
            persistRuntimePreference(runtimeOptimizationsEnabled)
        }
        if needsDefaultIdlePreset {
            sharedDefaults.set(idleCadencePreset.rawValue, forKey: idleCadenceKey)
        }
        if needsDefaultEmergencyCadence {
            sharedDefaults.set(emergencyCadencePreset.rawValue, forKey: emergencyCadenceKey)
        }

        refreshHealthAuthorizationState()

        // Attempt CloudKit recovery if no local data
        Task { @MainActor [weak self] in
            await self?.recoverFromCloudKitIfNeeded()
        }

        // CRITICAL FIX: Activate WCSession after init completes
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            session.activate()
        }
        #endif

        startStaleConnectionMonitor()

        logFixAcceptancePolicy(reason: "init")
    }

    private func logFixAcceptancePolicy(reason: String) {
        let policyMode: TrackingMode = trackingMode == .auto ? .balanced : trackingMode
        let policy = fixAcceptancePolicy
        logger.notice(
            "Fix acceptance policy (\(reason, privacy: .public)) mode=\(trackingMode.rawValue, privacy: .public) mapped=\(policyMode.rawValue, privacy: .public) " +
                "accuracy<=\(policy.maxHorizontalAccuracyMeters, privacy: .public)m " +
                "jump<=\(policy.maxJumpDistanceMeters, privacy: .public)m " +
                "historical>=\(policy.maxFixStaleness, privacy: .public)s"
        )
    }

    deinit {
        staleConnectionTask?.cancel()
        staleConnectionTask = nil
    }

    /// Attempt to recover location data from CloudKit if local data is missing.
    private func recoverFromCloudKitIfNeeded() async {
        guard latestLocation == nil else { return }

        // Check iCloud availability first
        guard await CloudKitLocationSync.shared.checkAccountStatus() else {
            logger.notice("CloudKit unavailable for recovery")
            return
        }

        // Attempt to restore last known location
        if let recoveredLocation = await CloudKitLocationSync.shared.loadLocation() {
            // Only use if not too stale (within last 24 hours)
            let age = Date().timeIntervalSince(recoveredLocation.timestamp)
            if age < 24 * 60 * 60 {
                await MainActor.run {
                    // CR-002 FIX: Re-check latestLocation inside MainActor block
                    // A live WCSession update may have arrived during the CloudKit fetch
                    guard self.latestLocation == nil else {
                        self.logger.notice("Skipping CloudKit recovery - live data arrived during fetch")
                        return
                    }
                    self.latestLocation = recoveredLocation
                    self.latestUpdateSource = .cloudKit
                    self.watchBatteryFraction = recoveredLocation.batteryFraction
                    self.lastUpdateTime = recoveredLocation.timestamp
                    self.logger.info("Recovered location from CloudKit (age: \(Int(age))s)")
                }
            } else {
                logger.notice("CloudKit location too stale (age: \(Int(age))s)")
            }
        }
    }

    // MARK: - Public API

    /// Maximum age (in seconds) for pet location to be considered fresh for distance calculation.
    /// CR-005 FIX: Prevents misleading distance when location data is stale.
    private let maxDistanceLocationAge: TimeInterval = 600 // 10 minutes

    /// Calculate distance between owner (iPhone) and pet (Watch) in meters.
    /// Returns nil if either location is unavailable or if pet location is stale.
    /// CR-005 FIX: Now returns nil for stale pet locations (>10 min old).
    public var distanceFromOwner: Double? {
        guard let ownerLoc = ownerLocation,
              let petLoc = latestLocation else {
            return nil
        }

        // CR-005 FIX: Return nil if pet location is too stale to be meaningful
        let age = Date().timeIntervalSince(petLoc.timestamp)
        guard age <= maxDistanceLocationAge else {
            return nil
        }

        // Convert LocationFix to CLLocation for distance calculation
        let petCLLocation = CLLocation(
            latitude: petLoc.coordinate.latitude,
            longitude: petLoc.coordinate.longitude
        )

        return ownerLoc.distance(from: petCLLocation)
    }

    /// Whether the pet location is fresh enough for reliable distance calculation.
    /// Returns false if location is nil or older than 10 minutes.
    public var isDistanceFresh: Bool {
        guard let petLoc = latestLocation else { return false }
        let age = Date().timeIntervalSince(petLoc.timestamp)
        return age <= maxDistanceLocationAge
    }

    /// Battery level as percentage (0-100)
    public var batteryLevel: Double {
        latestLocation?.batteryFraction ?? 0.0
    }

    /// Adjusts and persists the number of fixes stored for the trail history.
    public func updateTrailHistoryLimit(to newValue: Int) {
        let clamped = Self.clampTrailHistoryLimit(newValue)
        guard clamped != trailHistoryLimit else { return }
        trailHistoryLimit = clamped
        persistTrailHistoryLimit(clamped)
        pruneHistoryIfNeeded()
    }

    /// Selects the idle cadence preset used for stationary heartbeats vs. full fixes.
    public func setIdleCadencePreset(_ preset: IdleCadencePreset) {
        guard preset != idleCadencePreset else { return }
        idleCadencePreset = preset
        sharedDefaults.set(preset.rawValue, forKey: idleCadenceKey)
        sendIdleCadenceCommand(preset)
    }

    /// Selects the cadence used during Emergency mode (fast vs battery-friendly).
    public func setEmergencyCadencePreset(_ preset: EmergencyCadencePreset) {
        guard preset != emergencyCadencePreset else { return }
        emergencyCadencePreset = preset
        sharedDefaults.set(preset.rawValue, forKey: emergencyCadenceKey)
        if trackingMode == .emergency {
            sendModeCommand(.emergency)
        }
    }

    /// Persists and forwards the extended runtime preference to the watch.
    public func setRuntimeOptimizationsEnabled(_ enabled: Bool) {
        guard enabled != runtimeOptimizationsEnabled else { return }
        runtimeOptimizationsEnabled = enabled
        persistRuntimePreference(enabled)
        sendRuntimePreferenceCommand(enabled)
    }

    /// GPS accuracy in meters (horizontal accuracy)
    public var accuracyMeters: Double {
        latestLocation?.horizontalAccuracyMeters ?? 0.0
    }

    /// Time elapsed since last GPS update in seconds
    public var secondsSinceLastUpdate: TimeInterval? {
        guard let lastUpdate = lastUpdateTime else { return nil }
        return Date().timeIntervalSince(lastUpdate)
    }

    /// Request immediate update from Apple Watch (if reachable)
    public func requestUpdate(force: Bool = false) {
        #if canImport(WatchConnectivity)
        guard isWatchReachable else {
            errorMessage = "Apple Watch not reachable. Check Bluetooth connection."
            return
        }

        // Send request message to Watch
        var message: [String: Any] = [ConnectivityConstants.action: ConnectivityConstants.requestLocation]
        if force { message[ConnectivityConstants.force] = true }
        session.sendMessage(
            message,
            replyHandler: nil,
            errorHandler: { error in
                Task { @MainActor in
                    self.errorMessage = "Failed to request update: \(error.localizedDescription)"
                }
            }
        )
        #else
        errorMessage = "WatchConnectivity not available"
        #endif
    }

    /// Request location update for background refresh (uses application context if not reachable).
    /// Returns true if request was sent, false if WatchConnectivity unavailable.
    @discardableResult
    public func requestBackgroundUpdate() -> Bool {
        #if canImport(WatchConnectivity)
        guard session.activationState == .activated else {
            logger.notice("Background update skipped: WCSession not activated")
            return false
        }

        let payload: [String: Any] = [
            ConnectivityConstants.action: ConnectivityConstants.requestLocation,
            ConnectivityConstants.background: true,
            ConnectivityConstants.timestamp: Date().timeIntervalSince1970
        ]

        if isWatchReachable {
            // Watch is immediately reachable - send direct message
            session.sendMessage(payload, replyHandler: nil) { [logger] error in
                logger.error("Background location request failed: \(error.localizedDescription, privacy: .public)")
            }
            logger.info("Background location requested via direct message")
        } else {
            // Queue via application context for delivery when watch wakes
            do {
                try session.updateApplicationContext(payload)
                logger.info("Background location requested via application context")
            } catch {
                logger.error("Failed to queue background location request: \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
        return true
        #else
        return false
        #endif
    }
    
    /// Sends a stop command to the Watch.
    public func sendStopCommand() {
        #if canImport(WatchConnectivity)
        guard session.activationState == .activated else { return }
        let payload: [String: Any] = [ConnectivityConstants.action: ConnectivityConstants.stopTracking]
        
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                Task { @MainActor in
                    self.logger.error("Failed to send stop command: \(error.localizedDescription)")
                }
            }
        } else {
            do {
                try session.updateApplicationContext(payload)
                logger.notice("Queued stop command via application context")
            } catch {
                logger.error("Failed to queue stop command: \(error.localizedDescription)")
            }
        }
        #endif
    }

    /// Request iPhone location permission again.
    public func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    private func startEmergencyCloudRelay() {
        Task.detached(priority: .utility) { [weak self] in
            _ = await CloudKitLocationSync.shared.ensureLocationSubscription()
            guard let self else { return }

            let state = await MainActor.run { (mode: self.trackingMode, reachable: self.isWatchReachable, lastUpdate: self.lastUpdateTime) }
            guard state.mode == .emergency else { return }

            let now = Date()
            let isStale = state.lastUpdate.map { now.timeIntervalSince($0) > 90 } ?? true
            guard !state.reachable || isStale else { return }

            if let fix = await CloudKitLocationSync.shared.loadLocation() {
                await MainActor.run {
                    self.handleLocationFix(fix, source: .cloudKit)
                }
            }
        }
    }

    private func stopEmergencyCloudRelay() {
        Task.detached(priority: .utility) {
            await CloudKitLocationSync.shared.deleteLocationSubscription()
        }
    }

    /// Update the desired tracking mode and inform the watch
    public func setTrackingMode(_ mode: TrackingMode) {
        let previousMode = trackingMode
        trackingMode = mode
        logFixAcceptancePolicy(reason: "user-mode-change")

        if mode == .emergency {
            startEmergencyCloudRelay()
        } else if previousMode == .emergency {
            stopEmergencyCloudRelay()
        }

        sendModeCommand(mode)

        if previousMode == .emergency, mode != .emergency {
            sendIdleCadenceCommand(idleCadencePreset)
        }
    }

    /// Accepts a CloudKit relay fix (typically delivered via CloudKit silent push on iPhone).
    public func applyCloudKitRelayLocation(_ fix: LocationFix) {
        handleLocationFix(fix, source: .cloudKit)
    }

    private func sendModeCommand(_ mode: TrackingMode) {
        #if canImport(WatchConnectivity)
        guard session.activationState == .activated else { return }

        var payload: [String: Any] = [
            ConnectivityConstants.action: ConnectivityConstants.setMode,
            ConnectivityConstants.mode: mode.rawValue
        ]

        if mode == .emergency {
            payload[ConnectivityConstants.heartbeatInterval] = emergencyCadencePreset.heartbeatInterval
            payload[ConnectivityConstants.fullFixInterval] = emergencyCadencePreset.fullFixInterval
        }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                Task { @MainActor in
                    self.errorMessage = "Failed to send mode: \(error.localizedDescription)"
                }
            }
        } else {
            do {
                try session.updateApplicationContext(payload)
            } catch {
                errorMessage = "Failed to cache mode: \(error.localizedDescription)"
            }
        }
        #endif
    }

    private func sendRuntimePreferenceCommand(_ enabled: Bool) {
        #if canImport(WatchConnectivity)
        guard session.activationState == .activated else { return }
        let payload: [String: Any] = [
            ConnectivityConstants.action: ConnectivityConstants.setRuntimeOptimizations,
            ConnectivityConstants.enabled: enabled
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                Task { @MainActor in
                    self.errorMessage = "Failed to update runtime guard: \(error.localizedDescription)"
                }
            }
        } else {
            do {
                try session.updateApplicationContext(payload)
            } catch {
                errorMessage = "Failed to queue runtime guard: \(error.localizedDescription)"
            }
        }
        #endif
    }

    private func sendIdleCadenceCommand(_ preset: IdleCadencePreset) {
        #if canImport(WatchConnectivity)
        guard session.activationState == .activated else { return }
        let payload: [String: Any] = [
            ConnectivityConstants.action: ConnectivityConstants.setIdleCadence,
            ConnectivityConstants.heartbeatInterval: preset.heartbeatInterval,
            ConnectivityConstants.fullFixInterval: preset.fullFixInterval
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                Task { @MainActor in
                    self.errorMessage = "Failed to update idle cadence: \(error.localizedDescription)"
                }
            }
        } else {
            do {
                try session.updateApplicationContext(payload)
            } catch {
                errorMessage = "Failed to queue idle cadence: \(error.localizedDescription)"
            }
        }
        #endif
    }

    /// Opens system Settings for manual permission adjustment.
    public func openLocationSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    /// Human readable description of the current location permission.
    public var locationPermissionDescription: String {
        switch locationAuthorizationStatus {
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "When In Use"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }

    /// Whether the app needs the user to take action on location permission.
    public var needsLocationPermissionAction: Bool {
        switch locationAuthorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    /// Copy shown anywhere we remind users that distance relies on the foreground dashboard.
    public var distanceUsageBlurb: String {
        "Distance updates refresh while pawWatch stays open on your iPhone. Background alerts aren't supported yet."
    }

    #if canImport(HealthKit)
    private func refreshHealthAuthorizationState() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        // Workout (WRITE permission - can check directly)
        let workoutType = HKObjectType.workoutType()
        if #available(iOS 18.0, *) {
            workoutAuthorizationStatus = healthStore.authorizationStatus(for: workoutType)
            logger.info("Workout status: \(String(describing: self.workoutAuthorizationStatus))")
        }

        // Heart Rate (READ permission - test by attempting to read)
        if let heartRateType {
            Task {
                let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: nil) { _, samples, error in
                    Task { @MainActor in
                        if let error {
                            if let hkError = error as? HKError, hkError.code == .errorAuthorizationDenied {
                                self.heartRateAuthorizationStatus = .sharingDenied
                                self.logger.info("Heart Rate: Denied (verified by query)")
                            } else {
                                self.heartRateAuthorizationStatus = .notDetermined
                                self.logger.info("Heart Rate: Unable to verify authorization (error: \(error.localizedDescription, privacy: .public))")
                            }
                            return
                        }

                        // No error means the read query was permitted, even if there are zero samples.
                        _ = samples // keep parameter used for future debugging
                        self.heartRateAuthorizationStatus = .sharingAuthorized
                        self.logger.info("Heart Rate: Authorized (verified by query)")
                    }
                }
                healthStore.execute(query)
            }
        }
    }

    private func describeHealthStatus(_ status: HKAuthorizationStatus) -> String {
        switch status {
        case .sharingAuthorized:
            return "Authorized"
        case .sharingDenied:
            return "Denied"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }
    #else
    private func refreshHealthAuthorizationState() {}
    #endif

    #if canImport(HealthKit)
    public var workoutPermissionDescription: String {
        describeHealthStatus(workoutAuthorizationStatus)
    }

    public var heartPermissionDescription: String {
        describeHealthStatus(heartRateAuthorizationStatus)
    }

    public var needsHealthPermissionAction: Bool {
        workoutAuthorizationStatus == .sharingDenied || heartRateAuthorizationStatus == .sharingDenied
    }

    public var canRequestHealthAuthorization: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public func requestHealthAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        var readTypes: Set<HKObjectType> = []
        if let heartRateType {
            readTypes.insert(heartRateType)
            logger.info("Requesting Heart Rate authorization")
        } else {
            logger.error("Heart rate type is nil!")
        }

        let shareTypes: Set<HKSampleType> = [HKObjectType.workoutType()]
        logger.info("Requesting authorization for \(readTypes.count) read types and \(shareTypes.count) share types")

        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
            Task { @MainActor in
                if let error {
                    self.errorMessage = "Health authorization failed: \(error.localizedDescription)"
                    self.logger.error("Health authorization failed: \(error.localizedDescription, privacy: .public)")
                } else if !success {
                    self.logger.error("Health authorization request cancelled")
                }
                self.refreshHealthAuthorizationState()
            }
        }
    }
#else
    public var workoutPermissionDescription: String { "Unavailable" }
    public var heartPermissionDescription: String { "Unavailable" }
    public var needsHealthPermissionAction: Bool { false }
    public var canRequestHealthAuthorization: Bool { false }
    public func requestHealthAuthorization() {}
#endif

    /// Clears current session statistics.
    public func resetSessionStats() {
        sessionSamples.removeAll()
        sessionStartDate = nil
        sessionReachabilityFlipCount = 0
        sessionSummary = SessionSummary()
    }

    /// Writes the current session to a temporary CSV and returns its URL for sharing.
    public func sessionShareURL() -> URL? {
        guard !sessionSamples.isEmpty else { return nil }
        let id = sessionSignposter.beginInterval("SessionCSVPrepare")
        defer { sessionSignposter.endInterval("SessionCSVPrepare", id) }

        var rows: [String] = ["timestamp,latitude,longitude,h_accuracy_m,preset"]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        for sample in sessionSamples {
            let timestamp = formatter.string(from: sample.timestamp)
            let preset = sample.preset ?? ""
            rows.append([timestamp, String(sample.lat), String(sample.lon), String(format: "%.2f", sample.accuracy), preset].joined(separator: ","))
        }

        guard let data = rows.joined(separator: "\n").data(using: .utf8) else {
            logger.error("Failed to encode session CSV")
            return nil
        }

        let filename = "pawwatch-session-\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
        logger.log("Prepared session CSV rows=\(self.sessionSamples.count)")
            return url
        } catch {
            logger.error("Failed to write session CSV: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Private Helpers

    /// Starts a periodic monitor that flags when the Watch connection has gone stale.
    private func startStaleConnectionMonitor() {
        staleConnectionTask?.cancel()
        staleConnectionTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard let self = self else { return }
                self.checkForStaleConnection()
            }
        }
    }

    @MainActor
    private func checkForStaleConnection() {
        guard isWatchConnected else { return }
        guard let lastUpdateTime else { return }

        let elapsed = Date().timeIntervalSince(lastUpdateTime)
        let threshold: TimeInterval = 300 // 5 minutes

        if elapsed > threshold {
            if !isConnectionStale {
                isConnectionStale = true
                logger.warning("Watch connection stale (no updates for \(Int(elapsed))s)")
                scheduleStaleConnectionNotification()
            }
        } else if isConnectionStale {
            // Fresh data within threshold clears stale state.
            isConnectionStale = false
        }
    }

    private func scheduleStaleConnectionNotification() {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "PawWatch connection stale"
        content.body = "No signal from pawWatch for 5 minutes."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "pawwatch.stale-connection",
            content: content,
            trigger: nil
        )

        center.add(request) { [weak self] error in
            if let error {
                self?.logger.error("Failed to schedule stale connection notification: \(error.localizedDescription, privacy: .public)")
            }
        }
        #endif
    }

    /// Process incoming LocationFix and update state.
    private func handleLocationFix(_ locationFix: LocationFix, source: LocationUpdateSource = .watchConnectivity) {
        guard shouldAccept(locationFix) else { return }

        recordSequence(locationFix.sequence)

        var didUpdateLatest = false
        if let current = latestLocation {
            if locationFix.timestamp >= current.timestamp {
                latestLocation = locationFix
                didUpdateLatest = true
            }
        } else {
            latestLocation = locationFix
            didUpdateLatest = true
        }

        let previousUpdate = lastUpdateTime
        let isFreshUpdate = previousUpdate == nil || locationFix.timestamp >= previousUpdate!
        if didUpdateLatest, isFreshUpdate {
            lastUpdateTime = locationFix.timestamp
            isConnectionStale = false
            latestUpdateSource = source

            if source == .watchConnectivity {
                errorMessage = nil
            } else if errorMessage?.contains("unreachable") == true {
                errorMessage = "Apple Watch unreachable. Showing iCloud relay updates."
            }

            watchBatteryFraction = locationFix.batteryFraction
        }

        logger.debug("Received fix accuracy=\(locationFix.horizontalAccuracyMeters, privacy: .public)")
        signposter.emitEvent("FixReceived")

        insertIntoHistory(locationFix)
        appendSessionSample(locationFix)
        PerformanceMonitor.shared.recordRemoteFix(locationFix, watchReachable: isWatchReachable)

        // Sync to CloudKit for offline recovery (throttled to prevent rate limiting)
        // CR-001 FIX: Only sync every 5 minutes to prevent CloudKit throttling and battery drain
        if source == .watchConnectivity, didUpdateLatest {
            let now = Date()
            if lastCloudKitSync == nil || now.timeIntervalSince(lastCloudKitSync!) >= cloudKitSyncInterval {
                lastCloudKitSync = now
                Task.detached {
                    await CloudKitLocationSync.shared.saveLocation(locationFix)
                }
            }
        }
    }

    /// Acceptance filter for incoming fixes.
    /// Internal so unit tests can validate thresholds.
    func shouldAccept(_ fix: LocationFix) -> Bool {
        let policy = fixAcceptancePolicy
        if recentSequenceSet.contains(fix.sequence) {
            logger.debug("Dropping duplicate fix seq=\(fix.sequence)")
            return false
        }

        let staleness = Date().timeIntervalSince(fix.timestamp)
        if staleness > policy.maxFixStaleness {
            logger.info("Received historical fix (age=\(staleness)s) - accepting for trail")
        }

        if fix.horizontalAccuracyMeters > policy.maxHorizontalAccuracyMeters {
            logger.info("Dropping low-quality fix accuracy=\(fix.horizontalAccuracyMeters)")
            return false
        }

        if let current = latestLocation {
            // Only guard against wild jumps when timestamps are close.
            let deltaTime = abs(fix.timestamp.timeIntervalSince(current.timestamp))
            if deltaTime < 5 {
                let jump = distanceBetween(current.coordinate, fix.coordinate)
                if jump > policy.maxJumpDistanceMeters {
                    logger.info("Dropping implausible jump distance=\(jump)")
                    return false
                }
            }
        }

        return true
    }

    #if DEBUG
    /// Test-only hook to prime duplicate detection.
    internal func _testRecordSequence(_ sequence: Int) {
        recordSequence(sequence)
    }

    /// Test-only hook to seed a baseline location for jump filtering.
    internal func _testSetLatestLocation(_ fix: LocationFix?) {
        latestLocation = fix
    }
    #endif

    private func recordSequence(_ sequence: Int) {
        recentSequenceSet.insert(sequence)
        recentSequenceOrder.append(sequence)
        if recentSequenceOrder.count > recentSequenceCapacity {
            if let removed = recentSequenceOrder.first {
                recentSequenceOrder.removeFirst()
                recentSequenceSet.remove(removed)
            }
        }
    }

    private func insertIntoHistory(_ fix: LocationFix) {
        // Ring-buffer style history: append newest fixes and trim oldest
        locationHistory.append(fix)
        pruneHistoryIfNeeded()
    }

    private func distanceBetween(_ lhs: LocationFix.Coordinate, _ rhs: LocationFix.Coordinate) -> Double {
        let lhsLocation = CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
        let rhsLocation = CLLocation(latitude: rhs.latitude, longitude: rhs.longitude)
        return lhsLocation.distance(from: rhsLocation)
    }

    private func pruneHistoryIfNeeded() {
        let overflow = locationHistory.count - trailHistoryLimit
        guard overflow > 0 else { return }
        locationHistory.removeFirst(overflow)
    }

    private static func clampTrailHistoryLimit(_ value: Int) -> Int {
        let lower = trailHistoryLimitRange.lowerBound
        let upper = trailHistoryLimitRange.upperBound
        return min(max(value, lower), upper)
    }

    private func persistTrailHistoryLimit(_ value: Int) {
        sharedDefaults.set(value, forKey: trailHistoryLimitKey)
    }

    private func persistRuntimePreference(_ enabled: Bool) {
        sharedDefaults.set(enabled, forKey: runtimePreferenceKey)
    }

    private func applyRuntimePreferenceFromWatch(_ enabled: Bool) {
        guard enabled != runtimeOptimizationsEnabled else { return }
        runtimeOptimizationsEnabled = enabled
        persistRuntimePreference(enabled)
    }

    /// Decode a LocationFix from raw Data produced by the watch.
    nonisolated private func decodeLocationFix(from data: Data) -> LocationFix? {
        do {
            return try JSONDecoder().decode(LocationFix.self, from: data)
        } catch {
            Task { @MainActor in
                self.logger.error("Failed to decode LocationFix: \(error.localizedDescription, privacy: .public)")
                self.signposter.emitEvent("FixDecodeError")
                self.errorMessage = "Received invalid location data from Apple Watch."
            }
            return nil
        }
    }

    /// Convenience to decode raw data and hop back to the main actor.
    nonisolated private func handleLocationFixData(_ data: Data) {
        guard let fix = decodeLocationFix(from: data) else { return }

        Task { @MainActor in
            self.handleLocationFix(fix, source: .watchConnectivity)
        }
    }
}

// MARK: - WCSessionDelegate

#if canImport(WatchConnectivity)
extension PetLocationManager: WCSessionDelegate {

    /// WCSession activation completed.
    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Capture session reachability before Task to avoid data race
        let isReachable = session.isReachable

        Task { @MainActor in
            if let error = error {
                self.errorMessage = "Watch connection failed: \(error.localizedDescription)"
                self.logger.error("WCSession activation error: \(error.localizedDescription, privacy: .public)")
                self.isWatchConnected = false
            } else {
                self.isWatchConnected = (activationState == .activated)
                self.isWatchReachable = isReachable
                self.errorMessage = nil
                self.logger.log("WCSession activated (reachable=\(isReachable, privacy: .public))")
                if activationState == .activated {
                    self.sendRuntimePreferenceCommand(self.runtimeOptimizationsEnabled)
                    self.sendIdleCadenceCommand(self.idleCadencePreset)
                }
            }
        }
    }

    /// WCSession became inactive (iOS only).
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchConnected = false
        }
    }

    /// WCSession deactivated (iOS only).
    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        // Capture session reference before Task to avoid data race
        let sessionToReactivate = session

        Task { @MainActor in
            self.isWatchConnected = false
        }

        // Reactivate for new Apple Watch pairing (can be called on background thread)
        sessionToReactivate.activate()
    }

    /// Watch reachability changed.
    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        // Capture reachability status before Task to avoid data race
        let isReachable = session.isReachable

        Task { @MainActor in
            self.isWatchReachable = isReachable
            self.logger.log("Reachability changed: \(isReachable, privacy: .public)")
            self.sessionReachabilityFlipCount += 1
            self.recomputeSessionSummary()
            if let latest = self.latestLocation {
                PerformanceMonitor.shared.recordRemoteFix(latest, watchReachable: self.isWatchReachable)
            }
            if !isReachable {
                self.errorMessage = "Apple Watch unreachable. Latest data may be delayed."
            } else if self.errorMessage?.contains("unreachable") == true {
                self.errorMessage = nil
                self.sendRuntimePreferenceCommand(self.runtimeOptimizationsEnabled)
                self.sendIdleCadenceCommand(self.idleCadencePreset)
            }
        }
    }

    /// Received message from Apple Watch (real-time delivery).
    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        if let data = message[ConnectivityConstants.latestFix] as? Data {
            Task { @MainActor in
                self.isWatchConnected = true
                self.isWatchReachable = true
            }
            handleLocationFixData(data)
        }
    }

    /// Received queued user info from Apple Watch (FIFO background delivery).
    ///
    /// This is the primary path for fixes sent via `transferUserInfo` while the
    /// phone app is unreachable or suspended. Every fix the watch queues
    /// offline must be surfaced here when connectivity is restored.
    ///
    /// Supports both single fixes (latestFix) and batched fixes (batchedFixes)
    /// to prevent queue flooding from extended offline periods.
    nonisolated public func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String : Any]
    ) {
        Task { @MainActor in
            self.isWatchConnected = true
        }

        // Check for batched transfer (QUEUE FLOODING FIX)
        if let isBatched = userInfo[ConnectivityConstants.isBatched] as? Bool, isBatched {
            // New format: single Data payload containing an array of LocationFix.
            if let batchData = userInfo[ConnectivityConstants.batchedFixes] as? Data {
                do {
                    let fixes = try JSONDecoder().decode([LocationFix].self, from: batchData)
                    logger.notice("Received batched transfer with \(fixes.count) fixes (compact payload)")
                    Task { @MainActor in
                        fixes.forEach { self.handleLocationFix($0, source: .watchConnectivity) }
                    }
                } catch {
                    logger.error("Failed to decode batched LocationFix array: \(error.localizedDescription, privacy: .public)")
                }
                return
            }

            // Backward-compatible format: array of Data payloads.
            if let batchedData = userInfo[ConnectivityConstants.batchedFixes] as? [Data] {
                logger.notice("Received batched transfer with \(batchedData.count) fixes")
                for fixData in batchedData {
                    handleLocationFixData(fixData)
                }
                return
            }
        }

        // Handle single fix (backward compatible)
        if let data = userInfo[ConnectivityConstants.latestFix] as? Data {
            handleLocationFixData(data)
        }
    }

    /// Received application context from Apple Watch (guaranteed delivery).
    nonisolated public func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        let battery = applicationContext[ConnectivityConstants.batteryOnly] as? Double
        let modeRaw = applicationContext[ConnectivityConstants.trackingMode] as? String
        let locked = applicationContext[ConnectivityConstants.lockState] as? Bool
        let latest = applicationContext[ConnectivityConstants.latestFix] as? Data
        let runtimeEnabled = applicationContext[ConnectivityConstants.runtimeOptimizationsEnabled] as? Bool
        let runtimeCapable = applicationContext[ConnectivityConstants.supportsExtendedRuntime] as? Bool
        let idleHeartbeat = applicationContext[ConnectivityConstants.idleHeartbeatInterval] as? Double
        let idleFullFix = applicationContext[ConnectivityConstants.idleFullFixInterval] as? Double

        Task { @MainActor in
            if let battery { self.watchBatteryFraction = battery }
            if let modeRaw, let mode = TrackingMode(rawValue: modeRaw) {
                if self.trackingMode != mode {
                    self.trackingMode = mode
                    self.logFixAcceptancePolicy(reason: "watch-context")
                }
            }
            if battery != nil || modeRaw != nil || locked != nil {
                self.isWatchConnected = true
            }
            if let locked { self.isWatchLocked = locked }
            if let runtimeEnabled { self.applyRuntimePreferenceFromWatch(runtimeEnabled) }
            if let runtimeCapable { self.watchSupportsExtendedRuntime = runtimeCapable }
            if let idleHeartbeat { self.watchIdleHeartbeatInterval = idleHeartbeat }
            if let idleFullFix { self.watchIdleFullFixInterval = idleFullFix }
            if let latest {
                self.isWatchConnected = true
                self.handleLocationFixData(latest)
            }
        }
    }

    /// Received message data payload (preferred interactive path from the watch).
    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessageData messageData: Data
    ) {
        Task { @MainActor in
            self.isWatchConnected = true
            self.isWatchReachable = true
        }
        handleLocationFixData(messageData)
    }

    /// Received file transfer from Apple Watch (large payloads).
    nonisolated public func session(
        _ session: WCSession,
        didReceive file: WCSessionFile
    ) {
        // Capture file URL before Task to avoid data race
        let fileURL = file.fileURL

        Task { @MainActor in
            do {
                let data = try Data(contentsOf: fileURL)
                self.isWatchConnected = true
                self.handleLocationFixData(data)
            } catch {
                self.errorMessage = "Failed to decode file transfer: \(error.localizedDescription)"
            }
        }
    }
}
#endif

// MARK: - CLLocationManagerDelegate

extension PetLocationManager: CLLocationManagerDelegate {

    /// Owner's iPhone location updated.
    nonisolated public func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        Task { @MainActor in
            // CR-004 FIX: Use min(by:) for clarity - select location with smallest horizontal accuracy
            // horizontalAccuracy is a radius in meters, so LOWER is BETTER (more precise)
            if let bestLocation = locations.min(by: { $0.horizontalAccuracy < $1.horizontalAccuracy }) {
                self.ownerLocation = bestLocation
            }
        }
    }

    /// Location authorization changed.
    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Capture authorization status before Task to avoid data race
        let status = manager.authorizationStatus

        Task { @MainActor in
            self.locationAuthorizationStatus = status
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationManager.startUpdatingLocation()
            case .denied, .restricted:
                self.errorMessage = "Location permission denied. Enable in Settings to see distance."
            case .notDetermined:
                self.locationManager.requestWhenInUseAuthorization()
            @unknown default:
                break
            }
        }
    }

    /// Location update failed.
    nonisolated public func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            // Only show error if it's not a transient failure
            if (error as? CLError)?.code != .locationUnknown {
                self.errorMessage = "Owner location unavailable: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Session Metrics Helpers

extension PetLocationManager {
    private struct SessionSample {
        let timestamp: Date
        let lat: Double
        let lon: Double
        let accuracy: Double
        let preset: String?
    }

    public struct SessionSummary: Sendable {
        public var fixCount: Int = 0
        public var averageIntervalSec: Double = 0
        public var medianAccuracy: Double = 0
        public var p90Accuracy: Double = 0
        public var maxAccuracy: Double = 0
        public var reachabilityChanges: Int = 0
        public var presetCounts: [String: Int] = [:]
        public var durationSec: Double = 0
    }

    private func appendSessionSample(_ fix: LocationFix) {
        if sessionStartDate == nil {
            sessionStartDate = fix.timestamp
        }
        let sample = SessionSample(
            timestamp: fix.timestamp,
            lat: fix.coordinate.latitude,
            lon: fix.coordinate.longitude,
            accuracy: fix.horizontalAccuracyMeters,
            preset: fix.trackingPreset
        )
        sessionSamples.append(sample)
        if sessionSamples.count > maxSessionSamples {
            sessionSamples.removeFirst(sessionSamples.count - maxSessionSamples)
        }
        recomputeSessionSummary()
    }

    private func recomputeSessionSummary() {
        let count = sessionSamples.count
        guard count > 0 else {
            sessionSummary = SessionSummary(reachabilityChanges: sessionReachabilityFlipCount)
            return
        }

        let timestamps = sessionSamples.map { $0.timestamp }
        guard let firstTimestamp = timestamps.first,
              let lastTimestamp = timestamps.last else { return }
        let start = sessionStartDate ?? firstTimestamp
        let duration = max(0, lastTimestamp.timeIntervalSince(start))
        let intervals = zip(timestamps.dropFirst(), timestamps).map { $0.0.timeIntervalSince($0.1) }
        let avgInterval = intervals.isEmpty ? 0 : intervals.reduce(0, +) / Double(intervals.count)

        let accuracies = sessionSamples.map { $0.accuracy }.sorted()
        let medianAcc = median(of: accuracies)
        let p90Acc = percentile(of: accuracies, percent: 90)
        let maxAcc = accuracies.last ?? 0

        var histogram: [String: Int] = [:]
        for preset in sessionSamples.compactMap({ $0.preset }) {
            histogram[preset, default: 0] += 1
        }

        sessionSummary = SessionSummary(
            fixCount: count,
            averageIntervalSec: avgInterval,
            medianAccuracy: medianAcc,
            p90Accuracy: p90Acc,
            maxAccuracy: maxAcc,
            reachabilityChanges: sessionReachabilityFlipCount,
            presetCounts: histogram,
            durationSec: duration
        )
    }

    private func median(of values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mid = values.count / 2
        if values.count % 2 == 1 {
            return values[mid]
        }
        return 0.5 * (values[mid - 1] + values[mid])
    }

    private func percentile(of values: [Double], percent: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        if percent <= 0 { return values.first ?? 0 }
        if percent >= 100 { return values.last ?? 0 }
        let rank = Int(ceil(percent / 100 * Double(values.count))) - 1
        return values[max(0, min(values.count - 1, rank))]
    }
}

#endif
