import Combine
import Foundation
import XCTest
@testable import Platform

/// Test-only events carrying identity so publish ordering is observable.
private struct TickEvent: AppEvent, Equatable {
    let id: Int
}

private struct TockEvent: AppEvent, Equatable {
    let id: Int
}

final class AppEventBusTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: Type filtering

    func testSubscriberReceivesPublishedEventOfItsType() {
        let bus = AppEventBus()
        let recorder = Recorder<UserLoggedOut>()
        bus.on(UserLoggedOut.self).record(into: recorder).store(in: &cancellables)

        bus.publish(UserLoggedOut())

        XCTAssertEqual(recorder.count, 1)
    }

    func testSubscriberOfAnotherTypeReceivesNothing() {
        let bus = AppEventBus()
        let loggedOut = Recorder<UserLoggedOut>()
        let lifecycle = Recorder<AppLifecycleChanged>()
        bus.on(UserLoggedOut.self).record(into: loggedOut).store(in: &cancellables)
        bus.on(AppLifecycleChanged.self).record(into: lifecycle).store(in: &cancellables)

        bus.publish(UserLoggedOut())

        XCTAssertEqual(loggedOut.count, 1)
        XCTAssertEqual(lifecycle.count, 0)
    }

    func testTwoSubscribersOnTheSameTypeBothReceiveOnePublish() {
        let bus = AppEventBus()
        let first = Recorder<UserLoggedOut>()
        let second = Recorder<UserLoggedOut>()
        bus.on(UserLoggedOut.self).record(into: first).store(in: &cancellables)
        bus.on(UserLoggedOut.self).record(into: second).store(in: &cancellables)

        bus.publish(UserLoggedOut())

        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(second.count, 1)
    }

    // MARK: Replay 0

    func testSubscriberThatSubscribesAfterPublishReceivesNothing() {
        let bus = AppEventBus()

        bus.publish(UserLoggedOut())

        let recorder = Recorder<UserLoggedOut>()
        bus.on(UserLoggedOut.self).record(into: recorder).store(in: &cancellables)

        XCTAssertEqual(recorder.count, 0, "PassthroughSubject has no replay buffer")

        bus.publish(UserLoggedOut())
        XCTAssertEqual(recorder.count, 1)
    }

    // MARK: Cancellation

    func testCancellingTheCancellableStopsFurtherDelivery() {
        let bus = AppEventBus()
        let recorder = Recorder<UserLoggedOut>()
        let cancellable = bus.on(UserLoggedOut.self).record(into: recorder)

        bus.publish(UserLoggedOut())
        XCTAssertEqual(recorder.count, 1)

        cancellable.cancel()
        bus.publish(UserLoggedOut())

        XCTAssertEqual(recorder.count, 1)
    }

    // MARK: Ordering

    func testRapidPublishesAreDeliveredToTypeSubscriberInOrder() {
        let bus = AppEventBus()
        let ticks = Recorder<TickEvent>()
        bus.on(TickEvent.self).record(into: ticks).store(in: &cancellables)

        bus.publish(TickEvent(id: 1))
        bus.publish(TockEvent(id: 2))
        bus.publish(TickEvent(id: 3))

        XCTAssertEqual(ticks.values, [TickEvent(id: 1), TickEvent(id: 3)])
    }

    // MARK: Threading

    func testPublishFromABackgroundThreadIsDeliveredWithoutCrash() {
        let bus = AppEventBus()
        let received = expectation(description: "event delivered")
        bus.on(UserLoggedOut.self)
            .sink { _ in received.fulfill() }
            .store(in: &cancellables)

        DispatchQueue.global().async {
            bus.publish(UserLoggedOut())
        }

        wait(for: [received], timeout: 2)
    }

    // MARK: Resource teardown

    func testDroppingTheCancellableReleasesTheSubscriberClosure() {
        let bus = AppEventBus()
        weak var weakProbe: RetainProbe?

        do {
            let probe = RetainProbe()
            weakProbe = probe
            let cancellable = bus.on(UserLoggedOut.self).sink { [probe] _ in probe.touch() }
            XCTAssertNotNil(weakProbe)
            _ = cancellable
        }

        XCTAssertNil(weakProbe, "subscriber closure (and its captures) outlived its AnyCancellable")
    }
}
