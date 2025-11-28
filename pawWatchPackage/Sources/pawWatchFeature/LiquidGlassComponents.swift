#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WatchKit)
import WatchKit
#endif

/// Shared Liquid Glass primitives with graceful fallbacks for older OS versions.
/// On iOS 26+, uses native .glassEffect() API. On iOS 18-25, falls back to .ultraThinMaterial.
/// iOS-only - watchOS uses separate WatchGlassComponents.

#if os(iOS)

// MARK: - Background

struct GlassBackground: View {
    private let theme = LiquidGlassTheme.current
    private let cornerRadius: CGFloat
    private let opacity: Double

    init(cornerRadius: CGFloat = 0, opacity: Double = 1.0) {
        self.cornerRadius = cornerRadius
        self.opacity = opacity
    }

    var body: some View {
        ZStack {
            if let image = theme.backgroundImage() {
                image
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 30)
            } else {
                LinearGradient(
                    colors: theme.backgroundGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .opacity(opacity)
        .ignoresSafeArea()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Full-screen depth canvas that mirrors the marketing mockups with enhanced depth perception.
struct GlassSurface<Content: View>: View {
    private let content: Content
    private let theme = LiquidGlassTheme.current

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Base gradient background
            GlassBackground()

            // Enhanced radial depth gradient for 3D perception
            RadialGradient(
                colors: theme.depthRadialGradient,
                center: .center,
                startRadius: 0,
                endRadius: 600
            )
            .zIndex(LiquidGlassTheme.DepthLevel.background)

            // Content layer
            content
        }
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let depth: Double
    private let content: Content
    private let theme = LiquidGlassTheme.current

    /// Enhanced GlassCard with depth-aware shadows and improved blur effects
    /// - Parameters:
    ///   - cornerRadius: Corner radius for the card (default: 24)
    ///   - padding: Internal padding (default: 20)
    ///   - depth: Z-positioning depth level (default: cardMid = 150)
    ///   - content: Card content
    init(
        cornerRadius: CGFloat = 24,
        padding: CGFloat = 20,
        depth: Double = LiquidGlassTheme.DepthLevel.cardMid,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.depth = depth
        self.content = content()
    }

    var body: some View {
        // WORKAROUND: iOS 26 beta .glassEffect() causes Metal rendering crashes
        // Disabled until iOS 26 stabilizes
        if false, #available(iOS 26, *),
           LiquidGlassAssets.shared.isReady,
           !ProcessInfo.processInfo.arguments.contains("LIQUID_GLASS_FALLBACK") {
            // iOS 26/watchOS 26: Use native Liquid Glass API with depth-aware shadows
            content
                .padding(padding)
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .shadow(
                    color: .black.opacity(theme.shadowOpacity(for: depth)),
                    radius: theme.shadowRadius(for: depth),
                    x: 0,
                    y: theme.shadowOffsetY(for: depth)
                )
                .zIndex(depth)
        } else {
            // iOS 18-25: Enhanced fallback with depth-aware shadows
            content
                .padding(padding)
                .background(backgroundShapeLegacy)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(
                    color: .black.opacity(theme.shadowOpacity(for: depth)),
                    radius: theme.shadowRadius(for: depth),
                    x: 0,
                    y: theme.shadowOffsetY(for: depth)
                )
                .zIndex(depth)
        }
    }

    private var backgroundShapeLegacy: some View {
        ZStack {
            // Base glass material with enhanced blur
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            // Subtle inner glow for depth
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Chrome stroke border with gradient
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [theme.chromeStroke, theme.chromeStrokeSubtle],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.25
                )
        }
    }
}

// MARK: - Buttons

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(GlassCardBackground(isPressed: configuration.isPressed))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(LiquidGlassTheme.current.springQuick, value: configuration.isPressed)
    }

    private struct GlassCardBackground: View {
        let isPressed: Bool
        private let theme = LiquidGlassTheme.current

        var body: some View {
            ZStack {
                // Base glass background
                RoundedRectangle(cornerRadius: theme.cornerRadiusButton, style: .continuous)
                    .fill(isPressed ? theme.pressedHighlight : Color.white.opacity(0.08))

                // Enhanced chrome stroke
                RoundedRectangle(cornerRadius: theme.cornerRadiusButton, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                theme.chromeStroke.opacity(isPressed ? 0.8 : 0.6),
                                theme.chromeStrokeSubtle.opacity(isPressed ? 0.4 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isPressed ? 1.5 : 1
                    )
            }
            .animation(theme.springQuick, value: isPressed)
        }
    }
}

// MARK: - Liquid Glass Tab Bar

struct LiquidGlassTabBar<Selection: Hashable>: View {
    @Binding private var selection: Selection
    private let items: [(icon: String, title: String, tag: Selection)]
    private let onSelect: (Selection) -> Void
    private let theme = LiquidGlassTheme.current
    @State private var hoveredTag: Selection?

    init(
        selection: Binding<Selection>,
        items: [(icon: String, title: String, tag: Selection)],
        onSelect: @escaping (Selection) -> Void
    ) {
        self._selection = selection
        self.items = items
        self.onSelect = onSelect
    }

    var body: some View {
        // WORKAROUND: iOS 26 beta .glassEffect() causes Metal rendering crashes
        if false, #available(iOS 26, *),
           LiquidGlassAssets.shared.isReady,
           !ProcessInfo.processInfo.arguments.contains("LIQUID_GLASS_FALLBACK") {
            // iOS 26/watchOS 26: Enhanced native glass effect with depth
            HStack(spacing: 0) {
                ForEach(items, id: \.tag) { item in
                    TabBarButton(
                        item: item,
                        isSelected: selection == item.tag,
                        isHovered: hoveredTag == item.tag
                    ) {
                        withAnimation(theme.springStandard) {
                            selection = item.tag
                            onSelect(item.tag)
                            Haptics.selection()
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: theme.cornerRadiusLarge))
            .shadow(
                color: .black.opacity(theme.shadowOpacity(for: LiquidGlassTheme.DepthLevel.navigation)),
                radius: theme.shadowRadius(for: LiquidGlassTheme.DepthLevel.navigation),
                x: 0,
                y: theme.shadowOffsetY(for: LiquidGlassTheme.DepthLevel.navigation)
            )
            .padding(.horizontal, 8)
            .zIndex(LiquidGlassTheme.DepthLevel.navigation)
        } else {
            // iOS 18-25: Enhanced fallback with depth-aware styling
            HStack(spacing: 0) {
                ForEach(items, id: \.tag) { item in
                    TabBarButton(
                        item: item,
                        isSelected: selection == item.tag,
                        isHovered: hoveredTag == item.tag
                    ) {
                        withAnimation(theme.springStandard) {
                            selection = item.tag
                            onSelect(item.tag)
                            Haptics.selection()
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(tabBarBackgroundLegacy)
            .shadow(
                color: .black.opacity(theme.shadowOpacity(for: LiquidGlassTheme.DepthLevel.navigation)),
                radius: theme.shadowRadius(for: LiquidGlassTheme.DepthLevel.navigation),
                x: 0,
                y: theme.shadowOffsetY(for: LiquidGlassTheme.DepthLevel.navigation)
            )
            .padding(.horizontal, 8)
            .zIndex(LiquidGlassTheme.DepthLevel.navigation)
        }
    }

    private var tabBarBackgroundLegacy: some View {
        ZStack {
            // Base glass material
            RoundedRectangle(cornerRadius: theme.cornerRadiusLarge, style: .continuous)
                .fill(.ultraThinMaterial)

            // Subtle top highlight
            RoundedRectangle(cornerRadius: theme.cornerRadiusLarge, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Chrome stroke
            RoundedRectangle(cornerRadius: theme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [theme.chromeStroke, theme.chromeStrokeSubtle],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.25
                )
        }
    }

    private enum Haptics {
        @MainActor
        static func selection() {
#if os(iOS)
            UISelectionFeedbackGenerator().selectionChanged()
#elseif os(watchOS)
            WKInterfaceDevice.current().play(.click)
#endif
        }
    }
}

// MARK: - Tab Bar Button

private struct TabBarButton<Tag: Hashable>: View {
    let item: (icon: String, title: String, tag: Tag)
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void
    private let theme = LiquidGlassTheme.current
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: item.icon)
                    .symbolVariant(isSelected ? .fill : .none)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .symbolEffect(.bounce, value: isSelected)
                Text(item.title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? theme.accentPrimary : .secondary)
            .background(buttonBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusButton, style: .continuous))
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(theme.springQuick, value: isPressed)
            .animation(theme.springStandard, value: isSelected)
        }
        .buttonStyle(TabBarButtonStyle(isPressed: $isPressed))
        .accessibilityLabel(item.title)
        .accessibilityHint("Switch to \(item.title) tab")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if isSelected {
            ZStack {
                // Selected state with accent highlight
                RoundedRectangle(cornerRadius: theme.cornerRadiusButton, style: .continuous)
                    .fill(theme.highlight(for: true))

                // Subtle accent glow
                RoundedRectangle(cornerRadius: theme.cornerRadiusButton, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.accentPrimary.opacity(0.1),
                                theme.accentPrimary.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        } else if isHovered {
            // Hover state
            RoundedRectangle(cornerRadius: theme.cornerRadiusButton, style: .continuous)
                .fill(theme.hoverHighlight)
        } else if isPressed {
            // Pressed state
            RoundedRectangle(cornerRadius: theme.cornerRadiusButton, style: .continuous)
                .fill(Color.white.opacity(0.15))
        } else {
            Color.clear
        }
    }
}

private struct TabBarButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

#endif // os(iOS)

#endif // canImport(SwiftUI)
