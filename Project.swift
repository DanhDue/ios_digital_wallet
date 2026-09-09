import ProjectDescription
import ProjectDescriptionHelpers

/// The thin App project. One app target; no package dependencies yet — Phase 1
/// wires the local SPM packages via the markers below and in `Tuist/Package.swift`.
let project = Project(
    name: "iOSDigitalWallet",
    organizationName: "com.danhdue",
    targets: [
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
    ],
    schemes: [
        .scheme(
            name: "iOSDigitalWallet",
            shared: true,
            buildAction: .buildAction(targets: ["iOSDigitalWallet"]),
            testAction: .targets(["iOSDigitalWalletTests"]),
            runAction: .runAction(executable: "iOSDigitalWallet")
        ),
    ]
)
