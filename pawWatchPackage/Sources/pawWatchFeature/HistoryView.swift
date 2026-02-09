#if os(iOS)
import SwiftUI
import UIKit

/// History view displaying recent location fixes in a list
@MainActor
struct HistoryView: View {
    @Environment(PetLocationManager.self) private var locationManager
    let useMetricUnits: Bool

    // P6-05: Filter state
    @State private var showFilters = false
    @State private var filterDate: Date? = nil
    @State private var maxAccuracyFilter: Double = 0 // 0 = no filter

    /// Filtered location history based on active filters
    private var filteredHistory: [LocationFix] {
        locationManager.locationHistory.filter { fix in
            // Date filter: only show fixes from selected date onward
            if let filterDate {
                guard fix.timestamp >= filterDate else { return false }
            }
            // Accuracy filter: only show fixes better than threshold
            if maxAccuracyFilter > 0 {
                guard fix.horizontalAccuracyMeters <= maxAccuracyFilter else { return false }
            }
            return true
        }
    }

    private var hasActiveFilters: Bool {
        filterDate != nil || maxAccuracyFilter > 0
    }

    var body: some View {
        GlassScroll(spacing: Spacing.lg, maxWidth: 340, enableParallax: false) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("History")
                            .font(Typography.pageTitle)
                        Text("Recent location fixes")
                            .font(Typography.pageSubtitle)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    // P6-05: Filter toggle button
                    if !locationManager.locationHistory.isEmpty {
                        Button {
                            withAnimation(Animations.standard) {
                                showFilters.toggle()
                            }
                        } label: {
                            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.title3)
                                .foregroundStyle(hasActiveFilters ? .blue : .secondary)
                        }
                        .accessibilityLabel(showFilters ? "Hide filters" : "Show filters")
                        .accessibilityHint(hasActiveFilters ? "Filters are active" : "Filter by date or accuracy")
                    }
                }
            }
            .padding(.top, Spacing.xxxl)

            // P6-05: Collapsible filter controls
            if showFilters {
                filterControls
            }

            if locationManager.locationHistory.isEmpty {
                emptyStateView
                    .contentTransition(.opacity)
            } else if filteredHistory.isEmpty {
                noResultsView
                    .contentTransition(.opacity)
            } else {
                ForEach(Array(filteredHistory.enumerated()), id: \.offset) { index, fix in
                    GlassCard(cornerRadius: CornerRadius.lg, padding: Spacing.lg) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack {
                                Text("Fix #\(locationManager.locationHistory.count - index)")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(Self.dateFormatter.string(from: fix.timestamp))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text(String(format: "Lat: %.5f", fix.coordinate.latitude))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "Lon: %.5f", fix.coordinate.longitude))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("Accuracy: " + MeasurementDisplay.accuracy(fix.horizontalAccuracyMeters, useMetric: useMetricUnits))
                                    .font(.caption)
                                Spacer()
                                Text(String(format: "Battery: %.0f%%", fix.batteryFraction * 100))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    // P6-01: Context menu for history items
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = String(
                                format: "%.6f, %.6f",
                                fix.coordinate.latitude,
                                fix.coordinate.longitude
                            )
                        } label: {
                            Label("Copy Coordinates", systemImage: "doc.on.doc")
                        }

                        ShareLink(
                            item: String(
                                format: "Pet location: %.6f, %.6f (accuracy: ±%.0fm) at %@",
                                fix.coordinate.latitude,
                                fix.coordinate.longitude,
                                fix.horizontalAccuracyMeters,
                                Self.dateFormatter.string(from: fix.timestamp)
                            )
                        ) {
                            Label("Share Location", systemImage: "square.and.arrow.up")
                        }
                    }
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
                }
                .contentTransition(.opacity)
            }

            Spacer(minLength: Spacing.xxxl + Spacing.sm)
        }
        .refreshable {
            locationManager.requestUpdate(force: true)
        }
    }

    private var emptyStateView: some View {
        GlassCard(cornerRadius: CornerRadius.lg, padding: Spacing.Component.cardPadding) {
            VStack(spacing: Spacing.lg) {
                Image(systemName: "pawprint.circle")
                    .font(.system(size: IconSize.xxl * 1.5))
                    .foregroundStyle(.secondary)
                    .padding(.top, Spacing.md)

                VStack(spacing: Spacing.xs) {
                    Text("No Location History")
                        .font(Typography.cardTitle)
                        .foregroundStyle(.primary)

                    Text("Start tracking on your Apple Watch to see your pet's location trail here.")
                        .font(Typography.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.bottom, Spacing.md)
            }
        }
        .padding(.top, Spacing.xl)
    }

    // P6-05: Filter controls UI
    private var filterControls: some View {
        GlassCard(cornerRadius: CornerRadius.md, padding: Spacing.md + Spacing.xxxs) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Date filter
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Since")
                        .font(Typography.label)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if filterDate != nil {
                        Button("Clear") {
                            withAnimation(Animations.quick) { filterDate = nil }
                        }
                        .font(.caption)
                    }
                }

                HStack(spacing: Spacing.sm) {
                    filterDateButton("1h", hours: 1)
                    filterDateButton("6h", hours: 6)
                    filterDateButton("24h", hours: 24)
                    filterDateButton("7d", hours: 168)
                }

                Divider()

                // Accuracy filter
                HStack {
                    Image(systemName: "scope")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Max accuracy")
                        .font(Typography.label)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(maxAccuracyFilter > 0 ? "\(Int(maxAccuracyFilter))m" : "Any")
                        .font(Typography.label)
                        .foregroundStyle(maxAccuracyFilter > 0 ? .blue : .secondary)
                }

                HStack(spacing: Spacing.sm) {
                    filterAccuracyButton("Any", value: 0)
                    filterAccuracyButton("10m", value: 10)
                    filterAccuracyButton("50m", value: 50)
                    filterAccuracyButton("100m", value: 100)
                }

                if hasActiveFilters {
                    Text("\(filteredHistory.count) of \(locationManager.locationHistory.count) fixes")
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }

    private func filterDateButton(_ label: String, hours: Int) -> some View {
        let target = Date().addingTimeInterval(-Double(hours) * 3600)
        let isSelected = filterDate != nil && abs((filterDate ?? .distantPast).timeIntervalSince(target)) < 60
        return Button(label) {
            withAnimation(Animations.quick) {
                filterDate = isSelected ? nil : target
            }
        }
        .font(Typography.captionSmall.weight(.medium))
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(isSelected ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1))
        .clipShape(Capsule())
        .foregroundStyle(isSelected ? .blue : .primary)
    }

    private func filterAccuracyButton(_ label: String, value: Double) -> some View {
        let isSelected = maxAccuracyFilter == value
        return Button(label) {
            withAnimation(Animations.quick) {
                maxAccuracyFilter = isSelected ? 0 : value
            }
        }
        .font(Typography.captionSmall.weight(.medium))
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(isSelected ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1))
        .clipShape(Capsule())
        .foregroundStyle(isSelected ? .blue : .primary)
    }

    // P6-05: No results after filtering
    private var noResultsView: some View {
        GlassCard(cornerRadius: CornerRadius.lg, padding: Spacing.Component.cardPadding) {
            VStack(spacing: Spacing.md) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: IconSize.xl))
                    .foregroundStyle(.secondary)

                Text("No Matching Fixes")
                    .font(Typography.cardTitle)

                Text("Try adjusting your filters to see more results.")
                    .font(Typography.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Clear Filters") {
                    withAnimation(Animations.standard) {
                        filterDate = nil
                        maxAccuracyFilter = 0
                    }
                }
                .font(Typography.body.weight(.medium))
                .foregroundStyle(.blue)
            }
        }
        .padding(.top, Spacing.xl)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        formatter.locale = .current
        return formatter
    }()
}

#endif
