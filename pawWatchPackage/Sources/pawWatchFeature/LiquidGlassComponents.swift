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
        // iOS 26+: Use native Liquid Glass API with depth-aware shadows
        if #available(iOS 26, *) {
            content
                .padding(padding)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                .shadow(
                    color: .black.opacity(theme.shadowOpacity(for: depth) * 0.7),
                    radius: theme.shadowRadius(for: depth) * 0.8,
                    x: 0,
                    y: theme.shadowOffsetY(for: depth) * 0.6
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
    var isProminent: Bool = false
    private let theme = LiquidGlassTheme.current

    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, *) {
            configuration.label
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .fontWeight(.semibold)
                .foregroundStyle(isProminent ? .white : .primary)
                .background {
                    if isProminent {
                        Capsule()
                            .fill(theme.accentPrimary.gradient)
                    }
                }
                .glassEffect(isProminent ? .clear : .regular.interactive(), in: .capsule)
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .opacity(configuration.isPressed ? 0.9 : 1)
                .animation(theme.springQuick, value: configuration.isPressed)
        } else {
            configuration.label
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(GlassCardBackgroundLegacy(isPressed: configuration.isPressed, isProminent: isProminent))
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(theme.springQuick, value: configuration.isPressed)
        }
    }

    private struct GlassCardBackgroundLegacy: View {
        let isPressed: Bool
        let isProminent: Bool
        private let theme = LiquidGlassTheme.current

        var body: some View {
            ZStack {
                if isProminent {
                    RoundedRectangle(cornerRadius: theme.cornerRadiusButton, style: .continuous)
                        .fill(theme.accentPrimary.gradient)
                } else {
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
            }
            .animation(theme.springQuick, value: isPressed)
        }
    }
}

// MARK: - Modern Glass Pill Button

@available(iOS 26, *)
struct GlassPillButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isProminent: Bool = false

    private let theme = LiquidGlassTheme.current
    @State private var isPressed = false

    init(_ title: String, icon: String? = nil, isProminent: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isProminent = isProminent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .symbolEffect(.bounce, value: isPressed)
                }
                Text(title)
                    .font(.body.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .foregroundStyle(isProminent ? .white : .primary)
            .background {
                if isProminent {
                    Capsule()
                        .fill(theme.accentPrimary.gradient)
                }
            }
            .glassEffect(isProminent ? .clear : .regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : 1)
        .animation(theme.springQuick, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Liquid Glass Tab Bar

/// Modern sliding selector tab bar with liquid glass effect.
/// Clean, unified design - tap or swipe the sliding selector to navigate.
struct LiquidGlassTabBar<Selection: Hashable>: View {
    @Binding private var selection: Selection
    private let items: [(icon: String, title: String, tag: Selection)]
    private let onSelect: (Selection) -> Void
    private let theme = LiquidGlassTheme.current

    /// Tracks the current drag offset for smooth sliding animation
    @State private var dragOffset: CGFloat = 0
    /// Tracks if we're actively dragging
    @State private var isDragging = false

    init(
        selection: Binding<Selection>,
        items: [(icon: String, title: String, tag: Selection)],
        onSelect: @escaping (Selection) -> Void
    ) {
        self._selection = selection
        self.items = items
        self.onSelect = onSelect
    }

    /// Get index of currently selected item
    private var selectedIndex: Int {
        items.firstIndex(where: { $0.tag == selection }) ?? 0
    }

    /// Navigate to a specific index with bounds checking
    private func navigateToIndex(_ index: Int) {
        let clampedIndex = max(0, min(items.count - 1, index))
        if clampedIndex != selectedIndex {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selection = items[clampedIndex].tag
                onSelect(items[clampedIndex].tag)
                Haptics.selection()
            }
        }
    }

    var body: some View {
        if #available(iOS 26, *) {
            modernTabBar
        } else {
            legacyTabBar
        }
    }

    @available(iOS 26, *)
    private var modernTabBar: some View {
        GeometryReader { geometry in
            let itemWidth = (geometry.size.width - 16) / CGFloat(items.count)
            // Calculate the base position plus any drag offset
            let baseOffset = CGFloat(selectedIndex) * itemWidth + 12
            let currentOffset = isDragging ? baseOffset + dragOffset : baseOffset

            ZStack(alignment: .leading) {
                // Sliding selector indicator with liquid glass - now draggable!
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.accentPrimary.opacity(isDragging ? 0.25 : 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(theme.accentPrimary.opacity(isDragging ? 0.5 : 0.3), lineWidth: 1)
                    )
                    .frame(width: itemWidth - 8, height: 56)
                    .offset(x: currentOffset)
                    .animation(isDragging ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: selectedIndex)
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                isDragging = true
                                dragOffset = value.translation.width
                            }
                            .onEnded { value in
                                isDragging = false
                                let threshold = itemWidth * 0.4
                                let velocity = value.predictedEndTranslation.width - value.translation.width

                                // Calculate target index based on drag distance and velocity
                                var targetIndex = selectedIndex
                                if value.translation.width < -threshold || velocity < -100 {
                                    targetIndex = selectedIndex + 1
                                } else if value.translation.width > threshold || velocity > 100 {
                                    targetIndex = selectedIndex - 1
                                }

                                dragOffset = 0
                                navigateToIndex(targetIndex)
                            }
                    )

                // Tab buttons
                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.tag) { index, item in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selection = item.tag
                                onSelect(item.tag)
                                Haptics.selection()
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 20, weight: selection == item.tag ? .semibold : .regular))
                                    .symbolVariant(selection == item.tag ? .fill : .none)
                                    .symbolEffect(.bounce, value: selection == item.tag)

                                Text(item.title)
                                    .font(.system(size: 11, weight: selection == item.tag ? .semibold : .medium))
                            }
                            .foregroundStyle(selection == item.tag ? theme.accentPrimary : .secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.title)
                        .accessibilityAddTraits(selection == item.tag ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(height: 72)
        .padding(.horizontal, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }

    private var legacyTabBar: some View {
        GeometryReader { geometry in
            let itemWidth = (geometry.size.width - 16) / CGFloat(items.count)
            // Calculate the base position plus any drag offset
            let baseOffset = CGFloat(selectedIndex) * itemWidth + 12
            let currentOffset = isDragging ? baseOffset + dragOffset : baseOffset

            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [theme.chromeStroke, theme.chromeStrokeSubtle],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                // Sliding selector indicator - now draggable!
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.accentPrimary.opacity(isDragging ? 0.18 : 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(theme.accentPrimary.opacity(isDragging ? 0.4 : 0.25), lineWidth: 1)
                    )
                    .frame(width: itemWidth - 8, height: 52)
                    .offset(x: currentOffset)
                    .animation(isDragging ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: selectedIndex)
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                isDragging = true
                                dragOffset = value.translation.width
                            }
                            .onEnded { value in
                                isDragging = false
                                let threshold = itemWidth * 0.4
                                let velocity = value.predictedEndTranslation.width - value.translation.width

                                // Calculate target index based on drag distance and velocity
                                var targetIndex = selectedIndex
                                if value.translation.width < -threshold || velocity < -100 {
                                    targetIndex = selectedIndex + 1
                                } else if value.translation.width > threshold || velocity > 100 {
                                    targetIndex = selectedIndex - 1
                                }

                                dragOffset = 0
                                navigateToIndex(targetIndex)
                            }
                    )

                // Tab buttons
                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.tag) { index, item in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selection = item.tag
                                onSelect(item.tag)
                                Haptics.selection()
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 18, weight: selection == item.tag ? .semibold : .regular))
                                    .symbolVariant(selection == item.tag ? .fill : .none)

                                Text(item.title)
                                    .font(.system(size: 10, weight: selection == item.tag ? .semibold : .medium))
                            }
                            .foregroundStyle(selection == item.tag ? theme.accentPrimary : .secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.title)
                        .accessibilityAddTraits(selection == item.tag ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(height: 68)
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
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

#endif // os(iOS)

#endif // canImport(SwiftUI)
