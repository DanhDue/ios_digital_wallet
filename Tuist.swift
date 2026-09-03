import ProjectDescription

/// Tuist configuration for the iOS Super App Template.
///
/// The project graph is fully generated: `*.xcodeproj` / `*.xcworkspace` are
/// build artifacts and are git-ignored. The Tuist manifests are the source of
/// truth. The exact Tuist version is pinned in `.tuist-version` / `.mise.toml`.
let tuist = Tuist(
    project: .tuist()
)
