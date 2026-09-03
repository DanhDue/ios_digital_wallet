import Combine
import XCTest
@testable import Framework

/// §5.5 async-effect: same-key supersession, distinct-key concurrency, and
/// prompt `Task.isCancelled` observation. All progress is driven through
/// `EffectProbe` — no `sleep`, no wall-clock races.
@MainActor
final class AsyncEffectTests: XCTestCase {
    /// Wires `onAction(.load(value))` to `launch("load")` an effect that waits on
    /// the probe, then reduces `count = value`. A superseded effect observes
    /// `CancellationError` and reduces nothing.
    private func makeGatedLoadViewModel(_ probe: EffectProbe) -> CounterViewModel {
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
        return viewModel
    }

    // MARK: three rapid dispatches -> only the last effect reduces

    func testThreeRapidSameKeyDispatchesOnlyLastEffectReachesReduce() async {
        let probe = EffectProbe()
        let viewModel = makeGatedLoadViewModel(probe)

        viewModel.dispatch(.load(1))
        viewModel.dispatch(.load(2))
        viewModel.dispatch(.load(3))

        // effects 1 and 2 were cancelled before touching state...
        await expectSignal(probe, .cancelled(1))
        await expectSignal(probe, .cancelled(2))
        // ...and effect 3 is the one now running.
        await expectSignal(probe, .arrived(3))

        let midFlight = await probe.signals
        XCTAssertFalse(midFlight.contains(.completed(1)), "effect 1 must not reduce")
        XCTAssertFalse(midFlight.contains(.completed(2)), "effect 2 must not reduce")
        XCTAssertEqual(viewModel.uiState.count, 0, "no reduce has happened yet")

        await probe.release(3)
        await expectSignal(probe, .completed(3))

        XCTAssertEqual(viewModel.uiState.count, 3, "only effect 3's reduce is observed")
        XCTAssertTrue(viewModel.effectTasks.isEmpty, "the completed effect clears its slot")
    }

    // MARK: distinct keys run concurrently

    func testDistinctKeysRunConcurrentlyWithoutMutualCancellation() async {
        let probe = EffectProbe()
        let viewModel = CounterViewModel(initialState: CountState(count: 0))
        viewModel.onActionHook = { [weak viewModel] action in
            guard case let .load(value) = action else { return }
            let key = "key-\(value)"
            viewModel?.launch(key) { [weak viewModel] in
                do {
                    try await probe.wait(value)
                } catch is CancellationError {
                    await probe.note(.cancelled(value))
                    return
                } catch {
                    await probe.note(.failed(value))
                    return
                }
                viewModel?.reduce { $0.count += value }
                await probe.note(.completed(value))
            }
        }

        viewModel.dispatch(.load(10))
        viewModel.dispatch(.load(20))

        await expectSignal(probe, .arrived(10))
        await expectSignal(probe, .arrived(20))
        XCTAssertEqual(viewModel.effectTasks.count, 2, "both effects are tracked at once")

        await probe.release(10)
        await probe.release(20)
        await expectSignal(probe, .completed(10))
        await expectSignal(probe, .completed(20))

        let signals = await probe.signals
        XCTAssertFalse(signals.contains(.cancelled(10)))
        XCTAssertFalse(signals.contains(.cancelled(20)))
        XCTAssertEqual(viewModel.uiState.count, 30, "both effects reduced")
        XCTAssertTrue(viewModel.effectTasks.isEmpty)
    }

    // MARK: Task.isCancelled is observed promptly

    func testEffectCheckingIsCancelledStopsAfterSupersedingDispatch() async {
        let probe = EffectProbe()
        let viewModel = CounterViewModel(initialState: CountState(count: 0))
        viewModel.onActionHook = { [weak viewModel] action in
            guard case let .load(value) = action else { return }
            viewModel?.launch("spin") {
                await probe.note(.arrived(value))
                while !Task.isCancelled {
                    await Task.yield()
                }
                // cancelled: loop exited promptly, stop without mutating state
                await probe.note(.cancelled(value))
            }
        }

        viewModel.dispatch(.load(1))
        await expectSignal(probe, .arrived(1))

        viewModel.dispatch(.load(2)) // supersedes effect 1 on key "spin"
        await expectSignal(probe, .arrived(2))
        await expectSignal(probe, .cancelled(1)) // effect 1's loop exited promptly

        viewModel.onClear() // stop the still-spinning effect 2
        await expectSignal(probe, .cancelled(2))

        XCTAssertEqual(viewModel.uiState.count, 0, "no cancelled effect mutated state")
        XCTAssertTrue(viewModel.effectTasks.isEmpty)
    }
}
