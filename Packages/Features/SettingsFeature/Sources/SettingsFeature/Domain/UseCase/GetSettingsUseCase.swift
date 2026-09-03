import Core

/// Reads the persisted settings (Source Spec §4.4). A one-line pass-through to
/// `SettingsRepository.load()` today; the seam exists so policy (defaulting,
/// migration, feature flags) has a home that never leaks into the ViewModel.
@MainActor
public struct GetSettingsUseCase {
    private let repository: SettingsRepository

    public init(repository: SettingsRepository) {
        self.repository = repository
    }

    public func execute() async -> DataState<SettingsEntity> {
        await repository.load()
    }

    public func callAsFunction() async -> DataState<SettingsEntity> {
        await execute()
    }
}
