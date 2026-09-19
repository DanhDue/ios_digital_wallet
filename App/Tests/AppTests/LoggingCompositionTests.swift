import Core
import D3NexusLogging
import os
import XCTest
@testable import iOSDigitalWallet

final class LoggingCompositionTests: XCTestCase {
    private final class SpyLogger: LoggerProtocol, @unchecked Sendable {
        struct Entry {
            let level: LogLevel
            let message: String
            let metadata: [String: String]
        }

        let module: String = "Test"
        let traceId: String = "4bf92f3577b34da6a3ce929d0e0e4736"
        let spanId: String = "00f067aa0ba902b7"
        let parentSpanId: String? = nil

        private let storage = os.OSAllocatedUnfairLock<[Entry]>(initialState: [])

        var entries: [Entry] {
            storage.withLock { $0 }
        }

        func verbose(_ message: String, error _: (any Error)?, metadata: [String: String]?) {
            storage.withLock { $0.append(Entry(level: .verbose, message: message, metadata: metadata ?? [:])) }
        }

        func debug(_ message: String, error _: (any Error)?, metadata: [String: String]?) {
            storage.withLock { $0.append(Entry(level: .debug, message: message, metadata: metadata ?? [:])) }
        }

        func info(_ message: String, error _: (any Error)?, metadata: [String: String]?) {
            storage.withLock { $0.append(Entry(level: .info, message: message, metadata: metadata ?? [:])) }
        }

        func warning(_ message: String, error _: (any Error)?, metadata: [String: String]?) {
            storage.withLock { $0.append(Entry(level: .warning, message: message, metadata: metadata ?? [:])) }
        }

        func error(_ message: String, error _: (any Error)?, metadata: [String: String]?) {
            storage.withLock { $0.append(Entry(level: .error, message: message, metadata: metadata ?? [:])) }
        }

        func withSpan() -> any LoggerProtocol {
            self
        }
    }

    // Scenario: Call-site provenance survives the adapter
    func testCallSiteProvenanceSurvivesAdapter() {
        let spy = SpyLogger()
        let adapter = D3NexusCoreLoggerAdapter(logger: spy)

        adapter.debug("debug message", file: "TestFile.swift", function: "testFunc()", line: 42)
        adapter.info("info message", file: "TestFile.swift", function: "testFunc()", line: 55)
        adapter.error("error message", file: "TestFile.swift", function: "testFunc()", line: 99)

        let entries = spy.entries
        XCTAssertEqual(entries.count, 3)

        XCTAssertEqual(entries[0].level, .debug)
        XCTAssertEqual(entries[0].message, "debug message")
        XCTAssertEqual(entries[0].metadata["file"], "TestFile.swift")
        XCTAssertEqual(entries[0].metadata["function"], "testFunc()")
        XCTAssertEqual(entries[0].metadata["line"], "42")

        XCTAssertEqual(entries[1].level, .info)
        XCTAssertEqual(entries[1].metadata["line"], "55")

        XCTAssertEqual(entries[2].level, .error)
        XCTAssertEqual(entries[2].metadata["line"], "99")
    }

    // Scenario: The composition root bootstraps logging exactly once without trapping
    func testLoggingCompositionBuildsMultipleTimesWithoutTrap() {
        let logger1 = LoggingComposition.buildCoreLogger(subsystem: "com.test.one")
        let logger2 = LoggingComposition.buildCoreLogger(subsystem: "com.test.two")

        logger1.info("Log 1", file: #file, function: #function, line: #line)
        logger2.info("Log 2", file: #file, function: #function, line: #line)

        XCTAssertNotNil(logger1)
        XCTAssertNotNil(logger2)
    }
}
