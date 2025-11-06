//
//  PetMapView.swift
//  pawWatch
//
//  Purpose: MapKit view displaying pet location, movement trail, and owner position.
//           Real-time updates with dynamic zoom and Liquid Glass design.
//
//  Author: Created for pawWatch
//  Created: 2025-11-05
//  Swift: 6.2
//  Platform: iOS 26.1+
//

import SwiftUI
import MapKit

/// MapKit view showing pet location with trail and owner position.
///
/// Features:
/// - Pet location marker (red paw icon)
/// - Movement trail from last 100 GPS fixes (blue polyline)
/// - Owner location marker (green person icon)
/// - Dynamic zoom to show both pet and owner
/// - Real-time marker updates with smooth animations
///
/// Usage:
/// ```swift
/// PetMapView(locationManager: locationManager)
/// ```
public struct PetMapView: View {

    // MARK: - Dependencies

    /// Location manager providing pet GPS data
    let locationManager: PetLocationManager

    // MARK: - State

    /// Map camera position
    @State private var cameraPosition: MapCameraPosition = .automatic

    // MARK: - Body

    public var body: some View {
        Map(position: $cameraPosition) {
            // Pet location marker
            if let petLocation = locationManager.latestLocation {
                Annotation(
                    "Pet",
                    coordinate: CLLocationCoordinate2D(
                        latitude: petLocation.coordinate.latitude,
                        longitude: petLocation.coordinate.longitude
                    )
                ) {
                    PetMarkerView()
                }
            }

            // Movement trail (polyline connecting historical fixes)
            if locationManager.locationHistory.count >= 2 {
                MapPolyline(coordinates: trailCoordinates)
                    .stroke(.blue.opacity(0.7), lineWidth: 3)
            }

            // Owner location marker
            if let ownerLocation = locationManager.ownerLocation {
                Annotation(
                    "You",
                    coordinate: ownerLocation.coordinate
                ) {
                    OwnerMarkerView()
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onAppear {
            updateCamera()
        }
        .onChange(of: locationManager.latestLocation) { _, _ in
            // Smooth camera update when pet moves
            withAnimation(.easeInOut(duration: 1.0)) {
                updateCamera()
            }
        }
    }

    // MARK: - Helpers

    /// Extract CLLocationCoordinate2D array from location history for trail rendering.
    private var trailCoordinates: [CLLocationCoordinate2D] {
        locationManager.locationHistory.map { fix in
            CLLocationCoordinate2D(
                latitude: fix.coordinate.latitude,
                longitude: fix.coordinate.longitude
            )
        }
    }

    /// Update camera to show both pet and owner (or just pet if owner unavailable).
    private func updateCamera() {
        guard let petLocation = locationManager.latestLocation else { return }

        let petCoord = CLLocationCoordinate2D(
            latitude: petLocation.coordinate.latitude,
            longitude: petLocation.coordinate.longitude
        )

        // If owner location available, show both with padding
        if let ownerCoord = locationManager.ownerLocation?.coordinate {
            let rect = MKMapRect(
                coordinates: [petCoord, ownerCoord]
            )
            cameraPosition = .rect(rect.insetBy(dx: -1000, dy: -1000))
        } else {
            // Show just pet with reasonable zoom
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: petCoord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        }
    }
}

// MARK: - Pet Marker

/// Custom pet location marker with paw icon and Liquid Glass effect.
struct PetMarkerView: View {
    var body: some View {
        ZStack {
            // Liquid Glass background
            Circle()
                .fill(.red.gradient)
                .frame(width: 44, height: 44)
                .shadow(color: .red.opacity(0.4), radius: 8, x: 0, y: 4)

            // Paw icon
            Image(systemName: "pawprint.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: UUID()) // Liquid bounce
    }
}

// MARK: - Owner Marker

/// Custom owner location marker with person icon and Liquid Glass effect.
struct OwnerMarkerView: View {
    var body: some View {
        ZStack {
            // Liquid Glass background
            Circle()
                .fill(.green.gradient)
                .frame(width: 44, height: 44)
                .shadow(color: .green.opacity(0.4), radius: 8, x: 0, y: 4)

            // Person icon
            Image(systemName: "person.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - MKMapRect Extension

extension MKMapRect {
    /// Create MKMapRect encompassing all coordinates with padding.
    init(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else {
            self = .world
            return
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let topLeft = MKMapPoint(CLLocationCoordinate2D(latitude: maxLat, longitude: minLon))
        let bottomRight = MKMapPoint(CLLocationCoordinate2D(latitude: minLat, longitude: maxLon))

        self = MKMapRect(
            x: topLeft.x,
            y: topLeft.y,
            width: bottomRight.x - topLeft.x,
            height: bottomRight.y - topLeft.y
        )
    }
}
