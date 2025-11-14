#if canImport(Foundation)
import Foundation

#if os(iOS)

/// Detects whether the runtime bundle actually contains the Liquid Glass
/// shader/style assets (default.csv, scene@*.styl, etc.). When these assets
/// are missing we fall back to legacy `.ultraThinMaterial` so the system does
/// not spam the console trying to decode placeholder files.
struct LiquidGlassAssets {
    static let shared = LiquidGlassAssets()

    /// `true` only when every required asset is present in either the SPM
    /// resource bundle or the app bundle.
    let isReady: Bool

    /// Names of assets that could not be found (helpful for logging/testing).
    let missingResources: [String]

    private struct Resource: Hashable {
        let name: String
        let ext: String

        var fullName: String { "\(name).\(ext)" }
    }

    private init() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["PAWWATCH_FORCE_GLASS_FALLBACK"] == "1" {
            self.isReady = false
            self.missingResources = []
            return
        }
        #endif

        let required: [Resource] = [
            .init(name: "default", ext: "csv"),
            .init(name: "default@2.6x", ext: "styl"),
            .init(name: "default@3.4x", ext: "styl"),
            .init(name: "default@4x", ext: "styl"),
            .init(name: "scene@2.6x", ext: "styl"),
            .init(name: "scene@3.4x", ext: "styl"),
            .init(name: "scene@4x", ext: "styl"),
        ]

        var bundles: [Bundle] = [Bundle.main]
#if SWIFT_PACKAGE
        bundles.append(.module)
#endif

        let missing = required.compactMap { resource -> String? in
            let found = bundles.contains { bundle in
                bundle.url(forResource: resource.name, withExtension: resource.ext) != nil
            }
            return found ? nil : resource.fullName
        }

        self.isReady = missing.isEmpty
        self.missingResources = missing
    }
}

#endif // os(iOS)
#endif // canImport(Foundation)
