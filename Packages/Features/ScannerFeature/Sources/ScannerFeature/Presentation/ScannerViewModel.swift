import Core
import Framework

/// The Scanner screen's `MviViewModel` (Source Spec §5.4 / §5.5).
///
/// A minimal but *real* MVI trio so ArchTests K5 has something to check and the
/// stub still exercises the §5.5 async-effect path: `.onAppear` runs the
/// `"load"` effect (`GetScannerDataUseCase` → `reduce` → `showContent()`), which
/// bails on `Task.isCancelled` so teardown stays structural.
public final class ScannerViewModel: MviViewModel<ScannerState, ScannerAction, ScannerEvent> {
    private static let loadEffect = "load"

    private let getScannerData: GetScannerDataUseCase

    public init(getScannerData: GetScannerDataUseCase) {
        self.getScannerData = getScannerData
        super.init(initialState: ScannerState())
    }

    /// Convenience wiring for a caller that already holds a `ScannerRepository`.
    public convenience init(repository: ScannerRepository) {
        self.init(getScannerData: GetScannerDataUseCase(repository: repository))
    }

    override public func onAction(_ action: ScannerAction) {
        switch action {
        case .onAppear:
            load()
        }
    }

    private func load() {
        startLoading()
        launch(Self.loadEffect) { [weak self] in
            guard let self, !Task.isCancelled else { return }
            let result = await getScannerData.execute()
            guard !Task.isCancelled else { return }
            switch result {
            case let .success(entity):
                reduce { $0.entity = entity }
                showContent()
                emit(.dataLoaded)
            case let .error(appError):
                handleError(appError)
            case .loading:
                break
            }
        }
    }
}
