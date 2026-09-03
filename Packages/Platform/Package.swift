// swift-tools-version: 6.0
import PackageDescription

/// `Platform` — the cross-feature seam of the template: the per-tab `AppRouter`
/// (one `NavigationPath` per tab, mirroring Android's `NestedNavigator`), the
/// `RouteProvider` registry, `AppRoute` / `AppRoutes`, and the fire-and-forget
/// `AppEventBus` (`PassthroughSubject`, replay 0).
///
/// Depends on `Core` **only** (Source Spec Changelog #7: `AppRoute` is
/// `Hashable`, `RouteProvider` returns `AnyView`, `AppRouter` / `AppEventBus`
/// are Combine — nothing from `Framework`, so `Platform` is a peer of
/// `Framework` / `Network` / `AppUIKit`, not a consumer). Builds and tests
/// standalone:
///   swift build --package-path Packages/Platform
///   swift test  --package-path Packages/Platform
let package = Package(
    name: "Platform",
    // `.iOS(.v16)` is the product floor (`NavigationPath`). `.macOS(.v13)` is
    // added ONLY so `swift test --package-path Packages/Platform` runs on the
    // macOS host (SwiftPM builds tests for the host toolchain; `NavigationPath`
    // and Combine both need macOS 13+). It imposes nothing on app consumers.
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Platform", targets: ["Platform"]),
    ],
    dependencies: [
        .package(path: "../Core"),
    ],
    targets: [
        .target(
            name: "Platform",
            dependencies: [
                .product(name: "Core", package: "Core"),
            ]
        ),
        .testTarget(
            name: "PlatformTests",
            dependencies: ["Platform"]
        ),
    ]
)
