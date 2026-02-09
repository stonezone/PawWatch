//
//  WatchGPSManager.swift
//  pawWatch
//
//  Purpose: Manages GPS acquisition, accuracy filtering, and HealthKit workout sessions
//           for extended runtime location tracking on Apple Watch.
//
//  Extracted from WatchLocationProvider.swift as part of architectural refactoring.
//  Author: Refactored for modular architecture
//  Created: 2025-02-09
//  Swift: 6.2
//  Platform: watchOS 26.1+
//

import Foundation
#if os(watchOS)
@preconcurrency import CoreLocation
@preconcurrency import HealthKit
@preconcurrency import WatchKit
import OSLog

// MARK: - Tracking Preset Configuration

enum TrackingPreset: String {
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

// MARK: - GPS Manager Delegate

@MainActor
protocol WatchGPSManagerDelegate: AnyObject, Sendable {
    /// Called when a new location update is received
    func gpsManager(_ manager: WatchGPSManager, didUpdateLocation location: CLLocation)

    /// Called when GPS authorization status changes
    func gpsManager(_ manager: WatchGPSManager, didChangeAuthorizationStatus status: CLAuthorizationStatus)

    /// Called when GPS encounters an error
    func gpsManager(_ manager: WatchGPSManager, didFailWithError error: Error)

    /// Called when workout session state changes
    func gpsManager(_ manager: WatchGPSManager, workoutDidChangeTo state: HKWorkoutSessionState)
}

// MARK: - Watch GPS Manager

/// Manages GPS capture and HealthKit workout sessions on Apple Watch.
///
/// Responsibilities:
/// - Configure and manage CLLocationManager for GPS updates
/// - Start/stop HealthKit workout sessions for extended runtime
/// - Apply tracking presets (aggressive/balanced/saver)
/// - Filter and validate GPS accuracy
/// - Handle location authorization
@MainActor
final class WatchGPSManager: NSObject {

    // MARK: - Properties

    weak var delegate: WatchGPSManagerDelegate?

    private let locationManager = CLLocationManager()
    private let workoutStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    private let logger = Logger(subsystem: PawWatchLog.subsystem, category: "WatchGPSManager")
    private let signposter = OSSignposter(subsystem: PawWatchLog.subsystem, category: "WatchGPSManager")

    private(set) var currentPreset: TrackingPreset = .aggressive
    private(set) var isTracking = false

    // MARK: - Initialization

    override init() {
        super.init()
        locationManager.delegate = self
    }

    // MARK: - Public Methods

    /// Requests location authorization if not already granted
    func requestAuthorization() {
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            logger.log("Location authorization already granted")
        case .denied, .restricted:
            logger.error("Location authorization denied or restricted")
            delegate?.gpsManager(self, didChangeAuthorizationStatus: status)
        @unknown default:
            break
        }
    }

    /// Requests HealthKit authorization for workout sessions
    func requestHealthKitAuthorization() async throws {
        var readTypes: Set<HKObjectType> = []
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(heartRate)
        }

        var shareTypes: Set<HKSampleType> = []
        shareTypes.insert(HKObjectType.workoutType())

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            workoutStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Starts a HealthKit workout session and begins GPS updates
    func startWorkoutSession(activity: HKWorkoutActivityType = .other) throws {
        guard !isTracking else {
            logger.log("GPS already tracking")
            return
        }

        // Check if we already have an active session
        if let existingSession = workoutSession,
           existingSession.state == .running || existingSession.state == .prepared {
            logger.log("Workout session already active")
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activity
        configuration.locationType = .outdoor

        let session = try HKWorkoutSession(healthStore: workoutStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: workoutStore,
            workoutConfiguration: configuration
        )

        session.delegate = self
        builder.delegate = self

        workoutSession = session
        workoutBuilder = builder

        session.startActivity(with: Date())
        builder.beginCollection(withStart: Date()) { _, error in
            if let error {
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.delegate?.gpsManager(self, didFailWithError: error)
                }
            }
        }

        logger.log("Workout session started")
    }

    /// Starts location updates with current preset configuration
    func startUpdatingLocation() {
        guard !isTracking else { return }

        // Check authorization before starting
        let status = locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            logger.error("Cannot start updates: authorization not granted")
            return
        }

        applyPreset(currentPreset, force: true)
        locationManager.startUpdatingLocation()
        isTracking = true

        logger.log("GPS updates started with preset: \(self.currentPreset.rawValue)")
    }

    /// Stops location updates
    func stopUpdatingLocation() {
        guard isTracking else { return }

        locationManager.stopUpdatingLocation()
        isTracking = false

        logger.log("GPS updates stopped")
    }

    /// Stops workout session and cleans up HealthKit resources
    func stopWorkoutSession() {
        let builder = workoutBuilder
        let session = workoutSession

        workoutSession = nil
        workoutBuilder = nil

        if let builder {
            builder.endCollection(withEnd: Date()) { _, error in
                if let error {
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        self.delegate?.gpsManager(self, didFailWithError: error)
                    }
                }
                builder.finishWorkout { _, finishError in
                    if let finishError {
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            self.delegate?.gpsManager(self, didFailWithError: finishError)
                        }
                    }
                }
            }
        }

        if let session, session.state == .running || session.state == .prepared {
            session.end()
        }

        logger.log("Workout session stopped")
    }

    /// Applies a tracking preset to configure GPS accuracy and filtering
    func applyPreset(_ preset: TrackingPreset, force: Bool = false) {
        guard force || preset != currentPreset else { return }

        currentPreset = preset
        locationManager.activityType = preset.activityType
        locationManager.desiredAccuracy = preset.desiredAccuracy
        locationManager.distanceFilter = preset.distanceFilter

        logger.log("Applied GPS preset: \(preset.rawValue)")
        signposter.emitEvent("PresetChange")
    }

    /// Requests a single location update
    func requestLocation() {
        locationManager.requestLocation()
    }

    /// Returns current authorization status
    var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }
}

// MARK: - CLLocationManagerDelegate

extension WatchGPSManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.logger.log("Location authorization changed: \(status.rawValue)")
            self.delegate?.gpsManager(self, didChangeAuthorizationStatus: status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            guard let self, let latest = locations.last else { return }
            self.delegate?.gpsManager(self, didUpdateLocation: latest)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.logger.error("Location error: \(error.localizedDescription)")
            self.delegate?.gpsManager(self, didFailWithError: error)
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchGPSManager: HKWorkoutSessionDelegate {

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.logger.log("Workout session state: \(fromState.rawValue) → \(toState.rawValue)")
            self.delegate?.gpsManager(self, workoutDidChangeTo: toState)
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.logger.error("Workout session error: \(error.localizedDescription)")
            self.delegate?.gpsManager(self, didFailWithError: error)
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchGPSManager: HKLiveWorkoutBuilderDelegate {

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        // Data collection events not needed for GPS tracking
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Event collection not needed for GPS tracking
    }
}

#endif
