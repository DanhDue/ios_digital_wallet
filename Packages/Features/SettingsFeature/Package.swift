// swift-tools-version: 6.0
import PackageDescription

/// `SettingsFeature` — the reference MVI + Clean-Architecture feature of the
/// template (Source Spec §4.4 / §11). Local-only: it persists a
/// `SettingsEntity` through `Core.CacheStore`, with no backend.
///
/// **Layer layout** (ArchTests K2 / K3 / K4 / K5):
///   * `Domain/**`       — pure Swift (`SettingsEntity`, `SettingsRepository`
///                         protocol, `GetSettingsUseCase` / `SaveSettingsUseCase`);
///                         no SwiftUI / UIKit / Combine.
///   * `Data/**`         — every declaration `internal` (`SettingsDTO`,
///                         `SettingsMapper`, `SettingsLocalDataSource`,
///                         `SettingsRepositoryImpl`); reached only through the
///                         `Domain` protocol.
///   * `Presentation/**` — `SettingsAction` / `SettingsState` / `SettingsEvent`,
///                         `SettingsViewModel` (`MviViewModel`), `SettingsView`,
///                         `SettingsRouteProvider`. Never references `Data` types.
///   * `SettingsFeatureModule.swift` (top level) — the only composition point
///                         that wires `Data` → `Domain` → `Presentation`; it is
///                         outside every layer folder on purpose so K2/K3/K4 do
///                         not scan it.
///
/// **Dependencies** — `Platform`, `Framework`, `Network`, `AppUIKit` (template
/// parity: `Network` is declared even though Settings is local-only and never
/// calls it, Source Spec §11). `Core` is used transitively through those four.
///
/// Builds and tests standalone:
///   swift build --package-path Packages/Features/SettingsFeature
///   swift test  --package-path Packages/Features/SettingsFeature
let package = Package(
    name: "SettingsFeature",
    // `.iOS(.v16)` is the product floor. `.macOS(.v13)` is added ONLY so
    // `swift test --package-path Packages/Features/SettingsFeature` runs on the
    // macOS host (SwiftPM builds tests for the host toolchain). It imposes
    // nothing on app consumers.
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "SettingsFeature", targets: ["SettingsFeature"]),
    ],
    dependencies: [
        .package(path: "../../AppUIKit"),
        .package(path: "../../Framework"),
        .package(path: "../../Network"),
        .package(path: "../../Platform"),
    ],
    targets: [
        .target(
            name: "SettingsFeature",
            dependencies: [
                .product(name: "AppUIKit", package: "AppUIKit"),
                .product(name: "Framework", package: "Framework"),
                .product(name: "Network", package: "Network"),
                .product(name: "Platform", package: "Platform"),
            ]
        ),
        .testTarget(
            name: "SettingsFeatureTests",
            dependencies: ["SettingsFeature"]
        ),
    ]
)
