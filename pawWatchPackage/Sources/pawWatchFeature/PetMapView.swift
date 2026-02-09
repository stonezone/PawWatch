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
            let isValidSize = geometry.size.width >= MapConstants.minRenderSize && geometry.size.height >= MapConstants.minRenderSize

            Group {
                if isValidSize && hasValidSize {
                    mapContent
                        // Ensure explicit minimum frame to prevent layout collapse
                        .frame(
                            minWidth: MapConstants.minRenderSize,
                            idealWidth: geometry.size.width,
                            maxWidth: .infinity,
                            minHeight: MapConstants.minRenderSize,
                            idealHeight: geometry.size.height,
                            maxHeight: .infinity
                        )
                        // Clip any overflow to prevent Metal from rendering outside bounds
                        .clipped()
                } else {
                    // P1-08: Improved loading state with proper feedback
                    mapLoadingView
                }
            }
            .task(id: isValidSize) {
                guard isValidSize else { return }
                lastValidSize = geometry.size
                // Delay to ensure Metal layer is ready - using Swift Concurrency for proper cancellation
                try? await Task.sleep(for: .milliseconds(MapConstants.renderDelayMs))
                guard !Task.isCancelled else { return }
                hasValidSize = true
            }
        }
        // Prevent map from ever having zero intrinsic size
        .frame(minWidth: MapConstants.minRenderSize, minHeight: MapConstants.minRenderSize)
        // Accessibility
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityMapLabel)
        .accessibilityHint("Map showing pet and owner locations. Swipe to explore markers.")
    }

    /// Dynamic accessibility label based on current map state
    private var accessibilityMapLabel: String {
        let hasPet = locationManager.latestLocation != nil
        let hasOwner = locationManager.ownerLocation != nil

        return AccessibilityHelper.formatMapRegion(
            hasPetLocation: hasPet,
            hasOwnerLocation: hasOwner
        )
    }

    /// P1-08: Loading view shown while map initializes
    private var mapLoadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .controlSize(.large)
                .tint(LiquidGlassTheme.current.accentPrimary)

            Text("Loading map...")
                .font(Typography.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).opacity(0.95))
    }

    /// The actual map content, separated to prevent zero-size Metal rendering crashes
    @ViewBuilder
    private var mapContent: some View {
        Map(position: $cameraPosition) {
            // Pet location marker (actual or predicted)
            if let petLocation = locationManager.latestLocation {
                let coordinate = CLLocationCoordinate2D(
                    latitude: petLocation.coordinate.latitude,
                    longitude: petLocation.coordinate.longitude
                )

                Annotation("Pet", coordinate: coordinate) {
                    PetMarkerView(
                        sequence: petLocation.sequence,
                        isPredicted: false
                    )
                }
            }

            // Predicted location marker (if available and different from actual)
            if let predicted = locationManager.predictedLocation,
               locationManager.latestLocation != nil {
                let predictedCoord = CLLocationCoordinate2D(
                    latitude: predicted.coordinate.latitude,
                    longitude: predicted.coordinate.longitude
                )

                Annotation("Predicted", coordinate: predictedCoord) {
                    PredictedMarkerView(prediction: predicted)
                }

                // Show confidence radius as a circle overlay
                MapCircle(
                    center: predictedCoord,
                    radius: predicted.confidenceRadius
                )
                .foregroundStyle(.blue.opacity(0.15))
                .stroke(.blue.opacity(0.5), lineWidth: 2)
            }

            // P6-04: Movement trail colored by recency
            if locationManager.locationHistory.count >= 2 {
                // Segment trail into recent (solid blue) and older (faded, dashed) portions
                let recentCount = min(locationManager.locationHistory.count, MapConstants.trailRecentCount)
                let olderCount = locationManager.locationHistory.count - recentCount

                // Older trail (faded and dashed)
                if olderCount >= MapConstants.trailMinFixCount {
                    let olderCoords = Array(trailCoordinates.prefix(olderCount + 1))
                    MapPolyline(coordinates: olderCoords)
                        .stroke(.blue.opacity(0.3), style: StrokeStyle(lineWidth: MapConstants.trailOlderLineWidth, dash: MapConstants.trailDashPattern))
                }

                // Recent trail (solid bright blue)
                if recentCount >= MapConstants.trailMinFixCount {
                    let recentStartIndex = max(0, trailCoordinates.count - recentCount)
                    let recentCoords = Array(trailCoordinates.suffix(from: recentStartIndex))
                    MapPolyline(coordinates: recentCoords)
                        .stroke(.blue.opacity(0.8), lineWidth: MapConstants.trailRecentLineWidth)
                }
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
            // P3-12: Safe area aware map style control
            GeometryReader { geometry in
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
                .padding(adaptiveControlPadding(for: geometry.size))
                .accessibilityLabel("Map style menu")
                .accessibilityHint("Choose between standard, hybrid, or satellite map views")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // P3-12: Safe area aware zoom controls
            GeometryReader { geometry in
                VStack(spacing: adaptiveControlSpacing(for: geometry.size)) {
                    Button {
                        withAnimation(Animations.quickEase) {
                            zoomScale = max(MapConstants.zoomScaleMin, zoomScale * MapConstants.zoomInFactor)
                            updateCamera()
                        }
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Zoom in")
                    .accessibilityHint("Zoom in on the map to see more detail")

                    Button {
                        withAnimation(Animations.quickEase) {
                            zoomScale = min(MapConstants.zoomScaleMax, zoomScale * MapConstants.zoomOutFactor)
                            updateCamera()
                        }
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Zoom out")
                    .accessibilityHint("Zoom out on the map to see more area")
                }
                .padding(adaptiveControlPadding(for: geometry.size))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .onAppear {
            updateCamera()
        }
        .onChange(of: locationManager.latestLocation) { _, _ in
            // Smooth camera update when pet moves
            withAnimation(Animations.mapCamera) {
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
            let rect = MKMapRect(coordinates: [petCoord, ownerCoord]).insetBy(dx: MapConstants.boundingRectInset, dy: MapConstants.boundingRectInset)
            let region = regionFromRect(rect)
            cameraPosition = .region(scaled(region, by: zoomScale))
        } else {
            // Show just pet with reasonable zoom
            let region = MKCoordinateRegion(
                center: petCoord,
                span: MKCoordinateSpan(latitudeDelta: MapConstants.defaultSpanDelta, longitudeDelta: MapConstants.defaultSpanDelta)
            )
            cameraPosition = .region(scaled(region, by: zoomScale))
        }
    }

    private func scaled(_ region: MKCoordinateRegion, by scale: Double) -> MKCoordinateRegion {
        let clampedScale = max(MapConstants.scaleDeltaMin, min(MapConstants.scaleDeltaMax, scale))
        let latitudeDelta = max(MapConstants.coordDeltaMin, min(MapConstants.coordDeltaMax, region.span.latitudeDelta * clampedScale))
        let longitudeDelta = max(MapConstants.coordDeltaMin, min(MapConstants.coordDeltaMax, region.span.longitudeDelta * clampedScale))
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

    // P3-12: Adaptive control spacing for small screens
    private func adaptiveControlSpacing(for size: CGSize) -> CGFloat {
        // Reduce spacing on smaller screens (iPhone SE)
        if size.height < MapConstants.smallScreenHeight {
            return Spacing.xs
        } else if size.height < MapConstants.mediumScreenHeight {
            return Spacing.sm
        } else {
            return Spacing.sm + Spacing.xxxs
        }
    }

    // P3-12: Adaptive padding to prevent overlap with safe areas
    private func adaptiveControlPadding(for size: CGSize) -> CGFloat {
        // Use smaller padding on compact devices
        if size.width < MapConstants.compactScreenWidth {
            return Spacing.sm
        } else {
            return Spacing.md
        }
    }
}

// MARK: - Pet Marker

/// Custom pet location marker with paw icon and Liquid Glass effect.
struct PetMarkerView: View {
    @Environment(PetProfileStore.self) private var petProfileStore
    let sequence: Int
    let isPredicted: Bool

    var body: some View {
        ZStack {
            // Liquid Glass background
            Circle()
                .fill(isPredicted ? Color.orange.gradient : Color.red.gradient)
                .frame(width: MapConstants.petMarkerSize, height: MapConstants.petMarkerSize)
                .shadow(color: (isPredicted ? Color.orange : Color.red).opacity(0.4), radius: 8, x: 0, y: 4)

            if let avatar = petAvatar {
                Image(uiImage: avatar)
                    .resizable()
                    .scaledToFill()
                    .frame(width: MapConstants.petMarkerIconSize, height: MapConstants.petMarkerIconSize)
                    .clipShape(Circle())
                    .opacity(isPredicted ? 0.7 : 1.0)
            } else if let badge = pawBadge {
                Image(uiImage: badge)
                    .resizable()
                    .scaledToFit()
                    .frame(width: MapConstants.petMarkerIconSize, height: MapConstants.petMarkerIconSize)
                    .clipShape(Circle())
                    .opacity(isPredicted ? 0.7 : 1.0)
            } else {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: IconSize.tabBar, weight: .bold))
                    .foregroundStyle(.white.opacity(isPredicted ? 0.7 : 1.0))
            }
        }
        .animation(Animations.quick, value: sequence) // Liquid bounce on new fixes
    }

    private var pawBadge: UIImage? {
        UIImage(named: "AppIcon") ?? UIImage(named: "AppIcon60x60@2x")
    }

    private var petAvatar: UIImage? {
        guard let data = petProfileStore.profile.avatarPNGData else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Predicted Marker

/// Marker view for predicted pet location with uncertainty indicator.
struct PredictedMarkerView: View {
    let prediction: PredictedLocation

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Semi-transparent background to indicate prediction
                Circle()
                    .fill(.orange.gradient.opacity(0.6))
                    .frame(width: MapConstants.predictedMarkerSize, height: MapConstants.predictedMarkerSize)
                    .shadow(color: .orange.opacity(0.3), radius: 6, x: 0, y: 3)

                // Question mark icon to indicate uncertainty
                Image(systemName: "questionmark")
                    .font(.system(size: IconSize.button, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Time elapsed label
            Text(prediction.timeAgoDescription)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: Capsule())
        }
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
                .frame(width: MapConstants.ownerMarkerSize, height: MapConstants.ownerMarkerSize)
                .shadow(color: .green.opacity(0.4), radius: 8, x: 0, y: 4)

            // Person icon
            Image(systemName: "person.fill")
                .font(.system(size: IconSize.md, weight: .bold))
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
