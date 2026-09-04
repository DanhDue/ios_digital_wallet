import Core

/// Fetches available languages supported by the application.
///
/// Falls back to local cache or bundled defaults when offline.
@MainActor
public struct GetAvailableLanguagesUseCase {
    private let repository: SettingsRepository

    public init(repository: SettingsRepository) {
        self.repository = repository
    }

    public func execute() async -> DataState<[AvailableLanguage]> {
        await repository.getAvailableLanguages()
    }

    public func callAsFunction() async -> DataState<[AvailableLanguage]> {
        await execute()
    }
}
