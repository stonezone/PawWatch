//
//  GlassPill.swift
//  pawWatch Watch App
//
//  Purpose: Glass pill UI component with modern glass effects
//  Created: 2025-12-15
//

import SwiftUI
import pawWatchFeature

// MARK: - Glass Pill

struct GlassPill<Content: View>: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var highContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder var content: Content

    var body: some View {
        if #available(watchOS 26, *) {
            if reduceTransparency {
                content
                    .foregroundStyle(.primary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.black.opacity(0.85), in: Capsule())
            } else {
                // P3-08: Increased contrast - always use .primary for glass backgrounds
                content
                    .foregroundStyle(.primary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(highContrast ? Color.black.opacity(0.5) : Color.clear)
                    .glassEffect(.regular, in: .capsule)
            }
        } else {
            if reduceTransparency {
                content
                    .foregroundStyle(.primary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.black.opacity(0.85), in: Capsule())
            } else {
                // P3-08: Increased contrast - always use .primary for glass backgrounds
                content
                    .foregroundStyle(.primary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(highContrast ? Color.black.opacity(0.5) : Color.clear)
                    .background(.thinMaterial, in: Capsule())
            }
        }
    }
}

// MARK: - Glass Skeleton

struct GlassSkeleton: View {
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
            .fill(.ultraThinMaterial.opacity(Opacity.medium * 0.5))
            .frame(height: height)
    }
}
