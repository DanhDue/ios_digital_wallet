import Core

/// The persistence and network seam for the Settings feature.
@MainActor
public protocol SettingsRepository {
    /// Loads the persisted settings. A missing or unreadable store resolves to
    /// `.success(SettingsEntity.default)` — never `.error`.
    func load() async -> DataState<SettingsEntity>

    /// Persists `entity` wholesale. Returns `.error` when the write fails.
    func save(_ entity: SettingsEntity) async -> DataState<Void>

    /// Retrieves available languages, falling back to local cache or bundled defaults.
    func getAvailableLanguages() async -> DataState<[AvailableLanguage]>

    /// Checks whether translations for `code` are cached locally.
    func isLanguageCached(_ code: String) async -> Bool

    /// Fetches translation overrides from remote API with optional ETag / sinceVersion.
    func getLocalizationOverrides(code: String, sinceVersion: String?, eTag: String?) async
        -> DataState<TranslationOverride?>

    /// Saves translations JSON, version, and ETag to local cache.
    func saveCachedTranslations(code: String, version: String, eTag: String?, translations: [String: String]) async
        -> DataState<Void>

    /// Synchronizes language and/or dark mode preferences to the server.
    func updateUserPreferences(language: String?, isDarkMode: Bool?) async -> DataState<Void>

    /// Checks whether settings have been persisted to local cache.
    func isSettingsCached() async -> Bool
}
