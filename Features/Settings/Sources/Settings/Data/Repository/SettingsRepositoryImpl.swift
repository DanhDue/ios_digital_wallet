import Core
import Network

/// The one `SettingsRepository` conformer (Source Spec §4.4). `internal`, a
/// `struct`, reached only through the Domain protocol (ArchTests K4 / K5).
///
/// `load()` never surfaces `.error`: a missing or corrupt cache degrades to
/// `SettingsEntity.default` and is logged once at `.info` (the `.error` for a
/// genuine decode failure is emitted by the `CacheStore` itself). `save()`
/// forwards to the cache write, which is synchronous and total.
struct SettingsRepositoryImpl: SettingsRepository {
    private let local: SettingsLocalDataSource
    private let remote: SettingsRemoteDataSource?
    private let logger: any Logger

    init(
        cache: any CacheStore,
        apiClient: (any APIClient)? = nil,
        logger: any Logger
    ) {
        local = SettingsLocalDataSource(cache: cache)
        if let apiClient {
            remote = SettingsRemoteDataSource(client: apiClient)
        } else {
            remote = nil
        }
        self.logger = logger
    }

    func load() async -> DataState<SettingsEntity> {
        var entity: SettingsEntity
        if let dto = local.read() {
            entity = SettingsMapper.toEntity(dto)
        } else {
            logger.info(
                "[SettingsRepository] no readable persisted settings — using SettingsEntity.default",
                file: #file,
                function: #function,
                line: #line
            )
            entity = .default
        }
        if let cachedLanguages = local.readAvailableLanguages(), !cachedLanguages.isEmpty {
            entity.availableLanguages = cachedLanguages.map(SettingsMapper.toLanguageEntity)
        }
        return .success(entity)
    }

    func save(_ entity: SettingsEntity) async -> DataState<Void> {
        local.write(SettingsMapper.toDTO(entity))
        return .success(())
    }

    func getAvailableLanguages() async -> DataState<[AvailableLanguage]> {
        if let remote {
            do {
                let dtos = try await remote.getAvailableLanguages()
                if !dtos.isEmpty {
                    local.writeAvailableLanguages(dtos)
                    return .success(dtos.map(SettingsMapper.toLanguageEntity))
                }
            } catch {
                logger.info(
                    "[SettingsRepository] remote languages failed: \(error) — fallback",
                    file: #file,
                    function: #function,
                    line: #line
                )
            }
        }

        if let cached = local.readAvailableLanguages(), !cached.isEmpty {
            return .success(cached.map(SettingsMapper.toLanguageEntity))
        }

        return .success(AvailableLanguage.defaultLanguages)
    }

    func isLanguageCached(_ code: String) async -> Bool {
        local.isLanguageCached(code)
    }

    func getLocalizationOverrides(
        code: String,
        sinceVersion: String?,
        eTag: String?
    ) async -> DataState<TranslationOverride?> {
        guard let remote else {
            return .success(nil)
        }
        let effectiveSinceVersion = sinceVersion ?? local.readVersion(for: code)
        let effectiveETag = eTag ?? local.readETag(for: code)
        do {
            let dto = try await remote.getLocalizationOverrides(
                languageCode: code,
                sinceVersion: effectiveSinceVersion,
                eTag: effectiveETag
            )
            if let dto {
                return .success(SettingsMapper.toOverrideEntity(dto))
            } else {
                return .success(nil)
            }
        } catch {
            return .error(AppError(code: "network", message: error.localizedDescription))
        }
    }

    func saveCachedTranslations(
        code: String,
        version: String,
        eTag: String?,
        translations: [String: String]
    ) async -> DataState<Void> {
        var merged = local.readTranslations(for: code) ?? [:]
        for (key, value) in translations {
            merged[key] = value
        }
        local.writeTranslations(merged, for: code)
        local.writeVersion(version, for: code)
        if let eTag {
            local.writeETag(eTag, for: code)
        }
        return .success(())
    }

    func updateUserPreferences(language: String?, isDarkMode: Bool?) async -> DataState<Void> {
        guard let remote else {
            return .success(())
        }
        do {
            let themeId = isDarkMode.map { $0 ? "dark" : "light" }
            try await remote.updateUserPreferences(language: language, themeId: themeId)
            return .success(())
        } catch {
            return .error(AppError(code: "network", message: error.localizedDescription))
        }
    }

    func isSettingsCached() async -> Bool {
        local.hasCachedSettings()
    }
}
