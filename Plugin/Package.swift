// swift-tools-version: 6.0
import PackageDescription

/// `Plugin` — the clean architecture Swift package backing the Flutter plugin devbed.
///
/// **Platform floor note:** `platforms: [.iOS("15.0")]` deliberately sits below the template's
/// iOS 16 floor because this package's consumer is a Flutter app, matching what `pac_native_plugin` emits.
let package = Package(
    name: "Plugin",
    platforms: [.iOS("15.0")],
    products: [
        .library(name: "Plugin", targets: ["Plugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hmlongco/Factory.git", exact: "3.3.2"),
    ],
    targets: [
        .binaryTarget(
            name: "Flutter",
            path: "Vendor/Flutter.xcframework"
        ),
        .target(
            name: "Plugin",
            dependencies: [
                "Flutter",
                .product(name: "FactoryKit", package: "Factory"),
            ]
        ),
        .testTarget(
            name: "PluginTests",
            dependencies: ["Plugin"]
        ),
    ]
)
