import Foundation

/// ViewModel for MyPlugin screen handling MVI state reduction.
@MainActor
public final class MyPluginViewModel: MviViewModel<MyPluginState, MyPluginAction, MyPluginEvent> {
    private let getDataUseCase: GetDataUseCase
    private var inFlightTask: Task<Void, Never>?

    public init(getDataUseCase: GetDataUseCase) {
        self.getDataUseCase = getDataUseCase
        super.init(initialState: .idle)
    }

    override public func dispatch(action: MyPluginAction) {
        switch action {
        case .load, .refresh:
            loadData()
        }
    }

    private func loadData() {
        inFlightTask?.cancel()
        setState(.loading)

        inFlightTask = Task { [weak self] in
            guard let self else { return }
            do {
                try Task.checkCancellation()
                let data = try await getDataUseCase.execute()
                try Task.checkCancellation()
                setState(.loaded(data))
            } catch is CancellationError {
                // Task was cancelled by rapid repeat action; do not emit error or loaded state
            } catch {
                setState(.error(error.localizedDescription))
                emit(event: .showError(error.localizedDescription))
            }
        }
    }

    deinit {
        inFlightTask?.cancel()
    }
}
