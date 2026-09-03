---
id: "task_14_scanner_dynamic_feature"
status: "done"
priority: "high"
assignee: null
epic: "android_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-03T03:30:25.382Z"
completedAt: "2026-09-03T03:30:25.382Z"
labels: ["architecture", "feature", "dfm"]
order: "a1l"
---
# Task 14: Convert `scanner` → on-demand Dynamic Feature Module

Epic: [android_super_app_template](../epic/android_super_app_template/android_super_app_template.en.md)

## Requirement Analysis

The template's one worked on-demand example (Goal G10). Convert `:features:scanner` to `com.android.dynamic-feature`, installed on first tab tap:

1. **Gradle**: `scanner/build.gradle.kts` applies `com.android.dynamic-feature` (new convention `commons.android-feature-dynamic` — feature convention minus `android-library`, plus dynamic-feature); `implementation(project(":app"))` (DFM inverts the dependency); `:app`'s `android { dynamicFeatures += ":features:scanner" }`.
2. **`:app` base**: add the Play `feature-delivery` dependency (`com.google.android.play:feature-delivery` / `feature-delivery-ktx`); `SplitCompat` enabled in the base `Application` (`SplitCompatApplication` or manual `SplitCompat.install`).
3. **`FeatureInstaller` impl** in `:app`: wraps `SplitInstallManager` — `ensureInstalled("scanner", onReady)` checks `splitInstallManager.installedModules`, otherwise `startInstall(SplitInstallRequest)`, listens for `SplitInstallSessionStatus` (DOWNLOADING/INSTALLING/INSTALLED), calls `SplitCompat.install(context)` on completion, then `onReady()`. Surface progress/failure to `:shell` for a loading UI.
4. **`ScannerFeatureEntry : FeatureEntry`** in the scanner module + `src/main/resources/META-INF/services/com.danhdue.platform.FeatureEntry`. After install, `:shell` (or `:app`) does `ServiceLoader.load(FeatureEntry::class.java)` and merges the returned `EntryProviderInstaller` into the set feeding `NavDisplay`. `ScannerRoute` lives in `:platform.AppRoutes`.
5. **Manifest**: `<dist:module dist:instant="false" dist:onDemand="true"><dist:fusing dist:include="false" /><dist:delivery><dist:on-demand /></dist:delivery></dist:module>`.
6. **`:shell`** scanner tab: `FeatureInstaller.ensureInstalled("scanner") { Navigator.navigateTo(AppRoutes.ScannerRoute) }`; show a progress indicator while installing; handle failure (retry).
7. **Konsist K8**: read `:app`'s `android.dynamicFeatures` list; exempt exactly those modules from the "feature must not import `com.danhdue.androiddigitalwallet.*`" rule. No hand-maintained whitelist.
8. **Brick**: finalise the `--delivery on-demand` path in `mvi_feature` (Task 4) against this real implementation — the generated files should match what this task produces by hand.

## Relevant Files & Context Pointers

- `features/scanner/build.gradle.kts`, `features/scanner/src/main/AndroidManifest.xml`
- `features/scanner/src/main/kotlin/com/danhdue/scanner/{ScannerFeatureEntry.kt, presentation/**}`
- `features/scanner/src/main/resources/META-INF/services/com.danhdue.platform.FeatureEntry`
- `app/build.gradle.kts` (`android.dynamicFeatures`, Play feature-delivery dep), `app/src/main/kotlin/com/danhdue/androiddigitalwallet/{Application, FeatureInstallerImpl}.kt`
- `platform/src/main/kotlin/com/danhdue/platform/{FeatureEntry,FeatureInstaller,AppRoutes}.kt`
- `shell/src/main/kotlin/com/danhdue/shell/**` — scanner tab install branch + progress UI
- `buildSrc/src/main/kotlin/commons/` — new `android-feature-dynamic.gradle.kts`
- `konsist-test/src/test/kotlin/com/danhdue/konsist/HostRulesTest.kt` — K8 dynamicFeatures-aware exemption
- `bricks/mvi_feature/hooks/post_gen.dart` — align on-demand branch
- `.github/workflows/ci.yml` — ensure `bundleDebug` builds the split (fuller check in Task 16)

## Design Rationale

Hilt `@IntoSet` multibinding does not cross the dynamic-feature split at compile time (`:app`'s component can't see the DFM's `@Module`). `FeatureEntry` + `ServiceLoader` is the minimal runtime bridge — used **only** for DFM features; every install-time feature keeps plain Hilt multibinding (source spec §4.4). `scanner` is the natural on-demand candidate (camera/QR — not every user needs it) and is already empty, so the conversion carries no business-logic risk.

Applicable skills: `@quality_check` after; consult `docs/architecture/ARCHITECTURE.md` (written in Task 9) for the nav-mechanism contract.

## TDD Checklist

- [ ] **RED**: `FeatureInstallerImplTest` (Robolectric + fake `SplitInstallManager`) — already-installed module invokes `onReady` immediately; not-installed triggers `startInstall` then `onReady` on INSTALLED; failure surfaces an error state.
- [ ] **RED**: `ScannerFeatureEntryTest` — `ServiceLoader.load` finds `ScannerFeatureEntry`; its `installer()` registers `ScannerRoute`.
- [ ] **RED**: Konsist K8 test — a non-DFM feature importing `com.danhdue.androiddigitalwallet.*` fails; `scanner` (in `dynamicFeatures`) does not.
- [ ] **GREEN**: implement the Gradle plugin, manifest, `FeatureInstaller` impl, `FeatureEntry`, shell branch, K8 logic.
- [ ] **REFACTOR**: align the Mason `on-demand` template; extract install-UI into `:ui_kit` if reusable.
- [ ] Manual: `bundleDebug` → bundletool `--local-testing` install → launch → tap Scanner → split downloads → screen opens; publish a `ScanCompleted` event, shell reacts.

## Definition of Done

- `:features:scanner` is a `com.android.dynamic-feature`; base APK does not contain it; `bundleDebug` produces the split.
- First Scanner-tab tap installs then navigates; subsequent taps are instant.
- Konsist K8 exempts `scanner` via `dynamicFeatures`, blocks every other feature.
- `mvi_feature --delivery on-demand` generates a matching structure.
- All tests green; `assembleDebug` + `bundleDebug` green.

## Dependencies & Blockers

- Blocked by [Task 13](task_13_strip_domain_to_template.md), [Task 1](task_1_platform_module.md), [Task 10](task_10_extract_shell_thin_app.md).
- Related: [Task 4](task_4_mason_brick_wiring.md) (brick), [Task 16](task_16_e2e_acceptance_validation.md) (CI + acceptance).

## References & Rollback

- Source spec §4.4, §8, §9 Phase 3.
- Android Play Feature Delivery / `SplitInstallManager` docs; bundletool `--local-testing`.
- Rollback: revert the module to `com.android.library` + install-time wiring (Hilt `@IntoSet`); remove `dynamicFeatures` entry and the `FeatureInstaller` impl. The `FeatureEntry`/`FeatureInstaller` interfaces can stay unused in `:platform`.