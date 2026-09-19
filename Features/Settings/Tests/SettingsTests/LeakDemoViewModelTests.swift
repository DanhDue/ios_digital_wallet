#if DEBUG
    import Combine
    import Core
    import D3NexusLogging
    import Framework
    import XCTest
    @testable import Settings

    private final class SpyLogManager: LogManager, @unchecked Sendable {
        private let lock = NSLock()
        private(set) var loggedRecords: [LogRecord] = []

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

    private final class ManualTestClock: LeakSentinelClock, @unchecked Sendable {
        private final class Token: LeakSentinelCancellable, @unchecked Sendable {
            private let lock = NSLock()
            private var isCancelled = false
            private let action: @Sendable () -> Void

            init(action: @escaping @Sendable () -> Void) {
                self.action = action
            }

            func cancel() {
                lock.lock()
                defer { lock.unlock() }
                isCancelled = true
            }

            func fire() {
                lock.lock()
                let cancelled = isCancelled
                lock.unlock()
                if !cancelled {
                    action()
                }
            }
        }

        private let lock = NSLock()
        private var scheduledTokens: [Token] = []

        func schedule(after _: TimeInterval, action: @escaping @Sendable () -> Void) -> any LeakSentinelCancellable {
            let token = Token(action: action)
            lock.lock()
            scheduledTokens.append(token)
            lock.unlock()
            return token
        }

        func advance() {
            lock.lock()
            let tokens = scheduledTokens
            scheduledTokens.removeAll()
            lock.unlock()
            for token in tokens {
                token.fire()
            }
        }
    }

    @MainActor
    final class LeakDemoViewModelTests: XCTestCase {
        func testInitialStateIsIdle() {
            let sut = LeakDemoViewModel()
            XCTAssertEqual(sut.uiState.statusMessage, "Idle")
            XCTAssertFalse(sut.uiState.isLeakingTriggered)
            XCTAssertFalse(sut.uiState.isCleanTriggered)
        }

        func testLeakingFlowRetainsViewModel() {
            weak var weakVM: LeakDemoViewModel?
            do {
                let sut = LeakDemoViewModel()
                weakVM = sut
                sut.onAction(.triggerLeak)
                XCTAssertTrue(sut.uiState.isLeakingTriggered)
                XCTAssertFalse(sut.uiState.isCleanTriggered)
            }

            XCTAssertNotNil(weakVM, "Leaking flow must retain the view model via Combine sink cycle")
        }

        func testControlFlowDeallocatesCleanly() {
            weak var weakVM: LeakDemoViewModel?
            do {
                let sut = LeakDemoViewModel()
                weakVM = sut
                sut.onAction(.triggerClean)
                XCTAssertTrue(sut.uiState.isCleanTriggered)
                XCTAssertFalse(sut.uiState.isLeakingTriggered)
            }

            XCTAssertNil(weakVM, "Control flow must allow the view model to deallocate cleanly")
        }

        func testLeakingFlowTriggersLeakSentinel() {
            let clock = ManualTestClock()
            let spy = SpyLogManager()
            let sentinel = LeakSentinel(clock: clock, logManager: spy)

            do {
                let sut = LeakDemoViewModel(leakSentinel: sentinel, gracePeriod: 3.0)
                sut.onAction(.triggerLeak)
                sut.onAction(.onDisappear)
            }

            // Object is still alive because of the retain cycle.
            // Advancing clock past grace period should trigger the sentinel.
            clock.advance()

            XCTAssertEqual(spy.loggedRecords.count, 1)
            guard let record = spy.loggedRecords.first else {
                XCTFail("Expected a log record from LeakSentinel")
                return
            }
            XCTAssertEqual(record.level, .error)
            XCTAssertEqual(record.module, "LeakSentinel")
            XCTAssertTrue(record.message.contains("LeakDemoViewModel"))
            XCTAssertEqual(record.metadata["leakedObject"], "LeakDemoViewModel")
            XCTAssertEqual(record.metadata["gracePeriod"], "3.0")
        }

        func testControlFlowDoesNotTriggerLeakSentinel() {
            let clock = ManualTestClock()
            let spy = SpyLogManager()
            let sentinel = LeakSentinel(clock: clock, logManager: spy)

            do {
                let sut = LeakDemoViewModel(leakSentinel: sentinel, gracePeriod: 3.0)
                sut.onAction(.triggerClean)
                sut.onAction(.onDisappear)
            }

            // Object deallocated immediately upon scope exit.
            // Advancing clock should NOT produce any error logs.
            clock.advance()

            XCTAssertTrue(spy.loggedRecords.isEmpty, "Deallocated object must not trigger sentinel")
        }

        func testOnAppearCancelsSentinelPendingCheck() {
            let clock = ManualTestClock()
            let spy = SpyLogManager()
            let sentinel = LeakSentinel(clock: clock, logManager: spy)

            let sut = LeakDemoViewModel(leakSentinel: sentinel, gracePeriod: 3.0)
            sut.onAction(.triggerLeak)
            sut.onAction(.onDisappear)
            // User navigates back into screen before grace period expires
            sut.onAction(.onAppear)

            clock.advance()

            XCTAssertTrue(spy.loggedRecords.isEmpty, "Cancelled sentinel token must not produce records")
        }

        func testEventEmission() {
            let sut = LeakDemoViewModel()
            var emittedEvents: [LeakDemoEvent] = []
            let cancellable = sut.eventSubject.sink { emittedEvents.append($0) }
            defer { cancellable.cancel() }

            sut.onAction(.triggerLeak)
            XCTAssertEqual(emittedEvents, [.leakTriggered])

            sut.onAction(.triggerClean)
            XCTAssertEqual(emittedEvents, [.leakTriggered, .cleanTriggered])
        }
    }
#endif
