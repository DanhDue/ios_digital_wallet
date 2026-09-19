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
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.2"),
    ],
    targets: [
        .target(
            name: "D3NexusLogging",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "D3NexusLoggingTests",
            dependencies: [
                "D3NexusLogging",
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
    ]
)
