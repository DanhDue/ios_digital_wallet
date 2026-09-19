#if DEBUG
    import os
    import XCTest
    @testable import D3NexusLogging

    private struct ScheduledClockItem {
        let id: UUID
        let delay: TimeInterval
        let action: @Sendable () -> Void
    }

    private final class TestClockToken: LeakSentinelCancellable, @unchecked Sendable {
        private let onCancel: () -> Void
        init(onCancel: @escaping () -> Void) {
            self.onCancel = onCancel
        }

        func cancel() {
            onCancel()
        }
    }

    private final class TestClock: LeakSentinelClock, @unchecked Sendable {
        private var items: [ScheduledClockItem] = []
        private var currentTime: TimeInterval = 0
        private let lock = NSLock()

        func schedule(
            after delay: TimeInterval,
            action: @escaping @Sendable () -> Void
        ) -> any LeakSentinelCancellable {
            lock.lock()
            let id = UUID()
            items.append(ScheduledClockItem(id: id, delay: currentTime + delay, action: action))
            lock.unlock()

            return TestClockToken { [weak self] in
                guard let self else { return }
                lock.lock()
                items.removeAll(where: { $0.id == id })
                lock.unlock()
            }
        }

        func advance(by seconds: TimeInterval) {
            lock.lock()
            currentTime += seconds
            let ready = items.filter { $0.delay <= currentTime }
            items.removeAll(where: { $0.delay <= currentTime })
            lock.unlock()

            for item in ready {
                item.action()
            }
        }
    }

    private final class SpyLogManager: LogManager, @unchecked Sendable {
        var loggedRecords: [LogRecord] = []
        private let lock = NSLock()

        func getLogger(module: String) -> any LoggerProtocol {
            NoOpLogger(module: module)
        }

        func registerAppender(_: any LogAppender) {}

        func log(_ record: LogRecord) {
            lock.lock()
            defer { lock.unlock() }
            loggedRecords.append(record)
        }

        func setModuleEnabled(_: String, enabled _: Bool) {}
        func isModuleEnabled(_: String) -> Bool {
            true
        }

        func setAppenderEnabled(_: String, enabled _: Bool) {}
        func isAppenderEnabled(_: String) -> Bool {
            true
        }
    }

    private final class SampleObject {}

    @MainActor
    final class LeakSentinelTests: XCTestCase {
        private func trackForMemoryLeaks(
            _ instance: AnyObject,
            file: StaticString = #filePath,
            line: UInt = #line
        ) {
            addTeardownBlock { [weak instance] in
                XCTAssertNil(
                    instance,
                    "Instance should have been deallocated. Potential memory leak.",
                    file: file,
                    line: line
                )
            }
        }

        func testSentinelReportsObjectOutlivingScope() throws {
            let clock = TestClock()
            let spy = SpyLogManager()
            let sut = LeakSentinel(clock: clock, logManager: spy)
            trackForMemoryLeaks(sut)

            var retainedObject: SampleObject? = SampleObject()
            try sut.track(XCTUnwrap(retainedObject), name: "RetainedSample", gracePeriod: 3.0)

            // Clock advances past grace period while object is still held
            clock.advance(by: 4.0)

            XCTAssertEqual(spy.loggedRecords.count, 1)
            guard let record = spy.loggedRecords.first else {
                XCTFail("Expected one logged record")
                return
            }

            XCTAssertEqual(record.level, .error)
            XCTAssertEqual(record.module, "LeakSentinel")
            XCTAssertTrue(record.message.contains("RetainedSample"))
            XCTAssertEqual(record.metadata["leakedObject"], "RetainedSample")
            XCTAssertEqual(record.metadata["gracePeriod"], "3.0")

            _ = retainedObject
            retainedObject = nil
        }

        func testObjectDeallocatedWithinGracePeriodProducesNoRecord() throws {
            let clock = TestClock()
            let spy = SpyLogManager()
            let sut = LeakSentinel(clock: clock, logManager: spy)
            trackForMemoryLeaks(sut)

            var transientObject: SampleObject? = SampleObject()
            try sut.track(XCTUnwrap(transientObject), name: "TransientSample", gracePeriod: 3.0)

            // Object deallocates before grace period expires
            transientObject = nil

            // Clock advances past grace period
            clock.advance(by: 5.0)

            XCTAssertEqual(
                spy.loggedRecords.count,
                0,
                "No leak record should be dispatched when object deallocates in time"
            )
        }

        func testCancelledRegistrationNeverReports() throws {
            let clock = TestClock()
            let spy = SpyLogManager()
            let sut = LeakSentinel(clock: clock, logManager: spy)
            trackForMemoryLeaks(sut)

            var retainedObject: SampleObject? = SampleObject()
            let token = try sut.track(XCTUnwrap(retainedObject), name: "CancelledSample", gracePeriod: 3.0)

            // Cancel token (e.g. view reappeared)
            token.cancel()

            // Clock advances past grace period
            clock.advance(by: 10.0)

            XCTAssertEqual(spy.loggedRecords.count, 0, "Cancelled tracking token must never trigger a leak record")

            _ = retainedObject
            retainedObject = nil
        }

        func testSentinelHoldsNoStrongReference() throws {
            let clock = TestClock()
            let spy = SpyLogManager()
            let sut = LeakSentinel(clock: clock, logManager: spy)
            trackForMemoryLeaks(sut)

            var object: SampleObject? = SampleObject()
            weak let weakRef = object
            _ = weakRef
            XCTAssertNotNil(weakRef)

            try sut.track(XCTUnwrap(object), name: "WeakTrackedSample", gracePeriod: 5.0)

            // Releasing caller's reference must deallocate immediately
            object = nil
            XCTAssertNil(weakRef, "Sentinel must hold a weak reference so object deallocates without delay")
        }

        func testSystemClockSchedulesAndExecutes() {
            let clock = SystemLeakSentinelClock()
            let expectation = expectation(description: "System clock timer fires")

            clock.schedule(after: 0.05) {
                expectation.fulfill()
            }

            waitForExpectations(timeout: 1.0)
        }

        func testSystemClockTokenCancelsExecution() {
            let clock = SystemLeakSentinelClock()
            let didExecute = OSAllocatedUnfairLock(initialState: false)

            let token = clock.schedule(after: 0.05) {
                didExecute.withLock { $0 = true }
            }
            token.cancel()

            let expectation = expectation(description: "Wait to ensure cancellation was honored")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                expectation.fulfill()
            }
            waitForExpectations(timeout: 1.0)

            XCTAssertFalse(didExecute.withLock { $0 }, "Cancelled token must prevent execution")
        }
    }
#endif
