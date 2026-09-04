import Core

/// The reader / writer of the settings cache slots (Source Spec §4.4).
///
/// `internal` (ArchTests K4).
struct SettingsLocalDataSource {
    /// The cache key the whole feature agrees on.
    static let storageKey = "settings"
    static let availableLanguagesKey = "settings_available_languages"
    static func translationKey(for code: String) -> String {
        "translations_\(code)"
    }

    static func versionKey(for code: String) -> String {
        "translations_version_\(code)"
    }

    static func eTagKey(for code: String) -> String {
        "translations_etag_\(code)"
    }

    private let cache: any CacheStore

    init(cache: any CacheStore) {
        self.cache = cache
    }

    /// The stored DTO, or `nil` when absent or unreadable.
    func read() -> SettingsDTO? {
        cache.get(SettingsDTO.self, key: Self.storageKey)
    }

    func write(_ dto: SettingsDTO) {
        cache.set(dto, key: Self.storageKey)
    }

    func clear() {
        cache.remove(key: Self.storageKey)
    }

    func hasCachedSettings() -> Bool {
        read() != nil
    }

    // MARK: - Available Languages

    func readAvailableLanguages() -> [AvailableLanguageDTO]? {
        cache.get([AvailableLanguageDTO].self, key: Self.availableLanguagesKey)
    }

    func writeAvailableLanguages(_ languages: [AvailableLanguageDTO]) {
        cache.set(languages, key: Self.availableLanguagesKey)
    }

    // MARK: - Translations Cache

    func isLanguageCached(_ code: String) -> Bool {
        cache.get([String: String].self, key: Self.translationKey(for: code)) != nil
    }

    func readTranslations(for code: String) -> [String: String]? {
        cache.get([String: String].self, key: Self.translationKey(for: code))
    }

    func writeTranslations(_ translations: [String: String], for code: String) {
        cache.set(translations, key: Self.translationKey(for: code))
    }

    func readVersion(for code: String) -> String? {
        cache.get(String.self, key: Self.versionKey(for: code))
    }

    func writeVersion(_ version: String, for code: String) {
        cache.set(version, key: Self.versionKey(for: code))
    }

    func readETag(for code: String) -> String? {
        cache.get(String.self, key: Self.eTagKey(for: code))
    }

    func writeETag(_ eTag: String, for code: String) {
        cache.set(eTag, key: Self.eTagKey(for: code))
    }
}
