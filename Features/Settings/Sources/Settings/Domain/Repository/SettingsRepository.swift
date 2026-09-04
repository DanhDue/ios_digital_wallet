import Core

/// The persistence seam for the Settings feature (Source Spec §4.4). The
/// `Data` layer supplies the only conforming type; `Presentation` never sees it.
///
/// `@MainActor`-isolated on purpose: this feature is local-only (a synchronous
/// `CacheStore` behind an `async` face), so keeping the whole Domain stack on the
/// main actor removes all `Sendable` ceremony from the §5.5 async-effect path. A
/// networked feature would model its repository as an `actor` instead.
@MainActor
public protocol SettingsRepository {
    /// Loads the persisted settings. A missing or unreadable store resolves to
    /// `.success(SettingsEntity.default)` — never `.error`.
    func load() async -> DataState<SettingsEntity>

    /// Persists `entity` wholesale. Returns `.error` when the write fails.
    func save(_ entity: SettingsEntity) async -> DataState<Void>
}
