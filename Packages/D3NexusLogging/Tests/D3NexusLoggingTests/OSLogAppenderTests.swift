import os
import XCTest
@testable import D3NexusLogging

final class OSLogAppenderTests: XCTestCase {
    private func makeSuite() -> UserDefaults {
        let name = "test.suite.\(UUID().uuidString)"
        guard let suite = UserDefaults(suiteName: name) else {
            fatalError("Could not create test UserDefaults suite")
        }
        return suite
    }

    // Scenario: Correlation prefix is present and well formed; category equals record module
    @MainActor
    func testCorrelationPrefixAndCategory() {
        struct Captured: Equatable {
            var subsystem: String?
            var category: String?
            var message: String?
            var level: LogLevel?
        }
        let box = OSAllocatedUnfairLock<Captured>(initialState: Captured())

        let appender = OSLogAppender(subsystem: "com.danhdue.iOSDigitalWallet") { sub, cat, lvl, msg in
            box.withLock {
                $0 = Captured(subsystem: sub, category: cat, message: msg, level: lvl)
            }
        }
        trackForMemoryLeaks(appender)

        let record = LogRecord(
            module: "Payments",
            level: .info,
            message: "Initiating transfer",
            traceId: "4bf92f3577b34da6a3ce929d0e0e4736",
            spanId: "00f067aa0ba902b7"
        )

        appender.append(record)

        let captured = box.withLock { $0 }
        XCTAssertEqual(captured.subsystem, "com.danhdue.iOSDigitalWallet")
        XCTAssertEqual(captured.category, "Payments")
        XCTAssertEqual(captured.level, LogLevel.info)
        XCTAssertEqual(
            captured.message,
            "[4bf92f3577b34da6a3ce929d0e0e4736][00f067aa0ba902b7] Initiating transfer"
        )
    }

    // Scenario: Message with error description formats correctly
    @MainActor
    func testMessageWithErrorDescription() {
        let box = OSAllocatedUnfairLock<String?>(initialState: .none)

        let appender = OSLogAppender(subsystem: "com.test") { _, _, _, msg in
            box.withLock { $0 = msg }
        }
        trackForMemoryLeaks(appender)

        let record = LogRecord(
            module: "Auth",
            level: .error,
            message: "Authentication failed",
            traceId: "4bf92f3577b34da6a3ce929d0e0e4736",
            spanId: "00f067aa0ba902b7",
            errorDescription: "Invalid credentials"
        )

        appender.append(record)
        XCTAssertEqual(
            box.withLock { $0 },
            "[4bf92f3577b34da6a3ce929d0e0e4736][00f067aa0ba902b7] Authentication failed | error: Invalid credentials"
        )
    }

    // Scenario: All 5 log levels are handled
    @MainActor
    func testAllSeveritiesDispatched() {
        let levels: [LogLevel] = [.verbose, .debug, .info, .warning, .error]

        for level in levels {
            let box = OSAllocatedUnfairLock<LogLevel?>(initialState: .none)
            let appender = OSLogAppender(subsystem: "com.test") { _, _, lvl, _ in
                box.withLock { $0 = lvl }
            }
            trackForMemoryLeaks(appender)

            let record = LogRecord(
                module: "Test",
                level: level,
                message: "Msg for \(level)",
                traceId: "4bf92f3577b34da6a3ce929d0e0e4736",
                spanId: "00f067aa0ba902b7"
            )
            appender.append(record)
            XCTAssertEqual(box.withLock { $0 }, level)
        }
    }

    /// UC-4.1 & UC-4.2: respectsModuleToggle = false, kill-switch suppresses
    @MainActor
    func testRespectsModuleToggleIsFalseAndDispatchesWhenModuleMuted() {
        let countBox = OSAllocatedUnfairLock<Int>(initialState: 0)
        let appender = OSLogAppender(subsystem: "com.test") { _, _, _, _ in
            countBox.withLock { $0 += 1 }
        }
        trackForMemoryLeaks(appender)

        XCTAssertFalse(appender.respectsModuleToggle)

        let suite = makeSuite()
        let store = ToggleStore(userDefaults: suite)
        let manager = LogManagerImpl(toggleStore: store)
        manager.registerAppender(appender)

        // Mute module
        manager.setModuleEnabled("Scanner", enabled: false)

        let record = LogRecord(
            module: "Scanner",
            level: .info,
            message: "Muted scan",
            traceId: "4bf92f3577b34da6a3ce929d0e0e4736",
            spanId: "00f067aa0ba902b7"
        )
        manager.log(record)

        // Must still receive because respectsModuleToggle is false!
        XCTAssertEqual(countBox.withLock { $0 }, 1)

        // Now disable oslog appender kill switch
        manager.setAppenderEnabled("oslog", enabled: false)
        manager.log(record)

        // Count should not increase because appender is disabled
        XCTAssertEqual(countBox.withLock { $0 }, 1)
    }

    /// Standard init without custom sink executes safely across all severities
    @MainActor
    func testStandardInitDoesNotCrash() {
        let appender = OSLogAppender(subsystem: "com.danhdue.wallet")
        trackForMemoryLeaks(appender)

        for level in [LogLevel.verbose, .debug, .info, .warning, .error] {
            let record = LogRecord(
                module: "Settings",
                level: level,
                message: "Standard os.Logger append test: \(level)",
                traceId: "4bf92f3577b34da6a3ce929d0e0e4736",
                spanId: "00f067aa0ba902b7"
            )
            appender.append(record)
        }
    }
}
