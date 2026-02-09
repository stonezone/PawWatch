#if os(iOS)
import SwiftUI
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
    @State private var showFullScreenPhoto = false

    init(useMetricUnits: Binding<Bool>) {
        self._useMetricUnits = useMetricUnits
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
                PetProfileCard(showFullScreenPhoto: $showFullScreenPhoto)
                    .environment(locationManager)
                    .environment(petProfileStore)
            }

            // MARK: - Tracking
            settingsCard(title: "Tracking") {
                TrackingModeSection(trackingModeRaw: $trackingModeRaw)
                    .environment(locationManager)
            }

            // MARK: - Safe Zones
            settingsCard(title: "Safe Zones") {
                NavigationLink {
                    SafeZonesView()
                        .environment(locationManager)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Manage Safe Zones")
                                .font(.body)
                            Text("Get alerts when your pet leaves designated areas")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - Battery Analytics
            settingsCard(title: "Battery Analytics") {
                NavigationLink {
                    BatteryAnalyticsView()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Battery Impact")
                                .font(.body)
                            Text("See which features consume the most power")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - HealthKit Permissions (promoted from Advanced)
            settingsCard(title: "HealthKit Permissions") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "figure.run")
                            .foregroundStyle(.pink)
                        Text("Workout")
                        Spacer()
                        Text(locationManager.workoutPermissionDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider().opacity(0.3)

                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text("Heart Rate")
                        Spacer()
                        Text(locationManager.heartPermissionDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if locationManager.needsHealthPermissionAction {
                        Button {
                            locationManager.requestHealthAuthorization()
                        } label: {
                            Label("Request HealthKit Access", systemImage: "heart.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .glassButtonStyle()
                        .controlSize(.small)
                        .disabled(!locationManager.canRequestHealthAuthorization)
                    }
                }
            }

            // MARK: - Export Session Data (promoted from Advanced)
            settingsCard(title: "Session Data") {
                VStack(alignment: .leading, spacing: 12) {
                    let summary = locationManager.sessionSummary

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Session")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(summary.fixCount) location fixes")
                                .font(.subheadline.weight(.medium))
                        }
                        Spacer()
                        if let exportURL = locationManager.sessionShareURL() {
                            ShareLink(item: exportURL) {
                                Label("Export", systemImage: "square.and.arrow.up")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    Text("Export GPS data for analysis or backup")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - Distance Alerts
            settingsCard(title: "Distance Alerts") {
                DistanceAlertsSection(useMetricUnits: $useMetricUnits)
                    .environment(locationManager)
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
            AdvancedSettingsSection(showAdvanced: $showAdvanced, showDeveloperSheet: $showDeveloperSheet)
                .environment(locationManager)

            Spacer(minLength: 32)
        }
        .sheet(isPresented: $showDeveloperSheet) {
            DeveloperSettingsSheet()
                .environment(locationManager)
        }
        .fullScreenCover(isPresented: $showFullScreenPhoto) {
            ZStack {
                Color.black.ignoresSafeArea()

                if let data = petProfileStore.profile.avatarPNGData,
                   let avatarImage = UIImage(data: data) {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            showFullScreenPhoto = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.8))
                                .padding()
                        }
                    }
                    Spacer()
                }
            }
        }
    }


}

// MARK: - SettingsView Helpers
private extension SettingsView {

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



}

#endif
