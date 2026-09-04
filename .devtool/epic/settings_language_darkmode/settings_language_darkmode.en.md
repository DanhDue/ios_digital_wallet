---
epic: "settings_language_darkmode"
---

# Settings: Language Change & Dark Mode with Dynamic Sync

## 1. Meta Data
- **Status**: In Progress
- **Target Release**: v1.1.0
- **Source Spec**: [2026-09-05-settings-language-darkmode-design.md](2026-09-05-settings-language-darkmode-design.md)

## 2. Background
In the reference repository (`bloc_digital_wallet/.worktrees/flutter_super_app_template`), the application implements theme mode toggling and dynamic over-the-air (OTA) localization with remote synchronization (`GET /translations`, `GET /translations/{code}` with ETag 304, `PUT /users/me/preferences`). PR #34 resolved critical bugs including race conditions on rapid switching and un-cached language display failures.
This Epic brings complete feature parity to the iOS Super App template using Clean Architecture + MVI, conforming to the AST-based architecture gate (`ArchTests` K1–K9), and implementing a card-based Settings UI with a modal Language Bottom Sheet.

## 3. Goals & Non-Goals

### Goals
- **Dark Mode**: Provide `AppThemeManager` in `Packages/Platform` supporting `.system`, `.light`, and `.dark`, persisted to `CacheStore`, broadcast via `AppEventBus`, bound to `.preferredColorScheme` in `RootView`, and synced to backend via `PUT /api/v1/users/me/preferences`.
- **Dynamic Localization**: Provide `AppLocalizationManager` in `Packages/Platform` with two-tier lookup (dynamic JSON cache overrides $\to$ local `.xcstrings` $\to$ fallback key).
- **Remote Synchronization**: Integrate `GET /api/v1/translations`, `GET /api/v1/translations/{code}` (with ETag & 304 Not Modified), and `PUT /api/v1/users/me/preferences`.
- **PR #34 Parity**: Implement `ChangeLanguageUseCase` state machine with race condition protection via Task cancellation, state-aware optimistic UI (immediate for cached, loading for un-cached), and same-language redundant call elimination.
- **Card-based UI & Bottom Sheet**: Rebuild `SettingsView` to match the exact design in the reference screenshots (grouped cards, circular colored icon badges, section headers, standalone logout button, modal `LanguagePickerBottomSheet`).
- **Strict Quality**: 100% test coverage on new use cases, ViewModels, and repositories; 0 ArchTests violations.

### Non-Goals
- Full server-driven CMS theme engine (palette styling customization beyond Dark/Light/System).
- Non-settings screens localization (only Settings module and Shell/Platform infrastructure in this epic).

## 4. Architecture & Technical Design

### High-Level Architecture
```mermaid
graph TD
    App[App Host: AppComposition & RootView] --> Shell[Packages/Shell]
    App --> Settings[Features/Settings]
    App --> Platform[Packages/Platform]

    Shell --> Platform
    Shell --> AppUIKit[Packages/AppUIKit]

    Settings --> Platform
    Settings --> Network[Packages/Network: APIClient]
    Settings --> Framework[Packages/Framework: MviViewModel]
    Settings --> AppUIKit

    Platform --> Core[Packages/Core: CacheStore, Logger]
    Network --> Core
    Framework --> Core
    AppUIKit --> Core

    subgraph Platform Module
        ATM[AppThemeManager]
        ALM[AppLocalizationManager]
        AEB[AppEventBus]
    end

    subgraph Settings Feature
        VM[SettingsViewModel]
        CLUC[ChangeLanguageUseCase]
        REPO[SettingsRepositoryImpl]
        RDS[SettingsRemoteDataSource]
        LDS[SettingsLocalDataSource]
        VIEW[SettingsView + LanguageBottomSheet]
    end

    VIEW --> VM
    VM --> CLUC
    CLUC --> REPO
    CLUC --> ALM
    VM --> ATM
    REPO --> RDS
    REPO --> LDS
    RDS --> Network
    LDS --> Core
```

### Use Cases
```mermaid
flowchart TD
    User([User])

    subgraph Settings Operations
        UC1[Toggle Dark Mode]
        UC2[Select Language]
        UC3[Open Language Bottom Sheet]
        UC4[Load Settings & Languages]
    end

    User --> UC1
    User --> UC2
    User --> UC3
    User --> UC4

    UC1 -->|Updates| ATM[AppThemeManager]
    UC1 -->|Syncs| UPUC[UpdateUserPreferencesUseCase]
    
    UC2 -->|Executes| CLUC[ChangeLanguageUseCase]
    CLUC -->|If cached| ALM[AppLocalizationManager]
    CLUC -->|Fetch OTA| GDLU[GetDynamicLocalizationUseCase]
    CLUC -->|Sync preference| UPUC
    
    UC4 -->|Fetch| GALU[GetAvailableLanguagesUseCase]
```

### Sequence Diagram: Language Selection (PR #34 Parity)
```mermaid
sequenceDiagram
    actor User
    participant View as SettingsView
    participant Sheet as LanguagePickerBottomSheet
    participant VM as SettingsViewModel
    participant UC as ChangeLanguageUseCase
    participant ALM as AppLocalizationManager
    participant Repo as SettingsRepository
    participant API as Backend API

    User->>View: Taps "Language" row
    View->>VM: dispatch(.showLanguagePicker(true))
    VM-->>View: State(isLanguagePickerPresented: true)
    View->>Sheet: Present Bottom Sheet
    
    User->>Sheet: Taps language (e.g. "ja")
    Sheet->>VM: dispatch(.selectLanguage("ja"))
    Sheet-->>View: Dismiss Bottom Sheet
    VM->>VM: launch("changeLanguage") [Cancels prior in-flight task]
    VM->>UC: execute("ja")

    alt Same as current language
        UC-->>VM: return (No-op)
    else Language is Cached
        UC->>ALM: setLocale("ja") [Optimistic UI]
        UC-->>VM: state: cachedApplied
        UC->>Repo: getLocalizationOverrides("ja", sinceVersion, eTag)
        Repo->>API: GET /api/v1/translations/ja
        API-->>Repo: 200 OK / 304 Not Modified
        Repo->>ALM: applyDynamicTranslations(...)
        UC->>Repo: updateUserPreferences(language: "ja")
        Repo->>API: PUT /api/v1/users/me/preferences
    else Language NOT Cached
        VM->>VM: reduce { $0.isLoadingLanguage = true }
        UC->>Repo: getLocalizationOverrides("ja", nil, nil)
        Repo->>API: GET /api/v1/translations/ja
        alt Fetch Success
            API-->>Repo: 200 OK (Translations JSON)
            Repo->>Repo: Save to CacheStore
            Repo->>ALM: applyDynamicTranslations(...)
            UC->>ALM: setLocale("ja")
            VM->>VM: reduce { $0.isLoadingLanguage = false }
            UC->>Repo: updateUserPreferences(language: "ja")
            Repo->>API: PUT /api/v1/users/me/preferences
        else Fetch Failure
            API-->>Repo: Network Error
            VM->>VM: reduce { $0.isLoadingLanguage = false }
            VM->>VM: emit(.showError("Failed to download language"))
        end
    end
```

## 5. Rollout Strategy & Mitigation
- **Fallback Integrity**: In offline scenarios or if API calls fail, the application relies seamlessly on bundled local string catalogs (`.xcstrings`) and local cache.
- **Backwards Compatibility**: Existing `SettingsEntity` fields remain intact; new fields have robust defaults (`default_light` theme, `en` fallback).
- **Concurrency Safety**: Strict Structured Concurrency ensures no race conditions when requests are in flight.
- **Rollback Plan**: In case of regression, local cache can be invalidated or bypassed without impacting core wallet features.

## 6. Kanban Tasks Breakdown
- [Task 1: Platform Theme & Localization Infrastructure](../../features/task_1_platform_theme_localization_infrastructure.md)
- [Task 2: Settings Data Layer & API Client Integration](../../features/task_2_settings_data_layer_api_integration.md)
- [Task 3: Settings Domain Layer & PR #34 Orchestration Use Cases](../../features/task_3_settings_domain_orchestration_usecases.md)
- [Task 4: Settings Presentation Layer & MVI ViewModel](../../features/task_4_settings_presentation_mvi_viewmodel.md)
- [Task 5: Settings Card UI & Language Bottom Sheet](../../features/task_5_settings_card_ui_language_bottom_sheet.md)
- [Task 6: Root Composition & App-Wide Wiring Verification](../../features/task_6_root_composition_app_wiring.md)
