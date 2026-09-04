import Core

/// Checks whether user settings have been cached locally.
@MainActor
public struct CheckSettingsCachedUseCase {
    private let repository: SettingsRepository

    public init(repository: SettingsRepository) {
        self.repository = repository
    }

    public func execute() async -> Bool {
        await repository.isSettingsCached()
    }

    public func callAsFunction() async -> Bool {
        await execute()
    }
}
