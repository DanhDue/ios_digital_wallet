import Core

/// Reads the persisted `{{name.pascalCase()}}` value (Source Spec §4.4). A
/// one-line pass-through to `{{name.pascalCase()}}Repository.load()` today; the
/// seam exists so policy (defaulting, migration, feature flags) has a home that
/// never leaks into the ViewModel.
///
/// See: Packages/Features/SettingsFeature/Sources/SettingsFeature/Domain/UseCase/GetSettingsUseCase.swift
@MainActor
public struct Get{{name.pascalCase()}}UseCase {
    private let repository: {{name.pascalCase()}}Repository

    public init(repository: {{name.pascalCase()}}Repository) {
        self.repository = repository
    }

    public func execute() async -> DataState<{{name.pascalCase()}}Entity> {
        await repository.load()
    }

    public func callAsFunction() async -> DataState<{{name.pascalCase()}}Entity> {
        await execute()
    }
}
