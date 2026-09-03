import Combine
import XCTest
@testable import Framework

/// Resource teardown: `onClear()` empties `cancellables` and `effectTasks`,
/// cancels in-flight effects, delivers no further `@Published` emission, and
/// leaves no retain cycle.
@MainActor
final class TeardownTests: XCTestCase {
    func testOnClearEmptiesCancellablesAndEffectTasks() async {
        let probe = EffectProbe()
        let viewModel = CounterViewModel(initialState: CountState(count: 0))

        // a live subscription in the bag
        viewModel.$uiState
            .sink { _ in }
            .store(in: &viewModel.cancellables)
        XCTAssertEqual(viewModel.cancellables.count, 1)

        // a live effect
        viewModel.onActionHook = { [weak viewModel] _ in
            viewModel?.launch("load") { [weak viewModel] in
                do { try await probe.wait(1) } catch { await probe.note(.cancelled(1)); return }
                viewModel?.reduce { $0.count = 1 }
            }
        }
        viewModel.dispatch(.load(1))
        await expectSignal(probe, .arrived(1))
        XCTAssertEqual(viewModel.effectTasks.count, 1)

        viewModel.onClear()

        XCTAssertTrue(viewModel.cancellables.isEmpty, "cancellables emptied")
        XCTAssertTrue(viewModel.effectTasks.isEmpty, "effectTasks emptied")
    }

    func testOnClearDuringInFlightEffectCancelsItAndNoReduceHappensAfterwards() async {
        let probe = EffectProbe()
        let viewModel = CounterViewModel(initialState: CountState(count: 0))

        viewModel.onActionHook = { [weak viewModel] _ in
            viewModel?.launch("load") { [weak viewModel] in
                do {
                    try await probe.wait(1)
                } catch is CancellationError {
                    await probe.note(.cancelled(1))
                    return
                } catch {
                    return
                }
                viewModel?.reduce { $0.count = 99 }
                await probe.note(.completed(1))
            }
        }

        viewModel.dispatch(.load(1))
        await expectSignal(probe, .arrived(1))

        viewModel.onClear()
        await expectSignal(probe, .cancelled(1))

        let signals = await probe.signals
        XCTAssertFalse(signals.contains(.completed(1)), "no reduce after onClear")
        XCTAssertEqual(viewModel.uiState.count, 0)
        XCTAssertTrue(viewModel.effectTasks.isEmpty)
    }

    func testNoPublishedEmissionIsDeliveredAfterOnClear() async {
        let probe = EffectProbe()
        let viewModel = CounterViewModel(initialState: CountState(count: 0))

        let uiRecorder = Recorder(viewModel.$uiState.map(\.count))
        let viewRecorder = Recorder(viewModel.$viewState.map(\.tag))

        viewModel.onActionHook = { [weak viewModel] _ in
            viewModel?.launch("load") { [weak viewModel] in
                do {
                    try await probe.wait(1)
                } catch {
                    await probe.note(.cancelled(1))
                    return
                }
                viewModel?.reduce { $0.count = 1 } // must never run
            }
        }
        viewModel.dispatch(.load(1))
        await expectSignal(probe, .arrived(1))

        let uiBefore = uiRecorder.values
        let viewBefore = viewRecorder.values

        viewModel.onClear()
        await expectSignal(probe, .cancelled(1))
        // give any stray continuation a chance to schedule
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(uiRecorder.values, uiBefore, "no uiState emission after onClear")
        XCTAssertEqual(viewRecorder.values, viewBefore, "no viewState emission after onClear")
    }

    func testViewModelIsNotRetainedAfterScopeExit() {
        weak var weakViewModel: CounterViewModel?

        autoreleasepool {
            let viewModel = CounterViewModel(initialState: CountState(count: 0))
            weakViewModel = viewModel
            viewModel.dispatch(.increment)
            viewModel.onClear()
        }

        XCTAssertNil(weakViewModel, "no retain cycle keeps the ViewModel alive")
    }

    func testEffectClosureCapturingWeakSelfDoesNotRetainTheViewModel() async {
        let probe = EffectProbe()
        weak var weakViewModel: CounterViewModel?

        await { () async in
            let viewModel = CounterViewModel(initialState: CountState(count: 0))
            weakViewModel = viewModel
            viewModel.onActionHook = { [weak viewModel] _ in
                viewModel?.launch("load") { [weak viewModel] in
                    do { try await probe.wait(1) } catch { await probe.note(.cancelled(1)); return }
                    viewModel?.reduce { $0.count = 1 }
                }
            }
            viewModel.dispatch(.load(1))
            await expectSignal(probe, .arrived(1))
            viewModel.onClear()
            await expectSignal(probe, .cancelled(1))
        }()

        XCTAssertNil(weakViewModel)
    }
}
