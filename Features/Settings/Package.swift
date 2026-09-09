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
///   * `SettingsContainer.swift` (top level) — Factory `Container` extensions
///                         that register `Data` → `Domain` dependencies; it is
///                         outside every layer folder on purpose so K2/K3/K4 do
///                         not scan it.
///
/// **Dependencies** — `Platform`, `Framework`, `Network`, `AppUIKit` (template
/// parity: `Network` is declared even though Settings is local-only and never
/// calls it, Source Spec §11). `Core` is used transitively through those four.
///
/// Builds and tests standalone:
///   swift build --package-path Features/Settings
///   swift test  --package-path Features/Settings
let package = Package(
    name: "Settings",
    // `.iOS(.v16)` is the product floor. `.macOS(.v13)` is added ONLY so
    // `swift test --package-path Features/Settings` runs on the macOS host
    // (SwiftPM builds tests for the host toolchain). It imposes nothing on app
    // consumers.
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Settings", targets: ["Settings"]),
    ],
    dependencies: [
        .package(path: "../../Packages/AppUIKit"),
        .package(path: "../../Packages/Framework"),
        .package(path: "../../Packages/Network"),
        .package(path: "../../Packages/Platform"),
    ],
    targets: [
        .target(
            name: "Settings",
            dependencies: [
                .product(name: "AppUIKit", package: "AppUIKit"),
                .product(name: "Framework", package: "Framework"),
                .product(name: "Network", package: "Network"),
                .product(name: "Platform", package: "Platform"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "SettingsTests",
            dependencies: ["Settings"]
        ),
    ]
)
