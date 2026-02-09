//
//  PerformanceInstrumentation.swift
//  pawWatch
//
//  os_signpost instrumentation for critical performance paths
//  Tracks: GPS acquisition, WatchConnectivity relay, CloudKit sync
//

import Foundation
import OSLog

/// Performance instrumentation using os_signpost for Instruments analysis
///
/// Provides signpost intervals and events for critical paths:
/// - GPS fix acquisition (Watch → iPhone relay)
/// - WatchConnectivity message delivery
/// - CloudKit synchronization operations
/// - Location prediction calculations
/// - Geofence boundary checks
///
/// ## Usage in Instruments
/// 1. Profile app with Instruments
/// 2. Add "os_signpost" instrument
/// 3. Filter by subsystem: `com.pawwatch.performance`
/// 4. Analyze interval durations and event frequencies
public enum PerformanceInstrumentation {

    // MARK: - Signposters

    /// GPS fix acquisition signposter (Watch-side location capture)
    public static let gpsAcquisition = OSSignposter(
        subsystem: "com.pawwatch.performance",
        category: "GPSAcquisition"
    )

    /// WatchConnectivity relay signposter (Watch → iPhone transmission)
    public static let watchConnectivity = OSSignposter(
        subsystem: "com.pawwatch.performance",
        category: "WatchConnectivity"
    )

    /// CloudKit sync signposter (iPhone → iCloud persistence)
    public static let cloudKitSync = OSSignposter(
        subsystem: "com.pawwatch.performance",
        category: "CloudKitSync"
    )

    /// Location prediction signposter (dead reckoning calculation)
    public static let locationPrediction = OSSignposter(
        subsystem: "com.pawwatch.performance",
        category: "LocationPrediction"
    )

    /// Geofence check signposter (boundary crossing detection)
    public static let geofenceCheck = OSSignposter(
        subsystem: "com.pawwatch.performance",
        category: "GeofenceCheck"
    )

    /// Location processing signposter (validation, filtering, history)
    public static let locationProcessing = OSSignposter(
        subsystem: "com.pawwatch.performance",
        category: "LocationProcessing"
    )

    // MARK: - GPS Acquisition

    /// Begin GPS fix acquisition interval (called when CLLocationManager requests location)
    @inlinable
    public static func beginGPSAcquisition() -> OSSignpostIntervalState {
        let state = gpsAcquisition.beginInterval("GPSFixAcquisition")
        gpsAcquisition.emitEvent("GPSRequestStarted")
        return state
    }

    /// End GPS fix acquisition interval (called when location received)
    @inlinable
    public static func endGPSAcquisition(_ state: OSSignpostIntervalState, accuracy: Double) {
        gpsAcquisition.emitEvent("GPSFixReceived", "accuracy: \(accuracy)m")
        gpsAcquisition.endInterval("GPSFixAcquisition", state)
    }

    // MARK: - WatchConnectivity Relay

    /// Begin WatchConnectivity message send interval
    @inlinable
    public static func beginWatchConnectivitySend(path: String) -> OSSignpostIntervalState {
        let state = watchConnectivity.beginInterval("MessageSend", id: watchConnectivity.makeSignpostID())
        watchConnectivity.emitEvent("SendStarted", "path: \(path)")
        return state
    }

    /// End WatchConnectivity message send interval
    @inlinable
    public static func endWatchConnectivitySend(_ state: OSSignpostIntervalState, success: Bool) {
        let result = success ? "success" : "failure"
        watchConnectivity.emitEvent("SendCompleted", "result: \(result)")
        watchConnectivity.endInterval("MessageSend", state)
    }

    /// Record WatchConnectivity reachability change event
    @inlinable
    public static func recordReachabilityChange(reachable: Bool) {
        let status = reachable ? "reachable" : "unreachable"
        watchConnectivity.emitEvent("ReachabilityChanged", "status: \(status)")
    }

    // MARK: - CloudKit Sync

    /// Begin CloudKit upload interval
    @inlinable
    public static func beginCloudKitUpload() -> OSSignpostIntervalState {
        let state = cloudKitSync.beginInterval("CloudKitUpload")
        cloudKitSync.emitEvent("UploadStarted")
        return state
    }

    /// End CloudKit upload interval
    @inlinable
    public static func endCloudKitUpload(_ state: OSSignpostIntervalState, success: Bool, recordCount: Int = 1) {
        let result = success ? "success" : "failure"
        cloudKitSync.emitEvent("UploadCompleted", "result: \(result), records: \(recordCount)")
        cloudKitSync.endInterval("CloudKitUpload", state)
    }

    /// Begin CloudKit download/recovery interval
    @inlinable
    public static func beginCloudKitRecovery() -> OSSignpostIntervalState {
        let state = cloudKitSync.beginInterval("CloudKitRecovery")
        cloudKitSync.emitEvent("RecoveryStarted")
        return state
    }

    /// End CloudKit download/recovery interval
    @inlinable
    public static func endCloudKitRecovery(_ state: OSSignpostIntervalState, recovered: Bool) {
        let result = recovered ? "data_recovered" : "no_data"
        cloudKitSync.emitEvent("RecoveryCompleted", "result: \(result)")
        cloudKitSync.endInterval("CloudKitRecovery", state)
    }

    /// Record CloudKit throttling event
    @inlinable
    public static func recordCloudKitThrottle(timeSinceLastSync: TimeInterval) {
        cloudKitSync.emitEvent("UploadThrottled", "time_since_last: \(Int(timeSinceLastSync))s")
    }

    // MARK: - Location Prediction

    /// Begin location prediction calculation interval
    @inlinable
    public static func beginLocationPrediction() -> OSSignpostIntervalState {
        let state = locationPrediction.beginInterval("PredictionCalculation")
        locationPrediction.emitEvent("PredictionStarted")
        return state
    }

    /// End location prediction calculation interval
    @inlinable
    public static func endLocationPrediction(_ state: OSSignpostIntervalState, confidence: Double) {
        locationPrediction.emitEvent("PredictionCompleted", "confidence: \(confidence)")
        locationPrediction.endInterval("PredictionCalculation", state)
    }

    /// Record prediction fallback event (GPS unavailable)
    @inlinable
    public static func recordPredictionFallback(reason: String) {
        locationPrediction.emitEvent("FallbackToPrediction", "reason: \(reason)")
    }

    // MARK: - Geofence Monitoring

    /// Begin geofence boundary check interval
    @inlinable
    public static func beginGeofenceCheck(zoneCount: Int) -> OSSignpostIntervalState {
        let state = geofenceCheck.beginInterval("BoundaryCheck")
        geofenceCheck.emitEvent("CheckStarted", "zones: \(zoneCount)")
        return state
    }

    /// End geofence boundary check interval
    @inlinable
    public static func endGeofenceCheck(_ state: OSSignpostIntervalState, violations: Int) {
        geofenceCheck.emitEvent("CheckCompleted", "violations: \(violations)")
        geofenceCheck.endInterval("BoundaryCheck", state)
    }

    /// Record geofence boundary crossing event
    @inlinable
    public static func recordBoundaryCrossing(zoneName: String, entered: Bool) {
        if entered {
            geofenceCheck.emitEvent("ZoneEntered", "zone: \(zoneName)")
        } else {
            geofenceCheck.emitEvent("ZoneExited", "zone: \(zoneName)")
        }
    }

    // MARK: - Location Processing

    /// Begin location fix processing interval (validation, filtering, storage)
    @inlinable
    public static func beginLocationProcessing(sequence: Int) -> OSSignpostIntervalState {
        let state = locationProcessing.beginInterval("FixProcessing")
        locationProcessing.emitEvent("ProcessingStarted", "sequence: \(sequence)")
        return state
    }

    /// End location fix processing interval
    @inlinable
    public static func endLocationProcessing(_ state: OSSignpostIntervalState, accepted: Bool) {
        let result = accepted ? "accepted" : "rejected"
        locationProcessing.emitEvent("ProcessingCompleted", "result: \(result)")
        locationProcessing.endInterval("FixProcessing", state)
    }

    /// Record fix rejection event
    @inlinable
    public static func recordFixRejection(reason: String, sequence: Int) {
        locationProcessing.emitEvent("FixRejected", "reason: \(reason), sequence: \(sequence)")
    }

    /// Record duplicate sequence detection
    @inlinable
    public static func recordDuplicateSequence(sequence: Int) {
        locationProcessing.emitEvent("DuplicateSequence", "sequence: \(sequence)")
    }

    /// Record history pruning event
    @inlinable
    public static func recordHistoryPruning(removed: Int, remaining: Int) {
        locationProcessing.emitEvent("HistoryPruned", "removed: \(removed), remaining: \(remaining)")
    }

    // MARK: - Performance Events

    /// Record battery level event (for correlation with performance)
    @inlinable
    public static func recordBatteryLevel(_ level: Double, device: String) {
        let signposter = OSSignposter(subsystem: "com.pawwatch.performance", category: "Battery")
        signposter.emitEvent("BatteryLevel", "level: \(Int(level * 100))%, device: \(device)")
    }

    /// Record session lifecycle event
    @inlinable
    public static func recordSessionEvent(_ event: StaticString, detail: String = "") {
        let signposter = OSSignposter(subsystem: "com.pawwatch.performance", category: "Session")
        if detail.isEmpty {
            signposter.emitEvent(event)
        } else {
            signposter.emitEvent(event, "\(detail)")
        }
    }

    /// Record critical error event
    @inlinable
    public static func recordError(_ category: String, detail: String) {
        let signposter = OSSignposter(subsystem: "com.pawwatch.performance", category: "Errors")
        signposter.emitEvent("Error", "\(category): \(detail)")
    }
}

// MARK: - Convenience Extensions

extension OSSignposter {
    /// Emit event with optional metadata string
    @inlinable
    func emitEventWithMetadata(_ name: StaticString, _ metadata: String = "") {
        if metadata.isEmpty {
            self.emitEvent(name)
        } else {
            self.emitEvent(name, "\(metadata)")
        }
    }
}
