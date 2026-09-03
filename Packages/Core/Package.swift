// swift-tools-version: 6.0
import PackageDescription

/// `Core` — the dependency floor of the template. Swift stdlib + Foundation +
/// Security only; **no package dependencies** (`ArchTests` rule K7 depends on
/// this list staying empty). Builds and tests standalone:
///   swift build --package-path Packages/Core
///   swift test  --package-path Packages/Core
let package = Package(
    name: "Core",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "Core", targets: ["Core"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "Core"),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"]
        ),
    ]
)
