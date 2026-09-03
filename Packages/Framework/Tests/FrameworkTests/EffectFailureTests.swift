import Combine
import XCTest
@testable import Framework

/// Failure injection: a non-cancellation throw surfaces as `viewState == .error`
/// via `handleError`; a `CancellationError` is swallowed (never `.error`).
@MainActor
final class EffectFailureTests: XCTestCase {
    func testEffectThrowingNonCancellationErrorCallsHandleErrorAndSetsViewStateError() async {
        let probe = EffectProbe()
        let viewModel = CounterViewModel(initialState: CountState(count: 0))
        let thrown = SampleError(reason: "http-500")

        viewModel.onActionHook = { [weak viewModel] _ in
            viewModel?.launch("load") { [weak viewModel] in
                do {
                    try await probe.wait(1)
                    throw thrown
                } catch is CancellationError {
                    await probe.note(.cancelled(1))
                } catch {
                    viewModel?.handleError(error)
                    await probe.note(.failed(1))
                }
            }
        }

        viewModel.dispatch(.failNonCancellation)
        await expectSignal(probe, .arrived(1))
        await probe.release(1)
        await expectSignal(probe, .failed(1))

        XCTAssertEqual(viewModel.viewState.tag, "error")
        XCTAssertEqual(viewModel.viewState.errorValue as? SampleError, thrown)
    }

    func testCancellationErrorIsSwallowedAndNeverSurfacedAsViewStateError() async {
        let probe = EffectProbe()
        let viewModel = CounterViewModel(initialState: CountState(count: 0))

        viewModel.onActionHook = { [weak viewModel] action in
            guard case let .load(value) = action else { return }
            viewModel?.launch("load") { [weak viewModel] in
                do {
                    try await probe.wait(value)
                } catch is CancellationError {
                    await probe.note(.cancelled(value))
                    return
                } catch {
                    viewModel?.handleError(error)
                    await probe.note(.failed(value))
                    return
                }
                viewModel?.reduce { $0.count = value }
                await probe.note(.completed(value))
            }
        }

        viewModel.dispatch(.load(1))
        viewModel.dispatch(.load(2)) // cancels effect 1

        await expectSignal(probe, .cancelled(1))
        await expectSignal(probe, .arrived(2))

        XCTAssertEqual(viewModel.viewState.tag, "loading", "cancellation is not an error state")

        await probe.release(2)
        await expectSignal(probe, .completed(2))
        XCTAssertEqual(viewModel.viewState.tag, "loading")
        XCTAssertEqual(viewModel.uiState.count, 2)
    }
}
