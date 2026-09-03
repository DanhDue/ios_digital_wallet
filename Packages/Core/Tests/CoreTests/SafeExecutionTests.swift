import XCTest
@testable import Core

final class SafeExecutionTests: XCTestCase {
    // MARK: happy path

    func testReturnsBlockValueAndDoesNotLogWhenBlockSucceeds() {
        let spy = SpyLogger()
        let result = SafeExecution.run(logger: spy, label: "Load", fallback: "fb") { "ok" }
        XCTAssertEqual(result, "ok")
        XCTAssertTrue(spy.entries.isEmpty)
    }

    // MARK: failure injection

    func testReturnsFallbackAndLogsErrorOnceWithLabelWhenBlockThrows() {
        let spy = SpyLogger()
        let result = SafeExecution.run(logger: spy, label: "Sync", fallback: 99) { () throws -> Int in
            throw AppError(code: "x", message: "kaboom")
        }
        XCTAssertEqual(result, 99)
        XCTAssertEqual(spy.errorEntries.count, 1)
        XCTAssertTrue(spy.errorEntries[0].message.contains("[Sync]"))
        XCTAssertEqual(spy.entries.count, 1, "only one log call, at error level")
    }

    func testDefaultEmptyLabelStillProducesBracketedPrefix() {
        let spy = SpyLogger()
        _ = SafeExecution.run(logger: spy, fallback: 0) { () throws -> Int in
            throw AppError(code: "x", message: "m")
        }
        XCTAssertEqual(spy.errorEntries.count, 1)
        XCTAssertTrue(spy.errorEntries[0].message.contains("[]"))
    }

    func testNoLoggerAndThrowStillReturnsFallbackWithoutCrashing() {
        let result = SafeExecution.run(fallback: -1) { () throws -> Int in
            throw AppError(code: "x", message: "m")
        }
        XCTAssertEqual(result, -1)
    }

    // MARK: fallback identity

    func testFallbackReturnedIsTheExactInstanceProvided() {
        let fallback = Box(value: 7)
        let result = SafeExecution.run(fallback: fallback) { () throws -> Box in
            throw AppError(code: "x", message: "m")
        }
        XCTAssertTrue(result === fallback)
    }
}
