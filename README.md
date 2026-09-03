# iOS Super App Template

A governed, multi-package **native iOS** template: Clean Architecture + MVI +
Feature-First, a package-per-module graph (the compiler enforces boundaries), a
thin host `App` + a feature-blind `Shell`, an AST-based architecture gate
(`ArchTests`, swift-syntax), and GitHub Actions CI. Clone it, run one script,
start building.

> Status: **Phase 0 skeleton.** The `App` target builds and runs a placeholder
> screen. Infrastructure packages, the `Shell`, the sample features, the Mason
> bricks, and the real `ArchTests` rules land in Phases 1–3.

## Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| **Xcode** | 16 or newer | Swift 6 toolchain, iOS 16+ SDK, Simulator |
| **[mise](https://mise.jdx.dev)** | latest | pins & installs the tools below from `.mise.toml` |
| **[Tuist](https://tuist.dev)** | `4.206.0` | generates the Xcode project/workspace from the manifests |
| **[SwiftLint](https://github.com/realm/SwiftLint)** | `0.65.1` | style + a thin defence-in-depth layer (real rules live in `ArchTests`) |
| **[SwiftFormat](https://github.com/nicklockwood/SwiftFormat)** | `0.63.0` | formatter, kept in step with SwiftLint |
| **[Mason](https://github.com/felangel/mason)** | latest (`mason_cli`) | one-command feature scaffolding (bricks arrive in Phase 3) |
| **swift-syntax** | **`602.0.0`** (exact) | AST parser used by `ArchTests`; version-locked to the Swift 6.3.3 toolchain — see `ArchTests/Package.swift` |

`.mise.toml` pins Tuist / SwiftLint / SwiftFormat; `mise install` fetches those
exact versions. Xcode and Mason are installed separately.

## Quick start

```bash
git clone <this-repo> && cd iOSDigitalWallet
mise install                 # tuist, swiftlint, swiftformat at the pinned versions
tuist install                # resolve SPM dependencies (no-op until Phase 1)
tuist generate               # writes iOSDigitalWallet.xcworkspace (git-ignored)
open iOSDigitalWallet.xcworkspace
```

Build & run the `iOSDigitalWallet` scheme (iOS 16+ Simulator).

Prefer the command line:

```bash
tuist generate --no-open
xcodebuild build -workspace iOSDigitalWallet.xcworkspace \
  -scheme iOSDigitalWallet \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  CODE_SIGNING_ALLOWED=NO
```

### Add a feature (Phase 3+)

```bash
mason make ios_mvi_feature --name Payments
```

Generates a full `Packages/Features/PaymentsFeature` package (Data / Domain /
Presentation + `PaymentsRouteProvider`), edits the Tuist manifests inside their
marker regions, and re-runs `tuist generate`. It never touches another feature.

## Project layout

```text
iOSDigitalWallet/
├── App/                     # Thin host: @main, DI wiring, RouteProvider registration, lifecycle events
│   ├── Sources/             # iOSDigitalWalletApp.swift, RootView.swift, Composition/ (Phase 1)
│   └── Resources/           # Assets.xcassets, Info.plist
├── Packages/                # One local SPM package per module (Phase 1) — compiler-enforced boundaries
│   ├── Core/                # stdlib-only dependency floor
│   ├── Framework/           # MviViewModel / MvvmViewModel / ViewState        (→ Core)
│   ├── Network/             # APIClient, interceptors, Environment            (→ Core)
│   ├── AppUIKit/            # design system + components                      (→ Core)
│   ├── Platform/            # AppRoute(s), RouteProvider, AppRouter, AppEventBus (→ Core)
│   ├── Shell/               # tab layout + per-tab NavigationStack; feature-blind (→ Platform, Framework, AppUIKit)
│   └── Features/            # SettingsFeature (real), ScannerFeature (stub) — never import each other
├── ArchTests/               # Standalone swift-syntax architecture gate — NEVER linked into the app
│   ├── Sources/ArchTestSupport/  # RepoRoot, SyntaxScanner, Baseline, BoundaryWhitelist
│   ├── Tests/ArchTests/          # ScopeSanityTest + support unit tests (K1–K9 land in Task 9/12)
│   └── baseline.txt              # accepted-violation ledger — empty (greenfield)
├── quality/                 # .swiftlint.yml, .swiftformat (one config for the whole repo; run from root)
├── scripts/                 # check_module_boundaries.sh, module_boundary_whitelist.txt, rename_project.sh
├── Tuist/                   # Package.swift (SPM graph for Tuist) + ProjectDescriptionHelpers/Module.swift
├── Tuist.swift · Project.swift · Workspace.swift   # Tuist manifests = source of truth
├── docs/architecture/ARCHITECTURE.md   # authoritative architecture guide (written in Task 9)
└── .github/workflows/ci.yml # quality · packages · app  (macos-15, no signing secrets)
```

`*.xcodeproj` / `*.xcworkspace` and `**/.build/` are **generated build artefacts**
— they are git-ignored and must never be committed. `tuist generate` recreates
them from the manifests.

## Testing tiers

Every task in this repo is graded against the three-tier standard in
**Source Spec §9A** (`.devtool/epic/ios_super_app_template/…-design.md`):

| Tier | Scope | Bar |
|---|---|---|
| **A** | Business logic (UseCases, reducers, ViewModels) | BDD scenarios → XCTest, RED-before-GREEN, BVA + equivalence partitioning |
| **B** | Tooling / config (this task, CI, Mason bricks) | verification-scenario table, executed and pasted |
| **C** | Wiring / composition (DI graph, navigation) | one integration test that exercises the path end to end |

## CI

`.github/workflows/ci.yml` runs on every pull request and on pushes to
`develop` / `main`, on `macos-15`, with **no signing secrets**:

- **quality** — `mise install` → `swiftlint --strict` → `swiftformat --lint` →
  `check_module_boundaries.sh` → `swift test --package-path ArchTests`.
- **packages** — `swift test` over every `Packages/*` / `Packages/Features/*`
  (no-op until Phase 1).
- **app** — `needs: [quality, packages]` → `tuist generate --no-open` →
  `xcodebuild test` (falls back to `xcodebuild build` until test targets exist).
