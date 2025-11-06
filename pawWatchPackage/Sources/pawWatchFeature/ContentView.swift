//
//  ContentView.swift
//  pawWatch
//
//  Purpose: Main iPhone app dashboard combining pet status and map.
//           iOS 26 Liquid Glass design with real-time GPS updates.
//
//  Author: Created for pawWatch
//  Created: 2025-11-05
//  Swift: 6.2
//  Platform: iOS 26.1+
//

#if os(iOS)
import SwiftUI

/// Main iPhone dashboard for pawWatch app.
///
/// Features:
/// - Pet status card showing GPS metadata (Liquid Glass design)
/// - MapKit view with pet location, trail, and owner position
/// - Real-time updates from Apple Watch via WatchConnectivity
/// - Manual refresh button
/// - Smooth spring animations for all state changes
///
/// Usage:
/// ```swift
/// ContentView() // Automatically creates PetLocationManager
/// ```
public struct ContentView: View {

    // MARK: - State

    /// Location manager handling Watch connectivity and GPS data
    @State private var locationManager = PetLocationManager()

    /// Manual refresh button rotation animation
    @State private var isRefreshing = false

    // MARK: - Initialization

    public init() {}

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient (Liquid Glass base)
                LinearGradient(
                    colors: [.blue.opacity(0.1), .purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Pet status card
                        PetStatusCard(locationManager: locationManager)
                            .padding(.top, 8)

                        // Map view
                        PetMapView(locationManager: locationManager)
                            .frame(height: 400)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                            .padding(.horizontal, 20)

                        // Location history count
                        if !locationManager.locationHistory.isEmpty {
                            HistoryCountView(count: locationManager.locationHistory.count)
                        }

                        Spacer(minLength: 40)
                    }
                }
                .refreshable {
                    // Pull-to-refresh gesture
                    await performRefresh()
                }
            }
            .navigationTitle("pawWatch")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    RefreshButton(
                        isRefreshing: $isRefreshing,
                        action: {
                            Task {
                                await performRefresh()
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Actions

    /// Manually request location update from Apple Watch.
    @MainActor
    private func performRefresh() async {
        guard !isRefreshing else { return }

        withAnimation(.spring(response: 0.3)) {
            isRefreshing = true
        }

        // Request update from Watch
        locationManager.requestUpdate()

        // Minimum refresh duration for visual feedback
        try? await Task.sleep(for: .milliseconds(800))

        withAnimation(.spring(response: 0.3)) {
            isRefreshing = false
        }
    }
}

// MARK: - Refresh Button

/// Manual refresh button with rotation animation.
struct RefreshButton: View {
    @Binding var isRefreshing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.blue.gradient)
                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                .animation(
                    isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .spring(response: 0.3),
                    value: isRefreshing
                )
        }
        .disabled(isRefreshing)
    }
}

// MARK: - History Count View

/// Displays number of GPS fixes in trail history.
struct HistoryCountView: View {
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Trail: \(count) location\(count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial) // Liquid Glass pill
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
#endif
