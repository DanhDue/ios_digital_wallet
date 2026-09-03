// swift-tools-version:6.0
import PackageDescription

/// swift-syntax is version-locked to the Swift compiler. This toolchain is
/// Swift 6.3.3 (swiftlang-6.3.3.1.3). The Swift project publishes official
/// swift-syntax *prebuilts* for this exact toolchain at
///   https://download.swift.org/prebuilts/swift-syntax/602.0.0/swiftlang-6.3.3.1.3-macosx26.5-MacroSupport.zip
/// i.e. 602.0.0 is the release the 6.3.3 toolchain is built and tested against.
/// `swift package resolve` also accepts 600.0.1 / 601.0.1 / 603.0.0, but only
/// 602.0.0 has a matching official prebuilt, so that is the version pinned here.
/// Keep this EXACT and in sync with README.md ("Prerequisites").
let package = Package(
    name: "ArchTests",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ArchTestSupport", targets: ["ArchTestSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", exact: "602.0.0"),
    ],
    targets: [
        .target(
            name: "ArchTestSupport",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "ArchTests",
            dependencies: ["ArchTestSupport"]
        ),
    ]
)
