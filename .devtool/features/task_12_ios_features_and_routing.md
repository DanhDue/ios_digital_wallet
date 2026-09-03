---
id: "task_12_ios_features_and_routing"
status: "backlog"
priority: "high"
assignee: null
epic: "ios_super_app_template"
dueDate: null
created: "2026-09-02T00:00:00Z"
modified: "2026-09-02T00:00:00Z"
completedAt: null
labels: ["architecture", "feature", "routing"]
order: "a12"
---

# Task 12: Implement Settings (real) + Scanner (stub) + RouteProvider wiring

Epic: [ios_super_app_template](../epic/ios_super_app_template/ios_super_app_template.en.md)

## Requirement Analysis

Implement the two Feature modules and wire them to the Shell via `RouteProvider`. This task closes Phase 2 — the app becomes a working 3-tab template with real architecture.

**Settings Feature** (real — reference implementation for new developers):

```
iOSDigitalWallet/Features/Settings/
├── Data/
│   ├── Local/SettingsLocalDataSource.swift   ← reads/writes CacheStore
│   ├── Mapper/SettingsMapper.swift
│   └── Repository/SettingsRepositoryImpl.swift
├── Domain/
│   ├── Entity/SettingsEntity.swift           ← struct (theme, language, notifications)
│   ├── Repository/SettingsRepository.swift   ← protocol
│   └── UseCase/GetSettingsUseCase.swift
└── Presentation/
    ├── SettingsAction.swift                  ← toggleDarkMode, selectLanguage, etc.
    ├── SettingsState.swift
    ├── SettingsEvent.swift
    ├── SettingsViewModel.swift
    ├── SettingsView.swift                    ← real SwiftUI settings screen
    └── SettingsRouteProvider.swift
```

**Scanner Feature** (stub — empty scaffold from Mason brick, demonstrates pattern):

```
iOSDigitalWallet/Features/Scanner/
├── Data/ (empty stubs)
├── Domain/ (empty stubs)
└── Presentation/
    ├── ScannerAction.swift (empty)
    ├── ScannerState.swift (empty)
    ├── ScannerEvent.swift (empty)
    ├── ScannerViewModel.swift
    ├── ScannerView.swift                     ← placeholder: "Scanner coming soon"
    └── ScannerRouteProvider.swift
```

**RouteProvider wiring** — update `iOSDigitalWalletApp.swift`:
```swift
appRouter.register(SettingsRouteProvider(viewModel: SettingsViewModel(...)))
appRouter.register(ScannerRouteProvider())
```

Enable SwiftLint K4/K5 rules (data-internal + naming). Run `check_module_boundaries.sh` — expect clean (no cross-Feature imports).

## Relevant Files & Context Pointers

- `iOSDigitalWallet/Features/Settings/` — **NEW** (all files above)
- `iOSDigitalWallet/Features/Scanner/` — **NEW** (stub files)
- `iOSDigitalWallet/App/iOSDigitalWalletApp.swift` — update `RouteProvider` registration
- `quality/.swiftlint.yml` — enable K4/K5 rules from warning → error
- `scripts/check_module_boundaries.sh` — run and confirm clean
- Reference: `bloc_digital_wallet/packages/settings/` (Flutter — mirror structure)
- Reference: Android `features/settings/` (Android — mirror)
- Source spec §13 (template 3 features), §4.4 (Feature layer structure)

## Design Rationale

`Settings` is the reference implementation — it must be complete enough that a developer cloning the template can understand the full MVI + Clean Architecture pattern end-to-end. It intentionally uses `CacheStore` (local storage only, no network) to keep the template self-contained without requiring a backend.

`Scanner` is intentionally stubbed — it shows the Feature scaffold pattern without business logic. In real projects, this would be replaced with actual QR scanning logic.

`AppRoutes.SettingsRoute` and `AppRoutes.ScannerRoute` are already defined in `Platform` (Task 8). `SettingsRouteProvider` and `ScannerRouteProvider` implement the `RouteProvider` protocol from `Platform` — they do NOT know about each other.

## TDD Checklist

- [ ] **RED**: `SettingsViewModelTests` — `dispatch(.loadSettings)` updates state with loaded `SettingsEntity`; `dispatch(.toggleDarkMode)` flips `isDarkMode`; error state set on `GetSettingsUseCase` failure.
- [ ] **RED**: `GetSettingsUseCaseTests` — calls `SettingsRepository`; returns `DataState.success` on success; `DataState.error` on failure.
- [ ] **RED**: `SettingsRepositoryImplTests` — reads from `CacheStore`; returns default `SettingsEntity` when key missing.
- [ ] **GREEN**: Implement Settings full stack + Scanner stub.
- [ ] **WIRE**: Register `RouteProvider`s in `iOSDigitalWalletApp.swift`.
- [ ] **VERIFY**: `xcodebuild test` — all tests green. App runs: Settings tab shows real UI; Scanner tab shows stub. `check_module_boundaries.sh` exits 0.
- [ ] **VERIFY**: SwiftLint `no_public_in_data` (K4) catches `public` in `Settings/Data/` — introduce intentional violation, confirm CI fails, revert.

## Definition of Done

- App runs with 3 working tabs: HomeStub / Scanner stub / Settings real.
- Full MVI + Clean Architecture cycle verified in Settings (UseCase → Repository → DataState → ViewModel → View).
- `check_module_boundaries.sh` exits 0 (no cross-Feature imports).
- SwiftLint K4/K5 in error mode, zero violations.
- All unit tests green.

## Dependencies & Blockers

- Blocked by [Task 11](task_11_ios_shell.md) (Shell must exist to receive RouteProviders).
- Blocked by [Task 6](task_6_ios_network_package.md) (Settings uses `Core.CacheStore` — Task 6 for `Network` is optional here since Settings is local-only, but should be done).
- Blocks [Task 13](task_13_ios_mason_brick_complete.md) (brick `post_gen` references the wiring pattern established here).

## References & Rollback

- Source spec §13 (template features), §4.4 (feature layer).
- Rollback: delete `Features/Settings/` and `Features/Scanner/`; revert `iOSDigitalWalletApp.swift`. App reverts to Shell with empty tabs.
