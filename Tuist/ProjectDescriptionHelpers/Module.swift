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

    /// Pre-build SwiftLint gate, attached to every target the factory produces
    /// (app today, local SPM packages in Phase 1) so a style violation fails the
    /// build the same way in Xcode and in CI. One config at repo root
    /// (`quality/.swiftlint.yml`) serves every target.
    ///
    /// It degrades gracefully: if `swiftlint` is not on `PATH` the phase emits a
    /// warning instead of failing, so a fresh checkout without the toolchain can
    /// still build. `basedOnDependencyAnalysis: false` keeps it running on every
    /// build rather than being skipped when inputs look unchanged.
    public static let mergeLocalizationsScript: TargetScript = .pre(
        script: #"""
        if which python3 >/dev/null; then
          python3 "$SRCROOT/scripts/merge_localizations.py"
        fi
        """#,
        name: "Merge Localizations",
        basedOnDependencyAnalysis: false
    )

    public static let swiftLintScript: TargetScript = .pre(
        script: #"""
        export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/share/mise/shims:$PATH"
        if which swiftlint >/dev/null; then
          swiftlint lint --config "$SRCROOT/quality/.swiftlint.yml" --quiet
        else
          echo "warning: swiftlint not installed"
        fi
        """#,
        name: "SwiftLint",
        basedOnDependencyAnalysis: false
    )

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
            resources: [
                "App/Resources/Assets.xcassets",
                "App/Resources/Localizable.xcstrings",
            ],
            scripts: [mergeLocalizationsScript, swiftLintScript],
            dependencies: dependencies
        )
    }

    /// The host-app unit-test target (`App/Tests/**`). Runs the Tier A / Tier C
    /// composition-root tests under `xcodebuild test`; hosted by the app target
    /// it depends on. Added to `Project.swift` alongside `appTarget`.
    ///
    /// - Parameters:
    ///   - appName: the host app target name; the test target is `<appName>Tests`.
    ///   - bundleId: bundle identifier for the test bundle.
    public static func appTestTarget(
        appName: String,
        bundleId: String
    ) -> Target {
        .target(
            name: "\(appName)Tests",
            destinations: destinations,
            product: .unitTests,
            bundleId: bundleId,
            deploymentTargets: .iOS(iOSDeploymentTarget),
            infoPlist: .default,
            sources: ["App/Tests/**"],
            scripts: [swiftLintScript],
            dependencies: [.target(name: appName)]
        )
    }
}
