// swift-tools-version: 6.0
import PackageDescription

/// `ScannerFeature` — the template's **stub** feature (Source Spec §11 / §4.3).
/// It ships the full Clean-Architecture scaffold a real feature has, but no
/// logic: `ScannerView` is a "coming soon" placeholder and the repository
/// returns a fixed `ScannerEntity.stub`.
///
/// **Layer layout** (ArchTests K2 / K3 / K4 / K5):
///   * `Domain/**`       — pure Swift (`ScannerEntity`, `ScannerRepository`
///                         protocol, `GetScannerDataUseCase`); no SwiftUI /
///                         UIKit / Combine.
///   * `Data/**`         — `internal` only (`ScannerRepositoryImpl`), reached
///                         through the `Domain` protocol.
///   * `Presentation/**` — `ScannerAction` / `ScannerState` / `ScannerEvent`,
///                         `ScannerViewModel` (`MviViewModel`), `ScannerView`,
///                         `ScannerRouteProvider`.
///   * `ScannerModule.swift` (top level) — the only composition seam that
///                         wires `Data` → `Domain` → `Presentation`.
///
/// **Dependencies** — `Platform`, `Framework`, `AppUIKit` only. There is **no
/// `Network` dependency**: the Scanner stub performs no I/O (Source Spec
/// Changelog — "Scanner has no network"). `Core` is used transitively.
///
/// Builds and tests standalone:
///   swift build --package-path Features/Scanner
///   swift test  --package-path Features/Scanner
let package = Package(
    name: "Scanner",
    // `.iOS(.v16)` is the product floor. `.macOS(.v13)` is added ONLY so
    // `swift test --package-path Features/Scanner` runs on the
    // macOS host. It imposes nothing on app consumers.
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Scanner", targets: ["Scanner"]),
    ],
    dependencies: [
        .package(path: "../../Packages/AppUIKit"),
        .package(path: "../../Packages/Framework"),
        .package(path: "../../Packages/Platform"),
    ],
    targets: [
        .target(
            name: "Scanner",
            dependencies: [
                .product(name: "AppUIKit", package: "AppUIKit"),
                .product(name: "Framework", package: "Framework"),
                .product(name: "Platform", package: "Platform"),
            ]
        ),
        .testTarget(
            name: "ScannerTests",
            dependencies: ["Scanner"]
        ),
    ]
)
