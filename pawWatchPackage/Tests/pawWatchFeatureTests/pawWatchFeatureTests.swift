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

#if !os(watchOS)
@MainActor
@Test func performanceMonitorBatteryDrainSmoothingClampsAndSmooths() async {
    let monitor = PerformanceMonitor.shared

    let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    let fix1 = makeFix(sequence: 1, timestamp: t0, battery: 1.0)
    monitor.recordRemoteFix(fix1, watchReachable: true)

    let fix2 = makeFix(sequence: 2, timestamp: t0.addingTimeInterval(120), battery: 0.98)
    monitor.recordRemoteFix(fix2, watchReachable: true)

    #expect(abs(monitor.batteryDrainPerHourInstant - 30) < 0.2)
    #expect(abs(monitor.batteryDrainPerHourSmoothed - 6) < 0.8)

    let fix3 = makeFix(sequence: 3, timestamp: t0.addingTimeInterval(240), battery: 0.97)
    monitor.recordRemoteFix(fix3, watchReachable: true)

    #expect(abs(monitor.batteryDrainPerHourInstant - 30) < 0.2)
    #expect(abs(monitor.batteryDrainPerHourSmoothed - 10.8) < 1.0)
}

private func makeFix(sequence: Int, timestamp: Date, battery: Double) -> LocationFix {
    LocationFix(
        timestamp: timestamp,
        source: .watchOS,
        coordinate: .init(latitude: 37.3318, longitude: -122.0312),
        altitudeMeters: 10,
        horizontalAccuracyMeters: 5,
        verticalAccuracyMeters: 7,
        speedMetersPerSecond: 0.6,
        courseDegrees: 42,
        headingDegrees: nil,
        batteryFraction: battery,
        sequence: sequence,
        trackingPreset: "balanced"
    )
}
#endif

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
    // Read output while the process runs to avoid pipe-buffer deadlocks on large files.
    let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        let message = String(decoding: stderrData, as: UTF8.self)
        throw ExportValidationError.processFailed(
            command: ([executable] + arguments).joined(separator: " "),
            message: message.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    return stdoutData
}
