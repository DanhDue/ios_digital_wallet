import Core

/// The data seam for the Scanner feature (Source Spec §4.3). The `Data` layer
/// supplies the only conforming type; `Presentation` never sees it.
///
/// `@MainActor`-isolated to match `SettingsRepository`: the template's features
/// are local-only, so keeping the Domain stack on the main actor removes all
/// `Sendable` ceremony from the async-effect path.
@MainActor
public protocol ScannerRepository {
    /// Loads the (stub) scanner data. Never fails in the template.
    func fetch() async -> DataState<ScannerEntity>
}
