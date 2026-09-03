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
                .external(name: "Core"),
                .external(name: "Framework"),
                // tuist:app-deps:end
            ]
        ),
    ]
)
