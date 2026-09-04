import Core

/// Status emitted during the language switch workflow.
public enum LanguageSyncStatus: Equatable, Sendable {
    case loading
    case cachedApplied
    case success
    case error(AppError)
}

/// Orchestrates language changing with optimistic UI, race condition protection,
/// and fallback logic (parity with Flutter PR #34).
@MainActor
public struct ChangeLanguageUseCase {
    private let checkLanguageCachedUseCase: CheckLanguageCachedUseCase
    private let getDynamicLocalizationUseCase: GetDynamicLocalizationUseCase
    private let updateUserPreferencesUseCase: UpdateUserPreferencesUseCase
    private let localizationService: any LocalizationService

    public init(
        checkLanguageCachedUseCase: CheckLanguageCachedUseCase,
        getDynamicLocalizationUseCase: GetDynamicLocalizationUseCase,
        updateUserPreferencesUseCase: UpdateUserPreferencesUseCase,
        localizationService: any LocalizationService
    ) {
        self.checkLanguageCachedUseCase = checkLanguageCachedUseCase
        self.getDynamicLocalizationUseCase = getDynamicLocalizationUseCase
        self.updateUserPreferencesUseCase = updateUserPreferencesUseCase
        self.localizationService = localizationService
    }

    public func execute(_ languageCode: String) -> AsyncStream<LanguageSyncStatus> {
        AsyncStream { continuation in
            Task { @MainActor in
                let currentLanguage = localizationService.currentLanguageCode
                let isSameLanguage = (currentLanguage == languageCode)

                if isSameLanguage {
                    // Delta update only, skip static locale setting and backend updates
                    let deltaResult = await getDynamicLocalizationUseCase(languageCode)
                    if case let .error(appError) = deltaResult {
                        continuation.yield(.error(appError))
                    }
                    continuation.finish()
                    return
                }

                let isCached = await checkLanguageCachedUseCase(languageCode)
                    || AvailableLanguage.isDefaultOrBundled(languageCode)

                if isCached {
                    // Optimistic UI: Apply locale immediately
                    localizationService.setLocale(code: languageCode)
                    continuation.yield(.cachedApplied)
                } else {
                    continuation.yield(.loading)
                }

                let dynamicResult = await getDynamicLocalizationUseCase(languageCode)
                switch dynamicResult {
                case let .error(appError):
                    continuation.yield(.error(appError))
                case .success:
                    if !isCached {
                        localizationService.setLocale(code: languageCode)
                    }
                    continuation.yield(.success)
                case .loading:
                    break
                }

                // Update backend preference for new language click
                _ = await updateUserPreferencesUseCase(language: languageCode)
                continuation.finish()
            }
        }
    }

    public func callAsFunction(_ languageCode: String) -> AsyncStream<LanguageSyncStatus> {
        execute(languageCode)
    }
}
