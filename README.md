# iOS Super App Template

A governed, **native-iOS** application template: **Clean Architecture + MVI +
Feature-First**, one local SPM package per module (the compiler enforces the
boundaries), a thin host `App` plus a feature-blind `Shell`, an AST-based
architecture gate (`ArchTests`, swift-syntax), Mason scaffolding for new
features, and GitHub Actions CI. Clone it, run one script, start building.

The project graph is declared with **Tuist** and generated on demand —
`iOSDigitalWallet.xcodeproj` / `iOSDigitalWallet.xcworkspace` are build
artefacts, git-ignored, and never committed. `tuist generate` recreates them
from the manifests.

## Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| **Xcode** | 16 or newer | Swift 6 toolchain, iOS 16+ SDK, Simulator |
| **[mise](https://mise.jdx.dev)** | latest | installs the pinned tools below from `.mise.toml` / `.tuist-version` |
| **[Tuist](https://tuist.dev)** | `4.206.0` | generates the Xcode project / workspace from the manifests |
| **[SwiftLint](https://github.com/realm/SwiftLint)** | `0.65.1` | style + a thin defence-in-depth layer (real rules live in `ArchTests`) |
| **[SwiftFormat](https://github.com/nicklockwood/SwiftFormat)** | `0.63.0` | formatter, kept in step with SwiftLint |
| **[Mason](https://docs.brickhub.dev)** | latest (`mason_cli`) | one-command feature scaffolding (`bricks/`) |
| **swift-syntax** | `602.0.0` (exact) | AST parser used by `ArchTests`; version-locked to the Swift 6 toolchain — see `ArchTests/Package.swift` |

`mise install` fetches the exact Tuist / SwiftLint / SwiftFormat versions; CI
does the same. Xcode and Mason are installed separately (`brew install mason`).

## Quick start

```bash
git clone <this-repo> my-app && cd my-app
mise install                                     # pinned tuist / swiftlint / swiftformat

./scripts/rename_project.sh MyApp com.my.app     # THE entry point after clone — see below
git add -A && git commit -m "Rename project to MyApp"

tuist install                                    # resolve the SPM graph
tuist generate                                   # writes MyApp.xcworkspace (git-ignored)
open MyApp.xcworkspace                           # build & run the MyApp scheme (iOS 16+ Simulator)
```

Command-line build instead of Xcode:

```bash
tuist generate --no-open
xcodebuild build -workspace MyApp.xcworkspace -scheme MyApp \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

### `scripts/rename_project.sh <NewAppName> <new.bundle.id>`

The **single entry point after cloning**. It rewrites the shipped project name
and bundle id to yours across the Tuist manifests, the `App` sources / tests /
`Info.plist`, `ConsoleLogger`'s subsystem, the root docs and CI; then `git mv`s
the `@main` entry-point file to `<NewAppName>App.swift` and verifies with
`tuist generate` + `xcodebuild build`.

- Requires a **clean git tree** (commit or stash first).
- `<NewAppName>` must be a valid Swift identifier: `^[A-Za-z][A-Za-z0-9]*$`.
- `<new.bundle.id>` must be reverse-DNS: `^[a-z0-9]+(\.[a-z0-9]+)+$`.
- The **infra / Shell / `*Feature` package names stay fixed** (`Core`,
  `Framework`, `Network`, `AppUIKit`, `Platform`, `Shell`, `SettingsFeature`,
  `ScannerFeature`) — a vendor namespace, so Mason output is stable across
  every renamed project.
- Idempotent: re-running on an already-renamed tree is a clean no-op.
- `RENAME_SKIP_VERIFY=1 ./scripts/rename_project.sh …` skips the build step for
  a dry run.

### Add a feature

```bash
mason get                                        # once, to resolve bricks/
mason make ios_mvi_feature --name Payments        # add --has_network true for a remote data source
```

`ios_mvi_feature` scaffolds a full `Packages/Features/PaymentsFeature` package
(`Data` / `Domain` / `Presentation` + `PaymentsViewModel` + `PaymentsRouteProvider`
+ tests), edits the Tuist manifests **inside their `// tuist:*:begin/end` marker
regions**, re-runs `tuist generate`, and prints a manual checklist (register the
`RouteProvider` in `App/Sources/Composition/AppComposition.swift`, promote a
cross-feature route, run the tests). It never touches another feature.

Other bricks: `ios_mvi_subfeature --feature X --name Y` (adds a screen to an
existing feature), `ios_remove_feature --name X` (exact inverse of
`ios_mvi_feature`), `ios_remove_subfeature --feature X --name Y`.

## Project layout

```text
.
├── App/                     # Thin host: @main, DI wiring, RouteProvider registration, lifecycle
│   ├── Sources/             # <App>App.swift, RootView.swift, Composition/ (ConsoleLogger, AppComposition, …)
│   ├── Tests/               # AppTests — Tier C composition-root / navigation integration tests
│   └── Resources/           # Assets.xcassets (placeholder AppIcon + AccentColor), Info.plist
├── Packages/                # One local SPM package per module — compiler-enforced boundaries
│   ├── Core/                # stdlib-only dependency floor: primitives, protocols, extensions
│   ├── Framework/           # MviViewModel / MvvmViewModel / ViewState          (→ Core)
│   ├── Network/             # APIClient, interceptors, AppEnvironment (placeholder URLs) (→ Core)
│   ├── AppUIKit/            # design system + components                        (→ Core)
│   ├── Platform/            # AppRoute(s), RouteProvider, AppRouter, AppEventBus (→ Core)
│   ├── Shell/               # tab layout + per-tab NavigationStack; feature-blind; HomeStubView
│   │                        #                                                   (→ Platform, Framework, AppUIKit)
│   └── Features/            # SettingsFeature (real reference), ScannerFeature (stub) — never import each other
├── ArchTests/               # Standalone swift-syntax architecture gate (K1–K9) — NEVER linked into the app
│   ├── Sources/ArchTestSupport/  # RepoRoot, SyntaxScanner, Baseline, BoundaryWhitelist
│   ├── Tests/ArchTests/          # the K1–K9 rule bodies + support unit tests (31 tests)
│   └── baseline.txt              # accepted-violation ledger — empty (greenfield)
├── bricks/                  # Mason bricks: ios_mvi_feature / ios_mvi_subfeature / ios_remove_{feature,subfeature}
├── quality/                 # .swiftlint.yml, .swiftformat — one config for the whole repo; run from root
├── scripts/                 # rename_project.sh, check_module_boundaries.sh, module_boundary_whitelist.txt
├── Tuist/                   # Package.swift (SPM graph Tuist reads) + ProjectDescriptionHelpers/Module.swift
├── Tuist.swift · Project.swift · Workspace.swift   # Tuist manifests = source of truth
├── docs/architecture/ARCHITECTURE.md   # the authoritative architecture guide
├── ARCHITECTURE.md · AGENTS.md · PROJECT_RULES.md  # thin root pointers / working rules
└── .github/workflows/ci.yml # quality · packages · app  (macos-15, no signing secrets)
```

`*.xcodeproj` / `*.xcworkspace` and every `**/.build/` are **generated** — they
are git-ignored and must never be committed.

## Architecture

Read **[`docs/architecture/ARCHITECTURE.md`](docs/architecture/ARCHITECTURE.md)**
— the authoritative guide: the `Presentation → Domain ← Data` layer rules, the
MVI contract (`Action` / `State` / `Event`, `dispatch → onAction → reduce`, the
`launch(key:)` async-effect), the module map and 4-tier dependency graph,
cross-feature communication through `Platform`, the iOS stack rationale, worked
code examples, and the `ArchTests` **K1–K9** governance table.

## Testing tiers

Every task in this repo is graded against a three-tier standard — see
`docs/architecture/ARCHITECTURE.md` §VI (Governance) and the Source Spec §9A
(`.devtool/epic/ios_super_app_template/…-design.md`):

| Tier | Scope | Bar |
|---|---|---|
| **A** | Business logic (`Core`, `Framework`, `Network`, `Platform`, `Shell`, `*Feature`) | Gherkin BDD scenarios → XCTest 1:1, RED-before-GREEN, BVA + equivalence partitioning |
| **B** | Tooling / scripts / config (`rename_project.sh`, CI, the Mason bricks, boundary guard) | a Verification-Scenario table, executed and pasted |
| **C** | Wiring / composition (DI graph, navigation, `ArchTests` rule activation) | end-to-end scenarios exercising the path on a simulator |

## CI

`.github/workflows/ci.yml` runs on every pull request and on pushes to
`develop` / `main`, on `macos-15`, with **no signing secrets**:

- **quality** — `mise install` → `swiftlint --strict` → `swiftformat --lint` →
  `check_module_boundaries.sh` → `swift test --package-path ArchTests`.
- **packages** — `swift test` over every `Packages/*` and `Packages/Features/*`.
- **app** — `needs: [quality, packages]` → `tuist install` →
  `tuist generate --no-open` → `xcodebuild test` (falls back to
  `xcodebuild build`).
