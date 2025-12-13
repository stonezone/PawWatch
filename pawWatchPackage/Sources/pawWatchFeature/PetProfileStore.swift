import Foundation
import Observation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

public struct PetProfile: Codable, Equatable, Sendable {
    public var name: String
    public var type: String
    public var avatarPNGData: Data?

    public init(name: String = "", type: String = "", avatarPNGData: Data? = nil) {
        self.name = name
        self.type = type
        self.avatarPNGData = avatarPNGData
    }
}

@MainActor
@Observable
public final class PetProfileStore {
    public static let shared = PetProfileStore()

    private static let storageKey = "PetProfileStore.profile"
    private static let syncDebounceMilliseconds = 650

    public var profile: PetProfile {
        didSet {
            persist(profile)
            scheduleSyncToWatchIfNeeded()
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isApplyingRemoteUpdate = false
    @ObservationIgnored private var syncTask: Task<Void, Never>?

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? (UserDefaults(suiteName: PerformanceSnapshotStore.suiteName) ?? .standard)
        if let data = self.defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(PetProfile.self, from: data) {
            self.profile = decoded
        } else {
            self.profile = PetProfile()
        }
    }

    public func applyRemoteProfileData(_ data: Data) -> Bool {
        guard let decoded = try? JSONDecoder().decode(PetProfile.self, from: data) else {
            return false
        }
        isApplyingRemoteUpdate = true
        profile = decoded
        isApplyingRemoteUpdate = false
        return true
    }

    public func clearAvatar() {
        profile.avatarPNGData = nil
    }

    private func persist(_ profile: PetProfile) {
        guard let encoded = try? JSONEncoder().encode(profile) else { return }
        defaults.set(encoded, forKey: Self.storageKey)
    }

    private func scheduleSyncToWatchIfNeeded() {
#if os(iOS)
        guard !isApplyingRemoteUpdate else { return }

        syncTask?.cancel()
        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Self.syncDebounceMilliseconds))
            guard let self, !Task.isCancelled else { return }
            self.syncToWatch()
        }
#endif
    }

#if os(iOS)
    private func syncToWatch() {
#if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard let encoded = try? JSONEncoder().encode(profile) else { return }

        let message: [String: Any] = [
            ConnectivityConstants.action: ConnectivityConstants.setPetProfile,
            ConnectivityConstants.petProfile: encoded,
            ConnectivityConstants.timestamp: Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            _ = session.transferUserInfo(message)
        }
#endif
    }
#endif
}
