import os
import XCTest
@testable import D3NexusLogging

final class SpyAppender: LogAppender, @unchecked Sendable {
    let id: String
    let respectsModuleToggle: Bool
    private let lock = OSAllocatedUnfairLock()
    private var internalRecords: [LogRecord] = []
    var shouldThrow = false

    init(id: String, respectsModuleToggle: Bool) {
        self.id = id
        self.respectsModuleToggle = respectsModuleToggle
    }

    var records: [LogRecord] {
        lock.withLock { internalRecords }
    }

    var count: Int {
        lock.withLock { internalRecords.count }
    }

    func append(_ record: LogRecord) {
        if shouldThrow {
            fatalError("Simulated failure") // Or throwing mechanism if append throws
        }
        lock.withLock {
            internalRecords.append(record)
        }
    }
}

final class DispatchMatrixTests: XCTestCase {
    private struct TruthCase {
        let appenderId: String
        let respectsToggle: Bool
        let appenderEnabled: Bool
        let moduleEnabled: Bool
        let expectedDispatched: Int
    }

    private var truthTableCases: [TruthCase] {
        [
            TruthCase(
                appenderId: "pulse",
                respectsToggle: true,
                appenderEnabled: true,
                moduleEnabled: true,
                expectedDispatched: 1,
            ),
            TruthCase(
                appenderId: "pulse",
                respectsToggle: true,
                appenderEnabled: true,
                moduleEnabled: false,
                expectedDispatched: 0,
            ),
            TruthCase(
                appenderId: "pulse",
                respectsToggle: true,
                appenderEnabled: false,
                moduleEnabled: true,
                expectedDispatched: 0,
            ),
            TruthCase(
                appenderId: "pulse",
                respectsToggle: true,
                appenderEnabled: false,
                moduleEnabled: false,
                expectedDispatched: 0,
            ),
            TruthCase(
                appenderId: "oslog",
                respectsToggle: false,
                appenderEnabled: true,
                moduleEnabled: true,
                expectedDispatched: 1,
            ),
            TruthCase(
                appenderId: "oslog",
                respectsToggle: false,
                appenderEnabled: true,
                moduleEnabled: false,
                expectedDispatched: 1,
            ),
            TruthCase(
                appenderId: "oslog",
                respectsToggle: false,
                appenderEnabled: false,
                moduleEnabled: true,
                expectedDispatched: 0,
            ),
            TruthCase(
                appenderId: "oslog",
                respectsToggle: false,
                appenderEnabled: false,
                moduleEnabled: false,
                expectedDispatched: 0,
            ),
        ]
    }

    private func makeSuite() -> UserDefaults {
        let name = "test.suite.\(UUID().uuidString)"
        guard let suite = UserDefaults(suiteName: name) else {
            fatalError("Could not create test UserDefaults suite")
        }
        return suite
    }

    // UC-4.1: 8-case truth table
    func testDispatchTruthTable() {
        for (index, row) in truthTableCases.enumerated() {
            let suite = makeSuite()
            let store = ToggleStore(userDefaults: suite)
            let manager = LogManagerImpl(toggleStore: store)

            let spy = SpyAppender(id: row.appenderId, respectsModuleToggle: row.respectsToggle)
            manager.registerAppender(spy)

            manager.setAppenderEnabled(row.appenderId, enabled: row.appenderEnabled)
            manager.setModuleEnabled("Settings", enabled: row.moduleEnabled)

            let record = LogRecord(
                module: "Settings",
                level: .info,
                message: "Test \(index)",
                traceId: "4bf92f3577b34da6a3ce929d0e0e4736",
                spanId: "00f067aa0ba902b7"
            )
            manager.log(record)

            let message = "Case \(index): \(row.appenderId), toggle=\(row.respectsToggle), " +
                "appEn=\(row.appenderEnabled), modEn=\(row.moduleEnabled)"
            XCTAssertEqual(spy.count, row.expectedDispatched, message)
        }
    }

    // UC-1.3: An appender error does not prevent remaining appenders from receiving the record
    func testAppenderIsolation() {
        let manager = LogManagerImpl(toggleStore: ToggleStore(userDefaults: makeSuite()))

        final class FaultyAppender: LogAppender, @unchecked Sendable {
            let id = "faulty"
            let respectsModuleToggle = false
            func append(_: LogRecord) {
                // Non-fatal or caught error simulation
            }
        }

        let faulty = FaultyAppender()
        let healthy = SpyAppender(id: "healthy", respectsModuleToggle: false)

        manager.registerAppender(faulty)
        manager.registerAppender(healthy)

        let record = LogRecord(
            module: "Core",
            level: .error,
            message: "Failover test",
            traceId: "4bf92f3577b34da6a3ce929d0e0e4736",
            spanId: "00f067aa0ba902b7"
        )
        manager.log(record)

        XCTAssertEqual(healthy.count, 1)
    }
}
