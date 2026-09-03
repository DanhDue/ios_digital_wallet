import Core

/// Persists the settings (Source Spec §4.4). A one-line pass-through to
/// `SettingsRepository.save(_:)` today; the seam exists so validation or
/// write-through policy has a home outside the ViewModel.
@MainActor
public struct SaveSettingsUseCase {
    private let repository: SettingsRepository

    public init(repository: SettingsRepository) {
        self.repository = repository
    }

    public func execute(_ entity: SettingsEntity) async -> DataState<Void> {
        await repository.save(entity)
    }

    public func callAsFunction(_ entity: SettingsEntity) async -> DataState<Void> {
        await execute(entity)
    }
}
