//
//  RadialHistoryGlanceView.swift
//  pawWatch Watch App
//
//  Purpose: Radial history display component showing recent GPS fixes
//  Created: 2025-12-15
//

import SwiftUI
import pawWatchFeature

// MARK: - Radial History Glance

struct RadialHistoryGlanceView: View {
    @Bindable var manager: WatchLocationManager
    private let maxItems = 8

    var body: some View {
        List {
            if manager.recentFixes.isEmpty {
                RadialHistoryEmptyState()
                    .listRowBackground(Color.clear)
            } else {
                ForEach(manager.recentFixes.prefix(maxItems), id: \.sequence) { fix in
                    GlassPill {
                        RadialFixRow(fix: fix)
                    }
                    .listRowInsets(EdgeInsets(top: Spacing.xxxs, leading: Spacing.xs, bottom: Spacing.xxxs, trailing: Spacing.xs))
                }
            }
        }
        .listStyle(.carousel)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .background(WatchGlassBackground())
    }
}

// MARK: - Radial History Empty State

struct RadialHistoryEmptyState: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "location.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No recent fixes")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Start tracking to populate the glance.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 32)
    }
}

// MARK: - Radial Fix Row

struct RadialFixRow: View {
    let fix: LocationFix
    private let maxAge: TimeInterval = 15 * 60

    var body: some View {
        HStack(spacing: Spacing.sm) {
            RadialRing(
                progress: progress(for: fix.timestamp),
                color: SharedUtilities.accuracyColor(for: fix.horizontalAccuracyMeters),
                size: IconSize.xl - Spacing.xxxs,
                lineWidth: Spacing.xxs
            ) {
                Text(SharedUtilities.timeAgoShort(since: fix.timestamp))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                HStack(spacing: Spacing.xs) {
                    Text(SharedUtilities.timeAgoLong(since: fix.timestamp))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .monospacedDigit()

                    HStack(spacing: Spacing.xxxs) {
                        Image(systemName: SharedUtilities.batteryIcon(for: fix.batteryFraction))
                            .font(.caption2)
                        Text("\(Int((fix.batteryFraction * 100).rounded()))%")
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.secondary)
                }

                Text("±\(fix.horizontalAccuracyMeters, specifier: "%.0f") m")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private func progress(for timestamp: Date) -> CGFloat {
        let age = max(0, Date().timeIntervalSince(timestamp))
        let clamped = max(0.2, 1 - age / maxAge)
        return CGFloat(min(1, clamped))
    }
}

// MARK: - Radial Ring

struct RadialRing<Content: View>: View {
    let progress: CGFloat
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(Opacity.xlow * 0.6), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            content
        }
        .frame(width: size, height: size)
    }
}
