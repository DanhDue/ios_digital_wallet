import Framework

/// The `Result` sub-screen's `MviViewModel` (Source Spec §5.4 / §5.5).
///
/// Self-contained on purpose — it owns no use case and performs no I/O. The
/// code to display arrives already resolved (`ScannerResultRoute.code`) at
/// construction time, so `.onAppear` only flips `viewState` from `.loading`
/// to `.content`; there is no async effect to `launch`.
///
/// See: Features/Settings/Sources/Settings/Presentation/SettingsViewModel.swift
public final class ResultViewModel: MviViewModel<ResultState, ResultAction, ResultEvent> {
    public init(code: String) {
        super.init(initialState: ResultState(code: code))
    }

    override public func onAction(_ action: ResultAction) {
        switch action {
        case .onAppear:
            showContent()
        }
    }
}
