# Template Modes Guide

The **iOS Super App Template** supports three distinct operational modes to match different team needs and product stages: **Enterprise**, **Lean**, and **Plugin**.

---

## The Three Modes

### 1. Enterprise Mode (Default)
- **Target Audience:** Production-grade banking/fintech super apps with multiple feature modules and strict architecture governance.
- **Active Units (10):**
  - Host Target: `App/`
  - Infra Packages: `Core`, `Framework`, `Network`, `AppUIKit`, `Platform`, `Shell`
  - Feature Packages: `Settings`, `Scanner`
  - Architecture Gate: `ArchTests/` (AST-based swift-syntax rules K1–K10)
- **Governance:** Enforces pure domain boundaries, dependency inversion, AppRoute scanning, deep link reachability (K10.2), and module boundary verification.

### 2. Lean Mode
- **Target Audience:** Fast-moving teams, prototypes, or single-feature MVPs who want Clean Architecture and MVI without the build overhead of heavy AST governance and auxiliary features.
- **Differences from Enterprise:**
  - `Scanner` feature is unwired from `Tuist/Package.swift`, `Project.swift`, `AppComposition.swift`, and `ShellView.swift`.
  - Shell presents 2 tabs (`Home`, `Settings`) instead of 3.
  - `ArchTests` are skipped for maximum build and test velocity.
- **Optional Pruning:** Passing `--prune` permanently removes the `Features/Scanner/` directory from disk (guarded by git clean checks).

### 3. Plugin Mode (Flutter Plugin DevBed)
- **Target Audience:** Native iOS Flutter plugin developers building clean architecture SPM packages with optional SwiftUI platform views.
- **Active Units:**
  - `Plugin/`: The native plugin package (`Sources/Plugin/`, `Tests/PluginTests/`).
  - `Sample/`: Standalone SwiftUI runner app (`SampleApp.swift`, `ContentView.swift`) mounting plugin views without a Flutter engine.
  - Host and enterprise infrastructure targets are excluded from the Tuist workspace (`PluginDevbed.xcworkspace`).
- **Engine Binding:** Automatically bootstrapped via `./scripts/bootstrap_devbed.sh` to symlink local Flutter SDK `Flutter.xcframework`.

---

## Mode Comparison Matrix

| Feature / Attribute | Enterprise | Lean | Plugin |
|---|:---:|:---:|:---:|
| **Default Workspace** | `ios_digital_wallet.xcworkspace` | `ios_digital_wallet.xcworkspace` | `PluginDevbed.xcworkspace` |
| **Active Modules** | 10 | 8 | 2 (`Plugin`, `Sample`) |
| **ArchTests (K1–K10)** | Enforced | Skipped | N/A |
| **Tabs in Shell** | 3 (`Home`, `Scanner`, `Settings`) | 2 (`Home`, `Settings`) | Standalone Runner |
| **Build Velocity** | Standard | Fast (~35% faster) | Minimal / Isolated |
| **Flutter Engine** | None | None | Symlinked via DevBed |
| **Tooling Support** | `ios_mvi_feature`, etc. | `ios_mvi_feature`, etc. | `ios_native_plugin`, `ios_add_native_ui` |

---

## Switching Modes

Use the unified `scripts/configure_mode.sh` script to switch modes:

```bash
# Switch to Enterprise mode (full template with Scanner and ArchTests)
./scripts/configure_mode.sh enterprise

# Switch to Lean mode (Scanner unwired, 2 tabs, fast builds)
./scripts/configure_mode.sh lean

# Switch to Lean mode and prune Scanner from disk (requires clean git status)
./scripts/configure_mode.sh lean --prune

# Switch to Plugin DevBed mode
./scripts/configure_mode.sh plugin
```

The script automatically regenerates Tuist manifests (`tuist generate --no-open`) and manages dependencies.

---

## Project Renaming with Modes

When creating a new project from the template, choose the initial mode directly via `rename_project.sh`:

```bash
# Rename and keep Enterprise mode (default)
./scripts/rename_project.sh MyWallet com.example.wallet --mode enterprise

# Rename and configure directly into Lean mode
./scripts/rename_project.sh MyWallet com.example.wallet --mode lean

# Rename and configure into Plugin DevBed mode
./scripts/rename_project.sh MyPlugin com.example.plugin --mode plugin
```

Use `--dry-run` to preview all changes without modifying files:
```bash
./scripts/rename_project.sh MyWallet com.example.wallet --mode lean --dry-run
```
