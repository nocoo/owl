// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Owl",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // Obj-C bridge for Apple Silicon IOHIDEventSystemClient temperature API
        .target(
            name: "HIDThermalBridge",
            path: "Sources/HIDThermalBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        // Core library — all testable business logic lives here
        .target(
            name: "OwlCore",
            dependencies: ["HIDThermalBridge"],
            path: "Sources/OwlCore",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        // Executable — thin app shell, UI entry point
        .executableTarget(
            name: "Owl",
            dependencies: ["OwlCore"],
            path: "Sources/Owl",
            exclude: ["Resources"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        // Unit + Integration tests for OwlCore
        .testTarget(
            name: "OwlCoreTests",
            dependencies: ["OwlCore"],
            path: "Tests/OwlCoreTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
