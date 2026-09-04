import Core
import Framework

/// The `{{name.pascalCase()}}` screen's `MviViewModel` (Source Spec §5.4 / §5.5).
///
/// * `.onAppear` runs the `"load"` effect: `Get{{name.pascalCase()}}UseCase` →
///   `reduce` → `showContent()`, or `handleError` on failure.
/// * Every mutating action applies an **optimistic** `reduce`, then runs the
///   shared `"save"` effect. A burst of edits coalesces to a single
///   `Save{{name.pascalCase()}}UseCase` call for the final value (the prior
///   same-key `Task` is cancelled by `launch` before the next starts).
/// * A failed save **reverts** to the pre-action snapshot and emits
///   `.saveFailed`.
///
/// Both effect bodies bail on `Task.isCancelled` — before and after the `await`
/// — so a superseded effect neither performs I/O nor emits.
///
/// See: Features/Settings/Sources/Settings/Presentation/SettingsViewModel.swift
public final class {{name.pascalCase()}}ViewModel: MviViewModel<{{name.pascalCase()}}State, {{name.pascalCase()}}Action, {{name.pascalCase()}}Event> {
    private static let loadEffect = "load"
    private static let saveEffect = "save"

    private let get{{name.pascalCase()}}: Get{{name.pascalCase()}}UseCase
    private let save{{name.pascalCase()}}: Save{{name.pascalCase()}}UseCase

    public init(
        get{{name.pascalCase()}}: Get{{name.pascalCase()}}UseCase,
        save{{name.pascalCase()}}: Save{{name.pascalCase()}}UseCase
    ) {
        self.get{{name.pascalCase()}} = get{{name.pascalCase()}}
        self.save{{name.pascalCase()}} = save{{name.pascalCase()}}
        super.init(initialState: {{name.pascalCase()}}State(entity: .default))
    }

    /// Convenience wiring for a caller that already holds a
    /// `{{name.pascalCase()}}Repository`.
    public convenience init(repository: {{name.pascalCase()}}Repository) {
        self.init(
            get{{name.pascalCase()}}: Get{{name.pascalCase()}}UseCase(repository: repository),
            save{{name.pascalCase()}}: Save{{name.pascalCase()}}UseCase(repository: repository)
        )
    }

    override public func onAction(_ action: {{name.pascalCase()}}Action) {
        switch action {
        case .onAppear:
            load()
        case let .titleChanged(title):
            guard !title.isEmpty else { return }
            mutate { $0.title = title }
        case .increment:
            mutate { $0.count += 1 }
        }
    }

    // MARK: - Effects

    private func load() {
        startLoading()
        launch(Self.loadEffect) { [weak self] in
            guard let self, !Task.isCancelled else { return }
            let result = await get{{name.pascalCase()}}.execute()
            guard !Task.isCancelled else { return }
            switch result {
            case let .success(entity):
                reduce { $0.entity = entity }
                showContent()
            case let .error(appError):
                handleError(appError)
            case .loading:
                break
            }
        }
    }

    /// Applies `change` to `entity` optimistically, flags `isSaving`, then runs
    /// the shared `"save"` effect against a snapshot taken *before* the change.
    private func mutate(_ change: (inout {{name.pascalCase()}}Entity) -> Void) {
        let snapshot = uiState.entity
        reduce {
            change(&$0.entity)
            $0.isSaving = true
        }
        persist(revertingTo: snapshot)
    }

    private func persist(revertingTo snapshot: {{name.pascalCase()}}Entity) {
        launch(Self.saveEffect) { [weak self] in
            guard let self, !Task.isCancelled else { return }
            let result = await save{{name.pascalCase()}}.execute(uiState.entity)
            guard !Task.isCancelled else { return }
            reduce { $0.isSaving = false }
            if case let .error(appError) = result {
                reduce { $0.entity = snapshot }
                emit(.saveFailed(appError.message))
            }
        }
    }
}
