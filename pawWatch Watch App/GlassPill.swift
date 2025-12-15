//
//  GlassPill.swift
//  pawWatch Watch App
//
//  Purpose: Glass pill UI component with modern glass effects
//  Created: 2025-12-15
//

import SwiftUI

// MARK: - Glass Pill

struct GlassPill<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(watchOS 26, *) {
            content
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .capsule)
        } else {
            content
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
        }
    }
}

// MARK: - Glass Skeleton

struct GlassSkeleton: View {
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.3))
            .frame(height: height)
    }
}
