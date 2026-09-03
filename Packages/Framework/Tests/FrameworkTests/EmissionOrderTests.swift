import Combine
import XCTest
@testable import Framework

/// Asserts the exact *sequence* of `@Published` emissions (arrays), never just
/// the terminal value. Recorders are subscribed BEFORE the first dispatch.
@MainActor
final class EmissionOrderTests: XCTestCase {
    func testViewStateSequenceForSuccessfulLoadIsLoadingThenContent() {
        let viewModel = CounterViewModel(initialState: CountState(count: 0))
        let recorder = Recorder(viewModel.$viewState.map(\.tag))

        viewModel.onActionHook = { [weak viewModel] _ in
            viewModel?.reduce { $0.count = 1 }
            viewModel?.showContent()
        }
        viewModel.dispatch(.load(1))

        XCTAssertEqual(recorder.values, ["loading", "content"])
    }

    func testViewStateSequenceForFailedLoadIsLoadingThenError() {
        let viewModel = CounterViewModel(initialState: CountState(count: 0))
        let recorder = Recorder(viewModel.$viewState.map(\.tag))

        viewModel.onActionHook = { [weak viewModel] _ in
            viewModel?.handleError(SampleError(reason: "network"))
        }
        viewModel.dispatch(.load(1))

        XCTAssertEqual(recorder.values, ["loading", "error"])
    }

    func testUiStateSequenceIsInitialThenEachReduceResultInOrder() {
        let viewModel = CounterViewModel(initialState: CountState(count: 0))
        let recorder = Recorder(viewModel.$uiState.map(\.count))

        viewModel.onActionHook = { [weak viewModel] _ in
            viewModel?.reduce { $0.count = 1 }
            viewModel?.reduce { $0.count = 2 }
            viewModel?.reduce { $0.count = 3 }
        }
        viewModel.dispatch(.increment)

        XCTAssertEqual(recorder.values, [0, 1, 2, 3])
    }

    func testUiStateDoesNotEmitForANoOpAction() {
        let viewModel = CounterViewModel(initialState: CountState(count: 9))
        let recorder = Recorder(viewModel.$uiState.map(\.count))

        viewModel.onActionHook = { _ in }
        viewModel.dispatch(.ignored)

        XCTAssertEqual(recorder.values, [9])
    }
}
