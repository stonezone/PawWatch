import SwiftUI

/// Shared utility functions used across the pawWatch application.
///
/// This file consolidates common helper functions to avoid duplication across iOS and watchOS targets.
/// All functions are public and can be used throughout the app.
public enum SharedUtilities {

    // MARK: - Battery Utilities

    /// Returns the appropriate SF Symbol name for a given battery level.
    ///
    /// - Parameter level: Battery level as a fraction (0.0 - 1.0)
    /// - Returns: SF Symbol name representing the battery state
    ///
    /// Example:
    /// ```swift
    /// let icon = SharedUtilities.batteryIcon(for: 0.85) // Returns "battery.100"
    /// ```
    public static func batteryIcon(for level: Double) -> String {
        let percentage = level * 100
        switch percentage {
        case 75...100:
            return "battery.100"
        case 50..<75:
            return "battery.75"
        case 25..<50:
            return "battery.50"
        case 10..<25:
            return "battery.25"
        default:
            return "battery.0"
        }
    }

    /// Returns the appropriate color for a given battery level.
    ///
    /// - Parameter level: Battery level as a fraction (0.0 - 1.0)
    /// - Returns: Color indicating battery health (green=good, yellow=medium, red=low)
    ///
    /// Example:
    /// ```swift
    /// let color = SharedUtilities.batteryColor(for: 0.15) // Returns .red
    /// ```
    public static func batteryColor(for level: Double) -> Color {
        if level > 0.5 { return .green }
        if level > 0.2 { return .yellow }
        return .red
    }

    // MARK: - GPS Accuracy Utilities

    /// Returns the appropriate color for a given GPS accuracy value.
    ///
    /// - Parameter accuracy: Horizontal accuracy in meters
    /// - Returns: Color indicating accuracy quality
    ///   - Green: Excellent accuracy (<10m)
    ///   - Yellow: Good accuracy (10-25m)
    ///   - Orange: Poor accuracy (>25m)
    ///
    /// Example:
    /// ```swift
    /// let color = SharedUtilities.accuracyColor(for: 8.5) // Returns .green
    /// ```
    public static func accuracyColor(for accuracy: Double) -> Color {
        switch accuracy {
        case 0..<10:
            return .green
        case 10..<25:
            return .yellow
        default:
            return .orange
        }
    }

    // MARK: - Time Formatting Utilities

    /// Formats a time interval as a short human-readable string without "ago" suffix.
    ///
    /// - Parameter date: The date to calculate time since
    /// - Returns: Formatted string (e.g., "5s", "12m", "2h")
    ///
    /// Example:
    /// ```swift
    /// let time = SharedUtilities.timeAgoShort(since: someDate) // "5m"
    /// ```
    public static func timeAgoShort(since date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h"
    }

    /// Formats a time interval as a human-readable string with "ago" suffix.
    ///
    /// - Parameter date: The date to calculate time since
    /// - Returns: Formatted string (e.g., "5s ago", "12m ago", "2h ago")
    ///
    /// Example:
    /// ```swift
    /// let time = SharedUtilities.timeAgoLong(since: someDate) // "5m ago"
    /// ```
    public static func timeAgoLong(since date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
    }

    /// Formats a time interval (in seconds) as a human-readable string with "ago" suffix.
    ///
    /// This variant takes a TimeInterval directly rather than calculating from a Date.
    ///
    /// - Parameter seconds: Time interval in seconds
    /// - Returns: Formatted string with "ago" suffix
    ///
    /// Example:
    /// ```swift
    /// let time = SharedUtilities.timeAgoText(120) // "2m ago"
    /// ```
    public static func timeAgoText(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.0fs ago", seconds)
        } else if seconds < 3600 {
            return String(format: "%.0fm ago", seconds / 60)
        } else {
            return String(format: "%.1fh ago", seconds / 3600)
        }
    }
}
