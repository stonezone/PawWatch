//
//  AccessibilityHelpers.swift
//  pawWatch
//
//  Accessibility helper functions and extensions for VoiceOver support
//

#if os(iOS)
import Foundation
import SwiftUI

/// Accessibility helpers for pawWatch views
///
/// Provides consistent accessibility labels, hints, and values across the app.
/// Supports VoiceOver, Dynamic Type, and other accessibility features.
public enum AccessibilityHelper {

    // MARK: - Distance Formatting

    /// Format distance for accessibility announcement
    /// - Parameters:
    ///   - meters: Distance in meters
    ///   - useMetric: Whether to use metric units
    /// - Returns: Formatted accessibility string (e.g., "100 meters" or "328 feet")
    public static func formatDistance(_ meters: Double?, useMetric: Bool) -> String {
        guard let meters = meters else {
            return "Distance unavailable"
        }

        if useMetric {
            if meters >= 1000 {
                let km = meters / 1000
                return String(format: "%.1f kilometers", km)
            } else {
                return String(format: "%.0f meters", meters)
            }
        } else {
            let feet = meters * 3.28084
            if feet >= 5280 {
                let miles = feet / 5280
                return String(format: "%.1f miles", miles)
            } else {
                return String(format: "%.0f feet", feet)
            }
        }
    }

    // MARK: - Battery Formatting

    /// Format battery level for accessibility announcement
    /// - Parameter fraction: Battery level from 0.0 to 1.0
    /// - Returns: Formatted accessibility string (e.g., "Battery 85 percent")
    public static func formatBattery(_ fraction: Double?) -> String {
        guard let fraction = fraction else {
            return "Battery level unavailable"
        }

        let percentage = Int(fraction * 100)
        return "Battery \(percentage) percent"
    }

    // MARK: - Accuracy Formatting

    /// Format GPS accuracy for accessibility announcement
    /// - Parameter meters: Horizontal accuracy in meters
    /// - Returns: Formatted accessibility string (e.g., "Accuracy 10 meters")
    public static func formatAccuracy(_ meters: Double?) -> String {
        guard let meters = meters else {
            return "Accuracy unavailable"
        }

        return String(format: "Accuracy %.0f meters", meters)
    }

    // MARK: - Time Formatting

    /// Format elapsed time for accessibility announcement
    /// - Parameter seconds: Elapsed seconds since last update
    /// - Returns: Formatted accessibility string (e.g., "Updated 5 seconds ago")
    public static func formatElapsedTime(_ seconds: TimeInterval?) -> String {
        guard let seconds = seconds else {
            return "Last update time unavailable"
        }

        if seconds < 60 {
            return String(format: "Updated %.0f seconds ago", seconds)
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "Updated \(minutes) \(minutes == 1 ? "minute" : "minutes") ago"
        } else {
            let hours = Int(seconds / 3600)
            return "Updated \(hours) \(hours == 1 ? "hour" : "hours") ago"
        }
    }

    // MARK: - Coordinate Formatting

    /// Format coordinate for accessibility announcement
    /// - Parameters:
    ///   - latitude: Latitude value
    ///   - longitude: Longitude value
    /// - Returns: Formatted accessibility string
    public static func formatCoordinate(latitude: Double, longitude: Double) -> String {
        let latDirection = latitude >= 0 ? "North" : "South"
        let lonDirection = longitude >= 0 ? "East" : "West"

        return String(format: "Latitude %.4f degrees %@, Longitude %.4f degrees %@",
                     abs(latitude), latDirection,
                     abs(longitude), lonDirection)
    }

    // MARK: - Connection Status

    /// Format connection status for accessibility announcement
    /// - Parameters:
    ///   - isConnected: Whether Watch is connected
    ///   - isReachable: Whether Watch is reachable
    ///   - secondsSince: Seconds since last update
    /// - Returns: Formatted accessibility string
    public static func formatConnectionStatus(
        isConnected: Bool,
        isReachable: Bool,
        secondsSince: TimeInterval?
    ) -> String {
        if !isConnected {
            return "Watch disconnected. Open pawWatch on Apple Watch to connect."
        }

        if !isReachable {
            return "Watch connected but not reachable. Move closer or open Watch app."
        }

        if let seconds = secondsSince {
            if seconds > 300 {
                return "Connection stale. No updates for \(Int(seconds / 60)) minutes."
            } else {
                return "Connected. \(formatElapsedTime(seconds))"
            }
        }

        return "Connected"
    }

    // MARK: - Map Region

    /// Format map region for accessibility announcement
    /// - Parameters:
    ///   - hasPetLocation: Whether pet location is available
    ///   - hasOwnerLocation: Whether owner location is available
    /// - Returns: Formatted accessibility string
    public static func formatMapRegion(hasPetLocation: Bool, hasOwnerLocation: Bool) -> String {
        if hasPetLocation && hasOwnerLocation {
            return "Map showing pet and owner locations"
        } else if hasPetLocation {
            return "Map showing pet location"
        } else if hasOwnerLocation {
            return "Map showing owner location only"
        } else {
            return "Map view. Waiting for location data."
        }
    }

    // MARK: - Safe Zone Status

    /// Format safe zone status for accessibility announcement
    /// - Parameters:
    ///   - zoneName: Name of the safe zone
    ///   - isInside: Whether pet is currently inside the zone
    /// - Returns: Formatted accessibility string
    public static func formatSafeZoneStatus(zoneName: String, isInside: Bool) -> String {
        if isInside {
            return "\(zoneName). Pet is inside this safe zone."
        } else {
            return "\(zoneName). Pet is outside this safe zone."
        }
    }

    // MARK: - Tracking Mode

    /// Format tracking mode for accessibility announcement
    /// - Parameter mode: Current tracking mode
    /// - Returns: Formatted accessibility string with description
    public static func formatTrackingMode(_ mode: TrackingMode) -> String {
        switch mode {
        case .auto:
            return "Auto mode. Automatically adjusts GPS frequency based on conditions."
        case .emergency:
            return "Emergency mode. Maximum GPS frequency for real-time tracking."
        case .balanced:
            return "Balanced mode. Standard GPS frequency for typical tracking."
        case .saver:
            return "Saver mode. Reduced GPS frequency to extend battery life."
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Add standard accessibility label and hint
    /// - Parameters:
    ///   - label: Accessibility label
    ///   - hint: Accessibility hint (optional)
    /// - Returns: Modified view with accessibility
    public func accessibility(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .modifier(ConditionalHintModifier(hint: hint))
    }

    /// Add accessibility value (for dynamic content)
    /// - Parameters:
    ///   - label: Accessibility label
    ///   - value: Current value
    ///   - hint: Accessibility hint (optional)
    /// - Returns: Modified view with accessibility
    public func accessibility(label: String, value: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .modifier(ConditionalHintModifier(hint: hint))
    }
}

/// Conditional hint modifier (only adds hint if non-nil)
private struct ConditionalHintModifier: ViewModifier {
    let hint: String?

    func body(content: Content) -> some View {
        if let hint = hint {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}

// MARK: - Dynamic Type Support

extension View {
    /// Enable Dynamic Type scaling with custom limits
    /// - Parameters:
    ///   - minScale: Minimum scale category
    ///   - maxScale: Maximum scale category
    /// - Returns: Modified view with Dynamic Type limits
    public func dynamicTypeRange(_ minScale: DynamicTypeSize = .xSmall, _ maxScale: DynamicTypeSize = .accessibility5) -> some View {
        self.dynamicTypeSize(minScale...maxScale)
    }
}

#endif
