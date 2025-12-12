// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "pawWatchFeature",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11),
        // Included to allow `swift test` on macOS host.
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "pawWatchFeature",
            targets: ["pawWatchFeature"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "pawWatchFeature",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "pawWatchFeatureTests",
            dependencies: [
                "pawWatchFeature"
            ]
        ),
    ]
)
