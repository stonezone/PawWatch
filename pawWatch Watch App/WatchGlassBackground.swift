//
//  WatchGlassBackground.swift
//  pawWatch Watch App
//
//  Purpose: Background component for watch views with glass effect
//  Created: 2025-12-15
//

import SwiftUI

// MARK: - Watch Glass Background

struct WatchGlassBackground: View {
    var body: some View {
        if #available(watchOS 26, *) {
            Color.clear
                .glassEffect(.regular, in: .rect)
        } else {
            Color.clear
                .background(.ultraThinMaterial)
        }
    }
}
