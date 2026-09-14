# Flutter Plugin DevBed Architecture & Build Guide

## Overview

The **Plugin DevBed** provides a dedicated, lightweight environment within the template for developing native iOS Flutter plugins using Clean Architecture and SwiftUI without requiring the full host application or a running Flutter engine during UI/logic iteration.

## Engine Binding & DevBed Bootstrap

iOS Flutter plugins require `Flutter.xcframework` for symbols like `FlutterPlugin`, `FlutterMethodChannel`, `FlutterPlatformView`, etc. Unlike Android, which can resolve Flutter dependencies via Maven (`compileOnly`), iOS SPM packages cannot compile against an ephemeral or missing framework.

The bootstrap script resolves the local Flutter SDK engine artifacts and creates a symlink:

```bash
./scripts/bootstrap_devbed.sh [--flutter-root=<path>]
```

### Resolution Order:
1. `--flutter-root=<path>` CLI argument.
2. `$FLUTTER_ROOT` environment variable.
3. `fvm` configuration (`.fvmrc` or `~/.fvm/versions/default`).
4. `which flutter` on `PATH` (resolved through symlinks to its real SDK root).

The script verifies `<root>/bin/cache/artifacts/engine/ios/Flutter.xcframework` exists and creates a symlink at:
`Plugin/Vendor/Flutter.xcframework`

> [!NOTE]
> `Plugin/Vendor/` is listed in `.gitignore` and must never be committed to git.

## Building & Testing the Plugin Package

### Plain `swift build` is Unsupported
Because `Plugin/Package.swift` depends on an `.xcframework` binary target (`Flutter.xcframework`), running:
```bash
swift build --package-path Plugin
```
is **unsupported** by the Swift Package Manager CLI for iOS targets, as SPM CLI requires explicit platform SDKs and architecture specifications that Xcode provides.

### The Working `xcodebuild` Invocation
To build and test the `Plugin` package standalone:

#### Build:
```bash
(cd Plugin && xcodebuild build -scheme Plugin -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO)
```

#### Test:
```bash
# Note: xcodebuild test requires a concrete device or simulator rather than generic destination
(cd Plugin && xcodebuild test -scheme Plugin -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO)
```

## Mode Switching

To switch to the plugin mode:
```bash
./scripts/configure_mode.sh plugin
```
This automatically invokes `./scripts/bootstrap_devbed.sh` to ensure `Plugin/Vendor/Flutter.xcframework` is bound before configuring the workspace.

## Sample Runner App (`Sample/`)

The Sample runner app (`Sample/Sources/SampleApp.swift` and `Sample/Sources/ContentView.swift`) provides a standalone iOS host application for plugin developers to iterate on SwiftUI views and execute domain use cases directly without needing a running Flutter engine or Flutter host process.

### Features
- **Direct SwiftUI View Mounting:** Mounts `MyPluginView()` directly into the SwiftUI hierarchy.
- **Background Task Registration:** Calls `DataSyncTask.register()` in `SampleApp.init` prior to scene creation, with `BGTaskSchedulerPermittedIdentifiers` configured in `Sample/Resources/Info.plist`.
- **Direct UseCase Execution:** Exercises `SyncDataUseCase` via `PluginContainer.shared.syncDataUseCase()`.

### Building & Running Sample
When in `plugin` mode:
```bash
# Generate workspace
tuist generate --no-open

# Build Sample app:
xcodebuild build -workspace PluginDevbed.xcworkspace -scheme Sample -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO

# Run Sample unit tests:
xcodebuild test -workspace PluginDevbed.xcworkspace -scheme Sample -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```

