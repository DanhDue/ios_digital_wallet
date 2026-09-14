import Foundation
import ProjectDescription
import ProjectDescriptionHelpers

/// The thin App project. One app target; no package dependencies yet — Phase 1
/// wires the local SPM packages via the markers below and in `Tuist/Package.swift`.
private let targets: [Target]
private let schemes: [Scheme]

switch activeMode {
case .enterprise:
    targets = [
        Module.appTarget(
            name: "iOSDigitalWallet",
            bundleId: "com.danhdue.iOSDigitalWallet",
            dependencies: [
                // tuist:app-deps:begin
                .external(name: "AppUIKit"),
                .external(name: "Core"),
                .external(name: "Factory"),
                .external(name: "Framework"),
                .external(name: "Network"),
                .external(name: "Platform"),
                .external(name: "Scanner"),
                .external(name: "Settings"),
                .external(name: "Shell"),
                // tuist:app-deps:end
            ]
        ),
        Module.appTestTarget(
            appName: "iOSDigitalWallet",
            bundleId: "com.danhdue.iOSDigitalWalletTests"
        ),
        Module.appUITestTarget(
            appName: "iOSDigitalWallet",
            bundleId: "com.danhdue.iOSDigitalWalletUITests"
        ),
    ]
    schemes = [
        .scheme(
            name: "iOSDigitalWallet",
            shared: true,
            buildAction: .buildAction(targets: ["iOSDigitalWallet"]),
            testAction: .targets(["iOSDigitalWalletTests", "iOSDigitalWalletUITests"]),
            runAction: .runAction(executable: "iOSDigitalWallet")
        ),
    ]

case .lean:
    targets = [
        Module.appTarget(
            name: "iOSDigitalWallet",
            bundleId: "com.danhdue.iOSDigitalWallet",
            dependencies: [
                .external(name: "AppUIKit"),
                .external(name: "Core"),
                .external(name: "Factory"),
                .external(name: "Framework"),
                .external(name: "Network"),
                .external(name: "Platform"),
                .external(name: "Settings"),
                .external(name: "Shell"),
            ]
        ),
        Module.appTestTarget(
            appName: "iOSDigitalWallet",
            bundleId: "com.danhdue.iOSDigitalWalletTests",
            sources: activeMode == .lean
                ? .sourceFilesList(globs: [.glob(
                    "App/Tests/**",
                    excluding: ["App/Tests/AppTests/Scanner*", "App/Tests/AppTests/DeepLinkFlowTests.swift"]
                )])
                : ["App/Tests/**"]
        ),
        Module.appUITestTarget(
            appName: "iOSDigitalWallet",
            bundleId: "com.danhdue.iOSDigitalWalletUITests",
            sources: activeMode == .lean
                ? .sourceFilesList(globs: [.glob("App/UITests/**", excluding: ["App/UITests/Scanner*"])])
                : ["App/UITests/**"]
        ),
    ]
    schemes = [
        .scheme(
            name: "iOSDigitalWallet",
            shared: true,
            buildAction: .buildAction(targets: ["iOSDigitalWallet"]),
            testAction: .targets(["iOSDigitalWalletTests", "iOSDigitalWalletUITests"]),
            runAction: .runAction(executable: "iOSDigitalWallet")
        ),
    ]

case .plugin:
    targets = [
        .target(
            name: "Sample",
            destinations: Module.destinations,
            product: .app,
            bundleId: "com.danhdue.Sample",
            deploymentTargets: .iOS(Module.iOSDeploymentTarget),
            infoPlist: .file(path: "Sample/Resources/Info.plist"),
            sources: ["Sample/Sources/**"],
            dependencies: [
                .external(name: "Plugin"),
            ]
        ),
        .target(
            name: "SampleTests",
            destinations: Module.destinations,
            product: .unitTests,
            bundleId: "com.danhdue.SampleTests",
            deploymentTargets: .iOS(Module.iOSDeploymentTarget),
            infoPlist: .default,
            sources: ["Sample/Tests/**"],
            dependencies: [
                .target(name: "Sample"),
                .external(name: "Plugin"),
            ]
        ),
    ]
    schemes = [
        .scheme(
            name: "Sample",
            shared: true,
            buildAction: .buildAction(targets: ["Sample"]),
            testAction: .targets(["SampleTests"]),
            runAction: .runAction(executable: "Sample")
        ),
    ]
}

let project = Project(
    name: activeMode == .plugin ? "PluginDevbed" : "iOSDigitalWallet",
    organizationName: "com.danhdue",
    targets: targets,
    schemes: schemes
)
