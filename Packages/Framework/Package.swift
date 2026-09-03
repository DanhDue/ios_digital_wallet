// swift-tools-version: 6.0
import PackageDescription

/// `Framework` — the MVI base every Feature / Shell ViewModel inherits from
/// (`MvvmViewModel`, `ViewState`, `MviViewModel`, plus the §5.5 async-effect
/// helper). Depends on `Core` only. Builds and tests standalone:
///   swift build --package-path Packages/Framework
///   swift test  --package-path Packages/Framework
let package = Package(
    name: "Framework",
    // `.iOS(.v16)` is the product floor. `.macOS(.v13)` is added ONLY so
    // `swift test --package-path Packages/Framework` can run on the macOS host
    // (SwiftPM builds tests for the host toolchain, and this package uses
    // Combine, which needs macOS 10.15+). It imposes nothing on app consumers.
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Framework", targets: ["Framework"]),
    ],
    dependencies: [
        .package(path: "../Core"),
    ],
    targets: [
        .target(
            name: "Framework",
            dependencies: [
                .product(name: "Core", package: "Core"),
            ]
        ),
        .testTarget(
            name: "FrameworkTests",
            dependencies: ["Framework"]
        ),
    ]
)
