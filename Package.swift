// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Owl",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // Core library — all testable business logic lives here
        .target(
            name: "OwlCore",
            path: "Sources/OwlCore"
        ),
        // Executable — thin app shell, UI entry point
        .executableTarget(
            name: "Owl",
            dependencies: ["OwlCore"],
            path: "Sources/Owl"
        ),
        // Unit + Integration tests for OwlCore
        .testTarget(
            name: "OwlCoreTests",
            dependencies: ["OwlCore"],
            path: "Tests/OwlCoreTests"
        )
    ]
)
