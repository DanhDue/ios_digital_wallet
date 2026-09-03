---
id: "task_11_ios_settings_feature"
status: "backlog"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-03T00:00:00Z"
modified: "2026-09-03T00:00:00Z"
completedAt: null
labels: ["architecture", "spm", "feature", "mvi"]
order: "a11"
---

# Task 11: `SettingsFeature` package (real, full MVI + Clean)

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

**Testing tier: A (behavioral).** The reference implementation — its scenario coverage is the bar every generated feature is measured against.

## Requirement Analysis

`Packages/Features/SettingsFeature/` — depends on `Platform`, `Framework`, `Network`, `AppUIKit`. The complete MVI + Clean example, local-only (no backend) via `Core.CacheStore`.

```
Sources/SettingsFeature/
├── Data/            (internal only — ArchTests K4)
│   ├── Local/SettingsLocalDataSource.swift    reads/writes CacheStore key "settings"
│   ├── Mapper/SettingsMapper.swift            SettingsDTO <-> SettingsEntity
│   ├── Model/SettingsDTO.swift                Codable
│   └── Repository/SettingsRepositoryImpl.swift  implements Domain.SettingsRepository
├── Domain/          (public, pure Swift — ArchTests K3)
│   ├── Entity/SettingsEntity.swift            struct { isDarkMode: Bool, language: String, notificationsEnabled: Bool }
│   ├── Repository/SettingsRepository.swift    protocol { func load() async -> DataState<SettingsEntity>; func save(_:) async -> DataState<Void> }
│   └── UseCase/GetSettingsUseCase.swift · SaveSettingsUseCase.swift
└── Presentation/
    ├── SettingsAction.swift   enum { case onAppear, toggleDarkMode, selectLanguage(String), toggleNotifications }
    ├── SettingsState.swift    struct { settings: SettingsEntity, isSaving: Bool }
    ├── SettingsEvent.swift    enum { case saveFailed(String) }
    ├── SettingsViewModel.swift  MviViewModel<SettingsState, SettingsAction, SettingsEvent>
    ├── SettingsView.swift       real SwiftUI form using AppUIKit components
    └── SettingsRouteProvider.swift  RouteProvider — canHandle(AppRoutes.SettingsRoot()); destination -> SettingsView(viewModel:)
```

ViewModel behavior:
- `.onAppear` → `startLoading()`, `launch("load") { GetSettingsUseCase → reduce(settings) → showContent() }`; on `.error` → `handleError`.
- `.toggleDarkMode` → optimistic `reduce { $0.settings.isDarkMode.toggle() }`, `reduce { $0.isSaving = true }`, `launch("save") { SaveSettingsUseCase }`; on failure → revert the toggle + `emit(.saveFailed(msg))`.
- `.selectLanguage` / `.toggleNotifications` — same optimistic-save shape (same `"save"` key ⇒ rapid changes coalesce to the last).

## Relevant Files & Context Pointers

- `Packages/Features/SettingsFeature/Package.swift`, `.../Sources/SettingsFeature/{Data,Domain,Presentation}/**`, `.../Tests/SettingsFeatureTests/**` — **NEW**
- `Tuist/Package.swift` — marker-region entry for `Packages/Features/SettingsFeature`
- Source Spec §4.4 (feature layer), §11 (template features), §5.5 (async-effect); Android `features/settings/` (structural mirror); Flutter `packages/settings/`

## Design Rationale

Local-only keeps the template self-contained (no server to run). Optimistic update + revert-on-failure is the canonical MVI interaction worth demonstrating. Reusing one `"save"` effect key means the async-effect helper (Task 5) coalesces a burst of toggles into a single persisted write — the race scenario a generated feature will also face.

**Applicable skills:** none specific.

### BDD Scenarios

```gherkin
# Happy path
Scenario: onAppear loads settings from cache and shows content
  Given CacheStore has a stored SettingsEntity(isDarkMode: true, ...)
  When dispatch(.onAppear)
  Then viewState sequence is [.loading, .content] and uiState.settings.isDarkMode == true

# Boundary / equivalence
Scenario: onAppear with no stored settings -> repository returns a default entity, content shown
Scenario: onAppear with corrupted cache bytes -> default entity + Logger.error, content shown (no crash)
Scenario: selectLanguage with an empty string is rejected (state unchanged)
Scenario: selectLanguage with a 2-letter and a long tag both persist

# State transitions
Scenario: toggleDarkMode flips isDarkMode and sets isSaving true then false on success
Scenario: toggleNotifications toggles and persists

# Emission order
Scenario: a successful toggle emits uiState [before, optimistic] and viewState stays .content throughout
Scenario: onAppear failure emits viewState [.loading, .error]

# Async / race
Scenario: three rapid toggleDarkMode within one runloop -> only one SaveSettingsUseCase call, final persisted value matches the last toggle
Scenario: onAppear dispatched twice quickly -> only one load effect runs (key "load")
Scenario: a save in flight when the view disappears (onClear) is cancelled; cache not partially written

# Failure injection
Scenario: SaveSettingsUseCase fails -> the optimistic toggle is reverted and event .saveFailed is emitted once
Scenario: GetSettingsUseCase fails -> viewState .error, retry via .onAppear recovers

# Sequence-diagram cross-check (Source Spec §4.3)
Scenario: SettingsRouteProvider.canHandle(AppRoutes.SettingsRoot()) is true and destination renders SettingsView

# Resource teardown
Scenario: onClear() cancels "load"/"save" effects; cancellables empty; no emission after
```

### TDD Tests

- `SettingsViewModelTests` — onAppear happy / default / corrupted (spy `Logger`); toggle success/failure (revert + `.saveFailed`); language validation matrix.
- `EmissionOrderTests` — `record()` sinks assert `viewState` and `uiState` sequences.
- `SaveCoalescingTests` — a `SpySaveSettingsUseCase` counts calls; 3 rapid toggles → 1 call, last value.
- `GetSettingsUseCaseTests` / `SaveSettingsUseCaseTests` — call repository, map to `DataState`.
- `SettingsRepositoryImplTests` — reads/writes `CacheStore` (in-memory fake); missing key → default; decode failure → default + log.
- `SettingsRouteProviderTests` — `canHandle` true only for `SettingsRoot`; `destination` builds a view.
- `SettingsMapperTests` — DTO↔Entity round-trip incl. edge values.
- `TeardownTests` — §9A category 7.

### RED → GREEN

- RED: coalescing test fails if each toggle spawns its own save; revert test fails if failure path doesn't restore state.
- GREEN: implement the stack; wire the `"save"` effect key.

## Definition of Done

- `swift test --package-path Packages/Features/SettingsFeature` green; every scenario has a passing test.
- ArchTests: no `public` in `Data/`; no UI import in `Domain/`; `Presentation` doesn't import `Data` symbols; naming rules pass.
- Full MVI cycle demonstrated (UseCase → Repository → DataState → ViewModel → View) with emission-order assertions.
- Coverage ≥ 80%. SwiftLint/SwiftFormat clean. `Package.swift` deps == `[Platform, Framework, Network, AppUIKit]`.

## Dependencies & Blockers

- Blocked by [Task 5](task_5_ios_framework_package.md), [Task 6](task_6_ios_network_package.md), [Task 7](task_7_ios_appuikit_package.md), [Task 8](task_8_ios_platform_package.md), [Task 9](task_9_ios_rewire_arch_doc.md).
- Blocks [Task 12](task_12_ios_scanner_and_composition.md) (App registers `SettingsRouteProvider`) and [Task 13](task_13_ios_mason_bricks.md) (bricks reference this as the worked example).

## References & Rollback

- Source Spec §4.4, §11, §5.5, §4.3.
- Rollback: remove `Packages/Features/SettingsFeature/` + marker line; drop its provider registration.
