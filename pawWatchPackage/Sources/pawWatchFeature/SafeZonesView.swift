//
//  SafeZonesView.swift
//  pawWatch
//
//  Purpose: User interface for managing safe zones and viewing geofence alerts.
//           Allows adding, editing, and deleting safe zones with map visualization.
//
//  Created: 2025-02-09
//  Swift: 6.2
//  Platform: iOS 26.1+
//

#if os(iOS)
import SwiftUI
import MapKit
import CoreLocation
import UIKit

/// View for managing safe zones and monitoring geofence events.
public struct SafeZonesView: View {

    // MARK: - Dependencies

    @Environment(PetLocationManager.self) private var locationManager

    // MARK: - State

    @State private var safeZones: [SafeZone] = []
    @State private var recentEvents: [SafeZoneEvent] = []
    @State private var showingAddZone = false
    @State private var editingZone: SafeZone?
    @State private var isLoading = false
    @State private var zoneViolations: Set<UUID> = []
    @State private var showingClearConfirmation = false

    // MARK: - Body

    public var body: some View {
        List {
            // Urgency Alert Banner (P1-07)
            if !zoneViolations.isEmpty {
                Section {
                    ForEach(Array(zoneViolations), id: \.self) { zoneId in
                        if let zone = safeZones.first(where: { $0.id == zoneId }),
                           let exitEvent = recentEvents.first(where: { $0.zoneId == zoneId && $0.type == .exited }) {
                            UrgencyAlertBanner(zone: zone, event: exitEvent)
                        }
                    }
                }
            }

            // Safe Zones Section
            Section {
                if safeZones.isEmpty {
                    ContentUnavailableView {
                        Label("No Safe Zones", systemImage: "shield.slash")
                    } description: {
                        Text("Add safe zones to get alerts when your pet leaves designated areas.")
                    } actions: {
                        Button("Add Safe Zone") {
                            showingAddZone = true
                        }
                        .glassButtonStyle()
                    }
                } else {
                    ForEach(safeZones) { zone in
                        SafeZoneRow(
                            zone: zone,
                            isViolated: zoneViolations.contains(zone.id),
                            lastViolation: recentEvents.first(where: { $0.zoneId == zone.id && $0.type == .exited }),
                            onEdit: {
                                editingZone = zone
                            },
                            onToggle: {
                                toggleZone(zone)
                            },
                            onDelete: {
                                deleteZone(zone)
                            },
                            onDuplicate: {
                                duplicateZone(zone)
                            }
                        )
                    }
                }
            } header: {
                Text("Safe Zones")
            } footer: {
                Text("Define circular areas where your pet is expected to stay. You'll receive alerts when they exit these zones.")
            }

            // Recent Events Section (P3-05)
            if !recentEvents.isEmpty {
                Section {
                    ForEach(recentEvents.prefix(10)) { event in
                        SafeZoneEventRow(event: event, zone: safeZones.first(where: { $0.id == event.zoneId }))
                    }
                } header: {
                    HStack {
                        Text("Recent Events")
                        Spacer()
                        Button("Clear All") {
                            showingClearConfirmation = true
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("Safe Zones")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddZone = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddZone) {
            SafeZoneEditorView(
                locationManager: locationManager,
                onSave: { zone in
                    addZone(zone)
                }
            )
        }
        .sheet(item: $editingZone) { zone in
            SafeZoneEditorView(
                locationManager: locationManager,
                existingZone: zone,
                onSave: { updatedZone in
                    updateZone(updatedZone)
                }
            )
        }
        .confirmationDialog(
            "Clear All Events",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Events", role: .destructive) {
                clearAllEvents()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will clear all recent event history. This action cannot be undone.")
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    // MARK: - Actions

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        safeZones = await locationManager.geofenceMonitor.getAllSafeZones()
        recentEvents = await locationManager.geofenceMonitor.getRecentEvents(limit: 10)

        // Calculate zone violations (P1-07)
        updateViolations()
    }

    private func updateViolations() {
        guard let currentLocation = locationManager.latestLocation else {
            zoneViolations.removeAll()
            return
        }

        var violations = Set<UUID>()
        for zone in safeZones where zone.isEnabled {
            // Pet is outside the zone if distance > radius
            if !zone.contains(currentLocation) {
                violations.insert(zone.id)
            }
        }

        zoneViolations = violations
    }

    private func clearAllEvents() {
        Task {
            await locationManager.geofenceMonitor.clearEvents()
            await loadData()
        }
    }

    private func addZone(_ zone: SafeZone) {
        Task {
            await locationManager.geofenceMonitor.addSafeZone(zone)
            await loadData()
        }
    }

    private func updateZone(_ zone: SafeZone) {
        Task {
            await locationManager.geofenceMonitor.updateSafeZone(zone)
            await loadData()
        }
    }

    private func deleteZone(_ zone: SafeZone) {
        Task {
            await locationManager.geofenceMonitor.deleteSafeZone(id: zone.id)
            await loadData()
        }
    }

    private func toggleZone(_ zone: SafeZone) {
        Task {
            await locationManager.geofenceMonitor.setSafeZoneEnabled(zone.id, enabled: !zone.isEnabled)
            await loadData()
        }
    }

    private func duplicateZone(_ zone: SafeZone) {
        let duplicatedZone = SafeZone(
            id: UUID(),
            name: "\(zone.name) (Copy)",
            coordinate: zone.coordinate,
            radiusMeters: zone.radiusMeters,
            isEnabled: zone.isEnabled,
            createdAt: Date(),
            modifiedAt: Date()
        )
        Task {
            await locationManager.geofenceMonitor.addSafeZone(duplicatedZone)
            await loadData()
        }
    }
}

// MARK: - Urgency Alert Banner (P1-07)

struct UrgencyAlertBanner: View {
    let zone: SafeZone
    let event: SafeZoneEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .symbolEffect(.pulse)

            VStack(alignment: .leading, spacing: 4) {
                Text("Pet outside \(zone.name)!")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Exited \(event.timestamp, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.red.gradient)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}

// MARK: - Safe Zone Row

struct SafeZoneRow: View {
    let zone: SafeZone
    let isViolated: Bool
    let lastViolation: SafeZoneEvent?
    let onEdit: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void

    @State private var showingDeleteConfirmation = false

    private var statusColor: Color {
        if !zone.isEnabled {
            return .gray
        }
        return isViolated ? .red : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(zone.name)
                        .font(.headline)

                    HStack(spacing: 12) {
                        Label("\(Int(zone.radiusMeters))m", systemImage: "circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label(
                            zone.isEnabled ? (isViolated ? "Outside" : "Inside") : "Disabled",
                            systemImage: zone.isEnabled ? (isViolated ? "exclamationmark.triangle.fill" : "checkmark.circle.fill") : "circle"
                        )
                        .font(.caption)
                        .foregroundStyle(statusColor)
                    }

                    // Last violation timestamp (P1-07)
                    if let lastViolation = lastViolation {
                        Text("Last exit: \(lastViolation.timestamp, style: .relative) ago")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { zone.isEnabled },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                // P6-06: Haptic feedback on destructive action
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                // P6-06: Haptic feedback on duplicate
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onDuplicate()
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                // P6-06: Haptic feedback on destructive action
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Delete Safe Zone",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete \(zone.name)", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete \(zone.name). This action cannot be undone.")
        }
    }
}

// MARK: - Event Row

struct SafeZoneEventRow: View {
    let event: SafeZoneEvent
    let zone: SafeZone?

    var body: some View {
        HStack {
            Image(systemName: event.type == .exited ? "arrow.up.right.circle.fill" : "arrow.down.left.circle.fill")
                .foregroundStyle(event.type == .exited ? .red : .green)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(zone?.name ?? "Unknown Zone")
                    .font(.headline)

                HStack {
                    Text(event.type == .exited ? "Exited" : "Entered")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(event.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Safe Zone Editor

struct SafeZoneEditorView: View {
    let locationManager: PetLocationManager
    let existingZone: SafeZone?
    let onSave: (SafeZone) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var radiusMeters: Double
    @State private var centerCoordinate: LocationFix.Coordinate
    @State private var cameraPosition: MapCameraPosition
    @State private var allZones: [SafeZone] = []

    init(
        locationManager: PetLocationManager,
        existingZone: SafeZone? = nil,
        onSave: @escaping (SafeZone) -> Void
    ) {
        self.locationManager = locationManager
        self.existingZone = existingZone
        self.onSave = onSave

        if let zone = existingZone {
            _name = State(initialValue: zone.name)
            _radiusMeters = State(initialValue: zone.radiusMeters)
            _centerCoordinate = State(initialValue: zone.coordinate)
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: zone.coordinate.latitude,
                    longitude: zone.coordinate.longitude
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))
        } else {
            _name = State(initialValue: "")
            _radiusMeters = State(initialValue: SafeZone.defaultRadius)
            // Use pet's current location or a default
            let defaultCoord = LocationFix.Coordinate(latitude: 37.7749, longitude: -122.4194)
            _centerCoordinate = State(initialValue: defaultCoord)
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: defaultCoord.latitude, longitude: defaultCoord.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Zone Name", text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Name")
                } footer: {
                    Text("Give this safe zone a memorable name like 'Home' or 'Dog Park'.")
                }

                Section {
                    HStack {
                        Text("Radius")
                        Spacer()
                        Text("\(Int(radiusMeters))m")
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: $radiusMeters,
                        in: SafeZone.minimumRadius...SafeZone.maximumRadius,
                        step: 10
                    )

                    // Validation messages (P2-05)
                    ValidationMessages(
                        radiusMeters: radiusMeters,
                        centerCoordinate: centerCoordinate,
                        existingZoneId: existingZone?.id,
                        allZones: allZones
                    )
                } header: {
                    Text("Size")
                } footer: {
                    Text("Recommended: 50-200m for home, 200-500m for parks")
                }

                Section {
                    Button("Use Pet's Current Location") {
                        if let petLoc = locationManager.latestLocation {
                            centerCoordinate = petLoc.coordinate
                            updateCamera()
                        }
                    }
                    .disabled(locationManager.latestLocation == nil)

                    Button("Use My Location") {
                        if let ownerLoc = locationManager.ownerLocation {
                            centerCoordinate = LocationFix.Coordinate(
                                latitude: ownerLoc.coordinate.latitude,
                                longitude: ownerLoc.coordinate.longitude
                            )
                            updateCamera()
                        }
                    }
                    .disabled(locationManager.ownerLocation == nil)
                } header: {
                    Text("Location")
                }

                Section {
                    Map(position: $cameraPosition) {
                        // Center marker
                        Annotation("Zone Center", coordinate: CLLocationCoordinate2D(
                            latitude: centerCoordinate.latitude,
                            longitude: centerCoordinate.longitude
                        )) {
                            ZStack {
                                Circle()
                                    .fill(.blue.opacity(0.3))
                                    .frame(width: 20, height: 20)

                                Circle()
                                    .fill(.blue)
                                    .frame(width: 10, height: 10)
                            }
                        }

                        // Radius visualization
                        MapCircle(
                            center: CLLocationCoordinate2D(
                                latitude: centerCoordinate.latitude,
                                longitude: centerCoordinate.longitude
                            ),
                            radius: radiusMeters
                        )
                        .foregroundStyle(.blue.opacity(0.2))
                        .stroke(.blue, lineWidth: 2)
                    }
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle(existingZone == nil ? "Add Safe Zone" : "Edit Safe Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveZone()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task {
                // Initialize with pet's location if adding new zone
                if existingZone == nil, let petLoc = locationManager.latestLocation {
                    centerCoordinate = petLoc.coordinate
                    updateCamera()
                }

                // Load all zones for validation (P2-05)
                allZones = await locationManager.geofenceMonitor.getAllSafeZones()
            }
        }
    }

    private func updateCamera() {
        cameraPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: centerCoordinate.latitude,
                longitude: centerCoordinate.longitude
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    private func saveZone() {
        let zone = SafeZone(
            id: existingZone?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            coordinate: centerCoordinate,
            radiusMeters: radiusMeters,
            isEnabled: existingZone?.isEnabled ?? true,
            createdAt: existingZone?.createdAt ?? Date(),
            modifiedAt: Date()
        )

        // P6-06: Success haptic on save
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSave(zone)
        dismiss()
    }
}

// MARK: - Validation Messages (P2-05)

struct ValidationMessages: View {
    let radiusMeters: Double
    let centerCoordinate: LocationFix.Coordinate
    let existingZoneId: UUID?
    let allZones: [SafeZone]

    private var overlappingZone: SafeZone? {
        // Create a temporary zone to check against
        let currentZone = SafeZone(
            id: existingZoneId ?? UUID(),
            name: "temp",
            coordinate: centerCoordinate,
            radiusMeters: radiusMeters
        )

        for zone in allZones {
            // Skip comparing with itself
            if zone.id == existingZoneId {
                continue
            }

            // Skip disabled zones
            if !zone.isEnabled {
                continue
            }

            // Calculate distance between zone centers
            let centerLocation = CLLocation(
                latitude: centerCoordinate.latitude,
                longitude: centerCoordinate.longitude
            )
            let otherCenterLocation = CLLocation(
                latitude: zone.coordinate.latitude,
                longitude: zone.coordinate.longitude
            )
            let centerDistance = centerLocation.distance(from: otherCenterLocation)

            // Check if zones overlap: distance between centers < sum of radii
            if centerDistance < (radiusMeters + zone.radiusMeters) {
                return zone
            }
        }

        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Small zone warning
            if radiusMeters < 30 {
                ValidationMessage(
                    icon: "exclamationmark.triangle.fill",
                    text: "Very small zone — may cause frequent false alerts",
                    color: .orange
                )
            }

            // Large zone warning
            if radiusMeters > 1000 {
                ValidationMessage(
                    icon: "battery.25",
                    text: "Large zone — increased battery usage for monitoring",
                    color: .orange
                )
            }

            // Overlap warning
            if let overlapping = overlappingZone {
                ValidationMessage(
                    icon: "exclamationmark.circle.fill",
                    text: "This zone overlaps with '\(overlapping.name)'",
                    color: .yellow
                )
            }
        }
    }
}

struct ValidationMessage: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
#endif
