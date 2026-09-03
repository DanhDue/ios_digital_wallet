import Combine
import XCTest
@testable import Framework

/// Event channels: `eventSubject` (one-consumer convention) and
/// `sharedEventSubject` (multi-consumer), plus the no-subscriber safety case.
@MainActor
final class EventSubjectTests: XCTestCase {
    func testEmitDeliversToTheSingleEventSubjectSubscriber() {
        let viewModel = CounterViewModel(initialState: CountState())
        let recorder = Recorder(viewModel.eventSubject)

        viewModel.emit(.pinged)
        viewModel.emit(.tagged(3))

        XCTAssertEqual(recorder.values, [.pinged, .tagged(3)])
    }

    func testEmitSharedDeliversTheSameEventToTwoSubscribers() {
        let viewModel = CounterViewModel(initialState: CountState())
        let first = Recorder(viewModel.sharedEventSubject)
        let second = Recorder(viewModel.sharedEventSubject)

        viewModel.emitShared(.tagged(7))

        XCTAssertEqual(first.values, [.tagged(7)])
        XCTAssertEqual(second.values, [.tagged(7)])
    }

    func testEmitWithNoSubscriberDoesNotCrash() {
        let viewModel = CounterViewModel(initialState: CountState())

        viewModel.emit(.pinged)
        viewModel.emitShared(.pinged)

        // reaching here without a trap is the assertion; a late subscriber sees
        // nothing (PassthroughSubject has no replay).
        let late = Recorder(viewModel.eventSubject)
        XCTAssertTrue(late.values.isEmpty)
    }

    func testEventSubjectAndSharedEventSubjectAreIndependent() {
        let viewModel = CounterViewModel(initialState: CountState())
        let onEvent = Recorder(viewModel.eventSubject)
        let onShared = Recorder(viewModel.sharedEventSubject)

        viewModel.emit(.pinged)
        viewModel.emitShared(.tagged(1))

        XCTAssertEqual(onEvent.values, [.pinged])
        XCTAssertEqual(onShared.values, [.tagged(1)])
    }
}
