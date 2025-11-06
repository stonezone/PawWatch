//
//  ContentView.swift
//  pawWatch Watch App
//
//  Purpose: Main view for the watchOS app displaying pet tracking interface
//  Created: 2025-02-05
//

import SwiftUI
import WatchKit

@MainActor
struct ContentView: View {
    // MARK: - State Properties
    
    /// Current location tracking state
    @State private var isTracking = false
    
    /// Latest location fix information
    @State private var currentLocation: String = "Waiting for location..."
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // App title
                Text("pawWatch")
                    .font(.title3)
                    .fontWeight(.bold)
                
                // Location status display
                VStack(spacing: 8) {
                    Image(systemName: isTracking ? "location.fill" : "location.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(isTracking ? .green : .secondary)
                    
                    Text(currentLocation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Tracking toggle button
                Button(action: toggleTracking) {
                    Label(
                        isTracking ? "Stop Tracking" : "Start Tracking",
                        systemImage: isTracking ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(isTracking ? .red : .green)
            }
            .padding()
            .navigationTitle("Pet Tracker")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Actions
    
    /// Toggles location tracking on/off
    private func toggleTracking() {
        isTracking.toggle()
        
        if isTracking {
            startLocationTracking()
        } else {
            stopLocationTracking()
        }
    }
    
    /// Starts location tracking using WatchLocationProvider
    private func startLocationTracking() {
        currentLocation = "Acquiring location..."
        // TODO: Initialize WatchLocationProvider and start tracking
        print("Starting location tracking")
    }
    
    /// Stops location tracking and cleans up resources
    private func stopLocationTracking() {
        currentLocation = "Tracking stopped"
        // TODO: Stop WatchLocationProvider
        print("Stopping location tracking")
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
