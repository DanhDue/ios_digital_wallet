import Combine
import XCTest
@testable import Framework

/// Happy-path routing + reduce + the three `viewState` mutators, plus the
/// state-transition matrix (every documented edge + a no-op edge).
@MainActor
final class MviViewModelTests: XCTestCase {
    // MARK: dispatch -> onAction

    func testDispatchRoutesToOnActionExactlyOnce() {
        let viewModel = CounterViewModel(initialState: CountState())

        viewModel.dispatch(.increment)

        XCTAssertEqual(viewModel.receivedActions, [.increment])
    }

    func testDispatchForwardsTheExactActionPayload() {
        let viewModel = CounterViewModel(initialState: CountState())

        viewModel.dispatch(.load(7))
        viewModel.dispatch(.load(7))

        XCTAssertEqual(viewModel.receivedActions, [.load(7), .load(7)])
    }

    // MARK: reduce

    func testReduceMutatesUiStateInPlace() {
        let viewModel = CounterViewModel(initialState: CountState(count: 0))

        viewModel.reduce { $0.count += 1 }

        XCTAssertEqual(viewModel.uiState.count, 1)
    }

    func testReduceAppliesEverySuccessiveTransform() {
        let viewModel = CounterViewModel(initialState: CountState(count: 0))

        viewModel.reduce { $0.count = 10 }
        viewModel.reduce { $0.count += 5 }
        viewModel.reduce { $0.label = "done" }

        XCTAssertEqual(viewModel.uiState, CountState(count: 15, label: "done"))
    }

    // MARK: viewState mutators

    func testInitialViewStateIsLoading() {
        let viewModel = CounterViewModel(initialState: CountState())

        XCTAssertEqual(viewModel.viewState.tag, "loading")
    }

    func testStartLoadingSetsViewStateLoading() {
        let viewModel = CounterViewModel(initialState: CountState())
        viewModel.showContent() // move off .loading first

        viewModel.startLoading()

        XCTAssertEqual(viewModel.viewState.tag, "loading")
    }

    func testHandleErrorSetsViewStateErrorCarryingTheError() {
        let viewModel = CounterViewModel(initialState: CountState())
        let error = SampleError(reason: "boom")

        viewModel.handleError(error)

        XCTAssertEqual(viewModel.viewState.tag, "error")
        XCTAssertEqual(viewModel.viewState.errorValue as? SampleError, error)
    }

    func testShowContentSetsViewStateContentWithCurrentUiState() {
        let viewModel = CounterViewModel(initialState: CountState(count: 3))
        viewModel.reduce { $0.count = 42 }

        viewModel.showContent()

        XCTAssertEqual(viewModel.viewState.tag, "content")
        XCTAssertEqual(viewModel.viewState.contentValue, CountState(count: 42))
    }

    // MARK: state-transition matrix

    func testEveryDocumentedViewStateEdgeIsReachable() {
        let viewModel = CounterViewModel(initialState: CountState(count: 1))

        // loading -> content
        viewModel.showContent()
        XCTAssertEqual(viewModel.viewState.tag, "content")

        // content -> loading
        viewModel.startLoading()
        XCTAssertEqual(viewModel.viewState.tag, "loading")

        // loading -> error
        viewModel.handleError(SampleError(reason: "x"))
        XCTAssertEqual(viewModel.viewState.tag, "error")

        // error -> content
        viewModel.showContent()
        XCTAssertEqual(viewModel.viewState.tag, "content")

        // content -> error
        viewModel.handleError(SampleError(reason: "y"))
        XCTAssertEqual(viewModel.viewState.tag, "error")

        // error -> loading
        viewModel.startLoading()
        XCTAssertEqual(viewModel.viewState.tag, "loading")
    }

    func testNoOpActionLeavesStateUntouched() {
        let viewModel = CounterViewModel(initialState: CountState(count: 5))
        viewModel.onActionHook = { _ in } // .ignored does nothing

        viewModel.dispatch(.ignored)

        XCTAssertEqual(viewModel.receivedActions, [.ignored])
        XCTAssertEqual(viewModel.uiState, CountState(count: 5))
        XCTAssertEqual(viewModel.viewState.tag, "loading")
    }

    func testDispatchOnSubclassWithoutOnActionOverrideIsANoOp() {
        final class Bare: MviViewModel<CountState, CountAction, CountEvent> {}
        let viewModel = Bare(initialState: CountState(count: 1))

        viewModel.dispatch(.increment) // routes to the base empty onAction

        XCTAssertEqual(viewModel.uiState, CountState(count: 1))
        XCTAssertEqual(viewModel.viewState.tag, "loading")
    }
}
