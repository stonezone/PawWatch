#if os(iOS)
import SwiftUI
import UIKit

/// Shared Liquid Glass primitives with graceful fallbacks for older OS versions.
enum LiquidGlassComponents {
    /// Returns the best available material for translucent glass panels.
    static func preferredMaterial() -> Material {
        if #available(iOS 26, *) {
            return .thinMaterial
        } else {
            return .ultraThinMaterial
        }
    }
}

// MARK: - Background

struct GlassBackground: View {
    private let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 0) {
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let image = Image(resource: "GlassBackground") {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color.cyan.opacity(0.35), Color.blue.opacity(0.2), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let shadowOpacity: Double
    private let content: Content

    init(
        cornerRadius: CGFloat = 24,
        padding: CGFloat = 20,
        shadowOpacity: Double = 0.12,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.shadowOpacity = shadowOpacity
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(backgroundShape)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(shadowOpacity), radius: 20, x: 0, y: 10)
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(LiquidGlassComponents.preferredMaterial())
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.25
                    )
            )
    }
}

// MARK: - Liquid Glass Tab Bar

struct LiquidGlassTabBar<Selection: Hashable>: View {
    @Binding private var selection: Selection
    private let items: [(icon: String, title: String, tag: Selection)]
    private let onSelect: (Selection) -> Void

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
        HStack(spacing: 0) {
            ForEach(items, id: \.tag) { item in
                Button {
                    selection = item.tag
                    onSelect(item.tag)
                    Haptics.selection()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .symbolVariant(selection == item.tag ? .fill : .none)
                        Text(item.title)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selection == item.tag ? Color.accentColor : .secondary)
                    .background(highlight(for: item.tag))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(LiquidGlassComponents.preferredMaterial())
        )
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 12)
    }

    private func highlight(for tag: Selection) -> some ShapeStyle {
        if selection == tag {
            return AnyShapeStyle(Color.white.opacity(0.15))
        }
        return AnyShapeStyle(Color.clear)
    }

    private enum Haptics {
        @MainActor
        static func selection() {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

// MARK: - Helpers

private extension Image {
    init?(resource name: String) {
        if UIImage(named: name, in: .module, compatibleWith: nil) != nil {
            self.init(name, bundle: .module)
        } else if UIImage(named: name) != nil {
            self.init(name)
        } else {
            return nil
        }
    }
}
#endif
