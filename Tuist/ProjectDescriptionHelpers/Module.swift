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

    /// The URL scheme registered for deep links (Task 8, Source Spec §4.10):
    /// `App/Resources/Info.plist`'s `CFBundleURLSchemes` references it as
    /// `$(DEEPLINK_SCHEME)`. The single source of truth for the literal — no
    /// other file in the repo may hard-code it — so `scripts/rename_project.sh`
    /// (Task 12) has exactly one place to rewrite.
    public static let deepLinkScheme = "iosdigitalwallet"

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
            dependencies: dependencies,
            settings: .settings(base: [
                "DEEPLINK_SCHEME": .string(deepLinkScheme),
            ])
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

    /// The host-app UI-test target (`App/UITests/**`, Task 9): drives the app
    /// through the OS — `XCUIApplication.open(_:)` / SpringBoard — rather
    /// than in-process, the one hop `App/Tests/**` structurally cannot cover
    /// (`.onOpenURL` calling `deepLinkRouter.open(url:)` is the same callee a
    /// direct unit-test call already exercises). Added to `Project.swift`
    /// alongside `appTarget` / `appTestTarget`, and to the scheme's
    /// `testAction` so `xcodebuild test` runs it too.
    ///
    /// Carries the same `DEEPLINK_SCHEME` build setting `appTarget` sets, and
    /// republishes it into this target's own `Info.plist` under
    /// `DeepLinkScheme` — `Bundle(for:)` inside the UI test process resolves
    /// to *this* bundle, never the app-under-test's, so the registered scheme
    /// has to reach the test some way that isn't a second hard-coded literal;
    /// this is that way. `Module.deepLinkScheme` stays the single source of
    /// truth `scripts/rename_project.sh` (Task 12) rewrites.
    ///
    /// - Parameters:
    ///   - appName: the host app target name; the UI test target is
    ///     `<appName>UITests`.
    ///   - bundleId: bundle identifier for the UI test bundle.
    public static func appUITestTarget(
        appName: String,
        bundleId: String
    ) -> Target {
        .target(
            name: "\(appName)UITests",
            destinations: destinations,
            product: .uiTests,
            bundleId: bundleId,
            deploymentTargets: .iOS(iOSDeploymentTarget),
            infoPlist: .extendingDefault(with: [
                "DeepLinkScheme": "$(DEEPLINK_SCHEME)",
            ]),
            sources: ["App/UITests/**"],
            scripts: [swiftLintScript],
            dependencies: [.target(name: appName)],
            settings: .settings(base: [
                "DEEPLINK_SCHEME": .string(deepLinkScheme),
            ])
        )
    }
}
