//
//  pawWatchApp.swift
//  pawWatch Watch App
//
//  Purpose: Main entry point for the watchOS app using SwiftUI lifecycle
//  Created: 2025-02-05
//

import SwiftUI
import WatchKit

@main
struct pawWatch_Watch_App: App {
    // MARK: - Properties
    
    // Scene phase tracking for app lifecycle management
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }
    
    // MARK: - Lifecycle Methods
    
    /// Handles app lifecycle transitions for proper resource management
    /// - Parameters:
    ///   - oldPhase: Previous scene phase
    ///   - newPhase: New scene phase
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active - initialize location services if needed
            print("pawWatch Watch App became active")
            
        case .inactive:
            // App became inactive - pause non-critical tasks
            print("pawWatch Watch App became inactive")
            
        case .background:
            // App moved to background - preserve state and minimize resource usage
            print("pawWatch Watch App moved to background")
            
        @unknown default:
            break
        }
    }
}
