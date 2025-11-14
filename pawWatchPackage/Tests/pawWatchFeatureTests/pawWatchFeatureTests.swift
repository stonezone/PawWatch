import Foundation
import Testing
@testable import pawWatchFeature

@Test func exportedSourcesStayInSyncWithWorkingTree() throws {
    let workspace = try workspaceRootURL()
    let package = workspace.appendingPathComponent("pawWatchPackage")
    let sources = package.appendingPathComponent("Sources/pawWatchFeature")
    let archive = workspace.appendingPathComponent("pawWatchFeatureSources.zip")

    guard FileManager.default.fileExists(atPath: archive.path) else {
        throw ExportValidationError.missingArchive(archive)
    }

    let relativeSwiftFiles = try swiftSourceRelativePaths(at: sources)
    let expectedEntries = Set(relativeSwiftFiles.map { "pawWatchPackage/Sources/pawWatchFeature/\($0)" })
    let archivedEntries = Set(try zipEntries(in: archive).filter { $0.hasSuffix(".swift") && $0.contains("pawWatchPackage/Sources/pawWatchFeature/") })

    #expect(archivedEntries == expectedEntries, "Export archive is missing source files or contains unexpected extras.")

    for relative in relativeSwiftFiles {
        let workingURL = sources.appendingPathComponent(relative)
        let workingText = try String(contentsOf: workingURL, encoding: .utf8)
        let archiveText = try contentsOfZipEntry(archive, entryPath: "pawWatchPackage/Sources/pawWatchFeature/\(relative)")
        #expect(workingText == archiveText, "\(relative) drifted; rerun scripts/export_pawwatch_feature.sh to refresh the bundle.")
    }

    // Sanity-check that a LocationFix instance round-trips through Codable, proving the core types remain usable.
    let fix = LocationFix(
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        source: .watchOS,
        coordinate: .init(latitude: 37.3318, longitude: -122.0312),
        altitudeMeters: 10,
        horizontalAccuracyMeters: 5,
        verticalAccuracyMeters: 7,
        speedMetersPerSecond: 0.6,
        courseDegrees: 42,
        headingDegrees: nil,
        batteryFraction: 0.77,
        sequence: 123,
        trackingPreset: "aggressive"
    )
    let encoded = try JSONEncoder().encode(fix)
    let decoded = try JSONDecoder().decode(LocationFix.self, from: encoded)
    #expect(decoded == fix)
}

// MARK: - Helpers

private enum ExportValidationError: Error, CustomStringConvertible {
    case missingArchive(URL)
    case processFailed(command: String, message: String)

    var description: String {
        switch self {
        case .missingArchive(let url):
            return "Export archive not found at \(url.path). Run scripts/export_pawwatch_feature.sh first."
        case let .processFailed(command, message):
            return "Command failed: \(command) — \(message)"
        }
    }
}

private func workspaceRootURL(file: StaticString = #filePath) throws -> URL {
    var url = URL(fileURLWithPath: "\(file)")
    for _ in 0..<3 { // …/Tests/pawWatchFeatureTests
        url.deleteLastPathComponent()
    }
    guard url.lastPathComponent == "pawWatchPackage" else {
        throw ExportValidationError.processFailed(command: "path-resolution", message: "Unable to locate package root from \(file)")
    }
    return url.deletingLastPathComponent()
}

private func swiftSourceRelativePaths(at directory: URL) throws -> [String] {
    let base = directory.path + "/"
    guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
        throw ExportValidationError.processFailed(command: "enumerate", message: "Failed to enumerate \(directory.path)")
    }

    var results: [String] = []
    for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
        let relative = String(fileURL.path.dropFirst(base.count))
        results.append(relative)
    }
    return results.sorted()
}

private func zipEntries(in archive: URL) throws -> [String] {
    let data = try runProcess(executable: "/usr/bin/zipinfo", arguments: ["-1", archive.path])
    let raw = String(decoding: data, as: UTF8.self)
    return raw.split(separator: "\n").map { String($0) }
}

private func contentsOfZipEntry(_ archive: URL, entryPath: String) throws -> String {
    let data = try runProcess(executable: "/usr/bin/unzip", arguments: ["-p", archive.path, entryPath])
    return String(decoding: data, as: UTF8.self)
}

private func runProcess(executable: String, arguments: [String]) throws -> Data {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        let message = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        throw ExportValidationError.processFailed(command: ([executable] + arguments).joined(separator: " "), message: message.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    return stdout.fileHandleForReading.readDataToEndOfFile()
}
