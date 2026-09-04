import Core

/// The persistence seam for the `{{name.pascalCase()}}` feature (Source Spec §4.4).
/// The `Data` layer supplies the only conforming type; `Presentation` never
/// sees it.
///
/// `@MainActor`-isolated to match `SettingsRepository`: the template's features
/// keep the whole Domain stack on the main actor so the §5.5 async-effect path
/// carries no `Sendable` ceremony. A heavily-networked feature would model this
/// as an `actor` instead.
///
/// See: Features/Settings/Sources/Settings/Domain/Repository/SettingsRepository.swift
@MainActor
public protocol {{name.pascalCase()}}Repository {
    /// Loads the persisted value. A missing or unreadable store resolves to
    /// `.success({{name.pascalCase()}}Entity.default)` — never `.error`.
    func load() async -> DataState<{{name.pascalCase()}}Entity>

    /// Persists `entity` wholesale. Returns `.error` when the write fails.
    func save(_ entity: {{name.pascalCase()}}Entity) async -> DataState<Void>
}
