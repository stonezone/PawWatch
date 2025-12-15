//
//  LockOverlayBackgroundModifier.swift
//  pawWatch Watch App
//
//  Purpose: Background modifier for the lock overlay with glass effects
//  Created: 2025-12-15
//

import SwiftUI

// MARK: - Lock Overlay Background Modifier

struct LockOverlayBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(watchOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
