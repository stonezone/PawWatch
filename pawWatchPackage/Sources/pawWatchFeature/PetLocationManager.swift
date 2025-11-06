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

import Foundation
import CoreLocation
import Observation

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

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

    // MARK: - Published State

    /// Most recent GPS fix from Apple Watch (nil if no data received)
    public private(set) var latestLocation: LocationFix?

    /// Last 100 GPS fixes for trail visualization (newest first)
    public private(set) var locationHistory: [LocationFix] = []

    /// WatchConnectivity session status
    public private(set) var isWatchConnected: Bool = false

    /// Whether WCSession is reachable for immediate message delivery
    public private(set) var isWatchReachable: Bool = false

    /// Timestamp of last received GPS fix
    public private(set) var lastUpdateTime: Date?

    /// Current owner location from iPhone GPS (nil if not yet obtained)
    public private(set) var ownerLocation: CLLocation?

    /// Error message for connection issues (nil if no error)
    public private(set) var errorMessage: String?

    // MARK: - Constants

    private let maxHistoryCount = 100 // Trail history limit

    // MARK: - Dependencies

    #if canImport(WatchConnectivity)
    private let session: WCSession
    #endif
    private let locationManager: CLLocationManager

    // MARK: - Initialization

    /// Initialize PetLocationManager with WatchConnectivity and CoreLocation.
    /// Automatically activates WCSession if supported.
    public override init() {
        #if canImport(WatchConnectivity)
        self.session = WCSession.default
        #endif
        self.locationManager = CLLocationManager()

        super.init()

        // Setup WatchConnectivity
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        } else {
            errorMessage = "WatchConnectivity not supported on this device"
        }
        #else
        errorMessage = "WatchConnectivity not available in this build"
        #endif

        // Setup CoreLocation for owner position
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - Public API

    /// Calculate distance between owner (iPhone) and pet (Watch) in meters.
    /// Returns nil if either location is unavailable.
    public var distanceFromOwner: Double? {
        guard let ownerLoc = ownerLocation,
              let petLoc = latestLocation else {
            return nil
        }

        // Convert LocationFix to CLLocation for distance calculation
        let petCLLocation = CLLocation(
            latitude: petLoc.coordinate.latitude,
            longitude: petLoc.coordinate.longitude
        )

        return ownerLoc.distance(from: petCLLocation)
    }

    /// Battery level as percentage (0-100)
    public var batteryLevel: Double {
        latestLocation?.batteryFraction ?? 0.0
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
    public func requestUpdate() {
        #if canImport(WatchConnectivity)
        guard isWatchReachable else {
            errorMessage = "Apple Watch not reachable. Check Bluetooth connection."
            return
        }

        // Send request message to Watch
        session.sendMessage(
            ["action": "requestLocation"],
            replyHandler: { reply in
                Task { @MainActor in
                    // Watch responded successfully
                    self.errorMessage = nil
                }
            },
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

    // MARK: - Private Helpers

    /// Process incoming LocationFix and update state.
    private func handleLocationFix(_ locationFix: LocationFix) {
        // Update latest location
        latestLocation = locationFix
        lastUpdateTime = Date()
        errorMessage = nil

        // Add to history (newest first)
        locationHistory.insert(locationFix, at: 0)

        // Trim history to last 100 fixes
        if locationHistory.count > maxHistoryCount {
            locationHistory = Array(locationHistory.prefix(maxHistoryCount))
        }
    }

    /// Decode LocationFix from dictionary (WCSession message format).
    private func decodeLocationFix(from dictionary: [String: Any]) -> LocationFix? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dictionary) else {
            errorMessage = "Failed to serialize location data"
            return nil
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(LocationFix.self, from: jsonData)
        } catch {
            errorMessage = "Failed to decode LocationFix: \(error.localizedDescription)"
            return nil
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
        Task { @MainActor in
            if let error = error {
                self.errorMessage = "Watch connection failed: \(error.localizedDescription)"
                self.isWatchConnected = false
            } else {
                self.isWatchConnected = (activationState == .activated)
                self.isWatchReachable = session.isReachable
                self.errorMessage = nil
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
        Task { @MainActor in
            self.isWatchConnected = false
            // Reactivate for new Apple Watch pairing
            session.activate()
        }
    }

    /// Watch reachability changed.
    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
        }
    }

    /// Received message from Apple Watch (real-time delivery).
    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            if let locationFix = self.decodeLocationFix(from: message) {
                self.handleLocationFix(locationFix)
            }
        }
    }

    /// Received application context from Apple Watch (guaranteed delivery).
    nonisolated public func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            if let locationFix = self.decodeLocationFix(from: applicationContext) {
                self.handleLocationFix(locationFix)
            }
        }
    }

    /// Received file transfer from Apple Watch (large payloads).
    nonisolated public func session(
        _ session: WCSession,
        didReceive file: WCSessionFile
    ) {
        Task { @MainActor in
            do {
                let data = try Data(contentsOf: file.fileURL)
                let decoder = JSONDecoder()
                let locationFix = try decoder.decode(LocationFix.self, from: data)
                self.handleLocationFix(locationFix)
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
            // Use most recent location with best accuracy
            if let bestLocation = locations.max(by: { $0.horizontalAccuracy > $1.horizontalAccuracy }) {
                self.ownerLocation = bestLocation
            }
        }
    }

    /// Location authorization changed.
    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus

            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()
            case .denied, .restricted:
                self.errorMessage = "Location permission denied. Enable in Settings to see distance."
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
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
