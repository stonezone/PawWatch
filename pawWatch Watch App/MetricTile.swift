//
//  MetricTile.swift
//  pawWatch Watch App
//
//  Purpose: Metric display tile component for showing tracking metrics
//  Created: 2025-12-15
//

import SwiftUI
import pawWatchFeature

// MARK: - Metric Tile

struct MetricTile: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String?
    var tint: Color = .cyan

    init(icon: String, title: String, value: String, subtitle: String? = nil, tint: Color = .cyan) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.tint = tint
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(tint)
                .imageScale(.small)

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
