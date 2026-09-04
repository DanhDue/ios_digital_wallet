import Core

/// Updates user preferences on the remote backend (language, theme).
@MainActor
public struct UpdateUserPreferencesUseCase {
    private let repository: SettingsRepository

    public init(repository: SettingsRepository) {
        self.repository = repository
    }

    public func execute(language: String? = nil, isDarkMode: Bool? = nil) async -> DataState<Void> {
        await repository.updateUserPreferences(language: language, isDarkMode: isDarkMode)
    }

    public func callAsFunction(language: String? = nil, isDarkMode: Bool? = nil) async -> DataState<Void> {
        await execute(language: language, isDarkMode: isDarkMode)
    }
}
