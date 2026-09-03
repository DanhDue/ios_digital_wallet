// swift-tools-version: 6.0
import PackageDescription

/// `Shell` — the tab container of the template: `ShellView` (a `TabView` with one
/// per-tab `NavigationStack`, Source Spec §6.1 / Changelog #4), `ShellViewModel`
/// (`MviViewModel`, so the host obeys the same MVI discipline it asks of every
/// Feature), and `HomeStubView`.
///
/// **Hard invariant (Source Spec Changelog #6, ArchTests K6):** depends on
/// `Platform`, `Framework`, `AppUIKit` — and NEVER on a Feature package. The
/// Shell is feature-blind: it resolves tab content only through
/// `AppRouter.destination(for:)`; the `App` composition root (Task 12) is the
/// sole aggregator that registers each feature's `RouteProvider`.
///
/// Builds and tests standalone:
///   swift build --package-path Packages/Shell
///   swift test  --package-path Packages/Shell
let package = Package(
    name: "Shell",
    // `.iOS(.v16)` is the product floor (`NavigationStack`, `NavigationPath`).
    // `.macOS(.v13)` is added ONLY so `swift test --package-path Packages/Shell`
    // runs on the macOS host (SwiftPM builds tests for the host toolchain). It
    // imposes nothing on app consumers.
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Shell", targets: ["Shell"]),
    ],
    dependencies: [
        .package(path: "../AppUIKit"),
        .package(path: "../Framework"),
        .package(path: "../Platform"),
    ],
    targets: [
        .target(
            name: "Shell",
            dependencies: [
                .product(name: "AppUIKit", package: "AppUIKit"),
                .product(name: "Framework", package: "Framework"),
                .product(name: "Platform", package: "Platform"),
            ]
        ),
        .testTarget(
            name: "ShellTests",
            dependencies: ["Shell"]
        ),
    ]
)
