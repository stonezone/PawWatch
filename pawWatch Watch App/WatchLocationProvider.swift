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
import pawWatchFeature

#if os(watchOS)
@preconcurrency import CoreLocation
@preconcurrency import HealthKit
@preconcurrency import WatchConnectivity
@preconcurrency import WatchKit

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
public final class WatchLocationProvider: NSObject, Sendable {
    
    // MARK: - Public Properties
    
    public weak var delegate: (any WatchLocationProviderDelegate)?
    
    // MARK: - Private Properties
    
    private let workoutStore = HKHealthStore()
    private let locationManager = CLLocationManager()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var wcSession: WCSession { WCSession.default }
    private let encoder = JSONEncoder()
    private let fileManager = FileManager.default
    
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
    
    /// Accuracy bypass threshold: When horizontal accuracy changes by more than 5 meters,
    /// immediately push application context regardless of time throttle. This ensures
    /// critical accuracy improvements (e.g., GPS lock acquisition) are delivered promptly.
    private let contextAccuracyDelta: Double = 5.0  // meters
    
    /// Tracks active file transfers to retry on failure and clean up temp files
    private var activeFileTransfers: [WCSessionFileTransfer: (url: URL, fix: LocationFix)] = [:]
    
    /// Most recent fix, used to satisfy manual refresh requests from the phone.
    private var latestFix: LocationFix?
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        locationManager.delegate = self
        encoder.outputFormatting = [.withoutEscapingSlashes]
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
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
        requestAuthorizationsIfNeeded()
        startWorkoutSession(activity: activity)
        configureWatchConnectivity()
        
        // Configure CLLocationManager for maximum update frequency
        // - activityType .other: Provides most frequent updates (no activity-based throttling)
        // - desiredAccuracy Best: Requests highest precision GPS available
        // - distanceFilter None: No distance-based throttling (get all fixes)
        // Result: ~1Hz native Apple Watch GPS update rate
        locationManager.activityType = .other
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        
        locationManager.startUpdatingLocation()
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
    private func configureWatchConnectivity() {
        if WCSession.isSupported() {
            print("[WatchLocationProvider] Activating WCSession")
            wcSession.delegate = self
            wcSession.activate()
        } else {
            print("[WatchLocationProvider] WCSession not supported")
        }
    }
    
    /// Publishes a location fix using triple-path WatchConnectivity strategy.
    ///
    /// Triple-path messaging strategy:
    /// 1. Application Context: Always updated (0.5s throttle + accuracy bypass)
    ///    - Works in background
    ///    - Latest-only (overwrites previous)
    ///    - Throttled to prevent overwhelming the system
    /// 2. Interactive Message: Attempted first if phone is reachable
    ///    - Foreground only
    ///    - Immediate delivery
    ///    - Falls back to file transfer on failure
    /// 3. File Transfer: Used when phone not reachable or interactive fails
    ///    - Works in background
    ///    - Queued delivery
    ///    - Guaranteed delivery (retries on failure)
    ///
    /// - Parameter fix: The location fix to publish
    private func publishFix(_ fix: LocationFix) {
        latestFix = fix
        transmitFix(fix, includeContext: true, notifyDelegate: true)
    }

    /// Sends the provided fix to the paired iPhone, optionally updating context or notifying delegate.
    private func transmitFix(
        _ fix: LocationFix,
        includeContext: Bool,
        notifyDelegate: Bool
    ) {
        if notifyDelegate {
            Task { @MainActor in
                delegate?.didProduce(fix)
            }
        }
        
        print("[WatchLocationProvider] Session state: \(wcSession.activationState.rawValue), reachable: \(wcSession.isReachable)")
        
        guard wcSession.activationState == .activated else {
            print("[WatchLocationProvider] Session not activated")
            return
        }
        
        if includeContext {
            updateApplicationContextWithFix(fix)
        }
        
        if wcSession.isReachable {
            do {
                let data = try encoder.encode(fix)
                print("[WatchLocationProvider] Sending interactive message (\(data.count) bytes)")
                
                let payload: [String: Any] = ["latestFix": data]
                wcSession.sendMessage(payload, replyHandler: nil) { [weak self] error in
                    print("[WatchLocationProvider] Interactive send failed: \(error.localizedDescription), falling back to file transfer")
                    self?.queueBackgroundTransfer(for: fix)
                }
            } catch {
                print("[WatchLocationProvider] Encode error: \(error.localizedDescription)")
                Task { @MainActor in
                    delegate?.didFail(error)
                }
                queueBackgroundTransfer(for: fix)
            }
        } else {
            print("[WatchLocationProvider] Not reachable, using file transfer")
            queueBackgroundTransfer(for: fix)
        }
    }
    
    /// Updates WatchConnectivity application context with latest location fix.
    ///
    /// Throttling Logic:
    /// - Skip if same sequence number already sent (prevents duplicates)
    /// - Skip if less than 0.5s since last push AND accuracy change < 5m
    /// - Always send if accuracy improved by 5m+ (bypass time throttle)
    ///
    /// The 0.5s throttle allows ~2Hz max rate while capturing all 1Hz Watch GPS fixes.
    /// Accuracy bypass ensures critical GPS lock improvements are delivered immediately.
    ///
    /// - Parameter fix: The location fix to send via application context
    private func updateApplicationContextWithFix(_ fix: LocationFix) {
        guard wcSession.activationState == .activated else { return }
        
        let now = Date()
        
        // Skip if same sequence already sent (duplicate prevention)
        if lastContextSequence == fix.sequence {
            return
        }
        
        // Apply 0.5s throttle with accuracy bypass
        // Skip update if:
        // 1. Less than 0.5s since last push, AND
        // 2. Accuracy change is less than 5m threshold
        if let lastPush = lastContextPushDate,
           now.timeIntervalSince(lastPush) < contextPushInterval,
           let lastAccuracy = lastContextAccuracy,
           abs(lastAccuracy - fix.horizontalAccuracyMeters) < contextAccuracyDelta {
            return
        }
        
        do {
            let data = try encoder.encode(fix)
            let metadata: [String: Any] = [
                "seq": fix.sequence,
                "timestamp": fix.timestamp.timeIntervalSince1970,
                "accuracy": fix.horizontalAccuracyMeters
            ]
            let context: [String: Any] = [
                "latestFix": data,
                "metadata": metadata
            ]
            
            try wcSession.updateApplicationContext(context)
            print("[WatchLocationProvider] Updated application context with latest fix")
            
            // Update throttle state
            lastContextSequence = fix.sequence
            lastContextPushDate = now
            lastContextAccuracy = fix.horizontalAccuracyMeters
        } catch {
            print("[WatchLocationProvider] Failed to update context: \(error.localizedDescription)")
            // Non-fatal - other delivery paths will still work
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
            
            let transfer = wcSession.transferFile(url, metadata: ["sequence": fix.sequence])
            activeFileTransfers[transfer] = (url, fix)
            
            print("[WatchLocationProvider] Queued file transfer")
        } catch {
            Task { @MainActor in
                delegate?.didFail(error)
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WatchLocationProvider: CLLocationManagerDelegate {
    
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
            
            let device = WKInterfaceDevice.current()
            
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
                batteryFraction: device.batteryLevel >= 0 ? Double(device.batteryLevel) : 0,
                sequence: Int(Int64(Date().timeIntervalSinceReferenceDate * 1000) % Int64(Int.max))
            )
            
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
        Task { @MainActor [weak self] in
            print("[WatchLocationProvider] WCSession activation completed with state: \(activationState.rawValue), error: \(error?.localizedDescription ?? "none")")
            
            if let error {
                self?.delegate?.didFail(error)
            }
        }
    }
    
    /// Handles changes in phone reachability status.
    /// Intentionally left blank - reachability is checked during send.
    ///
    /// - Parameter session: The WatchConnectivity session
    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {}
    
    /// Handles incoming message dictionaries from the phone (e.g., manual refresh requests).
    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: (([String: Any]) -> Void)? = nil
    ) {
        guard let action = message["action"] as? String else {
            replyHandler?(["status": "ignored"])
            return
        }
        
        switch action {
        case "requestLocation":
            Task { @MainActor in
                if let fix = self.latestFix {
                    self.transmitFix(fix, includeContext: false, notifyDelegate: false)
                } else {
                    self.locationManager.requestLocation()
                }
            }
        default:
            break
        }
    }
    
    /// Handles incoming message data (not currently used).
    nonisolated public func session(_ session: WCSession, didReceiveMessageData messageData: Data) {}
    
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
                print("[WatchLocationProvider] File transfer failed: \(error.localizedDescription). Retrying…")
                self.queueBackgroundTransfer(for: record.fix)
            } else {
                print("[WatchLocationProvider] File transfer completed successfully")
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
            guard toState == .ended || toState == .stopped else { return }
            
            if let builder = self.workoutBuilder {
                builder.endCollection(withEnd: date) { [weak delegate = self.delegate] _, error in
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
        }
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
public final class WatchLocationProvider: Sendable {
    public weak var delegate: (any WatchLocationProviderDelegate)?
    
    public init() {}
    
    public func startWorkoutAndStreaming(activity: Int = 0) {
        assertionFailure("WatchLocationProvider is only available on watchOS")
    }
    
    public func stop() {}
}

#endif
