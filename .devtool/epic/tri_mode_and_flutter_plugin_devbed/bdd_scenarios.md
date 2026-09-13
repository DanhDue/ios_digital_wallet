# BDD Scenarios — Tri-Mode iOS Template & Flutter Plugin Native Devbed

Canonical Gherkin suite for epic `tri_mode_and_flutter_plugin_devbed`.
Derived purely from the HLD Use Cases (§4.2) and Sequence Diagram (§4.3) — **not** from any
existing implementation.

Tags: `[Tier A - Unit]` = class/function level, runnable by `xcodebuild test` /
`swift test --package-path`. `[Tier C - Integration]` = host composition, mode switching,
end-to-end build and navigation.

---

## Feature: Enterprise ↔ Lean mode switching

### Scenario S1: Switching to Lean unwires Scanner from the Tuist graph
`[Tier C - Integration]`
```gherkin
Given the project is in enterprise mode
And "Tuist/Package.swift" declares .package(path: "../Features/Scanner")
And "Project.swift" declares .external(name: "Scanner")
When I run "./scripts/configure_mode.sh lean"
Then "Tuist/ProjectDescriptionHelpers/ActiveMode.swift" declares activeMode == .lean
And the generated graph contains no Scanner package or target
And "tuist generate --no-open" completes without error
And "xcodebuild build" succeeds
```

### Scenario S2: Switching to Lean unwires Scanner from the composition root
`[Tier C - Integration]`
```gherkin
Given the project is in enterprise mode
When I run "./scripts/configure_mode.sh lean"
Then "import Scanner" inside app:feature-imports is commented out
And the ScannerRouteProvider registration inside app:route-providers is commented out
And AppComposition.routeProviders contains exactly one provider
And no provider reports canHandle(AppRoutes.ScannerRoot())
```

### Scenario S3: Switching to Lean collapses the shell to two tabs
`[Tier C - Integration]`
```gherkin
Given the project is in enterprise mode with a 3-tab shell
When I run "./scripts/configure_mode.sh lean"
Then the shell:scanner-tab region in ShellView.swift is commented out
And the Settings tab is bound to index 1 and .tag(1)
And ShellConfig defaults are tabCount 2 and initialTab 1
And ShellView renders exactly two tab items
```

### Scenario S4: Lean mode makes the Scanner deep link unresolvable
`[Tier C - Integration]`
```gherkin
Given the project has been switched to lean mode
When the app receives a URL whose route is AppRoutes.ScannerRoot
Then ShellTabResolver.placement(for:) returns nil
And no navigation occurs
And the selected tab is unchanged
```

### Scenario S5: Round-trip through every mode preserves the tree
`[Tier C - Integration]`
```gherkin
Given the project is in enterprise mode with a clean git tree
When I run configure_mode.sh for lean, then plugin, then enterprise
Then every Swift source and Tuist manifest parses without error
And no source file has been lost
And the final tree differs from the starting tree only in generated artefacts
```

### Scenario S6: Returning to Enterprise restores the full governance gate
`[Tier C - Integration]`
```gherkin
Given the project is in lean mode
When I run "./scripts/configure_mode.sh enterprise"
Then Scanner is wired in the manifests, composition root, shell and tab resolver
And "swift test --package-path ArchTests" passes, including rule K10.2
And "bash scripts/check_module_boundaries.sh" passes
```

### Scenario S7: `--prune` physically removes what the mode does not use
`[Tier C - Integration]`
```gherkin
Given the project is in enterprise mode with a clean git tree
When I run "./scripts/configure_mode.sh lean --prune"
Then the directory "Features/Scanner" no longer exists
And "tuist generate --no-open" completes without a missing-dependency error
And "xcodebuild build" succeeds
```

### Scenario S8: `--prune` refuses to run on a dirty tree
`[Tier C - Integration]`
```gherkin
Given the git working tree has at least one uncommitted modification
When I run "./scripts/configure_mode.sh lean --prune"
Then the script exits with a non-zero status
And the error names the dirty tree and the --force override
And no file has been deleted and no manifest modified
```

---

## Feature: Plugin devbed mode

### Scenario S9: Switching to Plugin mode isolates the devbed
`[Tier C - Integration]`
```gherkin
Given the project is in enterprise mode
And a Flutter SDK is installed
When I run "./scripts/configure_mode.sh plugin"
Then activeMode is .plugin
And the generated graph contains only the Plugin package and the Sample app target
And no App, Packages/*, Features/* or ArchTests target is present
```

### Scenario S10: Bootstrap resolves the Flutter engine
`[Tier A - Unit]`
```gherkin
Given FLUTTER_ROOT is unset
And fvm has a version installed containing bin/cache/artifacts/engine/ios/Flutter.xcframework
When I run "./scripts/bootstrap_devbed.sh"
Then "Plugin/Vendor/Flutter.xcframework" exists as a symlink to that xcframework
And the script prints the resolved Flutter and engine versions
And re-running the script leaves the symlink unchanged
```

### Scenario S11: Bootstrap fails actionably when no SDK is present
`[Tier A - Unit]`
```gherkin
Given no Flutter SDK can be found via FLUTTER_ROOT, fvm, or PATH
When I run "./scripts/bootstrap_devbed.sh"
Then the script exits with a non-zero status
And the message names FLUTTER_ROOT and the --flutter-root override
And no symlink or directory is created under Plugin/
```

### Scenario S12: The plugin container resolves and is overridable
`[Tier A - Unit]`
```gherkin
Given a PluginContainer subclassing SharedContainer
When I resolve PluginContainer.shared.repository()
Then a PluginRepositoryImpl instance is returned
When a test registers a mock via PluginContainer.shared.repository.register
Then resolution returns the mock
And PluginContainer.shared.manager.reset() restores the default
```

### Scenario S13: The Pigeon host API delegates to the domain layer
`[Tier A - Unit]`
```gherkin
Given a MyPluginHostApiImpl backed by a stubbed GetDataUseCase
When Flutter invokes the host API method
Then the use case is executed exactly once
And the domain model is mapped to the Pigeon message type
When the use case throws
Then the error is surfaced as a Pigeon error rather than crashing
```

### Scenario S14: The SwiftUI screen is exposed as a FlutterPlatformView
`[Tier A - Unit]`
```gherkin
Given MyPlatformViewFactory is registered with view id "com.danhdue.plugin/native_view"
When Flutter requests a platform view for that id
Then a MyPlatformView is created wrapping a UIHostingController
And its view() returns a non-nil UIView
And the hosted SwiftUI view is driven by MyPluginViewModel
```

### Scenario S15: Background work runs with zero Flutter engine
`[Tier A - Unit]`
```gherkin
Given DataSyncTask is registered for identifier "com.danhdue.plugin.sync"
When the handler is invoked with a BGProcessingTask
Then dependencies are resolved through PluginContainer
And no FlutterEngine is instantiated at any point
And the task is completed with success true when the use case succeeds
When the task expires mid-flight
Then the in-flight work is cancelled and the task completes with success false
```

### Scenario S16: The Sample runner mounts the plugin screen
`[Tier C - Integration]`
```gherkin
Given the project is in plugin mode and the devbed is bootstrapped
When I build and run the Sample scheme on a simulator
Then the app launches without a Flutter engine
And the plugin SwiftUI screen renders
And triggering the sync action drives the same use case the Pigeon path uses
```

---

## Feature: Project renaming with modes

### Scenario S17: `rename_project.sh --mode lean` renames and configures
`[Tier C - Integration]`
```gherkin
Given a freshly cloned template
When I run "./scripts/rename_project.sh AcmeApp com.acme.app --mode lean"
Then the app name, bundle id, URL scheme and entry point are renamed
And configure_mode.sh lean has been applied
And "xcodebuild build" succeeds for scheme AcmeApp
And ArchTests is not executed during self-verification
```

### Scenario S18: `--dry-run` changes nothing
`[Tier C - Integration]`
```gherkin
Given a clean git working tree
When I run "./scripts/rename_project.sh AcmeApp com.acme.app --mode lean --dry-run"
Then the output contains "WOULD CONFIGURE MODE: lean"
And "git status --porcelain" reports no changes
```

### Scenario S19: Omitting `--mode` preserves today's behaviour exactly
`[Tier C - Integration]`
```gherkin
Given a freshly cloned template
When I run "./scripts/rename_project.sh AcmeApp com.acme.app"
Then the project is configured in enterprise mode
And all 10 units remain active
And self-verification runs ArchTests and the boundary guard
```

---

## Feature: Scaffolding and governance

### Scenario S20: The Mason brick emits a plugin matching the Flutter template
`[Tier C - Integration]`
```gherkin
Given the plugin devbed bricks are installed
When I run "mason make ios_native_plugin --name biometric_auth --has_ui true"
Then a four-layer package is emitted with Platform, Domain, Data and Presentation
And its DI container subclasses SharedContainer using FactoryKit 3.3.2
And its layout matches what pac_native_plugin emits in bloc_digital_wallet
When I run the brick with --has_ui false
Then no Presentation directory is emitted and the Pigeon host API path is used
```

### Scenario S21: The test suite is green in both host modes
`[Tier C - Integration]`
```gherkin
Given the test suite has been made mode-aware
When I configure enterprise mode and run the full test suite
Then every test passes, including the Scanner-coupled assertions
When I configure lean mode and run the full test suite
Then every test passes
And no Scanner-coupled assertion is executed
```

### Scenario S22: Lint and format stay clean in every mode
`[Tier C - Integration]`
```gherkin
Given the project is in any of enterprise, lean or plugin mode
When I run swiftlint --strict and swiftformat --lint against the repo root
Then both report zero violations
And the marker-region comments introduced by configure_mode.sh are not flagged
```
