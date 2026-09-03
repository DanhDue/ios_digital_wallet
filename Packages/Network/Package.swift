// swift-tools-version: 6.0
import PackageDescription

/// `Network` — URLSession-based HTTP client (`APIClient` / `URLSessionAPIClient`),
/// request interceptors, `Environment`, `NetworkError` → `Core.AppError` mapping,
/// and an in-package `MockAPIClient` test double. Depends on `Core` **only**
/// (Source Spec Changelog #8: a 401 is surfaced to the composition root through
/// `Core.AuthEventSink`, so `Network` never imports `Platform`). Builds and
/// tests standalone:
///   swift build --package-path Packages/Network
///   swift test  --package-path Packages/Network
let package = Package(
    name: "Network",
    // `.iOS(.v16)` is the product floor. `.macOS(.v13)` is added ONLY so
    // `swift test --package-path Packages/Network` runs on the macOS host
    // (SwiftPM builds tests for the host toolchain). It imposes nothing on app
    // consumers.
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Network", targets: ["Network"]),
    ],
    dependencies: [
        .package(path: "../Core"),
    ],
    targets: [
        .target(
            name: "Network",
            dependencies: [
                .product(name: "Core", package: "Core"),
            ]
        ),
        .testTarget(
            name: "NetworkTests",
            dependencies: ["Network"]
        ),
    ]
)
