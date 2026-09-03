// swift-tools-version: 6.0
import PackageDescription

/// `AppUIKit` — the SwiftUI Design System (tokens + purely-presentational
/// components) for the template. Named `AppUIKit` so it never collides with
/// Apple's `UIKit`.
///
/// **Hard invariant (Source Spec §4.2 / §4.3, ArchTests rule K):** depends on
/// `Core` **only** — it must NEVER depend on `Framework`. Not pulling in the MVI
/// machinery keeps the design system extractable into any SwiftUI project and
/// lets every component render in an Xcode `#Preview` with no ViewModel.
///
/// Every component is presentational: `@Binding` / `@State` for local transient
/// UI state and closures for actions ONLY — no `ObservableObject`,
/// `@StateObject`, or `@ObservedObject` (a test greps the sources to prove it).
///
/// Builds and tests standalone:
///   swift build --package-path Packages/AppUIKit
///   swift test  --package-path Packages/AppUIKit
let package = Package(
    name: "AppUIKit",
    // `.iOS(.v16)` is the product floor. `.macOS(.v13)` is added ONLY so
    // `swift test --package-path Packages/AppUIKit` runs on the macOS host
    // (SwiftPM builds tests for the host toolchain). It imposes nothing on app
    // consumers.
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "AppUIKit", targets: ["AppUIKit"]),
    ],
    dependencies: [
        .package(path: "../Core"),
    ],
    targets: [
        .target(
            name: "AppUIKit",
            dependencies: [
                .product(name: "Core", package: "Core"),
            ]
        ),
        .testTarget(
            name: "AppUIKitTests",
            dependencies: ["AppUIKit"]
        ),
    ]
)
