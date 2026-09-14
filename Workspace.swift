import ProjectDescription
import ProjectDescriptionHelpers

/// Workspace = the App project.
let workspace = Workspace(
    name: activeMode == .plugin ? "PluginDevbed" : "iOSDigitalWallet",
    projects: [
        ".",
    ]
)
