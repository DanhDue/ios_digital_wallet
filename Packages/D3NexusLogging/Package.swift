// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "D3NexusLogging",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "D3NexusLogging",
            targets: ["D3NexusLogging"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "D3NexusLogging",
            dependencies: []
        ),
        .testTarget(
            name: "D3NexusLoggingTests",
            dependencies: ["D3NexusLogging"]
        ),
    ]
)
