#if os(iOS)
import SwiftUI

/// Root tab controller for the iOS app with custom Liquid Glass tab bar.
public struct MainTabView: View {
    /// Tab selection options
    enum TabSelection: Hashable {
        case dashboard, history, settings
    }

    @Environment(PetLocationManager.self) private var locationManager
    @AppStorage("useMetricUnits") private var useMetricUnits = true
    @State private var selectedTab: TabSelection = .dashboard
    // P2-02: Track geofence violations for badge display
    @State private var geofenceMonitor: GeofenceMonitor?
    @State private var hasActiveViolation = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Tab content - manual switching to avoid native TabView artifacts
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView(useMetricUnits: useMetricUnits)
                case .history:
                    HistoryView(useMetricUnits: useMetricUnits)
                case .settings:
                    SettingsView(useMetricUnits: $useMetricUnits)
                }
            }

            // Custom Liquid Glass tab bar at bottom
            // P2-02: Pass badge info to tab bar
            LiquidGlassTabBar(
                selection: $selectedTab,
                items: tabItems,
                badgedTabs: hasActiveViolation ? [.dashboard] : []
            ) { tab in
                withAnimation(Animations.standard) {
                    selectedTab = tab
                }
            }
            .padding(.bottom, 4)
        }
        .background {
            GlassSurface { Color.clear }
                .ignoresSafeArea()
        }
        // P2-02: Monitor geofence events for badge updates
        .task {
            geofenceMonitor = GeofenceMonitor()
            // Poll for violations every few seconds
            while !Task.isCancelled {
                if let monitor = geofenceMonitor {
                    let events = await monitor.getRecentEvents(limit: 10)
                    // Check if any recent exit events in the last 5 minutes
                    let now = Date()
                    let recentExits = events.filter { event in
                        event.type == .exited && now.timeIntervalSince(event.timestamp) < 300
                    }
                    hasActiveViolation = !recentExits.isEmpty
                }
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }
}

private extension MainTabView {
    var tabItems: [(icon: String, title: String, tag: TabSelection)] {
        [
            ("house.fill", "Dashboard", .dashboard),
            ("clock.arrow.circlepath", "History", .history),
            ("gearshape.fill", "Settings", .settings)
        ]
    }
}

// MARK: - Shared Components

/// Centers scrollable content and constrains width for large devices so cards never overflow portrait.
/// iOS 26+: Uses native scroll edge effects for modern glass blur at edges.
struct GlassScroll<Content: View>: View {
    private let spacing: CGFloat
    private let maximumWidth: CGFloat
    private let horizontalPadding: CGFloat
    private let enableParallax: Bool
    @ViewBuilder private let content: Content

    @State private var scrollOffset: CGFloat = 0

    init(
        spacing: CGFloat = 24,
        maxWidth: CGFloat = 420,
        horizontalPadding: CGFloat = 18,
        enableParallax: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.maximumWidth = maxWidth
        self.horizontalPadding = horizontalPadding
        self.enableParallax = enableParallax
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let clampedWidth = max(0, min(maximumWidth, proxy.size.width - horizontalPadding * 2))
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: spacing) {
                    content
                }
                .frame(maxWidth: clampedWidth, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(
                    GeometryReader { scrollProxy in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: scrollProxy.frame(in: .named("scroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                if enableParallax {
                    scrollOffset = value
                }
            }
            .modifier(ScrollEdgeEffectModifier())
        }
        .environment(\.scrollOffset, scrollOffset)
    }
}

/// iOS 26 scroll edge effect modifier
private struct ScrollEdgeEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .scrollEdgeEffectStyle(.soft, for: .top)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            content
        }
    }
}

// MARK: - Scroll Offset Environment

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollOffsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var scrollOffset: CGFloat {
        get { self[ScrollOffsetKey.self] }
        set { self[ScrollOffsetKey.self] = newValue }
    }
}

// MARK: - Parallax Card Modifier

private struct ParallaxCardModifier: ViewModifier {
    let index: Int
    @Environment(\.scrollOffset) private var scrollOffset

    func body(content: Content) -> some View {
        content
            .offset(y: parallaxOffset)
    }

    private var parallaxOffset: CGFloat {
        // Subtle parallax: cards further down move slightly slower
        let baseOffset = scrollOffset * 0.05
        let indexMultiplier = CGFloat(index) * 0.02
        return baseOffset * (1 - indexMultiplier)
    }
}

extension View {
    func parallaxCard(index: Int) -> some View {
        modifier(ParallaxCardModifier(index: index))
    }
}

#endif
