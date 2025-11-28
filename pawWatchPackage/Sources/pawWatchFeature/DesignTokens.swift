import SwiftUI

// MARK: - Typography System

/// Typography tokens for consistent text styling across the app.
/// Uses SF Pro with strategic weight and design variations for optimal readability.
public enum Typography {
    // MARK: Display
    
    /// Large page titles for screen headers
    /// - Usage: Main screen titles, feature headers
    /// - Size: 28pt, Bold, Rounded
    public static let pageTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    
    /// Subtitle text for page headers
    /// - Usage: Contextual information under page titles
    public static let pageSubtitle = Font.subheadline
    
    // MARK: Headlines
    
    /// Primary card title
    /// - Usage: Card headers, section titles within cards
    /// - Size: 17pt, Semibold
    public static let cardTitle = Font.system(size: 17, weight: .semibold)
    
    /// Secondary section title
    /// - Usage: Section headers in lists, group labels
    /// - Size: 15pt, Semibold
    public static let sectionTitle = Font.system(size: 15, weight: .semibold)
    
    // MARK: Body
    
    /// Standard body text
    /// - Usage: Main content, descriptions, paragraphs
    /// - Size: 15pt, Regular
    public static let body = Font.system(size: 15, weight: .regular)
    
    /// Callout text
    /// - Usage: Supporting text, informational messages
    public static let callout = Font.callout
    
    // MARK: Labels
    
    /// Standard label
    /// - Usage: Field labels, metadata labels
    /// - Size: 12pt, Medium
    public static let label = Font.system(size: 12, weight: .medium)
    
    /// Uppercase label
    /// - Usage: Category labels, status indicators
    /// - Size: 11pt, Medium
    /// - Note: Use with `.textCase(.uppercase)` modifier
    public static let labelUppercase = Font.system(size: 11, weight: .medium)
    
    /// Caption text
    /// - Usage: Secondary information, timestamps
    public static let caption = Font.caption
    
    /// Small caption text
    /// - Usage: Tertiary information, fine print
    public static let captionSmall = Font.caption2
    
    // MARK: Data Display
    
    /// Large data display
    /// - Usage: Primary metrics, featured numbers
    /// - Size: 20pt, Semibold, Monospaced
    public static let dataLarge = Font.system(size: 20, weight: .semibold, design: .monospaced)
    
    /// Medium data display
    /// - Usage: Secondary metrics, inline numbers
    /// - Size: 16pt, Semibold, Monospaced
    public static let dataMedium = Font.system(size: 16, weight: .semibold, design: .monospaced)
    
    /// Small data display
    /// - Usage: Compact metrics, list item numbers
    /// - Size: 13pt, Medium, Monospaced
    public static let dataSmall = Font.system(size: 13, weight: .medium, design: .monospaced)
}

// MARK: - Spacing System

/// Spacing tokens based on an 8pt grid system for consistent layout.
/// Provides both raw values and semantic component-specific spacing.
public enum Spacing {
    // MARK: Base Scale (8pt grid)
    
    /// Extra extra extra small: 2pt
    public static let xxxs: CGFloat = 2
    
    /// Extra extra small: 4pt
    public static let xxs: CGFloat = 4
    
    /// Extra small: 6pt (off-grid for fine adjustments)
    public static let xs: CGFloat = 6
    
    /// Small: 8pt (1 grid unit)
    public static let sm: CGFloat = 8
    
    /// Medium: 12pt (1.5 grid units)
    public static let md: CGFloat = 12
    
    /// Large: 16pt (2 grid units)
    public static let lg: CGFloat = 16
    
    /// Extra large: 20pt (2.5 grid units)
    public static let xl: CGFloat = 20
    
    /// Extra extra large: 24pt (3 grid units)
    public static let xxl: CGFloat = 24
    
    /// Extra extra extra large: 32pt (4 grid units)
    public static let xxxl: CGFloat = 32
    
    /// Huge: 48pt (6 grid units)
    public static let huge: CGFloat = 48
    
    // MARK: Semantic Component Spacing
    
    /// Component-specific spacing tokens for consistent UI patterns.
    public enum Component {
        /// Card internal padding
        public static let cardPadding: CGFloat = 20
        
        /// Spacing between cards in a list
        public static let cardSpacing: CGFloat = 16
        
        /// Spacing between major sections
        public static let sectionSpacing: CGFloat = 24
        
        /// Spacing between list items
        public static let listItemSpacing: CGFloat = 12
        
        /// Gap between icon and text
        public static let iconTextGap: CGFloat = 8
        
        /// Button horizontal padding
        public static let buttonPaddingH: CGFloat = 24
        
        /// Button vertical padding
        public static let buttonPaddingV: CGFloat = 14
        
        /// Tab bar item horizontal padding
        public static let tabBarPaddingH: CGFloat = 12
        
        /// Tab bar item vertical padding
        public static let tabBarPaddingV: CGFloat = 10
        
        /// Screen edge padding (slightly off-grid for visual balance)
        public static let screenEdge: CGFloat = 18
    }
}

// MARK: - Corner Radius System

/// Corner radius tokens for consistent rounded corners across components.
public enum CornerRadius {
    // MARK: Base Scale
    
    /// Extra small: 8pt
    public static let xs: CGFloat = 8
    
    /// Small: 12pt
    public static let sm: CGFloat = 12
    
    /// Medium: 16pt
    public static let md: CGFloat = 16
    
    /// Large: 20pt
    public static let lg: CGFloat = 20
    
    /// Extra large: 24pt
    public static let xl: CGFloat = 24
    
    /// Extra extra large: 30pt
    public static let xxl: CGFloat = 30
    
    /// Full radius for capsules and circles
    public static let full: CGFloat = .infinity
    
    // MARK: Semantic Component Radius
    
    /// Card corner radius
    public static let card: CGFloat = 24
    
    /// Button corner radius
    public static let button: CGFloat = 16
    
    /// Badge corner radius
    public static let badge: CGFloat = 12
    
    /// Tab bar corner radius
    public static let tabBar: CGFloat = 28
}

// MARK: - Icon Sizes

/// Icon size tokens for consistent icon scaling across the app.
public enum IconSize {
    /// Extra small: 12pt
    public static let xs: CGFloat = 12
    
    /// Small: 16pt
    public static let sm: CGFloat = 16
    
    /// Medium: 20pt
    public static let md: CGFloat = 20
    
    /// Large: 24pt
    public static let lg: CGFloat = 24
    
    /// Extra large: 32pt
    public static let xl: CGFloat = 32
    
    /// Extra extra large: 48pt
    public static let xxl: CGFloat = 48
    
    // MARK: Semantic Icon Sizes
    
    /// Tab bar icon size
    public static let tabBar: CGFloat = 22
    
    /// Button icon size
    public static let button: CGFloat = 18
    
    /// Card header icon size
    public static let card: CGFloat = 28
}

// MARK: - Opacity System

/// Opacity tokens for consistent transparency effects.
public enum Opacity {
    /// Full opacity (no transparency)
    public static let full: Double = 1.0
    
    /// High opacity (slightly transparent)
    public static let high: Double = 0.85
    
    /// Medium opacity
    public static let medium: Double = 0.6
    
    /// Low opacity (very transparent)
    public static let low: Double = 0.4
    
    /// Extra low opacity (barely visible)
    public static let xlow: Double = 0.25
    
    /// Disabled opacity for interactive elements
    public static let disabled: Double = 0.5
}

// MARK: - Shadow System

/// Shadow tokens for consistent elevation effects.
public enum Shadow {
    /// No shadow
    public static let none = (radius: CGFloat(0), x: CGFloat(0), y: CGFloat(0))
    
    /// Small shadow for subtle elevation
    public static let sm = (radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
    
    /// Medium shadow for cards
    public static let md = (radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
    
    /// Large shadow for prominent elements
    public static let lg = (radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
    
    /// Extra large shadow for floating elements
    public static let xl = (radius: CGFloat(24), x: CGFloat(0), y: CGFloat(12))
}

// MARK: - Animation System

/// Animation tokens for consistent motion design.
public enum AnimationDuration {
    /// Extra fast: 0.1s
    public static let xfast: Double = 0.1
    
    /// Fast: 0.2s
    public static let fast: Double = 0.2
    
    /// Normal: 0.3s
    public static let normal: Double = 0.3
    
    /// Slow: 0.5s
    public static let slow: Double = 0.5
    
    /// Extra slow: 0.8s
    public static let xslow: Double = 0.8
}

// MARK: - View Modifiers

#if os(iOS)
public extension View {
    // MARK: Card Styles
    
    /// Applies standard card styling with padding, background, and shadow.
    /// - Returns: A view styled as a card component.
    func cardStyle() -> some View {
        self
            .padding(Spacing.Component.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(.background)
                    .shadow(
                        color: .black.opacity(0.06),
                        radius: Shadow.md.radius,
                        x: Shadow.md.x,
                        y: Shadow.md.y
                    )
            )
    }
    
    /// Applies compact card styling with less padding.
    /// - Returns: A view styled as a compact card.
    func compactCardStyle() -> some View {
        self
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(.background)
                    .shadow(
                        color: .black.opacity(0.04),
                        radius: Shadow.sm.radius,
                        x: Shadow.sm.x,
                        y: Shadow.sm.y
                    )
            )
    }
    
    // MARK: Label Styles
    
    /// Applies standard label styling with proper font and color.
    /// - Returns: A view styled as a label.
    func labelStyle() -> some View {
        self
            .font(Typography.label)
            .foregroundStyle(.secondary)
    }
    
    /// Applies uppercase label styling.
    /// - Returns: A view styled as an uppercase label.
    func uppercaseLabel() -> some View {
        self
            .font(Typography.labelUppercase)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .tracking(0.5) // Slightly increased letter spacing for uppercase
    }
    
    // MARK: Button Styles
    
    /// Applies primary button styling.
    /// - Returns: A view styled as a primary button.
    func primaryButtonStyle() -> some View {
        self
            .font(Typography.body.weight(.semibold))
            .padding(.horizontal, Spacing.Component.buttonPaddingH)
            .padding(.vertical, Spacing.Component.buttonPaddingV)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.button)
                    .fill(.tint)
            )
            .foregroundStyle(.white)
    }
    
    /// Applies secondary button styling.
    /// - Returns: A view styled as a secondary button.
    func secondaryButtonStyle() -> some View {
        self
            .font(Typography.body.weight(.medium))
            .padding(.horizontal, Spacing.Component.buttonPaddingH)
            .padding(.vertical, Spacing.Component.buttonPaddingV)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.button)
                    .fill(.tint.opacity(0.1))
            )
            .foregroundStyle(.tint)
    }
    
    // MARK: Badge Styles
    
    /// Applies badge styling with accent color.
    /// - Returns: A view styled as a badge.
    func badgeStyle() -> some View {
        self
            .font(Typography.labelUppercase)
            .textCase(.uppercase)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.badge)
                    .fill(.tint.opacity(0.1))
            )
            .foregroundStyle(.tint)
    }
    
    // MARK: Icon Modifiers
    
    /// Applies standard icon styling with proper sizing and weight.
    /// - Parameter size: The icon size to apply (default: .md)
    /// - Returns: A view styled as an icon.
    func iconStyle(size: CGFloat = IconSize.md) -> some View {
        self
            .font(.system(size: size, weight: .medium))
            .imageScale(.medium)
    }
    
    // MARK: Section Modifiers
    
    /// Applies section spacing for vertical lists.
    /// - Returns: A view with proper section spacing.
    func sectionSpacing() -> some View {
        self
            .padding(.vertical, Spacing.Component.sectionSpacing / 2)
    }
    
    /// Applies screen edge padding.
    /// - Returns: A view with standard screen edge padding.
    func screenPadding() -> some View {
        self
            .padding(.horizontal, Spacing.Component.screenEdge)
    }
}
#endif

// MARK: - Layout Constants

/// Layout-specific constants for consistent sizing and constraints.
public enum Layout {
    // MARK: Minimum Sizes
    
    /// Minimum touch target size (Apple HIG recommendation)
    public static let minTouchTarget: CGFloat = 44
    
    /// Minimum button height
    public static let minButtonHeight: CGFloat = 50
    
    // MARK: Maximum Sizes
    
    /// Maximum content width for readability on larger screens
    public static let maxContentWidth: CGFloat = 600
    
    /// Maximum card width
    public static let maxCardWidth: CGFloat = 400
    
    // MARK: Tab Bar
    
    /// Tab bar height
    public static let tabBarHeight: CGFloat = 60
    
    /// Tab bar icon container size
    public static let tabBarIconSize: CGFloat = 32
}

// MARK: - Transitions

/// Pre-configured transitions for common animations.
/// Uses computed properties for Swift 6 concurrency safety.
public enum Transitions {
    /// Slide transition from bottom
    public static var slideUp: AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }

    /// Slide transition from trailing edge
    public static var slideTrailing: AnyTransition {
        .move(edge: .trailing).combined(with: .opacity)
    }

    /// Scale and fade transition
    public static var scaleFade: AnyTransition {
        .scale(scale: 0.9).combined(with: .opacity)
    }

    /// Asymmetric slide transition
    public static var asymmetricSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}
