import Core

/// Checks whether translations for `languageCode` are cached locally.
@MainActor
public struct CheckLanguageCachedUseCase {
    private let repository: SettingsRepository

    public init(repository: SettingsRepository) {
        self.repository = repository
    }

    public func execute(_ languageCode: String) async -> Bool {
        await repository.isLanguageCached(languageCode)
    }

    public func callAsFunction(_ languageCode: String) async -> Bool {
        await execute(languageCode)
    }
}
