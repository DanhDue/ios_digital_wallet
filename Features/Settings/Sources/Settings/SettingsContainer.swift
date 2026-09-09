import Core
import Factory
import Network
import Platform

private struct SilentLogger: Logger {
    func debug(_ message: String, file: String, function: String, line: Int) {}
    func info(_ message: String, file: String, function: String, line: Int) {}
    func error(_ message: String, file: String, function: String, line: Int) {}
}

public extension Container {
    var settingsRepository: Factory<any SettingsRepository> {
        self {
            MainActor.assumeIsolated {
                SettingsRepositoryImpl(
                    cache: UserDefaultsCacheStore(),
                    apiClient: nil,
                    logger: SilentLogger()
                )
            }
        }
    }

    var settingsThemeManager: Factory<AppThemeManager?> {
        self { nil }
    }

    var settingsLocalizationService: Factory<(any LocalizationService)?> {
        self { nil }
    }

    var settingsGetSettingsUseCase: Factory<GetSettingsUseCase> {
        self {
            MainActor.assumeIsolated {
                GetSettingsUseCase(repository: self.settingsRepository())
            }
        }
    }

    var settingsSaveSettingsUseCase: Factory<SaveSettingsUseCase> {
        self {
            MainActor.assumeIsolated {
                SaveSettingsUseCase(repository: self.settingsRepository())
            }
        }
    }

    var settingsGetAvailableLanguagesUseCase: Factory<GetAvailableLanguagesUseCase> {
        self {
            MainActor.assumeIsolated {
                GetAvailableLanguagesUseCase(repository: self.settingsRepository())
            }
        }
    }

    var settingsCheckSettingsCachedUseCase: Factory<CheckSettingsCachedUseCase> {
        self {
            MainActor.assumeIsolated {
                CheckSettingsCachedUseCase(repository: self.settingsRepository())
            }
        }
    }

    var settingsCheckLanguageCachedUseCase: Factory<CheckLanguageCachedUseCase> {
        self {
            MainActor.assumeIsolated {
                CheckLanguageCachedUseCase(repository: self.settingsRepository())
            }
        }
    }

    var settingsGetDynamicLocalizationUseCase: Factory<GetDynamicLocalizationUseCase> {
        self {
            MainActor.assumeIsolated {
                GetDynamicLocalizationUseCase(
                    repository: self.settingsRepository(),
                    localizationService: self.settingsLocalizationService() ?? NoOpLocalizationService()
                )
            }
        }
    }

    var settingsUpdateUserPreferencesUseCase: Factory<UpdateUserPreferencesUseCase> {
        self {
            MainActor.assumeIsolated {
                UpdateUserPreferencesUseCase(repository: self.settingsRepository())
            }
        }
    }

    var settingsChangeLanguage: Factory<ChangeLanguageUseCase> {
        self {
            MainActor.assumeIsolated {
                ChangeLanguageUseCase(
                    checkLanguageCachedUseCase: self.settingsCheckLanguageCachedUseCase(),
                    getDynamicLocalizationUseCase: self.settingsGetDynamicLocalizationUseCase(),
                    updateUserPreferencesUseCase: self.settingsUpdateUserPreferencesUseCase(),
                    localizationService: self.settingsLocalizationService() ?? NoOpLocalizationService()
                )
            }
        }
    }

    func registerSettingsRepository(
        cache: any CacheStore,
        apiClient: (any APIClient)? = nil,
        logger: any Logger
    ) {
        nonisolated(unsafe) let cache = cache
        nonisolated(unsafe) let logger = logger
        settingsRepository.register {
            MainActor.assumeIsolated {
                SettingsRepositoryImpl(
                    cache: cache,
                    apiClient: apiClient,
                    logger: logger
                )
            }
        }
    }
}
