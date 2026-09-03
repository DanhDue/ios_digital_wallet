import ProjectDescription

/// Shared target factory so every module / target in the template is defined
/// the same way (DRY). The deployment target lives here in exactly one place.
///
/// Phase 1+ adds `Module.package(name:dependencies:)` alongside `appTarget`
/// once the local SPM packages (declared in `Tuist/Package.swift`) land.
public enum Module {
    /// The single source of truth for the minimum iOS deployment target across
    /// the whole repo. Referenced by every target the factory produces.
    public static let iOSDeploymentTarget = "16.0"

    /// Platforms every target in the template ships to.
    public static let destinations: Destinations = .iOS

    /// Builds the thin host application target.
    ///
    /// - Parameters:
    ///   - name: Product / target name (also the generated scheme name).
    ///   - bundleId: The app bundle identifier.
    ///   - dependencies: Product dependencies. Mason bricks edit this list via
    ///     the `// tuist:app-deps:begin/end` markers in `Project.swift`.
    public static func appTarget(
        name: String,
        bundleId: String,
        dependencies: [TargetDependency] = []
    ) -> Target {
        .target(
            name: name,
            destinations: destinations,
            product: .app,
            bundleId: bundleId,
            deploymentTargets: .iOS(iOSDeploymentTarget),
            infoPlist: .file(path: "App/Resources/Info.plist"),
            sources: ["App/Sources/**"],
            resources: ["App/Resources/Assets.xcassets"],
            dependencies: dependencies
        )
    }
}
