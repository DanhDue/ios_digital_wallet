import Core

/// Persists the `{{name.pascalCase()}}` value (Source Spec §4.4). A one-line
/// pass-through to `{{name.pascalCase()}}Repository.save(_:)` today; the seam
/// exists so validation or write-through policy has a home outside the ViewModel.
///
/// See: Features/Settings/Sources/Settings/Domain/UseCase/SaveSettingsUseCase.swift
@MainActor
public struct Save{{name.pascalCase()}}UseCase {
    private let repository: {{name.pascalCase()}}Repository

    public init(repository: {{name.pascalCase()}}Repository) {
        self.repository = repository
    }

    public func execute(_ entity: {{name.pascalCase()}}Entity) async -> DataState<Void> {
        await repository.save(entity)
    }

    public func callAsFunction(_ entity: {{name.pascalCase()}}Entity) async -> DataState<Void> {
        await execute(entity)
    }
}
