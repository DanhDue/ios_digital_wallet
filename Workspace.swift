import ProjectDescription

/// Workspace = the App project. Phase 1 adds the local SPM packages here.
let workspace = Workspace(
    name: "iOSDigitalWallet",
    projects: [
        ".",
    ]
)
