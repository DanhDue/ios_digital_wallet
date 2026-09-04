import Framework

/// The `{{name.pascalCase()}}` sub-screen's `MviViewModel`
/// (Source Spec §5.4 / §5.5).
///
/// Self-contained on purpose — it owns no use cases, so it compiles inside any
/// feature package. Wire it to the feature's Domain the way
/// `{{feature.pascalCase()}}ViewModel` does when it needs real data.
///
/// See: Features/Settings/Sources/Settings/Presentation/SettingsViewModel.swift
public final class {{name.pascalCase()}}ViewModel: MviViewModel<{{name.pascalCase()}}State, {{name.pascalCase()}}Action, {{name.pascalCase()}}Event> {
    private static let loadEffect = "load"

    public init() {
        super.init(initialState: {{name.pascalCase()}}State())
    }

    override public func onAction(_ action: {{name.pascalCase()}}Action) {
        switch action {
        case .onAppear:
            load()
        case .increment:
            reduce { $0.count += 1 }
            if uiState.count.isMultiple(of: 5) {
                emit(.milestone(uiState.count))
            }
        }
    }

    private func load() {
        startLoading()
        launch(Self.loadEffect) { [weak self] in
            guard let self, !Task.isCancelled else { return }
            showContent()
        }
    }
}
