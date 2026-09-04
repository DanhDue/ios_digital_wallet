import Core
import Framework

/// The Settings screen's `MviViewModel` (Source Spec §5.4 / §5.5).
///
/// * `.onAppear` runs the `"load"` effect: `GetSettingsUseCase` → `reduce` →
///   `showContent()`, or `handleError` on failure.
/// * Every mutating action applies an **optimistic** `reduce` (flip the field,
///   set `isSaving`), then runs the `"save"` effect. All three mutating actions
///   share the one `"save"` key, so a burst of toggles coalesces to a single
///   `SaveSettingsUseCase` call for the final value (the prior same-key `Task` is
///   cancelled by `launch` before the next starts).
/// * A failed save **reverts** to the pre-action snapshot and emits
///   `.saveFailed`.
///
/// Both effect bodies bail on `Task.isCancelled` — before touching the use case
/// and again after it resumes — so a superseded effect neither performs I/O nor
/// emits, which is what makes the coalescing and teardown guarantees structural.
public final class SettingsViewModel: MviViewModel<SettingsState, SettingsAction, SettingsEvent> {
    private static let loadEffect = "load"
    private static let saveEffect = "save"

    private let getSettings: GetSettingsUseCase
    private let saveSettings: SaveSettingsUseCase

    public init(getSettings: GetSettingsUseCase, saveSettings: SaveSettingsUseCase) {
        self.getSettings = getSettings
        self.saveSettings = saveSettings
        super.init(initialState: SettingsState(settings: .default))
    }

    /// Convenience wiring for a caller that already holds a `SettingsRepository`.
    public convenience init(repository: SettingsRepository) {
        self.init(
            getSettings: GetSettingsUseCase(repository: repository),
            saveSettings: SaveSettingsUseCase(repository: repository)
        )
    }

    override public func onAction(_ action: SettingsAction) {
        switch action {
        case .onAppear:
            load()
        case .toggleDarkMode:
            mutate { $0.isDarkMode.toggle() }
        case let .selectLanguage(code):
            guard !code.isEmpty else { return }
            mutate { $0.language = code }
        case .toggleNotifications:
            mutate { $0.notificationsEnabled.toggle() }
        }
    }

    // MARK: - Effects

    private func load() {
        startLoading()
        launch(Self.loadEffect) { [weak self] in
            guard let self, !Task.isCancelled else { return }
            let result = await getSettings.execute()
            guard !Task.isCancelled else { return }
            switch result {
            case let .success(entity):
                reduce { $0.settings = entity }
                showContent()
            case let .error(appError):
                handleError(appError)
            case .loading:
                break
            }
        }
    }

    /// Applies `change` to `settings` optimistically, flags `isSaving`, then runs
    /// the shared `"save"` effect against a snapshot taken *before* the change.
    private func mutate(_ change: (inout SettingsEntity) -> Void) {
        let snapshot = uiState.settings
        reduce {
            change(&$0.settings)
            $0.isSaving = true
        }
        persist(revertingTo: snapshot)
    }

    private func persist(revertingTo snapshot: SettingsEntity) {
        launch(Self.saveEffect) { [weak self] in
            guard let self, !Task.isCancelled else { return }
            let result = await saveSettings.execute(uiState.settings)
            guard !Task.isCancelled else { return }
            reduce { $0.isSaving = false }
            if case let .error(appError) = result {
                reduce { $0.settings = snapshot }
                emit(.saveFailed(appError.message))
            }
        }
    }
}
