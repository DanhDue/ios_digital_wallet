import Foundation
import XCTest
@testable import D3NexusLogging

final class LogRecordTests: XCTestCase {
    func testLogLevelOrdering() {
        XCTAssertTrue(LogLevel.verbose < LogLevel.debug)
        XCTAssertTrue(LogLevel.debug < LogLevel.info)
        XCTAssertTrue(LogLevel.info < LogLevel.warning)
        XCTAssertTrue(LogLevel.warning < LogLevel.error)
    }

    func testLogRecordInitializationWithDefaults() {
        let record = LogRecord(
            module: "TestModule",
            level: .info,
            message: "Hello",
            traceId: "4bf92f3577b34da6a3ce929d0e0e4736",
            spanId: "00f067aa0ba902b7"
        )

        XCTAssertEqual(record.module, "TestModule")
        XCTAssertEqual(record.level, .info)
        XCTAssertEqual(record.message, "Hello")
        XCTAssertNil(record.parentSpanId)
        XCTAssertNil(record.errorDescription)
        XCTAssertTrue(record.metadata.isEmpty)
    }

    func testEmptyMessageAndMetadataAreAccepted() {
        let record = LogRecord(
            module: "Core",
            level: .debug,
            message: "",
            traceId: "4bf92f3577b34da6a3ce929d0e0e4736",
            spanId: "00f067aa0ba902b7",
            metadata: [:]
        )

        XCTAssertEqual(record.message, "")
        XCTAssertTrue(record.metadata.isEmpty)
        XCTAssertEqual(record.traceId, "4bf92f3577b34da6a3ce929d0e0e4736")
    }

    func testOversizedMessagePreservedWithoutCorruption() {
        let largeMessage = String(repeating: "A", count: 64 * 1024)
        let record = LogRecord(
            module: "Network",
            level: .debug,
            message: largeMessage,
            traceId: "4bf92f3577b34da6a3ce929d0e0e4736",
            spanId: "00f067aa0ba902b7"
        )

        XCTAssertEqual(record.message.count, 64 * 1024)
        XCTAssertEqual(record.message, largeMessage)
    }

    func testErrorDescriptionCaptured() {
        struct SampleError: Error, CustomStringConvertible {
            var description: String {
                "Connection timed out"
            }
        }

        let record = LogRecord(
            module: "Network",
            level: .error,
            message: "Request failed",
            traceId: "4bf92f3577b34da6a3ce929d0e0e4736",
            spanId: "00f067aa0ba902b7",
            errorDescription: String(describing: SampleError())
        )

        XCTAssertEqual(record.level, .error)
        XCTAssertEqual(record.message, "Request failed")
        XCTAssertEqual(record.errorDescription, "Connection timed out")
    }

    func testCodableRoundtrip() throws {
        let original = LogRecord(
            module: "Auth",
            level: .warning,
            message: "Token expiring",
            traceId: "4bf92f3577b34da6a3ce929d0e0e4736",
            spanId: "00f067aa0ba902b7",
            parentSpanId: "1111222233334444",
            errorDescription: "Notice",
            metadata: ["key": "value"]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LogRecord.self, from: data)

        XCTAssertEqual(original, decoded)
    }
}
