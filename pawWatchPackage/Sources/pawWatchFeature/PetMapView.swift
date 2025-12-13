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

#if os(iOS)
import SwiftUI
import MapKit
import UIKit

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
/// PetMapView()
///     .environment(PetLocationManager())
/// ```
public struct PetMapView: View {

    // MARK: - Dependencies

    /// Location manager providing pet GPS data
    @Environment(PetLocationManager.self) private var locationManager

    // MARK: - State

    private enum MapStyleChoice: String, CaseIterable, Identifiable {
        case standard
        case hybrid
        case satellite

        var id: String { rawValue }

        var label: String {
            switch self {
            case .standard: return "Standard"
            case .hybrid: return "Hybrid"
            case .satellite: return "Satellite"
            }
        }

        var mapStyle: MapStyle {
            switch self {
            case .standard:
                return .standard(elevation: .flat)
            case .hybrid:
                return .hybrid(elevation: .flat)
            case .satellite:
                return .imagery(elevation: .flat)
            }
        }
    }

    @AppStorage("pawWatch.mapStyleChoice") private var mapStyleChoice: MapStyleChoice = .standard

    /// Map camera position
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var zoomScale: Double = 1.0
    /// Track if we have a valid size to prevent Metal crashes during transitions
    @State private var hasValidSize = false
    /// Last valid size for restoration
    @State private var lastValidSize: CGSize = .zero

    // MARK: - Body

    public var body: some View {
        // CRITICAL FIX: Multi-layer protection against Metal multisampling crash
        // iOS 26 Map with CAMetalLayer crashes if size becomes zero during view lifecycle
        GeometryReader { geometry in
            let isValidSize = geometry.size.width >= 20 && geometry.size.height >= 20

            Group {
                if isValidSize && hasValidSize {
                    mapContent
                        // Ensure explicit minimum frame to prevent layout collapse
                        .frame(
                            minWidth: 20,
                            idealWidth: geometry.size.width,
                            maxWidth: .infinity,
                            minHeight: 20,
                            idealHeight: geometry.size.height,
                            maxHeight: .infinity
                        )
                        // Clip any overflow to prevent Metal from rendering outside bounds
                        .clipped()
                } else {
                    // Placeholder with matching background while waiting for valid size
                    Color(.systemBackground)
                        .opacity(0.5)
                }
            }
            .task(id: isValidSize) {
                guard isValidSize else { return }
                lastValidSize = geometry.size
                // Delay to ensure Metal layer is ready - using Swift Concurrency for proper cancellation
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                hasValidSize = true
            }
        }
        // Prevent map from ever having zero intrinsic size
        .frame(minWidth: 20, minHeight: 20)
    }

    /// The actual map content, separated to prevent zero-size Metal rendering crashes
    @ViewBuilder
    private var mapContent: some View {
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
                    PetMarkerView(sequence: petLocation.sequence)
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
        .mapStyle(mapStyleChoice.mapStyle) // Use flat to avoid iOS 26 Metal multisampling crash
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .overlay(alignment: .topTrailing) {
            Menu {
                Picker("Map style", selection: $mapStyleChoice) {
                    ForEach(MapStyleChoice.allCases) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
            } label: {
                Image(systemName: "map.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(12)
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        zoomScale = max(0.25, zoomScale * 0.7)
                        updateCamera()
                    }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        zoomScale = min(8.0, zoomScale * 1.4)
                        updateCamera()
                    }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding(12)
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
            let rect = MKMapRect(coordinates: [petCoord, ownerCoord]).insetBy(dx: -250, dy: -250)
            let region = regionFromRect(rect)
            cameraPosition = .region(scaled(region, by: zoomScale))
        } else {
            // Show just pet with reasonable zoom
            let region = MKCoordinateRegion(
                center: petCoord,
                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
            )
            cameraPosition = .region(scaled(region, by: zoomScale))
        }
    }

    private func scaled(_ region: MKCoordinateRegion, by scale: Double) -> MKCoordinateRegion {
        let clampedScale = max(0.1, min(20.0, scale))
        let latitudeDelta = max(0.0002, min(40.0, region.span.latitudeDelta * clampedScale))
        let longitudeDelta = max(0.0002, min(40.0, region.span.longitudeDelta * clampedScale))
        return MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    private func regionFromRect(_ rect: MKMapRect) -> MKCoordinateRegion {
        let topLeft = MKMapPoint(x: rect.minX, y: rect.minY).coordinate
        let bottomRight = MKMapPoint(x: rect.maxX, y: rect.maxY).coordinate
        let center = CLLocationCoordinate2D(
            latitude: (topLeft.latitude + bottomRight.latitude) / 2,
            longitude: (topLeft.longitude + bottomRight.longitude) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: abs(topLeft.latitude - bottomRight.latitude),
            longitudeDelta: abs(topLeft.longitude - bottomRight.longitude)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Pet Marker

/// Custom pet location marker with paw icon and Liquid Glass effect.
struct PetMarkerView: View {
    @Environment(PetProfileStore.self) private var petProfileStore
    let sequence: Int

    var body: some View {
        ZStack {
            // Liquid Glass background
            Circle()
                .fill(.red.gradient)
                .frame(width: 48, height: 48)
                .shadow(color: .red.opacity(0.4), radius: 8, x: 0, y: 4)

            if let avatar = petAvatar {
                Image(uiImage: avatar)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else if let badge = pawBadge {
                Image(uiImage: badge)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: sequence) // Liquid bounce on new fixes
    }

    private var pawBadge: UIImage? {
        UIImage(named: "AppIcon") ?? UIImage(named: "AppIcon60x60@2x")
    }

    private var petAvatar: UIImage? {
        guard let data = petProfileStore.profile.avatarPNGData else { return nil }
        return UIImage(data: data)
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
#endif
