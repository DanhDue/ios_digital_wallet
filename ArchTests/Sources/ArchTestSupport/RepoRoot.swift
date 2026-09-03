import Foundation

/// Locates the repository root so architecture-rule tests can read checked-in
/// governance files (`ArchTests/baseline.txt`,
/// `scripts/module_boundary_whitelist.txt`) regardless of the working directory
/// `swift test` / Xcode happens to start with.
///
/// The root is the first ancestor of this source file that contains
/// `Workspace.swift` (the Tuist workspace manifest — see Source Spec §4.1).
public enum RepoRoot {
    /// Absolute URL of the repository root.
    public static let url: URL = {
        let marker = "Workspace.swift"
        let fileManager = FileManager.default
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while true {
            let candidate = directory.appendingPathComponent(marker)
            if fileManager.fileExists(atPath: candidate.path) {
                return directory
            }
            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path {
                fatalError("RepoRoot: no \(marker) found walking up from \(#filePath)")
            }
            directory = parent
        }
    }()

    /// Absolute path of the repository root.
    public static var path: String {
        url.path
    }

    /// Resolves `relativePath` against the repository root.
    public static func url(for relativePath: String) -> URL {
        url.appendingPathComponent(relativePath)
    }
}
