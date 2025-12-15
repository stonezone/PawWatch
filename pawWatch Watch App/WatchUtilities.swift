//
//  WatchUtilities.swift
//  pawWatch Watch App
//
//  Purpose: Shared utility functions for watch app
//  Created: 2025-12-15
//

import SwiftUI

// MARK: - Battery Utilities

/// Returns appropriate SF Symbol name for battery level
func batteryIcon(for level: Double) -> String {
    switch level {
    case 0..<0.10: return "battery.0percent"
    case 0.10..<0.25: return "battery.25percent"
    case 0.25..<0.50: return "battery.50percent"
    case 0.50..<0.75: return "battery.75percent"
    default: return "battery.100percent"
    }
}

/// Returns color for battery level
func batteryColor(for level: Double) -> Color {
    switch level {
    case 0..<0.20: return .red
    case 0.20..<0.50: return .orange
    default: return .green
    }
}

// MARK: - Accuracy Utilities

/// Returns color based on GPS accuracy
func accuracyColor(for accuracy: Double) -> Color {
    switch accuracy {
    case 0..<10: return .green
    case 10..<25: return .mint
    case 25..<50: return .yellow
    case 50..<100: return .orange
    default: return .red
    }
}

// MARK: - Time Formatting

/// Short time ago string (e.g., "5m", "2h")
func timeAgoShort(since date: Date) -> String {
    let seconds = -date.timeIntervalSinceNow
    if seconds < 60 { return "\(Int(seconds))s" }
    if seconds < 3600 { return "\(Int(seconds / 60))m" }
    if seconds < 86400 { return "\(Int(seconds / 3600))h" }
    return "\(Int(seconds / 86400))d"
}

/// Long time ago string (e.g., "5 minutes ago")
func timeAgoLong(since date: Date) -> String {
    let seconds = -date.timeIntervalSinceNow
    if seconds < 60 { return "\(Int(seconds)) seconds ago" }
    if seconds < 3600 {
        let minutes = Int(seconds / 60)
        return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
    }
    if seconds < 86400 {
        let hours = Int(seconds / 3600)
        return "\(hours) hour\(hours == 1 ? "" : "s") ago"
    }
    let days = Int(seconds / 86400)
    return "\(days) day\(days == 1 ? "" : "s") ago"
}
