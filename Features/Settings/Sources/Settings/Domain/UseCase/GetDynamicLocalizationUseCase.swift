import Core

/// Fetches dynamic translation overrides from remote, caches them, and applies to the localization service.
@MainActor
public struct GetDynamicLocalizationUseCase {
    private let repository: SettingsRepository
    private let localizationService: any LocalizationService

    public init(
        repository: SettingsRepository,
        localizationService: any LocalizationService
    ) {
        self.repository = repository
        self.localizationService = localizationService
    }

    public func execute(_ languageCode: String) async -> DataState<Void> {
        let result = await repository.getLocalizationOverrides(code: languageCode, sinceVersion: nil, eTag: nil)
        switch result {
        case let .success(override):
            if let override {
                _ = await repository.saveCachedTranslations(
                    code: languageCode,
                    version: override.version,
                    eTag: override.checksum,
                    translations: override.translations
                )
                localizationService.applyDynamicTranslations(override.translations, languageCode: languageCode)
            }
            return .success(())
        case let .error(error):
            return .error(error)
        case .loading:
            return .loading
        }
    }

    public func callAsFunction(_ languageCode: String) async -> DataState<Void> {
        await execute(languageCode)
    }
}
