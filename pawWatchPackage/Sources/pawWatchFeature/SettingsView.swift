#if os(iOS)
import SwiftUI
import PhotosUI
import UIKit

/// Settings view for configuring app preferences, pet profile, and tracking options
@MainActor
struct SettingsView: View {
    @Environment(PetLocationManager.self) private var locationManager
    @Environment(PetProfileStore.self) private var petProfileStore
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("trackingMode") private var trackingModeRaw = TrackingMode.auto.rawValue
    @Binding private var useMetricUnits: Bool
    @State private var showDeveloperSheet = false
    @State private var showAdvanced = false
    @State private var selectedPetPhotoItem: PhotosPickerItem?
    @State private var petPhotoLoadTask: Task<Void, Never>?
    @State private var petPhotoError: String?
    /// Debounce task to prevent rapid mode change race conditions
    @State private var modeChangeTask: Task<Void, Never>?

    init(useMetricUnits: Binding<Bool>) {
        self._useMetricUnits = useMetricUnits
    }

    private var emergencyCadenceBinding: Binding<EmergencyCadencePreset> {
        Binding(
            get: { locationManager.emergencyCadencePreset },
            set: { locationManager.setEmergencyCadencePreset($0) }
        )
    }

    var body: some View {
        GlassScroll(spacing: Spacing.Component.listItemSpacing + Spacing.xs, maxWidth: 340, enableParallax: false) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Settings")
                    .font(Typography.pageTitle)
                Text("Customize your experience")
                    .font(Typography.pageSubtitle)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, Spacing.xxxl)

            // MARK: - Connection Status Card (Visual)
            ConnectionStatusCard()

            // MARK: - Quick Settings
            settingsCard(title: "Quick Settings") {
                Toggle("Notifications", isOn: $notificationsEnabled)
                Toggle("Metric Units", isOn: $useMetricUnits)
            }

            // MARK: - Pet
            settingsCard(title: "Pet") {
                petProfileCardContent
            }

            // MARK: - Tracking
            settingsCard(title: "Tracking") {
                let selectedMode = TrackingMode(rawValue: trackingModeRaw) ?? .auto
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mode")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Picker("Mode", selection: Binding(
                        get: { TrackingMode(rawValue: trackingModeRaw) ?? .auto },
                        set: { trackingModeRaw = $0.rawValue }
                    )) {
                        ForEach(TrackingMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: trackingModeRaw) { _, newRaw in
                        // Debounce mode changes to prevent race conditions and crashes
                        modeChangeTask?.cancel()
                        modeChangeTask = Task { @MainActor in
                            // 300ms debounce delay
                            try? await Task.sleep(for: .milliseconds(300))
                            guard !Task.isCancelled else { return }

                            if let mode = TrackingMode(rawValue: newRaw) {
                                locationManager.setTrackingMode(mode)
                            }
                        }
                    }
                }

                if selectedMode == .emergency {
                    Divider().opacity(0.3)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Emergency cadence")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        Picker("Emergency cadence", selection: emergencyCadenceBinding) {
                            ForEach(EmergencyCadencePreset.allCases) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(locationManager.emergencyCadencePreset.footnote)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().opacity(0.3)

                Stepper(
                    value: Binding(
                        get: { locationManager.trailHistoryLimit },
                        set: { locationManager.updateTrailHistoryLimit(to: $0) }
                    ),
                    in: PetLocationManager.trailHistoryLimitRange,
                    step: PetLocationManager.trailHistoryStep
                ) {
                    HStack {
                        Text("Trail History")
                        Spacer()
                        Text("\(locationManager.trailHistoryLimit)")
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    locationManager.requestUpdate(force: true)
                } label: {
                    Label("Request Fresh Location", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!locationManager.isWatchReachable)
            }

            // MARK: - Permissions (Simplified)
            if locationManager.needsLocationPermissionAction || locationManager.needsHealthPermissionAction {
                settingsCard(title: "Permissions Needed") {
                    if locationManager.needsLocationPermissionAction {
                        HStack {
                            Image(systemName: "location.slash.fill")
                                .foregroundStyle(.orange)
                            Text("Location access required")
                                .font(.callout)
                            Spacer()
                            Button("Fix") { locationManager.openLocationSettings() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }

                    if locationManager.needsHealthPermissionAction {
                        HStack {
                            Image(systemName: "heart.slash.fill")
                                .foregroundStyle(.orange)
                            Text("HealthKit access needed")
                                .font(.callout)
                            Spacer()
                            Button("Fix") { locationManager.requestHealthAuthorization() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(!locationManager.canRequestHealthAuthorization)
                        }
                    }
                }
            }

            // MARK: - Error Alert
            if let error = locationManager.errorMessage {
                GlassCard(cornerRadius: 16, padding: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                }
            }

            // MARK: - Advanced Section (Collapsible)
            advancedSection

            Spacer(minLength: 32)
        }
        .sheet(isPresented: $showDeveloperSheet) {
            DeveloperSettingsSheet()
                .environment(locationManager)
        }
    }

    // MARK: - Connection Status Card
    @ViewBuilder
    private func ConnectionStatusCard() -> some View {
        if #available(iOS 26, *) {
            modernConnectionStatusCard
        } else {
            legacyConnectionStatusCard
        }
    }

    @available(iOS 26, *)
    private var modernConnectionStatusCard: some View {
        HStack(spacing: 16) {
            // Watch icon with glass circle and pulse effect
            ZStack {
                Circle()
                    .fill(connectionColor.opacity(0.2))
                    .frame(width: 56, height: 56)

                Image(systemName: "applewatch")
                    .font(.title)
                    .foregroundStyle(connectionColor.gradient)
                    .symbolEffect(.pulse.byLayer, options: locationManager.isWatchReachable ? .repeating : .default, value: locationManager.isWatchReachable)
            }
            .glassEffect(.regular, in: .circle)

            VStack(alignment: .leading, spacing: 4) {
                Text(connectionTitle)
                    .font(.headline)

                Text(connectionSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let battery = locationManager.watchBatteryFraction {
                    HStack(spacing: 4) {
                        Image(systemName: SharedUtilities.batteryIcon(for: battery))
                            .font(.caption2)
                            .foregroundStyle(SharedUtilities.batteryColor(for: battery))
                        Text(String(format: "%.0f%%", battery * 100))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Status indicator with glow
            Circle()
                .fill(connectionColor.gradient)
                .frame(width: 14, height: 14)
                .shadow(color: connectionColor.opacity(0.6), radius: 6)
        }
        .padding(20)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }

    private var legacyConnectionStatusCard: some View {
        GlassCard(cornerRadius: 24, padding: 20) {
            HStack(spacing: 16) {
                // Watch icon with status
                ZStack {
                    Circle()
                        .fill(connectionColor.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: "applewatch")
                        .font(.title)
                        .foregroundStyle(connectionColor.gradient)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(connectionTitle)
                        .font(.headline)

                    Text(connectionSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let battery = locationManager.watchBatteryFraction {
                        HStack(spacing: 4) {
                            Image(systemName: SharedUtilities.batteryIcon(for: battery))
                                .font(.caption2)
                                .foregroundStyle(SharedUtilities.batteryColor(for: battery))
                            Text(String(format: "%.0f%%", battery * 100))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Status indicator
                Circle()
                    .fill(connectionColor.gradient)
                    .frame(width: 12, height: 12)
                    .shadow(color: connectionColor.opacity(0.5), radius: 4)
            }
        }
    }

    private var connectionColor: Color {
        if !locationManager.isWatchConnected { return .red }
        if !locationManager.isWatchReachable { return .orange }
        return .green
    }

    private var connectionTitle: String {
        if !locationManager.isWatchConnected { return "Watch Disconnected" }
        if !locationManager.isWatchReachable { return "Watch Paired" }
        return "Watch Connected"
    }

    private var connectionSubtitle: String {
        if !locationManager.isWatchConnected { return "Open Watch app to connect" }
        if !locationManager.isWatchReachable { return "Waiting for active session" }
        if locationManager.isWatchLocked { return "Tracker locked on watch" }
        return "Tracking active"
    }

    // MARK: - Advanced Section
    @ViewBuilder
    private var advancedSection: some View {
        if #available(iOS 26, *) {
            modernAdvancedSection
        } else {
            legacyAdvancedSection
        }
    }

    @available(iOS 26, *)
    private var modernAdvancedSection: some View {
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(spacing: 14) {
                sessionStatsSection
                healthKitSection
                developerSection
                aboutSection
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .foregroundStyle(.secondary)
                    .symbolEffect(.rotate, value: showAdvanced)
                Text("Advanced")
                    .font(.headline)
            }
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
    }

    private var legacyAdvancedSection: some View {
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(spacing: 14) {
                sessionStatsSection
                healthKitSection
                developerSection
                aboutSection
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .foregroundStyle(.secondary)
                Text("Advanced")
                    .font(.headline)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Session Stats Section
    @ViewBuilder
    private var sessionStatsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Stats")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            let summary = locationManager.sessionSummary
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                StatCell(title: "Fixes", value: "\(summary.fixCount)")
                StatCell(title: "Avg Interval", value: formatSeconds(summary.averageIntervalSec))
                StatCell(title: "Median Acc", value: formatMeters(summary.medianAccuracy))
                StatCell(title: "Duration", value: formatDuration(summary.durationSec))
            }

            HStack {
                if let exportURL = locationManager.sessionShareURL() {
                    ShareLink(item: exportURL) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                Button("Reset", role: .destructive) {
                    locationManager.resetSessionStats()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - HealthKit Section
    @ViewBuilder
    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HealthKit")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "figure.run")
                    .foregroundStyle(.pink)
                Text("Workout: \(locationManager.workoutPermissionDescription)")
                    .font(.caption)
            }

            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("Heart Rate: \(locationManager.heartPermissionDescription)")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Developer Section
    @ViewBuilder
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Developer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack {
                Text("Extended Runtime")
                    .font(.caption)
                Spacer()
                Text(locationManager.runtimeOptimizationsEnabled ? "Enabled" : "Disabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Open Developer Settings") {
                showDeveloperSheet = true
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - About Section
    @ViewBuilder
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack {
                Text("Version")
                    .font(.caption)
                Spacer()
                Text(appVersion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Stat Cell
private struct StatCell: View {
    let title: String
    let value: String

    var body: some View {
        if #available(iOS 26, *) {
            modernStatCell
        } else {
            legacyStatCell
        }
    }

    @available(iOS 26, *)
    private var modernStatCell: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.weight(.semibold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
    }

    private var legacyStatCell: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.weight(.semibold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - SettingsView Helpers
private extension SettingsView {

    @ViewBuilder
    private var petProfileCardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 56, height: 56)

                    if let avatarImage = petAvatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "pawprint.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    TextField(
                        "Pet name",
                        text: Binding(
                            get: { petProfileStore.profile.name },
                            set: { petProfileStore.profile.name = $0 }
                        )
                    )
                    .textInputAutocapitalization(.words)

                    TextField(
                        "Pet type (Dog, Cat, etc.)",
                        text: Binding(
                            get: { petProfileStore.profile.type },
                            set: { petProfileStore.profile.type = $0 }
                        )
                    )
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(.secondary)
                }
            }

            PhotosPicker(selection: $selectedPetPhotoItem, matching: .images) {
                Label("Choose pet photo", systemImage: "photo.on.rectangle.angled")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.bordered)
            .onChange(of: selectedPetPhotoItem) { _, newItem in
                petPhotoLoadTask?.cancel()
                petPhotoError = nil

                guard let newItem else { return }
                petPhotoLoadTask = Task { @MainActor in
                    do {
                        guard let imageData = try await newItem.loadTransferable(type: Data.self) else {
                            petPhotoError = "Unable to load photo."
                            return
                        }
                        guard let image = UIImage(data: imageData) else {
                            petPhotoError = "Unsupported image format."
                            return
                        }
                        guard let avatarData = renderAvatarPNG(from: image, side: 128) else {
                            petPhotoError = "Unable to process photo."
                            return
                        }
                        petProfileStore.profile.avatarPNGData = avatarData
                    } catch {
                        petPhotoError = "Photo error: \(error.localizedDescription)"
                    }
                }
            }

            Button {
                locationManager.pingWatch()
            } label: {
                Label("Ping watch", systemImage: "bell")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.bordered)
            .disabled(!locationManager.isWatchReachable)

            if petProfileStore.profile.avatarPNGData != nil {
                Button(role: .destructive) {
                    petProfileStore.clearAvatar()
                } label: {
                    Label("Remove photo", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
            }

            if let petPhotoError {
                Text(petPhotoError)
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else {
                Text("Pet profile syncs to your watch when it's reachable, otherwise it queues for delivery.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var petAvatarImage: UIImage? {
        guard let data = petProfileStore.profile.avatarPNGData else { return nil }
        return UIImage(data: data)
    }

    private func renderAvatarPNG(from image: UIImage, side: CGFloat) -> Data? {
        let targetSize = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            let scale = max(side / max(image.size.width, 1), side / max(image.size.height, 1))
            let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(x: (side - scaledSize.width) / 2, y: (side - scaledSize.height) / 2)
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
        return rendered.pngData()
    }

    @ViewBuilder
    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26, *) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
        } else {
            GlassCard(cornerRadius: 20, padding: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    content()
                }
            }
        }
    }

    private func SettingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private struct DeveloperSettingsSheet: View {
        @Environment(PetLocationManager.self) private var locationManager
        @Environment(\.dismiss) private var dismiss

        private var runtimeBinding: Binding<Bool> {
            Binding(
                get: { locationManager.runtimeOptimizationsEnabled },
                set: { locationManager.setRuntimeOptimizationsEnabled($0) }
            )
        }

        private var idleCadenceBinding: Binding<IdleCadencePreset> {
            Binding(
                get: { locationManager.idleCadencePreset },
                set: { locationManager.setIdleCadencePreset($0) }
            )
        }

        var body: some View {
            NavigationStack {
                List {
                    Section("Extended Runtime Guard") {
                        Toggle("Keep workout alive longer", isOn: runtimeBinding)
                            .disabled(!locationManager.watchSupportsExtendedRuntime && !locationManager.runtimeOptimizationsEnabled)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: locationManager.watchSupportsExtendedRuntime ? "bolt.badge.clock" : "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(locationManager.watchSupportsExtendedRuntime ? .green : .orange)
                            Text(capabilityCopy)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text("Enabling requests WKExtendedRuntimeSession on the watch and keeps adaptive GPS throttling active even while the display sleeps. Disable to reproduce baseline battery drain or to test OS energy heuristics.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }

                    Section("Idle Cadence") {
                        Picker("Stationary cadence", selection: idleCadenceBinding) {
                            ForEach(IdleCadencePreset.allCases) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                        .pickerStyle(.inline)

                        Text(idleCadenceBinding.wrappedValue.footnote)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if let heartbeat = locationManager.watchIdleHeartbeatInterval,
                           let fullFix = locationManager.watchIdleFullFixInterval {
                            Text("Watch applied: heartbeat \(formatSeconds(heartbeat)), fix \(formatSeconds(fullFix)).")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Section("Debug") {
                        Button("Close") { dismiss() }
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .navigationTitle("Developer")
                .navigationBarTitleDisplayMode(.inline)
            }
        }

        private func formatSeconds(_ value: TimeInterval) -> String {
            String(format: "%.0fs", value)
        }

        private var capabilityCopy: String {
            if locationManager.watchSupportsExtendedRuntime {
                return "Watch hardware reports extended runtime support."
            } else {
                return "Awaiting confirmation from the watch. Open the watch app to refresh."
            }
        }
    }

    private func formatSeconds(_ value: Double) -> String {
        guard value > 0 else { return "-" }
        return String(format: "%.1f s", value)
    }

    private func formatMeters(_ value: Double) -> String {
        guard value > 0 else { return "-" }
        return String(format: "%.1f m", value)
    }

    private func formatDuration(_ value: Double) -> String {
        guard value > 0 else { return "-" }
        let minutes = Int(value / 60)
        let seconds = Int(value.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private var buildDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }
}

#endif
