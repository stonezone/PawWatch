//
//  SmartStackHintView.swift
//  pawWatch Watch App
//
//  Purpose: Smart Stack hint view component for widget preview
//  Created: 2025-12-15
//

import SwiftUI
import pawWatchFeature

// MARK: - Smart Stack Hint View

struct SmartStackHintView: View {
    let latency: String
    let drain: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "rectangle.stack.badge.play.fill")
                .font(.caption2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text("Smart Stack preview")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("WidgetKit card will mirror \(latency) + \(drain) snapshot when Phase 6 lands.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
