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
    @ViewBuilder var content: Content

    var body: some View {
        if #available(watchOS 26, *) {
            content
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .glassEffect(.regular, in: .capsule)
        } else {
            content
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(.thinMaterial, in: Capsule())
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
