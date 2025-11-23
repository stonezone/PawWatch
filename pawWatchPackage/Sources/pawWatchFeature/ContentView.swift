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

/// Entry point now delegates to `MainTabView`.
public struct ContentView: View {
    @EnvironmentObject private var locationManager: PetLocationManager

    public init() {}

    public var body: some View {
        MainTabView()
            .environmentObject(locationManager)
    }
}

#Preview { ContentView() }
#endif
