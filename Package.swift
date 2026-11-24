// swift-tools-version: 6.2
import PackageDescription

let approachable: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "Space2Moon",
    platforms: [.macOS(.v15)],
    targets: [
        // Scanning, cleaning and history. No UI, nonisolated by design.
        .target(name: "MageCore", swiftSettings: approachable),
        // The SwiftUI app. Main actor by default.
        .executableTarget(
            name: "Space2Moon",
            dependencies: ["MageCore"],
            swiftSettings: approachable + [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "MageCoreTests", dependencies: ["MageCore"], swiftSettings: approachable),
    ]
)
