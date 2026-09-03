---
id: "task_10_extract_shell_thin_app"
status: "done"
priority: "high"
assignee: null
epic: "android_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-03T03:30:13.218Z"
completedAt: "2026-09-03T03:30:13.218Z"
labels: ["architecture", "refactor", "shell"]
order: "a5"
---
# Task 10: Extract `:shell`, thin `:app`, dissolve `features/home`

Epic: [android_super_app_template](../epic/android_super_app_template/android_super_app_template.en.md)

## Requirement Analysis

Pure-container Host (Goal G3). Today `features/home` depends directly on `myWallet`, `transactions`, `scanner`, `trends`, `settings` (see `features/home/build.gradle.kts`) — it *is* the Shell, misplaced in a feature module.

- **Create `:shell`** (`com.danhdue.shell`, Host-only): move `features/home/src/main/java/com/danhdue/home/presentation/**` (the tab-shell UI — `HomeScreen`/`HomeRoute`/`HomeViewModel`/bottom nav) into `:shell` as `ShellScreen`/`ShellRoute`/`ShellViewModel`. `:shell` builds the `NavDisplay` from the Hilt `Set<EntryProviderInstaller>` and provides one `NestedNavigator` per tab (`LocalNestedNavigator`). `:shell` may depend on multiple `:features:*` (Konsist K6 grants this to `:app`/`:shell` only).
- **`features/home` data/domain** (`HomeDto`/`HomeRepository`/`GetHomeDataUseCase`) — this is a real feature slice, not shell. Reduce to a **home stub page** inside `:shell` (`tabs/HomeStubPage.kt`), matching the Flutter template's `lib/shell/tabs/home_stub_page.dart`. Delete the `:features:home` module.
- **Thin `:app`**: `app/src/main/kotlin/com/danhdue/androiddigitalwallet/` keeps only `Application`, the entry `Activity` hosting `NavDisplay`, DI aggregation (`di/`), and the (later) `FeatureInstaller` impl. No feature composition logic beyond `implementation(project(":shell"))` + `implementation(project(":features:x"))` for each install-time feature.
- Whitelist: the 5 `home→*` edges are removed — 4 disappear (home gone), `home→settings` becomes `:shell→settings` which is legal (Host privilege). `konsist_boundary_whitelist.txt` should end this task with **0** entries from `home`.

Preserve the navigation3 mechanism exactly — `:shell` consumes `LocalEntryProviderInstallers` / `Navigator` / `NestedNavigator`, it does not reimplement them.

## Relevant Files & Context Pointers

- `features/home/src/main/java/com/danhdue/home/presentation/**` → `:shell`
- `features/home/src/main/java/com/danhdue/home/{data,domain}/**` → discard (stub replaces it)
- `features/home/build.gradle.kts` (the 5 cross-feature deps to eliminate)
- `app/src/main/kotlin/com/danhdue/androiddigitalwallet/{di,ui}/**`, `app/build.gradle.kts`
- `libraries/framework` → now `:framework`: `navigation/{Navigator,NestedNavigator,EntryProviderInstaller}.kt`, `navigation/FlipperBackstackObserver.kt` (`ObserveBackstackForFlipper` used by the shell)
- `settings.gradle.kts` — remove `:features:home`, add `:shell`
- `scripts/konsist_boundary_whitelist.txt`
- Reference: `bloc_digital_wallet/.worktrees/flutter_super_app_template/lib/shell/**` (`shell_bloc.dart`, `shell_page.dart`, `tabs/home_stub_page.dart`, `widgets/custom_bottom_nav_bar.dart`)

## Design Rationale

Exactly the Flutter epic's Phase 2 "relocate Shell out of `home`" move, applied to Android. The shell's tab state is its own `ShellViewModel` (MVI) — state isolation (Goal G5) applies to the Host too. The `// TODO: notify tab` that exists in the Flutter shell has its Android analogue closed in Task 11 via `AppEventBus`.

Applicable skill: `@quality_check` after.

## TDD Checklist

- [ ] **RED**: `ShellViewModelTest` — tab-change action updates selected-tab state; re-tapping the active tab emits a "pop to root" event for that tab.
- [ ] **GREEN**: move + rename shell code into `:shell`; wire `NavDisplay` from the Hilt installer set; implement the home stub page.
- [ ] **REFACTOR**: delete `:features:home`; remove dead cross-feature deps; clean whitelist.
- [ ] Run all feature tests + new shell tests; manual smoke: every tab renders, nested nav per tab, config-change survival, back-stack behavior unchanged.

## Definition of Done

- `:shell` module exists; `:features:home` deleted.
- `:app` contains no feature composition beyond module wiring.
- `konsist_boundary_whitelist.txt` has zero `home→*` entries.
- Nested navigation + tab switching verified by smoke test; all tests green; `assembleDebug` green.

## Dependencies & Blockers

- Blocked by [Task 9](task_9_rewire_and_architecture_doc.md).
- Blocks [Task 11](task_11_platform_routes_settings_pilot.md).

## References & Rollback

- Source spec §4.1, §9 Phase 2.
- Rollback: revert the PR; `:features:home` returns. (Larger blast radius than Phase 1 tasks — land as a single reviewed PR.)