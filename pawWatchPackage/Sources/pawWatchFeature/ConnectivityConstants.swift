//
//  ConnectivityConstants.swift
//  pawWatchFeature
//
//  Purpose: centralized constants for WatchConnectivity keys and values
//  to ensure type safety and consistency between iOS and watchOS.
//

import Foundation

public enum ConnectivityConstants {
    // MARK: - Keys
    public static let action = "action"
    public static let payload = "payload"
    public static let timestamp = "timestamp"
    public static let sequence = "sequence"
    public static let latestFix = "latestFix"
    public static let error = "error"
    
    // MARK: - Actions
    public static let requestLocation = "requestLocation"
    public static let pushRequestLocation = "request-location"
    public static let stopTracking = "stop-tracking"
    public static let setMode = "setMode"
    public static let setRuntimeOptimizations = "setRuntimeOptimizations"
    public static let setIdleCadence = "setIdleCadence"
    
    // MARK: - Parameters
    public static let background = "background"
    public static let pushTriggered = "pushTriggered"
    public static let force = "force"
    public static let mode = "mode"
    public static let enabled = "enabled"
    
    public static let heartbeatInterval = "heartbeatInterval"
    public static let fullFixInterval = "fullFixInterval"
    
    public static let batteryOnly = "batteryOnly"
    public static let trackingMode = "trackingMode"
    public static let lockState = "lockState"
    public static let runtimeOptimizationsEnabled = "runtimeOptimizationsEnabled"
    public static let supportsExtendedRuntime = "supportsExtendedRuntime"
    public static let idleHeartbeatInterval = "idleHeartbeatInterval"
    public static let idleFullFixInterval = "idleFullFixInterval"
    
    // MARK: - Batched Transfers (Queue Flooding Prevention)
    public static let batchedFixes = "batchedFixes"
    public static let batchedSequences = "batchedSequences"
    public static let isBatched = "isBatched"

    // MARK: - Diagnostics
    public static let diagnostic = "diagnostic"
    public static let activationState = "activationState"
    public static let isCompanionAppInstalled = "isCompanionAppInstalled"
}
