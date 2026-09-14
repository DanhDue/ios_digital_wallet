// swift-tools-version: 5.9
import Foundation
import PackageDescription

#if TUIST
    import ProjectDescription
    import ProjectDescriptionHelpers

    let packageSettings = PackageSettings(
        productTypes: [:]
    )
#else
    private enum TemplateMode: String {
        case enterprise
        case lean
        case plugin
    }

    private let activeMode: TemplateMode = {
        let modeFile = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("ProjectDescriptionHelpers/ActiveMode.swift")
        if let content = try? String(contentsOf: modeFile, encoding: .utf8) {
            if content.contains(".lean") {
                return .lean
            }
            if content.contains(".plugin") {
                return .plugin
            }
        }
        return .enterprise
    }()
#endif

private var packageDependencies: [PackageDescription.Package.Dependency] {
    switch activeMode {
    case .enterprise:
        [
            // tuist:packages:begin
            .package(url: "https://github.com/hmlongco/Factory.git", exact: "2.4.3"),
            .package(path: "../Features/Scanner"),
            .package(path: "../Features/Settings"),
            .package(path: "../Packages/AppUIKit"),
            .package(path: "../Packages/Core"),
            .package(path: "../Packages/Framework"),
            .package(path: "../Packages/Network"),
            .package(path: "../Packages/Platform"),
            .package(path: "../Packages/Shell"),
            // tuist:packages:end
        ]
    case .lean:
        [
            .package(url: "https://github.com/hmlongco/Factory.git", exact: "2.4.3"),
            .package(path: "../Features/Settings"),
            .package(path: "../Packages/AppUIKit"),
            .package(path: "../Packages/Core"),
            .package(path: "../Packages/Framework"),
            .package(path: "../Packages/Network"),
            .package(path: "../Packages/Platform"),
            .package(path: "../Packages/Shell"),
        ]
    case .plugin:
        [
            .package(path: "../Plugin"),
        ]
    }
}

/// SPM manifest Tuist reads for packages.
let package = PackageDescription.Package(
    name: activeMode == .plugin ? "PluginDevbed" : "iOSDigitalWallet",
    dependencies: packageDependencies
)
