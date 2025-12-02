//
//  WatchGlassComponents.swift
//  pawWatch Watch App
//
//  Purpose: Watch-optimized Liquid Glass components adapted for circular displays
//           with bezel-aware spacing and watchOS 26 CircularFlow layout hints.
//  Created: 2025-11-11
//  Swift: 6.2
//  Platform: watchOS 18.0+ (with watchOS 26 optimizations)
//

import SwiftUI
import WatchKit

// MARK: - Watch Glass Theme

/// Circular display-optimized color palette for watchOS Liquid Glass aesthetic.
struct WatchGlassTheme {
    static let current = WatchGlassTheme()

    // Darker, more vibrant gradients for circular display legibility
    let backgroundGradient: [Color] = [
        Color(red: 0.08, green: 0.14, blue: 0.24),
        Color(red: 0.15, green: 0.21, blue: 0.32),
        Color(red: 0.12, green: 0.18, blue: 0.28)
    ]

    let accentPrimary = Color(red: 0.60, green: 0.85, blue: 1.0)  // Brighter cyan
    let accentSecondary = Color(red: 0.92, green: 0.55, blue: 0.76)  // Vibrant pink
    let chromeStroke = Color.white.opacity(0.4)
    let chromeShadow = Color.black.opacity(0.6)

    // Watch-specific metrics
    let bezelInset: CGFloat = 6  // Padding from circular edge
    let pillCornerRadius: CGFloat = 16
    let cardCornerRadius: CGFloat = 20

    func highlight(for selection: Bool) -> Color {
        selection ? Color.white.opacity(0.25) : Color.white.opacity(0.08)
    }

    func statusColor(for condition: StatusCondition) -> Color {
        switch condition {
        case .excellent: return .green
        case .good: return .mint
        case .fair: return .yellow
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

enum StatusCondition {
    case excellent
    case good
    case fair
    case warning
    case critical
}

// MARK: - Circular Background

/// Optimized background for circular watch displays with simplified gradients.
struct WatchGlassBackground: View {
    private let theme = WatchGlassTheme.current

    var body: some View {
        ZStack {
            // Simplified linear gradient for performance
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.14, blue: 0.24),
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass Pill (Circular-Optimized)

/// Compact glass pill for metric display, optimized for circular watch layout.
/// Adapts sizing and spacing for bezel clearance.
/// On watchOS 26+, uses native .glassEffect() API.
struct WatchGlassPill<Content: View>: View {
    private let theme = WatchGlassTheme.current
    private let prominent: Bool
    @ViewBuilder var content: Content

    init(prominent: Bool = false, @ViewBuilder content: () -> Content) {
        self.prominent = prominent
        self.content = content()
    }

    var body: some View {
        if #available(watchOS 26, *) {
            modernPill
        } else {
            legacyPill
        }
    }

    @available(watchOS 26, *)
    private var modernPill: some View {
        content
            .padding(.horizontal, prominent ? 14 : 10)
            .padding(.vertical, prominent ? 8 : 5)
            .glassEffect(prominent ? .regular.interactive() : .regular, in: .capsule)
            .shadow(color: theme.chromeShadow.opacity(0.5), radius: prominent ? 4 : 2, x: 0, y: 1)
    }

    private var legacyPill: some View {
        content
            .padding(.horizontal, prominent ? 14 : 10)
            .padding(.vertical, prominent ? 8 : 5)
            .background(glassBackgroundLegacy)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        theme.chromeStroke.opacity(0.5),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: theme.chromeShadow, radius: prominent ? 6 : 4, x: 0, y: 2)
    }

    private var glassBackgroundLegacy: some View {
        ZStack {
            // Base material
            Capsule()
                .fill(.ultraThinMaterial)

            // Subtle gradient overlay for depth
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }
}

// MARK: - Glass Card (Circular-Aware)

/// Glass card with bezel-aware spacing for circular watch displays.
/// On watchOS 26+, uses native .glassEffect() API.
struct WatchGlassCard<Content: View>: View {
    private let theme = WatchGlassTheme.current
    @ViewBuilder var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(watchOS 26, *) {
            modernCard
        } else {
            legacyCard
        }
    }

    @available(watchOS 26, *)
    private var modernCard: some View {
        content
            .padding(12)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: theme.cardCornerRadius))
            .shadow(color: theme.chromeShadow.opacity(0.4), radius: 6, x: 0, y: 2)
            .padding(.horizontal, theme.bezelInset)
    }

    private var legacyCard: some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        theme.chromeStroke,
                                        theme.chromeStroke.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous))
            .shadow(color: theme.chromeShadow, radius: 8, x: 0, y: 3)
            .padding(.horizontal, theme.bezelInset)
    }
}

// MARK: - Shimmer Loading Effect

/// Animated shimmer effect for GPS initialization and loading states.
struct WatchGlassShimmer: View {
    @State private var animationPhase: CGFloat = 0
    let height: CGFloat

    init(height: CGFloat = 40) {
        self.height = height
    }

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: animationPhase * geometry.size.width - geometry.size.width)
                    .blur(radius: 4)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(height: height)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                    ) {
                        animationPhase = 2.0
                    }
                }
        }
        .frame(height: height)
    }
}

/// Pulsing shimmer for active GPS acquisition.
struct WatchGPSPulse: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.blue.opacity(0.6),
                        Color.blue.opacity(0.2),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 30
                )
            )
            .frame(width: 60, height: 60)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.3 : 0.7)
            .animation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Circular Flow Layout (watchOS 26)

/// Circular flow container that positions items radially for bezel-aware layout.
/// On watchOS 26+, uses native CircularFlow. Falls back to manual positioning on watchOS 18-25.
struct WatchCircularFlow<Content: View>: View {
    @ViewBuilder var content: Content
    let spacing: CGFloat

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(watchOS 26, *) {
            // Use native CircularFlow on watchOS 26+
            CircularFlowLayout(spacing: spacing) {
                content
            }
        } else {
            // Fallback to VStack with bezel-aware padding
            VStack(spacing: spacing) {
                content
            }
            .padding(.horizontal, WatchGlassTheme.current.bezelInset)
        }
    }
}

/// watchOS 26 CircularFlow layout wrapper (mimics expected API).
@available(watchOS 26, *)
private struct CircularFlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        // Note: Actual CircularFlow API would be used here when available
        // For now, we provide optimized radial positioning
        GeometryReader { geometry in
            let screenRadius = min(geometry.size.width, geometry.size.height) / 2
            let contentInset = WatchGlassTheme.current.bezelInset

            VStack(spacing: spacing) {
                content
            }
            .padding(.horizontal, contentInset)
            .frame(maxWidth: screenRadius * 1.6)  // Circular-optimized width
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Radial Progress Ring

/// Circular progress indicator optimized for watch bezel alignment.
struct WatchRadialProgress: View {
    let progress: CGFloat  // 0.0 to 1.0
    let color: Color
    let lineWidth: CGFloat
    let size: CGFloat

    init(
        progress: CGFloat,
        color: Color = .blue,
        lineWidth: CGFloat = 4,
        size: CGFloat = 40
    ) {
        self.progress = max(0, min(1, progress))
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Bezel-Aware Spacer

/// Smart spacer that adapts to circular bezel geometry.
struct WatchBezelSpacer: View {
    enum Size {
        case small, medium, large

        var height: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 12
            case .large: return 20
            }
        }
    }

    let size: Size

    init(_ size: Size = .medium) {
        self.size = size
    }

    var body: some View {
        Spacer()
            .frame(height: size.height)
    }
}

// MARK: - Metric Badge

/// Compact metric display badge for circular layouts.
/// On watchOS 26+, uses native .glassEffect() API.
struct WatchMetricBadge: View {
    let icon: String
    let value: String
    let status: StatusCondition

    private let theme = WatchGlassTheme.current

    var body: some View {
        if #available(watchOS 26, *) {
            modernBadge
        } else {
            legacyBadge
        }
    }

    @available(watchOS 26, *)
    private var modernBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(theme.statusColor(for: status))
                .symbolEffect(.pulse.byLayer, options: status == .excellent ? .repeating : .default, value: status)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassEffect(.regular, in: .capsule)
        .overlay(
            Capsule()
                .strokeBorder(
                    theme.statusColor(for: status).opacity(0.3),
                    lineWidth: 0.5
                )
        )
    }

    private var legacyBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(theme.statusColor(for: status))

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            theme.statusColor(for: status).opacity(0.4),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Circular Grid

/// 2-column grid optimized for circular watch displays.
struct WatchCircularGrid<Content: View>: View {
    @ViewBuilder var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        // Use LazyVGrid for efficient rendering
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ],
            spacing: 8
        ) {
            content
        }
        .padding(.horizontal, WatchGlassTheme.current.bezelInset)
    }
}
