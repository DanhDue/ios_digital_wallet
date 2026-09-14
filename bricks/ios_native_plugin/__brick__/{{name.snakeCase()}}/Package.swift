// swift-tools-version: 5.9
// Copyright (c) 2026, one of DanhDue ExOICTIF projects. All rights reserved.

import Foundation
import PackageDescription

var dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/hmlongco/Factory.git", exact: "3.3.2"),
]
var targetDependencies: [Target.Dependency] = [
    .product(name: "FactoryKit", package: "Factory"),
]
var targets: [Target] = []

if FileManager.default.fileExists(atPath: "Vendor/Flutter.xcframework") {
    targets.append(
        .binaryTarget(
            name: "Flutter",
            path: "Vendor/Flutter.xcframework"
        )
    )
    targetDependencies.append("Flutter")
} else {
    dependencies.append(
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    )
    targetDependencies.append(
        .product(name: "FlutterFramework", package: "FlutterFramework")
    )
}

targets.append(
    .target(
        name: "{{name.snakeCase()}}",
        dependencies: targetDependencies
    )
)
targets.append(
    .testTarget(
        name: "{{name.snakeCase()}}Tests",
        dependencies: ["{{name.snakeCase()}}"]
    )
)

let package = Package(
    name: "{{name.snakeCase()}}",
    platforms: [.iOS("15.0")],
    products: [
        .library(name: "{{name.paramCase()}}", targets: ["{{name.snakeCase()}}"]),
    ],
    dependencies: dependencies,
    targets: targets
)
