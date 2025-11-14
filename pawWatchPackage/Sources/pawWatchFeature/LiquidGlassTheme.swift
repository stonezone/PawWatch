import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Enhanced Liquid Glass theme with adaptive colors, depth layers, and refined visual polish.
/// Provides WCAG AA compliant colors, depth-aware shadows, and consistent animation springs.
/// iOS-only - watchOS uses WatchGlassTheme.

#if os(iOS)

struct LiquidGlassTheme {
    static let current = LiquidGlassTheme()

    // MARK: - Enhanced Color Palette

    /// Improved background gradient with deeper tones for better glass contrast
    let backgroundGradient: [Color] = [
        Color(red: 0.05, green: 0.08, blue: 0.15),  // Deep blue-black
        Color(red: 0.12, green: 0.14, blue: 0.22),  // Midnight blue
        Color(red: 0.08, green: 0.06, blue: 0.18)   // Deep purple-black
    ]

    /// Primary accent - WCAG AA compliant blue
    let accentPrimary = Color(red: 0.0, green: 0.478, blue: 1.0) // #007AFF

    /// Secondary accent for gradients
    let accentSecondary = Color(red: 0.2, green: 0.6, blue: 1.0)

    /// Accent gradient for enhanced visual depth
    var accentGradient: [Color] {
        [accentPrimary, accentSecondary]
    }

    // MARK: - Chrome Strokes (Enhanced)

    /// Bright edge stroke for glass borders
    let chromeStroke = Color.white.opacity(0.35)

    /// Subtle inner stroke for layered depth
    let chromeStrokeSubtle = Color.white.opacity(0.15)

    /// Dark mode adaptive stroke
    let chromeStrokeDark = Color.white.opacity(0.2)

    /// Legacy shadow (deprecated in favor of depth-aware shadows)
    let chromeShadow = Color.black.opacity(0.5)

    // MARK: - Depth Levels (Z-Positioning Constants)

    /// Z-index constants for proper layering and depth perception
    enum DepthLevel {
        /// Background layer (gradients, images) - z = 0
        static let background: Double = 0

        /// Card elevation - minimal (z = 100)
        static let cardLow: Double = 100

        /// Card elevation - standard (z = 150)
        static let cardMid: Double = 150

        /// Card elevation - prominent (z = 200)
        static let cardHigh: Double = 200

        /// Tab bar and navigation (z = 250)
        static let navigation: Double = 250

        /// Overlay elements - modals, alerts (z = 300)
        static let overlay: Double = 300
    }

    // MARK: - Depth-Aware Shadow Configuration

    /// Returns shadow opacity based on elevation depth
    func shadowOpacity(for depth: Double) -> Double {
        switch depth {
        case ..<DepthLevel.cardLow:
            return 0.08
        case DepthLevel.cardLow..<DepthLevel.cardMid:
            return 0.12
        case DepthLevel.cardMid..<DepthLevel.cardHigh:
            return 0.16
        case DepthLevel.cardHigh..<DepthLevel.overlay:
            return 0.22
        default:
            return 0.28
        }
    }

    /// Returns shadow radius based on elevation depth
    func shadowRadius(for depth: Double) -> CGFloat {
        switch depth {
        case ..<DepthLevel.cardLow:
            return 12
        case DepthLevel.cardLow..<DepthLevel.cardMid:
            return 20
        case DepthLevel.cardMid..<DepthLevel.cardHigh:
            return 28
        case DepthLevel.cardHigh..<DepthLevel.overlay:
            return 36
        default:
            return 44
        }
    }

    /// Returns shadow Y offset based on elevation depth
    func shadowOffsetY(for depth: Double) -> CGFloat {
        switch depth {
        case ..<DepthLevel.cardLow:
            return 4
        case DepthLevel.cardLow..<DepthLevel.cardMid:
            return 10
        case DepthLevel.cardMid..<DepthLevel.cardHigh:
            return 14
        case DepthLevel.cardHigh..<DepthLevel.overlay:
            return 18
        default:
            return 22
        }
    }

    // MARK: - Blur Effects

    /// Blur radius for glass materials (legacy fallback)
    var glassBlurRadius: CGFloat { 30 }

    /// Enhanced blur for card backgrounds
    var cardBlurRadius: CGFloat { 40 }

    // MARK: - Interactive Highlights

    /// Enhanced highlight with proper opacity levels
    func highlight(for selection: Bool) -> Color {
        selection ? accentPrimary.opacity(0.18) : Color.white.opacity(0.08)
    }

    /// Hover state for interactive elements
    var hoverHighlight: Color {
        Color.white.opacity(0.12)
    }

    /// Pressed state for buttons
    var pressedHighlight: Color {
        accentPrimary.opacity(0.25)
    }

    // MARK: - Gradients

    /// Alert/warning gradient
    func tint(forAlert alert: Bool) -> LinearGradient {
        let colors = alert ? [Color.red.opacity(0.85), Color.orange.opacity(0.6)] : accentGradient
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Radial depth gradient for overlays
    var depthRadialGradient: [Color] {
        [Color.white.opacity(0.05), Color.black.opacity(0.6)]
    }

    /// Map overlay gradient
    var mapOverlayGradient: [Color] {
        [Color.black.opacity(0.15), Color.clear]
    }

    // MARK: - Background Image

    func backgroundImage() -> Image? {
        ImageLoader.named("GlassBackground")
    }

    // MARK: - Animation Springs

    /// Standard spring animation (response: 0.35s, damping: 0.85)
    var springStandard: Animation {
        .spring(response: 0.35, dampingFraction: 0.85)
    }

    /// Quick spring for immediate feedback (response: 0.25s, damping: 0.9)
    var springQuick: Animation {
        .spring(response: 0.25, dampingFraction: 0.9)
    }

    /// Smooth spring for fluid motion (response: 0.4s, damping: 0.8)
    var springSmooth: Animation {
        .spring(response: 0.4, dampingFraction: 0.8)
    }

    // MARK: - Corner Radius Constants

    /// Standard card corner radius
    var cornerRadiusCard: CGFloat { 24 }

    /// Button corner radius
    var cornerRadiusButton: CGFloat { 18 }

    /// Large elements (tab bar, prominent cards)
    var cornerRadiusLarge: CGFloat { 30 }

    /// Small/compact elements
    var cornerRadiusSmall: CGFloat { 16 }
}

enum ImageLoader {
    static func named(_ name: String) -> Image? {
        if let image = loadImage(name, bundle: .module) { return image }
        if let image = loadImage(name, bundle: .main) { return image }
        return nil
    }

    private static func loadImage(_ name: String, bundle: Bundle) -> Image? {
        #if os(iOS)
        if let uiImage = UIImage(named: name, in: bundle, compatibleWith: nil) {
            return Image(uiImage: uiImage)
        }
        if let url = bundle.url(forResource: name, withExtension: nil),
           let uiImage = UIImage(contentsOfFile: url.path) {
            return Image(uiImage: uiImage)
        }
        if let url = bundle.url(forResource: name, withExtension: "png"),
           let uiImage = UIImage(contentsOfFile: url.path) {
            return Image(uiImage: uiImage)
        }
        #elseif os(watchOS)
        if let url = bundle.url(forResource: name, withExtension: nil),
           let uiImage = UIImage(contentsOfFile: url.path) {
            return Image(uiImage: uiImage)
        }
        if let url = bundle.url(forResource: name, withExtension: "png"),
           let uiImage = UIImage(contentsOfFile: url.path) {
            return Image(uiImage: uiImage)
        }
        #elseif os(macOS)
        if let nsImage = NSImage(named: name) {
            return Image(nsImage: nsImage)
        }
        if let url = bundle.url(forResource: name, withExtension: nil),
           let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        if let url = bundle.url(forResource: name, withExtension: "png"),
           let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        #endif
        return nil
    }
}

#endif // os(iOS)
