#if canImport(ActivityKit)
import CryptoKit
import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct PushTokenUploadRequest: Encodable {
    struct ActivityToken: Encodable {
        let activityId: String
        let pushToken: String
        let updatedAt: String
    }

    struct DeviceContext: Encodable {
        let model: String
        let osVersion: String
        let appVersion: String
        let appBuild: String
        let environment: String
        let platform: String
    }

    let deviceToken: String
    let activityTokens: [ActivityToken]
    let device: DeviceContext
}

struct PushTokenUploadContext {
    let deviceModel: String
    let osVersion: String
    let appVersion: String
    let appBuild: String

    static func current(bundle: Bundle = .main) -> PushTokenUploadContext {
#if canImport(UIKit)
        let device = UIDevice.current
        return PushTokenUploadContext(
            deviceModel: device.modelIdentifier,
            osVersion: device.systemVersion,
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            appBuild: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        )
#else
        return PushTokenUploadContext(
            deviceModel: "unknown",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            appBuild: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        )
#endif
    }
}

struct PushTokenUploadConfiguration {
    let endpoint: URL
    let apiKey: String?
    let signatureKey: Data?
    let environment: String
    let uploadsEnabled: Bool

    static func load(bundle: Bundle = .main, processInfo: ProcessInfo = .processInfo) -> PushTokenUploadConfiguration {
        let env = processInfo.environment
        let endpointString = Self.value(for: "PAWWATCH_PUSH_ENDPOINT", bundle: bundle, environment: env)
            ?? "https://api.pawwatch.app/v1/push/register"
        let apiKey = Self.value(for: "PAWWATCH_PUSH_API_KEY", bundle: bundle, environment: env)
        let signatureString = Self.value(for: "PAWWATCH_PUSH_SIGNATURE_KEY", bundle: bundle, environment: env)
        let signatureKey = signatureString.flatMap { Data(base64Encoded: $0) ?? $0.data(using: .utf8) }
        let environmentValue = Self.value(for: "PAWWATCH_PUSH_ENVIRONMENT", bundle: bundle, environment: env)
            ?? Self.defaultEnvironment
        let uploadsEnabled = Self.boolValue(
            for: "PAWWATCH_PUSH_UPLOADS_ENABLED",
            bundle: bundle,
            environment: env,
            defaultValue: false
        )

        guard let endpointURL = URL(string: endpointString) else {
            return PushTokenUploadConfiguration(
                endpoint: URL(string: "https://api.pawwatch.app/v1/push/register")!,
                apiKey: apiKey,
                signatureKey: signatureKey,
                environment: environmentValue,
                uploadsEnabled: uploadsEnabled
            )
        }

        return PushTokenUploadConfiguration(
            endpoint: endpointURL,
            apiKey: apiKey,
            signatureKey: signatureKey,
            environment: environmentValue,
            uploadsEnabled: uploadsEnabled
        )
    }

    private static func value(for key: String, bundle: Bundle, environment: [String: String]) -> String? {
        if let value = sanitized(environment[key] ?? environment[key.uppercased()]) {
            return value
        }
        if let infoValue = sanitized(bundle.object(forInfoDictionaryKey: key) as? String) {
            return infoValue
        }
        return nil
    }

    private static func sanitized(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        if trimmed == "__UNSET__" { return nil }
        if trimmed.hasPrefix("$(") && trimmed.hasSuffix(")") { return nil }
        return trimmed
    }

    private static func boolValue(
        for key: String,
        bundle: Bundle,
        environment: [String: String],
        defaultValue: Bool
    ) -> Bool {
        if let raw = sanitized(environment[key] ?? environment[key.uppercased()]), let parsed = parseBool(raw) {
            return parsed
        }
        if let infoValue = sanitized(bundle.object(forInfoDictionaryKey: key) as? String), let parsed = parseBool(infoValue) {
            return parsed
        }
        return defaultValue
    }

    private static func parseBool(_ raw: String) -> Bool? {
        switch raw.lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return nil
        }
    }

#if DEBUG
    private static let defaultEnvironment = "debug"
#else
    private static let defaultEnvironment = "release"
#endif
}

struct PushTokenUploader {
    enum UploadError: LocalizedError {
        case encodingFailed
        case invalidResponse
        case serverRejected(status: Int, body: String?)
        case requestFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .encodingFailed:
                return "Failed to encode push token payload"
            case .invalidResponse:
                return "Push token upload returned an unexpected response"
            case let .serverRejected(status, _):
                return "Server rejected push token upload (status: \(status))"
            case let .requestFailed(underlying):
                return "Push token upload request failed: \(underlying.localizedDescription)"
            }
        }
    }

    private let session: URLSession
    private let configuration: PushTokenUploadConfiguration
    private let context: PushTokenUploadContext

    var isEnabled: Bool { configuration.uploadsEnabled }

    init(
        session: URLSession = .shared,
        configuration: PushTokenUploadConfiguration = .load(),
        context: PushTokenUploadContext = .current()
    ) {
        self.session = session
        self.configuration = configuration
        self.context = context
    }

    func upload(deviceToken: String, activityTokens: [PushTokenUploadRequest.ActivityToken]) async throws {
        guard configuration.uploadsEnabled else { return }
        guard !activityTokens.isEmpty else { return }

        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = configuration.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let payload = PushTokenUploadRequest(
            deviceToken: deviceToken,
            activityTokens: activityTokens,
            device: .init(
                model: context.deviceModel,
                osVersion: context.osVersion,
                appVersion: context.appVersion,
                appBuild: context.appBuild,
                environment: configuration.environment,
                platform: "iOS"
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let body = try? encoder.encode(payload) else {
            throw UploadError.encodingFailed
        }
        request.httpBody = body

        if let signature = signature(for: body) {
            request.setValue(signature, forHTTPHeaderField: "X-Pawwatch-Signature")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw UploadError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let snippet = String(data: data, encoding: .utf8)
                throw UploadError.serverRejected(status: httpResponse.statusCode, body: snippet)
            }
        } catch let error as UploadError {
            throw error
        } catch {
            throw UploadError.requestFailed(underlying: error)
        }
    }

    private func signature(for body: Data) -> String? {
        guard let keyData = configuration.signatureKey else { return nil }
        let symmetricKey = SymmetricKey(data: keyData)
        let mac = HMAC<SHA256>.authenticationCode(for: body, using: symmetricKey)
        return mac.withUnsafeBytes { buffer -> String in
            buffer.map { String(format: "%02hhx", $0) }.joined()
        }
    }
}

#if canImport(UIKit)
private extension UIDevice {
    var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let hardware = withUnsafePointer(to: &systemInfo.machine) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 1) { cPtr in
                String(cString: cPtr)
            }
        }
        return hardware
    }
}
#endif
#endif
